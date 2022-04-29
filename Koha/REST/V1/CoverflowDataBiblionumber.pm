package Koha::REST::V1::CoverflowDataBiblionumber;

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

use Koha::Misc::Coverhtml;

use C4::CoverFlowData;

use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::Items - Koha REST API for handling items (V1)

=head1 API

=head2 Methods

=cut

=head3 get

Controller function provides coverflow data for given biblionumbers.

=cut

sub get {
    
    sub flat(@) {
        return map { ref eq 'ARRAY' ? @$_ : $_ } @_;
    }

    my $c = shift->openapi->valid_input or return;
    my @params = $c->validation->output->{'biblio_ids'};
    my @biblio_ids = flat(@params);

    try {
        my $coverflow_data = C4::CoverFlowData::GetCoverFlowDataByBiblionumber(@biblio_ids);

        unless ( $coverflow_data ) {
            return $c->render(
                status => 404,
                openapi => { error => "No item(s) with specified biblionumber(s)" }
            );
        }
        

        my @item_hashes = flat( $coverflow_data->{'items'} );

        @item_hashes = flat( Koha::Misc::Coverhtml::coverhtml(@item_hashes) );

        $coverflow_data->{'items'} = \@item_hashes;

        return $c->render( status => 200, openapi => $coverflow_data );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
