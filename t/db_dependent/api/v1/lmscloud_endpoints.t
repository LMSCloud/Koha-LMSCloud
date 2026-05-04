#!/usr/bin/env perl

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

# Test::NoWarnings intentionally omitted: the ALV/ZKSH controllers emit
# diagnostic STDERR output (Data::Dumper traces) that bleeds into the
# test runner. Smoke goal here is route registration and auth gating.

use Modern::Perl;

use Test::More tests => 4;
use Test::Mojo;
use MIME::Base64 qw( encode_base64 );

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'Public coverflow endpoints registered' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    for my $path (
        '/api/v1/public/coverflow_data_biblionumber/99999999',
        '/api/v1/public/coverflow_data_nearby_items/99999999',
        '/api/v1/public/coverflow_data_query?query=__no_match_zzz__',
        )
    {
        $t->get_ok($path);
        isnt( $t->tx->res->code, 404, "route registered: $path" );
    }

    $schema->storage->txn_rollback;
};

subtest 'ALV ILL endpoint registered, requires auth' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    $t->post_ok( '/api/v1/alv_illrequests' => json => { mediumTitle => 'X' } )->status_is(401);

    my $patron   = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 1 } } );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $auth = 'Basic ' . encode_base64( $patron->userid . ":$password", '' );

    my $tx = $t->ua->build_tx( POST => '/api/v1/alv_illrequests' => json => {} );
    $tx->req->headers->authorization($auth);
    $t->request_ok($tx);
    isnt( $t->tx->res->code, 404, 'ALV endpoint reachable when authed' );

    $schema->storage->txn_rollback;
};

subtest 'ZKSH ILL endpoints registered, require auth' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    $t->post_ok( '/api/v1/zksha_illrequests' => json => { Art => 'RLV-Bestellung' } )->status_is(401);
    $t->post_ok( '/api/v1/zkshp_illrequests' => json => { Art => 'RLV-Bestellinfo' } )->status_is(401);

    $schema->storage->txn_rollback;
};

subtest 'BZSH endpoints registered, require auth' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    $t->get_ok('/api/v1/bzsh/bib_updates')->status_is(401);
    $t->get_ok('/api/v1/bzsh/order_status')->status_is(401);

    $schema->storage->txn_rollback;
};
