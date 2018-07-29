#!/usr/bin/env perl

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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Test::More tests => 1;
use Test::MockModule;
use Test::Mojo;
use Test::Warn;

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Auth;
use Koha::Illrequests;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'SessionStorage', 'tmp' );

my $remote_address = '127.0.0.1';
my $t              = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 15;

    my $illreqmodule = Test::MockModule->new('Koha::Illrequest');
    # Mock ->capabilities
    $illreqmodule->mock( 'capabilities', sub { return 'capable'; } );
    # Mock ->metadata
    $illreqmodule->mock( 'metadata', sub { return 'metawhat?'; } );

    $schema->storage->txn_begin;

    Koha::Illrequests->search->delete;
    # ill => 22 (userflags.sql)
    my ( $borrowernumber, $session_id ) = create_user_and_session({ authorized => 22 });

    ## Authorized user tests
    # No requests, so empty array should be returned
    my $tx = $t->ua->build_tx( GET => '/api/v1/illrequests' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
    $tx->req->env( { REMOTE_ADDR => $remote_address } );
    $t->request_ok($tx)->status_is(200)->json_is( [] );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );

    # Create an ILL request
    my $illrequest = $builder->build_object(
        {
            class => 'Koha::Illrequests',
            value => {
                branchcode     => $library->branchcode,
                borrowernumber => $patron->borrowernumber
            }
        }
    );

    # One illrequest created, should get returned
    $tx = $t->ua->build_tx( GET => '/api/v1/illrequests' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
    $tx->req->env( { REMOTE_ADDR => $remote_address } );
    $t->request_ok($tx)->status_is(200)->json_is( [ $illrequest->TO_JSON ] );

    # One illrequest created, returned with augmented data
    $tx = $t->ua->build_tx( GET =>
          '/api/v1/illrequests?embed=patron,library,capabilities,metadata' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
    $tx->req->env( { REMOTE_ADDR => $remote_address } );
    $t->request_ok($tx)->status_is(200)->json_is(
        [
            $illrequest->TO_JSON(
                { patron => 1, library => 1, capabilities => 1, metadata => 1 }
            )
        ]
    );

    # Create another ILL request
    my $illrequest2 = $builder->build_object(
        {
            class => 'Koha::Illrequests',
            value => {
                branchcode     => $library->branchcode,
                borrowernumber => $patron->borrowernumber
            }
        }
    );

    # Two illrequest created, should get returned
    $tx = $t->ua->build_tx( GET => '/api/v1/illrequests' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
    $tx->req->env( { REMOTE_ADDR => $remote_address } );
    $t->request_ok($tx)->status_is(200)
      ->json_is( [ $illrequest->TO_JSON, $illrequest2->TO_JSON ] );

    # Warn on unsupported query parameter
    $tx = $t->ua->build_tx( GET => '/api/v1/illrequests?request_blah=blah' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
    $tx->req->env( { REMOTE_ADDR => $remote_address } );
    $t->request_ok($tx)->status_is(400)->json_is(
        [{ path => '/query/request_blah', message => 'Malformed query string'}]
    );

    $schema->storage->txn_rollback;
};

sub create_user_and_session {

    my $args = shift;
    my $dbh  = C4::Context->dbh;

    my $flags = ( $args->{authorized} ) ? 2**$args->{authorized} : 0;

    my $user = $builder->build(
        {
            source => 'Borrower',
            value  => {
                flags => $flags
            }
        }
    );

    # Create a session for the authorized user
    my $session = C4::Auth::get_session('');
    $session->param( 'number',   $user->{borrowernumber} );
    $session->param( 'id',       $user->{userid} );
    $session->param( 'ip',       '127.0.0.1' );
    $session->param( 'lasttime', time() );
    $session->flush;

    return ( $user->{borrowernumber}, $session->id );
}

1;
