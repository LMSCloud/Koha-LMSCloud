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
use C4::Epayment::GiroSolution;

my $error = 0;
my $errorTemplate = 'GIROSOLUTION_ERROR_PROCESSING';
my $redirectUrl = "/cgi-bin/koha/errors/404.pl";
my $cgi = new CGI;

my $logger = Koha::Logger->get({ interface => 'epayment' });    # logger common to all e-payment methods
$logger->debug("opac-account-pay-girosolution-return.pl START cgi:" . Dumper($cgi) . ":");

if ( C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled') || C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled') || C4::Context->preference('GirosolutionPaypageOpacPaymentsEnabled') ) {

    # When Girosolution calls this return/success/fail URL it uses HTTP GET in case of Giropay and CreditCard, so we can use $cgi->param(...) to get all params, i.e. both the gc* form params and the *Koha query params.
    # When Girosolution calls this return/success/fail URL it uses HTTP POST in case of Paypage, so we can use $cgi->param(...) to get the gc* form params, but have to use $cgi->url_param(...) to get the *Koha query params.
    # This is differing from the call of the notify/message URL in the Paypage case. (See opac-account-pay-girosolution-message.pl)
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $paytypeKoha = $cgi->param('paytypeKoha');
    
    # Girosolution sends a HTTP POST request in case of Paypage, with the gc* params as form params, so the *Koha params of the query URL have to be accessed via $cgi->url_param().
    $amountKoha = $cgi->url_param('amountKoha') if !$amountKoha;
    @accountlinesKoha = $cgi->url_param('accountlinesKoha') if !@accountlinesKoha;
    $borrowernumberKoha = $cgi->url_param('borrowernumberKoha') if !$borrowernumberKoha;
    $paytypeKoha = $cgi->url_param('paytypeKoha') if !$paytypeKoha;

    $logger->debug("opac-account-pay-girosolution-return.pl creating new C4::Epayment::GiroSolution object. borrowernumberKoha:$borrowernumberKoha: amountKoha:$amountKoha: accountlinesKoha:" . Dumper(@accountlinesKoha) . ": paytypeKoha:$paytypeKoha:");

    my $patron = Koha::Patrons->find( $borrowernumberKoha );
    if ( $patron ) {
        my $girosolution = C4::Epayment::GiroSolution->new( { patron => $patron, amount_to_pay => $amountKoha, accountlinesIds => \@accountlinesKoha, paytype => $paytypeKoha } );

        # verify that the accountlines have been 'paid' in Koha by opac-account-pay-girosolution-message.pl
        ( $error, $errorTemplate ) = $girosolution->verifyPaymentInKoha($cgi);

    } else {
        my $mess = "Error: No patron found having borrowernumber:$borrowernumberKoha:";
        $logger->error("opac-account-pay-girosolution-return.pl $mess");
        carp ("opac-account-pay-girosolution-return.pl " . $mess . "\n");
    }
    $redirectUrl = "/cgi-bin/koha/opac-account.pl?payment=$amountKoha&payment-error=$errorTemplate";
}

$logger->debug("opac-account-pay-girosolution-return.pl END error:$error: errorTemplate:$errorTemplate: redirectUrl:$redirectUrl:");
print $cgi->redirect($redirectUrl);
