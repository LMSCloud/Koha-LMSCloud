package Koha::REST::V1::Illrequests;

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
use Data::Dumper;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;
use Koha::Illrequests;
use Koha::Illrequestattributes;
use Koha::Libraries;
use Koha::Patrons;
use Koha::Libraries;
use Koha::DateUtils qw( format_sqldatetime );

=head1 NAME

Koha::REST::V1::Illrequests

=head2 Operations

=head3 list

Controller function that handles listing Koha::Illrequest objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $backendsStringMap = {};    # mapping of designation used in a specific backend's illrequestattributes.type to designation assumed in the general ILL framework
        my $config = Koha::Illrequest::Config->new;
        my $backends = $config->available_backends;

        foreach my $b (@$backends) {
            my $backend = Koha::Illrequest->new->load_backend($b);

            my $backendStringMap = $backend->_backend_capability( 'getStringMap', $backend );
            if ( ! $backendStringMap ) {
                $backendStringMap = {};
            }
            $backendsStringMap->{$b} = $backendStringMap;
        }


        my $reqs = $c->objects->search(Koha::Illrequests->new->filter_by_visible);

        # Via backendsStringMap we rename the specific backend's illrequestattributes.type to the type designation used in the general ILL framework (e.g. in in ill-list-table.js).
        foreach my $req ( @{$reqs} ) {
            my $ill_backend_id = $req->{ill_backend_id};
            if ( $backendsStringMap->{$ill_backend_id} && $backendsStringMap->{$ill_backend_id}->{attrType} ) {
                foreach my $frameworkAttrType ( keys %{$backendsStringMap->{$ill_backend_id}->{attrType}} ) {
                    my $backendAttrType = $frameworkAttrType;
                    $backendAttrType = $backendsStringMap->{$ill_backend_id}->{attrType}->{$frameworkAttrType};
                    if ( $backendAttrType && ($backendAttrType ne $frameworkAttrType) ) {
                        foreach my $illattr ( @{$req->{extended_attributes}} ) {
                            my $type = $illattr->{type};
                            if ( $type && $type eq $backendAttrType ) {
                                $illattr->{type} = $frameworkAttrType;
                                last;
                            }
                        }
                    }
                }
            }
        }

        return $c->render(
            status  => 200,
            openapi => $reqs,
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
