#!/usr/bin/env perl

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 1;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ItemTypes;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list_item_types() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    my $item_type = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => {
                itemtype                     => 'TEST_IT',
                parent_type                  => undef,
                description                  => 'Test item type',
                rentalcharge                 => 100.0,
                rentalcharge_daily           => 50.,
                rentalcharge_daily_calendar  => 0,
                rentalcharge_hourly          => 0.60,
                rentalcharge_hourly_calendar => 1,
                defaultreplacecost           => 1000.0,
                processfee                   => 20.0,
                notforloan                   => 0,
                imageurl          => 'https://upload.wikimedia.org/wikipedia/commons/1/1f/202208_test-tube-4.svg',
                summary           => 'An item type for testing',
                checkinmsg        => 'Checking in test',
                checkinmsgtype    => 'message',
                sip_media_type    => 'spt',
                hideinopac        => 1,
                searchcategory    => 'test search category',
                automatic_checkin => 0,
            }
        }
    );

    my $en = $builder->build_object(
        {
            class => 'Koha::Localizations',
            value => {
                entity      => 'itemtypes',
                code        => 'TEST_IT',
                lang        => 'en',
                translation => 'English word "test"',
            }
        }
    );
    my $sv = $builder->build_object(
        {
            class => 'Koha::Localizations',
            value => {
                entity      => 'itemtypes',
                code        => 'TEST_IT',
                lang        => 'sv_SE',
                translation => 'Swedish word "test"',
            }
        }
    );

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**2 }    # catalogue flag = 2
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    ## Authorized user tests
    # No category, 404 expected
    $t->get_ok("//$userid:$password@/api/v1/item_types")->status_is(200)->json_has('/0');

    for my $json ( @{ $t->tx->res->json } ) {
        if ( $json->{item_type} eq 'TEST_IT' ) {
            is( $json->{description}, 'Test item type' );
            ok( !exists $json->{translated_descriptions} );
        }
    }

    $t->get_ok( "//$userid:$password@/api/v1/item_types" => { 'x-koha-embed' => 'translated_descriptions' } )
        ->status_is(200)->json_has('/0');

    for my $json ( @{ $t->tx->res->json } ) {
        if ( $json->{item_type} eq 'TEST_IT' ) {
            is( $json->{description}, 'Test item type' );
            is_deeply(
                $json->{translated_descriptions},
                [
                    { lang => 'en',    translation => 'English word "test"' },
                    { lang => 'sv_SE', translation => 'Swedish word "test"' },
                ]
            );
        }
    }

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/item_types")->status_is(403);

    $schema->storage->txn_rollback;
};
