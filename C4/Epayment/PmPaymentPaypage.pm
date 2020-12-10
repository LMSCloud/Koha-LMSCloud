package C4::Epayment::PmPaymentPaypage;

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
use Data::Dumper;

use Modern::Perl;
use CGI::Carp;
#use SOAP::Lite;
#use URI::Escape;
use JSON;
use Encode;
use HTTP::Request::Common;
use LWP::UserAgent;
#
use C4::Context;
#use C4::Koha;
#use Koha::Acquisition::Currencies;
#use Koha::Database;
use Koha::Patrons;
use Koha::DateUtils;

use C4::Epayment::EpaymentBase;
use parent qw(C4::Epayment::EpaymentBase);

sub new {
    my $class = shift;
    my $params = shift;
    my $loggerPmpayment = Koha::Logger->get({ interface => 'epayment.pmpayment' });

    my $self = {};
    bless $self, $class;
    $self = $self->SUPER::new();
    bless $self, $class;

    $self->{logger} = $loggerPmpayment;
    $self->{patron} = $params->{patron};
    $self->{amount_to_pay} = $params->{amount_to_pay};
    $self->{accountlinesIds} = $params->{accountlinesIds};    # ref to array containing the accountlines_ids of accountlines to be payed
    $self->{paytype} = $params->{paytype};    # always 18; may be interpreted as payment via pmPayment paypage
    $self->{seconds} = time();    # make payment trials for same accountlinesIds distinguishable
    
    $self->{logger}->debug("new() cardnumber:" . $self->{patron}->cardnumber() . ": amount_to_pay:" . $self->{amount_to_pay} . ": accountlinesIds:" . Dumper($self->{accountlinesIds}) . ":");
    $self->{logger}->trace("new()  Dumper(class):" . Dumper($class) . ":");

    $self->getSystempreferences();

#    my $authValues = GetAuthorisedValues("PAYMENT_ACCOUNTTYPE_MAPPING",0);    # must be differentiated for differing payment service providers
#    foreach my $authValue( @{$authValues} ) {
#        my @authLib = split( /\|/, $authValue->{lib} );
#        $self->{paymentAccounttypeMapping}->{$authValue->{authorised_value}}->{haushalt} = $authLib[0];
#        $self->{paymentAccounttypeMapping}->{$authValue->{authorised_value}}->{objektnummer} = $authLib[1];
#    };

    $self->{now} = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
    $self->{timestamp} = sprintf("%04d%02d%02d%02d%02d%02d%03d", $self->{now}->year, $self->{now}->month, $self->{now}->day, $self->{now}->hour, $self->{now}->minute, $self->{now}->second, $self->{now}->nanosecond/1000000);
    my $calculatedHashVal = $self->calculateHashVal($self->{now});
    if ( ! $self->{pmpaymentProcedure} ) {
        $self->{merchantTxId} = 'KohaLMSCloud' . '.' . $self->{timestamp} . '.' . $calculatedHashVal;
    } else {
        $self->{merchantTxId} = $self->{pmpaymentProcedure} . '.' . $self->{timestamp} . '.' . $calculatedHashVal;
    }

    $self->{ua} = LWP::UserAgent->new;

    $self->{logger}->debug("new() returns self:" . Dumper($self) . ":");
    return $self;
}

