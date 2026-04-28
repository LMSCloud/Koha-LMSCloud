#!/usr/bin/perl

# Copyright 2026 LMSCloud GmbH
#
# This file is part of Koha.
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 5;
use Test::NoWarnings;
use Test::Exception;

use C4::Context;

use Koha::Database;
use Koha::Booking;
use Koha::CirculationRules;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'LMS-specific schema columns' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $branch_source = $schema->source('Branch');
    ok( $branch_source->has_column('mobilebranch'), 'branches has mobilebranch column' );

    my $itemtype_source = $schema->source('Itemtype');
    ok( $itemtype_source->has_column('parent_type'), 'itemtypes has parent_type column' );

    my $item_source = $schema->source('Item');
    ok( $item_source->has_column('bookable'), 'items has bookable column' );

    my $item_bookable_info = $item_source->column_info('bookable');
    is( $item_bookable_info->{is_nullable}, 1, 'items.bookable is nullable' );

    my $itemtype_bookable_info = $itemtype_source->column_info('bookable');
    is( $itemtype_bookable_info->{default_value}, 0, 'itemtypes.bookable defaults to 0' );

    my $sf_source   = $schema->source('SearchField');
    my $sf_col_info = $sf_source->column_info('type');
    my $enum_list   = $sf_col_info->{extra}{list};
    ok(
        ( grep { $_ eq 'availability' } @$enum_list ),
        'search_field.type enum includes availability'
    );

    $schema->storage->txn_rollback;
};

subtest 'LMS-specific system preferences' => sub {
    plan tests => 22;

    $schema->storage->txn_begin;

    my @prefs = (
        'BookMobileSupportEnabled',
        'ActivateCashRegisterTransactionsOnly',
        'AdhocNoticesLetterCodes',
        'BookingDateRangeConstraint',
        'BookingConstraintMode',
        'DivibibEnabled',
        'BrockhausSearchActive',
        'MunzingerEncyclopediaSearchEnabled',
        'EnableHoldsNotForLoanStatus',
        'IllItemtypes',
        'BibtipEnabled',
    );

    for my $pref (@prefs) {
        lives_ok { t::lib::Mocks::mock_preference( $pref, '1' ) } "$pref is mockable";
        is( C4::Context->preference($pref), '1', "$pref returns mocked value" );
    }

    $schema->storage->txn_rollback;
};

subtest 'LMS booking extensions' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    lives_ok { t::lib::Mocks::mock_preference( 'BookingDateRangeConstraint', 'issuelength' ) }
    'BookingDateRangeConstraint can be set to issuelength';
    is(
        C4::Context->preference('BookingDateRangeConstraint'),
        'issuelength',
        'BookingDateRangeConstraint returns issuelength'
    );

    lives_ok { t::lib::Mocks::mock_preference( 'BookingConstraintMode', 'enforce' ) }
    'BookingConstraintMode can be set';
    is(
        C4::Context->preference('BookingConstraintMode'),
        'enforce',
        'BookingConstraintMode returns mocked value'
    );

    can_ok( 'Koha::Booking', 'set_itemtype_filter' );
    can_ok( 'Koha::Booking', '_select_optimal_item' );
    can_ok( 'Koha::Booking', '_check_date_range_constraints' );

    my $rule_kinds = Koha::CirculationRules->rule_kinds;
    ok(
        exists $rule_kinds->{bookings_lead_period} && exists $rule_kinds->{bookings_trail_period},
        'CirculationRules supports bookings_lead_period and bookings_trail_period'
    );

    $schema->storage->txn_rollback;
};

subtest 'Elasticsearch availability type' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $source   = $schema->source('SearchField');
    my $col_info = $source->column_info('type');

    is( $col_info->{data_type}, 'enum', 'search_field.type is an enum column' );

    my $list = $col_info->{extra}{list};
    ok(
        ( grep { $_ eq 'availability' } @$list ),
        'search_field.type enum includes availability'
    );

    $schema->storage->txn_rollback;
};
