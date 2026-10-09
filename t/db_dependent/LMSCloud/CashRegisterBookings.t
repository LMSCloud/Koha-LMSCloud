#!/usr/bin/perl

# Copyright 2026 LMSCloud GmbH
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
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

# The LMSCloud cash registers inside community's Koha::Account: which payments
# and payouts need an open register, and what they book on it.

use Modern::Perl;

use Test::More tests => 7;
use Test::Exception;

use C4::CashRegisterManagement;
use Koha::Account;
use Koha::Database;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

sub mock_register_preferences {
    my (%prefs) = @_;
    t::lib::Mocks::mock_preference( 'ActivateCashRegisterTransactionsOnly', 1 );
    t::lib::Mocks::mock_preference( 'PermitConcurrentCashRegisterUsers',    0 );
    t::lib::Mocks::mock_preference( 'UseCashRegisters',                     0 );
    t::lib::Mocks::mock_preference( 'RequirePaymentType',                   0 );
    t::lib::Mocks::mock_preference( $_,                                     $prefs{$_} ) for keys %prefs;
}

sub new_library {
    return $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } )->branchcode;
}

sub new_staff {
    my ($library) = @_;
    return $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library, flags => 1 } } );
}

# A register of $library that the given staff may manage, opened by the first of them
sub open_register {
    my ( $library, @staff ) = @_;

    my $register = $builder->build(
        {
            source => 'CashRegisterDefinition',
            value  => {
                branchcode            => $library,
                manager_id            => undef,
                prev_manager_id       => undef,
                no_branch_restriction => 0,
            }
        }
    );
    $builder->build(
        {
            source => 'CashRegisterManager',
            value  => { cash_register_id => $register->{id}, manager_id => $_->borrowernumber, opened => 0 }
        }
    ) for @staff;
    open_as( $register->{id}, $staff[0] );
    return $register->{id};
}

sub open_as {
    my ( $register_id, $staff ) = @_;
    return C4::CashRegisterManagement->new( $staff->branchcode, $staff->borrowernumber )
        ->openCashRegister( $register_id, $staff->borrowernumber );
}

sub close_as {
    my ( $register_id, $staff ) = @_;
    return C4::CashRegisterManagement->new( $staff->branchcode, $staff->borrowernumber )
        ->closeCashRegister( $register_id, $staff->borrowernumber );
}

# The register's bookings other than opening and closing, as "ACTION amount"
sub bookings {
    my ($register_id) = @_;
    return $dbh->selectcol_arrayref(
        q|SELECT CONCAT_WS(' ', action, ROUND(booking_amount, 2)) FROM cash_register_account
          WHERE cash_register_id = ? AND action NOT IN ('OPEN', 'CLOSE') ORDER BY id|,
        undef, $register_id
    );
}

sub balance {
    my ($register_id) = @_;
    return sprintf( '%.2f', C4::CashRegisterManagement->new->getCurrentBalance($register_id) );
}

sub bookings_of_line {
    my ($accountlines_id) = @_;
    return $dbh->selectrow_array(
        q|SELECT COUNT(*) FROM cash_register_account WHERE accountlines_id = ?|, undef,
        $accountlines_id
    );
}

# A patron owing $amount, and their account
sub patron_owing {
    my ( $library, $amount ) = @_;
    my $patron  = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library } } );
    my $account = $patron->account;
    $account->add_debit( { amount => $amount, type => 'MANUAL', interface => 'intranet' } );
    return $account;
}

sub pay {
    my ( $account, $amount, %params ) = @_;
    return $account->pay( { amount => $amount, interface => 'intranet', %params } );
}

subtest 'Cash-type payments are booked on the manager\'s open register' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;
    mock_register_preferences();

    my $library  = new_library();
    my $staff    = new_staff($library);
    my $register = open_register( $library, $staff );
    t::lib::Mocks::mock_userenv( { patron => $staff, branchcode => $library } );

    my $account = patron_owing( $library, 10 );
    my $cash    = pay( $account, 3, payment_type => 'CASH' );
    pay( $account, 2, payment_type => 'SIP00' );
    my $card = pay( $account, 1, payment_type => 'CARD' );

    is_deeply( bookings($register), [ 'PAYMENT 3.00', 'PAYMENT 2.00' ], 'CASH and SIP payments are booked' );
    is( bookings_of_line( $cash->{payment_id} ), 1,      'the booking refers to the payment' );
    is( bookings_of_line( $card->{payment_id} ), 0,      'a card payment is not booked' );
    is( balance($register),                      '5.00', 'the register balance grows by the cash received' );

    $schema->storage->txn_rollback;
};

subtest 'Cash payments need an open register, write-offs and cancellations do not' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;
    mock_register_preferences( RequirePaymentType => 1 );

    my $library = new_library();
    my $staff   = new_staff($library);
    t::lib::Mocks::mock_userenv( { patron => $staff, branchcode => $library } );

    my $account = patron_owing( $library, 10 );
    throws_ok { pay( $account, 3, payment_type => 'CASH' ) } 'Koha::Exceptions::Account::RegisterRequired',
        'a cash payment without an open register is refused';
    is( $account->balance + 0, 10, 'and nothing is paid' );

    my $writeoff     = pay( $account, 1, type => 'WRITEOFF' );
    my $cancellation = pay( $account, 2, type => 'CANCELLATION' );
    ok( $cancellation->{payment_id}, 'a cancellation needs no payment type' );
    is( $account->balance + 0, 7, 'the write-off and the cancellation are applied' );
    is(
        bookings_of_line( $writeoff->{payment_id} ) + bookings_of_line( $cancellation->{payment_id} ), 0,
        'neither is booked on a register'
    );

    $schema->storage->txn_rollback;
};

