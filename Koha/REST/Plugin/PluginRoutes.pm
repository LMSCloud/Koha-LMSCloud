package Koha::REST::Plugin::PluginRoutes;

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

use Koha::Exceptions::Plugin;
use Koha::Plugins;
use Koha::Logger;

use Clone qw(clone);
use Try::Tiny;

=head1 NAME

Koha::REST::Plugin::PluginRoutes

=head1 API

=head2 Helper methods

=head3 register

=cut

sub register {
    my ( $self, $app, $config ) = @_;

    my $spec      = $config->{spec};
    my $validator = $config->{validator};

    my @plugins;

    if ( C4::Context->config("enable_plugins") )
    {
        $self->{'swagger-v2-schema'} = $app->home->rel_file("api/swagger-v2-schema.json");

        # plugin needs to define a namespace
        @plugins = Koha::Plugins->new()->GetPlugins(
            {
                method => 'api_namespace',
            }
        );

        foreach my $plugin ( @plugins ) {
            $spec = $self->inject_routes( $spec, $plugin, $validator );
        }

    }

    return $spec;
}

=head3 inject_routes

=cut

sub inject_routes {
    my ( $self, $spec, $plugin, $validator ) = @_;

    return merge_spec( $spec, $plugin ) unless $validator;

    return try {

        my $backup_spec = merge_spec( clone($spec), $plugin );
        if ( $self->spec_ok( $backup_spec, $validator ) ) {
            $spec = merge_spec( $spec, $plugin );
        }
        else {
            Koha::Exceptions::Plugin->throw(
                "The resulting spec is invalid. Skipping " . $plugin->get_metadata->{name}
            );
        }

        return $spec;
    }
    catch {
        my $error = $_;
        my $class = ref $plugin;
        my $logger = Koha::Logger->get({ interface => 'api' });
        $logger->error("Plugin $class route injection failed: $error");
        return $spec;
    };
}

=head3 merge_spec

=cut

sub merge_spec {
    my ( $spec, $plugin ) = @_;

    if($plugin->can('api_routes')) {
        my $plugin_spec = $plugin->api_routes;

        foreach my $route ( keys %{ $plugin_spec } ) {
            my $THE_route = '/contrib/' . $plugin->api_namespace . $route;
            if ( exists $spec->{ $THE_route } ) {
                # Route exists, overwriting is forbidden
                Koha::Exceptions::Plugin::ForbiddenAction->throw(
                    "Attempted to overwrite $THE_route"
                );
            }

            $spec->{'paths'}->{ $THE_route } = $plugin_spec->{ $route };
        }
    }

    if($plugin->can('static_routes')) {
        my $plugin_spec = $plugin->static_routes;

        foreach my $route ( keys %{ $plugin_spec } ) {

            my $THE_route = '/contrib/' . $plugin->api_namespace . '/static'.$route;
            if ( exists $spec->{ $THE_route } ) {
                # Route exists, overwriting is forbidden
                Koha::Exceptions::Plugin::ForbiddenAction->throw(
                    "Attempted to overwrite $THE_route"
                );
            }

            $spec->{'paths'}->{ $THE_route } = $plugin_spec->{ $route };
        }
    }
    return $spec;
}

=head3 spec_ok

=cut

sub spec_ok {
    my ( $self, $spec, $validator ) = @_;

    my $schema = $self->{'swagger-v2-schema'};

    return try {
        $validator->load_and_validate_schema(
            $spec,
            {
                allow_invalid_ref => 1,
                schema => ( $schema ) ? $schema : undef,
            }
        );
        return 1;
    }
    catch {
        return 0;
    }
}

1;