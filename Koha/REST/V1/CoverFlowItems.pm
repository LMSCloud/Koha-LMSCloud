package Koha::REST::V1::CoverFlowItems;

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
use C4::CoverFlowData 'GetCoverFlowDataOfNearbyItemsByItemNumber';

use Try::Tiny;

=head1 API

=head2 Methods

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $cover_flow_items = C4::CoverFlowData
    }
}

1;