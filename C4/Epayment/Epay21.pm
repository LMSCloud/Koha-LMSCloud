package C4::Epayment::Epay21;

# Copyright (C) 2021 LMSCLoud GmbH
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

use CGI::Carp;
use JSON;
use Encode;
use HTTP::Request::Common;
use LWP::UserAgent;

use C4::Context;
use Koha::Patrons;
use Koha::DateUtils;

use C4::Epayment::EpaymentBase;
use parent qw(C4::Epayment::EpaymentBase);


# Typical response->result of epay21 webservices, shown here using webservice ConfirmPayment as example:
# {
#     'Payment' => {
#         'PayID' => '9008cd99-7a2f-44ca-81da-8ab8ccbc8c0c',
#         'CallerPayID' => '7791133b5fbc2da0de2853c9c4ae81f1',
#         'Type' => 'Giropay',
#         'Status' => 'payed',
#         'TimestampStart' => '2020-05-06T20:25:19.81',
#         'TimestampFinish' => '2020-05-06T20:27:54.07',
#         'Protocol' => {
#             'ProtocolEntry' => [
#                 {'Timestamp' => '2020-05-06T20:25:19.3270197+02:00', 'Operation' => 'InitPayment',      'Text' => 'Operation \'InitPayment\' \'OK\'',      'OperationOk' => 'true', 'PaymentState' => 'init'},
#                 {'Timestamp' => '2020-05-06T20:26:22.6770371+02:00', 'Operation' => 'StartPayment',     'Text' => 'Operation \'StartPayment\' \'OK\'',     'OperationOk' => 'true', 'PaymentState' => 'started'},
#                 {'Timestamp' => '2020-05-06T20:27:53.6596871+02:00', 'Operation' => 'ClosePayment',     'Text' => 'Operation \'ClosePayment\' \'OK\'',     'OperationOk' => 'true', 'PaymentState' => 'payed'},
#                 {'Timestamp' => '2020-05-06T20:28:05.1274580+02:00', 'Operation' => 'GetPaymentStatus', 'Text' => 'Operation \'GetPaymentStatus\' \'OK\'', 'OperationOk' => 'true', 'PaymentState' => 'payed'}
#             ]
#         }
#     },
#     'Operation' => {
#         'Parameters' => {
#             'MandantDesc' => "Universit\x{e4}tsstadt Gie\x{df}en",
#             'Mandant' => '06531005',
#             'App' => 'lms.koha',
#             'LocaleCode' => 'DE_DE',
#             'ClientInfo' => '06531005_lms.koha'
#         },
#         'Result' => {
#             'OK' => 'true',
#             'PayID' => '9008cd99-7a2f-44ca-81da-8ab8ccbc8c0c'
#         }
#     }
# }
# 
# Explanation:
# - 'PayID' is the unique ID of the payment action set by epay21.
# - 'CallerPayID' is another unique ID of the payment action, set by the 'shop', that is by Koha in our case.
# - 'Type' signals the payment type chosen by the 'shop customer' (i.e. patron in our case), e.g. Giropay, Paydirect, Creditcard, Paypal, etc.
# - 'Status' shows the current status of the payment, e.g. init, started, payed (sic!), confirmed, canceled (sic!), failed, etc.
# - 'TimestampStart': The payment action started at TimestampStart, initiated by webservice InitPayment (more exactly: when InitPayment (which will display the epay21 paypage) has finished).
#   InitPayment is called by opac-account-pay.pl. This marks the time when the paypage is displayed.
# - 'TimestampFinish': The payment action finalized at TimestampFinish, when webservice ClosePayment started (or finished?).
#   ClosePayment is called by the bank or by PayPal when the customer affirms his payment there.
# - The protocol entries list the sequence of webservice calls that happened before the current call (in the example: before ConfirmPayment).
# - Protocol entry InitPayment: Timestamp shows start of webservice InitPayment (i.e. when called in opac-account-pay.pl in order to redirect to epay21 paypage).
#   After execution of webservice InitPayment the payment state is 'init'.
# - Protocol entry StartPayment: Timestamp shows start of webservice StartPayment.
#   StartPayment is called from the epay21 paypage when the customer finally has clicked the button to be forwarded to the payment service provider or his bank
#   after chosing a payment method in the epay21 paypage and entering required data (e.g. BLZ of his bank in case of giropay or paydirect payments).
#   After execution of webservice StartPayment the payment state is 'started' in this example.
# - Protocol entry ClosePayment: Timestamp shows start of webservice ClosePayment.
#   ClosePayment is called by the customer's payment service provider or bank immediately after he has affirmed his payment there.
#   When ClosePayment has finished, normally a button is displayed in the dialog of the payment service provider or bank
#   for redirecting the customer to his 'online shop' (i.e. Koha opac, CGI script opac-account-pay-epay21-return.pl).
#   After execution of webservice StartPayment the payment state is 'payed' in this example, because the patron has not aborted the payment action but has affirmed it.
# - Protocol entry GetPaymentStatus: Timestamp shows start of webservice GetPaymentStatus.
#   GetPaymentStatus is called in opac-account-pay-epay21-return.pl to query epay21 for the result of the initated payment action.
#   If payment was affirmed by the patron and has succeeded, the accountlines selected for paying are updated in Koha 
#   and a success message is shown in the Koha opac (now back in CGI script opac-account.pl).
#   Otherwise an error message is shown in the Koha opac (now back in CGI script opac-account.pl).
# - 'Operation' shows information concerning the current webservice call (in the example: of ConfirmPayment).
# - 'Parameters' shows the call arguments of the current webservice call (in the example: of ConfirmPayment).
# - 'Result' shows the response arguments of the current webservice call (in the example: of ConfirmPayment).



sub new {
    my $class = shift;
    my $params = shift;
    my $loggerEpay21 = Koha::Logger->get({ interface => 'epayment.epay21' });

    my $self = {};
    bless $self, $class;
    $self = $self->SUPER::new();
    bless $self, $class;

    $self->{logger} = $loggerEpay21;
    $self->{patron} = $params->{patron};
    $self->{amount_to_pay} = $params->{amount_to_pay};
    $self->{accountlinesIds} = $params->{accountlinesIds};    # ref to array containing the accountlines_ids of accountlines to be paid.
    $self->{paytype} = $params->{paytype};    # always 17; may be interpreted as payment via epay21 paypage
    $self->{seconds} = $params->{seconds};    # Make payment trials for same accountlinesIds distinguishable, but using equal seconds value is required in confirmPayment() for calculating correct merchantTxId.
    
    $self->{logger}->debug("new() cardnumber:" . $self->{patron}->cardnumber() . ": amount_to_pay:" . $self->{amount_to_pay} . ": accountlinesIds:" . Dumper($self->{accountlinesIds}) . ": paytype:$self->{paytype}: seconds:$self->{seconds}:");
    $self->{logger}->trace("new()  Dumper(class):" . Dumper($class) . ":");

    $self->getSystempreferences();
    $self->{epay21WebservicesUrlNs} = 'http://epay21.ekom21.de/service/v11';

    $self->{now} = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );

    my $calculatedHashVal = $self->calculateHashVal( $self->{now} );
    $self->{merchantTxId} = $calculatedHashVal;

    #$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;    # never do that!
    use IO::Socket::SSL;
