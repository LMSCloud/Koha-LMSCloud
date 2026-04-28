#!/usr/bin/perl

# Copyright 2026 LMSCloud GmbH
#
# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>

use Modern::Perl;

use Test::More tests => 4;
use Test::NoWarnings;

use Koha::Database;
use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Cash register management' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    use_ok('C4::CashRegisterManagement');

    can_ok(
        'C4::CashRegisterManagement',
        qw(
            new
            passCashRegisterCheck
            getOpenedCashRegister
            managerHasOpenCashRegister
            registerPayment
            registerReversePayment
            registerCreditPayout
        )
    );

    ok(
        defined C4::Context->preference('ActivateCashRegisterTransactionsOnly'),
        'ActivateCashRegisterTransactionsOnly syspref is accessible'
    );

    ok(
        defined C4::Context->preference('UseCashRegisters'),
        'UseCashRegisters syspref is accessible'
    );

    my @exported = @C4::CashRegisterManagement::EXPORT;
    ok(
        ( grep { $_ eq 'passCashRegisterCheck' } @exported ),
        'passCashRegisterCheck is exported by default'
    );
    ok(
        ( grep { $_ eq 'getOpenedCashRegister' } @exported ),
        'getOpenedCashRegister is exported by default'
    );

    subtest 'Koha::Account::pay accepts LMS cash register params' => sub {

        plan tests => 3;

        use_ok('Koha::Account');

        my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
        my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );

        t::lib::Mocks::mock_preference( 'UseCashRegisters',                     0 );
        t::lib::Mocks::mock_preference( 'ActivateCashRegisterTransactionsOnly', 0 );
        t::lib::Mocks::mock_preference( 'RequirePaymentType',                   0 );

        $account->add_debit(
            {
                amount    => 5.00,
                type      => 'OVERDUE',
                interface => 'commandline',
            }
        );

        my $payment = $account->pay(
            {
                amount                        => 5.00,
                withoutCashRegisterManagement => 1,
                interface                     => 'commandline',
            }
        );

        ok( $payment, 'pay() succeeds with withoutCashRegisterManagement parameter' );

        my $payment2 = $account->pay(
            {
                amount                             => 0.01,
                withoutCashRegisterManagement      => 1,
                onlinePaymentCashRegisterManagerId => 0,
                interface                          => 'commandline',
            }
        );

        ok( $payment2, 'pay() succeeds with onlinePaymentCashRegisterManagerId parameter' );
    };

    $schema->storage->txn_rollback;
};

subtest 'Bookmobile register-clearing primitives' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    use_ok('Koha::Cash::Registers');

    ok(
        defined C4::Context->preference('BookMobileSupportEnabled'),
        'BookMobileSupportEnabled syspref is accessible (gates branchcategory persistence in set-library.pl)'
    );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $register = $builder->build_object(
        {
            class => 'Koha::Cash::Registers',
            value => {
                branch => $library->branchcode,
                name   => 'Bookmobile-Test-Register',
            },
        }
    );

    my $found = Koha::Cash::Registers->find( $register->id );
    isa_ok( $found, 'Koha::Cash::Register', 'find($id) returns a Cash::Register object' );
    is(
        $found->name,
        'Bookmobile-Test-Register',
        '$register->name returns the value stored in session by set-library.pl'
    );

    is(
        Koha::Cash::Registers->find(0),
        undef,
        'find on a non-existent id returns undef (set-library.pl falls back to clearing session)'
    );

    $schema->storage->txn_rollback;
};

subtest 'Claiming fees' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    use_ok('C4::ClaimingFees');
    use_ok('C4::NoticeFees');

    can_ok(
        'C4::ClaimingFees',
        qw(
            new
            checkForClaimingRules
            getFittingClaimingRule
            AddClaimFee
            GetClaimingFeeDescription
        )
    );

    can_ok(
        'C4::NoticeFees',
        qw(
            new
            checkForNoticeFeeRules
            getNoticeFeeRule
            AddNoticeFee
            GetNoticeFeeDescription
        )
    );

    subtest 'CLAIM_LEVEL debit types referenced in ClaimingFees' => sub {

        plan tests => 5;

        my $source = do {
            local $/;
            my $path = $INC{'C4/ClaimingFees.pm'};
            open my $fh, '<', $path or die "Cannot open $path: $!";
            <$fh>;
        };

        for my $level ( 1 .. 5 ) {
            like(
                $source,
                qr/CLAIM_LEVEL_?$level/,
                "CLAIM_LEVEL$level is referenced in C4::ClaimingFees source"
            );
        }
    };

    subtest 'ClaimingRule schema has claim_fee_level columns' => sub {

        plan tests => 5;

        use_ok('Koha::ClaimingRule');

        my $rule = $builder->build_object(
            {
                class => 'Koha::ClaimingRules',
                value => {
                    branchcode       => '*',
                    categorycode     => '*',
                    itemtype         => '*',
                    claim_fee_level1 => 1.00,
                    claim_fee_level2 => 2.00,
                    claim_fee_level3 => 3.00,
                    claim_fee_level4 => 4.00,
                    claim_fee_level5 => 5.00,
                },
            }
        );

        for my $level ( 1 .. 4 ) {
            my $accessor = "claim_fee_level$level";
            is(
                $rule->$accessor + 0,
                $level,
                "claim_fee_level$level accessor returns correct value"
            );
        }
    };

    subtest 'ClaimingFees rule matching' => sub {

        plan tests => 3;

        my $claimFees = C4::ClaimingFees->new();
        ok( $claimFees, 'C4::ClaimingFees->new() returns an object' );

        ok(
            $claimFees->can('getFittingClaimingRule'),
            'ClaimingFees object can getFittingClaimingRule'
        );

        ok(
            $claimFees->can('checkForClaimingRules'),
            'ClaimingFees object can checkForClaimingRules'
        );
    };

    $schema->storage->txn_rollback;
};
