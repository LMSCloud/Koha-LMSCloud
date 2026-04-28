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

use Modern::Perl;
use Test::More tests => 5;
use Test::NoWarnings;

use File::Slurp qw( read_file );

use Koha::Database;
use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Reserves qw( IsAvailableForItemLevelRequest ItemsAnyAvailableAndNotRestricted );
use Koha::Libraries;
use Koha::CirculationRules;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'EnableHoldsNotForLoanStatus syspref-driven notforloan check' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    Koha::CirculationRules->set_rules(
        {
            categorycode => '*',
            itemtype     => '*',
            branchcode   => '*',
            rules        => {
                onshelfholds => 0,
            }
        }
    );

    my $item_nfl_neg1 = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            notforloan   => -1,
        }
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1' );
    ok(
        C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is holdable when EnableHoldsNotForLoanStatus includes -1'
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is NOT holdable when EnableHoldsNotForLoanStatus is empty'
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '0' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is NOT holdable when EnableHoldsNotForLoanStatus is 0 (does not match -1)'
    );

    my $item_nfl_neg2 = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            notforloan   => -2,
        }
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1|-2' );
    ok(
        C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is holdable when EnableHoldsNotForLoanStatus is -1|-2'
    );
    ok(
        C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg2, $patron ),
        'notforloan=-2 item is holdable when EnableHoldsNotForLoanStatus is -1|-2'
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg2, $patron ),
        'notforloan=-2 item is NOT holdable when EnableHoldsNotForLoanStatus is only -1'
    );

    my $item_nfl_pos = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            notforloan   => 1,
        }
    );
    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1|-2|1' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_pos, $patron ),
        'notforloan=1 (positive) item is always blocked regardless of EnableHoldsNotForLoanStatus (early return in function)'
    );

    Koha::CirculationRules->set_rules(
        {
            categorycode => '*',
            itemtype     => '*',
            branchcode   => '*',
            rules        => {
                onshelfholds => 2,
            }
        }
    );

    Koha::Cache::Memory::Lite->get_instance->flush;

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1|-2' );

    my $result = ItemsAnyAvailableAndNotRestricted( { biblionumber => $biblio->biblionumber, patron => $patron } );
    is(
        $result, 0,
        'ItemsAnyAvailableAndNotRestricted returns 0 when all items have negative notforloan and EnableHoldsNotForLoanStatus matches them (items treated as unavailable via notforloan)'
    );

    $schema->storage->txn_rollback;
};

subtest 'Mobile branch (get_effective_branch) in C4::Reserves' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $source = read_file('C4/Reserves.pm');
    like( $source, qr/use Koha::Libraries/, 'C4::Reserves imports Koha::Libraries' );
    like(
        $source,
        qr/Koha::Libraries->get_effective_branch/,
        'C4::Reserves references get_effective_branch'
    );

    can_ok( 'Koha::Libraries', 'get_effective_branch' );

    my $parent_library = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => { mobilebranch => undef }
        }
    );

    my $result = Koha::Libraries->get_effective_branch( $parent_library->branchcode );
    is( $result, $parent_library->branchcode, 'get_effective_branch returns same branchcode when no mobilebranch set' );

    my $mobile_station = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => { mobilebranch => $parent_library->branchcode }
        }
    );

    $result = Koha::Libraries->get_effective_branch( $mobile_station->branchcode );
    is( $result, $parent_library->branchcode, 'get_effective_branch returns parent branchcode for mobile station' );

    $schema->storage->txn_rollback;
};

subtest 'NoticeFees and SuppressNotificationOnHolds in C4::Reserves' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $source = read_file('C4/Reserves.pm');

    like( $source, qr/use C4::NoticeFees/, 'C4::Reserves imports C4::NoticeFees' );
    like(
        $source,
        qr/C4::NoticeFees->new\(\)/,
        'C4::Reserves instantiates C4::NoticeFees in _koha_notify_reserve'
    );

    like(
        $source,
        qr/SuppressNotificationOnHolds/,
        'C4::Reserves references SuppressNotificationOnHolds syspref'
    );

    use_ok('C4::NoticeFees');

    $schema->storage->txn_rollback;
};

subtest 'ILL hold fee check in AddReserve' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $source = read_file('C4/Reserves.pm');

    like( $source, qr/use Koha::Illrequest/, 'C4::Reserves imports Koha::Illrequest' );
    like(
        $source,
        qr/Koha::Illrequest->checkIfIllItem/,
        'AddReserve calls Koha::Illrequest->checkIfIllItem'
    );
    like(
        $source,
        qr/IllModule.*checkIfIllItem|checkIfIllItem.*IllModule/s,
        'ILL check is gated behind IllModule syspref'
    );
    like(
        $source,
        qr/reservefee_acceptable/,
        'AddReserve uses reservefee_acceptable flag to gate hold fee charging'
    );

    t::lib::Mocks::mock_preference( 'IllModule', 1 );

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio       = $builder->build_sample_biblio;
    my $ill_itemtype = 'ILL_T';

    my $itemtype_obj = Koha::ItemTypes->find($ill_itemtype);
    if ($itemtype_obj) {
        $itemtype_obj->delete;
    }
    $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => { itemtype => $ill_itemtype, notforloan => 0 }
        }
    );

    my $item = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            itype        => $ill_itemtype,
        }
    );

    t::lib::Mocks::mock_preference( 'IllItemtypes', $ill_itemtype );

    my ( $is_ill, $request ) = Koha::Illrequest->checkIfIllItem( $item->unblessed );
    is( $is_ill, 1, 'checkIfIllItem correctly identifies item with ILL itemtype as an ILL item' );

    $schema->storage->txn_rollback;
};
