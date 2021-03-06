#!/usr/bin/perl

# Copyright ByWater Solutions 2015
# parts Copyright 2019-2020 (C) LMSCLoud GmbH
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
use Data::Dumper;

use CGI;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI;
use Digest;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use JSON;
use Encode;
use CGI::Carp;
use SOAP::Lite;

use C4::Auth;
use C4::Output;
use C4::Context;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Plugins::Handler;
use Koha::Patrons;
use C4::Epayment::GiroSolution;
use C4::Epayment::PmPaymentPaypage;
use C4::Epayment::EPayBLPaypage;

my $cgi = new CGI;
my $payment_method = $cgi->param('payment_method');
my @accountlines   = $cgi->multi_param('accountline');

my $use_plugin;
if ( $payment_method ne 'paypal' &&
     $payment_method ne 'gs_giropay' &&
     $payment_method ne 'gs_creditcard' &&
     $payment_method ne 'epay21_paypage' &&
     $payment_method ne 'pmpayment_paypage' ) {
    $use_plugin = Koha::Plugins::Handler->run(
        {
            class  => $payment_method,
            method => 'opac_online_payment',
            cgi    => $cgi,
        }
    );
}

unless ( C4::Context->preference('EnablePayPalOpacPayments') ||
         C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled') ||
         C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled') ||
         C4::Context->preference('Epay21PaypageOpacPaymentsEnabled') ||
         C4::Context->preference('PmPaymentPaypageOpacPaymentsEnabled') ||
         C4::Context->preference('EpayblPaypageOpacPaymentsEnabled') ||
         $use_plugin ) {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $key = 'dsTFshg5678DGHMO';    # dummy for wrong HMAC digest
sub genHmacMd5 {
    my ($key, $str) = @_;
    my $hmac_md5 = Digest->HMAC_MD5($key);
    $hmac_md5->add($str);
    my $hashval = $hmac_md5->hexdigest();

    return $hashval;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-account-pay-error.tt",
        query           => $cgi,
        type            => "opac",
        authnotrequired => 0,
        debug           => 1,
    }
);

my $logger = Koha::Logger->get({ interface => 'epayment' });    # logger common to all e-payment methods
$logger->debug("opac-account-pay.pl: START payment_method:$payment_method: borrowernumber:$borrowernumber: accountlines:" . Dumper(@accountlines) . ":");

# get borrower information
my $patron = Koha::Patrons->find( $borrowernumber );

my $amount_to_pay =
  Koha::Database->new()->schema()->resultset('Accountline')->search( { accountlines_id => { -in => \@accountlines } } )
  ->get_column('amountoutstanding')->sum();
$amount_to_pay = sprintf( "%.2f", $amount_to_pay );

my $active_currency = Koha::Acquisition::Currencies->get_active;

my $error = 0;
if ( $payment_method eq 'paypal' && C4::Context->preference('EnablePayPalOpacPayments') ) {
    my $ua = LWP::UserAgent->new;

    my $url =
      C4::Context->preference('PayPalSandboxMode')
      ? 'https://api-3t.sandbox.paypal.com/nvp'
      : 'https://api-3t.paypal.com/nvp';

    my $opac_base_url = C4::Context->preference('OPACBaseURL');

    my $return_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account-pay-paypal-return.pl" );
    $return_url->query_form( { amount => $amount_to_pay, accountlines => \@accountlines } );

    my $cancel_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account.pl" );

    my $nvp_params = {
        'USER'      => C4::Context->preference('PayPalUser'),
        'PWD'       => C4::Context->preference('PayPalPwd'),
        'SIGNATURE' => C4::Context->preference('PayPalSignature'),

        # API Version and Operation
        'METHOD'  => 'SetExpressCheckout',
        'VERSION' => '82.0',

        # API specifics for SetExpressCheckout
        'NOSHIPPING'                            => 1,
        'REQCONFIRMSHIPPING'                    => 0,
        'ALLOWNOTE'                             => 0,
        'BRANDNAME'                             => C4::Context->preference('LibraryName'),
        'CANCELURL'                             => $cancel_url->as_string(),
        'RETURNURL'                             => $return_url->as_string(),
        'PAYMENTREQUEST_0_CURRENCYCODE'         => $active_currency->currency,
        'PAYMENTREQUEST_0_AMT'                  => $amount_to_pay,
        'PAYMENTREQUEST_0_PAYMENTACTION'        => 'Sale',
        'PAYMENTREQUEST_0_ALLOWEDPAYMENTMETHOD' => 'InstantPaymentOnly',
        'PAYMENTREQUEST_0_DESC'                 => C4::Context->preference('PayPalChargeDescription'),
        'SOLUTIONTYPE'                          => 'Sole',
    };

    my $response = $ua->request( POST $url, $nvp_params );

    if ( $response->is_success ) {

        my $urlencoded = $response->content;
        my %params = URI->new( "?$urlencoded" )->query_form;

        if ( $params{ACK} eq "Success" ) {
            my $token = $params{TOKEN};

            my $redirect_url =
              C4::Context->preference('PayPalSandboxMode')
              ? "https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token="
              : "https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=";
            print $cgi->redirect( $redirect_url . $token );

        }
        else {
            $template->param( error => "PAYPAL_ERROR_PROCESSING" );
            $error = 1;
        }

    }
    else {
        $template->param( error => "PAYPAL_UNABLE_TO_CONNECT" );
        $error = 1;
    }

    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 }) if $error;
}


