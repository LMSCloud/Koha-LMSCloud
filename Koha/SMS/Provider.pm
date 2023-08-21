package Koha::SMS::Provider;

# Copyright ByWater Solutions 2016
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


use Koha::Patrons;

use base qw(Koha::Object);

=head1 NAME

Koha::Biblio - Koha Biblio Object class
Koha::SMS::Provider - Koha SMS Provider object class

=head1 API

=head2 Class Methods

=cut

=head3 patrons_using

my $count = $provider->patrons_using()

Gives the number of patrons using this provider

=cut

sub patrons_using {
    my ( $self ) = @_;

    return Koha::Patrons->search( { sms_provider_id => $self->id } )->count();
}

=head3 _type

=cut

sub _type {
    return 'SmsProvider';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
