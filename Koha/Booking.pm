package Koha::Booking;

# Copyright PTFS Europe 2021
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Koha::Exceptions::Booking;
use Koha::DateUtils qw( dt_from_string );
use Koha::Items;
use Koha::Patrons;
use Koha::Libraries;
use Koha::CirculationRules;
use Koha::Calendar;

use C4::Context;
use C4::Letters;

use List::Util qw(any);

use base qw( Koha::Object Koha::Object::Mixin::AdditionalFields );

=head1 NAME

Koha::Booking - Koha Booking object class

=head1 API

=head2 Class methods

=head3 biblio

Returns the related Koha::Biblio object for this booking

=cut

sub biblio {
    my ($self) = @_;

    my $biblio_rs = $self->_result->biblio;
    return Koha::Biblio->_new_from_dbic($biblio_rs);
}

=head3 patron

Returns the related Koha::Patron object for this booking

=cut

sub patron {
    my ($self) = @_;

    my $patron_rs = $self->_result->patron;
    return Koha::Patron->_new_from_dbic($patron_rs);
}

=head3 pickup_library

Returns the related Koha::Library object for this booking

=cut

sub pickup_library {
    my ($self) = @_;

    my $pickup_library_rs = $self->_result->pickup_library;
    return Koha::Library->_new_from_dbic($pickup_library_rs);
}

=head3 item

Returns the related Koha::Item object for this Booking

=cut

sub item {
    my ($self) = @_;

    my $item_rs = $self->_result->item;
    return unless $item_rs;
    return Koha::Item->_new_from_dbic($item_rs);
}

=head3 checkout

Returns the related Koha::Checkout object for this booking, if any

=cut

sub checkout {
    my ($self) = @_;

    my $checkout_rs = $self->_result->issues->first;
    return unless $checkout_rs;
    return Koha::Checkout->_new_from_dbic($checkout_rs);
}

=head3 old_checkout

Returns the related Koha::Old::Checkout object for this booking, if any

=cut

sub old_checkout {
    my ($self) = @_;

    my $old_checkout_rs = $self->_result->old_issues->first;
    return unless $old_checkout_rs;
    return Koha::Old::Checkout->_new_from_dbic($old_checkout_rs);
}

=head3 store

Booking specific store method to catch booking clashes and ensure we have an item assigned

We assume that if an item is passed, it's bookability has already been checked. This is to allow
overrides in the future.

=cut

sub store {
    my ($self) = @_;

    $self->_result->result_source->schema->txn_do(
        sub {
            if ( $self->item_id ) {
                Koha::Exceptions::Object::FKConstraint->throw(
                    broken_fk => 'item_id',
                    value     => $self->item_id,
                ) unless ( $self->item );

                $self->biblio_id( $self->item->biblionumber )
                    unless $self->biblio_id;

                Koha::Exceptions::Object::FKConstraint->throw()
                    unless ( $self->biblio_id == $self->item->biblionumber );
            }

            Koha::Exceptions::Object::FKConstraint->throw(
                broken_fk => 'biblio_id',
                value     => $self->biblio_id,
            ) unless ( $self->biblio );


            # Throw exception for item level booking clash
            Koha::Exceptions::Booking::Clash->throw()
                if $self->item_id && !$self->item->check_booking(
                {
                    start_date => $self->start_date,
                    end_date   => $self->end_date,
                    booking_id => $self->in_storage ? $self->booking_id : undef
                }
                );

            # Throw exception for biblio level booking clash
            Koha::Exceptions::Booking::Clash->throw()
                if !$self->biblio->check_booking(
                {
                    start_date => $self->start_date,
                    end_date   => $self->end_date,
                    booking_id => $self->in_storage ? $self->booking_id : undef
                }
                );

            # FIXME: We should be able to combine the above two functions into one

            # Assign item at booking time
            if ( !$self->item_id ) {
                $self->_assign_item_for_booking;
            }

            # Check date range constraints based on system preferences
            # This must happen AFTER item assignment so we can determine the itemtype
            $self->_check_date_range_constraints();

            if ( !$self->in_storage ) {
                $self->SUPER::store;
                $self->discard_changes;
                $self->_send_notice( { notice => 'BOOKING_CONFIRMATION' } );
            } else {
                my %updated_columns = $self->_result->get_dirty_columns;
                return $self->SUPER::store unless %updated_columns;

                my $old_booking = $self->get_from_storage;
                $self->SUPER::store;

                if ( exists( $updated_columns{status} ) && $updated_columns{status} eq 'cancelled' ) {
                    $self->_send_notice(
                        { notice => 'BOOKING_CANCELLATION', objects => { old_booking => $old_booking } } );
                } elsif ( exists( $updated_columns{pickup_library_id} )
                    or exists( $updated_columns{start_date} )
                    or exists( $updated_columns{end_date} ) )
                {
                    $self->_send_notice(
                        { notice => 'BOOKING_MODIFICATION', objects => { old_booking => $old_booking } } );
                }
            }
        }
    );

    return $self;
}

