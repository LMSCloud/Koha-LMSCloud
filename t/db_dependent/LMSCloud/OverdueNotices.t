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

# End-to-end tests for misc/cronjobs/overdue_notices.pl closed-day / run-mode
# behaviour. Instead of asserting on the script's source text (brittle to any
# reformatting), we run the REAL cron in-process (eval, as t/db_dependent/
# cronjobs/advance_notices_digest.t does) inside a transaction and assert on the
# rows it actually enqueues into message_queue.
#
# NB: no Test::NoWarnings here on purpose -- eval-ing the script more than once
# per run emits "Subroutine ... redefined" warnings (same as advance_notices_digest.t).

use Modern::Perl;

use Test::More tests => 12;

use File::Slurp qw( read_file );

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Notice::Template;
use Koha::Notice::Templates;
use Koha::Caches;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

# Slurped once; run_overdue_notices evaluates it with a fresh @ARGV each call.
my $script = read_file('misc/cronjobs/overdue_notices.pl');

sub run_overdue_notices {
    local @ARGV = @_;
    eval $script;    ## no critic (StringyEval)
    die $@ if $@;
}

# Build a patron at $library with one item overdue by $days_overdue days and an
# ODUE overdue rule firing at delay1 = 5 (email transport). Returns the patron.
sub build_overdue_scenario {
    my ( $library, $days_overdue ) = @_;

    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { overduenoticerequired => 1 } } );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->categorycode,
                branchcode   => $library,
                email        => 'overdue-test@example.com',
                debarred     => undef,
            }
        }
    );
    my $item = $builder->build_sample_item( { library => $library } );
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $library,
                date_due       => dt_from_string->subtract( days => $days_overdue )->ymd . ' 23:59:00',
            }
        }
    );
    my $rule = $builder->build(
        {
            source => 'Overduerule',
            value  => {
                branchcode   => $library,
                categorycode => $category->categorycode,
                delay1       => 5,
                letter1      => 'ODUE',
                debarred1    => 0,
                delay2       => undef,
                letter2      => undef,
                delay3       => undef,
                letter3      => undef,
            }
        }
    );
    $builder->build(
        {
            source => 'OverduerulesTransportType',
            value  => {
                overduerules_id        => $rule->{overduerules_id},
                letternumber           => 1,
                message_transport_type => 'email',
            }
        }
    );
    return $patron;
}

# Build an ODUE overdue rule for $library and $categorycode with one notice
# per given delay, e.g. [ 5, 10 ] for levels 1 and 2, sent by the given
# transports (email by default).
sub build_rule {
    my ( $library, $categorycode, $delays, $transports ) = @_;
    $transports //= ['email'];

    my %levels;
    foreach my $level ( 1 .. 5 ) {
        my $delay = $delays->[ $level - 1 ];
        $levels{"delay$level"}    = $delay;
        $levels{"letter$level"}   = defined $delay ? 'ODUE' : undef;
        $levels{"debarred$level"} = 0;
    }
    my $rule = $builder->build(
        {
            source => 'Overduerule',
            value  => { branchcode => $library, categorycode => $categorycode, %levels }
        }
    );
    foreach my $level ( 1 .. scalar @{$delays} ) {
        foreach my $transport ( @{$transports} ) {
            $builder->build(
                {
                    source => 'OverduerulesTransportType',
                    value  => {
                        overduerules_id        => $rule->{overduerules_id},
                        letternumber           => $level,
                        message_transport_type => $transport,
                    }
                }
            );
        }
    }
    return $rule;
}

# Build a patron of $category at $library with one item checked out there and
# overdue by $days_overdue days. $values overrides patron attributes. Returns
# the patron and the checkout.
sub build_overdue_checkout {
    my ( $library, $category, $days_overdue, $values ) = @_;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category,
                branchcode   => $library,
                email        => 'overdue-test@example.com',
                debarred     => undef,
                %{ $values // {} },
            }
        }
    );
    return ( $patron, add_overdue_checkout( $patron, $library, $days_overdue ) );
}

# Check out one more item at $library to $patron, overdue by $days_overdue days.
sub add_overdue_checkout {
    my ( $patron, $library, $days_overdue, $itemtype ) = @_;

    my $item = $builder->build_sample_item( { library => $library, $itemtype ? ( itype => $itemtype ) : () } );
    return $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $library,
                date_due       => dt_from_string->subtract( days => $days_overdue )->ymd . ' 23:59:00',
            }
        }
    );
}

