package Koha::Patron;

# Copyright ByWater Solutions 2014
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;

use Koha::Database;
use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::Patron::Images;

use base qw(Koha::Object);

=head1 NAME

Koha::Patron - Koha Patron Object class

=head1 API

=head2 Class Methods

=cut

=head3 guarantor

Returns a Koha::Patron object for this patron's guarantor

=cut

=head3 category

my $patron_category = $patron->category

Return the patron category for this patron

=cut

sub category {
    my ( $self ) = @_;
    return Koha::Patron::Category->_new_from_dbic( $self->_result->categorycode );
}

=head3 guarantor

Returns a Koha::Patron object for this patron's guarantor

=cut

sub guarantor {
    my ( $self ) = @_;

    return unless $self->guarantorid();

    return Koha::Patrons->find( $self->guarantorid() );
}

sub image {
    my ( $self ) = @_;

    return Koha::Patron::Images->find( $self->borrowernumber )
}

=head3 guarantees

Returns the guarantees (list of Koha::Patron) of this patron

=cut

sub guarantees {
    my ( $self ) = @_;

    return Koha::Patrons->search( { guarantorid => $self->borrowernumber } );
}

=head3 siblings

Returns the siblings of this patron.

=cut

sub siblings {
    my ( $self ) = @_;

    my $guarantor = $self->guarantor;

    return unless $guarantor;

    return Koha::Patrons->search(
        {
            guarantorid => {
                '!=' => undef,
                '=' => $guarantor->id,
            },
            borrowernumber => {
                '!=' => $self->borrowernumber,
            }
        }
    );
}

=head3 type

=cut

sub _type {
    return 'Borrower';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
