# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 4;

use Test::Mojo;
use Data::Dumper;
use List::MoreUtils qw(any);

use FindBin();
use IPC::Cmd qw(can_run);

my $t    = Test::Mojo->new('Koha::REST::V1');
my $spec = $t->get_ok( '/api/v1/', 'Correctly fetched the spec' )->tx->res->json;

my $paths = $spec->{paths};

my @missing_additionalProperties = ();

foreach my $route ( keys %{$paths} ) {
    foreach my $verb ( keys %{ $paths->{$route} } ) {

        # p($paths->{$route}->{$verb});

        # check parameters []
        foreach my $parameter ( @{ $paths->{$route}->{$verb}->{parameters} } ) {
            if (   exists $parameter->{schema}
                && exists $parameter->{schema}->{type}
                && ref( $parameter->{schema}->{type} ) ne 'ARRAY'
                && $parameter->{schema}->{type} eq 'object' ) {

                # it is an object type definition
                if ( $parameter->{name} ne 'query' # our query parameter is under-specified
                    and not exists $parameter->{schema}->{additionalProperties} ) {
                    push @missing_additionalProperties,
                      { type  => 'parameter',
                        route => $route,
                        verb  => $verb,
                        name  => $parameter->{name}
                      };
                }
            }
        }

        # check responses  {}
        my $responses = $paths->{$route}->{$verb}->{responses};
        foreach my $response ( keys %{$responses} ) {
            if (   exists $responses->{$response}->{schema}
                && exists $responses->{$response}->{schema}->{type}
                && ref( $responses->{$response}->{schema}->{type} ) ne 'ARRAY'
                && $responses->{$response}->{schema}->{type} eq 'object' ) {

                # it is an object type definition
                if ( not exists $responses->{$response}->{schema}->{additionalProperties} ) {
                    push @missing_additionalProperties,
                      { type  => 'response',
                        route => $route,
                        verb  => $verb,
                        name  => $response
                      };
                }
            }
        }
    }
}

is( scalar @missing_additionalProperties, 0 )
  or diag Dumper \@missing_additionalProperties;

subtest 'The spec passes the swagger-cli validation' => sub {

    plan tests => 1;

    SKIP: {
        skip "Skipping tests, swagger-cli missing", 1
          unless can_run('swagger-cli');

        my $spec_dir = "$FindBin::Bin/../api/v1/swagger";
        my $var      = qx{swagger-cli validate $spec_dir/swagger.yaml 2>&1};
        is( $?, 0, 'Validation exit code is 0' )
          or diag $var;
    }
};

subtest '400 response tests' => sub {

    plan tests => 1;

    my @errors;

    foreach my $route ( sort keys %{$paths} ) {
        foreach my $verb ( keys %{ $paths->{$route} } ) {

            my $response_400 = $paths->{$route}->{$verb}->{responses}->{400};

            if ( !$response_400 ) {
                push @errors, "$verb $route -> response 400 absent";
                next;
            }

            push @errors,
                "$verb $route -> 'description' does not start with 'Bad request': ($response_400->{description})"
                unless $response_400->{description} =~ /^Bad request/;

            my $ref = $response_400->{schema}->{'$ref'};
            push @errors, "$verb $route -> '\$ref' is not '#/definitions/error': ($ref)"
                unless $ref =~ m/^#\/definitions\/error/;

            # GET routes with q parameter must mention the `invalid_query` error code
            if (   ( any { $_->{in} eq 'body' && $_->{name} eq 'query' } @{ $paths->{$route}->{$verb}->{parameters} } )
                || ( any { $_->{in} eq 'query' && $_->{name} eq 'q' } @{ $paths->{$route}->{$verb}->{parameters} } ) )
            {

                push @errors,
                    "$verb $route -> 'description' does not include '* \`invalid_query\`': ($response_400->{description})"
                    unless $response_400->{description} =~ /\* \`invalid_query\`/;
            }
        }
    }

    is( scalar @errors, 0, 'No errors in 400 definitions in the spec' );

    foreach my $error (@errors) {
        print STDERR "$error\n";
    }
};
