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

use Test::More tests => 7;
use Test::NoWarnings;

use File::Slurp qw( read_file );
use File::Temp  qw( tempdir );

use C4::CashRegisterManagement;
use C4::Overdues qw( UpdateFine );
use Koha::Account::Lines;
use Koha::DateUtils qw( dt_from_string );
use Koha::SEPAPayment;
use Koha::Database;
use Koha::Notice::Messages;
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

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
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

subtest 'UpdateFine records the checkout library on a new fine' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $checkout_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron           = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item             = $builder->build_sample_item;
    my $checkout         = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                itemnumber     => $item->itemnumber,
                borrowernumber => $patron->borrowernumber,
                branchcode     => $checkout_library->branchcode,
            }
        }
    );

    UpdateFine(
        {
            issue_id       => $checkout->issue_id,
            itemnumber     => $item->itemnumber,
            borrowernumber => $patron->borrowernumber,
            amount         => '2.50',
            due            => $checkout->date_due,
        }
    );

    my $fines = Koha::Account::Lines->search( { issue_id => $checkout->issue_id, debit_type_code => 'OVERDUE' } );
    is( $fines->count,            1,                             'One overdue fine is created' );
    is( $fines->next->branchcode, $checkout_library->branchcode, 'The fine carries the checkout library' );

    $schema->storage->txn_rollback;
};

subtest 'SEPA membership renewal books the enrolment fee under the cash register manager' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $manager  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $category = $builder->build_object(
        { class => 'Koha::Patron::Categories', value => { enrolmentfee => 5, enrolmentperiod => 12 } } );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->categorycode,
                dateexpiry   => dt_from_string->add( days => 7 )->ymd,
            }
        }
    );
    my $type = Koha::Patron::Attribute::Types->find('SEPA')
        // $builder->build_object( { class => 'Koha::Patron::Attribute::Types', value => { code => 'SEPA' } } );
    $patron->add_extended_attribute( { code => $type->code, attribute => '1' } );

    t::lib::Mocks::mock_preference( 'SepaDirectDebitCashRegisterManagerCardnumber', $manager->cardnumber );
    C4::Context->unset_userenv;

    my $sepa = Koha::SEPAPayment->new( 0, q{}, 1 );
    my ( $selected, $renewed ) =
        $sepa->renewMembershipForSepaDirectDebitPatrons( { 'me.borrowernumber' => $patron->borrowernumber } );

    is( $renewed, 1, 'The SEPA patron is renewed' );
    my $fee = Koha::Account::Lines->search(
        { borrowernumber => $patron->borrowernumber, debit_type_code => 'ACCOUNT_RENEW' } )->next;
    ok( $fee, 'The renewal adds the enrolment fee' );
    is( $fee && $fee->manager_id, $manager->borrowernumber, 'The fee is booked under the cash register manager' );
    is( C4::Context->userenv,     undef,                    'The userenv is reset afterwards' );

    $schema->storage->txn_rollback;
};

