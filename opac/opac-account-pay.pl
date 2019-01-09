#!/usr/bin/perl

# Copyright ByWater Solutions 2015
# parts Copyright 2019 (C) LMSCLoud GmbH
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

use utf8;

use Modern::Perl;

use CGI;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI;
use Digest;
use Data::Dumper;    # XXXWH
use JSON;
use Encode;

use C4::Auth;
use C4::Output;
use C4::Context;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Plugins::Handler;
use Koha::Patrons;

my $cgi = new CGI;
my $payment_method = $cgi->param('payment_method');
my @accountlines   = $cgi->multi_param('accountline');

my $use_plugin;
if ( $payment_method ne 'paypal' && $payment_method ne 'gs_giropay' && $payment_method ne 'gs_creditcard' ) {
    $use_plugin = Koha::Plugins::Handler->run(
        {
            class  => $payment_method,
            method => 'opac_online_payment',
            cgi    => $cgi,
        }
    );
}

unless ( C4::Context->preference('EnablePayPalOpacPayments') || C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled') || C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled') || $use_plugin ) {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}


my $key = 'dsTFshg5678DGHMO';    # dummy for wrong HMAC md5sum
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
# get borrower information
my $patron = Koha::Patrons->find( $borrowernumber );

my $amount_to_pay =
  Koha::Database->new()->schema()->resultset('Accountline')->search( { accountlines_id => { -in => \@accountlines } } )
  ->get_column('amountoutstanding')->sum();
$amount_to_pay = sprintf( "%.2f", $amount_to_pay );

my $active_currency = Koha::Acquisition::Currencies->get_active;

my $error = 0;
if ( $payment_method eq 'paypal' ) {
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

    output_html_with_http_headers( $cgi, $cookie, $template->output ) if $error;
}