sub getSystempreferences {
    my $self = shift;

    $self->{logger}->debug("getSystempreferences() START");

    $self->{pmpaymentPaypageOpacPaymentsEnabled} = C4::Context->preference('PmpaymentPaypageOpacPaymentsEnabled');    # payment service pmPayment via paypage enabled or not
    $self->{pmpaymentPaypageWebservicesURL} = C4::Context->preference('PmpaymentPaypageWebservicesURL');    # test env: https://payment-test.itebo.de   production env: https://www.payment.govconnect.de
    $self->{pmpaymentAgs} = C4::Context->preference('PmpaymentAgs');    # mandatory; officiary municipal key (Amtlicher Gemeinde-Schlüssel)
    $self->{pmpaymentProcedure} = C4::Context->preference('PmpaymentProcedure');    # mandatory; procedure designation (Verfahrensname)
    $self->{pmpaymentSaltHmacSha256} = C4::Context->preference('PmpaymentSaltHmacSha256');    # salt for generating HMAC SHA-256 digest
    #$self->{pmpaymentSaltHmacSha256} = 'dsTFshg5678DGHMO';    # for test only: salt for wrong HMAC digest
    $self->{pmpaymentRemittanceInfo} = C4::Context->preference('PmpaymentRemittanceInfo');
    $self->{pmpaymentAccountingRecord} = C4::Context->preference('PmpaymentAccountingRecord');
    if ( ! defined($self->{pmpaymentAccountingRecord}) ) {
        $self->{pmpaymentAccountingRecord} = '';
    }
    $self->{opac_base_url} = C4::Context->preference('OPACBaseURL');    # The GiroSolution software seems to work only with https URL (not with http), and pmPayment uses GiroSolution software.

    $self->{logger}->debug("getSystempreferences() END pmpaymentPaypageWebservicesURL:$self->{pmpaymentPaypageWebservicesURL}: pmpaymentAgs:$self->{pmpaymentAgs}: pmpaymentProcedure:$self->{pmpaymentProcedure}:");
}

sub calculateHashVal {
    my $self = shift;
    my $timestamp = shift;

    $self->{logger}->debug("calculateHashVal() START self->{now}:$self->{now}:");

    my $tsMDY = $timestamp->mdy;
    my $tsDMY = $timestamp->dmy;
    my $key = $self->{pmpaymentSaltHmacSha256};
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

    my $merchantTxId = $self->genHmacSha256( $merchantTxIdVal, $merchantTxIdKey );    # unique merchant transaction ID (this hash value is used to check integrity of Koha CGI parameters in opac-account-pay-pmpayment-return.pl)

    $self->{logger}->debug("calculateHashVal() returns merchantTxId:$merchantTxId:");
    return ( $merchantTxId );
}

