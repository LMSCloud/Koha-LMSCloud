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
use C4::Epayment::EPayBLPaypage;


my $error = 0;
my $errorTemplate = 'EPAYBL_ERROR_PROCESSING';
my $redirectUrl = "/cgi-bin/koha/errors/404.pl";
my $cgi = new CGI;

my $logger = Koha::Logger->get({ interface => 'epayment' });    # logger common to all e-payment methods
$logger->debug("opac-account-pay-epaypl-return.pl START cgi:" . Dumper($cgi) . ":");

if ( C4::Context->preference('EpayblPaypageOpacPaymentsEnabled') ) {

    # some params set by Koha in opac-account-pay.pl and EPayBLPaypage.pm
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $result = $cgi->param('result');

    # params set by ePayBL: none!


    if ( $result ) {
        if ( $result eq 'cancelled' ) {
            $errorTemplate = 'EPAYBL_ABORTED_BY_USER';

        } else {
            $logger->debug("opac-account-pay-epaypl-return.pl creating new C4::Epayment::EPayBLPaypage object. borrowernumberKoha:$borrowernumberKoha: amountKoha:$amountKoha: accountlinesKoha:" . Dumper(@accountlinesKoha) . ":");

            my $patron = Koha::Patrons->find( $borrowernumberKoha );
            if ( $patron ) {
                my $ePayBLPaypage = C4::Epayment::EPayBLPaypage->new( { patron => $patron, amount_to_pay => $amountKoha, accountlinesIds => \@accountlinesKoha, paytype => 19 } );

                # verify payment by calling the webservice 'lesenKassenzeichenInfo' and 'pay' the accountlines in Koha
                my $lesenKassenzeichenInfoIstOk = 0;
                ( $error, $errorTemplate, $lesenKassenzeichenInfoIstOk ) = $ePayBLPaypage->lesenKassenzeichenInfo($cgi);
            } else {
                my $mess = "Error: No patron found having borrowernumber:$borrowernumberKoha:";
                $logger->error("opac-account-pay-epaypl-return.pl $mess");
                carp ("opac-account-pay-epaypl-return.pl " . $mess . "\n");
            }
        }
    }

    $redirectUrl = "/cgi-bin/koha/opac-account.pl?payment=$amountKoha&payment-error=$errorTemplate";
}

$logger->debug("opac-account-pay-epaybl-return.pl END error:$error: errorTemplate:$errorTemplate: redirectUrl:$redirectUrl:");
print $cgi->redirect($redirectUrl);
