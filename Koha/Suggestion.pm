package Koha::Suggestion;

# Copyright ByWater Solutions 2015
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
use Koha::DateUtils qw(dt_from_string);

use base qw(Koha::Object);

=head1 NAME

Koha::Suggestion - Koha Suggestion object class

=head1 API

=head2 Class Methods

=cut

=head3 store

Override the default store behavior so that new suggestions have
a suggesteddate of today

=cut

sub store {
    my ($self) = @_;

    unless ( $self->suggesteddate() ) {
        $self->suggesteddate( dt_from_string()->ymd );
    }

    return $self->SUPER::store();
}

=head3 type

=cut

sub _type {
    return 'Suggestion';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
