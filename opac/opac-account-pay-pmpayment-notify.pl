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

use Modern::Perl;
use utf8;

use CGI;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI;
use Digest::SHA qw(hmac_sha256_hex);
use JSON;
use Encode;
use Data::Dumper;
use HTTP::Response;
use Carp;


use C4::Auth;
use C4::Output;
use C4::Accounts;
use C4::Context;
use C4::CashRegisterManagement;
use Koha::Database;
use Koha::Patrons;
use Koha::DateUtils;

my $httpResponseStatus = '400 Bad Request';    # default: Bad Request
my $cgi = new CGI;

my $kohaPaymentId;
my $key = 'dsTFshg5678DGHMO';    # dummy for wrong HMAC digest
sub genHmacSha256 {
    my ($key, $str) = @_;
    my $hashval = hmac_sha256_hex($str, $key);

    return $hashval;
}

# round float $flt to precision of $decimaldigits behind the decimal separator. E. g. roundGS(-1.234567, 2) == -1.23
sub roundGS ()
{
    my ($flt, $decimaldigits) = @_;
    my $decimalshift = 10 ** $decimaldigits;

    return (int(($flt * $decimalshift) + (($flt < 0) ? -0.5 : 0.5)) / $decimalshift);
}

my $loggerPmp = Koha::Logger->get({ interface => 'epayment.pmpayment' });
$loggerPmp->debug("opac-account-pay-pmpayment-notify.pl START cgi:" . Dumper($cgi) . ":");

if ( C4::Context->preference('PmpaymentPaypageOpacPaymentsEnabled') ) {
    my $procedure = C4::Context->preference('PmpaymentProcedure');    # Name des Verfahrens
    if ( ! $procedure ) {
        $procedure = 'KohaLMSCloud';
    }
    $key = C4::Context->preference('PmpaymentSaltHmacSha256');    # salt for generating HMAC SHA-256 digest
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl procedure:$procedure:");

    # params set by Koha in opac-account-pay.pl as URL query arguments
    my $amountKoha = $cgi->url_param('amountKoha');
    my @accountlinesKoha = $cgi->url_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->url_param('borrowernumberKoha');
    my $paytypeKoha = $cgi->url_param('paytypeKoha');

    # params set by pmPayment as POST HTML form arguments
    my $pmpAgs            = $cgi->param('ags');    # amtlicher Gemeinde-Schlüssel
    my $pmpTxid           = $cgi->param('txid');    # unique transaction ID
    my $pmpAmount         = $cgi->param('amount');    # amount to be paid in Eurocent
    my $pmpDesc           = $cgi->param('desc');    # SEPA-Verwendungszweck
    my $pmpStatus         = $cgi->param('status');    # generischer Buchungssatz für Stadtkasse
    my $pmpPayment_method = $cgi->param('payment_method') ? $cgi->param('payment_method') : '';# creditcard paydirect giropay paypal ...
    my $pmpProcedure      = $cgi->param('procedure');    # Name des Verfahrens
    my $pmpCreated_at     = $cgi->param('created_at');    # e.g. '2016-07-13 13:30:34'
#    my $pmpHash           = $cgi->param('hash');    # HMAC SHA-256 hash value (calculated on base of the parameter values above and $key)    # strangely this hash is not sent by pmPayment


    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl borrowernumberKoha:$borrowernumberKoha:");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl amountKoha:$amountKoha:");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl accountlinesKoha:" . Dumper(\@accountlinesKoha) . ":");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl paytypeKoha:$paytypeKoha:");

    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl pmpAgs:$pmpAgs: pmpTxid:$pmpTxid:");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl pmpAmount:$pmpAmount: pmpDesc:$pmpDesc:");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl pmpStatus:$pmpStatus: pmpPayment_method:$pmpPayment_method:");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl pmpProcedure:$pmpProcedure: pmpCreated_at:$pmpCreated_at:");
#    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl pmpHash:$pmpHash:");


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
#    my $hashval = genHmacSha256($key, $paramstr);
#    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl paramstr:" . $paramstr . ": hashval:" . $hashval . ": pmpHash:" . $pmpHash . ":");
#    if ( $hashval eq $pmpHash ) {
        $hashesAreEqual = 1;
