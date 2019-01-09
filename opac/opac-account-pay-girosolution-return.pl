#!/usr/bin/perl

# Copyright 2019 (C) LMSCLoud GmbH
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
use Data::Dumper;    # XXXWH

use C4::Auth;
use C4::Output;
use C4::Accounts;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Patrons;

my $cgi = new CGI;

print STDERR "opac-account-pay-girosolution-return.pl: cgi:", Dumper($cgi), "\n";

if ( C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled') || C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled') ) {

    # params set by Koha in opac-account-pay.pl
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $paytypeKoha = $cgi->param('paytypeKoha');

    # params set by girocheckout
    my $gcReference      = $cgi->param('gcReference');
    my $gcMerchantTxId   = $cgi->param('gcMerchantTxId');
    my $gcBackendTxId    = $cgi->param('gcBackendTxId');
    my $gcAmount         = $cgi->param('gcAmount');
    my $gcCurrency       = $cgi->param('gcCurrency');
    my $gcResultPayment  = $cgi->param('gcResultPayment');
    my $gcHash           = $cgi->param('gcHash');

print STDERR "opac-account-pay-girosolution-return.pl: amountKoha:$amountKoha:\n";
print STDERR "opac-account-pay-girosolution-return.pl: accountlinesKoha:", Dumper(\@accountlinesKoha), ":\n";
print STDERR "opac-account-pay-girosolution-return.pl: borrowernumberKoha:$borrowernumberKoha:\n";
print STDERR "opac-account-pay-girosolution-return.pl: paytypeKoha:$paytypeKoha:\n";

print STDERR "opac-account-pay-girosolution-return.pl: gcReference:$gcReference: gcMerchantTxId:$gcMerchantTxId:\n";
print STDERR "opac-account-pay-girosolution-return.pl: gcBackendTxId:$gcBackendTxId: gcResultPayment:$gcResultPayment:\n";
print STDERR "opac-account-pay-girosolution-return.pl: gcAmount:$gcAmount: gcCurrency:$gcCurrency:\n";

    my $error = "GIROSOLUTION_ERROR_PROCESSING";
    # If money transfer has succeeded (i.e. $gcResultPayment == 4000) we have to check if the selected accountlines now are also paid in Koha.
    if ( $gcResultPayment == 4000 ) {
        my $account = Koha::Account->new( { patron_id => $borrowernumberKoha } );
        my @lines = Koha::Account::Lines->search(
            {
                accountlines_id => { -in => \@accountlinesKoha }
            }
        );

        my $sumAmountoutstanding = 0.0;
        foreach my $accountline ( @lines ) {
###print STDERR "opac-account-pay-girosolution-message.pl: accountline:", Dumper($accountline), ":\n";
print STDERR "opac-account-pay-girosolution-return.pl: accountline->amountoutstanding:", Dumper($accountline->amountoutstanding()), ":\n";
            $sumAmountoutstanding += $accountline->amountoutstanding();
        }
        $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this roundig was also done in the complimentary opac-account-pay-pl
print STDERR "opac-account-pay-girosolution-return.pl: sumAmountoutstanding:$sumAmountoutstanding: amountKoha:$amountKoha: gcAmount:$gcAmount:\n";

        if ( $sumAmountoutstanding == 0.00 ) {
print STDERR "opac-account-pay-girosolution-return.pl: sumAmountoutstanding == 0.00 --- NO error!\n";
            $error = '';
        }
    }


    my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => "opac-account-pay-return.tt",    # name of non existent tt-file is sufficient
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

    print $cgi->redirect("/cgi-bin/koha/opac-account.pl?payment=$amountKoha&payment-error=$error");
} else {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
}
