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

use Koha::Booking;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# The item assigned to a new booking without an item, starting in 10 days
sub assigned_item {
    my ($biblio) = @_;

    my $booking = Koha::Booking->new(
        {
            biblio_id         => $biblio->id,
            patron_id         => $builder->build_object( { class => 'Koha::Patrons' } )->id,
            pickup_library_id => $builder->build_object( { class => 'Koha::Libraries' } )->id,
            start_date        => dt_from_string->add( days => 10 ),
            end_date          => dt_from_string->add( days => 12 ),
        }
    );
    $booking->_assign_item_for_booking;
    return $booking->item_id;
}

# Checked out, but due back before the booking starts
sub check_out {
    my ($item) = @_;

    my $due = dt_from_string->add( days => 5 );
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { itemnumber => $item->id, date_due => $due },
        }
    );
    $item->onloan($due)->store;
    return;
}

subtest 'items on the shelf are preferred over checked out items' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my $biblio  = $builder->build_sample_biblio;
    my $on_loan = $builder->build_sample_item( { bookable => 1, biblionumber => $biblio->id } );
    my $shelf   = $builder->build_sample_item( { bookable => 1, biblionumber => $biblio->id } );
    check_out($on_loan);

    is( assigned_item($biblio), $shelf->id, 'The item on the shelf is assigned' );

    $schema->storage->txn_rollback;
};

subtest 'the shelf preference comes before the longest free period' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my $biblio  = $builder->build_sample_biblio;
    my $on_loan = $builder->build_sample_item( { bookable => 1, biblionumber => $biblio->id } );
    my $shelf   = $builder->build_sample_item( { bookable => 1, biblionumber => $biblio->id } );
    check_out($on_loan);

    # The item on the shelf is booked again soon after, the checked out one is not
    $builder->build_object(
        {
            class => 'Koha::Bookings',
            value => {
                biblio_id  => $biblio->id,
                item_id    => $shelf->id,
                start_date => dt_from_string->add( days => 15 ),
                end_date   => dt_from_string->add( days => 17 ),
                status     => 'new',
            }
        }
    );

    is( assigned_item($biblio), $shelf->id, 'The item on the shelf is assigned' );

    $schema->storage->txn_rollback;
};

subtest 'a checked out item is assigned when it is the only one free' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my $biblio  = $builder->build_sample_biblio;
    my $on_loan = $builder->build_sample_item( { bookable => 1, biblionumber => $biblio->id } );
    check_out($on_loan);

    is( assigned_item($biblio), $on_loan->id, 'The checked out item is still assignable' );

    $schema->storage->txn_rollback;
};