#    if ( $self->{logger}->is_debug() ) {
#        $IO::Socket::SSL::DEBUG = 1;
#    } elsif ( $self->{logger}->is_trace() ) {
#        $IO::Socket::SSL::DEBUG = 3;
#    } else {
        $IO::Socket::SSL::DEBUG = 0;
#    }

    $self->{soap_request} = SOAP::Lite->new( proxy => $self->{epay21WebservicesUrl});
    $self->{soap_request}->default_ns($self->{epay21WebservicesUrlNs});
    $self->{soap_request}->serializer->readable(1);

    # SOAP::Lite generates $self->{epay21WebservicesUrlNs}#InitPayment by default,
    # but MS .NET requires $self->{epay21WebservicesUrlNs}/InitPayment  - so we have to counteract (i.e. replace '#' by '/'):
    $self->{soap_request}->on_action( sub { join '/', @_ } );

    $self->{logger}->debug("new() returns; self->{now}:$self->{now}:");
    return $self;
}

sub getSystempreferences {
    my $self = shift;

    $self->{logger}->debug("getSystempreferences() START");

    $self->{epay21OpacPaymentsEnabled} = C4::Context->preference('Epay21PaypageOpacPaymentsEnabled');    # payment service epay21 via paypage enabled or not
    $self->{epay21WebservicesUrl} = C4::Context->preference('Epay21PaypageWebservicesURL');    # test env: https://epay-qs.ekom21.de/epay21/service/v11/ePay21Service.asmx   production env: https://epay.ekom21.de/epay21/service/v11/ePay21Service.asmx

    $self->{epay21Mandant} = C4::Context->preference('Epay21Mandant');    # the library's epay21 mandator designation ('Mandant')
    $self->{epay21App} = C4::Context->preference('Epay21App');    # the library's epay21 application designation ('App')
    $self->{epay21BasicAuthUser} = C4::Context->preference('Epay21BasicAuthUser');    # the library's epay21 user name for basic authentication
    $self->{epay21BasicAuthPw} = C4::Context->preference('Epay21BasicAuthPw');    # the library's epay21 passwort for basic authentication
    $self->{epay21MandantDesc} = C4::Context->preference('Epay21MandantDesc');    # mandator description that will be displayed on paypage
    $self->{epay21OrderDesc} = C4::Context->preference('Epay21OrderDesc');    # order description that will be displayed on paypage
    $self->{epay21AccountingSystemInfo} = C4::Context->preference('Epay21AccountingSystemInfo');    # additional information transferred to the library's financial accounting system

    $self->{opacBaseUrl} = C4::Context->preference('OPACBaseURL');    # The GiroSolution software seems to work only with https URL (not with http), and epay21 uses GiroSolution software.

    $self->{logger}->debug("getSystempreferences() END epay21WebservicesUrl:$self->{epay21WebservicesUrl}: epay21Mandant:$self->{epay21Mandant}: epay21App:$self->{epay21App}:");
}

# overwriting SOAP::Transport::HTTP::Client::get_basic_credentials for substituting the 
# customized credentials configured in system preferences Epay21BasicAuthUser and Epay21BasicAuthPw
sub SOAP::Transport::HTTP::Client::get_basic_credentials {
    # credentials for basic authentication
    my $basicAuth_User = C4::Context->preference('Epay21BasicAuthUser');    # mandatory
    my $basicAuth_Pw = C4::Context->preference('Epay21BasicAuthPw');    # mandatory

    return $basicAuth_User => $basicAuth_Pw;
}

# create a Hmac Md5 hashvalue as unique id for CallerPayID
sub calculateHashVal {
    my $self = shift;
    my $timestamp = shift;

    $self->{logger}->debug("calculateHashVal() START self->{now}:$self->{now}: timestamp:$timestamp:");

    my $tsMDY = $timestamp->mdy;
    my $tsDMY = $timestamp->dmy;
    my $key = 'yK§' . $self->{epay21BasicAuthPw} . '89%3fhcR';
    my $borrowernumber = $self->{patron}->borrowernumber();
    my $paytype = $self->{paytype};
    my $amount_to_pay = $self->{amount_to_pay};
    my $seconds = $self->{seconds};

    my $merchantTxIdKey = $tsMDY . $key . $tsDMY . $key . $borrowernumber . $paytype . '_' . $amount_to_pay . '_' . $paytype . $borrowernumber . $key . $tsDMY . $key . $tsMDY . $seconds;
    my $merchantTxIdVal = $borrowernumber . '_' . $amount_to_pay;
    foreach my $accountlinesId ( @{$self->{accountlinesIds}} ) {
        $merchantTxIdVal .= '_' . $accountlinesId;
    }
    $merchantTxIdVal .= '_' . $self->{paytype};
    $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;

    my $merchantTxId = $self->genHmacMd5( $merchantTxIdKey, $merchantTxIdVal );       # unique merchant transaction ID (this MD5 sum is used to check integrity of Koha CGI parameters in opac-account-pay-epay21-return.pl)

    $self->{logger}->debug("calculateHashVal() returns merchantTxId:$merchantTxId:");
    return ( $merchantTxId );
}

