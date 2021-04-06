package C4::Epayment::GiroSolution;

# Copyright 2021 (C) LMSCLoud GmbH
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
use utf8;
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

sub new {
    my $class = shift;
    my $params = shift;
    my $loggerGirosolution = Koha::Logger->get({ interface => 'epayment.girosolution' });

    my $self = {};
    bless $self, $class;
    $self = $self->SUPER::new();
    bless $self, $class;

    $self->{logger} = $loggerGirosolution;
    $self->{patron} = $params->{patron};
    $self->{amount_to_pay} = $params->{amount_to_pay};
    $self->{accountlinesIds} = $params->{accountlinesIds};    # ref to array containing the accountlines_ids of accountlines to be payed
    $self->{paytype} = $params->{paytype};    # paytype 1: giropay   paytype 11: creditcard
    
    $self->{logger}->debug("new() cardnumber:" . $self->{patron}->cardnumber() . ": amount_to_pay:" . $self->{amount_to_pay} . ": accountlinesIds:" . Dumper($self->{accountlinesIds}) . ": paytype:" . $self->{paytype} . ":");
    $self->{logger}->trace("new()  Dumper(class):" . Dumper($class) . ":");

    $self->getSystempreferences();

    # Contrary to other payment service providers, Girosolution does not provide separate URLs for test and production environment.
    # One of the both environments is to be chosen for each GiroSolution project individually in the 'GiroSolution cockpit' configuration tool by the customer.
    # Switching between the two environments is possible. 
    $self->{girosolutionWebservicesURL} = 'https://payment.girosolution.de/girocheckout/api/v2/transaction/start';    # used for init payment service (both test and production environment)

    $self->{now} = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
    my $calculatedHashVal = $self->calculateHashVal($self->{now});
    $self->{merchantTxId} = $calculatedHashVal;

    $self->{ua} = LWP::UserAgent->new;
	$self->{ua}->timeout(15);
	$self->{ua}->env_proxy;
    $self->{ua}->ssl_opts( "verify_hostname" => 1 );

    $self->{logger}->debug("new() returns; self->{now}:$self->{now}:");
    $self->{logger}->trace("new() returns self:" . Dumper($self) . ":");
    return $self;
}

sub getSystempreferences {
    my $self = shift;

    $self->{logger}->debug("getSystempreferences() START");
    my $paytypeGiropay = 1;
    my $paytypeCreditcard = 11;

    $self->{girosolutionOpacPaymentsEnabled}->{$paytypeGiropay} = C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled');    # GiroSolution payment service via giropay enabled or not
    $self->{girosolutionOpacPaymentsEnabled}->{$paytypeCreditcard} = C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled');    # GiroSolution payment service via credit card enabled or not
    $self->{girosolutionMerchantId} = C4::Context->preference('GirosolutionMerchantId');    # the library's GiroSolution merchant ID (refers to library, not to township)
    $self->{girosolutionProjectId}->{$paytypeGiropay} = C4::Context->preference('GirosolutionGiropayProjectId');    # the library's GiroSolution 'Project ID' for GiroPay payments (refers to payment method)
    $self->{girosolutionProjectId}->{$paytypeCreditcard} = C4::Context->preference('GirosolutionCreditcardProjectId');    # the library's GiroSolution 'Project ID' for credit card payments (refers to payment method)
    $self->{girosolutionProjectPwd}->{$paytypeGiropay} = C4::Context->preference('GirosolutionGiropayProjectPwd');    # the library's GiroSolution project password for GiroPay payments
    $self->{girosolutionProjectPwd}->{$paytypeCreditcard} = C4::Context->preference('GirosolutionCreditcardProjectPwd');    # the library's GiroSolution project password for credit card payments
    $self->{girosolutionRemittanceInfo} = C4::Context->preference('GirosolutionRemittanceInfo');    # Text pattern for 'remittance information' (Verwendungszweck), supports placeholder <<borrowers.cardnumber>>. (maximum length: 27 characters; permitted characters: a-z A-Z 0-9 ':?,-(+.)/)

    $self->{opac_base_url} = C4::Context->preference('OPACBaseURL');    # The GiroSolution software seems to work only with https URL (not with http).

    $self->{logger}->debug("getSystempreferences() END girosolutionOpacPaymentsEnabled->{$paytypeGiropay}:$self->{girosolutionOpacPaymentsEnabled}->{$paytypeGiropay}: ->{$paytypeCreditcard}:$self->{girosolutionOpacPaymentsEnabled}->{$paytypeCreditcard}: girosolutionMerchantId:$self->{girosolutionMerchantId}:");
}

