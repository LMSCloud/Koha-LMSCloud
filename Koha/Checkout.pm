package Koha::Checkout;

# Copyright ByWater Solutions 2015
# Copyright 2016 Koha Development Team
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

use DateTime;
use Try::Tiny qw( catch try );

use C4::Circulation qw( LostItem MarkIssueReturned );
use Koha::Checkouts::Renewals;
use Koha::Checkouts::ReturnClaims;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Items;
use Koha::Libraries;

use base qw(Koha::Object);

=head1 NAME

Koha::Checkout - Koha Checkout object class

=head1 API

=head2 Class methods

=cut

=head3 is_overdue

my  $is_overdue = $checkout->is_overdue( [ $reference_dt ] );

Return 1 if the checkout is overdue.

A reference date can be passed, in this case it will be used, otherwise today
will be the reference date.

=cut

sub is_overdue {
    my ( $self, $dt ) = @_;
    $dt ||= dt_from_string();

    my $is_overdue =
      DateTime->compare( dt_from_string( $self->date_due, 'sql' ), $dt ) == -1
      ? 1
      : 0;
    return $is_overdue;
}

=head3 item

my $item = $checkout->item;

Return the checked out item

=cut

sub item {
    my ( $self ) = @_;
    my $item_rs = $self->_result->item;
    return Koha::Item->_new_from_dbic( $item_rs );
}

=head3 account_lines

my $account_lines = $checkout->account_lines;

Return the checked out account_lines

=cut

sub account_lines {
    my ( $self ) = @_;
    my $account_lines_rs = $self->_result->account_lines;
    return Koha::Account::Lines->_new_from_dbic( $account_lines_rs );
}

=head3 library

my $library = $checkout->library;

Return the library in which the transaction took place

=cut

sub library {
    my ( $self ) = @_;
    my $library_rs = $self->_result->library;
    return Koha::Library->_new_from_dbic( $library_rs );
}

=head3 patron

my $patron = $checkout->patron

Return the patron for who the checkout has been done

=cut

sub patron {
    my ( $self ) = @_;
    my $patron_rs = $self->_result->patron;
    return Koha::Patron->_new_from_dbic( $patron_rs );
}

=head3 issuer

my $issuer = $checkout->issuer

Return the patron by whom the checkout was done

=cut

sub issuer {
    my ( $self ) = @_;
    my $issuer_rs = $self->_result->issuer;
    return unless $issuer_rs;
    return Koha::Patron->_new_from_dbic( $issuer_rs );
}

=head3 renewals

  my $renewals = $checkout->renewals;

Return a Koha::Checkouts::Renewals set attached to this checkout

=cut

sub renewals {
    my ( $self ) = @_;
    my $renewals_rs = $self->_result->renewals;
    return unless $renewals_rs;
    return Koha::Checkouts::Renewals->_new_from_dbic( $renewals_rs );
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Checkout object
on the API.

=cut

sub to_api_mapping {
    return {
        issue_id        => 'checkout_id',
        borrowernumber  => 'patron_id',
        itemnumber      => 'item_id',
        date_due        => 'due_date',
        branchcode      => 'library_id',
        returndate      => 'checkin_date',
        lastreneweddate => 'last_renewed_date',
        issuedate       => 'checkout_date',
        notedate        => 'note_date',
        noteseen        => 'note_seen',
    };
}

=head3 public_read_list

    my @public_read_list = @{$checkout->public_read_list};

Returns the list of database columns that are allowed to be passed to render
checkout objects on the public API.

=cut

sub public_read_list {
    return [
        'item_id',
        'checkout_date',
        'due_date',
    ];
}

=head3 claim_returned

  my $return_claim = $checkout->claim_returned();

This method sets the checkout as claimed return.  It will:

1.  Add a new row to the `return_claims` table
2.  Set the item as lost using the 'ClaimReturnedLostValue'
3.  Charge a fee depending on the value of ClaimReturnedChargeFee
3a. If set to charge, then accruing overdues will be halted
3b. If set to charge, then any existing transfers will be cancelled
    and the holding branch will be set back to 'frombranch'.
4.  The issue will be marked as returned as per the 'MarkLostItemsAsReturned' preference

=cut

sub claim_returned {
    my ( $self, $params ) = @_;

    my $charge_lost_fee = $params->{charge_lost_fee};

    try {
        $self->_result->result_source->schema->txn_do(
            sub {
                my $claim = Koha::Checkouts::ReturnClaim->new(
                    {
                        issue_id       => $self->id,
                        itemnumber     => $self->itemnumber,
                        borrowernumber => $self->borrowernumber,
                        notes          => $params->{notes},
                        created_by     => $params->{created_by},
                        created_on     => dt_from_string,
                    }
                )->store();

                my $ClaimReturnedLostValue = C4::Context->preference('ClaimReturnedLostValue');
                $self->item->itemlost($ClaimReturnedLostValue)->store;

                my $ClaimReturnedChargeFee = C4::Context->preference('ClaimReturnedChargeFee');
                $charge_lost_fee =
                    $ClaimReturnedChargeFee eq 'charge'    ? 1
                : $ClaimReturnedChargeFee eq 'no_charge' ? 0
                :   $charge_lost_fee;    # $ClaimReturnedChargeFee eq 'ask'

                if ( $charge_lost_fee ) {
                    C4::Circulation::LostItem( $self->itemnumber, 'claim_returned' );
                }
                elsif ( C4::Context->preference( 'MarkLostItemsAsReturned' ) =~ m/claim_returned/ ) {
                    C4::Circulation::MarkIssueReturned( $self->borrowernumber, $self->itemnumber, undef, $self->patron->privacy );
                }

                return $claim;
            }
        );
    }
    catch {
        if ( $_->isa('Koha::Exception') ) {
            $_->rethrow();
        }
        else {
            # ?
            Koha::Exception->throw( "Unhandled exception" );
        }
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Issue';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

Jonathan Druart <jonathan.druart@bugs.koha-community.org>

=cut

1;