# Patron attributes for a patron without any email address or SMS number
sub without_addresses {
    return { email => undef, emailpro => undef, B_email => undef, smsalertnumber => undef };
}

sub claim_levels {
    my ($issue_id) = @_;
    return $dbh->selectcol_arrayref(
        q|SELECT claim_level FROM overdue_issues WHERE issue_id = ? ORDER BY claim_level|,
        undef, $issue_id
    );
}

# The patron's debits as "type amount library", ordered by type and amount
sub debits {
    my ($borrowernumber) = @_;
    return $dbh->selectcol_arrayref(
        q|SELECT CONCAT_WS(' ', debit_type_code, ROUND(amount, 2), branchcode) FROM accountlines
          WHERE borrowernumber = ? AND debit_type_code IS NOT NULL ORDER BY debit_type_code, amount|,
        undef, $borrowernumber
    );
}

sub queued_messages {
    my ($borrowernumber) = @_;
    return $dbh->selectall_arrayref(
        q|SELECT message_transport_type, branchcode, to_address, content FROM message_queue
          WHERE borrowernumber = ? AND letter_code = 'ODUE'|,
        { Slice => {} }, $borrowernumber
    );
}

sub add_claiming_rule {
    my (%values) = @_;
    $builder->build(
        {
            source => 'ClaimingRule',
            value  => {
                branchcode       => '*', categorycode     => '*', itemtype         => '*',
                claim_fee_level1 => 0,   claim_fee_level2 => 0,   claim_fee_level3 => 0, claim_fee_level4 => 0,
                claim_fee_level5 => 0,
                %values,
            }
        }
    );
}

sub add_notice_fee_rule {
    my (%values) = @_;
    $builder->build(
        {
            source => 'NoticeFeeRule',
            value  => {
                branchcode => '*', categorycode => '*', message_transport_type => '*', letter_code => '*',
                %values,
            }
        }
    );
}

sub debit_types {
    my ($borrowernumber) = @_;
    return $dbh->selectcol_arrayref(
        q|SELECT debit_type_code FROM accountlines WHERE borrowernumber = ? AND debit_type_code IS NOT NULL
          ORDER BY debit_type_code|,
        undef, $borrowernumber
    );
}

sub mock_notice_preferences {
    my (%prefs) = @_;
    t::lib::Mocks::mock_preference( 'OverdueNoticeCalendar',                0 );
    t::lib::Mocks::mock_preference( 'OverdueNoticeSkipWhenClosed',          0 );
    t::lib::Mocks::mock_preference( 'useDaysMode',                          'Days' );
    t::lib::Mocks::mock_preference( 'BookMobileSupportEnabled',             0 );
    t::lib::Mocks::mock_preference( 'BookMobileStationOverdueRulesActive',  0 );
    t::lib::Mocks::mock_preference( 'MaxFine',                              '' );
    t::lib::Mocks::mock_preference( 'OverdueNoticePeriodCalculationMethod', 'byDate' );
    t::lib::Mocks::mock_preference( 'FamilyCardMemberOverdueReceiver',      'member' );
    t::lib::Mocks::mock_preference( $_,                                     $prefs{$_} ) for keys %prefs;
}

sub new_library {
    return $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } )->branchcode;
}

sub new_category {
    my (%values) = @_;
    return $builder->build_object(
        { class => 'Koha::Patron::Categories', value => { overduenoticerequired => 1, family_card => 0, %values } } )
        ->categorycode;
}

sub queued_odue {
    my ($borrowernumber) = @_;
    return $dbh->selectrow_array(
        q|SELECT COUNT(*) FROM message_queue WHERE borrowernumber = ? AND letter_code = 'ODUE'|,
        undef, $borrowernumber
    );
}

sub setup_odue_template {
    my ($content) = @_;

    # a global ODUE email template so the notice actually renders + enqueues
    Koha::Notice::Templates->search( { code => 'ODUE' } )->delete;
    Koha::Notice::Template->new(
        {
            module                 => 'circulation',
            code                   => 'ODUE',
            branchcode             => '',
            name                   => 'Overdue',
            title                  => 'Overdue',
            content                => $content // 'You have overdue items.',
            message_transport_type => 'email',
            lang                   => 'default',
            is_html                => 0,
        }
    )->store;
}

