#!/usr/bin/perl

# Copyright 2024 Koha Development team
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
use utf8;

use Test::More tests => 2;

use Test::Exception;

use Koha::DateUtils qw( dt_from_string );

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Relation accessor tests' => sub {
    plan tests => 6;

    subtest 'biblio relation tests' => sub {
        plan tests => 3;
        $schema->storage->txn_begin;

        my $biblio = $builder->build_sample_biblio;
        my $booking =
            $builder->build_object( { class => 'Koha::Bookings', value => { biblio_id => $biblio->biblionumber } } );

        my $THE_biblio = $booking->biblio;
        is( ref($THE_biblio),          'Koha::Biblio',        "Koha::Booking->biblio returns a Koha::Biblio object" );
        is( $THE_biblio->biblionumber, $biblio->biblionumber, "Koha::Booking->biblio returns the links biblio object" );

        $THE_biblio->delete;
        $booking = Koha::Bookings->find( $booking->booking_id );
        is( $booking, undef, "The booking is deleted when the biblio it's attached to is deleted" );

        $schema->storage->txn_rollback;
    };

    subtest 'patron relation tests' => sub {
        plan tests => 3;
        $schema->storage->txn_begin;

        my $patron = $builder->build_object( { class => "Koha::Patrons" } );
        my $booking =
            $builder->build_object( { class => 'Koha::Bookings', value => { patron_id => $patron->borrowernumber } } );

        my $THE_patron = $booking->patron;
        is( ref($THE_patron), 'Koha::Patron', "Koha::Booking->patron returns a Koha::Patron object" );
        is(
            $THE_patron->borrowernumber, $patron->borrowernumber,
            "Koha::Booking->patron returns the links patron object"
        );

        $THE_patron->delete;
        $booking = Koha::Bookings->find( $booking->booking_id );
        is( $booking, undef, "The booking is deleted when the patron it's attached to is deleted" );

        $schema->storage->txn_rollback;
    };

    subtest 'pickup_library relation tests' => sub {
        plan tests => 3;
        $schema->storage->txn_begin;

        my $pickup_library = $builder->build_object( { class => "Koha::Libraries" } );
        my $booking =
            $builder->build_object(
            { class => 'Koha::Bookings', value => { pickup_library_id => $pickup_library->branchcode } } );

        my $THE_pickup_library = $booking->pickup_library;
        is( ref($THE_pickup_library), 'Koha::Library', "Koha::Booking->pickup_library returns a Koha::Library object" );
        is(
            $THE_pickup_library->branchcode, $pickup_library->branchcode,
            "Koha::Booking->pickup_library returns the linked pickup library object"
        );

        $THE_pickup_library->delete;
        $booking = Koha::Bookings->find( $booking->booking_id );
        is( $booking, undef, "The booking is deleted when the pickup_library it's attached to is deleted" );

        $schema->storage->txn_rollback;
    };

    subtest 'item relation tests' => sub {
        plan tests => 3;
        $schema->storage->txn_begin;

        my $item = $builder->build_sample_item( { bookable => 1 } );
        my $booking =
            $builder->build_object( { class => 'Koha::Bookings', value => { item_id => $item->itemnumber } } );

        my $THE_item = $booking->item;
        is( ref($THE_item), 'Koha::Item', "Koha::Booking->item returns a Koha::Item object" );
        is(
            $THE_item->itemnumber, $item->itemnumber,
            "Koha::Booking->item returns the links item object"
        );

        $THE_item->delete;
        $booking = Koha::Bookings->find( $booking->booking_id );
        is( $booking, undef, "The booking is deleted when the item it's attached to is deleted" );

        $schema->storage->txn_rollback;
    };

    subtest 'checkout relation tests' => sub {
        plan tests => 4;
        $schema->storage->txn_begin;

        my $patron  = $builder->build_object( { class => "Koha::Patrons" } );
        my $item    = $builder->build_sample_item( { bookable => 1 } );
        my $booking = $builder->build_object(
            {
                class => 'Koha::Bookings',
                value => {
                    patron_id => $patron->borrowernumber,
                    item_id   => $item->itemnumber,
                    status    => 'completed'
                }
            }
        );

        my $checkout = $booking->checkout;
        is( $checkout, undef, "Koha::Booking->checkout returns undef when no checkout exists" );

        my $issue = $builder->build_object(
            {
                class => 'Koha::Checkouts',
                value => {
                    borrowernumber => $patron->borrowernumber,
                    itemnumber     => $item->itemnumber,
                    booking_id     => $booking->booking_id
                }
            }
        );

        $checkout = $booking->checkout;
        is( ref($checkout),        'Koha::Checkout',     "Koha::Booking->checkout returns a Koha::Checkout object" );
        is( $checkout->issue_id,   $issue->issue_id,     "Koha::Booking->checkout returns the linked checkout" );
        is( $checkout->booking_id, $booking->booking_id, "The checkout is properly linked to the booking" );

        $schema->storage->txn_rollback;
    };

    subtest 'old_checkout relation tests' => sub {
        plan tests => 4;
        $schema->storage->txn_begin;

        my $patron  = $builder->build_object( { class => "Koha::Patrons" } );
        my $item    = $builder->build_sample_item( { bookable => 1 } );
        my $booking = $builder->build_object(
            {
                class => 'Koha::Bookings',
                value => {
                    patron_id => $patron->borrowernumber,
                    item_id   => $item->itemnumber,
                    status    => 'completed'
                }
            }
        );

        my $old_checkout = $booking->old_checkout;
        is( $old_checkout, undef, "Koha::Booking->old_checkout returns undef when no old_checkout exists" );

        my $old_issue = $builder->build_object(
            {
                class => 'Koha::Old::Checkouts',
                value => {
                    borrowernumber => $patron->borrowernumber,
                    itemnumber     => $item->itemnumber,
                    booking_id     => $booking->booking_id
                }
            }
        );

        $old_checkout = $booking->old_checkout;
        is(
            ref($old_checkout), 'Koha::Old::Checkout',
            "Koha::Booking->old_checkout returns a Koha::Old::Checkout object"
        );
        is(
            $old_checkout->issue_id, $old_issue->issue_id,
            "Koha::Booking->old_checkout returns the linked old_checkout"
        );
        is( $old_checkout->booking_id, $booking->booking_id, "The old_checkout is properly linked to the booking" );

        $schema->storage->txn_rollback;
    };
};

