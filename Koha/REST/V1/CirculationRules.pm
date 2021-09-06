package Koha::REST::V1::CirculationRules;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::CirculationRules;

use Try::Tiny;

=head1 API

=head2 Methods

=head3 get_kinds

List all available circulation rules that can be used.

=cut

sub get_kinds {
    my $c = shift->openapi->valid_input or return;

    return $c->render(
        status => 200,
        openapi => Koha::CirculationRules->rule_kinds,
    );
}

1;
