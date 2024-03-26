package Koha::REST::V1::ERM;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Patrons;

use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::ERM

=head1 API

=head2 Class methods

=head3 config

Return the configuration options needed for the ERM Vue app

=cut

sub config {
    my $c = shift->openapi->valid_input or return;
    return $c->render(
        status => 200,
        openapi => {
            settings => {
                ERMModule => C4::Context->preference('ERMModule'),
                ERMProviders => [split ',', C4::Context->preference('ERMProviders')]
            },
            # TODO Add permissions
        },
    )
}

=head3 list_users

Return the list of possible ERM users

=cut

sub list_users {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $patrons_rs = Koha::Patrons->search->filter_by_have_permission('erm');
        my $patrons    = $c->objects->search( $patrons_rs );

        return $c->render(
            status  => 200,
            openapi => $patrons
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