subtest 'Closed-day gate (OverdueNoticeSkipWhenClosed / OverdueNoticeCalendar)' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    setup_odue_template();

    t::lib::Mocks::mock_preference( 'OverdueNoticeCalendar', 0 );
    t::lib::Mocks::mock_preference( 'useDaysMode',           'Days' );

    my $open_lib =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } )->branchcode;
    my $closed_lib =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } )->branchcode;

    # mark TODAY (the run day) as a holiday only for $closed_lib
    my $today = dt_from_string;
    $schema->resultset('SpecialHoliday')->create(
        {
            branchcode  => $closed_lib,
            day         => $today->day,
            month       => $today->month,
            year        => $today->year,
            isexception => 0,
            description => 'test closed day',
        }
    );
    Koha::Caches->get_instance()->clear_from_cache( $closed_lib . '_holidays' );
    Koha::Cache::Memory::Lite->get_instance->flush;

    my $p_open   = build_overdue_scenario( $open_lib,   5 );
    my $p_closed = build_overdue_scenario( $closed_lib, 5 );

    # SkipWhenClosed ON: the closed branch's run day is a holiday -> its whole
    # branch is skipped; the open branch is unaffected.
    t::lib::Mocks::mock_preference( 'OverdueNoticeSkipWhenClosed', 1 );
    run_overdue_notices('-t');
    is( queued_odue( $p_open->borrowernumber ), 1, 'open branch: ODUE notice generated on the run day' );
    is(
        queued_odue( $p_closed->borrowernumber ), 0,
        'closed branch + OverdueNoticeSkipWhenClosed: no notice (branch skipped on the holiday run day)'
    );

    # A fresh patron on the closed branch, but SkipWhenClosed OFF (and calendar
    # off) -> the gate no longer fires, so the notice IS generated on the holiday.
    my $p_closed_again = build_overdue_scenario( $closed_lib, 5 );
    t::lib::Mocks::mock_preference( 'OverdueNoticeSkipWhenClosed', 0 );
    run_overdue_notices('-t');
    is(
        queued_odue( $p_closed_again->borrowernumber ), 1,
        'closed branch + SkipWhenClosed OFF + Calendar OFF: notice generated despite the holiday'
    );

    $schema->storage->txn_rollback;
};

subtest 'Triggered (exact) vs range: a skipped notice is lost vs deferred' => sub {
    plan tests => 2;

    # The delay1 = 5 notice is "due" at 5 overdue days. These patrons are 6 days
    # overdue (i.e. the day after) -- the situation a closed-day skip leaves you
    # in. In --triggered mode the exact match (== 5) is gone, so the notice is
    # LOST; in range mode ([5..90]) it is still due, so it is DEFERRED and sent.
    $schema->storage->txn_begin;
    setup_odue_template();

    t::lib::Mocks::mock_preference( 'OverdueNoticeCalendar',       0 );
    t::lib::Mocks::mock_preference( 'OverdueNoticeSkipWhenClosed', 0 );
    t::lib::Mocks::mock_preference( 'useDaysMode',                 'Days' );

    my $library =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } )->branchcode;

    my $p_triggered = build_overdue_scenario( $library, 6 );
    run_overdue_notices('-t');
    is(
        queued_odue( $p_triggered->borrowernumber ), 0,
        'triggered mode: 6 days overdue no longer matches delay 5 -> notice lost'
    );

    my $p_range = build_overdue_scenario( $library, 6 );
    run_overdue_notices();    # no -t -> range match
    is(
        queued_odue( $p_range->borrowernumber ), 1,
        'range mode: 6 days overdue still within [5..90] -> notice deferred and sent'
    );

    $schema->storage->txn_rollback;
};

subtest 'Five claim levels, recorded in the claim history' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences();

    my $library  = new_library();
    my $category = new_category();
    build_rule( $library, $category, [ 1, 2, 3, 4, 5 ] );
    my ( $patron, $checkout ) = build_overdue_checkout( $library, $category, 5 );

    run_overdue_notices();
    is( queued_odue( $patron->borrowernumber ), 1, 'one notice for the fifth level' );
    is_deeply( claim_levels( $checkout->issue_id ), [5], 'the checkout is recorded as claimed at level 5' );

    $schema->storage->txn_rollback;
};

