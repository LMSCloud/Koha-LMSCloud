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

use Test::More tests => 2;

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

sub queued_odue {
    my ($borrowernumber) = @_;
    return $dbh->selectrow_array(
        q|SELECT COUNT(*) FROM message_queue WHERE borrowernumber = ? AND letter_code = 'ODUE'|,
        undef, $borrowernumber
    );
}

sub setup_odue_template {

    # a global ODUE email template so the notice actually renders + enqueues
    Koha::Notice::Templates->search( { code => 'ODUE' } )->delete;
    Koha::Notice::Template->new(
        {
            module                 => 'circulation',
            code                   => 'ODUE',
            branchcode             => '',
            name                   => 'Overdue',
            title                  => 'Overdue',
            content                => 'You have overdue items.',
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
