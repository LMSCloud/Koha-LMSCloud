package Koha::Rating;

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

use base qw(Koha::Object);

=head1 NAME

Koha::Rating - Koha Rating Object class

=head1 API

=head2 Class Methods

=cut

=head3 store

=cut

sub store {
    my ($self) = @_;
    if ( $self->rating_value > 5 ) {
        $self->rating_value(5);
    }
    elsif ( $self->rating_value < 0 ) {
        $self->rating_value(0);
    }
    return $self->SUPER::store;
}

=head3 type

=cut

sub _type {
    return 'Rating';
}

1;