subtest 'byPreviousClaimLevel: levels follow the claim history, once per day' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences( OverdueNoticePeriodCalculationMethod => 'byPreviousClaimLevel' );

    my $library  = new_library();
    my $category = new_category();
    build_rule( $library, $category, [ 5, 10 ] );

    # 12 days overdue would be level 2 by date, but nothing was claimed yet
    my ( $patron, $checkout ) = build_overdue_checkout( $library, $category, 12 );
    run_overdue_notices();
    is_deeply( claim_levels( $checkout->issue_id ), [1], 'first run claims level 1, not level 2' );

    run_overdue_notices();
    is_deeply( claim_levels( $checkout->issue_id ), [1], 'a second run on the same day claims nothing' );
    is( queued_odue( $patron->borrowernumber ), 1, 'and sends no second notice' );

    $dbh->do(
        q|UPDATE overdue_issues SET claim_time = DATE_SUB(NOW(), INTERVAL 3 DAY) WHERE issue_id = ?|, undef,
        $checkout->issue_id
    );
    run_overdue_notices();
    is_deeply( claim_levels( $checkout->issue_id ), [ 1, 2 ], 'after an earlier level 1 claim, level 2 follows' );

    $schema->storage->txn_rollback;
};

subtest 'Claiming fees per item and notice fees per letter, unless --nocharge' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences();
    $schema->resultset('ClaimingRule')->delete;
    $schema->resultset('NoticeFeeRule')->delete;

    my $library  = new_library();
    my $category = new_category();
    build_rule( $library, $category, [5] );
    $builder->build(
        {
            source => 'ClaimingRule',
            value  => {
                branchcode       => '*', categorycode     => '*', itemtype         => '*',
                claim_fee_level1 => 1.5, claim_fee_level2 => 0,   claim_fee_level3 => 0, claim_fee_level4 => 0,
                claim_fee_level5 => 0,
            }
        }
    );
    $builder->build(
        {
            source => 'NoticeFeeRule',
            value  => {
                branchcode => '*', categorycode => '*', message_transport_type => '*', letter_code => '*',
                notice_fee => 0.5,
            }
        }
    );

    my ($charged) = build_overdue_checkout( $library, $category, 5 );
    run_overdue_notices();
    is( queued_odue( $charged->borrowernumber ), 1, 'the notice is sent' );
    is_deeply(
        debit_types( $charged->borrowernumber ), [ 'CLAIM_LEVEL1', 'NOTIFICATION' ],
        'a claiming fee for the item and a notice fee for the letter'
    );

    my ($free) = build_overdue_checkout( $library, $category, 5 );
    run_overdue_notices('--nocharge');
    is( queued_odue( $free->borrowernumber ), 1, '--nocharge: the notice is still sent' );
    is_deeply( debit_types( $free->borrowernumber ), [], '--nocharge: nothing is charged' );

    $schema->storage->txn_rollback;
};

subtest 'FamilyCardMemberOverdueReceiver owner: the card owner gets the member\'s notice' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences( FamilyCardMemberOverdueReceiver => 'owner' );

    my $library         = new_library();
    my $family_category = new_category( family_card => 1 );
    my $member_category = new_category();
    build_rule( $library, $family_category, [5] );
    build_rule( $library, $member_category, [5] );

    my $owner = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $family_category, branchcode => $library, email => 'owner@example.com',
                debarred     => undef
            }
        }
    );
    my ($member) = build_overdue_checkout( $library, $member_category, 5 );
    $member->add_guarantor( { guarantor_id => $owner->borrowernumber, relationship => 'father' } );

    run_overdue_notices();
    is( queued_odue( $owner->borrowernumber ),  1, 'the family card owner gets the notice' );
    is( queued_odue( $member->borrowernumber ), 0, 'the member gets none' );

    $schema->storage->txn_rollback;
};

