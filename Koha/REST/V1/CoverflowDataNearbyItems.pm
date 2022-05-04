package Koha::REST::V1::CoverflowDataNearbyItems;

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
use utf8;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Misc::Coverhtml;

use C4::CoverFlowData;

use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::CoverflowDataNearbyItems - endpoint for getting nearby items
coverflow metadata according to itemcallnumber by given itemnumbers.

=head1 API

=head2 Methods

=cut

=head3 get

Controller function provides nearby items from given itemnumbers.

=cut

sub flat(@) {
    return map { ref eq 'ARRAY' ? @$_ : $_ } @_;
}

sub get {
    my $c        = shift->openapi->valid_input or return;
    my $item_id  = $c->validation->param('item_id');
    my $quantity = $c->validation->param('quantity');

    try {
        my $nearby_items
            = C4::CoverFlowData::GetCoverFlowDataOfNearbyItemsByItemNumber(
            $item_id, $quantity || 3 );

        if ( !$nearby_items ) {
            return $c->render(
                status  => 404,
                openapi => { error => 'No nearby items could be found' },
            );
        }

        my @item_hashes = flat( $nearby_items->{'items'} );

        @item_hashes = flat( Koha::Misc::Coverhtml::coverhtml(@item_hashes) );

        $nearby_items->{'items'} = \@item_hashes;

        return $c->render( status => 200, openapi => $nearby_items );
    }
    catch {
        $c->unhandled_exception($_);
    };

    return;
}

1;
