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


    # check if payment has been triggered by calling GetPaymentStatus
    my $error = "EPAY21_ERROR_PROCESSING";
    my $epay21msg = '';
    my $paytype = 17;    # just a dummy

    # overwriting SOAP::Transport::HTTP::Client::get_basic_credentials for substituting our customized credentials
    sub SOAP::Transport::HTTP::Client::get_basic_credentials {
        # credentials for basic authentication
        my $basicAuth_User = C4::Context->preference('Epay21BasicAuthUser');    # mandatory
        my $basicAuth_Pw = C4::Context->preference('Epay21BasicAuthPw');    # mandatory

        return $basicAuth_User => $basicAuth_Pw;
    }

    # Überprüfung des Erfolgs der ePay21 paypage Zahlung
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
    # read payment status until it is 'payed', 'confirmed', 'canceled' or 'failed' - but maximal for 7 seconds
    my $paymentStatus = 'undef';
    my $paymentType = '';
    my $paymentPayID = '';
    my $starttime = time();

    while ( time() < $starttime + 7 ) {
        my $response = eval {
            $soap_request->GetPaymentStatus( $getPaymentStatus_OP, $getPaymentStatus_Query );
        };
        if ( $@ ) {
            carp "opac-account-pay-epay21-return.pl: error when calling soap_request->GetPaymentStatus:$@:\n";
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
                            if ( $paymentStatus eq 'payed' || $paymentStatus eq 'confirmed' ) {
                                last;    # looks good, we have to 'pay' the accountlines
                            }
                            if ( $paymentStatus eq 'canceled' || $paymentStatus eq 'failed' ) {
                                $epay21msg = 'paymentStatus:' . $paymentStatus . ':';
                                last;    # payment not successful, so we do NOT 'pay' the accountlines
                            }
                        } else {
                            $paymentStatus = '';
                            $paymentType = '';
                            $paymentPayID = '';
                        }
                    }
                }
            }
            sleep(1);
        }
    }

    if (  $paymentStatus eq 'payed' || $paymentStatus eq 'confirmed' ) {

        # now 'pay' the accountlines
        my $account = Koha::Account->new( { patron_id => $borrowernumberKoha } );
        my @lines = Koha::Account::Lines->search(
            {
                accountlines_id => { -in => \@accountlinesKoha }
            }
        );

        my $sumAmountoutstanding = 0.0;
        foreach my $accountline ( @lines ) {
            $sumAmountoutstanding += $accountline->amountoutstanding();
        }
        $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding was also done in the complimentary opac-account-pay-pl

        if ( $sumAmountoutstanding == $amountKoha ) {

            my $descriptionText = 'Zahlung (epay21)';    # should always be overwritten
            my $noteText = "Online-Zahlung $paymentPayID";    # should always be overwritten
            if ( $paytypeKoha == 17 ) {    # all: giropay, paydirect, credit card, Lastschrift, ...
                if ( $paymentType ) {
                    $descriptionText = $paymentType . " (epay21)";
                    $noteText = "Online ($paymentType) $paymentPayID";
                } else {
                    $descriptionText = "Online-Zahlung (epay21)";
                    $noteText = "Online-Zahlung $paymentPayID";
                }
            }

            # we take the borrowers branchcode also for the payment accountlines record to be created
            my $library_id = undef;
            my $patron = Koha::Patrons->find( $borrowernumberKoha );
            if ( $patron ) {
                $library_id = $patron->branchcode();
            }

            # evaluate configuration of cash register management for online payments
            my $withoutCashRegisterManagement = 1;    # default: avoiding cash register management in Koha::Account->pay()
            my $cash_register_manager_id = 0;    # borrowernumber of manager of cash register for online payments

            if ( C4::Context->preference("ActivateCashRegisterTransactionsOnly") ) {
                my $paymentsOnlineCashRegisterName = C4::Context->preference('PaymentsOnlineCashRegisterName');
                my $paymentsOnlineCashRegisterManagerCardnumber = C4::Context->preference('PaymentsOnlineCashRegisterManagerCardnumber');
                if ( length($paymentsOnlineCashRegisterName) && length($paymentsOnlineCashRegisterManagerCardnumber) ) {
                    $withoutCashRegisterManagement = 0;

                    # get cash register manager information
                    my $cash_register_manager = Koha::Patrons->search( { cardnumber => $paymentsOnlineCashRegisterManagerCardnumber } )->next();
                    if ( $cash_register_manager ) {
                        $cash_register_manager_id = $cash_register_manager->borrowernumber();
                        my $cash_register_manager_branchcode = $cash_register_manager->branchcode();
                        my $cash_register_mngmt = C4::CashRegisterManagement->new($cash_register_manager_branchcode, $cash_register_manager_id);

                        if ( $cash_register_mngmt ) {
                            my $cashRegisterNeedsToBeOpened = 1;
                            my $openedCashRegister = $cash_register_mngmt->getOpenedCashRegisterByManagerID($cash_register_manager_id);
                            if ( defined $openedCashRegister ) {
                                if ($openedCashRegister->{'cash_register_name'} eq $paymentsOnlineCashRegisterName) {
                                    $cashRegisterNeedsToBeOpened = 0;
                                } else {
                                    $cash_register_mngmt->closeCashRegister($openedCashRegister->{'cash_register_id'}, $cash_register_manager_id);
                                }
                            }
                            if ( $cashRegisterNeedsToBeOpened ) {
                                # try to open the specified cash register by name
                                my $cash_register_id = $cash_register_mngmt->readCashRegisterIdByName($paymentsOnlineCashRegisterName);
                                if ( defined $cash_register_id && $cash_register_mngmt->canOpenCashRegister($cash_register_id, $cash_register_manager_id) ) {
                                    my $opened = $cash_register_mngmt->openCashRegister($cash_register_id, $cash_register_manager_id);
                                }
                            }
                        }
                    }
                }
            }
            
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
            $epay21msg = 'sumAmountoutstanding != $amountKoha';
        }
    }

    if ( $kohaPaymentId ) {
        $error = '';
    } else {
        if (  $paymentStatus eq 'payed' || $paymentStatus eq 'confirmed' ) {
            if ( length($epay21msg) == 0 ) {
                $epay21msg = 'error in account->pay()';
            }
        } else {
            $epay21msg = 'payment has not been confirmed by epay21 within 7 seconds';
        }
    }


    if ( length($paymentPayID) ) {    # payment order has been found

        # ConfirmPayment Query parameters 
        my $confirmPay_Query_PayID = $paymentPayID;    # mandatory, unique Identifier des Falles im Fachverfahren 
        my $confirmPay_Query_Action = $error ? 'failure' : 'confirm';    # mandatory

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
    } else {
        $error = "EPAY21_ERROR_PROCESSING";
        $epay21msg = "could not get paymentPayID of order:$getPayStat_Query_SearchKey:";
    }


    my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => "opac-account-pay-return.tt",    # name of non existing tt-file is sufficient
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
        my $mess = "opac-account-pay-epay21-return.pl epay21msg:" . $epay21msg . ":";
        carp $mess . "\n";
    }

    print $cgi->redirect("/cgi-bin/koha/opac-account.pl?payment=$amountKoha&payment-error=$error");
} else {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
}