elsif ( $payment_method eq 'gs_giropay' && C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled') ) {    # Girosolution GiroPay

    $logger->debug("opac-account-pay.pl/girosolution_giropay START creating new C4::Epayment::GiroSolution object. cardnumber:" . $patron->cardnumber() . ": amount_to_pay:" . $amount_to_pay . ":");

    my $errorTemplate = 'GIROSOLUTION_ERROR_PROCESSING';
    my $girosolutionRedirectToGiropayUrl = '';

    # init payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, redirect to the GiroSolution GiroPay URL delivered in its response
    my $girosolutionGiropay = C4::Epayment::GiroSolution->new( { patron => $patron, amount_to_pay => $amount_to_pay, accountlinesIds => \@accountlines, paytype => 1 } );
    ( $error, $errorTemplate, $girosolutionRedirectToGiropayUrl ) = $girosolutionGiropay->paymentAction();

    if ( $error || $errorTemplate ) {
        $logger->error("opac-account-pay.pl/girosolution_giropay END error:$error: errorTemplate:$errorTemplate:");
        if ( $errorTemplate ) {
            $template->param( error => $errorTemplate );
        }
    } else {
        $logger->debug("opac-account-pay.pl/girosolution_giropay END error:$error: errorTemplate:$errorTemplate: girosolutionRedirectToGiropayUrl:$girosolutionRedirectToGiropayUrl:");

        if ( $girosolutionRedirectToGiropayUrl ) {
            print $cgi->redirect( $girosolutionRedirectToGiropayUrl );
        }
    }
    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } ) if $error;
}


elsif ( $payment_method eq 'gs_creditcard' && C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled') ) {    # Girosolution Credit Card

    $logger->debug("opac-account-pay.pl/girosolution_creditcard START creating new C4::Epayment::GiroSolution object. cardnumber:" . $patron->cardnumber() . ": amount_to_pay:" . $amount_to_pay . ":");

    my $errorTemplate = 'GIROSOLUTION_ERROR_PROCESSING';
    my $girosolutionRedirectToCreditcardUrl = '';

    # init payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, redirect to the GiroSolution GiroPay URL delivered in its response
    my $girosolutionCreditcard = C4::Epayment::GiroSolution->new( { patron => $patron, amount_to_pay => $amount_to_pay, accountlinesIds => \@accountlines, paytype => 11 } );
    ( $error, $errorTemplate, $girosolutionRedirectToCreditcardUrl ) = $girosolutionCreditcard->paymentAction();

    if ( $error || $errorTemplate ) {
        $logger->error("opac-account-pay.pl/girosolution_creditcard END error:$error: errorTemplate:$errorTemplate:");
        if ( $errorTemplate ) {
            $template->param( error => $errorTemplate );
        }
    } else {
        $logger->debug("opac-account-pay.pl/girosolution_creditcard END error:$error: errorTemplate:$errorTemplate: girosolutionRedirectToCreditcardUrl:$girosolutionRedirectToCreditcardUrl:");

        if ( $girosolutionRedirectToCreditcardUrl ) {
            print $cgi->redirect( $girosolutionRedirectToCreditcardUrl );
        }
    }
    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } ) if $error;
}