=head3 _assign_item_for_booking

  $self->_assign_item_for_booking;

Used internally in Koha::Booking->store to ensure we have an item assigned for the booking.

=cut

sub _assign_item_for_booking {
    my ($self) = @_;

    my $biblio = $self->biblio;

    my $start_date = dt_from_string( $self->start_date );
    my $end_date   = dt_from_string( $self->end_date );

    my $dtf = Koha::Database->new->schema->storage->datetime_parser;

    my $existing_bookings = $biblio->bookings(
        {
            '-and' => [
                {
                    '-or' => [
                        start_date => {
                            '-between' => [
                                $dtf->format_datetime($start_date),
                                $dtf->format_datetime($end_date)
                            ]
                        },
                        end_date => {
                            '-between' => [
                                $dtf->format_datetime($start_date),
                                $dtf->format_datetime($end_date)
                            ]
                        },
                        {
                            start_date => { '<' => $dtf->format_datetime($start_date) },
                            end_date   => { '>' => $dtf->format_datetime($end_date) }
                        }
                    ]
                },
                { status => { '-not_in' => [ 'cancelled', 'completed' ] } }
            ]
        }
    );

    my $checkouts =
        $biblio->current_checkouts->search( { date_due => { '>=' => $dtf->format_datetime($start_date) } } );

    my $bookable_items = $biblio->bookable_items->search(
        {
            itemnumber => [
                '-and' => { '-not_in' => $existing_bookings->_resultset->get_column('item_id')->as_query },
                { '-not_in' => $checkouts->_resultset->get_column('itemnumber')->as_query }
            ]
        },
        { order_by => \'RAND()', rows => 1 }
    );

    my $itemnumber = $bookable_items->single->itemnumber;
    return $self->item_id($itemnumber);
}

=head3 get_items_that_can_fill

    my $items = $bookings->get_items_that_can_fill();

Return the list of items that can fulfill this booking.

Items that are not:

  in transit
  lost
  withdrawn
  not for loan
  not already booked

=cut

sub get_items_that_can_fill {
    my ($self) = @_;
    return;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Booking object
on the API.

=cut

sub to_api_mapping {    #FIXME: needs to be updated for prod
    return {
        booking_id        => 'booking_id',
        biblio_id         => 'biblio_id',
        patron_id         => 'patron_id',
        item_id           => 'item_id',
        start_date        => 'start_date',
        end_date          => 'end_date',
        status            => 'status',
        creation_date     => 'creation_date',
        modification_date => 'modification_date',
        pickup_library_id => 'pickup_library_id'
    };
}

=head3 public_read_list

This method returns the list of publicly readable database fields for both API and UI output purposes

=cut

sub public_read_list {    #FIXME: needs to be updated for prod
    return [
        'booking_id',
        'biblio_id',
        'patron_id',
        'item_id',
        'start_date',
        'end_date',
        'status',
        'creation_date',
        'modification_date',
        'pickup_library_id'
    ];
}

=head3 to_api

    my $json = $booking->to_api;

Overloaded method that returns a JSON representation of the Koha::Booking object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $booking = $self->SUPER::to_api($params);
    return          unless $booking;
    return $booking unless $params->{'public'};

    my $logged_in_user = C4::Context->userenv->{'borrowernumber'};
    if ( $logged_in_user && $self->patron_id == $logged_in_user ) {
        $booking->{'patron'} = $self->patron->to_api( { public => 1 } );
    }
    delete $booking->{'patron'};

    return $booking;
}

