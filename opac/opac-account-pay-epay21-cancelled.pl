#!/usr/bin/perl

# Copyright 2019-2021 (C) LMSCLoud GmbH
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
use strict;
use warnings;
use Data::Dumper;

use CGI;
use CGI::Carp;

use Koha::Logger;
use Koha::Patrons;
use C4::Context;
use C4::Epayment::Epay21;

my $error = 0;
my $errorTemplate = 'EPAY21_ERROR_PROCESSING';
my $redirectUrl = "/cgi-bin/koha/errors/404.pl";
my $cgi = new CGI;

my $logger = Koha::Logger->get({ interface => 'epayment' });    # logger common to all e-payment methods
$logger->debug("opac-account-pay-epay21-cancelled.pl START cgi:" . Dumper($cgi) . ":");

if ( C4::Context->preference('Epay21PaypageOpacPaymentsEnabled') ) {

    # Params set by Koha in Epay21::initPayment() are sent as URL query arguments.
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $paytypeKoha = $cgi->param('paytypeKoha');
    my $timeKoha = $cgi->param('timeKoha');    # also required for calculating correct merchantTxId in $epay21->confirmPayment()

    $logger->debug("opac-account-pay-epay21-cancelled.pl creating new C4::Epayment::Epay21 object. borrowernumberKoha:$borrowernumberKoha: amountKoha:$amountKoha: accountlinesKoha:" . Dumper(@accountlinesKoha) . ": paytypeKoha:$paytypeKoha: timeKoha:$timeKoha:");

    my $patron = Koha::Patrons->find( $borrowernumberKoha );
    if ( $patron ) {
        my $epay21 = C4::Epayment::Epay21->new( { patron => $patron, amount_to_pay => $amountKoha, accountlinesIds => \@accountlinesKoha, paytype => $paytypeKoha, seconds => $timeKoha } );

        # Notify ePay21 that the payment action has been aborted by user, by calling ConfirmPayment with ActionType 'cancel'.
        ( $error, $errorTemplate ) = $epay21->confirmPayment( $cgi, { confirmPaymentQueryAction => 'cancel' } );

    } else {
        my $mess = "Error: No patron found having borrowernumber:$borrowernumberKoha:";
        $logger->error("opac-account-pay-epay21-cancelled.pl $mess");
        carp ("opac-account-pay-epay21-cancelled.pl " . $mess . "\n");
    }
    $redirectUrl = "/cgi-bin/koha/opac-account.pl?payment=$amountKoha&payment-error=$errorTemplate";
}

$logger->debug("opac-account-pay-epay21-cancelled.pl END error:$error: errorTemplate:$errorTemplate: redirectUrl:$redirectUrl:");
print $cgi->redirect($redirectUrl);