elsif ( $payment_method eq 'gs_giropay' ) {    # Girosolution GiroPay

    my $paytype = 1;    # paytype 1: gs_giropay
    my $merchantId = C4::Context->preference('GirosolutionMerchantId');
    my $projectId = C4::Context->preference('GirosolutionGiropayProjectId');    # GiroSolution 'Project ID' for payment method GiroPay
    $key = C4::Context->preference('GirosolutionGiropayProjectPwd');    # password of GiroSolution project for payment method GiroPay

    my $ua = LWP::UserAgent->new;



    if ( $error == 0 ) {
        # Initialisierung einer giropay Zahlung
        my $url = 'https://payment.girosolution.de/girocheckout/api/v2/transaction/start';

        my $opac_base_url = C4::Context->preference('OPACBaseURL');    # the GiroSolution software seems to work only with https URL (not with http)

        my $message_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account-pay-girosolution-message.pl" );
        $message_url->query_form( { amountKoha => $amount_to_pay, accountlinesKoha => \@accountlines, borrowernumberKoha => $borrowernumber, paytypeKoha => $paytype } );

        my $redirect_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account-pay-girosolution-return.pl" );
        $redirect_url->query_form( { amountKoha => $amount_to_pay, accountlinesKoha => \@accountlines, borrowernumberKoha => $borrowernumber, paytypeKoha => $paytype } );

        my $now = DateTime->now( time_zone => C4::Context->tz() );
        my $todayMDY = $now->mdy;
        my $todayDMY = $now->dmy;
        my $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumber . $paytype . '_' . $amount_to_pay . '_' . $paytype . $borrowernumber . $key . $todayDMY . $key . $todayMDY;
        my $merchantTxIdVal = $borrowernumber . '_' . $amount_to_pay;
        foreach my $accountline (@accountlines) {
            $merchantTxIdVal .= '_' . $accountline;
        }
        $merchantTxIdVal .= '_' . $paytype;
        $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;

        my $merchantTxId = genHmacMd5($merchantTxIdKey, $merchantTxIdVal);         # unique merchant transaction ID (this MD5 sum is used to check integrity of Koha CGI parameters in opac-account-pay-girosolution-message.pl)
        my $amount = $amount_to_pay * 100;      # not Euro but Cent are required
        my $currency = 'EUR';
        my $purpose = substr('Bibliothek:' . $patron->cardnumber(), 0, 27);   # With multibyte-characters a wrong hashval is calculated. This field accepts only characters conforming to SEPA, i.e.: a-z A-Z 0-9 ' : ? , - ( + . ) / 

        my $urlRedirect = $redirect_url->as_string();

        my $urlNotify = $message_url->as_string();

print STDERR "opac-account-pay.pl merchantTxIdKey:$merchantTxIdKey:\n";
print STDERR "opac-account-pay.pl merchantTxIdVal:$merchantTxIdVal:\n";
print STDERR "opac-account-pay.pl merchantTxId:$merchantTxId:\n";

        my $paramstr = 
            $merchantId .
            $projectId .
            $merchantTxId .
            $amount .
            $currency .
            $purpose .
            $urlRedirect .
            $urlNotify;

        my $hashval = genHmacMd5($key, $paramstr);

        my $gs_params = {
            'merchantId' => $merchantId,
            'projectId'  => $projectId,
            'merchantTxId' => $merchantTxId,
            'amount' => $amount,
            'currency' => $currency,
            'purpose' => $purpose,
            'urlRedirect' => $urlRedirect,
            'urlNotify' => $urlNotify,
            'hash' => $hashval
        };

        my $response = $ua->request( POST $url, $gs_params );

print STDERR "opac-account-pay.pl transaction/start response:", Dumper($response), ":\n";

        if ( $response->is_success ) {
            my $responseHeaderHash = $response->headers->header('hash');
print STDERR "opac-account-pay.pl response responseHeaderHash:$responseHeaderHash:\n";
            my $content = Encode::decode("utf8", $response->content);
            my $compHash = genHmacMd5($key, $content);
print STDERR "opac-account-pay.pl response responseHeaderHash:$responseHeaderHash: 2. compHash:$compHash: eq:", $responseHeaderHash eq $compHash, ":\n";
            my $json = from_json( $content );
print STDERR "opac-account-pay.pl 2. response json:", Dumper($json), ":\n";
print STDERR "opac-account-pay.pl 2. response json->rc:", scalar $json->{rc}, ":\n";
print STDERR "opac-account-pay.pl 2. response json->msg:", scalar $json->{msg}, ":\n";
print STDERR "opac-account-pay.pl 2. response json->reference:", scalar $json->{reference}, ":\n";
print STDERR "opac-account-pay.pl 2. response json->redirect:", scalar $json->{redirect}, ":\n";

            if ( $responseHeaderHash eq $compHash && $json->{rc} eq '0' ) {
                $error = 0;
                my $gs_message_redirect_url = $json->{redirect};
                print $cgi->redirect( $gs_message_redirect_url );

            } else {
                $template->param( error => "GIROSOLUTION_ERROR_PROCESSING", girosolutionmsg => $json->{msg} );
                $error = 1;
            }

        }
        else {
            $template->param( error => "GIROSOLUTION_UNABLE_TO_CONNECT" );
            $error = 1;
        }
    }

    output_html_with_http_headers( $cgi, $cookie, $template->output ) if $error;
}


