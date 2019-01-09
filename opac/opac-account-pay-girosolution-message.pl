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
use Data::Dumper;    # XXXWH
use HTTP::Response;

use C4::Auth;
use C4::Output;
use C4::Accounts;
use C4::Context;
use C4::CashRegisterManagement;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Patrons;

my $httpResponseStatus = '400 Bad Request';    # default: Bad Request
my $cgi = new CGI;

my $key = 'XsTFshg4321DGHMX';    # dummy for wrong HMAC md5sum
sub genHmacMd5 {
    my ($key, $str) = @_;
    my $hmac_md5 = Digest->HMAC_MD5($key);
    $hmac_md5->add($str);
    my $hashval = $hmac_md5->hexdigest();

    return $hashval;
}

print STDERR "opac-account-pay-girosolution-message.pl: START\n";

if ( C4::Context->preference('GirosolutionCreditcardOpacPaymentsEnabled') || C4::Context->preference('GirosolutionGiropayOpacPaymentsEnabled') ) {
    #print STDERR "opac-account-pay-girosolution-message.pl: cgi:", Dumper($cgi), "\n";    # XXXWH

    # params set by Koha in opac-account-pay.pl
    my $amountKoha = $cgi->param('amountKoha');
    my @accountlinesKoha = $cgi->multi_param('accountlinesKoha');
    my $borrowernumberKoha = $cgi->param('borrowernumberKoha');
    my $paytypeKoha = $cgi->param('paytypeKoha');

    # params set by girocheckout
    my $gcReference      = $cgi->param('gcReference');
    my $gcMerchantTxId   = $cgi->param('gcMerchantTxId');
    my $gcBackendTxId    = $cgi->param('gcBackendTxId');
    my $gcAmount         = $cgi->param('gcAmount');
    my $gcCurrency       = $cgi->param('gcCurrency');
    my $gcResultPayment  = $cgi->param('gcResultPayment');
    my $gcHash           = $cgi->param('gcHash');

print STDERR "opac-account-pay-girosolution-message.pl: amountKoha:$amountKoha:\n";
print STDERR "opac-account-pay-girosolution-message.pl: accountlinesKoha:", Dumper(\@accountlinesKoha), ":\n";
print STDERR "opac-account-pay-girosolution-message.pl: borrowernumberKoha:$borrowernumberKoha:\n";
print STDERR "opac-account-pay-girosolution-message.pl: paytypeKoha:$paytypeKoha:\n";

print STDERR "opac-account-pay-girosolution-message.pl: gcReference:$gcReference: gcMerchantTxId:$gcMerchantTxId:\n";
print STDERR "opac-account-pay-girosolution-message.pl: gcBackendTxId:$gcBackendTxId: gcResultPayment:$gcResultPayment:\n";
print STDERR "opac-account-pay-girosolution-message.pl: gcAmount:$gcAmount: gcCurrency:$gcCurrency:\n";

    my $merchantId = C4::Context->preference('GirosolutionMerchantId');
    my $projectId = '';
    if ( $paytypeKoha == 1 ) {
        $projectId = C4::Context->preference('GirosolutionGiropayProjectId');    # GiroSolution 'Project ID' for payment method GiroPay
        $key = C4::Context->preference('GirosolutionGiropayProjectPwd');    # password of GiroSolution project for payment method GiroPay
    } elsif ( $paytypeKoha == 11 ) {
        $projectId = C4::Context->preference('GirosolutionCreditcardProjectId');    # GiroSolution 'Project ID' for payment method CreditCard
        $key = C4::Context->preference('GirosolutionCreditcardProjectPwd');    # password of GiroSolution project for payment method CreditCard
    }

    # verify that the 6 CGI arguments of girocheckout are not manipulated
    my $compHash = genHmacMd5($key, $gcReference . $gcMerchantTxId . $gcBackendTxId . $gcAmount . $gcCurrency . $gcResultPayment);

print STDERR "opac-account-pay-girosolution-message.pl:   gcHash:$gcHash:\n";
print STDERR "opac-account-pay-girosolution-message.pl: compHash:$compHash:\n";

    # verify that the 4 CGI arguments of Koha are not manipulated
    my $now = DateTime->now( time_zone => C4::Context->tz() );
print STDERR "opac-account-pay-girosolution-message.pl now:$now:\n";
    my $todayMDY = $now->mdy;
    my $todayDMY = $now->dmy;
    my $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumberKoha . $paytypeKoha . '_' . $amountKoha . '_' . $paytypeKoha . $borrowernumberKoha . $key . $todayDMY . $key . $todayMDY;
    my $merchantTxIdVal = $borrowernumberKoha . '_' . $amountKoha;
    foreach my $accountline (@accountlinesKoha) {
        $merchantTxIdVal .= '_' . $accountline;
    }
    $merchantTxIdVal .= '_' . $paytypeKoha;
    $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;
print STDERR "opac-account-pay-girosolution-message.pl merchantTxIdKey:$merchantTxIdKey:\n";
print STDERR "opac-account-pay-girosolution-message.pl merchantTxIdVal:$merchantTxIdVal:\n";
print STDERR "opac-account-pay-girosolution-message.pl gcMerchantTxId:$gcMerchantTxId: genHmacMd5:", genHmacMd5($merchantTxIdKey, $merchantTxIdVal), ":\n";
    if ( genHmacMd5($merchantTxIdKey, $merchantTxIdVal) ne $gcMerchantTxId ) {    # last chance: maybe it is a message created the day before
        $now->subtract( days => 1 );
print STDERR "opac-account-pay-girosolution-message.pl yesterday:$now:\n";
        $todayMDY = $now->mdy;
        $todayDMY = $now->dmy;
        $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumberKoha . $paytypeKoha . '_' . $amountKoha . '_' . $paytypeKoha . $borrowernumberKoha . $key . $todayDMY . $key . $todayMDY;
print STDERR "opac-account-pay-girosolution-message.pl merchantTxIdKey:$merchantTxIdKey:\n";
print STDERR "opac-account-pay-girosolution-message.pl merchantTxIdVal:$merchantTxIdVal:\n";
print STDERR "opac-account-pay-girosolution-message.pl gcMerchantTxId:$gcMerchantTxId: genHmacMd5:", genHmacMd5($merchantTxIdKey, $merchantTxIdVal), ":\n";
    }
        

print STDERR "opac-account-pay-girosolution-message.pl ($gcHash eq $compHash):", ($gcHash eq $compHash), ":\n";
print STDERR "opac-account-pay-girosolution-message.pl (genHmacMd5($merchantTxIdKey, $merchantTxIdVal) eq $gcMerchantTxId):", (genHmacMd5($merchantTxIdKey, $merchantTxIdVal) eq $gcMerchantTxId), ":\n";
print STDERR "opac-account-pay-girosolution-message.pl ($gcResultPayment == 4000):", ($gcResultPayment == 4000), ":\n";
print STDERR "opac-account-pay-girosolution-message.pl ($amountKoha * 100.0):", ($amountKoha * 100.0), ":\n";
print STDERR "opac-account-pay-girosolution-message.pl ($gcAmount == $amountKoha * 100.0):", ($gcAmount == $amountKoha * 100.0), ":\n";
print STDERR "opac-account-pay-girosolution-message.pl ($gcAmount == ($amountKoha * 100.0)):", ($gcAmount == ($amountKoha * 100.0)), ":\n";
    my $paymentId;
    if ( ($gcHash eq $compHash) && (genHmacMd5($merchantTxIdKey, $merchantTxIdVal) eq $gcMerchantTxId) && ($gcResultPayment == 4000) && ($gcAmount/100.0 == $amountKoha)  ) {
print STDERR "opac-account-pay-girosolution-message.pl: The hash values are valid!\n";

        my $account = Koha::Account->new( { patron_id => $borrowernumberKoha } );
        my @lines = Koha::Account::Lines->search(
            {
                accountlines_id => { -in => \@accountlinesKoha }
            }
        );

        my $sumAmountoutstanding = 0.0;
        foreach my $accountline ( @lines ) {
###print STDERR "opac-account-pay-girosolution-message.pl: accountline:", Dumper($accountline), ":\n";
print STDERR "opac-account-pay-girosolution-message.pl: accountline->amountoutstanding:", Dumper($accountline->amountoutstanding()), ":\n";
            $sumAmountoutstanding += $accountline->amountoutstanding();
        }
        $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this roundig was also done in the complimentary opac-account-pay-pl
print STDERR "opac-account-pay-girosolution-message.pl: sumAmountoutstanding:$sumAmountoutstanding: amountKoha:$amountKoha: gcAmount:$gcAmount:\n";

        if ( $sumAmountoutstanding == $amountKoha ) {
print STDERR "opac-account-pay-girosolution-message.pl: now calling account->pay!\n";

            my $descriptionText = 'Zahlung';    # should always be overwritten
            my $noteText = "Online-Zahlung $gcReference";    # should always be overwritten
            if ( $paytypeKoha == 1 ) {    # giropay
                $descriptionText = "Überweisung (GiroPay/GiroSolution)";
                $noteText = "Online-Überweisung $gcReference";
            } elsif ( $paytypeKoha == 11 ) {    # creditcard
                $descriptionText = "Kreditkarte (GiroSolution)";
                $noteText = "Online-Kreditkarte $gcReference";
            }
print STDERR "opac-account-pay-girosolution-message.pl: noteText:$noteText:\n";

            # evaluate configuration of cash register management for online payments
            my $withoutCashRegisterManagement = 1;    # default: avoiding cash register management in Koha::Account->pay()
            my $cash_register_manager_id = 0;    # borrowernumber of manager of cash register for online payments

            if ( C4::Context->preference("ActivateCashRegisterTransactionsOnly") ) {
                my $paymentsOnlineCashRegisterName = C4::Context->preference('PaymentsOnlineCashRegisterName');
                my $paymentsOnlineCashRegisterManagerCardnumber = C4::Context->preference('PaymentsOnlineCashRegisterManagerCardnumber');
print STDERR "opac-account-pay-girosolution-message.pl: paymentsOnlineCashRegisterName:$paymentsOnlineCashRegisterName: paymentsOnlineCashRegisterManagerCardnumber:$paymentsOnlineCashRegisterManagerCardnumber:\n";
                if ( length($paymentsOnlineCashRegisterName) && length($paymentsOnlineCashRegisterManagerCardnumber) ) {
                    $withoutCashRegisterManagement = 0;

                    my $userenv = C4::Context->userenv;
                    my $library_id = $userenv ? $userenv->{'branch'} : undef;
                    # get cash register manager information
                    my $cash_register_manager = Koha::Patrons->search( { cardnumber => $paymentsOnlineCashRegisterManagerCardnumber } )->next();
                    if ( $cash_register_manager ) {
                        $cash_register_manager_id = $cash_register_manager->borrowernumber();
print STDERR "opac-account-pay-girosolution-message.pl: cash_register_manager_id:$cash_register_manager_id:\n";
                        my $cash_register_mngmt = C4::CashRegisterManagement->new($library_id, $cash_register_manager_id);

                        if ( $cash_register_mngmt ) {
                            my $cashRegisterNeedsToBeOpened = 1;
                            my $openedCashRegister = $cash_register_mngmt->getOpenedCashRegisterByManagerID($cash_register_manager_id);
                            if ( defined $openedCashRegister ) {
print STDERR "opac-account-pay-girosolution-message.pl: cash_register_name:", $openedCashRegister->{'cash_register_name'}, ":\n";
                                if ($openedCashRegister->{'cash_register_name'} eq $paymentsOnlineCashRegisterName) {
                                    $cashRegisterNeedsToBeOpened = 0;
                                } else {
                                    $cash_register_mngmt->closeCashRegister($openedCashRegister->{'cash_register_id'}, $cash_register_manager_id);
                                }
                            }
                            if ( $cashRegisterNeedsToBeOpened ) {
                                # try to open the specified cash register by name
                                my $cash_register_id = $cash_register_mngmt->readCashRegisterIdByName($paymentsOnlineCashRegisterName);
print STDERR "opac-account-pay-girosolution-message.pl: cash_register_id:$cash_register_id:\n";
                                if ( defined $cash_register_id && $cash_register_mngmt->canOpenCashRegister($cash_register_id, $cash_register_manager_id) ) {
                                    my $opened = $cash_register_mngmt->openCashRegister($cash_register_id, $cash_register_manager_id);
print STDERR "opac-account-pay-girosolution-message.pl: cash_register_mngmt->openCashRegister($library_id, $cash_register_manager_id) returned opened:$opened:\n";
                                }
                            }
                        }
                    }
                }
            }
            
print STDERR "opac-account-pay-girosolution-message.pl: withoutCashRegisterManagement:$withoutCashRegisterManagement:\n";
print STDERR "opac-account-pay-girosolution-message.pl: cash_register_manager_id:$cash_register_manager_id:\n";
            $paymentId = $account->pay(
                {
                    amount => $amountKoha,
                    lines => \@lines,
                    description => $descriptionText,
                    note => $noteText,
                    withoutCashRegisterManagement => $withoutCashRegisterManagement,
                    onlinePaymentCashRegisterManagerId => $cash_register_manager_id
                }
            );
        } else {
print STDERR "opac-account-pay-girosolution-message.pl: now NOT calling account->pay!\n";
        }
    }

print STDERR "opac-account-pay-girosolution-message.pl: paymentId:$paymentId:\n";
    if ( $paymentId ) {
print STDERR "opac-account-pay-girosolution-message.pl: It seems that the online payment has succeeded!\n";
        $httpResponseStatus = '200 OK';    # return statuscode '200 OK'
    } else {
print STDERR "opac-account-pay-girosolution-message.pl: It seems that the online payment has NOT succeeded!\n";
        $httpResponseStatus = '400 Bad Request';    # return statuscode '400 Bad Request'
        ###$httpResponseStatus = '333 Bad Request';    # test only; return neither 200 nor 400; this leads via 'return $httpresponse;' to the wanted multiple repetition of this call by GiroSolution (one call each half hour)
    }
print STDERR "opac-account-pay-girosolution-message.pl returns cgi with httpResponseStatus:", $httpResponseStatus, ":\n";

    print $cgi->header( -status => $httpResponseStatus,
                        -charset => 'utf-8',
                      );

}
