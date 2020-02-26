package Koha::REST::V1::Illrequests;

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
use Time::HiRes qw(time);

use Modern::Perl;
use Data::Dumper;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Illrequests;
use Koha::Illrequestattributes;
use Koha::Libraries;
use Koha::Patrons;
use Koha::DateUtils qw( format_sqldatetime );

=head1 NAME

Koha::REST::V1::Illrequests

=head2 Operations

=head3 list

Return a list of ILL requests, after applying filters.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my $args = $c->req->params->to_hash // {};
    #my @format_dates = ( 'placed', 'updated', 'completed' );  # Koha master
    my @format_dates = ( 'updated' );
    my $filter;
    # Create a hash where all keys are embedded values
    # Enables easy checking
    my %embed;
    my $args_arr = (ref $args->{embed} eq 'ARRAY') ? $args->{embed} : [ $args->{embed} ];
    if (defined $args->{embed}) {
        %embed = map { $_ => 1 }  @{$args_arr};
        delete $args->{embed};
    }

    if (defined $args->{infilter}) {
        my @cond = @{$args->{infilter}};
        my $fieldname = shift @cond;
        my $incond = shift @cond;
        $filter->{$fieldname} = { $incond => \@cond };
        delete $args->{infilter};
    }

    for my $filter_param ( keys %$args ) {
        my @values = split(/,/, $args->{$filter_param});
        $filter->{$filter_param} = \@values;
    }

    my $fetchadd = {};
    $fetchadd = { prefetch => 'illrequestattributes' } if ($embed{metadata});


    # Get all requests that meet the select condition
    my @requests = Koha::Illrequests->search($filter,$fetchadd)->as_list;

    # Identify patrons & branches that
    # we're going to need and get them
    my $to_fetch = {
        patrons      => {},
        branches     => {},
        capabilities => {}
    };
    foreach my $req(@requests) {
        $to_fetch->{patrons}->{$req->borrowernumber} = 1 if $embed{patron} && $req->borrowernumber;
        $to_fetch->{branches}->{$req->branchcode} = 1 if $embed{library};
        $to_fetch->{capabilities}->{$req->backend} = 1 if $embed{capabilities} && $req->backend;
    }

    # Fetch the patrons we need
    my $patrons = {};
    if ($embed{patron}) {
        my @patron_ids = keys %{$to_fetch->{patrons}};
        if (scalar @patron_ids > 0) {
            my $where = {
                borrowernumber => { -in => \@patron_ids }
            };
            my $patron_arr = Koha::Patrons->search($where)->unblessed;
            foreach my $p(@{$patron_arr}) {
                $patrons->{$p->{borrowernumber}} =
                {
                    patron_id      => $p->{borrowernumber},
                    firstname      => $p->{firstname},
                    surname        => $p->{surname},
                    cardnumber     => $p->{cardnumber}
                };
            }
        }
    }

    # Fetch the branches we need
    my $branches = {};
    if ($embed{library}) {
        my @branchcodes = keys %{$to_fetch->{branches}};
        if (scalar @branchcodes > 0) {
            my $where = {
                branchcode => { -in => \@branchcodes }
            };
            my $branch_arr = Koha::Libraries->search($where)->unblessed;
            foreach my $b(@{$branch_arr}) {
                $branches->{$b->{branchcode}} = $b;
            }
        }
    }

    # Fetch the capabilities we need
    my $backendcapabilities = {};
    if ($embed{capabilities}) {
        my @backends = keys %{$to_fetch->{capabilities}};
        if (scalar @backends > 0) {
            foreach my $bc(@backends) {
                my $backend = Koha::Illrequest->new->load_backend($bc);
                $backendcapabilities->{$bc} = $backend->capabilities;
            }
        }
    }

    # Now we've got all associated users and branches,
    # we can augment the request objects
    my @output = ();
    $output[0] = ();    # for illrequests
    $output[1] = $patrons;    # for patrons
    $output[2] = $branches;    # for branches
    $output[3] = $backendcapabilities;    # for backend capabilities

    foreach my $req(@requests) {
        my $to_push->{illreq} = $req->unblessed;
        $to_push->{illreq}->{id_prefix} = $req->id_prefix;  # Koha master
        #$to_push->{illreq}->{id_prefix} = '';    # faster variant

        # Create new "formatted" columns for each date column
        # that needs formatting
        foreach my $field(@format_dates) {
            if (defined $to_push->{illreq}->{$field}) {
                $to_push->{illreq}->{$field . "_formatted"} = format_sqldatetime(
                    $to_push->{illreq}->{$field},
                    undef,
                    undef,
                    ### 1  # Koha master
                    0    # LMSCloud
                );

            }
        }

        if ( ! exists( $patrons->{$req->borrowernumber} ) ) {
            # try your luck in the backend
            my $patronInfo = $req->_backend_capability( "getPatronInfo", $req );
            if ( $patronInfo ) {
                my $patronHelp = {
                    patron_id  => '',
                    firstname  => $patronInfo->{firstname},
                    surname    => $patronInfo->{surname},
                    cardnumber => $patronInfo->{cardnumber}
                };
                $patrons->{$req->borrowernumber} =  $patronHelp;
            }
        }

        if ($embed{metadata}) {
            my $meta_hash_json = {};
            my $meta_hash_backend = {};
            my $attributes =  $req->illrequestattributes->unblessed;

            my $attrcount = 0;
            foreach my $meta (@$attributes) {
                $meta_hash_backend->{$meta->{type}} = $meta->{value};
            }
            $meta_hash_json->{Author} = $meta_hash_backend->{author};
            $meta_hash_json->{Title} = $meta_hash_backend->{title};
            $meta_hash_json->{ISBN} = $meta_hash_backend->{isbn};

            # try to get better values from the backend
            my $backend_metadata;
            #eval { $backend_metadata = $req->metadata( $meta_hash_backend ); };
            $backend_metadata = $req->metadata( $meta_hash_backend );
            if ( $backend_metadata ) {
                foreach my $type ( keys %{$backend_metadata} ) {
                    $meta_hash_json->{$type} = $backend_metadata->{$type};
                }
            }

            $to_push->{illreq}->{metadata} = $meta_hash_json;
        }

        if ($embed{comments}) {
            $to_push->{illreq}->{comments} = $req->illcomments->count;
        }
        if ($embed{status_alias}) {
            $to_push->{illreq}->{status_alias} = $req->statusalias;
        }
        if ($embed{requested_partners}) {
            $to_push->{illreq}->{requested_partners} = $req->requested_partners;
        }
        push @{$output[0]}, $to_push->{illreq};
    }

    return $c->render( status => 200, openapi => \@output );
}

1;
