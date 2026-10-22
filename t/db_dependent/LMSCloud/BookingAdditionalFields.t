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
use Test::Mojo;

use Koha::AdditionalFields;
use Koha::AdditionalFieldValues;
use Koha::Booking;
use Koha::Bookings;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $t       = Test::Mojo->new('Koha::REST::V1');

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

sub build_booking {
    my $biblio = $builder->build_sample_biblio;
    my $item   = $builder->build_sample_item( { bookable => 1, biblionumber => $biblio->id } );
    return Koha::Booking->new(
        {
            biblio_id         => $biblio->id,
            item_id           => $item->id,
            patron_id         => $builder->build_object( { class => 'Koha::Patrons' } )->id,
            pickup_library_id => $builder->build_object( { class => 'Koha::Libraries' } )->id,
            start_date        => dt_from_string->add( days => 10 ),
            end_date          => dt_from_string->add( days => 12 ),
            status            => 'new',
        }
    )->store->get_from_storage;
}

sub field_values {
    my ($booking) = @_;
    return [ map { $_->value } Koha::AdditionalFieldValues->search( { record_id => $booking->booking_id } )->as_list ];
}

sub booking_manager {
    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $builder->build(
        {
            source => 'UserPermission',
            value  => { borrowernumber => $librarian->borrowernumber, module_bit => 1, code => 'manage_bookings' },
        }
    );
    $librarian->set_password( { password => 'thePassword123', skip_validation => 1 } );
    return $librarian->userid . ':thePassword123';
}

subtest 'store() saves additional fields when no column changed' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $field   = Koha::AdditionalField->new( { tablename => 'bookings', name => 'booking_note' } )->store;
    my $booking = build_booking();
    $booking->extended_attributes( [ { id => $field->id, value => 'old' } ] );
    is_deeply( field_values($booking), ['old'], 'Initial value stored' );

    $booking = Koha::Bookings->find( $booking->booking_id );
    $booking->store( { extended_attributes => [ { id => $field->id, value => 'new' } ] } );
    is_deeply( field_values($booking), ['new'], 'Additional field changed without a column change is saved' );

    $schema->storage->txn_rollback;
};

subtest 'PATCH without extended_attributes keeps the additional fields' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $credentials = booking_manager();
    my $field       = Koha::AdditionalField->new( { tablename => 'bookings', name => 'booking_note' } )->store;
    my $booking     = build_booking();
    $booking->extended_attributes( [ { id => $field->id, value => 'keep me' } ] );

    $t->patch_ok( "//$credentials@/api/v1/bookings/" . $booking->booking_id => json => { status => 'cancelled' } )
        ->status_is(200);

    is( Koha::Bookings->find( $booking->booking_id )->status, 'cancelled', 'Booking cancelled' );
    is_deeply( field_values($booking), ['keep me'], 'Additional field kept on a status-only PATCH' );

    $t->patch_ok( "//$credentials@/api/v1/bookings/" . $booking->booking_id => json => { extended_attributes => [] } );
    is_deeply( field_values($booking), [], 'An explicit empty list still clears the additional fields' );

    $schema->storage->txn_rollback;
};

subtest 'PATCH with extended_attributes only saves them' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $credentials = booking_manager();
    my $field       = Koha::AdditionalField->new( { tablename => 'bookings', name => 'booking_note' } )->store;
    my $booking     = build_booking();
    $booking->extended_attributes( [ { id => $field->id, value => 'old' } ] );

    $t->patch_ok( "//$credentials@/api/v1/bookings/"
            . $booking->booking_id => json => { extended_attributes => [ { field_id => $field->id, value => 'new' } ] }
    )->status_is(200);

    is_deeply( field_values($booking), ['new'], 'Additional field updated by an attribute-only PATCH' );

    $schema->storage->txn_rollback;
};
