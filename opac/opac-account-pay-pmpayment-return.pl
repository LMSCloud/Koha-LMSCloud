#!/usr/bin/perl

# Copyright 2020 (C) LMSCLoud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use utf8;

use CGI;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI;
use Digest::SHA qw(hmac_sha256_hex);
use Data::Dumper;

use C4::Auth;
use C4::Output;
use C4::Accounts;
use Koha::Database;
use Koha::Patrons;

my $key = 'dsTFshg5678DGHMO';    # dummy for wrong HMAC digest
sub genHmacSha256 {
    my ($key, $str) = @_;
    my $hashval = hmac_sha256_hex($str, $key);

    return $hashval;
}

my $redirectUrl = "/cgi-bin/koha/errors/404.pl";
my $cgi = new CGI;

my $loggerPmp = Koha::Logger->get({ interface => 'epayment.pmpayment' });
$loggerPmp->debug("opac-account-pay-pmpayment-return.pl START cgi:" . Dumper($cgi) . ":");

if ( C4::Context->preference('PmpaymentPaypageOpacPaymentsEnabled') ) {
    $key = C4::Context->preference('PmpaymentSaltHmacSha256');    # salt for generating HMAC md5sum or sha256 digest

    # params set by Koha in opac-account-pay.pl
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $paytypeKoha = $cgi->param('paytypeKoha');

    # params set by pmPayment
    my $pmpAgs            = $cgi->param('ags');    # amtlicher Gemeinde-Schlüssel
    my $pmpTxid           = $cgi->param('txid');    # unique transaction ID
    my $pmpAmount         = $cgi->param('amount');    # amount to be paid in Eurocent
    my $pmpDesc           = $cgi->param('desc');    # SEPA-Verwendungszweck
    my $pmpStatus         = $cgi->param('status');    # generischer Buchungssatz für Stadtkasse
    my $pmpPayment_method = $cgi->param('payment_method') ? $cgi->param('payment_method') : '';    # creditcard paydirect giropay paypal ...
    my $pmpCreated_at     = $cgi->param('created_at');    # e.g. '2016-07-13 13:30:34'
    my $pmpHash           = $cgi->param('hash');    # HMAC sha256 hash value (calculated on base of the parameter values above and $key)

    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl borrowernumberKoha:$borrowernumberKoha:");
    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl amountKoha:$amountKoha:");
    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl accountlinesKoha:" . Dumper(\@accountlinesKoha) . ":");
    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl paytypeKoha:$paytypeKoha:");

    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl pmpAgs:$pmpAgs: pmpTxid:$pmpTxid:");
    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl pmpAmount:$pmpAmount: pmpDesc:$pmpDesc:");
    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl pmpStatus:$pmpStatus: pmpPayment_method:$pmpPayment_method:");
    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl pmpCreated_at:$pmpCreated_at: pmpHash:$pmpHash:");

    my $error = "PMPAYMENT_ERROR_PROCESSING";

    # verify that the 7 CGI arguments of pmPayment are not manipulated
    my $hashesAreEqual = 0;
    my $paramstr = 
        $pmpAgs . '|' .
        $pmpTxid . '|' .
        $pmpAmount . '|' .
        $pmpDesc . '|' .
        $pmpStatus . '|' .
        $pmpPayment_method . '|' .
        $pmpCreated_at;

    my $hashval = genHmacSha256($key, $paramstr);
    if ( $hashval eq $pmpHash ) {
        $hashesAreEqual = 1;
    }
    $loggerPmp->debug("opac-account-pay-pmpayment-return.pl paramstr:$paramstr: hashval:$hashval: pmpHash:$pmpHash: hashesAreEqual:$hashesAreEqual:");


    # If money transfer has succeeded (i.e. $pmpStatus == 1) we have to check if the selected accountlines now are also paid in Koha.
    if ( $hashesAreEqual && $pmpStatus == 1 ) {
        # There may be a concurrency with opac-account-pay-pmpayment-notify.pl (simultanously called by pmPayment),
        # so we wait here for a certain maximum time to give opac-account-pay-pmpayment-notify.pl the opportunity to completely execute its required action.
        # The 'certain maximum time' depends on the number of accountlines to be paid; it ranges from 5*2 to 5*4 seconds.
        my $waitSingleDuration = 2 + (@accountlinesKoha + 0)/10;
        if ( $waitSingleDuration > 4 ) {
            $waitSingleDuration = 4;
        }
        for ( my $waitCount = 0; $waitCount < 6; $waitCount += 1 ) {
            my $account = Koha::Account->new( { patron_id => $borrowernumberKoha } );
            my @lines = Koha::Account::Lines->search(
                {
                    accountlines_id => { -in => \@accountlinesKoha }
                }
            );

            my $sumAmountoutstanding = 0.0;
            foreach my $accountline ( @lines ) {
                $loggerPmp->trace("opac-account-pay-pmpayment-return.pl accountline->{_column_data}:" . Dumper($accountline->{_column_data}) . ":");
                $loggerPmp->debug("opac-account-pay-pmpayment-return.pl accountline->id:" . $accountline->accountlines_id() . ": ->amountoutstanding():" . $accountline->amountoutstanding() . ":");
                $sumAmountoutstanding += $accountline->amountoutstanding();
            }
            $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding was also done in the complimentary opac-account-pay-pl
            $loggerPmp->debug("opac-account-pay-pmpayment-return.pl sumAmountoutstanding:$sumAmountoutstanding: amountKoha:$amountKoha: pmpAmount:$pmpAmount:");

            if ( $sumAmountoutstanding == 0.00 ) {
                $loggerPmp->debug("opac-account-pay-pmpayment-return.pl sumAmountoutstanding == 0.00 --- NO error!");
                $error = '';
                last;
            }
            $loggerPmp->debug("opac-account-pay-pmpayment-return.pl not all accountlines paid - now waiting $waitSingleDuration seconds and then trying again ...");
            sleep($waitSingleDuration);
        }
    } elsif ( $hashesAreEqual && $pmpStatus == 0 && $pmpPayment_method eq '' ) {    # patron aborted pmpayment paypage
        $error = "PMPAYMENT_ABORTED_BY_USER";
    }


    my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => "opac-account-pay-return.tt",    # name of non existing tt-file is sufficient
            query           => $cgi,
            type            => "opac",
            authnotrequired => 0,
            debug           => 1,
        }
    );

    my $patron = Koha::Patrons->find( $borrowernumber );
    $template->param(
        borrower    => $patron->unblessed,
        accountview => 1
    );

    $redirectUrl = "/cgi-bin/koha/opac-account.pl?payment=$amountKoha&payment-error=$error";
}
$loggerPmp->debug("opac-account-pay-pmpayment-return.pl END redirectUrl:$redirectUrl:");
print $cgi->redirect($redirectUrl);
