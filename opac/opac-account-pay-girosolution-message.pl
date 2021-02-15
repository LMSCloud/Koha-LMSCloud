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

use Koha::Logger;
use Koha::Patrons;
use C4::Context;
use C4::Epayment::GiroSolution;

my $cgi = new CGI;
my $httpResponseStatus = '400 Bad Request';    # default: Bad Request
my $error = 0;
my $kohaPaymentId;

my $logger = Koha::Logger->get({ interface => 'epayment' });    # logger common to all e-payment methods
$logger->debug("opac-account-pay-girosolution-message.pl START cgi:" . Dumper($cgi) . ":");

if ( C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled') || C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled') ) {

    # Params set by Koha in GiroSolution::initPayment() are sent as URL query arguments.
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $paytypeKoha = $cgi->param('paytypeKoha');

    $logger->debug("opac-account-pay-girosolution-message.pl creating new C4::Epayment::GiroSolution object. borrowernumberKoha:$borrowernumberKoha: paytypeKoha:$paytypeKoha:  amountKoha:$amountKoha: accountlinesKoha:" . Dumper(@accountlinesKoha) . ":");

    my $patron = Koha::Patrons->find( $borrowernumberKoha );
    if ( $patron ) {
        my $girosolution = C4::Epayment::GiroSolution->new( { patron => $patron, amount_to_pay => $amountKoha, accountlinesIds => \@accountlinesKoha, paytype => $paytypeKoha } );

        # verify online payment by calling the webservice to check the transaction status and, if paid, also 'pay' the accountlines in Koha
        ( $error, $kohaPaymentId ) = $girosolution->checkOnlinePaymentStatusAndPayInKoha($cgi);

    } else {
        my $mess = "Error: No patron found having borrowernumber:$borrowernumberKoha:";
        $logger->error("opac-account-pay-girosolution-message.pl $mess");
        carp ("opac-account-pay-girosolution-message.pl " . $mess . "\n");
    }

    $logger->debug("opac-account-pay-girosolution-message.pl error:$error: kohaPaymentId:" . (defined($kohaPaymentId) ? $kohaPaymentId : 'undef') . ":");
    if ( $kohaPaymentId ) {
        $logger->debug("opac-account-pay-girosolution-message.pl It seems that the external online payment and the Koha-payment have succeeded!");
        $httpResponseStatus = '200 OK';    # return statuscode '200 OK'
    } else {
        $logger->debug("opac-account-pay-girosolution-message.pl It seems that the external online payment or the Koha-payment has NOT succeeded!");
        $httpResponseStatus = '400 Bad Request';    # return statuscode '400 Bad Request'
        ###$httpResponseStatus = '333 Bad Request';    # test only; return neither 200 nor 400; this leads via 'return $httpresponse;' to the wanted multiple repetition of this call by GiroSolution (one call each half hour)
    }
    $logger->debug("opac-account-pay-girosolution-message.pl returns cgi with httpResponseStatus:" . $httpResponseStatus . ":");

    print $cgi->header( -status => $httpResponseStatus,
                        -charset => 'utf-8',
                      );

}