elsif ( $payment_method eq 'gs_creditcard' ) {    # Girosolution Credit Card

    my $paytype = 11;    # paytype 11: gs_creditcard
    my $merchantId = C4::Context->preference('GirosolutionMerchantId');
    my $projectId = C4::Context->preference('GirosolutionCreditcardProjectId');    # GiroSolution 'Project ID' for payment method CreditCard
    $key = C4::Context->preference('GirosolutionCreditcardProjectPwd');    # password of GiroSolution project for payment method CreditCard

    my $ua = LWP::UserAgent->new;

    if ( $error == 0 ) {
        # Initialisierung einer creditcard Zahlung
        my $url = 'https://payment.girosolution.de/girocheckout/api/v2/transaction/start';

        my $opac_base_url = C4::Context->preference('OPACBaseURL');    # the GiroSolution software seems to work only with https URL (not with http)

        my $message_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account-pay-girosolution-message.pl" );
        $message_url->query_form( { amountKoha => $amount_to_pay, accountlinesKoha => \@accountlines, borrowernumberKoha => $borrowernumber, paytypeKoha => $paytype } );

        my $redirect_url = URI->new( $opac_base_url . "/cgi-bin/koha/opac-account-pay-girosolution-return.pl" );
        $redirect_url->query_form( { amountKoha => $amount_to_pay, accountlinesKoha => \@accountlines, borrowernumberKoha => $borrowernumber, paytypeKoha => $paytype } );

        my $now = DateTime->now( time_zone => C4::Context->tz() );
        my $todayMDY = $now->mdy;
        my $todayDMY = $now->dmy;
        my $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumber . $paytype . '_' . $amount_to_pay . '_' . $paytype . $borrowernumber . $key . $todayDMY . $key . $todayMDY;
        my $merchantTxIdVal = $borrowernumber . '_' . $amount_to_pay;
        foreach my $accountline (@accountlines) {
            $merchantTxIdVal .= '_' . $accountline;
        }
        $merchantTxIdVal .= '_' . $paytype;
        $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;

        my $merchantTxId = genHmacMd5($merchantTxIdKey, $merchantTxIdVal);         # unique merchant transaction ID (this MD5 sum is used to check integrity of Koha CGI parameters in opac-account-pay-girosolution-message.pl)
        my $amount = $amount_to_pay * 100;      # not Euro but Cent are required
        my $currency = 'EUR';
        my $purpose = substr('Bibliothek:' . $patron->cardnumber(), 0, 27);   # With multibyte-characters a wrong hashval is calculated. This field accepts only characters conforming to SEPA, i.e.: a-z A-Z 0-9 ' : ? , - ( + . ) / 

        my $urlRedirect = $redirect_url->as_string();

        my $urlNotify = $message_url->as_string();

print STDERR "opac-account-pay.pl merchantTxIdKey:$merchantTxIdKey:\n";
print STDERR "opac-account-pay.pl merchantTxIdVal:$merchantTxIdVal:\n";
print STDERR "opac-account-pay.pl merchantTxId:$merchantTxId:\n";

        my $paramstr = 
            $merchantId .
            $projectId .
            $merchantTxId .
            $amount .
            $currency .
            $purpose .
            $urlRedirect .
            $urlNotify;

        my $hashval = genHmacMd5($key, $paramstr);

        my $gs_params = {
            'merchantId' => $merchantId,
            'projectId'  => $projectId,
            'merchantTxId' => $merchantTxId,
            'amount' => $amount,
            'currency' => $currency,
            'purpose' => $purpose,
            'urlRedirect' => $urlRedirect,
            'urlNotify' => $urlNotify,
            'hash' => $hashval
        };

        my $response = $ua->request( POST $url, $gs_params );

print STDERR "opac-account-pay.pl transaction/start response:", Dumper($response), ":\n";

        if ( $response->is_success ) {
            my $responseHeaderHash = $response->headers->header('hash');
print STDERR "opac-account-pay.pl response responseHeaderHash:$responseHeaderHash:\n";
            my $content = Encode::decode("utf8", $response->content);
            my $compHash = genHmacMd5($key, $content);
print STDERR "opac-account-pay.pl response responseHeaderHash:$responseHeaderHash: 2. compHash:$compHash: eq:", $responseHeaderHash eq $compHash, ":\n";
            my $json = from_json( $content );
print STDERR "opac-account-pay.pl 2. response json:", Dumper($json), ":\n";
print STDERR "opac-account-pay.pl 2. response json->rc:", scalar $json->{rc}, ":\n";
print STDERR "opac-account-pay.pl 2. response json->msg:", scalar $json->{msg}, ":\n";
print STDERR "opac-account-pay.pl 2. response json->reference:", scalar $json->{reference}, ":\n";
print STDERR "opac-account-pay.pl 2. response json->redirect:", scalar $json->{redirect}, ":\n";

            if ( $responseHeaderHash eq $compHash && $json->{rc} eq '0' ) {
                $error = 0;
                my $gs_message_redirect_url = $json->{redirect};
                print $cgi->redirect( $gs_message_redirect_url );

            } else {
                $template->param( error => "GIROSOLUTION_ERROR_PROCESSING", girosolutionmsg => $json->{msg} );
                $error = 1;
            }

        }
        else {
            $template->param( error => "GIROSOLUTION_UNABLE_TO_CONNECT" );
            $error = 1;
        }
    }

    output_html_with_http_headers( $cgi, $cookie, $template->output ) if $error;
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
