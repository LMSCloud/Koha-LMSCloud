package Koha::Plugin::Test::Controller;

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

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;

=head1 API

=head2 Methods

=head3 bother

=cut

sub bother {
    my ($c) = @_;
    return $c->render(
        status  => 200,
        openapi => { bothered => Mojo::JSON->true }
    );
}

=head3 owns_auth

Used by routes declaring x-plugin-owns-auth. Reports whether a userenv was
visible to the controller, so tests can assert the request did not inherit one
left behind by an earlier request in the same process.

=cut

sub owns_auth {
    my ($c) = @_;

    my $userenv = C4::Context->userenv;

    return $c->render(
        status  => 200,
        openapi => {
            bothered    => Mojo::JSON->true,
            userenv_set => ( $userenv && $userenv->{number} ) ? Mojo::JSON->true : Mojo::JSON->false,
        }
    );
}

1;