#    }

    # verify that the 4 CGI arguments of Koha are not manipulated, i.e. that txid is correct for the sent accountlines and amount of Koha
    my $txidsAreEqual = 0;
    my $timestamp = @{[split(/\./, $pmpTxid)]}[1];
    my $now = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl now:$now: procedure:$procedure: timestamp:$timestamp:");
    my $todayMDY = $now->mdy;
    my $todayDMY = $now->dmy;
    my $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumberKoha . $paytypeKoha . '_' . $amountKoha . '_' . $paytypeKoha . $borrowernumberKoha . $key . $todayDMY . $key . $todayMDY;
    my $merchantTxIdVal = $borrowernumberKoha . '_' . $amountKoha;
    foreach my $accountline (@accountlinesKoha) {
        $merchantTxIdVal .= '_' . $accountline;
    }
    $merchantTxIdVal .= '_' . $paytypeKoha;
    $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;
    $loggerPmp->trace("opac-account-pay-pmpayment-notify.pl today merchantTxIdKey:$merchantTxIdKey:");
    $loggerPmp->trace("opac-account-pay-pmpayment-notify.pl today merchantTxIdVal:$merchantTxIdVal:");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl today pmpTxid:$pmpTxid: genHmacSha256:" . genHmacSha256($merchantTxIdKey, $merchantTxIdVal) . ":");
    if ( $procedure . '.' . $timestamp . '.' . genHmacSha256($merchantTxIdKey, $merchantTxIdVal) ne $pmpTxid ) {
        # Last chance: maybe it is a message created the day before. This case is relevant if a patron is paying at midnight.
        $now->subtract( days => 1 );
        $loggerPmp->trace("opac-account-pay-pmpayment-notify.pl yesterday:$now:");
        $todayMDY = $now->mdy;
        $todayDMY = $now->dmy;
        $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumberKoha . $paytypeKoha . '_' . $amountKoha . '_' . $paytypeKoha . $borrowernumberKoha . $key . $todayDMY . $key . $todayMDY;
        $loggerPmp->trace("opac-account-pay-pmpayment-notify.pl yesterday merchantTxIdKey:$merchantTxIdKey:");
        $loggerPmp->trace("opac-account-pay-pmpayment-notify.pl yesterday merchantTxIdVal:$merchantTxIdVal:");
        $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl yesterday pmpTxid:$pmpTxid: genHmacSha256:" . genHmacSha256($merchantTxIdKey, $merchantTxIdVal) . ":");
    }
    if ( $procedure . '.' . $timestamp . '.' . genHmacSha256($merchantTxIdKey, $merchantTxIdVal) eq $pmpTxid ) {
        $txidsAreEqual = 1;
    }

    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl pmpStatus equal 1? ($pmpStatus == 1):" . ($pmpStatus == 1) . ":");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl txidsAreEqual:" . $txidsAreEqual . ":");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl amountKoha:" . $amountKoha . ":");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl pmpAmount/100.0: ($pmpAmount/100.0):" . ($pmpAmount/100.0) . ":");
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl (roundGS($pmpAmount/100.0,2) == roundGS($amountKoha,2)):" . (&roundGS($pmpAmount/100.0, 2) == &roundGS($amountKoha, 2)) . ":");

    # If money transfer is signalled as successfull (i.e. $pmpStatus == 1) we have to check if this is true via <PmpaymentPaypageWebservicesURL>/payment/status/<ags>/<txid>
    if ( $pmpStatus == 1 && $hashesAreEqual && $txidsAreEqual && (&roundGS($pmpAmount/100.0, 2) == &roundGS($amountKoha, 2))) {
        my $pmpaymentWebserviceUrl = C4::Context->preference('PmpaymentPaypageWebservicesURL');    # test env: https://payment-test.itebo.de   production env: https://www.payment.govconnect.de
        my $ags = C4::Context->preference('PmpaymentAgs');    # mandatory; amtlicher Gemeinde-Schlüssel

        # check for payment status
        my $url = $pmpaymentWebserviceUrl . '/payment/status/' . $ags . '/' . $pmpTxid;

        # read status of this payment until it is '1' (success) or '0' (failure) - but maximal for 7 seconds
        my $paymentStatus = 'undef';    # 1: payment succeeded   0: payment failed   -1: payment in progress, not finished yet
        my $paymentTimestamp = '';

        my $starttime = time();

        while ( time() < $starttime + 7 ) {

            my $ua = LWP::UserAgent->new;
            $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl is calling GET url:$url:");
            my $response = $ua->request( GET $url );
            $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl response:" . Dumper($response) . ":");

            if ( $response && $response->is_success ) {
                my $content = Encode::decode("utf8", $response->content);
                my $contentJson = from_json( $content );
                $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl contentJson:" . Dumper($contentJson) . ":");

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
                        $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl nowDT:" . scalar $nowDT . ": thenDT:" . scalar $thenDT . ":  paymentTimestampDT:" . scalar $paymentTimestampDT . ":");
                        if ( $paymentTimestampDT < $thenDT ) {
                            $paymentStatus = '-2';    # timestamp of payment is too old to be trustworthy. Probably this is an attack.

                            my $mess = "opac-account-pay-pmpayment-notify.pl timestamp of payment is too old to be trustworthy. nowDT:" . scalar $nowDT . ": thenDT:" . scalar $thenDT . ":  paymentTimestampDT:" . scalar $paymentTimestampDT . ":";
                            $loggerPmp->error($mess);
                            carp $mess . "\n";
                        }
                        # $paymentStatus eq '1': looks good, we have to 'pay' the accountlines in Koha
                        # $paymentStatus eq '-2': timestamp of payment is too old to be trustworthy, so we do NOT 'pay' the accountlines. 
                        last;
                    }
                    if ( $paymentStatus eq '0' ) {
                        last;    # external online payment not successful, so we do NOT 'pay' the accountlines
                    }
                }
            }
            sleep(1);
        }

        $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl paymentStatus:$paymentStatus:");
        if ( $paymentStatus eq '1' ) {
            $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl External online payment succeeded, so we have to 'pay' the accountlines in Koha now.");

            my $account = Koha::Account->new( { patron_id => $borrowernumberKoha } );
            my @lines = Koha::Account::Lines->search(
                {
                    accountlines_id => { -in => \@accountlinesKoha }
                }
            );

            my $sumAmountoutstanding = 0.0;
            foreach my $accountline ( @lines ) {
                $loggerPmp->trace("opac-account-pay-pmpayment-notify.pl accountline->{_column_data}:" . Dumper($accountline->{_column_data}) . ":");
                $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl accountline->id:" . $accountline->accountlines_id() . ": ->amountoutstanding():" . $accountline->amountoutstanding() . ":");
                $sumAmountoutstanding += $accountline->amountoutstanding();
            }
            $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this roundig was also done in the complimentary opac-account-pay-pl
            $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl sumAmountoutstanding:$sumAmountoutstanding: amountKoha:$amountKoha: pmpAmount:$pmpAmount:");

            # check if paid amount is correct
            if ( $sumAmountoutstanding == $amountKoha ) {
                $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl will call account->pay()");

                my $descriptionText = 'Zahlung (pmPayment)';    # should always be overwritten
                my $noteText = "Online-Zahlung $pmpTxid";    # should always be overwritten
                if ( $paytypeKoha == 18 ) {    # paypage: giropay, paydirect, credit card, Lastschrift, ...
                    if ( $pmpPayment_method ) {
                        $descriptionText = $pmpPayment_method . " (pmPayment)";
                        $noteText = "Online ($pmpPayment_method) $pmpTxid";
                    } else {
                        $descriptionText = "Online-Zahlung (pmPayment)";
                        $noteText = "Online-Zahlung $pmpTxid";
                    }
                }
                $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl descriptionText:$descriptionText: noteText:$noteText:");

                # we take the borrowers branchcode also for the payment accountlines record to be created
                my $library_id = undef;
                my $patron = Koha::Patrons->find( $borrowernumberKoha );
                if ( $patron ) {
                    $library_id = $patron->branchcode();
                }
                $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl library_id:$library_id:");

                # evaluate configuration of cash register management for online payments
                my $withoutCashRegisterManagement = 1;    # default: avoiding cash register management in Koha::Account->pay()
                my $cash_register_manager_id = 0;    # borrowernumber of manager of cash register for online payments

                if ( C4::Context->preference("ActivateCashRegisterTransactionsOnly") ) {
                    my $paymentsOnlineCashRegisterName = C4::Context->preference('PaymentsOnlineCashRegisterName');
                    my $paymentsOnlineCashRegisterManagerCardnumber = C4::Context->preference('PaymentsOnlineCashRegisterManagerCardnumber');
                    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl paymentsOnlineCashRegisterName:$paymentsOnlineCashRegisterName: paymentsOnlineCashRegisterManagerCardnumber:$paymentsOnlineCashRegisterManagerCardnumber:");

                    if ( length($paymentsOnlineCashRegisterName) && length($paymentsOnlineCashRegisterManagerCardnumber) ) {
                        $withoutCashRegisterManagement = 0;

                        # get cash register manager information
                        my $cash_register_manager = Koha::Patrons->search( { cardnumber => $paymentsOnlineCashRegisterManagerCardnumber } )->next();
                        if ( $cash_register_manager ) {
                            $cash_register_manager_id = $cash_register_manager->borrowernumber();
                            my $cash_register_manager_branchcode = $cash_register_manager->branchcode();
                            $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl cash_register_manager_id:$cash_register_manager_id: cash_register_manager_branchcode:$cash_register_manager_branchcode:");
                            my $cash_register_mngmt = C4::CashRegisterManagement->new($cash_register_manager_branchcode, $cash_register_manager_id);

                            if ( $cash_register_mngmt ) {
                                my $cashRegisterNeedsToBeOpened = 1;
                                my $openedCashRegister = $cash_register_mngmt->getOpenedCashRegisterByManagerID($cash_register_manager_id);
                                if ( defined $openedCashRegister ) {
                                    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl cash_register_name:" . $openedCashRegister->{'cash_register_name'} . ":");
                                    if ($openedCashRegister->{'cash_register_name'} eq $paymentsOnlineCashRegisterName) {
                                        $cashRegisterNeedsToBeOpened = 0;
                                    } else {
                                        $cash_register_mngmt->closeCashRegister($openedCashRegister->{'cash_register_id'}, $cash_register_manager_id);
                                    }
                                }
                                if ( $cashRegisterNeedsToBeOpened ) {
                                    # try to open the specified cash register by name
                                    my $cash_register_id = $cash_register_mngmt->readCashRegisterIdByName($paymentsOnlineCashRegisterName);
                                    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl cash_register_id:$cash_register_id:");
                                    if ( defined $cash_register_id && $cash_register_mngmt->canOpenCashRegister($cash_register_id, $cash_register_manager_id) ) {
                                        my $opened = $cash_register_mngmt->openCashRegister($cash_register_id, $cash_register_manager_id);
                                        $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl cash_register_mngmt->openCashRegister($cash_register_manager_branchcode, $cash_register_manager_id) returned opened:$opened:");
                                    }
                                }
                            }
                        }
                    }
                }
                
                $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl withoutCashRegisterManagement:$withoutCashRegisterManagement: cash_register_manager_id:$cash_register_manager_id:");
                $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl now is calling account->pay()");
                $kohaPaymentId = $account->pay(
                    {
                        amount => $amountKoha,
                        lines => \@lines,
                        library_id => $library_id,
                        description => $descriptionText,
                        note => $noteText,
                        withoutCashRegisterManagement => $withoutCashRegisterManagement,
                        onlinePaymentCashRegisterManagerId => $cash_register_manager_id
                    }
                );
            } else {
                $loggerPmp->error("opac-account-pay-pmpayment-notify.pl is NOT calling account->pay! (sumAmountoutstanding(" . $sumAmountoutstanding . ") != amountKoha(" . $amountKoha . "))");
            }
        } else {
            $loggerPmp->error("opac-account-pay-pmpayment-notify.pl is NOT calling account->pay! paymentStatus:$paymentStatus:");
        }
    }


    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl kohaPaymentId:" . (defined($kohaPaymentId) ? $kohaPaymentId : 'undef') . ":");
    if ( $kohaPaymentId ) {
        $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl It seems that the external online payment and the Koha-payment have succeeded!");
        $httpResponseStatus = '200 OK';    # return statuscode '200 OK'
    } else {
        $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl It seems that the external online payment or the Koha-payment has NOT succeeded!");
        $httpResponseStatus = '400 Bad Request';    # return statuscode '400 Bad Request'
    }
    $loggerPmp->debug("opac-account-pay-pmpayment-notify.pl returns cgi with httpResponseStatus:" . $httpResponseStatus . ":");

    print $cgi->header( -status => $httpResponseStatus,
                        -charset => 'utf-8',
                      );
}
