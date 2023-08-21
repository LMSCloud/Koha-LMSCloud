package Koha::REST::Plugin::Pagination;

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

use Mojo::Base 'Mojolicious::Plugin';

=head1 NAME

Koha::REST::Plugin::Pagination

=head1 API

=head2 Mojolicious::Plugin methods

=head3 register

=cut

sub register {
    my ( $self, $app ) = @_;

=head2 Helper methods

=head3 add_pagination_headers

    $c->add_pagination_headers();
    $c->add_pagination_headers(
        {
            base_total   => $base_total,
            page         => $page,
            per_page     => $per_page,
            query_params => $query_params,
            total        => $total,
        }
    );

Adds RFC5988 compliant I<Link> headers for pagination to the response message carried
by our controller.

Additionally, it also adds the customer I<X-Total-Count> header containing the total results
count, and I<X-Base-Total-Count> header containing the total of the non-filtered results count.

Optionally accepts the any of the following parameters to override the values stored in the
stash by the I<search_rs> helper.

=over

=item base_total

Total records for the search domain (e.g. all patron records, filtered only by visibility)

=item page

The requested page number, usually extracted from the request query.
See I<objects.search_rs> for more information.

=item per_page

The requested maximum results per page, usually extracted from the request query.
See I<objects.search_rs> for more information.

=item query_params

The request query, usually extracted from the request query and used to build the I<Link> headers.
See I<objects.search_rs> for more information.

=item total

Total records for the search with filters applied.

=back

=cut

    $app->helper(
        'add_pagination_headers' => sub {
            my ( $c, $args ) = @_;

            my $base_total = $args->{base_total} // $c->stash('koha.pagination.base_total');
            my $req_page   = $args->{page}         // $c->stash('koha.pagination.page')     // 1;
            my $per_page   = $args->{per_page}     // $c->stash('koha.pagination.per_page') // C4::Context->preference('RESTdefaultPageSize') // 20;
            my $params     = $args->{query_params} // $c->stash('koha.pagination.query_params');
            my $total      = $args->{total}        // $c->stash('koha.pagination.total');

            my $pages;
            if ( $per_page == -1 ) {
                $req_page = 1;
                $pages    = 1;
            }
            else {
                $pages = int $total / $per_page;
                $pages++
                    if $total % $per_page > 0;
            }

            my @links;

            if ( $per_page != -1 and $pages > 1 and $req_page > 1 ) {    # Previous exists?
                push @links,
                    _build_link(
                    $c,
                    {   page     => $req_page - 1,
                        per_page => $per_page,
                        rel      => 'prev',
                        params   => $params
                    }
                    );
            }

            if ( $per_page != -1 and $pages > 1 and $req_page < $pages ) {    # Next exists?
                push @links,
                    _build_link(
                    $c,
                    {   page     => $req_page + 1,
                        per_page => $per_page,
                        rel      => 'next',
                        params   => $params
                    }
                    );
            }

            push @links,
                _build_link( $c,
                { page => 1, per_page => $per_page, rel => 'first', params => $params } );
            push @links,
                _build_link( $c,
                { page => $pages, per_page => $per_page, rel => 'last', params => $params } );

            # Add Link header
            foreach my $link (@links) {
                $c->res->headers->add( 'Link' => $link );
            }

            # Add X-Total-Count header
            $c->res->headers->add( 'X-Total-Count'      => $total );
            $c->res->headers->add( 'X-Base-Total-Count' => $base_total )
              if defined $base_total;

            return $c;
        }
    );

=head3 dbic_merge_pagination

    $filter = $c->dbic_merge_pagination({
        filter => $filter,
        params => {
            page     => $params->{_page},
            per_page => $params->{_per_page}
        }
    });

Adds I<page> and I<rows> elements to the filter parameter.

=cut

    $app->helper(
        'dbic_merge_pagination' => sub {
            my ( $c, $args ) = @_;
            my $filter = $args->{filter};

            $filter->{page} = $args->{params}->{_page};
            $filter->{rows} = $args->{params}->{_per_page};

            return $filter;
        }
    );
}

=head2 Internal methods

=head3 _build_link

    my $link = _build_link( $c, { page => 1, per_page => 5, rel => 'prev' });

Returns a string, suitable for using in Link headers following RFC5988.

=cut

sub _build_link {
    my ( $c, $args ) = @_;

    my $params = $args->{params};

    $params->{_page}     = $args->{page};
    $params->{_per_page} = $args->{per_page};

    my $link = '<'
        . $c->req->url->clone->query(
            $params
        )->to_abs
        . '>; rel="'
        . $args->{rel} . '"';

    # TODO: Find a better solution for this horrible (but needed) fix
    $link =~ s|api/v1/app\.pl/||;

    return $link;
}

1;