sub getProjectId {
    my $self = shift;
    my $retProjectId = 'undef';

    if ( $self->{paytype} && $self->{girosolutionProjectId}->{$self->{paytype}} ) {
        $retProjectId = $self->{girosolutionProjectId}->{$self->{paytype}};
    }
    $self->{logger}->debug("getProjectId() paytype:$self->{paytype}: returns retProjectId:$retProjectId:");
    return $retProjectId;
}

sub getProjectPwd {
    my $self = shift;
    my $retProjectPwd = 'undef';

    if ( $self->{paytype} && $self->{girosolutionProjectPwd}->{$self->{paytype}} ) {
        $retProjectPwd = $self->{girosolutionProjectPwd}->{$self->{paytype}};
    }
    $self->{logger}->debug("getProjectPwd() paytype:$self->{paytype}: returns retProjectPwd:$retProjectPwd:");
    return $retProjectPwd;
}

sub calculateHashVal {
    my $self = shift;
    my $timestamp = shift;

    $self->{logger}->debug("calculateHashVal() START self->{now}:$self->{now}: timestamp:$timestamp:");

    my $tsMDY = $timestamp->mdy;
    my $tsDMY = $timestamp->dmy;
    my $key = $self->getProjectPwd();
    my $borrowernumber = $self->{patron}->borrowernumber();
    my $paytype = $self->{paytype};
    my $amount_to_pay = $self->{amount_to_pay};

    my $merchantTxIdKey = $tsMDY . $key . $tsDMY . $key . $borrowernumber . $paytype . '_' . $amount_to_pay . '_' . $paytype . $borrowernumber . $key . $tsDMY . $key . $tsMDY;
    my $merchantTxIdVal = $borrowernumber . '_' . $amount_to_pay;
    foreach my $accountlinesId ( @{$self->{accountlinesIds}} ) {
        $merchantTxIdVal .= '_' . $accountlinesId;
    }
    $merchantTxIdVal .= '_' . $self->{paytype};
    $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;

    my $merchantTxId = $self->genHmacMd5($merchantTxIdKey, $merchantTxIdVal);    # unique merchant transaction ID (this MD5 sum is used to check integrity of Koha CGI parameters in opac-account-pay-girosolution-message.pl)

    $self->{logger}->debug("calculateHashVal() returns merchantTxId:$merchantTxId:");
    return ( $merchantTxId );
}