elsif ( $payment_method eq 'epay21_paypage' && C4::Context->preference('Epay21PaypageOpacPaymentsEnabled') ) {    # ePay21 Paypage
    my $paytype = 17;    # just a dummy; may be interpreted as payment via epay21 paypage
    my $seconds = time();    # make payment trials for same accountline distinguishable

    # overwriting SOAP::Transport::HTTP::Client::get_basic_credentials for substituting our customized credentials
    sub SOAP::Transport::HTTP::Client::get_basic_credentials {
        # credentials for basic authentication
        my $basicAuth_User = C4::Context->preference('Epay21BasicAuthUser');    # mandatory
        my $basicAuth_Pw = C4::Context->preference('Epay21BasicAuthPw');    # mandatory

        return $basicAuth_User => $basicAuth_Pw;
    }

    # Initialisierung einer ePay21 paypage Zahlung
    my $epay21WebserviceUrl = C4::Context->preference('Epay21PaypageWebservicesURL');    # test env: https://epay-qs.ekom21.de/epay21/service/v11/ePay21Service.asmx   production env: https://epay.ekom21.de/epay21/service/v11/ePay21Service.asmx
    my $epay21WebserviceUrl_ns = 'http://epay21.ekom21.de/service/v11';

    my $opac_base_url = C4::Context->preference('OPACBaseURL');    # the ePay21 software seems to work only with https URL (not with http)

    my $return_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account-pay-epay21-return.pl" );    # return_url is used to update accountlines corresponding to the payment
    $return_url->query_form( { amountKoha => $amount_to_pay, accountlinesKoha => \@accountlines, borrowernumberKoha => $borrowernumber, paytypeKoha => $paytype, timeKoha => $seconds } );    # a la girosolutions

    my $cancel_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account-pay-epay21-cancelled.pl" );    # cancel_url is used to send info to epay21 that user has aborted the payment action
    $cancel_url->query_form( { amountKoha => $amount_to_pay, accountlinesKoha => \@accountlines, borrowernumberKoha => $borrowernumber, paytypeKoha => $paytype, timeKoha => $seconds } );    # a la $return_url

    # creating a Hmac Md5 hashvalue as unique id for CallerPayID
    my $basicAuth_Pw = C4::Context->preference('Epay21BasicAuthPw');
    $key = 'yK§' . $basicAuth_Pw . '89%3fhcR';
    my $now = DateTime->now( time_zone => C4::Context->tz() );
    my $todayMDY = $now->mdy;
    my $todayDMY = $now->dmy;
    my $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumber . $paytype . '_' . $amount_to_pay . '_' . $paytype . $borrowernumber . $key . $todayDMY . $key . $todayMDY . $seconds;
    my $merchantTxIdVal = $borrowernumber . '_' . $amount_to_pay;
    foreach my $accountline (@accountlines) {
        $merchantTxIdVal .= '_' . $accountline;
    }
    $merchantTxIdVal .= '_' . $paytype;
    $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;

    my $merchantTxId = genHmacMd5($merchantTxIdKey, $merchantTxIdVal);         # unique merchant transaction ID (this MD5 sum is used to check integrity of Koha CGI parameters in opac-account-pay-epay21-return.pl)

    # InitPayment OP parameters
    my $iniPay_OP_Mandant = C4::Context->preference('Epay21Mandant');    # mandatory
    my $iniPay_OP_MandantDesc = C4::Context->preference('Epay21MandantDesc');    # will be displayed on paypage
    my $iniPay_OP_App = C4::Context->preference('Epay21App');    # mandatory
    my $iniPay_OP_LocaleCode = 'DE_DE';
    my $iniPay_OP_ClientInfo = C4::Context->preference('Epay21Mandant') . '_' . C4::Context->preference('Epay21App');
    #my $iniPay_OP_PageURL = '';    # not required
    #my $iniPay_OP_PageReferrerURL = '';    # not required

    # InitPayment Query parameters
    my $epay21AccountingSystemInfo = C4::Context->preference('Epay21AccountingSystemInfo');
    if ( !defined($epay21AccountingSystemInfo) ) {
        $epay21AccountingSystemInfo = '';
    }
    my $iniPay_Query_CallerPayID = $merchantTxId;    # mandatory, unique Identifier des Falles im Fachverfahren
    my $iniPay_Query_Purpose = substr($patron->cardnumber() . ' ' . $epay21AccountingSystemInfo, 0, 27);   # With multibyte-characters a wrong hashval is calculated. This field accepts only characters conforming to SEPA ( i.e.: a-z A-Z 0-9 ' : ? , - ( + . ) /  );
    my $iniPay_Query_OrderDesc = C4::Context->preference('Epay21OrderDesc');    # will be displayed on paypage
    #my $iniPay_Query_OrderInfos = 'Auch dieser Text kann auf der PayPage angezeigt werden';    # wei 12.12.19: do not use to avoid confusion
    my $iniPay_Query_Amount = $amount_to_pay * 100;      # not Euro but Cent are required; 1,23 EUR => 123 Cent
    my $iniPay_Query_Currency = 'EUR';    # mandatory if Art=online
    my $iniPay_Query_ReturnURL = $return_url->as_string();    # mandatory
    my $iniPay_Query_CancelURL = $cancel_url->as_string();    # mandatory
    my $iniPay_Query_Art = 'online';    # mandatory
    my $iniPay_Query_GetQrCode = 'false';    # mandatory
    my $iniPay_Query_PaymentTimeout = 15;    # duration of validity of paypage: 15 minutes
#    my $iniPay_Query_ReferenceID = 'ReferenceID000002';    # mandatory if Art=invoice, not required if Art=online
#    my $iniPay_Query_ReferencePIN = 'ReferencePin000002';    # mandatory if Art=invoice, not required if Art=online
#    my $hashval = md5_hex($iniPay_Query_CallerPayID . $iniPay_Query_ReferenceID . $iniPay_Query_ReferencePIN);
#    my $iniPay_Query_CallerCode = SOAP::Data->name('CallerCode'  => $hashval);    # mandatory if Art=invoice, not required if Art=online

    my $InitPayment_OP = SOAP::Data->name('OP' => \SOAP::Data->value(
        SOAP::Data->name('Mandant' => $iniPay_OP_Mandant)->type('string'),
        SOAP::Data->name('MandantDesc' => $iniPay_OP_MandantDesc)->type('string'),
        SOAP::Data->name('App' => $iniPay_OP_App)->type('string'),
        SOAP::Data->name('LocaleCode' => $iniPay_OP_LocaleCode),
        SOAP::Data->name('ClientInfo' => $iniPay_OP_ClientInfo),
        #SOAP::Data->name('PageURL' => $iniPay_OP_PageURL,
        #SOAP::Data->name('PageReferrerURL' => $iniPay_OP_PageReferrerURL
    ));

    my $InitPayment_Query = SOAP::Data->name('Query' => \SOAP::Data->value(
        SOAP::Data->name('CallerPayID' => $iniPay_Query_CallerPayID),
        SOAP::Data->name('Purpose' => $iniPay_Query_Purpose)->type('string'),
        SOAP::Data->name('OrderDesc' => $iniPay_Query_OrderDesc)->type('string'),
        #SOAP::Data->name('OrderInfos' => $iniPay_Query_OrderInfos),    # wei 12.12.19: do not use to avoid confusion
        SOAP::Data->name('Amount' => $iniPay_Query_Amount),
        SOAP::Data->name('Currency' => $iniPay_Query_Currency),
        SOAP::Data->name('ReturnURL' => $iniPay_Query_ReturnURL),
        SOAP::Data->name('CancelURL' => $iniPay_Query_CancelURL),
        SOAP::Data->name('Art' => $iniPay_Query_Art),
        SOAP::Data->name('GetQrCode' => $iniPay_Query_GetQrCode),
        SOAP::Data->name('PaymentTimeout' => $iniPay_Query_PaymentTimeout)
#        SOAP::Data->name('ReferenceID' => $iniPay_Query_ReferenceID),    # mandatory if Art=invoice, not required if Art=online
#        SOAP::Data->name('ReferencePIN' => $iniPay_Query_ReferencePIN),    # mandatory if Art=invoice, not required if Art=online
#        SOAP::Data->name('CallerCode' => $iniPay_Query_CallerCode)    # mandatory if Art=invoice, not required if Art=online
    ));

    # call the webservice
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    use IO::Socket::SSL;
    #$IO::Socket::SSL::DEBUG = 3;

    my $soap_request = SOAP::Lite->new( proxy => $epay21WebserviceUrl);
    $soap_request->default_ns($epay21WebserviceUrl_ns);
    $soap_request->serializer->readable(1);

    # SOAP::Lite generates $epay21WebserviceUrl_ns#InitPayment by default,
    # but MS .NET requires $epay21WebserviceUrl_ns/InitPayment  - so we have to counteract:
    $soap_request->on_action( sub { join '/', @_ } );

    my $response = eval {
        $soap_request->InitPayment( $InitPayment_OP, $InitPayment_Query );
    };
    if ( $@ ) {
        my $mess = "opac-account-pay.pl/epay21_paypage error when calling soap_request->InitPayment:$@:";
        carp $mess . "\n";
        $template->param( error => "EPAY21_ERROR_PROCESSING" );
        $error = 1;
    }


    if ($response ) {
        my $epay21msg = '';
        if ( !$response->fault() ) {
            my $redirectedToPaypage = 0;
            if (    $response->result()
                 && $response->result()->{Operation}
                 && $response->result()->{Operation}->{Result} )
            {
                my $resultOperation = $response->result()->{Operation};
                my $resultOperationResult = $resultOperation->{Result};
                if ( $resultOperationResult->{'OK'} eq 'true' ) {
                    if ( $response->result()->{PayPageInfo} ) {
                        my $payPageUrl = $response->result()->{PayPageInfo}->{PayPageUrl};
                        print $cgi->redirect( $payPageUrl );
                        $redirectedToPaypage = 1;
                    }
                }
                if ( $resultOperationResult->{'OK'} ne 'true' ) {
                    $epay21msg = $resultOperationResult->{'ErrorMessage'} . ' (' . $resultOperationResult->{'ErrorMessageDetail'} . ')';
                }
            }

            if ( $redirectedToPaypage == 0 ) {
                $template->param( error => "EPAY21_ERROR_PROCESSING" );
                $error = 1;
            }
        }    # End of: !$response->fault()
        else {
            $epay21msg = $response->fault();
            $template->param( error => "EPAY21_UNABLE_TO_CONNECT" );
            $error = 1;
        }
        if ( $epay21msg ) {
            my $mess = "opac-account-pay.pl/epay21_paypage epay21msg:" . $epay21msg . ":";
            carp $mess . "\n";
        }
    }

    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 }) if $error;
}