# init payment and return the paypage URL delivered in the response
sub initPayment {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retPmpaymentRedirectToPaypageUrl = '';
    my $pmpaymentmsg = '';

    my $amountInCent = $self->{amount_to_pay} * 100;      # not Euro but Cent are required
    my $desc = $self->createRemittanceInfoText( $self->{pmpaymentRemittanceInfo}, $self->{patron}->cardnumber() );    # Remittance info text will be displayed on paypage. This field accepts only characters conforming to SEPA, i.e.: a-z A-Z 0-9 ' : ? , - ( + . ) /
    my $accountingRecordCustomized = $self->{patron}->cardnumber() . $self->{pmpaymentAccountingRecord};


    # URL of endpoint for for payment initialization (variant: server-to-server)
    my $initPaymentUrl = $self->{pmpaymentPaypageWebservicesURL} . '/payment/secure';    # init payment via server to server communication

    my $notifyUrl = URI->new( $self->{opac_base_url} . "/cgi-bin/koha/opac-account-pay-pmpayment-notify.pl" );
    $notifyUrl->query_form(
        {
            amountKoha => $self->{amount_to_pay},
            accountlinesKoha => $self->{accountlinesIds},
            borrowernumberKoha => $self->{patron}->borrowernumber(),
            paytypeKoha => $self->{paytype}
        }
    );

    my $redirectUrl = URI->new( $self->{opac_base_url} . "/cgi-bin/koha/opac-account-pay-pmpayment-return.pl" );
    $redirectUrl->query_form(
        {
            amountKoha => $self->{amount_to_pay},
            accountlinesKoha => $self->{accountlinesIds},
            borrowernumberKoha => $self->{patron}->borrowernumber(),
            paytypeKoha => $self->{paytype}
        }
    );

    my $urlNotify = $notifyUrl->as_string();
    my $urlRedirect = $redirectUrl->as_string();

    my $paramstr =
        $self->{pmpaymentAgs} . '|' .
        $amountInCent . '|' .
        $self->{pmpaymentProcedure} . '|' .
        $desc . '|' .
        $accountingRecordCustomized . '|' .
        $self->{merchantTxId} . '|' .
        $urlNotify . '|' .
        $urlRedirect;

    my $hashval = $self->genHmacSha256($paramstr, $self->{pmpaymentSaltHmacSha256});
    $self->{logger}->debug("initPayment() paramstr:$paramstr: hashval:$hashval:");

    my $pmpaymentParams = [
        'ags' => $self->{pmpaymentAgs},    # mandatory; officiary municipal key (Amtlicher Gemeinde-Schlüssel)
        'amount' => $amountInCent,    # mandatory; amount to be paid, in Eurocent
        'procedure'  => $self->{pmpaymentProcedure},    # mandatory; procedure designation (Verfahrensname)
        'desc' => $desc,    # mandatory; remittance info text (SEPA-Verwendungszweck)
        'accountingRecord' => $accountingRecordCustomized,    # optional; text sent to financial accounting system of township (Generischer Buchungssatz für Stadtkasse)
        'txid' => $self->{merchantTxId},    # optional; unique transaction ID (unique for this ags or unique for this ags/procedure combination ?)
        'notifyURL' => $urlNotify,    # formally optional, but functionally indespensable; URL for 'Account->Pay' in Koha if success of online payment is signalled by HTML form parameter 'status'
        'redirectURL' => $urlRedirect,    # formally optional, but functionally indespensable; URL for returning to Koha OPAC irrespective of success or failure of online payment
        'hash' => $hashval    # mandatory; HMAC SHA-256 hash value (calculated on base of the parameter values above and $self->{pmpaymentSaltHmacSha256})
    ];

    $self->{logger}->debug("initPayment() is calling POST initPaymentUrl:$initPaymentUrl: pmpaymentParams:" . Dumper($pmpaymentParams) . ":");
    my $response = $self->{ua}->request( POST $initPaymentUrl, $pmpaymentParams );
    $self->{logger}->debug("initPayment() response:" . Dumper($response) . ":");

    if ($response ) {
        if ( $response->is_success ) {
            $self->{logger}->debug("initPayment() response->content:" . Dumper($response->content) . ":");
            if ( $response->content() ) {
                my $content = Encode::decode("utf8", $response->content);
                my $contentJson = from_json( $content );
                $self->{logger}->debug("initPayment() contentJson:" . Dumper($contentJson) . ":");
                if ( $contentJson ) {
                    if ( $contentJson->{url} && $contentJson->{txid} ) {
                        $retError = 0;
                        $retPmpaymentRedirectToPaypageUrl = $contentJson->{url};
                    }
                }
                if ( ! $retPmpaymentRedirectToPaypageUrl ) {
                    $pmpaymentmsg = " content:" . Dumper($response->content());
                    $retError = 22;
                    $retErrorTemplate = 'PMPAYMENT_ERROR_PROCESSING';
                }
            }
        }
        if ( ! $retPmpaymentRedirectToPaypageUrl && $retError == 0) {
            $pmpaymentmsg = "_rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
            $retError = 23;
            if ( $response->is_success ) {
                $retErrorTemplate = 'PMPAYMENT_ERROR_PROCESSING';
            } else {
                $retErrorTemplate = 'PMPAYMENT_UNABLE_TO_CONNECT';
            }
        }
        if ( $pmpaymentmsg ) {
            my $mess = "initPayment() pmpaymentmsg:" . $pmpaymentmsg . ":";
            $self->{logger}->error($mess);
            carp ('PmPaymentPaypage::' . $mess . "\n");
        }
    }

    $self->{logger}->debug("initPayment() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retPmpaymentRedirectToPaypageUrl:$retPmpaymentRedirectToPaypageUrl:");
    return ( $retError, $retErrorTemplate, $retPmpaymentRedirectToPaypageUrl );
}

