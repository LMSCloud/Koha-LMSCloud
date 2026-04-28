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

use Koha::Database;
use Koha::Items;
use Koha::ItemTypes;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Item-level bookable flag with effective_bookable' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );

    my $bookable_itype = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => { bookable => 1 },
        }
    );

    my $non_bookable_itype = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => { bookable => 0 },
        }
    );

    my $item_null_on_bookable = $builder->build_sample_item(
        {
            itype    => $bookable_itype->itemtype,
            bookable => undef,
        }
    );
    is(
        $item_null_on_bookable->bookable, undef,
        'Item bookable is NULL when created with undef'
    );
    is(
        $item_null_on_bookable->effective_bookable, 1,
        'Item with NULL bookable inherits bookable=1 from itemtype'
    );

    my $item_null_on_non_bookable = $builder->build_sample_item(
        {
            itype    => $non_bookable_itype->itemtype,
            bookable => undef,
        }
    );
    is(
        $item_null_on_non_bookable->effective_bookable, 0,
        'Item with NULL bookable inherits bookable=0 from non-bookable itemtype'
    );

    my $item_explicit_zero = $builder->build_sample_item(
        {
            itype    => $bookable_itype->itemtype,
            bookable => 0,
        }
    );
    is(
        $item_explicit_zero->effective_bookable, 0,
        'Item with explicit bookable=0 overrides bookable itemtype'
    );

    my $item_explicit_one_on_non_bookable = $builder->build_sample_item(
        {
            itype    => $non_bookable_itype->itemtype,
            bookable => 1,
        }
    );
    is(
        $item_explicit_one_on_non_bookable->effective_bookable, 1,
        'Item with explicit bookable=1 overrides non-bookable itemtype'
    );

    my $item_explicit_one_on_bookable = $builder->build_sample_item(
        {
            itype    => $bookable_itype->itemtype,
            bookable => 1,
        }
    );
    is(
        $item_explicit_one_on_bookable->effective_bookable, 1,
        'Item with explicit bookable=1 on bookable itemtype returns 1'
    );

    my $item_explicit_zero_on_non_bookable = $builder->build_sample_item(
        {
            itype    => $non_bookable_itype->itemtype,
            bookable => 0,
        }
    );
    is(
        $item_explicit_zero_on_non_bookable->effective_bookable, 0,
        'Item with explicit bookable=0 on non-bookable itemtype returns 0'
    );

    $schema->storage->txn_rollback;
};

subtest 'Parent itemtype fallback via effective_bookable' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );

    my $parent_itype = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 1,
                parent_type => undef,
            },
        }
    );

    my $child_itype_not_bookable = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 0,
                parent_type => $parent_itype->itemtype,
            },
        }
    );

    my $child_itype_bookable = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 1,
                parent_type => $parent_itype->itemtype,
            },
        }
    );

    is(
        $child_itype_not_bookable->bookable, 0,
        'Child itemtype has bookable=0'
    );
    is(
        $parent_itype->bookable, 1,
        'Parent itemtype has bookable=1'
    );

    my $item_on_non_bookable_child = $builder->build_sample_item(
        {
            itype    => $child_itype_not_bookable->itemtype,
            bookable => undef,
        }
    );
    is(
        $item_on_non_bookable_child->effective_bookable, 1,
        'Item with NULL bookable on child itype(bookable=0) falls through to parent(bookable=1)'
    );

    my $item_on_bookable_child = $builder->build_sample_item(
        {
            itype    => $child_itype_bookable->itemtype,
            bookable => undef,
        }
    );
    is(
        $item_on_bookable_child->effective_bookable, 1,
        'Item with NULL bookable on child itype(bookable=1) inherits from child'
    );

    my $item_override_on_child = $builder->build_sample_item(
        {
            itype    => $child_itype_not_bookable->itemtype,
            bookable => 1,
        }
    );
    is(
        $item_override_on_child->effective_bookable, 1,
        'Item with explicit bookable=1 overrides child itype(bookable=0)'
    );

    my $parent_not_bookable = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 0,
                parent_type => undef,
            },
        }
    );

    my $child_of_non_bookable_parent = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 0,
                parent_type => $parent_not_bookable->itemtype,
            },
        }
    );

    my $item_both_zero = $builder->build_sample_item(
        {
            itype    => $child_of_non_bookable_parent->itemtype,
            bookable => undef,
        }
    );
    is(
        $item_both_zero->effective_bookable, 0,
        'Item inheriting from child(bookable=0) with parent(bookable=0) returns 0'
    );

    my $child_bookable_parent_not = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 1,
                parent_type => $parent_not_bookable->itemtype,
            },
        }
    );

    my $item_child_yes_parent_no = $builder->build_sample_item(
        {
            itype    => $child_bookable_parent_not->itemtype,
            bookable => undef,
        }
    );
    is(
        $item_child_yes_parent_no->effective_bookable, 1,
        'Item inheriting from child(bookable=1) with parent(bookable=0) uses child value'
    );

    my $parent_bookable_itype = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 1,
                parent_type => undef,
            },
        }
    );
    my $child_bookable_parent_yes = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 1,
                parent_type => $parent_bookable_itype->itemtype,
            },
        }
    );
    my $item_both_bookable = $builder->build_sample_item(
        {
            itype    => $child_bookable_parent_yes->itemtype,
            bookable => undef,
        }
    );
    is(
        $item_both_bookable->effective_bookable, 1,
        'Item inheriting from child(bookable=1) with parent(bookable=1) returns 1'
    );

    $schema->storage->txn_rollback;
};

subtest 'ItemType parent_type relationship' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    my $itemtype_source = $schema->source('Itemtype');
    ok( $itemtype_source->has_column('parent_type'), 'itemtypes table has parent_type column' );

    my $parent_type_info = $itemtype_source->column_info('parent_type');
    is( $parent_type_info->{is_nullable},    1, 'parent_type is nullable' );
    is( $parent_type_info->{is_foreign_key}, 1, 'parent_type is a foreign key' );

    my $parent = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 1,
                parent_type => undef,
            },
        }
    );

    my $child_a = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 0,
                parent_type => $parent->itemtype,
            },
        }
    );

    my $child_b = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                bookable    => 1,
                parent_type => $parent->itemtype,
            },
        }
    );

    my $parent_obj = $child_a->parent;
    isa_ok( $parent_obj, 'Koha::ItemType', 'child->parent returns a Koha::ItemType' );
    is(
        $parent_obj->itemtype, $parent->itemtype,
        'child->parent returns the correct parent itemtype'
    );

    my $children = $parent->children_with_localization;
    isa_ok( $children, 'Koha::ItemTypes', 'parent->children_with_localization returns Koha::ItemTypes' );
    my @child_codes = sort map { $_->itemtype } $children->as_list;
    my @expected    = sort( $child_a->itemtype, $child_b->itemtype );
    is_deeply(
        \@child_codes, \@expected,
        'parent->children_with_localization returns both child itemtypes'
    );

    $schema->storage->txn_rollback;
};