subtest 'withoutCashRegisterManagement bypasses the register' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    mock_register_preferences();

    my $library = new_library();
    my $staff   = new_staff($library);
    t::lib::Mocks::mock_userenv( { patron => $staff, branchcode => $library } );

    my $account = patron_owing( $library, 10 );
    my $payment = pay( $account, 3, payment_type => 'CASH', withoutCashRegisterManagement => 1 );
    is( $account->balance + 0,                      7, 'the cash payment is taken without an open register' );
    is( bookings_of_line( $payment->{payment_id} ), 0, 'and not booked' );

    $schema->storage->txn_rollback;
};

subtest 'An online payment is booked on the register of the given manager' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    mock_register_preferences();

    my $library  = new_library();
    my $manager  = new_staff($library);
    my $register = open_register( $library, $manager );
    t::lib::Mocks::mock_userenv( { patron => new_staff($library), branchcode => $library } );

    my $account = patron_owing( $library, 10 );
    my $payment = pay(
        $account, 4,
        payment_type                       => 'ONLINE',
        onlinePaymentCashRegisterManagerId => $manager->borrowernumber
    );
    my $credit = Koha::Account::Lines->find( $payment->{payment_id} );
    is( $credit->manager_id, $manager->borrowernumber, 'the payment is made in the manager\'s name' );
    is_deeply( bookings($register), ['PAYMENT 4.00'], 'and booked on the manager\'s register' );
    is( $account->balance + 0, 6, 'the debt is reduced' );

    $schema->storage->txn_rollback;
};

subtest 'Credit payouts are booked as cash leaving the register' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;
    mock_register_preferences();

    my $library  = new_library();
    my $staff    = new_staff($library);
    my $register = open_register( $library, $staff );
    t::lib::Mocks::mock_userenv( { patron => $staff, branchcode => $library } );

    my $patron  = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library } } );
    my $account = $patron->account;
    my $credit  = $account->add_credit( { amount => 5, type => 'CREDIT', interface => 'intranet' } );
    my %payout  = (
        payout_type => 'CASH', branch => $library, staff_id => $staff->borrowernumber,
        interface   => 'intranet'
    );

    $credit->payout( { %payout, amount => 2 } );
    $account->payout_amount( { %payout, amount => 1 } );
    is_deeply(
        bookings($register), [ 'CREDIT_PAYOUT -2.00', 'CREDIT_PAYOUT -1.00' ],
        'paying out one credit and paying out an amount are both booked'
    );
    is( balance($register), '-3.00', 'the register balance drops by the cash paid out' );

    close_as( $register, $staff );
    throws_ok { $credit->discard_changes->payout( { %payout, amount => 1 } ) }
    'Koha::Exceptions::Account::RegisterRequired', 'a payout without an open register is refused';
    is( $account->balance + 0, -2, 'and the remaining credit is kept' );

    $schema->storage->txn_rollback;
};

subtest 'Concurrent users share a register, others are refused' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;
    mock_register_preferences();

    my $library = new_library();
    my ( $first, $second, $outsider ) = map { new_staff($library) } 1 .. 3;
    my $register = open_register( $library, $first, $second );
    my $account  = patron_owing( $library, 10 );

    t::lib::Mocks::mock_userenv( { patron => $second, branchcode => $library } );
    throws_ok { pay( $account, 1, payment_type => 'CASH' ) } 'Koha::Exceptions::Account::RegisterRequired',
        'without concurrent users, only the manager who opened the register can take payments';

    t::lib::Mocks::mock_preference( 'PermitConcurrentCashRegisterUsers', 1 );
    ok( open_as( $register, $second ), 'with concurrent users, a second manager opens it too' );
    pay( $account, 2, payment_type => 'CASH' );
    t::lib::Mocks::mock_userenv( { patron => $first, branchcode => $library } );
    pay( $account, 1, payment_type => 'CASH' );
    is_deeply( bookings($register), [ 'PAYMENT 2.00', 'PAYMENT 1.00' ], 'both book on the same register' );

    t::lib::Mocks::mock_userenv( { patron => $outsider, branchcode => $library } );
    throws_ok { pay( $account, 1, payment_type => 'CASH' ) } 'Koha::Exceptions::Account::RegisterRequired',
        'staff who did not open it are refused';

    close_as( $register, $first );
    t::lib::Mocks::mock_userenv( { patron => $second, branchcode => $library } );
    pay( $account, 3, payment_type => 'CASH' );
    is( balance($register), '6.00', 'the second manager keeps booking after the first closes' );

    close_as( $register, $second );
    is(
        Koha::CashRegister::CashRegisterDefinitions->find( { id => $register } )->manager_id, undef,
        'the register is closed once the last manager closes it'
    );

    $schema->storage->txn_rollback;
};

subtest 'Bookmobile stations book on the register of their parent library' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    mock_register_preferences();

    my $parent = new_library();
    my $station =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => $parent } } )->branchcode;
    my $staff    = new_staff($parent);
    my $register = open_register( $parent, $staff );
    t::lib::Mocks::mock_userenv( { patron => $staff, branchcode => $station } );

    my $account = patron_owing( $station, 10 );
    pay( $account, 4, payment_type => 'CASH', library_id => $station );
    is_deeply( bookings($register), ['PAYMENT 4.00'], 'a payment at the station is booked' );
    is( $account->balance + 0, 6, 'and applied' );

    $schema->storage->txn_rollback;
};
