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

use strict;
use warnings;

use Modern::Perl;
use CGI;
use CGI::Carp;
use Data::Dumper;

use Koha::Logger;
use Koha::Patrons;
use C4::Context;
use C4::Epayment::PmPaymentPaypage;


my $cgi = new CGI;
my $httpResponseStatus = '400 Bad Request';    # default: Bad Request
my $error = 0;
my $kohaPaymentId;

my $logger = Koha::Logger->get({ interface => 'epayment' });    # logger common to all e-payment methods
$logger->debug("opac-account-pay-pmpayment-notify.pl START cgi:" . Dumper($cgi) . ":");

if ( C4::Context->preference('PmpaymentPaypageOpacPaymentsEnabled') ) {

    # some params set by Koha in opac-account-pay.pl and PmPaymentPaypage.pm as URL query arguments
    my $amountKoha = $cgi->url_param('amountKoha');
    my @accountlinesKoha = $cgi->url_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->url_param('borrowernumberKoha');

    $logger->debug("opac-account-pay-pmpayment-notify.pl creating new C4::Epayment::PmPaymentPaypage object. borrowernumberKoha:$borrowernumberKoha: amountKoha:$amountKoha: accountlinesKoha:" . Dumper(@accountlinesKoha) . ":");

    my $patron = Koha::Patrons->find( $borrowernumberKoha );
    if ( $patron ) {
        my $pmPaymentPaypage = C4::Epayment::PmPaymentPaypage->new( { patron => $patron, amount_to_pay => $amountKoha, accountlinesIds => \@accountlinesKoha, paytype => 18 } );

        # verify online payment by calling the webservice to check the transaction status and, if paid, also 'pay' the accountlines in Koha
        my $lesenKassenzeichenInfoIstOk = 0;
        ( $error, $kohaPaymentId ) = $pmPaymentPaypage->checkOnlinePaymentStatusAndPayInKoha($cgi);

    } else {
        my $mess = "Error: No patron found having borrowernumber:$borrowernumberKoha:";
        $logger->error("opac-account-pay-pmpayment-notify.pl $mess");
        carp ("opac-account-pay-pmpayment-notify.pl " . $mess . "\n");
    }

    $logger->debug("opac-account-pay-pmpayment-notify.pl error:$error: kohaPaymentId:" . (defined($kohaPaymentId) ? $kohaPaymentId : 'undef') . ":");
    if ( $kohaPaymentId ) {
        $logger->debug("opac-account-pay-pmpayment-notify.pl It seems that the external online payment and the Koha-payment have succeeded!");
        $httpResponseStatus = '200 OK';    # return statuscode '200 OK'
    } else {
        $logger->debug("opac-account-pay-pmpayment-notify.pl It seems that the external online payment or the Koha-payment has NOT succeeded!");
        $httpResponseStatus = '400 Bad Request';    # return statuscode '400 Bad Request'
    }
    $logger->debug("opac-account-pay-pmpayment-notify.pl returns cgi with httpResponseStatus:" . $httpResponseStatus . ":");

    print $cgi->header( -status => $httpResponseStatus,
                        -charset => 'utf-8',
                      );
}
