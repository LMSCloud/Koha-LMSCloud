package Koha::REST::V1::AuthorisedValue;

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
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Auth qw( haspermission );
use Koha::AuthorisedValues;

use Scalar::Util qw( blessed );
use Try::Tiny    qw( catch try );

=head1 NAME

Koha::REST::V1::AuthorisedValue - Controller for authorised values

=head1 METHODS

=head2 list

Controller function that handles listing authorised values.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $authvalues_set = Koha::AuthorisedValues->new;
        my $authvalues     = $c->objects->search($authvalues_set);
        return $c->render( status => 200, openapi => $authvalues );
    } catch {
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
        return $c->render(
            status  => 500,
            openapi => { error => "$_" }
        );
    };
}

1;
