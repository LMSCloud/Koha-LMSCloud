#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 10;

use C4::Context;
use Koha::Database;
use Koha::AdditionalFields;
use Koha::AuthorisedValues;
use Koha::AuthorisedValueCategories;

use t::lib::TestBuilder;
use t::lib::Mocks;

BEGIN {
    use_ok('Koha::Template::Plugin::AdditionalFields');
}

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

$schema->storage->txn_begin;

my $plugin = Koha::Template::Plugin::AdditionalFields->new();
ok( $plugin, "initialized AdditionalFields plugin" );

# Create test data
my $av_category = $builder->build_object(
    {
        class => 'Koha::AuthorisedValueCategories',
        value => {
            category_name   => 'TEST_CAT',
            is_system       => 0,
            is_integer_only => 0,
        }
    }
);

my $av1 = $builder->build_object(
    {
        class => 'Koha::AuthorisedValues',
        value => {
            category         => 'TEST_CAT',
            authorised_value => 'VAL1',
            lib              => 'Value 1',
            lib_opac         => 'Value 1 OPAC',
        }
    }
);

my $av2 = $builder->build_object(
    {
        class => 'Koha::AuthorisedValues',
        value => {
            category         => 'TEST_CAT',
            authorised_value => 'VAL2',
            lib              => 'Value 2',
            lib_opac         => 'Value 2 OPAC',
        }
    }
);

my $additional_field_with_av = $builder->build_object(
    {
        class => 'Koha::AdditionalFields',
        value => {
            tablename                 => 'test_bookings',
            name                      => 'Test Field with AV',
            authorised_value_category => 'TEST_CAT',
            marcfield                 => '245$a',
            marcfield_mode            => 'get',
            searchable                => 1,
            repeatable                => 0,
        }
    }
);

my $additional_field_without_av = $builder->build_object(
    {
        class => 'Koha::AdditionalFields',
        value => {
            tablename                 => 'test_bookings',
            name                      => 'Test Field without AV',
            authorised_value_category => undef,
            marcfield                 => '245$b',
            marcfield_mode            => 'set',
            searchable                => 0,
            repeatable                => 1,
        }
    }
);

# Test the all method
my $all_plugin  = $plugin->all( { tablename => 'test_bookings' } );
my $all_objects = Koha::AdditionalFields->search( { tablename => 'test_bookings' } );

is( $all_plugin->count, $all_objects->count, "all method returns correct count" );

# Test the with_authorised_values method
my $result = $plugin->with_authorised_values( { tablename => 'test_bookings' } );

ok( defined $result,                                 "with_authorised_values returns a result" );
ok( exists $result->{fields},                        "result contains fields key" );
ok( exists $result->{authorised_values_by_category}, "result contains authorised_values_by_category key" );

# Test that fields are returned correctly
is( scalar @{ $result->{fields} }, 2, "correct number of fields returned" );

# Test that authorized values are linked correctly
my $field_with_av;
foreach my $field ( @{ $result->{fields} } ) {
    if ( defined $field->{authorised_value_category_name} && $field->{authorised_value_category_name} eq 'TEST_CAT' ) {
        $field_with_av = $field;
        last;
    }
}
ok( defined $field_with_av, "field with authorized values found" );
is( scalar @{ $field_with_av->{authorised_values} }, 2, "correct number of authorized values linked" );

$schema->storage->txn_rollback;

1;
