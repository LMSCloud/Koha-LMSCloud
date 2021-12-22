#!/usr/bin/perl

# Copyright ByWater Solutions 2015
# parts Copyright 2019-2021 (C) LMSCLoud GmbH
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

use C4::Auth;
use C4::Output;
use C4::Context;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Plugins::Handler;
use Koha::Patrons;
use C4::Epayment::GiroSolution;
use C4::Epayment::Epay21;
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
         C4::Context->preference('GirosolutionPaypageOpacPaymentsEnabled') ||
         C4::Context->preference('Epay21PaypageOpacPaymentsEnabled') ||
         C4::Context->preference('PmPaymentPaypageOpacPaymentsEnabled') ||
         C4::Context->preference('EpayblPaypageOpacPaymentsEnabled') ||
         $use_plugin ) {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
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

    # init payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, redirect to the GiroSolution Creditcard URL delivered in its response
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


elsif ( $payment_method eq 'gs_paypage' && C4::Context->preference('GirosolutionPaypageOpacPaymentsEnabled') ) {    # Girosolution Paypage

    $logger->debug("opac-account-pay.pl/girosolution_paypage START creating new C4::Epayment::GiroSolution object. cardnumber:" . $patron->cardnumber() . ": amount_to_pay:" . $amount_to_pay . ":");

    my $errorTemplate = 'GIROSOLUTION_ERROR_PROCESSING';
    my $girosolutionRedirectToPaypageUrl = '';

    # init payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, redirect to the GiroSolution Paypage URL delivered in its response
    my $girosolutionPaypage = C4::Epayment::GiroSolution->new( { patron => $patron, amount_to_pay => $amount_to_pay, accountlinesIds => \@accountlines, paytype => 1001 } );    # paytype 1001: fictional, used to indicate paypage payment)
    ( $error, $errorTemplate, $girosolutionRedirectToPaypageUrl ) = $girosolutionPaypage->paymentAction();

    if ( $error || $errorTemplate ) {
        $logger->error("opac-account-pay.pl/girosolution_paypage END error:$error: errorTemplate:$errorTemplate:");
        if ( $errorTemplate ) {
            $template->param( error => $errorTemplate );
        }
    } else {
        $logger->debug("opac-account-pay.pl/girosolution_paypage END error:$error: errorTemplate:$errorTemplate: girosolutionRedirectToPaypageUrl:$girosolutionRedirectToPaypageUrl:");

        if ( $girosolutionRedirectToPaypageUrl ) {
            print $cgi->redirect( $girosolutionRedirectToPaypageUrl );
        }
    }
    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } ) if $error;
}


elsif ( $payment_method eq 'epay21_paypage' && C4::Context->preference('Epay21PaypageOpacPaymentsEnabled') ) {    # epay21 Paypage

    $logger->debug("opac-account-pay.pl/epay21_paypage START creating new C4::Epayment::Epay21 object. cardnumber:" . $patron->cardnumber() . ": amount_to_pay:" . $amount_to_pay . ":");

    my $errorTemplate = 'EPAY21_ERROR_PROCESSING';
    my $epay21RedirectToPaypageUrl = '';

    # init payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, redirect to the epay21 paypage URL delivered in its response
    my $epay21Paypage = C4::Epayment::Epay21->new( { patron => $patron, amount_to_pay => $amount_to_pay, accountlinesIds => \@accountlines, paytype => 17, seconds => time() } );
    ( $error, $errorTemplate, $epay21RedirectToPaypageUrl ) = $epay21Paypage->paymentAction();

    if ( $error || $errorTemplate ) {
        $logger->error("opac-account-pay.pl/epay21_paypage END error:$error: errorTemplate:$errorTemplate:");
        if ( $errorTemplate ) {
            $template->param( error => $errorTemplate );
        }
    } else {
        $logger->debug("opac-account-pay.pl/epay21_paypage END error:$error: errorTemplate:$errorTemplate: epay21RedirectToPaypageUrl:$epay21RedirectToPaypageUrl:");

        if ( $epay21RedirectToPaypageUrl ) {
            print $cgi->redirect( $epay21RedirectToPaypageUrl );
        }
    }

    output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } ) if $error;
}


elsif ( $payment_method eq 'pmpayment_paypage' && C4::Context->preference('PmPaymentPaypageOpacPaymentsEnabled') ) {    # pmPayment paypage

    $logger->debug("opac-account-pay.pl/pmpayment_paypage START creating new C4::Epayment::PmPaymentPaypage object. cardnumber:" . $patron->cardnumber() . ": amount_to_pay:" . $amount_to_pay . ":");

    my $errorTemplate = 'PMPAYMENT_ERROR_PROCESSING';
    my $pmpaymentRedirectToPaypageUrl = '';

    # init payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, redirect to the pmPayment paypage URL delivered in its response
    my $pmPaymentPaypage = C4::Epayment::PmPaymentPaypage->new( { patron => $patron, amount_to_pay => $amount_to_pay, accountlinesIds => \@accountlines, paytype => 18 } );
    ( $error, $errorTemplate, $pmpaymentRedirectToPaypageUrl ) = $pmPaymentPaypage->paymentAction();

    if ( $error || $errorTemplate ) {
        $logger->error("opac-account-pay.pl/pmpayment_paypage END error:$error: errorTemplate:$errorTemplate:");
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