# init payment and return the paypage URL delivered in the response of webservice 'initPayment'
sub initPayment {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retEpay21RedirectUrl = '';
    my $epay21msg = '';
    my $purpose;   # Text for remittance info (Verwendungszweck). Since 2022-04-14 it may contain placeholder '<<borrowers.cardnumber>>'. This field accepts only characters conforming to SEPA : a-z A-Z 0-9 ' : ? , - ( + . ) /

    $self->{logger}->debug("initPayment() START epay21Mandant:$self->{epay21Mandant}: epay21App:$self->{epay21App}: epay21AccountingSystemInfo:$self->{epay21AccountingSystemInfo}:");

    my $epay21AccountingSystemInfo = $self->{epay21AccountingSystemInfo};
    if ( ! defined($epay21AccountingSystemInfo) ) {
        $epay21AccountingSystemInfo = '';
    }
    if ( $epay21AccountingSystemInfo =~ /<<borrowers.cardnumber>>/ ) {
        $purpose = $self->createRemittanceInfoText( $epay21AccountingSystemInfo, $self->{patron}->cardnumber() );
    } else {
        # old method, prior to 2022-04-14
        $purpose = substr($self->{patron}->cardnumber() . ' ' . $epay21AccountingSystemInfo, 0, 27);
    }
    $self->{logger}->debug("initPayment() remittance info purpose:$purpose:");

    my $returnUrl = URI->new( $self->{opacBaseUrl} . "/cgi-bin/koha/opac-account-pay-epay21-return.pl" );    # $returnUrl is used to update accountlines corresponding to the payment
    # set URL query arguments
    $returnUrl->query_form(
        {
            amountKoha => $self->{amount_to_pay},
            accountlinesKoha => $self->{accountlinesIds},
            borrowernumberKoha => $self->{patron}->borrowernumber(),
            paytypeKoha => $self->{paytype},    # with epay21: always 17
            timeKoha => $self->{seconds}
        }
    );

    my $cancelUrl = URI->new( $self->{opacBaseUrl} . "/cgi-bin/koha/opac-account-pay-epay21-cancelled.pl" );    # $cancelUrl is used to send info to epay21 that user has aborted the payment action
    # set URL query arguments
    $cancelUrl->query_form(
        {
            amountKoha => $self->{amount_to_pay},
            accountlinesKoha => $self->{accountlinesIds},
            borrowernumberKoha => $self->{patron}->borrowernumber(),
            paytypeKoha => $self->{paytype},    # with epay21: always 17
            timeKoha => $self->{seconds}
        }
    );

    # InitPayment OP parameters
    my $iniPay_OP_Mandant = $self->{epay21Mandant};    # mandatory
    my $iniPay_OP_MandantDesc = $self->{epay21MandantDesc};    # will be displayed on paypage
    my $iniPay_OP_App = $self->{epay21App};    # mandatory
    my $iniPay_OP_LocaleCode = 'DE_DE';
    my $iniPay_OP_ClientInfo = $self->{epay21Mandant} . '_' . $self->{epay21App};
    #my $iniPay_OP_PageURL = '';    # not required
    #my $iniPay_OP_PageReferrerURL = '';    # not required

    # InitPayment Query parameters
    my $iniPay_Query_CallerPayID = $self->{merchantTxId};    # mandatory, unique merchant transaction identifier
    my $iniPay_Query_Purpose = $purpose;   # mandatory; remittance info ('Verwendungszweck') This field accepts only characters conforming to SEPA ( i.e.: a-z A-Z 0-9 ' : ? , - ( + . ) /  );
    my $iniPay_Query_OrderDesc = C4::Context->preference('Epay21OrderDesc');    # order description; will be displayed on paypage
    #my $iniPay_Query_OrderInfos = 'Auch dieser Text kann auf der PayPage angezeigt werden';    # wei 12.12.19: do not use to avoid confusion
    my $iniPay_Query_Amount = $self->{amount_to_pay} * 100;      # not Euro but Cent are required; 1,23 EUR => 123 Cent
    my $iniPay_Query_Currency = 'EUR';    # mandatory if Art=online
    my $iniPay_Query_ReturnURL = $returnUrl->as_string();    # mandatory
    my $iniPay_Query_CancelURL = $cancelUrl->as_string();    # mandatory
    my $iniPay_Query_Art = 'online';    # mandatory
    my $iniPay_Query_GetQrCode = 'false';    # mandatory
    my $iniPay_Query_PaymentTimeout = 15;    # duration of validity of paypage: 15 minutes
#    my $iniPay_Query_ReferenceID = 'ReferenceID000002';    # mandatory if Art=invoice, not required if Art=online
#    my $iniPay_Query_ReferencePIN = 'ReferencePin000002';    # mandatory if Art=invoice, not required if Art=online
#    my $hashval = md5_hex($iniPay_Query_CallerPayID . $iniPay_Query_ReferenceID . $iniPay_Query_ReferencePIN);
#    my $iniPay_Query_CallerCode = SOAP::Data->name('CallerCode'  => $hashval);    # mandatory if Art=invoice, not required if Art=online

    # create the InitPayment 'OP' SOAP object
    my $initPaymentOpSoap = SOAP::Data->name('OP' => \SOAP::Data->value(
        SOAP::Data->name('Mandant' => $iniPay_OP_Mandant)->type('string'),
        SOAP::Data->name('MandantDesc' => $iniPay_OP_MandantDesc)->type('string'),
        SOAP::Data->name('App' => $iniPay_OP_App)->type('string'),
        SOAP::Data->name('LocaleCode' => $iniPay_OP_LocaleCode),
        SOAP::Data->name('ClientInfo' => $iniPay_OP_ClientInfo),
        #SOAP::Data->name('PageURL' => $iniPay_OP_PageURL,    # not required
        #SOAP::Data->name('PageReferrerURL' => $iniPay_OP_PageReferrerURL    # not required
    ));

    # create the InitPayment 'Query' SOAP object
    my $initPaymentQuerySoap = SOAP::Data->name('Query' => \SOAP::Data->value(
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

    # call the webservice InitPayment
    $self->{logger}->debug("initPayment() is calling self->{soap_request}->InitPayment with initPaymentOpSoap:" . Dumper($initPaymentOpSoap) . ": initPaymentQuerySoap:" . Dumper($initPaymentQuerySoap) . ":");
    my $response = eval {
        $self->{soap_request}->InitPayment( $initPaymentOpSoap, $initPaymentQuerySoap );
    };
    $self->{logger}->debug("initPayment() InitPayment response:" . Dumper($response) . ":");

    if ( $@ ) {
        my $mess = "InitPayment() error when calling self->{soap_request}->InitPayment:$@:";
        $self->{logger}->error($mess);
        carp ('C4::Epayment::Epay21::' . $mess . "\n");
        $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
        $retError = 21;
    }

    # example of response->content if succeeded:
    #
    # <?xml version="1.0" encoding="utf-8"?>
    # <soap:Envelope
    #     xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
    #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    #     xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    #     <soap:Body>
    #         <InitPaymentResponse
    #             xmlns="http://epay21.ekom21.de/service/v11">
    #             <InitPaymentResult>
    #                 <Operation>
    #                     <Parameters>
    #                         <Mandant>06534014</Mandant>
    #                         <MandantDesc>Freier Mandantbezeichner fÃŒr PayPage</MandantDesc>
    #                         <App>lms.koha</App>
    #                         <LocaleCode>DE_DE</LocaleCode>
    #                     </Parameters>
    #                     <Result>
    #                         <PayID>34d4958f-9e3d-41b2-b54c-5ff035784530</PayID>
    #                         <OK>true</OK>
    #                     </Result>
    #                 </Operation>
    #                 <Payment>
    #                     <Type>none</Type>
    #                     <PayID>34d4958f-9e3d-41b2-b54c-5ff035784530</PayID>
    #                     <Status>init</Status>
    #                     <TimestampStart>0001-01-01T00:00:00</TimestampStart>
    #                     <TimestampFinish>0001-01-01T00:00:00</TimestampFinish>
    #                 </Payment>
    #                 <PayPageInfo>
    #                     <PayPageUrl>https://epay-qs.ekom21.de/epay21/PP/ePay21Page.aspx?PayID=34d4958f-9e3d-41b2-b54c-5ff035784530</PayPageUrl>
    #                 </PayPageInfo>
    #             </InitPaymentResult>
    #         </InitPaymentResponse>
    #     </soap:Body>
    # </soap:Envelope>
    #
    # This shows that $response->result() returns node <InitPaymentResult>.

    if ( $response ) {
        if ( ! $response->fault() ) {
            $self->{logger}->trace("InitPayment() response>result():" . Dumper($response->result()) . ":");

            if (    $response->result()
                 && $response->result()->{Operation}
                 && $response->result()->{Operation}->{Result} )
            {
                my $resultOperation = $response->result()->{Operation};
                my $resultOperationResult = $resultOperation->{Result};
                $self->{logger}->debug("InitPayment() resultOperationResult:" . Dumper($resultOperationResult) . ":");
                if ( $resultOperationResult->{'OK'} eq 'true' ) {
                    if ( $response->result()->{PayPageInfo} ) {
                        $retError = 0;
                        $retEpay21RedirectUrl = $response->result()->{PayPageInfo}->{PayPageUrl};
                    }
                }
                if ( ! $retEpay21RedirectUrl ) {
                    $epay21msg = $resultOperationResult->{'ErrorMessage'} . ' (' . $resultOperationResult->{'ErrorMessageDetail'} . ')';
                    $retError = 22;
                    $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                }
            }
            if ( ! $retEpay21RedirectUrl && $retError == 0) {
                $epay21msg = "_rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
                $retError = 23;
                if ( $response->is_success ) {
                    $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                } else {
                    $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
                }
            }
        }    # End of: !$response->fault()
        else {
            $epay21msg = $response->fault();
            $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
            $retError = 24;
        }
        if ( $epay21msg ) {
            my $mess = "initPayment() epay21msg:" . $epay21msg . ":";
            $self->{logger}->error($mess);
            carp ('C4::Epayment::Epay21::' . $mess . "\n");
        }
    }

    $self->{logger}->debug("initPayment() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retEpay21RedirectUrl:$retEpay21RedirectUrl:");
    return ( $retError, $retErrorTemplate, $retEpay21RedirectUrl );
}

# Notify epay21 that the payment action has been aborted by user, by calling ConfirmPayment with ActionType 'cancel'.
sub confirmPayment {
    my $self = shift;
    my $cgi = shift;
    my $params = shift;
    my $retError = 0;
    my $retErrorTemplate = 'EPAY21_ABORTED_BY_USER';
    my $epay21msg = '';

    $self->{logger}->debug("confirmPayment() START cgi:" . Dumper($cgi) . ": params:" . Dumper($params) . ":");

    # HTTP query arguments already used in constructor new(): 
    # $cgi->param('amountKoha'), $cgi->multi_param('accountlinesKoha'), $cgi->param('borrowernumberKoha'), $cgi->param('paytypeKoha'), $cgi->param('timeKoha');

    # if called by opac-account-pay-epay21-cancelled.pl (there are no other callers of confirmPayment() at the moment):
    #   Notify epay21 that the payment action has been aborted by user, by calling ConfirmPayment with Query parameter 'Action' = 'cancel'.

    # In order to do this we have to search the epay21 PayID first ( by calling webservice 'getPaymentStatus' with Query parameter 'SearchKey' = $self->{merchantTxId} ).


    # 1st step: Search epay21 payment having CallerPayID $self->{merchantTxId}, using webservice GetPaymentStatus.

    # GetPaymentStatus OP parameters
    my $getPaymStat_OP_Mandant = $self->{epay21Mandant};    # mandatory
    my $getPaymStat_OP_MandantDesc = $self->{epay21MandantDesc};    # mandatory, will be displayed on paypage
    my $getPaymStat_OP_App = $self->{epay21App};    # mandatory
    my $getPaymStat_OP_LocaleCode = 'DE_DE';
    my $getPaymStat_OP_ClientInfo = $self->{epay21Mandant} . '_' . $self->{epay21App};
    #my $getPaymStat_OP_PageURL = '';    # not required
    #my $getPaymStat_OP_PageReferrerURL = '';    # not required

    # GetPaymentStatus Query parameters 
    my $getPaymStat_Query_SearchKey = $self->{merchantTxId};    # mandatory, unique merchant transaction ID
    my $getPaymStat_Query_SearchMode =  'normal';    # mandatory


    # create the getPaymentStatus 'OP' SOAP object
    my $getPaymentStatusOpSoap = SOAP::Data->name('OP' => \SOAP::Data->value(
        SOAP::Data->name('Mandant' => $getPaymStat_OP_Mandant)->type('string'),
        SOAP::Data->name('MandantDesc' => $getPaymStat_OP_MandantDesc)->type('string'),
        SOAP::Data->name('App' => $getPaymStat_OP_App)->type('string'),
        SOAP::Data->name('LocaleCode' => $getPaymStat_OP_LocaleCode),
        SOAP::Data->name('ClientInfo' => $getPaymStat_OP_ClientInfo),
        #SOAP::Data->name('PageURL' => $getPaymStat_OP_PageURL,    # not required
        #SOAP::Data->name('PageReferrerURL' => $getPaymStat_OP_PageReferrerURL    # not required
    ));

    # create the getPaymentStatus 'Query' SOAP object
    my $getPaymentStatusQuerySoap = SOAP::Data->name('Query' => \SOAP::Data->value(
        SOAP::Data->name('SearchKey' => $getPaymStat_Query_SearchKey),    # search by CallerPayID 
        SOAP::Data->name('SearchMode' => $getPaymStat_Query_SearchMode),
    ));

    # call the webservice GetPaymentStatus: read epay21 payID by SearchKey == CallerPayID. We use our unique $self->{merchantTxId} as CallerPayID.
    my $paymentStatus = 'undef';
    my $paymentType = '';
    my $paymentPayID = '';
    my $starttime = time();

    # check for payment status by sending request to webservice GetPaymentStatus
    $self->{logger}->debug("confirmPayment() is calling self->{soap_request}->GetPaymentStatus with getPaymentStatusOpSoap:" . Dumper($getPaymentStatusOpSoap) . ": getPaymentStatusQuerySoap:" . Dumper($getPaymentStatusQuerySoap) . ":");
    my $response = eval {
        $self->{soap_request}->GetPaymentStatus( $getPaymentStatusOpSoap, $getPaymentStatusQuerySoap );
    };
    $self->{logger}->debug("confirmPayment() GetPaymentStatus response:" . Dumper($response) . ":");

    if ( $@ ) {
        my $mess = "confirmPayment() error when calling self->{soap_request}->GetPaymentStatus:$@:";
        $self->{logger}->error($mess);
        carp ('C4::Epayment::Epay21::' . $mess . "\n");
        $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
        $retError = 31;
    }

    # example of response->content if failed:
    # 
    # <?xml version="1.0" encoding="utf-8"?>
    # <soap:Envelope
    #     xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
    #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    #     xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    #     <soap:Body>
    #         <GetPaymentStatusResponse
    #             xmlns="http://epay21.ekom21.de/service/v11">
    #             <GetPaymentStatusResult>
    #                 <Operation>
    #                     <Parameters>
    #                         <Mandant>06534014</Mandant>
    #                         <MandantDesc>Freier Mandantbezeichner fÃŒr PayPage</MandantDesc>
    #                         <App>lms.koha</App>
    #                         <LocaleCode>DE_DE</LocaleCode>
    #                     </Parameters>
    #                     <Result>
    #                         <OK>false</OK>
    #                         <ErrorCode>P107</ErrorCode>
    #                         <ErrorMessage>(P107) Der Bezahlvorgang wurde nicht gefunden (PayID).</ErrorMessage>
    #                         <ErrorMessageDetail>Mandant:06534014; App:lms.koha; Datum:18-02-2021 14:21:43;  (P107) Payment-Fehler, Transaktion zu PayID \'\' nicht gefunden</ErrorMessageDetail>
    #                     </Result>
    #                 </Operation>
    #             </GetPaymentStatusResult>
    #         </GetPaymentStatusResponse>
    #     </soap:Body>
    # </soap:Envelope>
    #
    #
    # example of response->content if succeeded:
    # 
    # <?xml version="1.0" encoding="utf-8"?>
    # <soap:Envelope
    #     xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
    #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    #     xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    #     <soap:Body>
    #         <GetPaymentStatusResponse
    #             xmlns="http://epay21.ekom21.de/service/v11">
    #             <GetPaymentStatusResult>
    #                 <Operation>
    #                     <Parameters>
    #                         <Mandant>06534014</Mandant>
    #                         <MandantDesc>Freier Mandantbezeichner fÃŒr PayPage</MandantDesc>
    #                         <App>lms.koha</App>
    #                         <LocaleCode>DE_DE</LocaleCode>
    #                     </Parameters>
    #                     <Result>
    #                         <OK>true</OK>
    #                     </Result>
    #                 </Operation>
    #                 <Payment>
    #                     <Type>none</Type>
    #                     <PayID>0bf327cd-0dc3-4a0e-882e-0bf6b17a6741</PayID>
    #                     <CallerPayID>792b25b3ece3a7619ab80290e55cab94</CallerPayID>
    #                     <Status>init</Status>
    #                     <TimestampStart>2021-02-18T14:42:08.55</TimestampStart>
    #                     <TimestampFinish>0001-01-01T00:00:00</TimestampFinish>
    #                 </Payment>
    #             </GetPaymentStatusResult>
    #         </GetPaymentStatusResponse>
    #     </soap:Body>
    # </soap:Envelope>
    #
    # This shows that $response->result() returns node <GetPaymentStatusResult>.

    if ( $response ) {
        if ( ! $response->fault() ) {
            $self->{logger}->trace("confirmPayment() GetPaymentStatus response>result():" . Dumper($response->result()) . ":");

            if (    $response->result()
                 && $response->result()->{Operation}
                 && $response->result()->{Operation}->{Result} )
            {
                my $resultOperation = $response->result()->{Operation};
                my $resultOperationResult = $resultOperation->{Result};
                $self->{logger}->debug("confirmPayment() GetPaymentStatus resultOperationResult:" . Dumper($resultOperationResult) . ":");
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
                if ( ! $paymentPayID ) {
                    $epay21msg = 'epay21-ErrorCode:' . $resultOperationResult->{'ErrorCode'} . ' ' . $resultOperationResult->{'ErrorMessage'} . ' (' . $resultOperationResult->{'ErrorMessageDetail'} . ')';
                    $retError = 32;
                    $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                }
            }
            if ( ! $paymentPayID && $retError == 0) {
                $epay21msg = "_rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
                $retError = 33;
                if ( $response->is_success ) {
                    $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                } else {
                    $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
                }
            }
        }    # End of: !$response->fault()
        else {
            $epay21msg = $response->fault();
            $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
            $retError = 34;
        }
        if ( $epay21msg ) {
            my $mess = "confirmPayment() GetPaymentStatus epay21msg:" . $epay21msg . ":";
            $self->{logger}->error($mess);
            carp ('C4::Epayment::Epay21::' . $mess . "\n");
            $epay21msg = '';
        }
    }

    if ( length($paymentPayID) ) {    # GetPaymentStatus found the payment with CallerPayID = self->{merchantTxId}
        my $confirmPaymentResponseOK = 0;

        # 2nd step: Confirm status for payment having epay21 PayID = $paymentPayID, using webservice ConfirmPayment.

        # ConfirmPayment OP parameters are identical to GetPaymentStatus OP parameters (already set a few lines ago)
        # ConfirmPayment Query parameters: 
        my $confirmPay_Query_PayID = $paymentPayID;    # mandatory, unique payment identifier of epay21
        my $confirmPay_Query_Action = $params->{confirmPaymentQueryAction};    # mandatory, e.g. 'cancel'

        # create the confirmPayment 'OP' SOAP object
        my $confirmPaymentOpSoap =  $getPaymentStatusOpSoap;
        # create the confirmPayment 'Query' SOAP object
        my $confirmPaymentQuerySoap = SOAP::Data->name('Query' => \SOAP::Data->value(
            SOAP::Data->name('PayID' => $confirmPay_Query_PayID),
            SOAP::Data->name('Action' => $confirmPay_Query_Action),
        ));

        # call the webservice ConfirmPayment
        $self->{logger}->debug("confirmPayment() is calling self->{soap_request}->ConfirmPayment with confirmPaymentOpSoap:" . Dumper($confirmPaymentOpSoap) . ": confirmPaymentQuerySoap:" . Dumper($confirmPaymentQuerySoap) . ":");
        my $response = eval {
            $self->{soap_request}->ConfirmPayment( $confirmPaymentOpSoap, $confirmPaymentQuerySoap );
        };
        $self->{logger}->debug("confirmPayment() ConfirmPayment response:" . Dumper($response) . ":");

        if ( $@ ) {
            my $mess = "confirmPayment() error when calling self->{soap_request}->ConfirmPayment:$@:";
            $self->{logger}->error($mess);
            carp ('C4::Epayment::Epay21::' . $mess . "\n");
            $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
            $retError = 35;
        }

        # example of response->content if failed:
        # 
        # <?xml version="1.0" encoding="utf-8"?>
        # <soap:Envelope
        #     xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
        #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        #     xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        #     <soap:Body>
        #         <ConfirmPaymentResponse
        #             xmlns="http://epay21.ekom21.de/service/v11">
        #             <ConfirmPaymentResult>
        #                 <Operation>
        #                     <Parameters>
        #                         <Mandant>06534014</Mandant>
        #                         <MandantDesc>Freier Mandantbezeichner fÃŒr PayPage</MandantDesc>
        #                         <App>lms.koha</App>
        #                         <LocaleCode>DE_DE</LocaleCode>
        #                     </Parameters>
        #                     <Result>
        #                         <OK>false</OK>
        #                         <ErrorCode>X101</ErrorCode>
        #                         <ErrorMessage>epay21-Parameter-Error (API)</ErrorMessage>
        #                         <ErrorMessageDetail>WebParameter \'PayID\' is invalid (length) / Value: \'MzVkOTZlMzItNjcwZC00ZjM3LTgxMmYtNzMzYWMzZWQ4ZDNkWFhYV0g=\'</ErrorMessageDetail>
        #                     </Result>
        #                 </Operation>
        #             </ConfirmPaymentResult>
        #         </ConfirmPaymentResponse>
        #     </soap:Body>
        # </soap:Envelope
        #
        #
        # example of response->content if succeeded:
        # 
        # <?xml version="1.0" encoding="utf-8"?>
        # <soap:Envelope
        #     xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
        #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        #     xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        #     <soap:Body>
        #         <ConfirmPaymentResponse
        #             xmlns="http://epay21.ekom21.de/service/v11">
        #             <ConfirmPaymentResult>
        #                 <Operation>
        #                     <Parameters>
        #                         <Mandant>06534014</Mandant>
        #                         <MandantDesc>Freier Mandantbezeichner fÃŒr PayPage</MandantDesc>
        #                         <App>lms.koha</App>
        #                         <LocaleCode>DE_DE</LocaleCode>
        #                     </Parameters>
        #                     <Result>
        #                         <PayID>34d4958f-9e3d-41b2-b54c-5ff035784530</PayID>
        #                         <OK>true</OK>
        #                     </Result>
        #                 </Operation>
        #                 <Payment>
        #                     <Type>none</Type>
        #                     <PayID>34d4958f-9e3d-41b2-b54c-5ff035784530</PayID>
        #                     <CallerPayID>3a693e9cbc94b5e26cf39550aca96f6c</CallerPayID>
        #                     <Status>canceled</Status>
        #                     <StatusText>Abbruch durch Benutzer</StatusText>
        #                     <TimestampStart>2021-02-18T14:03:11.61</TimestampStart>
        #                     <TimestampFinish>0001-01-01T00:00:00</TimestampFinish>
        #                 </Payment>
        #             </ConfirmPaymentResult>
        #         </ConfirmPaymentResponse>
        #     </soap:Body>
        # </soap:Envelope
        #
        # This shows that $response->result() returns node <ConfirmPaymentResult>.

        if ( $response ) {
            if ( ! $response->fault() ) {
                $self->{logger}->trace("confirmPayment() ConfirmPayment response>result():" . Dumper($response->result()) . ":");

                if (    $response->result()
                     && $response->result()->{Operation}
                     && $response->result()->{Operation}->{Result} )
                {
                    my $resultOperation = $response->result()->{Operation};
                    my $resultOperationResult = $resultOperation->{Result};
                    $self->{logger}->debug("confirmPayment() ConfirmPayment resultOperationResult:" . Dumper($resultOperationResult) . ":");
                    if ( $resultOperationResult->{'OK'} eq 'true' ) {
                        $confirmPaymentResponseOK = 1;
                    }
                    if ( ! $confirmPaymentResponseOK ) {
                        $epay21msg = 'epay21-ErrorCode:' . $resultOperationResult->{'ErrorCode'} . ' ' . $resultOperationResult->{'ErrorMessage'} . ' (' . $resultOperationResult->{'ErrorMessageDetail'} . ')';
                        $retError = 36;
                        $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                    }
                }
                if ( ! $confirmPaymentResponseOK && $retError == 0) {
                    $epay21msg = "_rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
                    $retError = 37;
                    if ( $response->is_success ) {
                        $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                    } else {
                        $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
                    }
                }
            }    # End of: !$response->fault()
            else {
                $epay21msg = $response->fault();
                $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
                $retError = 38;
            }
            if ( $epay21msg ) {
                my $mess = "confirmPayment() ConfirmPayment epay21msg:" . $epay21msg . ":";
                $self->{logger}->error($mess);
                carp ('C4::Epayment::Epay21::' . $mess . "\n");
            }
        }
    }

    $self->{logger}->debug("confirmPayment() returns retError:$retError: retErrorTemplate:$retErrorTemplate:");
    return ( $retError, $retErrorTemplate );
}

# verify online payment by calling the webservice to check the transaction status and, if paid, also 'pay' the accountlines in Koha
sub checkOnlinePaymentStatusAndPayInKoha {
    my $self = shift;
    my $cgi = shift;
    my $retError = 0;
    my $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
    my $kohaPaymentId;
    my $epay21msg = '';

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() START cgi:" . Dumper($cgi) . ":");

    # Params set by Koha in Epay21::initPayment() are sent as URL query arguments.
    # Already used in constructor new(): 
    # $cgi->param('amountKoha'), $cgi->multi_param('accountlinesKoha'), $cgi->param('borrowernumberKoha'), $cgi->param('paytypeKoha'), $cgi->param('timeKoha');


    # Check if external online payment has been successful by calling webservice GetPaymentStatus (which delivers status and epay21 payment ID)
    # and, if payment status allows it, 'pay' the selected account lines in Koha
    # and, if epay21 payment ID has been found, inform epay21 about the result of 'paying' the accountlines in Koha.

    # In order to do this we have to search the epay21 payment having CallerPayID $self->{merchantTxId},
    # by calling webservice 'GetPaymentStatus' with Query parameter 'SearchKey' = $self->{merchantTxId} ( as CallerPayID) ).

    # 1st step: Search epay21 payment having CallerPayID $self->{merchantTxId}, using webservice GetPaymentStatus.

    # GetPaymentStatus OP parameters
    my $getPaymStat_OP_Mandant = $self->{epay21Mandant};    # mandatory
    my $getPaymStat_OP_MandantDesc = $self->{epay21MandantDesc};    # mandatory, will be displayed on paypage
    my $getPaymStat_OP_App = $self->{epay21App};    # mandatory
    my $getPaymStat_OP_LocaleCode = 'DE_DE';
    my $getPaymStat_OP_ClientInfo = $self->{epay21Mandant} . '_' . $self->{epay21App};
    #my $getPaymStat_OP_PageURL = '';    # not required
    #my $getPaymStat_OP_PageReferrerURL = '';    # not required

    # GetPaymentStatus Query parameters 
    my $getPaymStat_Query_SearchKey = $self->{merchantTxId};    # mandatory, unique merchant transaction ID, epay21 CallerPayID
    my $getPaymStat_Query_SearchMode =  'normal';    # mandatory


    # create the GetPaymentStatus 'OP' SOAP object
    my $getPaymentStatusOpSoap = SOAP::Data->name('OP' => \SOAP::Data->value(
        SOAP::Data->name('Mandant' => $getPaymStat_OP_Mandant)->type('string'),
        SOAP::Data->name('MandantDesc' => $getPaymStat_OP_MandantDesc)->type('string'),
        SOAP::Data->name('App' => $getPaymStat_OP_App)->type('string'),
        SOAP::Data->name('LocaleCode' => $getPaymStat_OP_LocaleCode),
        SOAP::Data->name('ClientInfo' => $getPaymStat_OP_ClientInfo),
        #SOAP::Data->name('PageURL' => $getPaymStat_OP_PageURL,    # not required
        #SOAP::Data->name('PageReferrerURL' => $getPaymStat_OP_PageReferrerURL    # not required
    ));

    # create the GetPaymentStatus 'Query' SOAP object
    my $getPaymentStatusQuerySoap = SOAP::Data->name('Query' => \SOAP::Data->value(
        SOAP::Data->name('SearchKey' => $getPaymStat_Query_SearchKey),    # search by CallerPayID 
        SOAP::Data->name('SearchMode' => $getPaymStat_Query_SearchMode),
    ));

    # call the webservice GetPaymentStatus: read epay21 payID by SearchKey == CallerPayID. We use our unique $self->{merchantTxId} as CallerPayID.
    # read payment status until it is 'payed', 'confirmed', 'canceled' or 'failed' - but maximal for 10 seconds
    my $paymentStatus = 'undef';
    my $paymentType = '';
    my $paymentPayID = '';
    my $starttime = time();

    while ( time() < $starttime + 10 ) {

        # check for payment status by sending request to webservice GetPaymentStatus
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() is calling self->{soap_request}->GetPaymentStatus with getPaymentStatusOpSoap:" . Dumper($getPaymentStatusOpSoap) . ": getPaymentStatusQuerySoap:" . Dumper($getPaymentStatusQuerySoap) . ":");
        my $response = eval {
            $self->{soap_request}->GetPaymentStatus( $getPaymentStatusOpSoap, $getPaymentStatusQuerySoap );
        };
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() GetPaymentStatus response:" . Dumper($response) . ":");

        if ( $@ ) {
            my $mess = "checkOnlinePaymentStatusAndPayInKoha() error when calling self->{soap_request}->GetPaymentStatus:$@:";
            $self->{logger}->error($mess);
            carp ('C4::Epayment::Epay21::' . $mess . "\n");
            $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
            $retError = 41;
        }

        # example of response->content if failed:
        # 
        # <?xml version="1.0" encoding="utf-8"?>
        # <soap:Envelope
        #     xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
        #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        #     xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        #     <soap:Body>
        #         <GetPaymentStatusResponse
        #             xmlns="http://epay21.ekom21.de/service/v11">
        #             <GetPaymentStatusResult>
        #                 <Operation>
        #                     <Parameters>
        #                         <Mandant>06534014</Mandant>
        #                         <MandantDesc>Freier Mandantbezeichner fÃŒr PayPage</MandantDesc>
        #                         <App>lms.koha</App>
        #                         <LocaleCode>DE_DE</LocaleCode>
        #                     </Parameters>
        #                     <Result>
        #                         <OK>false</OK>
        #                         <ErrorCode>P107</ErrorCode>
        #                         <ErrorMessage>(P107) Der Bezahlvorgang wurde nicht gefunden (PayID).</ErrorMessage>
        #                         <ErrorMessageDetail>Mandant:06534014; App:lms.koha; Datum:18-02-2021 14:21:43;  (P107) Payment-Fehler, Transaktion zu PayID \'\' nicht gefunden</ErrorMessageDetail>
        #                     </Result>
        #                 </Operation>
        #             </GetPaymentStatusResult>
        #         </GetPaymentStatusResponse>
        #     </soap:Body>
        # </soap:Envelope>
        #
        #
        # example of response->content if succeeded:
        # 
        # <?xml version="1.0" encoding="utf-8"?>
        # <soap:Envelope
        #     xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
        #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        #     xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        #     <soap:Body>
        #         <GetPaymentStatusResponse
        #             xmlns="http://epay21.ekom21.de/service/v11">
        #             <GetPaymentStatusResult>
        #                 <Operation>
        #                     <Parameters>
        #                         <Mandant>06534014</Mandant>
        #                         <MandantDesc>Freier Mandantbezeichner fÃŒr PayPage</MandantDesc>
        #                         <App>lms.koha</App>
        #                         <LocaleCode>DE_DE</LocaleCode>
        #                     </Parameters>
        #                     <Result>
        #                         <OK>true</OK>
        #                     </Result>
        #                 </Operation>
        #                 <Payment>
        #                     <Type>none</Type>
        #                     <PayID>0bf327cd-0dc3-4a0e-882e-0bf6b17a6741</PayID>
        #                     <CallerPayID>792b25b3ece3a7619ab80290e55cab94</CallerPayID>
        #                     <Status>init</Status>
        #                     <TimestampStart>2021-02-18T14:42:08.55</TimestampStart>
        #                     <TimestampFinish>0001-01-01T00:00:00</TimestampFinish>
        #                 </Payment>
        #             </GetPaymentStatusResult>
        #         </GetPaymentStatusResponse>
        #     </soap:Body>
        # </soap:Envelope>
        #
        # This shows that $response->result() returns node <GetPaymentStatusResult>.

        if ( $response ) {
            if ( ! $response->fault() ) {
                $self->{logger}->trace("checkOnlinePaymentStatusAndPayInKoha() GetPaymentStatus response>result():" . Dumper($response->result()) . ":");

                if (    $response->result()
                     && $response->result()->{Operation}
                     && $response->result()->{Operation}->{Result} )
                {
                    my $resultOperation = $response->result()->{Operation};
                    my $resultOperationResult = $resultOperation->{Result};
                    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() GetPaymentStatus resultOperationResult:" . Dumper($resultOperationResult) . ":");
                    if ( $resultOperationResult->{'OK'} eq 'true' ) {
                        if ( $response->result()->{Payment} ) {
                            $paymentStatus = $response->result()->{Payment}->{Status};
                            $paymentType = $response->result()->{Payment}->{Type};
                            $paymentPayID = $response->result()->{Payment}->{PayID};
                            if ( $paymentStatus eq 'payed' || $paymentStatus eq 'confirmed' ) {    # when paid, epay21 payment status is 'payed' (sic!)
                                $epay21msg = '';
                                $retError = 0;
                                $retErrorTemplate = '';
                                last;    # looks good, we have to 'pay' the accountlines
                            }
                            if ( $paymentStatus eq 'canceled' || $paymentStatus eq 'failed' ) {
                                $epay21msg = 'paymentStatus:' . $paymentStatus . ':';
                                $retError = 42;
                                $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                                last;    # payment not successful, so we do NOT 'pay' the accountlines
                            }
                        } else {    # payment status not decided yet
                            $paymentStatus = '';
                            $paymentType = '';
                            $paymentPayID = '';
                        }
                    }
                    if ( ! $paymentPayID ) {
                        $epay21msg = 'epay21-ErrorCode:' . $resultOperationResult->{'ErrorCode'} . ' ' . $resultOperationResult->{'ErrorMessage'} . ' (' . $resultOperationResult->{'ErrorMessageDetail'} . ')';
                        $retError = 43;
                        $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                    }
                }
                if ( ! $paymentPayID && $retError == 0) {
                    $epay21msg = "GetPaymentStatus _rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
                    $retError = 44;
                    if ( $response->is_success ) {
                        $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
                    } else {
                        $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
                    }
                }
            }    # End of: !$response->fault()
            else {
                $epay21msg .= $response->fault();
                $retError = 45;
                $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
            }
        } else {
            $epay21msg .= "response is empty or undef";
            $retError = 46;
            $retErrorTemplate = 'EPAY21_UNABLE_TO_CONNECT';
        }    # end: if ( $response )

        if ( $epay21msg ) {
            my $mess = "checkOnlinePaymentStatusAndPayInKoha() GetPaymentStatus epay21msg:" . $epay21msg . ":";
            $self->{logger}->error($mess);
            carp ('C4::Epayment::Epay21::' . $mess . "\n");
            $epay21msg = '';
        }
        sleep(1);
    }

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() paymentStatus:$paymentStatus:");
    if (  $paymentStatus eq 'payed' || $paymentStatus eq 'confirmed' ) {    # when paid, epay21 payment status is 'payed' (sic!)
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() External online payment succeeded, so we have to 'pay' the accountlines in Koha now.");

        # 2nd step: now 'pay' the accountlines in Koha
        my $account = Koha::Account->new( { patron_id => $self->{patron}->borrowernumber() } );
        my @lines = Koha::Account::Lines->search(
            {
                accountlines_id => { -in => $self->{accountlinesIds} }
            }
        );

        my $sumAmountoutstanding = 0.0;
        foreach my $accountline ( @lines ) {
            $self->{logger}->trace("checkOnlinePaymentStatusAndPayInKoha() accountline->{_result}->{_column_data}:" . Dumper($accountline->{_result}->{_column_data}) . ":");
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() accountline->id:" . $accountline->accountlines_id() . ": ->amountoutstanding():" . $accountline->amountoutstanding() . ":");
            $sumAmountoutstanding += $accountline->amountoutstanding();
        }
        $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding is also done in the complimentary opac-account-pay.pl
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() sumAmountoutstanding:$sumAmountoutstanding: self->{amount_to_pay}:$self->{amount_to_pay}:");

        # check if amount to pay is correct
        if ( $sumAmountoutstanding == $self->{amount_to_pay} ) {

            my $descriptionText = 'Zahlung (epay21)';    # should always be overwritten
            my $noteText = "Online-Zahlung $paymentPayID";    # should always be overwritten
            if ( $self->{paytype} == 17 ) {    # all: giropay, paydirect, credit card, Lastschrift, ...
                if ( $paymentType ) {
                    $descriptionText = $paymentType . " (epay21)";
                    $noteText = "Online ($paymentType) $paymentPayID";
                } else {
                    $descriptionText = "Online-Zahlung (epay21)";
                    $noteText = "Online-Zahlung $paymentPayID";
                }
            }
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() descriptionText:$descriptionText: noteText:$noteText:");

            # we take the borrowers branchcode also for the payment accountlines record to be created
            my $library_id = $self->{patron}->branchcode();
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() library_id:$library_id:");

            # evaluate configuration of cash register management for online payments
            # default: withoutCashRegisterManagement = 1; (i.e. avoiding cash register management in Koha::Account->pay())
            # default: onlinePaymentCashRegisterManagerId = 0;: borrowernumber of manager of cash register for online payments
            my ( $withoutCashRegisterManagement, $onlinePaymentCashRegisterManagerId ) = $self->getEpaymentCashRegisterManagement();

            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() withoutCashRegisterManagement:$withoutCashRegisterManagement: onlinePaymentCashRegisterManagerId:$onlinePaymentCashRegisterManagerId:");
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() now is calling account->pay()");
            $kohaPaymentId = $account->pay(
                {
                    amount => $self->{amount_to_pay},
                    lines => \@lines,
                    library_id => $library_id,
                    description => $descriptionText,
                    note => $noteText,
                    withoutCashRegisterManagement => $withoutCashRegisterManagement,
                    onlinePaymentCashRegisterManagerId => $onlinePaymentCashRegisterManagerId
                }
            );
        } else {
            $epay21msg = "sumAmountoutstanding ($sumAmountoutstanding) != self->{amount_to_pay} ($self->{amount_to_pay})";
            $retError = 47;
            $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
        }
    } else {
        $epay21msg .= "NOT calling account->pay! paymentStatus:$paymentStatus:";
        $retError = 48;
        $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
    }

    if ( $kohaPaymentId ) {
        $retError = 0;
        $retErrorTemplate = '';
    } else {
        if (  $paymentStatus eq 'payed' || $paymentStatus eq 'confirmed' ) {    # when paid, epay21 payment status is 'payed' (sic!)
            $epay21msg .= 'Error in account->pay()';
            $retError = 481;
            $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
        } else {
            $epay21msg .= 'Online payment has not been confirmed as successfull by epay21 within 10 seconds';
            $retError = 482;
            $retErrorTemplate = 'EPAY21_ERROR_PROCESSING';
        }
    }


    if ( length($paymentPayID) ) {    # epay21 payment order has been found

        # 3rd step: Confirm status ('failure' or 'confirm') in epay21 for payment having epay21 PayID = $paymentPayID, using webservice ConfirmPayment.

        # ConfirmPayment OP parameters are identical to GetPaymentStatus OP parameters (already set a few lines ago)
        # ConfirmPayment Query parameters: 
        my $confirmPay_Query_PayID = $paymentPayID;    # mandatory, unique payment identifier of epay21
        my $confirmPay_Query_Action = $retError ? 'failure' : 'confirm';    # mandatory

        # create the confirmPayment 'OP' SOAP object
        my $confirmPaymentOpSoap =  $getPaymentStatusOpSoap;
        # create the confirmPayment 'Query' SOAP object
        my $confirmPaymentQuerySoap = SOAP::Data->name('Query' => \SOAP::Data->value(
            SOAP::Data->name('PayID' => $confirmPay_Query_PayID),
            SOAP::Data->name('Action' => $confirmPay_Query_Action),
        ));

        # call the webservice ConfirmPayment
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() is calling self->{soap_request}->ConfirmPayment with confirmPaymentOpSoap:" . Dumper($confirmPaymentOpSoap) . ": confirmPaymentQuerySoap:" . Dumper($confirmPaymentQuerySoap) . ":");
        my $response = eval {
            $self->{soap_request}->ConfirmPayment( $confirmPaymentOpSoap, $confirmPaymentQuerySoap );
        };
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() ConfirmPayment response:" . Dumper($response) . ":");

        # a failure of this ConfirmPayment call must not spoil the result we got 
        # from calling the webservice GetPaymentStatus and from calling $account->pay(),
        # so $retError must not be set in this 3rd step.
        if ( $@ ) {
            my $mess = "confirmPayment() error when calling self->{soap_request}->ConfirmPayment:$@:";
            $self->{logger}->error($mess);
            carp ('C4::Epayment::Epay21::' . $mess . "\n");
        }

        if ( $response ) {
            if ( !$response->fault() ) {
                $self->{logger}->trace("checkOnlinePaymentStatusAndPayInKoha() ConfirmPayment response>result():" . Dumper($response->result()) . ":");

                if (    $response->result()
                     && $response->result()->{Operation}
                     && $response->result()->{Operation}->{Result} )
                {
                    my $resultOperation = $response->result()->{Operation};
                    my $resultOperationResult = $resultOperation->{Result};
                    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() ConfirmPayment resultOperationResult:" . Dumper($resultOperationResult) . ":");
                    if ( $resultOperationResult->{'OK'} eq 'true' ) {
                        if ( $response->result()->{Payment} ) {
                            my $paymentStatus = $response->result()->{Payment}->{Status};
                            my $paymentType = $response->result()->{Payment}->{Type};
                            my $paymentPayID = $response->result()->{Payment}->{PayID};
                        }
                    } else {
                        $epay21msg = 'epay21-ErrorCode:' . $resultOperationResult->{'ErrorCode'} . ' ' . $resultOperationResult->{'ErrorMessage'} . ' (' . $resultOperationResult->{'ErrorMessageDetail'} . ')';
                    }
                } else {
                    $epay21msg = "GetPaymentStatus _rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
                }
            }    # End of: !$response->fault()
            else {
                $epay21msg = "error when calling soap_request->ConfirmPayment:" . $response->fault() . ":";
            }
        }
    } else {
        $epay21msg = "could not get paymentPayID of order:$getPaymStat_Query_SearchKey:";
        $retError = 49;
        $retErrorTemplate = "EPAY21_ERROR_PROCESSING";
    }

    if ( $epay21msg ) {
        my $mess = "checkOnlinePaymentStatusAndPayInKoha() epay21msg:" . $epay21msg . ":";
        $self->{logger}->error($mess);
        carp ('C4::Epayment::Epay21::' . $mess . "\n");
    }

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() returns retError:$retError: retErrorTemplate:$retErrorTemplate:");
    return ( $retError, $retErrorTemplate );
}

# init the payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, extract the epay21 paypage URL delivered in its response
# (The method paymentAction() exists only for formal reasons in this case, to match the pattern of the other epayment implementations. 
#  This would not be so if one would call initPayment() directly in opac-account-pay.pl.) 
sub paymentAction {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retEpay21RedirectUrl = '';

    $self->{logger}->debug("paymentAction() START");

    ( $retError, $retErrorTemplate, $retEpay21RedirectUrl ) = $self->initPayment();

    $self->{logger}->debug("paymentAction() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retEpay21RedirectUrl:$retEpay21RedirectUrl:");
    return ( $retError, $retErrorTemplate, $retEpay21RedirectUrl );
}

1;
