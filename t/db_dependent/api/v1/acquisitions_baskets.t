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

use JSON qw(encode_json);

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new();
my $t       = Test::Mojo->new('Koha::REST::V1');

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list_managers() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron_with_permission =
      $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**11 } } )
      ;    ## 11 == acquisition
    my $patron_without_permission =
      $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $superlibrarian =
      $builder->build_object( { class => 'Koha::Patrons', value => { flags => 1 } } );
    my $password = 'thePassword123';
    $superlibrarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $superlibrarian->userid;
    $superlibrarian->discard_changes;

    my $api_filter = encode_json(
        {   'me.patron_id' =>
              [ $patron_with_permission->id, $patron_without_permission->id, $superlibrarian->id ]
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/baskets/managers?q=$api_filter")
      ->status_is(200)->json_is( [ $patron_with_permission->to_api, $superlibrarian->to_api ] );

    $schema->storage->txn_rollback;
};