# verify online payment by calling the webservice to check the transaction status and, if paid, also 'pay' the accountlines in Koha
sub checkOnlinePaymentStatusAndPayInKoha {
    my $self = shift;
    my $cgi = shift;
    my $retError = 0;
    my $retKohaPaymentId;
    my $pmpaymentmsg = '';

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() START cgi:" . Dumper($cgi) . ":");

    # Params set by Koha in opac-account-pay.pl and PmPaymentPaypage.pm are sent as URL query arguments.
    # Already used in constructor: $cgi->url_param('amountKoha') and $cgi->url_param('accountlinesKoha') and $cgi->url_param('borrowernumberKoha');

    # Params set by pmPayment are sent as as POST HTML form arguments.
    my $pmpAgs            = $cgi->param('ags');    # officiary municipal key (Amtlicher Gemeinde-Schlüssel)
    my $pmpTxid           = $cgi->param('txid');    # unique transaction ID
    my $pmpAmount         = $cgi->param('amount');    # amount to be paid, in Eurocent
    my $pmpDesc           = $cgi->param('desc');    # remittance info text (SEPA-Verwendungszweck)
    my $pmpStatus         = $cgi->param('status');    # text sent to financial accounting system of township (Generischer Buchungssatz für Stadtkasse)
    my $pmpPayment_method = $cgi->param('payment_method') ? $cgi->param('payment_method') : '';# creditcard paydirect giropay paypal ...
    my $pmpProcedure      = $cgi->param('procedure');    # procedure designation (Verfahrensname)
    my $pmpCreated_at     = $cgi->param('created_at');    # timestamp of payment action creation (e.g. '2016-07-13 13:30:34')
#    my $pmpHash           = $cgi->param('hash');    # HMAC SHA-256 hash value (calculated on base of the parameter values above and $self->{pmpaymentSaltHmacSha256})    # strangely this hash is not sent by pmPayment

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() pmpAgs:$pmpAgs: pmpTxid:$pmpTxid:");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() pmpAmount:$pmpAmount: pmpDesc:$pmpDesc:");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() pmpStatus:$pmpStatus: pmpPayment_method:$pmpPayment_method:");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() pmpProcedure:$pmpProcedure: pmpCreated_at:$pmpCreated_at:");
#    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() pmpHash:$pmpHash:");


#    # verify that the 8 CGI arguments of pmPayment are not manipulated    # of no use at the moment because hash is not sent by pmPayment
    my $hashesAreEqual = 0;
#    my $paramstr = 
#        $pmpAgs . '|' .
#        $pmpTxid . '|' .
#        $pmpAmount . '|' .
#        $pmpDesc . '|' .
#        $pmpStatus . '|' .
#        $pmpPayment_method . '|' .
#        $pmpProcedure . '|' .
#        $pmpCreated_at;
#
#    my $hashval = genHmacSha256($paramstr, $self->{pmpaymentSaltHmacSha256});
#    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl paramstr:" . $paramstr . ": hashval:" . $hashval . ": pmpHash:" . $pmpHash . ":");
#    if ( $hashval eq $pmpHash ) {
        $hashesAreEqual = 1;
