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
use Digest;
use CGI::Carp;
use SOAP::Lite;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use C4::Auth;
use C4::Output;
use C4::Accounts;
use C4::Context;
use C4::CashRegisterManagement;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Patrons;

my $key = 'dsTFshg5678DGHMO';    # dummy for wrong HMAC md5sum
sub genHmacMd5 {
    my ($key, $str) = @_;
    my $hmac_md5 = Digest->HMAC_MD5($key);
    $hmac_md5->add($str);
    my $hashval = $hmac_md5->hexdigest();

    return $hashval;
}

my $cgi = new CGI;

if ( C4::Context->preference('Epay21PaypageOpacPaymentsEnabled') ) {

    # params set by Koha in opac-account-pay.pl
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $paytypeKoha = $cgi->param('paytypeKoha');
    my $timeKoha = $cgi->param('timeKoha');

    # params set by epay21: none!


    # Signal that the payment action has been aborted by user, by calling ConfirmPayment with ActionType 'cancel'.
    # In order to do this we have to search the PayID (by ) first.
    my $error = "EPAY21_ABORTED_BY_USER";
    my $epay21msg = '';
    my $paytype = 17;    # just a dummy

    # overwriting SOAP::Transport::HTTP::Client::get_basic_credentials for substituting our customized credentials
    sub SOAP::Transport::HTTP::Client::get_basic_credentials {
        # credentials for basic authentication
        my $basicAuth_User = C4::Context->preference('Epay21BasicAuthUser');    # mandatory
        my $basicAuth_Pw = C4::Context->preference('Epay21BasicAuthPw');    # mandatory

        return $basicAuth_User => $basicAuth_Pw;
    }

    # notify ePay21 of abort of payment by user
    # 1st step: Search ePay21 paypage payment having CallerPayID
    my $epay21WebserviceUrl = C4::Context->preference('Epay21PaypageWebservicesURL');    # test env: https://epay-qs.ekom21.de/epay21/service/v11/ePay21Service.asmx   production env: 
    my $epay21WebserviceUrl_ns = 'http://epay21.ekom21.de/service/v11';

    # creating a Hmac Md5 hashvalue as unique id for CallerPayID / SearchKey
    my $basicAuth_Pw = C4::Context->preference('Epay21BasicAuthPw');
    $key = 'yK§' . $basicAuth_Pw . '89%3fhcR';
    my $now = DateTime->now( time_zone => C4::Context->tz() );
    my $todayMDY = $now->mdy;
    my $todayDMY = $now->dmy;
    my $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumberKoha . $paytypeKoha . '_' . $amountKoha . '_' . $paytypeKoha . $borrowernumberKoha . $key . $todayDMY . $key . $todayMDY . $timeKoha;
    my $merchantTxIdVal = $borrowernumberKoha . '_' . $amountKoha;
    foreach my $accountline (@accountlinesKoha) {
        $merchantTxIdVal .= '_' . $accountline;
    }
    $merchantTxIdVal .= '_' . $paytype;
    $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;

    my $merchantTxId = genHmacMd5($merchantTxIdKey, $merchantTxIdVal);         # unique merchant transaction ID


    # GetPaymentStatus OP parameters
    my $getPayStat_OP_Mandant = C4::Context->preference('Epay21Mandant');    # mandatory
    my $getPayStat_OP_MandantDesc = C4::Context->preference('Epay21MandantDesc');    # will be displayed on paypage
    my $getPayStat_OP_App = C4::Context->preference('Epay21App');    # mandatory
    my $getPayStat_OP_LocaleCode = 'DE_DE';
    my $getPayStat_OP_ClientInfo = C4::Context->preference('Epay21Mandant') . '_' . C4::Context->preference('Epay21App');
    #my $getPayStat_OP_PageURL = '';    # XXXWH perhaps to be adapted
    #my $getPayStat_OP_PageReferrerURL = '';    # XXXWH perhaps to be adapted

    # GetPaymentStatus Query parameters 
    my $getPayStat_Query_SearchKey = $merchantTxId;    # mandatory, unique Identifier des Falles im Fachverfahren
    my $getPayStat_Query_SearchMode =  'normal';    # mandatory


    my $getPaymentStatus_OP = SOAP::Data->name('OP' => \SOAP::Data->value(
        SOAP::Data->name('Mandant' => $getPayStat_OP_Mandant)->type('string'),
        SOAP::Data->name('MandantDesc' => $getPayStat_OP_MandantDesc)->type('string'),
        SOAP::Data->name('App' => $getPayStat_OP_App)->type('string'),
        SOAP::Data->name('LocaleCode' => $getPayStat_OP_LocaleCode),
        SOAP::Data->name('ClientInfo' => $getPayStat_OP_ClientInfo),
        #SOAP::Data->name('PageURL' => $getPayStat_OP_PageURL,
        #SOAP::Data->name('PageReferrerURL' => $getPayStat_OP_PageReferrerURL
    ));

    my $getPaymentStatus_Query = SOAP::Data->name('Query' => \SOAP::Data->value(
        SOAP::Data->name('SearchKey' => $getPayStat_Query_SearchKey),
        SOAP::Data->name('SearchMode' => $getPayStat_Query_SearchMode),
    ));

    # call the webservice
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    use IO::Socket::SSL;
    #$IO::Socket::SSL::DEBUG = 3;

    my $soap_request = SOAP::Lite->new( proxy => $epay21WebserviceUrl);
    $soap_request->default_ns($epay21WebserviceUrl_ns);
    $soap_request->serializer->readable(1);

    # SOAP::Lite generates $epay21WebserviceUrl_ns#InitPayment by default,
    # but .NET requires    $epay21WebserviceUrl_ns/InitPayment  - so we have to counteract:
    $soap_request->on_action( sub { join '/', @_ } );

    my $kohaPaymentId;
    # read payID by SearchKey == CallerPayID
    my $paymentStatus = 'undef';
    my $paymentType = '';
    my $paymentPayID = '';
    my $starttime = time();

    my $response = eval {
        $soap_request->GetPaymentStatus( $getPaymentStatus_OP, $getPaymentStatus_Query );
    };
    if ( $@ ) {
        $epay21msg = "error when calling soap_request->GetPaymentStatus:$@:";
    }


    if ($response ) {
        if ( !$response->fault() ) {
            if (    $response->result()
                 && $response->result()->{Operation}
                 && $response->result()->{Operation}->{Result} )
            {
                my $resultOperation = $response->result()->{Operation};
                my $resultOperationResult = $resultOperation->{Result};
                if ( $resultOperationResult->{'OK'} eq 'true' ) {
                    if ( $response->result()->{Payment} ) {
                        $paymentStatus = $response->result()->{Payment}->{Status};
                        $paymentType = $response->result()->{Payment}->{Type};
                        $paymentPayID = $response->result()->{Payment}->{PayID};
                    } else {
                        $paymentStatus = '';
                        $paymentType = '';
                        $paymentPayID = '';
                    }
                }
            }
        } else {
            $epay21msg = "error when calling soap_request->GetPaymentStatus:" . $response->fault() . ":";
        }
    }

    if ( length($paymentPayID) ) {

        # 2nd step: Confirm status for payment having CallerPayID / PayID
        # ConfirmPayment Query parameters 
        my $confirmPay_Query_PayID = $paymentPayID;    # mandatory, unique Identifier des Falles im Fachverfahren 
        my $confirmPay_Query_Action = 'cancel';    # mandatory

        my $confirmPayment_OP =  $getPaymentStatus_OP;
        my $confirmPayment_Query = SOAP::Data->name('Query' => \SOAP::Data->value(
            SOAP::Data->name('PayID' => $confirmPay_Query_PayID),
            SOAP::Data->name('Action' => $confirmPay_Query_Action),
        ));

        my $response = eval {
            $soap_request->ConfirmPayment( $confirmPayment_OP, $confirmPayment_Query );
        };
        if ( $@ ) {
            $epay21msg = "error when calling soap_request->ConfirmPayment:$@:";
        }


        if ($response ) {
            if ( !$response->fault() ) {
                if (    $response->result()
                     && $response->result()->{Operation}
                     && $response->result()->{Operation}->{Result} )
                {
                    my $resultOperation = $response->result()->{Operation};
                    my $resultOperationResult = $resultOperation->{Result};
                    if ( $resultOperationResult->{'OK'} eq 'true' ) {
                        if ( $response->result()->{Payment} ) {
                            my $paymentStatus = $response->result()->{Payment}->{Status};
                            my $paymentType = $response->result()->{Payment}->{Type};
                            my $paymentPayID = $response->result()->{Payment}->{PayID};
                        }
                    }
                }
            } else {
                $epay21msg = "error when calling soap_request->ConfirmPayment:" . $response->fault() . ":";
            }
        }
    }


    my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => "opac-account-pay-cancelled.tt",    # name of non existing tt-file is sufficient
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

    if ( $epay21msg ) {
        my $mess = "opac-account-pay-epay21-cancelled.pl epay21msg:" . $epay21msg . ":";
        carp $mess . "\n";
    }

    print $cgi->redirect("/cgi-bin/koha/opac-account.pl?payment=$amountKoha&payment-error=$error");
} else {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
}
