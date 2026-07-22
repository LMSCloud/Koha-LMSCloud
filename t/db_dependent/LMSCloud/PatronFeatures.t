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

use Test::More tests => 4;
use Test::NoWarnings;

use C4::Context;
use C4::Overdues;

use Koha::Database;
use Koha::Libraries;
use Koha::Library;
use Koha::Patrons;
use Koha::Patron::Relationships;
use Koha::Template::Plugin::Branches;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'BookMobile support' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    # 1. Verify mobilebranch column exists in Branch schema
    ok(
        Koha::Database->new->schema->source('Branch')->has_column('mobilebranch'),
        'Branch schema has mobilebranch column'
    );

    # 2. Verify BookMobileSupportEnabled syspref is accessible
    my $pref_value;
    eval { $pref_value = C4::Context->preference('BookMobileSupportEnabled'); };
    ok( !$@, 'BookMobileSupportEnabled syspref can be read without dying' );

    # 3. Create a parent branch and a mobile station branch
    my $parent_branch = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => {
                mobilebranch => undef,
            },
        }
    );

    my $mobile_branch = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => {
                mobilebranch => $parent_branch->branchcode,
            },
        }
    );

    # Verify the mobilebranch column is accessible on the objects
    is( $parent_branch->mobilebranch, undef, 'Parent branch has no mobilebranch set' );
    is(
        $mobile_branch->mobilebranch, $parent_branch->branchcode,
        'Mobile station branch has mobilebranch pointing to parent'
    );

    # 4. Verify Koha::Libraries has get_effective_branch method
    can_ok( 'Koha::Libraries', 'get_effective_branch' );

    # 5. Test get_effective_branch returns parent when branch is a mobile station
    my $libraries = Koha::Libraries->new;
    my $effective = $libraries->get_effective_branch( $mobile_branch->branchcode );
    is(
        $effective, $parent_branch->branchcode,
        'get_effective_branch returns the parent mobilebranch for a mobile station'
    );

    # 6. Test get_effective_branch returns same branch when not a mobile station
    my $effective_parent = $libraries->get_effective_branch( $parent_branch->branchcode );
    is(
        $effective_parent, $parent_branch->branchcode,
        'get_effective_branch returns same branchcode for a non-mobile branch'
    );

    $schema->storage->txn_rollback;
};

subtest 'Family card' => sub {
    plan tests => 9;

    $schema->storage->txn_begin;

    # 1. Verify Koha::Patron has family card related methods
    can_ok( 'Koha::Patron', 'family_checkout_count' );
    can_ok( 'Koha::Patron', 'is_family_card' );
    can_ok( 'Koha::Patron', 'get_family_card_id' );

    # 2. Verify guarantor relationship methods exist
    can_ok( 'Koha::Patron', 'guarantor_relationships' );
    can_ok( 'Koha::Patron', 'guarantee_relationships' );

    # 3. Test hasFamilyCardRelationship on Koha::Patron::Relationships
    can_ok( 'Koha::Patron::Relationships', 'hasFamilyCardRelationship' );

    # 4. Create a patron category with family_card enabled
    my $family_category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => {
                category_type => 'A',
                family_card   => 1,
            },
        }
    );

    my $regular_category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => {
                category_type => 'A',
                family_card   => 0,
            },
        }
    );

    # Create a guarantor patron with family card category
    my $guarantor = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $family_category->categorycode,
            },
        }
    );

    # Create a child patron with regular category
    my $child = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $regular_category->categorycode,
            },
        }
    );

    # Verify is_family_card works
    ok( $guarantor->is_family_card, 'Patron with family_card category returns true for is_family_card' );

    # Mock borrowerRelationship to allow 'parent' as a valid relationship type
    t::lib::Mocks::mock_preference( 'borrowerRelationship', 'parent' );

    # Link child to guarantor
    $child->add_guarantor( { guarantor_id => $guarantor->borrowernumber, relationship => 'parent' } );

    # Test hasFamilyCardRelationship via the child's guarantor_relationships
    my $relationships = $child->guarantor_relationships;
    ok(
        $relationships->hasFamilyCardRelationship,
        'hasFamilyCardRelationship returns true when guarantor has family card'
    );

    # Test get_family_card_id returns the guarantor's borrowernumber
    is(
        $child->get_family_card_id, $guarantor->borrowernumber,
        'get_family_card_id returns the family card guarantor borrowernumber'
    );

    $schema->storage->txn_rollback;
};

subtest 'GetBranchcodesWithOverdueRules honours BookMobile station/bus rule mode' => sub {
    plan tests => 6;

    # This is the function that answers the test plan's central question:
    # "Werden die Regeln der Haltestelle oder die des Bücherbus berücksichtigt?"
    # It picks which branches the overdue cron iterates, driven by the two
    # BookMobile sysprefs and the station's mobilebranch pointer.
    $schema->storage->txn_begin;

    my $bus = $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } )->branchcode;
    my $station =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => $bus } } )->branchcode;

    # The bus has an overdue rule; the station has none (initially).
    $builder->build( { source => 'Overduerule', value => { branchcode => $bus, delay1 => 5 } } );

    my $has = sub { my ( $code, @list ) = @_; return scalar grep { $_ eq $code } @list; };

    # Mode A: station rules NOT active -> the bus's rules cover its stations, so
    # the cron iterates the bus but NOT the station.
    t::lib::Mocks::mock_preference( 'BookMobileSupportEnabled',            1 );
    t::lib::Mocks::mock_preference( 'BookMobileStationOverdueRulesActive', 0 );
    my @a = C4::Overdues::GetBranchcodesWithOverdueRules();
    ok( $has->( $bus, @a ), 'station-rules OFF: bus (with rules) is processed' );
    ok( !$has->( $station, @a ), 'station-rules OFF: station is NOT processed (bus rules cover it)' );

    # Mode B: station rules active; the station has no own rules but its bus does,
    # so the station is pulled in via the UNION and processed in its own right.
    t::lib::Mocks::mock_preference( 'BookMobileStationOverdueRulesActive', 1 );
    my @b = C4::Overdues::GetBranchcodesWithOverdueRules();
    ok( $has->( $bus,     @b ), 'station-rules ON: bus still processed' );
    ok( $has->( $station, @b ), 'station-rules ON: station processed (bus has rules to inherit)' );

    # Mode C: BookMobile support off entirely -> station is excluded regardless of
    # the station-rules pref (the pref only matters while support is on).
    t::lib::Mocks::mock_preference( 'BookMobileSupportEnabled',            0 );
    t::lib::Mocks::mock_preference( 'BookMobileStationOverdueRulesActive', 1 );
    my @c = C4::Overdues::GetBranchcodesWithOverdueRules();
    ok( $has->( $bus, @c ), 'support OFF: bus processed' );
    ok( !$has->( $station, @c ), 'support OFF: station NOT processed regardless of station-rules pref' );

    $schema->storage->txn_rollback;
};