=head2 Internal methods

=head3 _check_date_range_constraints

Validates booking date range against system preference constraints

=cut

sub _check_date_range_constraints {
    my ($self) = @_;

    # Get the appropriate system preference based on context
    my $constraint = C4::Context->preference('BookingDateRangeConstraint');

    # Skip validation if no constraint is set
    return unless $constraint;

    # Get circulation rules for this booking context
    my $patron    = $self->patron;
    my $item_type = $self->item->effective_itemtype;
    my $library   = $self->pickup_library_id;

    # Get circulation rules for this booking context
    my $rules = Koha::CirculationRules->get_effective_rules(
        {
            categorycode => $patron->categorycode,
            itemtype     => $item_type,
            branchcode   => $library,
            rules        => [ 'issuelength', 'renewalperiod', 'renewalsallowed' ]
        }
    );

    # Calculate maximum allowed days based on constraint type
    my $max_days;
    if ( $constraint eq 'issuelength' ) {
        $max_days = $rules->{issuelength} || 0;
    } elsif ( $constraint eq 'issuelength_with_renewals' ) {
        my $issue_length     = $rules->{issuelength}     || 0;
        my $renewal_period   = $rules->{renewalperiod}   || 0;
        my $renewals_allowed = $rules->{renewalsallowed} || 0;
        $max_days = $issue_length + ( $renewal_period * $renewals_allowed );
    }

    my $daysmode = Koha::CirculationRules->get_effective_daysmode(
        {
            categorycode => $patron->categorycode,
            itemtype     => $item_type,
            branchcode   => $library,
        }
    );

    my $start_dt = dt_from_string( $self->start_date )->truncate( to => 'day' );
    my $end_dt   = dt_from_string( $self->end_date )->truncate( to => 'day' );

    # Calculate the maximum allowed end date based on circulation rules
    # max_days represents days to ADD (like issuelength)
    my $max_end_date;

    if ( $daysmode eq 'Days' ) {

        # Simple arithmetic: add max_days to start date
        $max_end_date = $start_dt->clone->add( days => $max_days );
    } else {

        # Use calendar to account for closed days
        my $calendar = Koha::Calendar->new( branchcode => $library, days_mode => $daysmode );
        my $dur      = DateTime::Duration->new( days => $max_days );
        $max_end_date = $calendar->addDuration( $start_dt->clone, $dur, 'days' );
    }

    my $max_end_date_normalized = $max_end_date->clone->truncate( to => 'day' );

    if ( DateTime->compare( $end_dt, $max_end_date_normalized ) > 0 ) {
        my $requested_days = $end_dt->delta_days($start_dt)->in_units('days');
        Koha::Exceptions::Booking::DateRangeConstraint->throw(
            requested_days  => $requested_days,
            max_days        => $max_days,
            constraint_type => $constraint,
            start_date      => join( q{ }, $start_dt->ymd,                $start_dt->hms ),
            end_date        => join( q{ }, $end_dt->ymd,                  $end_dt->hms ),
            max_end_date    => join( q{ }, $max_end_date_normalized->ymd, $max_end_date_normalized->hms ),
            daysmode        => $daysmode
        );
    }

    return;
}

=head3 _send_notice

    $self->_send_notice();

Sends appropriate notice to patron.

=cut

sub _send_notice {
    my ( $self, $params ) = @_;

    my $notice  = $params->{notice};
    my $objects = $params->{objects} // {};
    $objects->{booking} = $self;

    my $branch = C4::Context->userenv->{'branch'};
    my $patron = $self->patron;

    my $letter = C4::Letters::GetPreparedLetter(
        module                 => 'bookings',
        letter_code            => $notice,
        message_transport_type => 'email',
        branchcode             => $branch,
        lang                   => $patron->lang,
        objects                => $objects
    );

    if ($letter) {
        C4::Letters::EnqueueLetter(
            {
                letter                 => $letter,
                borrowernumber         => $patron->borrowernumber,
                message_transport_type => 'email',
                branchcode             => $branch,
            }
        );
    }
}

=head3 _type

=cut

sub _type {
    return 'Booking';
}

=head1 AUTHORS

Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut

1;
