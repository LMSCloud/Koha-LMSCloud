#!/usr/bin/perl

#
# This file is part of Koha
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

use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::DateUtils qw(dt_from_string);

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

$schema->storage->txn_begin;

# create a privileged user
my $librarian = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => { flags => 2 ** 4 } # borrowers flag = 4
    }
);
my $password = 'thePassword123';
$librarian->set_password( { password => $password, skip_validation => 1 } );
my $userid = $librarian->userid;

subtest 'password validation - account lock out' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'FailedLoginAttempts', 1 );

    my $json = {
        identifier => $userid,
        password   => "bad",
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
      ->status_is(400)
      ->json_is({ error => q{Validation failed} });

    $json->{password} = $password;

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
      ->status_is(400)
      ->json_is({ error => q{Validation failed} });

    $schema->storage->txn_rollback;
};

subtest 'password validation - unauthorized user' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2 ** 2 } # catalogue flag = 2
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    my $json = {
        identifier => $userid,
        password   => "test",
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
      ->status_is(403)
      ->json_is('/error' => 'Authorization failure. Missing required permission(s).');

    $schema->storage->txn_rollback;
};

subtest 'password validation - unauthenticated user' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $json = {
        identifier => "banana",
        password   => "test",
    };

    $t->post_ok( "/api/v1/auth/password/validation" => json => $json )
      ->json_is( '/error' => 'Authentication failure.' )
      ->status_is(401);

    $schema->storage->txn_rollback;
};

subtest 'Password validation - authorized requests tests' => sub {

    plan tests => 24;

    $schema->storage->txn_begin;

    # generate a random unused userid
    my $patron_to_delete = $builder->build_object( { class => 'Koha::Patrons' } );

    my $deleted_userid     = $patron_to_delete->userid;
    my $deleted_cardnumber = $patron_to_delete->cardnumber;

    $patron_to_delete->delete;

    my $json = {
        identifier => $librarian->userid,
        password   => $password,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 201, 'Validating using `cardnumber` works' )
        ->json_is(
        { cardnumber => $librarian->cardnumber, patron_id => $librarian->id, userid => $librarian->userid } );

    $json = {
        identifier => $librarian->cardnumber,
        password   => $password,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 201, 'Validating using `cardnumber` works' )
        ->json_is(
        { cardnumber => $librarian->cardnumber, patron_id => $librarian->id, userid => $librarian->userid } );

    $json = {
        identifier => $deleted_cardnumber,
        password   => $password,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 400, 'Validating using and invalid identifier fails' )
        ->json_is( { error => 'Validation failed' } );

    $json = {
        identifier => $deleted_userid,
        password   => $password,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 400, 'Validating using and invalid identifier fails' )
        ->json_is( { error => 'Validation failed' } );

    $json = {
        password => $password,
        userid   => $deleted_userid,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 400, 'Validating using and invalid userid fails' )->json_is( { error => 'Validation failed' } );

    $json = {
        password => $password,
        userid   => $userid,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 201, 'Validating using the `userid` attribute works' )
        ->json_is(
        { cardnumber => $librarian->cardnumber, patron_id => $librarian->id, userid => $librarian->userid } );

    $json = {
        password => $password,
        userid   => $librarian->cardnumber,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 400, 'Validating using a cardnumber as userid fails' )->json_is( { error => 'Validation failed' } );

    $json = {
        identifier => $userid,
        password   => $password,
        userid     => $userid,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )
        ->status_is( 400, 'Passing both parameters forbidden' )
        ->json_is( { error => 'Bad request. Only one identifier attribute can be passed.' } );

    $schema->storage->txn_rollback;
};

subtest 'password validation - expired password' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**2 }    # catalogue flag = 2
        }
    );
    my $patron_password = 'thePassword123';
    $patron->set_password( { password => $patron_password, skip_validation => 1 } );

    my $date            = dt_from_string();
    my $expiration_date = $date->subtract( days => 1 );

    $patron->password_expiration_date($expiration_date)->store;

    my $json = {
        identifier => $patron->userid,
        password   => $patron_password,
    };

    $t->post_ok( "//$userid:$password@/api/v1/auth/password/validation" => json => $json )->status_is(400)
        ->json_is( '/error' => 'Password expired' );

    $schema->storage->txn_rollback;
};

$schema->storage->txn_rollback;