# init payment and return the GiroPay or CreditCard URL delivered in the response
sub initPayment {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retGirosolutionRedirectUrl = '';
    my $girosolutionmsg = '';

    # URL of endpoint for for payment initialization
    my $initPaymentUrl = $self->{girosolutionWebservicesURL};    # init payment (https://payment.girosolution.de/girocheckout/api/v2/transaction/start)

    # set all required request params
    my $merchantId = $self->{girosolutionMerchantId};
    my $projectId = $self->getProjectId();
    my $merchantTxId = $self->{merchantTxId};
    my $amount = $self->{amount_to_pay} * 100;    # not Euro but Cent are required
    my $currency = 'EUR';
    my $purpose = $self->createRemittanceInfoText( $self->{girosolutionRemittanceInfo}, $self->{patron}->cardnumber() );    # Remittance info text will be displayed during giropay action. This field accepts only characters conforming to SEPA, i.e.: a-z A-Z 0-9 ' : ? , - ( + . ) /

    my $messageUrl = URI->new( $self->{opac_base_url} . "/cgi-bin/koha/opac-account-pay-girosolution-message.pl" );
    # set URL query arguments
    $messageUrl->query_form(
        {
            amountKoha => $self->{amount_to_pay},
            accountlinesKoha => $self->{accountlinesIds},
            borrowernumberKoha => $self->{patron}->borrowernumber(),
            paytypeKoha => $self->{paytype}    # 1: giropay   11: creditcard
        }
    );

    my $returnUrl = URI->new( $self->{opac_base_url} . "/cgi-bin/koha/opac-account-pay-girosolution-return.pl" );
    # set URL query arguments
    $returnUrl->query_form(
        {
            amountKoha => $self->{amount_to_pay},
            accountlinesKoha => $self->{accountlinesIds},
            borrowernumberKoha => $self->{patron}->borrowernumber(),
            paytypeKoha => $self->{paytype}    # 1: giropay   11: creditcard
        }
    );

    my $urlNotify = $messageUrl->as_string();    # uri_escape_utf8($messageUrl->as_string()) not accepted
    my $urlRedirect = $returnUrl->as_string();    # uri_escape_utf8($returnUrl->as_string()) not accepted

    my $paramstr = 
        $merchantId .
        $projectId .
        $merchantTxId .
        $amount .
        $currency .
        $purpose .
        $urlRedirect .
        $urlNotify;

    my $key = $self->getProjectPwd();
    my $hashval = $self->genHmacMd5($key, $paramstr);
    $self->{logger}->debug("initPayment() paramstr:$paramstr: hashval:$hashval:");

    my $requestParams = {
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

    $self->{logger}->debug("initPayment() is calling POST initPaymentUrl:$initPaymentUrl: requestParams:" . Dumper($requestParams) . ":");
    my $response = $self->{ua}->request( POST $initPaymentUrl, $requestParams );
    $self->{logger}->debug("initPayment() response:" . Dumper($response) . ":");

    if ($response ) {
        if ( $response->is_success ) {
            my $responseHeaderHash = $response->headers->header('hash');
            $self->{logger}->debug("initPayment() response->content:" . Dumper($response->content) . ":");
            if ( $response->content() ) {
                my $content = Encode::decode("utf8", $response->content);
                my $compHash = $self->genHmacMd5($key, $content);
                my $contentJson = from_json( $content );
                $self->{logger}->debug("initPayment() responseHeaderHash:$responseHeaderHash: contentJson:" . Dumper($contentJson) . ":");
                if ( $responseHeaderHash && $contentJson && defined($contentJson->{rc}) ) {
                    $self->{logger}->debug("initPayment() responseHeaderHash:$responseHeaderHash: compHash:$compHash: contentJson->{rc}:$contentJson->{rc}:");

                    if ( $responseHeaderHash eq $compHash && $contentJson->{rc} eq '0' ) {
                        $retError = 0;
                        $retGirosolutionRedirectUrl = $contentJson->{redirect};
                    }
                }
                if ( ! $retGirosolutionRedirectUrl ) {
                    $girosolutionmsg = " content:" . Dumper($response->content());
                    $retError = 22;
                    $retErrorTemplate = 'GIROSOLUTION_ERROR_PROCESSING';
                }
            }
        }
        if ( ! $retGirosolutionRedirectUrl && $retError == 0) {
            $girosolutionmsg = "response_rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
            $retError = 23;
            if ( $response->is_success ) {
                $retErrorTemplate = 'GIROSOLUTION_ERROR_PROCESSING';
            } else {
                $retErrorTemplate = 'GIROSOLUTION_UNABLE_TO_CONNECT';
            }
        }
        if ( $girosolutionmsg ) {
            my $mess = "initPayment() girosolutionmsg:" . $girosolutionmsg . ":";
            $self->{logger}->error($mess);
            carp ('GiroSolution:' . $mess . "\n");
        }
    }

    $self->{logger}->debug("initPayment() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retGirosolutionRedirectUrl:$retGirosolutionRedirectUrl:");
    return ( $retError, $retErrorTemplate, $retGirosolutionRedirectUrl );
}

# verify online payment by calling the webservice to check the transaction status and, if paid, also 'pay' the accountlines in Koha
sub checkOnlinePaymentStatusAndPayInKoha {
    my $self = shift;
    my $cgi = shift;
    my $retError = 0;
    my $retKohaPaymentId;
    my $girosolutionmsg = '';

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() START cgi:" . Dumper($cgi) . ":");

    # Params set by Koha in GiroSolution::initPayment() are sent as URL query arguments.
    # Already used in constructor: $cgi->param('borrowernumberKoha') $cgi->param('amountKoha') and $cgi->param('accountlinesKoha') and and $cgi->param('paytypeKoha');;

    # Params set by girocheckout are sent as added URL query arguments.
    my $gcReference      = $cgi->param('gcReference');
    my $gcMerchantTxId   = $cgi->param('gcMerchantTxId');
    my $gcBackendTxId    = $cgi->param('gcBackendTxId');
    my $gcAmount         = $cgi->param('gcAmount');
    my $gcCurrency       = $cgi->param('gcCurrency');
    my $gcResultPayment  = $cgi->param('gcResultPayment');
    my $gcHash           = $cgi->param('gcHash');

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() gcReference:$gcReference: gcMerchantTxId:$gcMerchantTxId:");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() gcBackendTxId:$gcBackendTxId: gcResultPayment:$gcResultPayment:");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() gcAmount:$gcAmount: gcCurrency:$gcCurrency:");

    my $projectPwd = $self->getProjectPwd();    # password of GiroSolution project for payment method GiroPay or payment method CreditCard

    # verify that the 6 CGI arguments of girocheckout are not manipulated
    my $hashesAreEqual = 0;
    my $paramstr = $gcReference . $gcMerchantTxId . $gcBackendTxId . $gcAmount . $gcCurrency . $gcResultPayment;
    my $compHash = $self->genHmacMd5($projectPwd, $paramstr);
    if ( $compHash eq $gcHash ) {
        $hashesAreEqual = 1;
    }
    $self->{logger}->trace("checkOnlinePaymentStatusAndPayInKoha() hashesAreEqual:" . $hashesAreEqual . ": paramstr:" . $paramstr . ": compHash:" . $compHash . ": gcHash:" . $gcHash . ":");

    # verify that the 4 CGI arguments of Koha are not manipulated, i.e. that txid is correct for the sent accountlines and amount of Koha
    my $txidsAreEqual = 0;
    my $now = $self->{now};
    my $calculatedHashVal = $self->calculateHashVal($now);
    $self->{logger}->trace("checkOnlinePaymentStatusAndPayInKoha() now:$now: calculatedHashVal:$calculatedHashVal: gcMerchantTxId:$gcMerchantTxId:");

    if ( $calculatedHashVal ne $gcMerchantTxId ) {    # last chance: Maybe it is a message created the day before. This case is relevant if a patron is paying at midnight.
        $now->subtract( days => 1 );
        $calculatedHashVal = $self->calculateHashVal($now);
        $self->{logger}->trace("checkOnlinePaymentStatusAndPayInKoha() yesterday:$now: calculatedHashVal:$calculatedHashVal: gcMerchantTxId:$gcMerchantTxId:");
    }
    if ( $calculatedHashVal eq $gcMerchantTxId ) {
        $txidsAreEqual = 1;
    }        

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() hashesAreEqual:$hashesAreEqual: ($gcHash eq $compHash ?):" . ($gcHash eq $compHash) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() txidsAreEqual:$txidsAreEqual: ($calculatedHashVal eq $gcMerchantTxId ?):" . ($calculatedHashVal eq $gcMerchantTxId) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() ($gcResultPayment == 4000 ?):" . ($gcResultPayment == 4000) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() ($self->{amount_to_pay} * 100.0):" . ($self->{amount_to_pay} * 100.0) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() ($gcAmount == $self->{amount_to_pay} * 100.0 ?):" . ($gcAmount == $self->{amount_to_pay} * 100.0) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() ($gcAmount == ($self->{amount_to_pay} * 100.0) ?):" . ($gcAmount == ($self->{amount_to_pay} * 100.0)) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() ($gcAmount/100.0 == $self->{amount_to_pay} ?):" . ($gcAmount/100.0 == $self->{amount_to_pay}) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() (roundGS($gcAmount/100.0,2) == roundGS($self->{amount_to_pay},2) ?):" . ($self->roundGS($gcAmount/100.0, 2) == $self->roundGS($self->{amount_to_pay}, 2)) . ":");

    if ( $hashesAreEqual && $txidsAreEqual && ($gcResultPayment == 4000) && ($self->roundGS($gcAmount/100.0, 2) == $self->roundGS($self->{amount_to_pay}, 2))  ) {
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() The hash values etc. are valid! External online payment succeeded, so we have to 'pay' the accountlines in Koha now.");

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
        $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding is also done in the complimentary verifyPaymentInKoha
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() sumAmountoutstanding:$sumAmountoutstanding: self->{amount_to_pay}:$self->{amount_to_pay}: gcAmount:$gcAmount:");

        # check if amount to pay is correct
        if ( $sumAmountoutstanding == $self->{amount_to_pay} ) {
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() will call account->pay()");

            my $descriptionText = 'Zahlung (GiroSolution)';    # should always be overwritten
            my $noteText = "Online-Zahlung $gcReference";    # should always be overwritten
            if ( $self->{paytype} == 1 ) {    # giropay
                $descriptionText = "Überweisung (GiroPay/GiroSolution)";
                $noteText = "Online-Überweisung $gcReference";
            } elsif ( $self->{paytype} == 11 ) {    # creditcard
                $descriptionText = "Kreditkarte (GiroSolution)";
                $noteText = "Online-Kreditkarte $gcReference";
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
            $retKohaPaymentId = $account->pay(
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
            $retError = 31;
            $girosolutionmsg = "NOT calling account->pay! sumAmountoutstanding (=$sumAmountoutstanding) != amount_to_pay (=$self->{amount_to_pay})";
        }
    } else {
        $retError = 32;
        $girosolutionmsg = "Error gcResultPayment:$gcResultPayment: hashesAreEqual:$hashesAreEqual: txidsAreEqual:$txidsAreEqual: gcAmount:$gcAmount: self->{amount_to_pay}:$self->{amount_to_pay}:";
        
    }

    if ( $girosolutionmsg ) {
        my $mess = "checkOnlinePaymentStatusAndPayInKoha() girosolutionmsg:" . $girosolutionmsg . ":";
        $self->{logger}->error($mess);
        carp ('GiroSolution:' . $mess . "\n");
    }

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() returns retError:$retError: retKohaPaymentId:$retKohaPaymentId:");
    return ( $retError, $retKohaPaymentId );
}

# verify that the accountlines have been 'paid' in Koha by opac-account-pay-girosolution-message.pl
sub verifyPaymentInKoha {
    my $self = shift;
    my $cgi = shift;
    my $retError = 0;
    my $retErrorTemplate = 'GIROSOLUTION_ERROR_PROCESSING';
    my $girosolutionmsg = '';

    $self->{logger}->debug("verifyPaymentInKoha() START cgi:" . Dumper($cgi) . ":");

    # Params set by Koha in GiroSolution::initPayment() are sent as URL query arguments.
    # Already used in constructor: $cgi->param('borrowernumberKoha') $cgi->param('amountKoha') and $cgi->param('accountlinesKoha') and and $cgi->param('paytypeKoha');;

    # Params set by girocheckout are sent as added URL query arguments.
    my $gcReference      = $cgi->param('gcReference');
    my $gcMerchantTxId   = $cgi->param('gcMerchantTxId');
    my $gcBackendTxId    = $cgi->param('gcBackendTxId');
    my $gcAmount         = $cgi->param('gcAmount');
    my $gcCurrency       = $cgi->param('gcCurrency');
    my $gcResultPayment  = $cgi->param('gcResultPayment');
    my $gcHash           = $cgi->param('gcHash');

    $self->{logger}->debug("verifyPaymentInKoha() gcReference:$gcReference: gcMerchantTxId:$gcMerchantTxId:");
    $self->{logger}->debug("verifyPaymentInKoha() gcBackendTxId:$gcBackendTxId: gcResultPayment:$gcResultPayment:");
    $self->{logger}->debug("verifyPaymentInKoha() gcAmount:$gcAmount: gcCurrency:$gcCurrency:");

    my $projectPwd = $self->getProjectPwd();    # password of GiroSolution project for payment method GiroPay or payment method CreditCard

    # verify that the 6 CGI arguments of girocheckout are not manipulated
    my $hashesAreEqual = 0;
    my $paramstr = $gcReference . $gcMerchantTxId . $gcBackendTxId . $gcAmount . $gcCurrency . $gcResultPayment;
    my $compHash = $self->genHmacMd5($projectPwd, $paramstr);
    if ( $compHash eq $gcHash ) {
        $hashesAreEqual = 1;
    }
    $self->{logger}->trace("verifyPaymentInKoha() hashesAreEqual:" . $hashesAreEqual . ": paramstr:" . $paramstr . ": compHash:" . $compHash . ": gcHash:" . $gcHash . ":");

    if ( $hashesAreEqual ) {
        # If external online payment has succeeded (i.e. $gcResultPayment == 4000) we have to check if the selected accountlines now are also paid in Koha (by opac-account-pay-girosolution-message.pl).
        if ( $gcResultPayment == 4000 ) {
            # There may be a concurrency with opac-account-pay-girosolution-message.pl (simultanously called by GiroSolution),
            # so we wait here for a certain maximum time to give opac-account-pay-girosolution-message.pl the chance to finish.
            # The 'certain maximum time' depends on the number of accountlines to be paid; it ranges from 5*2 to 5*4 seconds.
            my $waitSingleDuration = 2 + (scalar @{$self->{accountlinesIds}})/10;
            if ( $waitSingleDuration > 4 ) {
                $waitSingleDuration = 4;
            }
            for ( my $waitCount = 0; $waitCount < 6; $waitCount += 1 ) {
                my $account = Koha::Account->new( { patron_id => $self->{patron}->borrowernumber() } );
                my @lines = Koha::Account::Lines->search(
                    {
                        accountlines_id => { -in => $self->{accountlinesIds} }
                    }
                );

                my $sumAmountoutstanding = 0.0;
                foreach my $accountline ( @lines ) {
                    $self->{logger}->trace("verifyPaymentInKoha() accountline->{_result}->{_column_data}:" . Dumper($accountline->{_result}->{_column_data}) . ":");
                    $self->{logger}->debug("verifyPaymentInKoha() accountline->id:" . $accountline->accountlines_id() . ": ->amountoutstanding():" . $accountline->amountoutstanding() . ":");
                    $sumAmountoutstanding += $accountline->amountoutstanding();
                }
                $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding is also done in the complimentary checkOnlinePaymentStatusAndPayInKoha
                $self->{logger}->debug("verifyPaymentInKoha() sumAmountoutstanding:$sumAmountoutstanding: self->{amount_to_pay}:$self->{amount_to_pay}: gcAmount:$gcAmount:");

                # check if paid amount is correct
                if ( $sumAmountoutstanding == 0.00 ) {
                    $self->{logger}->debug("verifyPaymentInKoha() sumAmountoutstanding == 0.00 --- NO error!");
                    $retError = 0;
                    $retErrorTemplate = '';
                    $girosolutionmsg = '';
                    last;
                }
                $self->{logger}->debug("verifyPaymentInKoha() not all accountlines paid yet - now waiting $waitSingleDuration seconds and then checking again ...");
                $retError = 41;
                $girosolutionmsg =  " not all accountlines paid yet - now waiting $waitSingleDuration seconds and then checking again ...";
                sleep($waitSingleDuration);
            }
        } else {
            $retError = 42;
            $girosolutionmsg = " gcResultPayment:$gcResultPayment:";
            # XXXWH prepared for future use, when GIROSOLUTION_TIMEOUT and GIROSOLUTION_ABORTED_BY_USER are handled in the required tt-files
            #if ( $gcResultPayment == 4501 ) {    # timeout / no input by patron
            #    $retErrorTemplate = 'GIROSOLUTION_TIMEOUT';
            #} elsif ( $gcResultPayment == 4502 || $gcResultPayment == 4900 ) {    # patron aborted payment action
            #    $retErrorTemplate = 'GIROSOLUTION_ABORTED_BY_USER';
            #}
        }
    } else {
        $retError = 43;
        $girosolutionmsg = " hashesAreEqual:$hashesAreEqual: paramstr:$paramstr: compHash:$compHash: gcHash:$gcHash:";
    }

    if ( $girosolutionmsg ) {
        my $mess = "verifyPaymentInKoha() girosolutionmsg:" . $girosolutionmsg . ":";
        $self->{logger}->error($mess);
        carp ('GiroSolution:' . $mess . "\n");
    }

    $self->{logger}->debug("verifyPaymentInKoha() returns retError:$retError: retErrorTemplate:$retErrorTemplate:");
    return ( $retError, $retErrorTemplate );
}

# Init the payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, 
# extract the GiroSolution-GiroPay URL or GiroSolution-CreditCard URL delivered in its response.
# (The method paymentAction() exists only for formal reasons in this case, to match the pattern of the other epayment implementations. 
#  This would not be so if one would call initPayment() directly in opac-account-pay.pl. ) 
sub paymentAction {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retGirosolutionRedirectUrl = '';    # at the moment this may be set to the URL for giropay payment (selection of BIC) or the URL for credit card payment

    $self->{logger}->debug("paymentAction() START");

    ( $retError, $retErrorTemplate, $retGirosolutionRedirectUrl ) = $self->initPayment();

    $self->{logger}->debug("paymentAction() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retGirosolutionRedirectUrl:$retGirosolutionRedirectUrl:");
    return ( $retError, $retErrorTemplate, $retGirosolutionRedirectUrl );
}

1;