elsif ( $payment_method eq 'pmpayment_paypage' && C4::Context->preference('PmPaymentPaypageOpacPaymentsEnabled') ) {    # pmPayment paypage

    $logger->debug("opac-account-pay.pl/pmpayment_paypage START creating new C4::Epayment::PmPaymentPaypage object. cardnumber:" . $patron->cardnumber() . ": amount_to_pay:" . $amount_to_pay . ":");

    my $errorTemplate = 'PMPAYMENT_ERROR_PROCESSING';
    my $pmpaymentRedirectToPaypageUrl = '';

    # init payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, redirect to the pmPayment paypage URL delivered in its response
    my $pmPaymentPaypage = C4::Epayment::PmPaymentPaypage->new( { patron => $patron, amount_to_pay => $amount_to_pay, accountlinesIds => \@accountlines, paytype => 18 } );
    ( $error, $errorTemplate, $pmpaymentRedirectToPaypageUrl ) = $pmPaymentPaypage->paymentAction();

    if ( $error || $errorTemplate ) {
        $logger->error("opac-account-pay.pl/epaybl_paypage END error:$error: errorTemplate:$errorTemplate:");
        if ( $errorTemplate ) {
            $template->param( error => $errorTemplate );
        }
    } else {
        $logger->debug("opac-account-pay.pl/pmpayment_paypage END error:$error: errorTemplate:$errorTemplate: pmpaymentRedirectToPaypageUrl:$pmpaymentRedirectToPaypageUrl:");

        if ( $pmpaymentRedirectToPaypageUrl ) {
            print $cgi->redirect( $pmpaymentRedirectToPaypageUrl );
        }
    }

    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } ) if $error;
}


