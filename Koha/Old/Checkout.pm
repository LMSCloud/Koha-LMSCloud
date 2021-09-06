package Koha::Old::Checkout;

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

use Koha::Database;
use Koha::Libraries;

use base qw(Koha::Object);

=head1 NAME

Koha::Old:Checkout - Koha checkout object for returned items

=head1 API

=head2 Class methods

=head3 item

my $item = $checkout->item;

Return the checked out item

=cut

sub item {
    my ( $self ) = @_;
    my $item_rs = $self->_result->item;
    return Koha::Item->_new_from_dbic( $item_rs );
}

=head3 library

my $library = $checkout->library;

Return the library in which the transaction took place. Might return I<undef>.

=cut

sub library {
    my ( $self ) = @_;
    my $library_rs = $self->_result->library;
    return unless $library_rs;
    return Koha::Library->_new_from_dbic( $library_rs );
}

=head3 patron

my $patron = $checkout->patron

Return the patron for who the checkout has been done

=cut

sub patron {
    my ( $self ) = @_;
    my $patron_rs = $self->_result->borrower;
    return unless $patron_rs;
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

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Old::Checkout object
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

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'OldIssue';
}

1;
