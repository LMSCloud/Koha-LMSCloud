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

use Test::More tests => 6;
use Test::NoWarnings;

use C4::Circulation qw(
    CanBookBeIssued
    AddIssue
    AddRenewal
    SetDueDateOfItems
    GetTransfers
    GetIssuingCharges
);
use C4::Context;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Booking;
use Koha::Checkouts;
use Koha::Libraries;
use Koha::Account::Lines;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# Ensure booking notice templates exist to avoid warnings
use Koha::Notice::Template;
use Koha::Notice::Templates;
for my $code (qw( BOOKING_CONFIRMATION BOOKING_CANCELLATION BOOKING_MODIFICATION )) {
    Koha::Notice::Templates->search( { code => $code } )->delete;
    Koha::Notice::Template->new(
        {
            module                 => 'bookings',
            code                   => $code,
            branchcode             => '',
            name                   => $code,
            is_html                => 0,
            title                  => $code,
            content                => "$code notice",
            message_transport_type => 'email',
            lang                   => 'default',
        }
    )->store;
}

subtest 'BOOKED_EARLY and BOOKED_TO_ANOTHER in CanBookBeIssued' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $staff   = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_userenv( { patron => $staff, branchcode => $library->branchcode } );

    my $patron1        = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2        = $builder->build_object( { class => 'Koha::Patrons' } );
    my $pickup_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $item           = $builder->build_sample_item( { bookable => 1 } );

    my $booking = Koha::Booking->new(
        {
            patron_id         => $patron1->borrowernumber,
            pickup_library_id => $pickup_library->branchcode,
            item_id           => $item->itemnumber,
            biblio_id         => $item->biblio->biblionumber,
            start_date        => dt_from_string()->subtract( days => 1 ),
            end_date          => dt_from_string()->add( days => 6 ),
        }
    )->store();

    # Booking started yesterday, due date in 5 days => loan falls inside booking.
    # Another patron trying to check out => issuingimpossible BOOKED_TO_ANOTHER
    my ( $issuingimpossible, $needsconfirmation, $alerts, $messages ) = CanBookBeIssued(
        $patron2, $item->barcode,
        dt_from_string()->add( days => 5 ),
        undef, undef, undef
    );
    is(
        $issuingimpossible->{BOOKED_TO_ANOTHER}->booking_id,
        $booking->booking_id,
        'BOOKED_TO_ANOTHER in issuingimpossible when loan falls inside another patron booking'
    );

    # Same patron (patron1) checking out => booking is theirs, start is in the past => BOOKED alert
    ( $issuingimpossible, $needsconfirmation, $alerts, $messages ) = CanBookBeIssued(
        $patron1, $item->barcode,
        dt_from_string()->add( days => 5 ),
        undef, undef, undef
    );
    is(
        $alerts->{BOOKED}->booking_id,
        $booking->booking_id,
        'BOOKED alert when same patron checks out during their own active booking'
    );

    # Move booking start to future (3 days from now)
    $booking->start_date( dt_from_string()->add( days => 3 ) )->store();

    # Another patron checks out with due date 5 days out => booking starts before due date
    # => needsconfirmation BOOKED_TO_ANOTHER
    ( $issuingimpossible, $needsconfirmation, $alerts, $messages ) = CanBookBeIssued(
        $patron2, $item->barcode,
        dt_from_string()->add( days => 5 ),
        undef, undef, undef
    );
    is(
        $needsconfirmation->{BOOKED_TO_ANOTHER}->booking_id,
        $booking->booking_id,
        'BOOKED_TO_ANOTHER in needsconfirmation when booking starts before proposed due date'
    );

    # Same patron (patron1) checks out before their booking starts => BOOKED_EARLY
    ( $issuingimpossible, $needsconfirmation, $alerts, $messages ) = CanBookBeIssued(
        $patron1, $item->barcode,
        dt_from_string()->add( days => 5 ),
        undef, undef, undef
    );
    is(
        $needsconfirmation->{BOOKED_EARLY}->booking_id,
        $booking->booking_id,
        'BOOKED_EARLY in needsconfirmation when patron checks out before their booking starts'
    );

    # Verify BOOKED_EARLY is not set when there is no booking for the patron
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item2   = $builder->build_sample_item( { bookable => 1 } );
    ( $issuingimpossible, $needsconfirmation, $alerts, $messages ) = CanBookBeIssued(
        $patron3, $item2->barcode,
        dt_from_string()->add( days => 5 ),
        undef, undef, undef
    );
    ok(
        !exists $needsconfirmation->{BOOKED_EARLY} && !exists $needsconfirmation->{BOOKED_TO_ANOTHER},
        'No booking flags when item has no bookings'
    );

    $schema->storage->txn_rollback;
};

