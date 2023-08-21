package Koha::Plugins;

# Copyright 2012 Kyle Hall
#
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

use Array::Utils qw( array_minus );
use Class::Inspector;
use List::MoreUtils qw( any );
use Module::Load::Conditional qw( can_load );
use Module::Load;
use Module::Pluggable search_path => ['Koha::Plugin'], except => qr/::Edifact(|::Line|::Message|::Order|::Segment|::Transport)$/;
use Try::Tiny;

use C4::Context;
use C4::Output;

use Koha::Cache::Memory::Lite;
use Koha::Exceptions::Plugin;
use Koha::Plugins::Methods;

use constant ENABLED_PLUGINS_CACHE_KEY => 'enabled_plugins';

BEGIN {
    my $pluginsdir = C4::Context->config("pluginsdir");
    my @pluginsdir = ref($pluginsdir) eq 'ARRAY' ? @$pluginsdir : $pluginsdir;
    push @INC, array_minus(@pluginsdir, @INC) ;
    pop @INC if $INC[-1] eq '.';
}

=head1 NAME

Koha::Plugins - Module for loading and managing plugins.

=head2 new

Constructor

=cut

sub new {
    my ( $class, $args ) = @_;

    return unless ( C4::Context->config("enable_plugins") || $args->{'enable_plugins'} );

    $args->{'pluginsdir'} = C4::Context->config("pluginsdir");

    return bless( $args, $class );
}

=head2 call

Calls a plugin method for all enabled plugins

    @responses = Koha::Plugins->call($method, @args)

Note: Pass your arguments as refs, when you want subsequent plugins to use the value
updated by preceding plugins, provided that these plugins support that.

=cut

sub call {
    my ($class, $method, @args) = @_;

    return unless C4::Context->config('enable_plugins');

    my @responses;
    my @plugins = $class->get_enabled_plugins();
    @plugins = grep { $_->can($method) } @plugins;

    # TODO: Remove warn when after_hold_create is removed from the codebase
    warn "after_hold_create is deprecated and will be removed soon. Contact the following plugin's authors: " . join( ', ', map {$_->{metadata}->{name}} @plugins)
        if $method eq 'after_hold_create' and @plugins;

    foreach my $plugin (@plugins) {
        my $response = eval { $plugin->$method(@args) };
        if ($@) {
            warn sprintf("Plugin error (%s): %s", $plugin->get_metadata->{name}, $@);
            next;
        }

        push @responses, $response;
    }

    return @responses;
}

=head2 get_enabled_plugins

Returns a list of enabled plugins.

    @plugins = Koha::Plugins->get_enabled_plugins();

=cut

sub get_enabled_plugins {
    my ($class) = @_;

    return unless C4::Context->config('enable_plugins');

    my $enabled_plugins = Koha::Cache::Memory::Lite->get_from_cache(ENABLED_PLUGINS_CACHE_KEY);
    unless ($enabled_plugins) {
        $enabled_plugins = [];
        my $rs = Koha::Database->schema->resultset('PluginData');
        $rs = $rs->search({ plugin_key => '__ENABLED__', plugin_value => 1 });
        my @plugin_classes = $rs->get_column('plugin_class')->all();
        foreach my $plugin_class (@plugin_classes) {
            unless (can_load(modules => { $plugin_class => undef }, nocache => 1)) {
                warn "Failed to load $plugin_class: $Module::Load::Conditional::ERROR";
                next;
            }

            my $plugin = eval { $plugin_class->new() };
            if ($@ || !$plugin) {
                warn "Failed to instantiate plugin $plugin_class: $@";
                next;
            }

            push @$enabled_plugins, $plugin;
        }
        Koha::Cache::Memory::Lite->set_in_cache(ENABLED_PLUGINS_CACHE_KEY, $enabled_plugins);
    }

    return @$enabled_plugins;
}

=head2 GetPlugins

This will return a list of all available plugins, optionally limited by
method or metadata value.

    my @plugins = Koha::Plugins::GetPlugins({
        method => 'some_method',
        metadata => { some_key => 'some_value' },
    });

The method and metadata parameters are optional.
If you pass multiple keys in the metadata hash, all keys must match.

=cut

sub GetPlugins {
    my ( $self, $params ) = @_;

    my $method       = $params->{method};
    my $req_metadata = $params->{metadata} // {};

    my $filter = ( $method ) ? { plugin_method => $method } : undef;

    my $plugin_classes = Koha::Plugins::Methods->search(
        $filter,
        {   columns  => 'plugin_class',
            distinct => 1
        }
    )->_resultset->get_column('plugin_class');

    my @plugins;

    # Loop through all plugins that implement at least a method
    while ( my $plugin_class = $plugin_classes->next ) {

        if ( can_load( modules => { $plugin_class => undef }, nocache => 1 ) ) {

            my $plugin;
            my $failed_instantiation;

            try {
                $plugin = $plugin_class->new({
                    enable_plugins => $self->{'enable_plugins'}
                        # loads even if plugins are disabled
                        # FIXME: is this for testing without bothering to mock config?
                });
            }
            catch {
                warn "$_";
                $failed_instantiation = 1;
            };

            next if $failed_instantiation;

            next unless $plugin->is_enabled or
                        defined($params->{all}) && $params->{all};

            # filter the plugin out by metadata
            my $plugin_metadata = $plugin->get_metadata;
            next
                if $plugin_metadata
                and %$req_metadata
                and any { !$plugin_metadata->{$_} || $plugin_metadata->{$_} ne $req_metadata->{$_} } keys %$req_metadata;

            push @plugins, $plugin;
        } elsif ( defined($params->{errors}) && $params->{errors} ){
            push @plugins, { error => 'cannot_load', name => $plugin_class };
        }

    }

    return @plugins;
}

=head2 InstallPlugins

Koha::Plugins::InstallPlugins()

This method iterates through all plugins physically present on a system.
For each plugin module found, it will test that the plugin can be loaded,
and if it can, will store its available methods in the plugin_methods table.

NOTE: We reload all plugins here as a protective measure in case someone
has removed a plugin directly from the system without using the UI

=cut

sub InstallPlugins {
    my ( $self, $params ) = @_;

    my @plugin_classes = $self->plugins();
    my @plugins;

    foreach my $plugin_class (@plugin_classes) {
        if ( can_load( modules => { $plugin_class => undef }, nocache => 1 ) ) {
            next unless $plugin_class->isa('Koha::Plugins::Base');

            my $plugin;
            my $failed_instantiation;

            try {
                $plugin = $plugin_class->new({ enable_plugins => $self->{'enable_plugins'} });
            }
            catch {
                warn "$_";
                $failed_instantiation = 1;
            };

            next if $failed_instantiation;

            Koha::Plugins::Methods->search({ plugin_class => $plugin_class })->delete();

            foreach my $method ( @{ Class::Inspector->methods( $plugin_class, 'public' ) } ) {
                Koha::Plugins::Method->new(
                    {
                        plugin_class  => $plugin_class,
                        plugin_method => $method,
                    }
                )->store();
            }

            push @plugins, $plugin;
        } else {
            my $error = $Module::Load::Conditional::ERROR;
            # Do not warn the error if the plugin has been uninstalled
            warn $error unless $error =~ m|^Could not find or check module '$plugin_class'|;
        }
    }

    Koha::Cache::Memory::Lite->clear_from_cache(ENABLED_PLUGINS_CACHE_KEY);

    return @plugins;
}

1;
__END__

=head1 AUTHOR

Kyle M Hall <kyle.m.hall@gmail.com>

=cut
