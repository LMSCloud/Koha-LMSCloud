package Koha::CirculationRule;

# Copyright Vaara-kirjastot 2015
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

use base qw(Koha::Object);

use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::ItemTypes;

=head1 NAME

Koha::CirculationRule - Koha CirculationRule  object class

=head1 API

=head2 Class Methods

=cut

=head3 library

=cut

sub library {
    my ($self) = @_;

    $self->{_library} ||= Koha::Libraries->find( $self->branchcode );

    return $self->{_library};
}

=head3 patron_category

=cut

sub patron_category {
    my ($self) = @_;

    $self->{_patron_category} ||= Koha::Patron::Categories->find( $self->categorycode );

    return $self->{_patron_category};
}

=head3 item_type

=cut

sub item_type {
    my ($self) = @_;

    $self->{_item_type} ||= Koha::ItemTypes->find( $self->itemtype );

    return $self->{item_type};
}

=head3 clone

Clone a circulation rule to another branch

=cut

sub clone {
    my ($self, $to_branch) = @_;

    my $cloned_rule = $self->unblessed;
    $cloned_rule->{branchcode} = $to_branch;
    delete $cloned_rule->{id};
    return Koha::CirculationRule->new( $cloned_rule )->store;
}

=head3 _type

=cut

sub _type {
    return 'CirculationRule';
}

1;
