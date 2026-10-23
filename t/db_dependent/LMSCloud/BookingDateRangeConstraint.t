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

use Test::More tests => 3;
use Test::NoWarnings;
use Test::Mojo;

use Koha::Booking;
use Koha::Bookings;
use Koha::CirculationRules;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string output_pref );

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $t       = Test::Mojo->new('Koha::REST::V1');

t::lib::Mocks::mock_preference( 'RESTBasicAuth',              1 );
t::lib::Mocks::mock_preference( 'BookingDateRangeConstraint', 'issuelength' );

sub rfc3339 {
    my ($dt) = @_;
    return output_pref( { dt => $dt, dateformat => 'rfc3339' } );
}

sub setup {
    my $library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $builder->build(
        {
            source => 'UserPermission',
            value  => { borrowernumber => $librarian->id, module_bit => 1, code => 'manage_bookings' },
        }
    );
    $librarian->set_password( { password => 'thePassword123', skip_validation => 1 } );

    my $biblio = $builder->build_sample_biblio;
    my $item =
        $builder->build_sample_item( { bookable => 1, biblionumber => $biblio->id, homebranch => $library->id } );
    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            itemtype     => undef,
            branchcode   => undef,
            rules        => { issuelength => 2, daysmode => 'Days' },
        }
    );

    return {
        credentials => $librarian->userid . ':thePassword123',
        booking     => {
            biblio_id         => $biblio->id,
            item_id           => $item->id,
            patron_id         => $builder->build_object( { class => 'Koha::Patrons' } )->id,
            pickup_library_id => $library->id,
        },
    };
}

subtest 'POST beyond the loan period returns 400' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $data  = setup();
    my $start = dt_from_string->add( days => 5 )->truncate( to => 'day' );

    $t->post_ok(
        "//$data->{credentials}@/api/v1/bookings" => json => {
            %{ $data->{booking} },
            start_date => rfc3339($start),
            end_date   => rfc3339( $start->clone->add( days => 10 ) ),
        }
    )->status_is(400)->json_is( '/error_code' => 'booking_exceeds_max_period' );

    $t->post_ok(
        "//$data->{credentials}@/api/v1/bookings" => json => {
            %{ $data->{booking} },
            start_date => rfc3339($start),
            end_date   => rfc3339( $start->clone->add( days => 2 ) ),
        }
    )->status_is(201);

    is(
        Koha::Bookings->search( { biblio_id => $data->{booking}->{biblio_id} } )->count, 1,
        'Only the valid booking was stored'
    );

    $schema->storage->txn_rollback;
};

subtest 'PATCH extending beyond the loan period returns 400' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $data  = setup();
    my $start = dt_from_string->add( days => 5 )->truncate( to => 'day' );
    my $booking =
        Koha::Booking->new(
        { %{ $data->{booking} }, start_date => $start, end_date => $start->clone->add( days => 2 ) } )->store;

    $t->patch_ok( "//$data->{credentials}@/api/v1/bookings/"
            . $booking->booking_id => json => { end_date => rfc3339( $start->clone->add( days => 10 ) ) } )
        ->status_is(400)
        ->json_is( '/error_code' => 'booking_exceeds_max_period' );

    is(
        dt_from_string( Koha::Bookings->find( $booking->booking_id )->end_date )->ymd,
        $start->clone->add( days => 2 )->ymd,
        'End date unchanged'
    );

    $schema->storage->txn_rollback;
};