#    }

    # verify that the 4 CGI arguments of Koha are not manipulated, i.e. that txid is correct for the sent accountlines and amount of Koha
    my $txidsAreEqual = 0;
    my $procedure = C4::Context->preference('PmpaymentProcedure');    # Name des Verfahrens
    if ( ! $procedure ) {
        $procedure = 'KohaLMSCloud';    # our fallback value, also used in new() for creating $self->{merchantTxId}
    }
    my $timestamp = @{[split(/\./, $pmpTxid)]}[1];
    my $now = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
    my $calculatedHashVal = $self->calculateHashVal($now);
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() now:$now: procedure:$procedure: timestamp:$timestamp: calculatedHashVal:$calculatedHashVal:");

    if ( $procedure . '.' . $timestamp . '.' . $calculatedHashVal ne $pmpTxid ) {
        # Last chance: maybe it is a message created the day before. This case is relevant if a patron is paying at midnight.
        $calculatedHashVal = $self->calculateHashVal($now);
        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() yesterday:$now: procedure:$procedure: timestamp:$timestamp: calculatedHashVal:$calculatedHashVal:");
    }
    if ( $procedure . '.' . $timestamp . '.' . $calculatedHashVal eq $pmpTxid ) {
        $txidsAreEqual = 1;
    }

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() pmpStatus equal 1? ($pmpStatus == 1):" . ($pmpStatus == 1) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() txidsAreEqual:" . $txidsAreEqual . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() self->{amount_to_pay}:" . $self->{amount_to_pay} . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() pmpAmount/100.0: ($pmpAmount/100.0):" . ($pmpAmount/100.0) . ":");
    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() (self->roundGS($pmpAmount/100.0, 2) == self->roundGS($self->{amount_to_pay},2)):" . ($self->roundGS($pmpAmount/100.0, 2) == $self->roundGS($self->{amount_to_pay}, 2)) . ":");

    # If online payment is signalled as successfull (i.e. $pmpStatus == 1),
    # we have to check if this is really true via <PmpaymentPaypageWebservicesURL>/payment/status/<ags>/<txid> .
    if ( $pmpStatus == 1 && $hashesAreEqual && $txidsAreEqual && ($self->roundGS($pmpAmount/100.0, 2) == $self->roundGS($self->{amount_to_pay}, 2))) {
        my $pmpaymentWebserviceUrl = C4::Context->preference('PmpaymentPaypageWebservicesURL');    # test env: https://payment-test.itebo.de   production env: https://www.payment.govconnect.de
        my $ags = C4::Context->preference('PmpaymentAgs');    # mandatory; amtlicher Gemeinde-Schlüssel

        # URL of endpoint for checking the payment action status (variant: server-to-server)
        my $checkPaymentStatusUrl = $self->{pmpaymentPaypageWebservicesURL} . '/payment/status/' . $ags . '/' . $pmpTxid;

        # read status of this payment until it is '1' (success) or '0' (failure) - but maximal for 7 seconds
        my $paymentStatus = 'undef';    # 1: payment succeeded   0: payment failed   -1: payment in progress, not finished yet
        my $paymentTimestamp = '';

        my $starttime = time();

        while ( time() < $starttime + 7 ) {

            # check for payment status by sending request to corresponding endpoint
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() is calling GET checkPaymentStatusUrl:$checkPaymentStatusUrl:");
            my $response = $self->{ua}->request( GET $checkPaymentStatusUrl );
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() response:" . Dumper($response) . ":");

            if ( $response ) {
                if ( $response->is_success ) {
                    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() response->content:" . Dumper($response->content) . ":");
                    if ( $response->content() ) {
                        my $content = Encode::decode("utf8", $response->content);
                        my $contentJson = from_json( $content );
                        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() contentJson:" . Dumper($contentJson) . ":");
                        if ( $contentJson ) {
                            if ( $contentJson->{status} && $contentJson->{timestamp} ) {
                                $paymentStatus = $contentJson->{status};
                                $paymentTimestamp = $contentJson->{timestamp};
                                if ( $paymentStatus eq '1' ) {
                                    # check if timestamp of payment is too old to be trustworthy
                                    # We can not be very strict here as
                                    #   A) configured timezones in Koha and pmPayment may be differing
                                    #   B) pmPayment sets the timestamp at the moment when the payment starts. But nobody knows when the payer is finished
                                    # So we allow for a huge (nominal) 4 hours difference.
                                    my $paymentTimestampDT = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
                                    $paymentTimestampDT = dt_from_string($paymentTimestamp);
                                    my $nowDT = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
                                    my $thenDT = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
                                    $thenDT = $thenDT->subtract( hours => 4 );
                                    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() nowDT:" . scalar $nowDT . ": thenDT:" . scalar $thenDT . ":  paymentTimestampDT:" . scalar $paymentTimestampDT . ":");
                                    if ( $paymentTimestampDT < $thenDT ) {
                                        $paymentStatus = '-2';    # timestamp of payment is too old to be trustworthy. Probably this is an attack.

                                        $retError = 310;
                                        $pmpaymentmsg = "timestamp of payment is too old to be trustworthy. nowDT:" . scalar $nowDT . ": thenDT:" . scalar $thenDT . ":  paymentTimestampDT:" . scalar $paymentTimestampDT . ":";
                                    } else {
                                        $retError = 0;
                                        $pmpaymentmsg = '';
                                    }
                                    # $paymentStatus eq '1': looks good, we have to 'pay' the accountlines in Koha
                                    # $paymentStatus eq '-2': timestamp of payment is too old to be trustworthy, so we do NOT 'pay' the accountlines. 
                                    last;
                                }
                                if ( $paymentStatus eq '0' ) {
                                    $retError = 311;
                                    $pmpaymentmsg = "paymentStatus:$paymentStatus:";
                                    last;    # external online payment not successful, so we do NOT 'pay' the accountlines
                                }
                                $retError = 312;
                                $pmpaymentmsg = "paymentStatus:$paymentStatus: paymentTimestamp:$paymentTimestamp:";
                            }
                        }
                        $retError = 313;
                        $pmpaymentmsg = "response->content():" . $response->content() . ":";
                    }    # end: if ( $response->content() )
                    $retError = 314;
                    $pmpaymentmsg = "response->content() is empty or undef";
                } else {
                    $retError = 315;
                    $pmpaymentmsg = "_rc:" . $response->{_rc} . ": _msg:" . $response->{_msg} . ":";
                }    # end: if ( $response->is_success )
            } else {
                $retError = 316;
                $pmpaymentmsg = "response is empty or undef";
            }    # end: if ( $response )
            sleep(1);
        }

        $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() paymentStatus:$paymentStatus:");
        if ( $paymentStatus eq '1' ) {
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() External online payment succeeded, so we have to 'pay' the accountlines in Koha now.");

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
            $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding was also done in the complimentary opac-account-pay-pl
            $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() sumAmountoutstanding:$sumAmountoutstanding: self->{amount_to_pay}:$self->{amount_to_pay}: pmpAmount:$pmpAmount:");

            # check if paid amount is correct
            if ( $sumAmountoutstanding == $self->{amount_to_pay} ) {
                $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() will call account->pay()");

                my $descriptionText = 'Zahlung (pmPayment)';    # should always be overwritten
                my $noteText = "Online-Zahlung $pmpTxid";    # should always be overwritten
                if ( $self->{paytypeKoha} == 18 ) {    # paypage: giropay, paydirect, credit card, Lastschrift, ...
                    if ( $pmpPayment_method ) {
                        $descriptionText = $pmpPayment_method . " (pmPayment)";
                        $noteText = "Online ($pmpPayment_method) $pmpTxid";
                    } else {
                        $descriptionText = "Online-Zahlung (pmPayment)";
                        $noteText = "Online-Zahlung $pmpTxid";
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
                $retError = 317;
                $pmpaymentmsg = "NOT calling account->pay! sumAmountoutstanding (=$sumAmountoutstanding) != amount_to_pay (=$self->{amount_to_pay})";
            }
        } else {
            $retError = 318;
            $pmpaymentmsg = "NOT calling account->pay! paymentStatus:$paymentStatus:";
        }
    } else {
        $retError = 319;
        $pmpaymentmsg = "Error pmpStatus:$pmpStatus: hashesAreEqual:$hashesAreEqual: txidsAreEqual:$txidsAreEqual: pmpAmount:$pmpAmount: self->{amount_to_pay}:$self->{amount_to_pay}:";
        
    }
    if ( $pmpaymentmsg ) {
        my $mess = "checkOnlinePaymentStatusAndPayInKoha() pmpaymentmsg:" . $pmpaymentmsg . ":";
        $self->{logger}->error($mess);
        carp ('PmPaymentPaypage::' . $mess . "\n");
    }

    $self->{logger}->debug("checkOnlinePaymentStatusAndPayInKoha() returns retError:$retError: retKohaPaymentId:$retKohaPaymentId:");
    return ( $retError, $retKohaPaymentId );
}

# verify that the accountlines have been 'paid' in Koha by opac-account-pay-pmpayment-notify.pl
sub verifyPaymentInKoha {
    my $self = shift;
    my $cgi = shift;
    my $retError = 0;
    my $retErrorTemplate = 'PMPAYMENT_ERROR_PROCESSING';
    my $pmpaymentmsg = '';

    $self->{logger}->debug("verifyPaymentInKoha() START cgi:" . Dumper($cgi) . ":");

    # Params set by Koha in opac-account-pay.pl and PmPaymentPaypage.pm are sent as URL query arguments.
    # Already used in constructor: $cgi->url_param('amountKoha') and $cgi->url_param('accountlinesKoha') and $cgi->url_param('borrowernumberKoha');

    # Params set by pmPayment are sent as as POST HTML form arguments.
    my $pmpAgs            = $cgi->param('ags');    # officiary municipal key (Amtlicher Gemeinde-Schlüssel)
    my $pmpTxid           = $cgi->param('txid');    # unique transaction ID
    my $pmpAmount         = $cgi->param('amount');    # amount to be paid, in Eurocent
    my $pmpDesc           = $cgi->param('desc');    # remittance info text (SEPA-Verwendungszweck)
    my $pmpStatus         = $cgi->param('status');    # text sent to financial accounting system of township (Generischer Buchungssatz für Stadtkasse)
    my $pmpPayment_method = $cgi->param('payment_method') ? $cgi->param('payment_method') : '';# creditcard paydirect giropay paypal ...
    my $pmpProcedure      = $cgi->param('procedure');    # procedure designation (Verfahrensname)
    my $pmpCreated_at     = $cgi->param('created_at');    # timestamp of payment action creation (e.g. '2016-07-13 13:30:34')
    my $pmpHash           = $cgi->param('hash');    # HMAC SHA-256 hash value (calculated on base of the parameter values above and $self->{pmpaymentSaltHmacSha256})

    $self->{logger}->debug("verifyPaymentInKoha() pmpAgs:$pmpAgs: pmpTxid:$pmpTxid:");
    $self->{logger}->debug("verifyPaymentInKoha() pmpAmount:$pmpAmount: pmpDesc:$pmpDesc:");
    $self->{logger}->debug("verifyPaymentInKoha() pmpStatus:$pmpStatus: pmpPayment_method:$pmpPayment_method:");
    $self->{logger}->debug("verifyPaymentInKoha() pmpProcedure:$pmpProcedure: pmpCreated_at:$pmpCreated_at:");
    $self->{logger}->debug("verifyPaymentInKoha() pmpHash:$pmpHash:");

    # verify that the 7 CGI arguments of pmPayment are not manipulated
    my $hashesAreEqual = 0;
    my $paramstr = 
        $pmpAgs . '|' .
        $pmpTxid . '|' .
        $pmpAmount . '|' .
        $pmpDesc . '|' .
        $pmpStatus . '|' .
        $pmpPayment_method . '|' .
        $pmpCreated_at;

    my $hashval = $self->genHmacSha256($paramstr, $self->{pmpaymentSaltHmacSha256});
    if ( $hashval eq $pmpHash ) {
        $hashesAreEqual = 1;
    }
    $self->{logger}->debug("verifyPaymentInKoha() hashesAreEqual:$hashesAreEqual: paramstr:$paramstr: hashval:$hashval: pmpHash:$pmpHash:");


    # If online payment has succeeded (i.e. $pmpStatus == 1) we have to check if the selected accountlines now are also paid in Koha.
    if ( $hashesAreEqual ) {
        if ( $pmpStatus == 1 ) {
            # There may be a concurrency with opac-account-pay-pmpayment-notify.pl (simultanously called by pmPayment),
            # so we wait here for a certain maximum time to give opac-account-pay-pmpayment-notify.pl the opportunity to completely execute its required action.
            # The 'certain maximum time' depends on the number of accountlines to be paid; it ranges from 5*2 to 5*4 seconds.
            my $waitSingleDuration = 2 + scalar(@{$self->{accountlinesIds}})/10;
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
                $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding was also done in the complimentary opac-account-pay-pl
                $self->{logger}->debug("verifyPaymentInKoha() sumAmountoutstanding:$sumAmountoutstanding: self->{amount_to_pay}:$self->{amount_to_pay}: pmpAmount:$pmpAmount:");

                if ( $sumAmountoutstanding == 0.00 ) {
                    $self->{logger}->debug("verifyPaymentInKoha() sumAmountoutstanding == 0.00 --- NO error!");
                    $retError = 0;
                    $retErrorTemplate = '';
                    $pmpaymentmsg = '';
                    last;
                }
                $self->{logger}->debug("verifyPaymentInKoha() not all accountlines paid - now waiting $waitSingleDuration seconds and then trying again ...");
                $retError = 41;
                $pmpaymentmsg =  " not all accountlines paid - now waiting $waitSingleDuration seconds and then trying again ...";
                sleep($waitSingleDuration);
            }
        } elsif ( $pmpStatus == 0 && $pmpPayment_method eq '' ) {    # patron aborted pmpayment paypage
            $retErrorTemplate = "PMPAYMENT_ABORTED_BY_USER";
        } else {
            $retError = 42;
            $pmpaymentmsg = " pmpStatus:$pmpStatus: pmpPayment_method:$pmpPayment_method:";
        }
    } else {
        $retError = 43;
        $pmpaymentmsg = " hashesAreEqual:$hashesAreEqual: paramstr:$paramstr: hashval:$hashval: pmpHash:$pmpHash:";
    }

    if ( $pmpaymentmsg ) {
        my $mess = "verifyPaymentInKoha() pmpaymentmsg:" . $pmpaymentmsg . ":";
        $self->{logger}->error($mess);
        carp ("PmPaymentPaypage::" . $mess . "\n");
    }

    $self->{logger}->debug("verifyPaymentInKoha() returns retError:$retError: retErrorTemplate:$retErrorTemplate:");
    return ( $retError, $retErrorTemplate );
}

# init the payment action by sending the required HTML form to the configured endpoint, and then, if succeeded, extract the pmPayment paypage URL delivered in its response
# (The method paymentAction() exists only for formal reasons in this case, to match the pattern of the other epayment implementations. 
#  This would not be so if one would call initPayment() directly in opac-account-pay.pl. ) 
sub paymentAction {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retPmpaymentRedirectToPaypageUrl = '';

    $self->{logger}->debug("paymentAction() START");

    ( $retError, $retErrorTemplate, $retPmpaymentRedirectToPaypageUrl ) = $self->initPayment();

    $self->{logger}->debug("paymentAction() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retPmpaymentRedirectToPaypageUrl:$retPmpaymentRedirectToPaypageUrl:");
    return ( $retError, $retErrorTemplate, $retPmpaymentRedirectToPaypageUrl );
}

1;
