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

use Modern::Perl;
use utf8;

use CGI;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI;

use C4::Auth;
use C4::Output;
use C4::Accounts;
use C4::Context;
use C4::CashRegisterManagement;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Patrons;

my $cgi = new CGI;

unless ( C4::Context->preference('EnablePayPalOpacPayments') ) {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-account-pay-return.tt",
        query           => $cgi,
        type            => "opac",
        authnotrequired => 0,
        debug           => 1,
    }
);

my $active_currency = Koha::Acquisition::Currencies->get_active;

my $token    = $cgi->param('token');
my $payer_id = $cgi->param('PayerID');
my $amount   = $cgi->param('amount');
my @accountlines = $cgi->multi_param('accountlines');

my $ua = LWP::UserAgent->new;

my $url =
  C4::Context->preference('PayPalSandboxMode')
  ? 'https://api-3t.sandbox.paypal.com/nvp'
  : 'https://api-3t.paypal.com/nvp';

my $nvp_params = {
    'USER'      => C4::Context->preference('PayPalUser'),
    'PWD'       => C4::Context->preference('PayPalPwd'),
    'SIGNATURE' => C4::Context->preference('PayPalSignature'),

    # API Version and Operation
    'METHOD'  => 'DoExpressCheckoutPayment',
    'VERSION' => '82.0',

    # API specifics for DoExpressCheckout
    'PAYMENTREQUEST_0_PAYMENTACTION' => 'Sale',
    'PAYERID'                        => $payer_id,
    'TOKEN'                          => $token,
    'PAYMENTREQUEST_0_AMT'           => $amount,
    'PAYMENTREQUEST_0_CURRENCYCODE'  => $active_currency->currency,
};

my $response = $ua->request( POST $url, $nvp_params );

my $error = q{};
if ( $response->is_success ) {

    my $urlencoded = $response->content;
    my %params = URI->new( "?$urlencoded" )->query_form;


    if ( $params{ACK} eq "Success" ) {
        $amount = $params{PAYMENTINFO_0_AMT};

        my $account = Koha::Account->new( { patron_id => $borrowernumber } );
        my @lines = Koha::Account::Lines->search(
            {
                accountlines_id => { -in => \@accountlines }
            }
        );

        # evaluate configuration of cash register management for online payments
        my $withoutCashRegisterManagement = 1;    # default: avoiding cash register management in Koha::Account->pay()
        my $cash_register_manager_id = 0;    # borrowernumber of manager of online cash register

        if ( C4::Context->preference("ActivateCashRegisterTransactionsOnly") ) {
            my $paymentsOnlineCashRegisterName = C4::Context->preference('PaymentsOnlineCashRegisterName');
            my $paymentsOnlineCashRegisterManagerCardnumber = C4::Context->preference('PaymentsOnlineCashRegisterManagerCardnumber');
print STDERR "opac-account-pay-paypal-return.pl: paymentsOnlineCashRegisterName:$paymentsOnlineCashRegisterName: paymentsOnlineCashRegisterManagerCardnumber:$paymentsOnlineCashRegisterManagerCardnumber:\n";
            if ( length($paymentsOnlineCashRegisterName) && length($paymentsOnlineCashRegisterManagerCardnumber) ) {
                $withoutCashRegisterManagement = 0;

                my $userenv = C4::Context->userenv;
                my $library_id = $userenv ? $userenv->{'branch'} : undef;
                # get cash register manager information
                my $cash_register_manager = Koha::Patrons->search( { cardnumber => $paymentsOnlineCashRegisterManagerCardnumber } )->next();
                if ( $cash_register_manager ) {
                    $cash_register_manager_id = $cash_register_manager->borrowernumber();
print STDERR "opac-account-pay-paypal-return.pl: cash_register_manager_id:$cash_register_manager_id:\n";
                    my $cash_register_mngmt = C4::CashRegisterManagement->new($library_id, $cash_register_manager_id);

                    if ( $cash_register_mngmt ) {
                        my $cashRegisterNeedsToBeOpened = 1;
                        my $openedCashRegister = $cash_register_mngmt->getOpenedCashRegisterByManagerID($cash_register_manager_id);
                        if ( defined $openedCashRegister ) {
print STDERR "opac-account-pay-paypal-return.pl: cash_register_name:", $openedCashRegister->{'cash_register_name'}, ":\n";
                            if ($openedCashRegister->{'cash_register_name'} eq $paymentsOnlineCashRegisterName) {
                                $cashRegisterNeedsToBeOpened = 0;
                            } else {
                                $cash_register_mngmt->closeCashRegister($openedCashRegister->{'cash_register_id'}, $cash_register_manager_id);
                            }
                        }
                        if ( $cashRegisterNeedsToBeOpened ) {
                            # try to open the specified cash register by name
                            my $cash_register_id = $cash_register_mngmt->readCashRegisterIdByName($paymentsOnlineCashRegisterName);
print STDERR "opac-account-pay-paypal-return.pl: cash_register_id:$cash_register_id:\n";
                            if ( defined $cash_register_id && $cash_register_mngmt->canOpenCashRegister($cash_register_id, $cash_register_manager_id) ) {
                                my $opened = $cash_register_mngmt->openCashRegister($cash_register_id, $cash_register_manager_id);
print STDERR "opac-account-pay-paypal-return.pl: cash_register_mngmt->openCashRegister($library_id, $cash_register_manager_id) returned opened:$opened:\n";
                            }
                        }
                    }
                }
            }
        }

        $account->pay(
            {
                amount => $amount,
                lines  => \@lines,
                description => 'PayPal',
                note => 'Online-PayPal',
                withoutCashRegisterManagement => $withoutCashRegisterManagement,
                onlinePaymentCashRegisterManagerId => $cash_register_manager_id
            }
        );
    }
    else {
       $error = "PAYPAL_ERROR_PROCESSING";
    }

}
else {
    $error = "PAYPAL_UNABLE_TO_CONNECT";
}

my $patron = Koha::Patrons->find( $borrowernumber );
$template->param(
    borrower    => $patron->unblessed,
    accountview => 1
);

print $cgi->redirect("/cgi-bin/koha/opac-account.pl?payment=$amount&payment-error=$error");