subtest 'store() tests' => sub {
    plan tests => 17;
    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => "Koha::Patrons" } );
    t::lib::Mocks::mock_userenv( { patron => $patron } );
    my $biblio  = $builder->build_sample_biblio();
    my $item_1  = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    my $start_0 = dt_from_string->subtract( days => 2 )->truncate( to => 'day' );
    my $end_0   = $start_0->clone()->add( days => 6 );

    my $deleted_item = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    $deleted_item->delete;

    my $wrong_item = $builder->build_sample_item();

    my $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $deleted_item->itemnumber,
            pickup_library_id => $deleted_item->homebranch,
            start_date        => $start_0,
            end_date          => $end_0
        }
    );

    throws_ok { $booking->store() } 'Koha::Exceptions::Object::FKConstraint',
        'Throws exception if passed a deleted item';

    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $wrong_item->itemnumber,
            pickup_library_id => $wrong_item->homebranch,
            start_date        => $start_0,
            end_date          => $end_0
        }
    );

    throws_ok { $booking->store() } 'Koha::Exceptions::Object::FKConstraint',
        "Throws exception if item passed doesn't match biblio passed";

    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $item_1->itemnumber,
            pickup_library_id => $item_1->homebranch,
            start_date        => $start_0,
            end_date          => $end_0
        }
    );

    # FIXME: Should this be allowed if an item is passed specifically?
    throws_ok { $booking->store() } 'Koha::Exceptions::Booking::Clash',
        'Throws exception when there are no items marked bookable for this biblio';

    $item_1->bookable(1)->store();
    $booking->store();
    ok( $booking->in_storage, 'First booking on item 1 stored OK' );

    # Bookings
    # ✓ Item 1    |----|
    # ✗ Item 1      |----|

    my $start_1 = dt_from_string->truncate( to => 'day' );
    my $end_1   = $start_1->clone()->add( days => 6 );
    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $item_1->itemnumber,
            pickup_library_id => $item_1->homebranch,
            start_date        => $start_1,
            end_date          => $end_1
        }
    );
    throws_ok { $booking->store } 'Koha::Exceptions::Booking::Clash',
        'Throws exception when passed booking start_date falls inside another booking for the item passed';

    # Bookings
    # ✓ Item 1    |----|
    # ✗ Item 1  |----|
    $start_1 = dt_from_string->subtract( days => 4 )->truncate( to => 'day' );
    $end_1   = $start_1->clone()->add( days => 6 );
    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $item_1->itemnumber,
            pickup_library_id => $item_1->homebranch,
            start_date        => $start_1,
            end_date          => $end_1
        }
    );
    throws_ok { $booking->store } 'Koha::Exceptions::Booking::Clash',
        'Throws exception when passed booking end_date falls inside another booking for the item passed';

    # Bookings
    # ✓ Item 1    |----|
    # ✗ Item 1  |--------|
    $start_1 = dt_from_string->subtract( days => 4 )->truncate( to => 'day' );
    $end_1   = $start_1->clone()->add( days => 10 );
    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $item_1->itemnumber,
            pickup_library_id => $item_1->homebranch,
            start_date        => $start_1,
            end_date          => $end_1
        }
    );
    throws_ok { $booking->store } 'Koha::Exceptions::Booking::Clash',
        'Throws exception when passed booking dates would envelope another booking for the item passed';

    # Bookings
    # ✓ Item 1    |----|
    # ✗ Item 1     |--|
    $start_1 = dt_from_string->truncate( to => 'day' );
    $end_1   = $start_1->clone()->add( days => 4 );
    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $item_1->itemnumber,
            pickup_library_id => $item_1->homebranch,
            start_date        => $start_1,
            end_date          => $end_1
        }
    );
    throws_ok { $booking->store } 'Koha::Exceptions::Booking::Clash',
        'Throws exception when passed booking dates would fall wholly inside another booking for the item passed';

    my $item_2 = $builder->build_sample_item( { biblionumber => $biblio->biblionumber, bookable => 1 } );
    my $item_3 = $builder->build_sample_item( { biblionumber => $biblio->biblionumber, bookable => 0 } );

    # Bookings
    # ✓ Item 1    |----|
    # ✓ Item 2     |--|
    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            item_id           => $item_2->itemnumber,
            pickup_library_id => $item_2->homebranch,
            start_date        => $start_1,
            end_date          => $end_1
        }
    )->store();
    ok(
        $booking->in_storage,
        'First booking on item 2 stored OK, even though it would overlap with a booking on item 1'
    );

    # Bookings
    # ✓ Item 1    |----|
    # ✓ Item 2     |--|
    # ✘ Any        |--|
    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            pickup_library_id => $item_2->homebranch,
            start_date        => $start_1,
            end_date          => $end_1
        }
    );
    throws_ok { $booking->store } 'Koha::Exceptions::Booking::Clash',
        'Throws exception when passed booking dates would fall wholly inside all existing bookings when no item specified';

    # Bookings
    # ✓ Item 1    |----|
    # ✓ Item 2     |--|
    # ✓ Any             |--|
    $start_1 = dt_from_string->add( days => 5 )->truncate( to => 'day' );
    $end_1   = $start_1->clone()->add( days => 4 );
    $booking = Koha::Booking->new(
        {
            patron_id         => $patron->borrowernumber,
            biblio_id         => $biblio->biblionumber,
            pickup_library_id => $item_2->homebranch,
            start_date        => $start_1,
            end_date          => $end_1
        }
    )->store();
    ok( $booking->in_storage, 'Booking stored OK when item not specified and the booking slot is available' );
    ok( $booking->item_id,    'An item was assigned to the booking' );

    subtest '_assign_item_for_booking() tests' => sub {
        plan tests => 5;

        # Bookings
        # ✓ Item 1    |----|
        # ✓ Item 2     |--|
        # ✓ Any (X)         |--|
        my $valid_items   = [ $item_1->itemnumber, $item_2->itemnumber ];
        my $assigned_item = $booking->item_id;
        is(
            ( scalar grep { $_ == $assigned_item } @$valid_items ), 1,
            'The item assigned was one of the valid, bookable items'
        );

        my $second_booking = Koha::Booking->new(
            {
                patron_id         => $patron->borrowernumber,
                biblio_id         => $biblio->biblionumber,
                pickup_library_id => $item_2->homebranch,
                start_date        => $start_1,
                end_date          => $end_1
            }
        )->store();
        isnt( $second_booking->item_id, $assigned_item, "The subsequent booking picks the only other available item" );

        # Cancel both bookings so we can check that cancelled bookings are allowed in the auto-assign
        $booking->status('cancelled')->store();
        $second_booking->status('cancelled')->store();
        is($booking->status, 'cancelled', "Booking is cancelled");
        is($second_booking->status, 'cancelled', "Second booking is cancelled");

        # Test randomness of selection
        my %seen_items;
        foreach my $i ( 1 .. 10 ) {
            my $new_booking = Koha::Booking->new(
                {
                    patron_id         => $patron->borrowernumber,
                    biblio_id         => $biblio->biblionumber,
                    pickup_library_id => $item_1->homebranch,
                    start_date        => $start_1,
                    end_date          => $end_1
                }
            );
            $new_booking->store();
            $seen_items{ $new_booking->item_id }++;
            $new_booking->delete();
        }
        ok(
            scalar( keys %seen_items ) > 1,
            'Multiple different items were selected randomly across bookings, and a cancelled booking is allowed in the selection'
        );
    };

    subtest 'confirmation notice trigger' => sub {
        plan tests => 2;

        my $original_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_CONFIRMATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;

        # Reuse previous booking to produce a clash
        eval { $booking = Koha::Booking->new( $booking->unblessed )->store };

        my $post_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_CONFIRMATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        is(
            $post_notices_count,
            $original_notices_count,
            'Koha::Booking->store should not have enqueued a BOOKING_CONFIRMATION email if booking creation fails'
        );

        $start_1 = dt_from_string->add( months => 1 )->truncate( to => 'day' );
        $end_1   = $start_1->clone()->add( days => 1 );

        $booking = Koha::Booking->new(
            {
                patron_id         => $patron->borrowernumber,
                biblio_id         => $biblio->biblionumber,
                pickup_library_id => $item_2->homebranch,
                start_date        => $start_1->datetime(q{ }),
                end_date          => $end_1->datetime(q{ }),
            }
        )->store;

        $post_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_CONFIRMATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        is(
            $post_notices_count,
            $original_notices_count + 1,
            'Koha::Booking->store should have enqueued a BOOKING_CONFIRMATION email for a new booking'
        );
    };

    subtest 'modification/cancellation notice triggers' => sub {
        plan tests => 5;

        my $original_modification_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_MODIFICATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        my $original_cancellation_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_CANCELLATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;

        $start_1 = dt_from_string->add( months => 1 )->truncate( to => 'day' );
        $end_1   = $start_1->clone()->add( days => 1 );

        # Use datetime formatting so that we don't get DateTime objects
        $booking = Koha::Booking->new(
            {
                patron_id         => $patron->borrowernumber,
                biblio_id         => $biblio->biblionumber,
                pickup_library_id => $item_2->homebranch,
                start_date        => $start_1->datetime(q{ }),
                end_date          => $end_1->datetime(q{ }),
            }
        )->store;

        my $post_modification_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_MODIFICATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        is(
            $post_modification_notices_count,
            $original_modification_notices_count,
            'Koha::Booking->store should not have enqueued a BOOKING_MODIFICATION email for a new booking'
        );

        my $item_4 = $builder->build_sample_item( { biblionumber => $biblio->biblionumber, bookable => 1 } );

        $booking->update(
            {
                item_id => $item_4->itemnumber,
            }
        );

        $post_modification_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_MODIFICATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        is(
            $post_modification_notices_count,
            $original_modification_notices_count,
            'Koha::Booking->store should not have enqueued a BOOKING_MODIFICATION email for a booking with modified item_id'
        );

        $booking->update(
            {
                start_date => $start_1->clone()->add( days => 1 )->datetime(q{ }),
            }
        );

        # start_date, end_date and pickup_library_id should behave identical
        $post_modification_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_MODIFICATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        is(
            $post_modification_notices_count,
            $original_modification_notices_count + 1,
            'Koha::Booking->store should have enqueued a BOOKING_MODIFICATION email for a booking with modified start_date'
        );

        $booking->update(
            {
                end_date => $end_1->clone()->add( days => 1 )->datetime(q{ }),
            }
        );

        $booking->update(
            {
                status => 'completed',
            }
        );

        my $post_cancellation_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_CANCELLATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        is(
            $post_cancellation_notices_count,
            $original_cancellation_notices_count,
            'Koha::Booking->store should NOT have enqueued a BOOKING_CANCELLATION email for a booking status change that is not a "cancellation"'
        );

        $booking->update(
            {
                status => 'cancelled',
            }
        );

        $post_cancellation_notices_count = Koha::Notice::Messages->search(
            {
                letter_code    => 'BOOKING_CANCELLATION',
                borrowernumber => $patron->borrowernumber,
            }
        )->count;
        is(
            $post_cancellation_notices_count,
            $original_cancellation_notices_count + 1,
            'Koha::Booking->store should have enqueued a BOOKING_CANCELLATION email for a booking status change that is a "cancellation"'
        );
    };

    subtest 'status change exception' => sub {
        plan tests => 2;

        $booking->discard_changes;
        my $status = $booking->status;
        throws_ok { $booking->update( { status => 'blah' } ) } 'Koha::Exceptions::Object::BadValue',
            'Throws exception when passed booking status would fail enum constraint';

        # Status unchanged
        $booking->discard_changes;
        is( $booking->status, $status, 'Booking status is unchanged' );
    };

    subtest 'date range constraint validation' => sub {
        plan tests => 11;

        # Set up fresh test data for constraint testing
        my $constraint_patron = $builder->build_object( { class => 'Koha::Patrons' } );
        my $constraint_biblio = $builder->build_sample_biblio();
        my $constraint_item   = $builder->build_sample_item(
            {
                biblionumber => $constraint_biblio->biblionumber,
                bookable     => 1
            }
        );
        my $library = $constraint_item->homebranch;

        # Test 1: No constraint - should allow long bookings
        t::lib::Mocks::mock_preference( 'BookingDateRangeConstraint', q{} );

        my $long_booking = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-01-01',
                end_date          => '2024-12-31',                         # Full year
            }
        );

        lives_ok { $long_booking->store() }
        'Year-long booking allowed when no constraint set';
        $long_booking->delete if $long_booking->in_storage;

        # Test 2: issuelength constraint in Days mode
        t::lib::Mocks::mock_preference( 'BookingDateRangeConstraint', 'issuelength' );

        # Set circulation rules
        use Koha::CirculationRules;
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $library,
                categorycode => $constraint_patron->categorycode,
                itemtype     => $constraint_item->effective_itemtype,
                rules        => {
                    issuelength => 3,
                    daysmode    => 'Days',
                }
            }
        );

        # Test 2a: Booking within limits (4 calendar days for issuelength=3)
        my $valid_booking = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-02-01',
                end_date          => '2024-02-04',                         # 4 days total
            }
        );

        lives_ok { $valid_booking->store() }
        'Booking with 4 calendar days allowed for issuelength=3';
        $valid_booking->delete if $valid_booking->in_storage;

        # Test 2b: Booking exactly at limit
        my $exact_booking = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-03-01',
                end_date          => '2024-03-04',                         # Exactly 4 days
            }
        );

        lives_ok { $exact_booking->store() }
        'Booking with exactly 4 days allowed';
        $exact_booking->delete if $exact_booking->in_storage;

        # Test 2c: Booking exceeding limits
        my $invalid_booking = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-04-01',
                end_date          => '2024-04-05',                         # 5 days total
            }
        );

        throws_ok { $invalid_booking->store() }
        'Koha::Exceptions::Booking::DateRangeConstraint',
            'Booking with 5 days throws exception when issuelength=3';

        # Test 3: Calendar mode with mocked calendar
        require Test::MockModule;
        my $calendar_mock = Test::MockModule->new('Koha::Calendar');

        # Mock addDuration to simulate calendar behavior with closed days
        # This simulates skipping weekends or holidays
        $calendar_mock->mock(
            'addDuration',
            sub {
                my ( $self, $start_dt, $duration ) = @_;
                my $days_to_add = $duration->in_units('days');

                # For testing: simulate that adding 3 days skips a weekend
                # So May 1 (Wed) + 3 working days = May 6 (Mon) instead of May 4 (Sat)
                if ( $start_dt->ymd eq '2024-05-01' && $days_to_add == 3 ) {

                    # Skip weekend: May 4-5
                    return dt_from_string('2024-05-06');
                }

                # June 1 is a Saturday, so adding days would skip weekend
                elsif ( $start_dt->ymd eq '2024-06-01' && $days_to_add == 3 ) {

                    # Jun 1 (Sat) closed, Jun 2 (Sun) closed
                    # Jun 3 (Mon) day 1, Jun 4 (Tue) day 2, Jun 5 (Wed) day 3
                    return dt_from_string('2024-06-05');
                }

                # Default: just add the days without skipping
                return $start_dt->clone->add($duration);
            }
        );

        # Update rules for Calendar mode
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $library,
                categorycode => $constraint_patron->categorycode,
                itemtype     => $constraint_item->effective_itemtype,
                rules        => {
                    issuelength => 3,
                    daysmode    => 'Calendar',
                }
            }
        );

        # Test 3a: Valid booking in Calendar mode with closed days
        # May 1 (Wed) + 3 working days = May 6 (Mon) due to weekend
        my $cal_valid = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-05-01',
                end_date          => '2024-05-06',                         # Matches calculated limit with weekend
            }
        );

        lives_ok { $cal_valid->store() }
        'Calendar mode: booking within calculated limit allowed (with weekend)';
        $cal_valid->delete if $cal_valid->in_storage;

        # Test 3b: Invalid booking in Calendar mode
        # May 1 + 3 working days = May 6, so May 7 should fail
        my $cal_invalid = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-05-01',
                end_date          => '2024-05-07',                         # Exceeds calculated limit
            }
        );

        throws_ok { $cal_invalid->store() }
        'Koha::Exceptions::Booking::DateRangeConstraint',
            'Calendar mode: booking exceeding calculated limit throws exception';

        # Test 3c: Booking ending before the calculated maximum should work
        my $cal_shorter = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-05-01',
                end_date          => '2024-05-04',                         # Before the max (May 6)
            }
        );

        lives_ok { $cal_shorter->store() }
        'Calendar mode: booking ending before calculated max allowed';
        $cal_shorter->delete if $cal_shorter->in_storage;

        # Test 4: issuelength_with_renewals constraint
        t::lib::Mocks::mock_preference( 'BookingDateRangeConstraint', 'issuelength_with_renewals' );

        Koha::CirculationRules->set_rules(
            {
                branchcode   => $library,
                categorycode => $constraint_patron->categorycode,
                itemtype     => $constraint_item->effective_itemtype,
                rules        => {
                    issuelength     => 7,
                    renewalperiod   => 7,
                    renewalsallowed => 2,
                    daysmode        => 'Days',
                }
            }
        );

        # Total allowed: 7 + (7 * 2) = 21, so 22 calendar days

        # Test 4a: Within extended limits
        my $renewal_valid = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-07-01',
                end_date          => '2024-07-22',                         # 22 days total
            }
        );

        lives_ok { $renewal_valid->store() }
        'Booking with 22 days allowed when issuelength=7 + 2 renewals of 7 days';
        $renewal_valid->delete if $renewal_valid->in_storage;

        # Test 4b: Exceeding extended limits
        my $renewal_invalid = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-08-01',
                end_date          => '2024-08-23',                         # 23 days total
            }
        );

        throws_ok { $renewal_invalid->store() }
        'Koha::Exceptions::Booking::DateRangeConstraint',
            'Booking with 23 days throws exception when max is 22';

        # Test 5: Edge case - zero issuelength
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $library,
                categorycode => $constraint_patron->categorycode,
                itemtype     => $constraint_item->effective_itemtype,
                rules        => {
                    issuelength => 0,
                    daysmode    => 'Days',
                }
            }
        );

        my $zero_booking = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-09-01',
                end_date          => '2024-09-01',                         # Same day
            }
        );

        lives_ok { $zero_booking->store() }
        'Same-day booking allowed even with issuelength=0';
        $zero_booking->delete if $zero_booking->in_storage;

        # Test 6: Timezone/time component handling
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $library,
                categorycode => $constraint_patron->categorycode,
                itemtype     => $constraint_item->effective_itemtype,
                rules        => {
                    issuelength => 3,
                    daysmode    => 'Days',
                }
            }
        );

        # Test timezone handling
        # Test dates with time components that could cause day-boundary issues
        my $timezone_booking = Koha::Booking->new(
            {
                patron_id         => $constraint_patron->borrowernumber,
                biblio_id         => $constraint_biblio->biblionumber,
                item_id           => $constraint_item->itemnumber,
                pickup_library_id => $library,
                start_date        => '2024-10-12 22:00:00',                # Late evening start
                end_date          => '2024-10-15 22:00:00',                # Late evening end (3 days later)
            }
        );

        lives_ok { $timezone_booking->store() }
        'UTC timestamps handled correctly for day-level validation';
        $timezone_booking->delete if $timezone_booking->in_storage;

        # Clean up
        $calendar_mock->unmock('addDuration');
    };

    $schema->storage->txn_rollback;
};