subtest 'byDate: each checkout is claimed at the level its overdue days reach, with that level\'s fee' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences();
    $schema->resultset('ClaimingRule')->delete;
    $schema->resultset('NoticeFeeRule')->delete;

    my $library  = new_library();
    my $category = new_category();
    build_rule( $library, $category, [ 5, 10 ] );
    add_claiming_rule( claim_fee_level1 => 1.5, claim_fee_level2 => 2.5 );

    my ( $first,  $first_checkout )   = build_overdue_checkout( $library, $category, 7 );
    my ( $second, @second_checkouts ) = build_overdue_checkout( $library, $category, 12 );
    push @second_checkouts, add_overdue_checkout( $second, $library, 12 );

    run_overdue_notices();
    is_deeply( claim_levels( $first_checkout->issue_id ), [1], '7 days overdue: claimed at level 1' );
    is_deeply(
        [ map { @{ claim_levels( $_->issue_id ) } } @second_checkouts ], [ 2, 2 ],
        '12 days overdue: both checkouts claimed at level 2'
    );
    is_deeply( debits( $first->borrowernumber ), ["CLAIM_LEVEL1 1.50 $library"], 'level 1 fee for the first patron' );
    is_deeply(
        debits( $second->borrowernumber ), [ "CLAIM_LEVEL2 2.50 $library", "CLAIM_LEVEL2 2.50 $library" ],
        'a level 2 fee per item for the second patron'
    );
    is( queued_odue( $second->borrowernumber ), 1, 'one notice lists both items' );

    $schema->storage->txn_rollback;
};

subtest 'MaxFine caps the claiming fees of a run' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences( MaxFine => 4 );
    $schema->resultset('ClaimingRule')->delete;
    $schema->resultset('NoticeFeeRule')->delete;

    my $library  = new_library();
    my $category = new_category();
    build_rule( $library, $category, [5] );
    add_claiming_rule( claim_fee_level1 => 3 );

    my ($patron) = build_overdue_checkout( $library, $category, 5 );
    add_overdue_checkout( $patron, $library, 5 );

    run_overdue_notices();
    is_deeply(
        debits( $patron->borrowernumber ), [ "CLAIM_LEVEL1 1.00 $library", "CLAIM_LEVEL1 3.00 $library" ],
        'the second fee is reduced to what is left up to MaxFine'
    );

    $schema->storage->txn_rollback;
};

subtest 'Notice fees follow the transport a notice is actually sent by' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;
    setup_odue_template('Total: <<total_fines>>');
    mock_notice_preferences();
    $schema->resultset('ClaimingRule')->delete;
    $schema->resultset('NoticeFeeRule')->delete;

    my $library        = new_library();
    my $category       = new_category();
    my $other_category = new_category();
    build_rule( $library, $category,       [5], [ 'email', 'sms' ] );
    build_rule( $library, $other_category, [5], [ 'email', 'sms' ] );
    add_notice_fee_rule( message_transport_type => 'email', notice_fee => 0.5 );
    add_notice_fee_rule( message_transport_type => 'sms',   notice_fee => 0.3 );
    add_notice_fee_rule( message_transport_type => 'print', notice_fee => 0.8 );
    add_notice_fee_rule( categorycode => $other_category,   message_transport_type => 'print', notice_fee => 1 );

    my ($with_email) = build_overdue_checkout( $library, $category,       5, { smsalertnumber => undef } );
    my ($without)    = build_overdue_checkout( $library, $category,       5, without_addresses() );
    my ($other)      = build_overdue_checkout( $library, $other_category, 5, without_addresses() );

    run_overdue_notices();
    my $transports = sub {
        [ sort map { $_->{message_transport_type} } @{ queued_messages(shift) } ];
    };
    is_deeply(
        $transports->( $with_email->borrowernumber ), ['email'],
        'email only: no letter exists for the SMS that falls back to print'
    );
    is_deeply(
        debits( $with_email->borrowernumber ), ["NOTIFICATION 0.50 $library"],
        'charged the email fee only, not the fee of the notice that was not sent'
    );
    is_deeply( $transports->( $without->borrowernumber ), ['print'], 'no address: a single print notice' );
    is_deeply( debits( $without->borrowernumber ), ["NOTIFICATION 0.80 $library"], 'charged the print fee once' );
    like(
        queued_messages( $without->borrowernumber )->[0]->{content}, qr/0[.,]80/,
        'the letter\'s total includes the fee for this notice'
    );
    is_deeply( $transports->( $other->borrowernumber ), ['print'], 'other category: a single print notice' );
    is_deeply(
        debits( $other->borrowernumber ), ["NOTIFICATION 1.00 $library"],
        'charged the print fee of the category\'s own rule'
    );

    $schema->storage->txn_rollback;
};

