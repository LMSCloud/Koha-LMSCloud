package Koha::REST::V1::CoverflowDataQuery;

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

Koha::REST::V1::CoverflowDataQuery - endpoint for getting items
coverflow metadata by search term, maxcount and index offset.

=head1 API

=head2 Methods

=cut

=head3 get

Controller function provides coverflow data for a dataset of size maxcount based on query strings and index offset.

=cut

sub flat(@) {
    return map { ref eq 'ARRAY' ? @$_ : $_ } @_;
}

sub get {
    my $c          = shift->openapi->valid_input or return;
    my $query      = $c->validation->param('query');
    my $offset     = $c->validation->param('offset');
    my $maxcount   = $c->validation->param('maxcount');

    try {
        my $coverflow_data
            = C4::CoverFlowData::GetCoverFlowDataByQueryString($query, $offset, $maxcount);

        if ( !$coverflow_data ) {
            return $c->render(
                status  => 404,
                openapi =>
                    { error => 'No item(s) returned from specified query' },
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

    return;
}

1;