elsif ( $payment_method eq 'epaybl_paypage' && C4::Context->preference('EpayblPaypageOpacPaymentsEnabled') ) {    # pmPayment paypage

    $logger->debug("opac-account-pay.pl/epaybl_paypage START creating new C4::Epayment::EPayBLPaypage object. cardnumber:" . $patron->cardnumber() . ": amount_to_pay:" . $amount_to_pay . ":");

    my $errorTemplate = 'EPAYBL_ERROR_PROCESSING';
    my $epayblRedirectToPaypageUrl = '';

    # call the webservices 'isAlive', 'anlegenKunde', 'anlegenKassenzeichen', 'loeschenKunde' and then, if succeeded, redirect to ePayBL paypage URL
    my $ePayBLPaypage = C4::Epayment::EPayBLPaypage->new( { patron => $patron, amount_to_pay => $amount_to_pay, accountlinesIds => \@accountlines, paytype => 19 } );
    ( $error, $errorTemplate, $epayblRedirectToPaypageUrl ) = $ePayBLPaypage->paymentAction();

    if ( $error || $errorTemplate ) {
        $logger->error("opac-account-pay.pl/epaybl_paypage END error:$error: errorTemplate:$errorTemplate:");
        if ( $errorTemplate ) {
            $template->param( error => $errorTemplate );
        }
    } else {
        $logger->debug("opac-account-pay.pl/epaybl_paypage END error:$error: errorTemplate:$errorTemplate: epayblRedirectToPaypageUrl:$epayblRedirectToPaypageUrl:");

        if ( $epayblRedirectToPaypageUrl ) {
            print $cgi->redirect( $epayblRedirectToPaypageUrl );
        }
    }

    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } ) if $error;
}


else {
    Koha::Plugins::Handler->run(
        {
            class  => $payment_method,
            method => 'opac_online_payment_begin',
            cgi    => $cgi,
        }
    );
}