subtest 'The SEPA batch renews, pays through the cash register and writes the direct debit file' => sub {
    plan tests => 17;

    $schema->storage->txn_begin;

    my $outputdir = tempdir( CLEANUP => 1 );
    mkdir "$outputdir/batchprint";
    t::lib::Mocks::mock_config( 'outputdownloaddir', $outputdir );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $manager =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $category = $builder->build_object(
        { class => 'Koha::Patron::Categories', value => { enrolmentfee => 12.5, enrolmentperiod => 12 } } );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode   => $library->branchcode,
                categorycode => $category->categorycode,
                cardnumber   => 'SEPA-MANDATE-1',
                email        => 'sepa@example.org',
                dateexpiry   => dt_from_string->add( days => 7 )->ymd,
                lang         => 'default',
            }
        }
    );
    for my $code (qw( SEPA SEPA_IBAN SEPA_BIC SEPA_Sign Konto_von )) {
        Koha::Patron::Attribute::Types->find($code)
            // $builder->build_object( { class => 'Koha::Patron::Attribute::Types', value => { code => $code } } );
    }
    $patron->add_extended_attribute( { code => 'SEPA',      attribute => '1' } );
    $patron->add_extended_attribute( { code => 'SEPA_IBAN', attribute => 'DE89370400440532013000' } );
    $patron->add_extended_attribute( { code => 'SEPA_BIC',  attribute => 'COBADEFFXXX' } );
    $patron->add_extended_attribute( { code => 'SEPA_Sign', attribute => '2020-01-01' } );

    my $register_name = 'SEPA register ' . $patron->borrowernumber;
    C4::CashRegisterManagement->new( $library->branchcode, $manager->borrowernumber )->saveCashRegister(
        { name => $register_name, branchcode => $library->branchcode, no_branch_restriction => 1 },
        $manager->borrowernumber
    );

    $builder->build_object(
        {
            class => 'Koha::Notice::Templates',
            value => {
                module                 => 'members',
                code                   => 'SEPA_TEST',
                branchcode             => q{},
                lang                   => 'default',
                message_transport_type => 'email',
                is_html                => 0,
                title                  => 'SEPA',
                content                => 'Lastschrift [% accountlinesPayment.amount %]',
            }
        }
    );

    my %prefs = (
        ActivateCashRegisterTransactionsOnly         => 1,
        PermitConcurrentCashRegisterUsers            => 0,
        RequirePaymentType                           => 0,
        SepaDirectDebitCashRegisterName              => $register_name,
        SepaDirectDebitCashRegisterManagerCardnumber => $manager->cardnumber,
        SepaDirectDebitCreditorBic                   => 'GENODEF1NDR',
        SepaDirectDebitCreditorIban                  => 'DE90200691119999999999',
        SepaDirectDebitCreditorId                    => 'DE09ZZZ00000099999',
        SepaDirectDebitCreditorName                  => 'Test Library',
        SepaDirectDebitInitiatingPartyName           => 'TEST LIBRARY',
        SepaDirectDebitMessageIdHeader               => 'Lastschrift Test-',
        SepaDirectDebitRemittanceInfo                => 'Jahresentgelt',
        SepaDirectDebitBorrowerNoticeLettercode      => 'SEPA_TEST',
        SepaDirectDebitBorrowerNoticeMtt             => q{},
        SepaDirectDebitAccountTypes                  => 'ACCOUNT|ACCOUNT_RENEW',
        SepaDirectDebitMinFeeSum                     => '1.00',
        SepaDirectDebitLocalInstrumentCode           => 'CORE',
        SepaDirectDebitPaymentInstructionFileName    => 'pain.008.<<cc>><<yy>><<mm>><<dd>>.xml',
    );
    t::lib::Mocks::mock_preference( $_, $prefs{$_} ) for keys %prefs;
    C4::Context->unset_userenv;

    my $script = read_file('misc/cronjobs/membership_renewal_SEPA.pl');
    {
        local @ARGV = ( '-c', '-branch', $library->branchcode, '-sepaDirectDebitDelayDays', 14 );
        eval $script;    ## no critic (StringyEval)
        die $@ if $@;
    }

    $patron->discard_changes;
    ok( dt_from_string( $patron->dateexpiry ) > dt_from_string->add( days => 300 ), 'The membership is renewed' );

    my $fee = Koha::Account::Lines->search(
        { borrowernumber => $patron->borrowernumber, debit_type_code => 'ACCOUNT_RENEW' } )->next;
    ok( $fee, 'The renewal adds the enrolment fee' );
    is( $fee->amount + 0,            12.5,                     'The fee has the category enrolment fee' );
    is( $fee->manager_id,            $manager->borrowernumber, 'The fee is booked under the cash register manager' );
    is( $fee->amountoutstanding + 0, 0,                        'The fee is paid' );

    my $payment =
        Koha::Account::Lines->search( { borrowernumber => $patron->borrowernumber, credit_type_code => 'PAYMENT' } )
        ->next;
    ok( $payment, 'A payment is created' );
    is( $payment->amount + 0,   -12.5,                        'The payment covers the fee' );
    is( $payment->payment_type, 'SEPA',                       'The payment type is SEPA' );
    is( $payment->manager_id,   $manager->borrowernumber,     'The payment is booked under the cash register manager' );
    is( $payment->branchcode,   $library->branchcode,         'The payment carries the patron library' );
    is( $payment->description,  'Zahlung (SEPA Lastschrift)', 'The payment description' );
    is( $payment->note,         dt_from_string->add( days => 14 )->ymd, 'The note is the requested collection date' );

    my $booking =
        $schema->resultset('CashRegisterAccount')
        ->search( { accountlines_id => $payment->accountlines_id, action => 'PAYMENT' } )
        ->next;
    ok( $booking, 'The payment is booked in the SEPA cash register' );
    is( $booking && $booking->booking_amount + 0, 12.5, 'The register booking has the amount' );

    my ($file) = glob("$outputdir/batchprint/pain.008.*.xml");
    ok( $file && $file !~ /_no_payment_instructions/, 'The direct debit file is written' );
    my $xml = $file ? read_file( $file, binmode => ':encoding(UTF-8)' ) : q{};
    like(
        $xml,
        qr{<MndtId>SEPA-MANDATE-1</MndtId>.*<IBAN>DE89370400440532013000</IBAN>}s,
        'The file holds the mandate and the IBAN'
    );

    my $notice =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'SEPA_TEST' } )
        ->next;
    like( $notice ? $notice->content : q{}, qr/Lastschrift -?12\.5/, 'The SEPA notice is queued with the payment' );

    $schema->storage->txn_rollback;
};