subtest 'Bookmobile stations are claimed under their parent library' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences( BookMobileSupportEnabled => 1 );
    $schema->resultset('ClaimingRule')->delete;
    $schema->resultset('NoticeFeeRule')->delete;

    my $parent = new_library();
    my $station =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => $parent } } )->branchcode;
    my $category = new_category();
    build_rule( $parent, $category, [5] );
    Koha::Notice::Template->new(
        {
            module                 => 'circulation',
            code                   => 'ODUE',
            branchcode             => $parent,
            name                   => 'Overdue',
            title                  => 'Overdue',
            content                => 'Parent library letter',
            message_transport_type => 'email',
            lang                   => 'default',
            is_html                => 0,
        }
    )->store;
    add_claiming_rule( claim_fee_level1 => 1 );
    add_claiming_rule( branchcode       => $parent, claim_fee_level1 => 2 );
    add_notice_fee_rule( notice_fee => 0.5 );

    my ($patron) = build_overdue_checkout( $station, $category, 5 );
    run_overdue_notices();
    my $messages = queued_messages( $patron->borrowernumber );
    is( scalar @{$messages},          1,                       'one notice, not one per library' );
    is( $messages->[0]->{branchcode}, $parent,                 'queued for the parent library' );
    is( $messages->[0]->{content},    'Parent library letter', 'using the parent library\'s letter' );
    is_deeply(
        debits( $patron->borrowernumber ), [ "CLAIM_LEVEL1 2.00 $parent", "NOTIFICATION 0.50 $parent" ],
        'charged by the parent library\'s rules, for the parent library'
    );

    t::lib::Mocks::mock_preference( 'BookMobileStationOverdueRulesActive', 1 );
    build_rule( $station, $category, [3] );
    my ($early) = build_overdue_checkout( $station, $category, 3 );
    run_overdue_notices();
    is( queued_odue( $early->borrowernumber ), 1, 'station rules active: the station\'s own rule applies' );
    is_deeply(
        debits( $early->borrowernumber ), [ "CLAIM_LEVEL1 2.00 $parent", "NOTIFICATION 0.50 $parent" ],
        'and is still charged by the parent library\'s rules'
    );

    my ($parent_patron) = build_overdue_checkout( $parent, $category, 3 );
    run_overdue_notices();
    is( queued_odue( $parent_patron->borrowernumber ), 0, 'and the parent library keeps its own rule' );

    $schema->storage->txn_rollback;
};

subtest 'A minor family card member without email is notified at the owner\'s address' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences();

    my $library         = new_library();
    my $family_category = new_category( family_card => 1 );
    my $member_category = new_category();
    build_rule( $library, $member_category, [5] );

    my $owner = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $family_category, branchcode => $library, email => 'owner@example.com',
                debarred     => undef
            }
        }
    );
    my ($minor) = build_overdue_checkout(
        $library, $member_category, 5,
        { %{ without_addresses() }, dateofbirth => dt_from_string->subtract( years => 10 )->ymd }
    );
    my ($adult) = build_overdue_checkout(
        $library, $member_category, 5,
        { %{ without_addresses() }, dateofbirth => dt_from_string->subtract( years => 30 )->ymd }
    );
    $_->add_guarantor( { guarantor_id => $owner->borrowernumber, relationship => 'father' } ) for $minor, $adult;

    run_overdue_notices();
    my $minor_messages = queued_messages( $minor->borrowernumber );
    is( $minor_messages->[0]->{message_transport_type}, 'email',             'the minor gets an email notice' );
    is( $minor_messages->[0]->{to_address},             'owner@example.com', 'sent to the card owner\'s address' );
    is( queued_messages( $adult->borrowernumber )->[0]->{message_transport_type}, 'print', 'an adult gets print' );

    $schema->storage->txn_rollback;
};

subtest '--test charges nothing and records no claims' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    setup_odue_template();
    mock_notice_preferences();
    $schema->resultset('ClaimingRule')->delete;
    $schema->resultset('NoticeFeeRule')->delete;

    my $library  = new_library();
    my $category = new_category();
    build_rule( $library, $category, [5] );
    add_claiming_rule( claim_fee_level1 => 1.5 );
    add_notice_fee_rule( notice_fee => 0.5 );

    my ( $patron, $checkout ) = build_overdue_checkout( $library, $category, 5 );
    run_overdue_notices('--test');
    is( queued_odue( $patron->borrowernumber ), 0, 'no notice is queued' );
    is_deeply( debits( $patron->borrowernumber ),   [], 'no fee is charged' );
    is_deeply( claim_levels( $checkout->issue_id ), [], 'no claim is recorded' );

    $schema->storage->txn_rollback;
};