subtest 'Mobile branch in transfers via get_effective_branch' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $parent_branch = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => {
                mobilebranch => undef,
            },
        }
    );

    my $mobile_station = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => {
                mobilebranch => $parent_branch->branchcode,
            },
        }
    );

    # get_effective_branch for mobile station returns parent
    is(
        Koha::Libraries->get_effective_branch( $mobile_station->branchcode ),
        $parent_branch->branchcode,
        'get_effective_branch returns parent branchcode for a mobile station'
    );

    # get_effective_branch for parent returns itself
    is(
        Koha::Libraries->get_effective_branch( $parent_branch->branchcode ),
        $parent_branch->branchcode,
        'get_effective_branch returns same branchcode for a non-mobile branch'
    );

    # get_effective_branch for a regular branch (no mobilebranch) returns itself
    my $regular_branch = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => {
                mobilebranch => undef,
            },
        }
    );
    is(
        Koha::Libraries->get_effective_branch( $regular_branch->branchcode ),
        $regular_branch->branchcode,
        'get_effective_branch returns same branchcode for a regular branch'
    );

    # Chain: mobile station pointing to another mobile station pointing to parent
    my $nested_mobile = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => {
                mobilebranch => $mobile_station->branchcode,
            },
        }
    );
    is(
        Koha::Libraries->get_effective_branch( $nested_mobile->branchcode ),
        $mobile_station->branchcode,
        'get_effective_branch only follows one level of mobilebranch indirection'
    );

    $schema->storage->txn_rollback;
};

subtest 'Rental fee discount sysprefs (IssuingDiscardRentalFeesOfPatronCategory)' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } );
    my $staff   = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_userenv( { patron => $staff, branchcode => $library->branchcode } );

    my $category_discounted = $builder->build_object( { class => 'Koha::Patron::Categories' } );
    my $category_regular    = $builder->build_object( { class => 'Koha::Patron::Categories' } );

    my $patron_discounted = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category_discounted->categorycode, branchcode => $library->branchcode },
        }
    );
    my $patron_regular = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category_regular->categorycode, branchcode => $library->branchcode },
        }
    );

    my $itemtype = $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => { rentalcharge => 2.50, rentalcharge_daily => 0, rentalcharge_hourly => 0 },
        }
    );
    my $item = $builder->build_sample_item(
        {
            itype      => $itemtype->itemtype,
            library    => $library->branchcode,
        }
    );

    t::lib::Mocks::mock_preference( 'RentalFeesCheckoutConfirmation', 1 );

    # Without the discount syspref, both patrons should see the rental charge confirmation
    t::lib::Mocks::mock_preference( 'IssuingDiscardRentalFeesOfPatronCategory', '' );

    my ( $issuingimpossible, $needsconfirmation ) = CanBookBeIssued(
        $patron_regular, $item->barcode,
        dt_from_string()->add( days => 14 ),
        undef, undef, undef
    );
    ok(
        $needsconfirmation->{RENTALCHARGE},
        'RENTALCHARGE confirmation required for regular patron when no discount syspref set'
    );

    ( $issuingimpossible, $needsconfirmation ) = CanBookBeIssued(
        $patron_discounted, $item->barcode,
        dt_from_string()->add( days => 14 ),
        undef, undef, undef
    );
    ok(
        $needsconfirmation->{RENTALCHARGE},
        'RENTALCHARGE confirmation required for discounted patron category when syspref is empty'
    );

    # Now set the discount syspref to include the discounted category
    t::lib::Mocks::mock_preference(
        'IssuingDiscardRentalFeesOfPatronCategory',
        $category_discounted->categorycode
    );

    ( $issuingimpossible, $needsconfirmation ) = CanBookBeIssued(
        $patron_discounted, $item->barcode,
        dt_from_string()->add( days => 14 ),
        undef, undef, undef
    );
    ok(
        !$needsconfirmation->{RENTALCHARGE},
        'No RENTALCHARGE confirmation for patron whose category is in IssuingDiscardRentalFeesOfPatronCategory'
    );

    ( $issuingimpossible, $needsconfirmation ) = CanBookBeIssued(
        $patron_regular, $item->barcode,
        dt_from_string()->add( days => 14 ),
        undef, undef, undef
    );
    ok(
        $needsconfirmation->{RENTALCHARGE},
        'RENTALCHARGE still required for patron whose category is NOT in the discount syspref'
    );

    $schema->storage->txn_rollback;
};

subtest 'SetDueDateOfItems function' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    can_ok( 'C4::Circulation', 'SetDueDateOfItems' );

    # Param validation
    my ( $count, $error ) = SetDueDateOfItems(undef);
    is( $error, 'no_params_specified', 'Returns error when no params given' );

    ( $count, $error ) = SetDueDateOfItems( {} );
    is( $error, 'current_due_date_not_specified', 'Returns error when currentDueDate missing' );

    ( $count, $error ) = SetDueDateOfItems( { currentDueDate => '2099-12-01' } );
    is( $error, 'new_due_date_not_specified', 'Returns error when newDueDate missing' );

    # Test with a past currentDueDate
    ( $count, $error ) = SetDueDateOfItems(
        {
            currentDueDate => '2020-01-01',
            newDueDate     => '2099-12-31',
        }
    );
    is( $error, 'current_due_date_before_today', 'Returns error when currentDueDate is in the past' );

    $schema->storage->txn_rollback;
};

subtest 'GetTransfers function' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    can_ok( 'C4::Circulation', 'GetTransfers' );

    my $item = $builder->build_sample_item();

    # No transfers for a fresh item
    my @transfers = GetTransfers( $item->itemnumber );
    is( scalar @transfers, 0, 'GetTransfers returns empty list for item with no pending transfers' );

    $schema->storage->txn_rollback;
};
