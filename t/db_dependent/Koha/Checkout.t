#!/usr/bin/perl

# Copyright 2020 Koha Development team
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

use Test::More tests => 3;
use t::lib::TestBuilder;

use Koha::Database;

my $builder = t::lib::TestBuilder->new;
my $schema  = Koha::Database->new->schema;

subtest 'library() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library  = $builder->build_object({ class => 'Koha::Libraries' });
    my $checkout = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                branchcode => $library->branchcode
            }
        }
    );

    is( ref($checkout->library), 'Koha::Library', 'Object type is correct' );
    is( $checkout->library->branchcode, $library->branchcode, 'Right library linked' );

    $schema->storage->txn_rollback;
};

subtest 'renewals() tests' => sub {

    plan tests => 2;
    $schema->storage->txn_begin;

    my $checkout = $builder->build_object(
        {
            class => 'Koha::Checkouts'
        }
    );
    my $renewal1 = $builder->build_object(
        {
            class => 'Koha::Checkouts::Renewals',
            value => { checkout_id => $checkout->issue_id }
        }
    );
    my $renewal2 = $builder->build_object(
        {
            class => 'Koha::Checkouts::Renewals',
            value => { checkout_id => $checkout->issue_id }
        }
    );

    is( ref($checkout->renewals), 'Koha::Checkouts::Renewals', 'Object set type is correct' );
    is( $checkout->renewals->count, 2, "Count of renewals is correct" );

    $schema->storage->txn_rollback;
};

subtest 'booking() tests' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $booking  = $builder->build_object( { class => 'Koha::Bookings' } );
    my $checkout = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { booking_id => $booking->booking_id }
        }
    );

    my $linked_booking = $checkout->booking;
    is( ref($linked_booking),        'Koha::Booking',      'booking() returns a Koha::Booking object' );
    is( $linked_booking->booking_id, $booking->booking_id, 'booking() returns the correct booking' );

    my $checkout_no_booking = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { booking_id => undef }
        }
    );

    my $no_booking = $checkout_no_booking->booking;
    is( $no_booking,      undef, 'booking() returns undef when no booking_id is set' );
    is( ref($no_booking), '',    'booking() returns empty ref when no booking_id is set' );

    $schema->storage->txn_rollback;
};
