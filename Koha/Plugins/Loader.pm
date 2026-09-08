package Koha::Plugins::Loader;

# Copyright 2024 Koha Development Team
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;
use Koha::Database;
use Koha::Cache::Memory::Lite;
use Module::Load::Conditional qw(can_load);

=head1 NAME

Koha::Plugins::Loader - Lightweight plugin loader for early initialization

=head1 SYNOPSIS

    # Safe to call from C4::Context BEGIN block
    use Koha::Plugins::Loader;
    my @plugins = Koha::Plugins::Loader->get_enabled_plugins();

=head1 DESCRIPTION

Minimal-dependency plugin loader that can be safely called during early
initialization (e.g., from C4::Context BEGIN block) without causing
circular dependencies. This module provides a clean separation between
plugin loading and the main Koha::Plugins module.

=head1 METHODS

=head2 get_enabled_plugins

    my @plugins = Koha::Plugins::Loader->get_enabled_plugins();

Returns a list of enabled plugin objects. Results are cached in memory
to avoid repeated database queries and plugin instantiation.

This method:
- Checks if the plugin_data table exists
- Queries for enabled plugins
- Loads and instantiates plugin classes
- Caches the results

Returns an array of plugin objects in list context, or an empty list
if plugins are not available or none are enabled.

=cut

sub get_enabled_plugins {
    my ( $class, $params ) = @_;

    my $cache_key = 'enabled_plugins';
    my $cached    = Koha::Cache::Memory::Lite->get_from_cache($cache_key);
    return @$cached if $cached;

    my $verbose = $params->{verbose} // 0;

    # Check if plugin_data table exists (using DBH for early init safety)
    my $dbh = eval { Koha::Database->dbh };
    return unless $dbh;
    return unless Koha::Database->table_exists( $dbh, 'plugin_data' );

    # Get enabled plugin classes using DBIx::Class when available
    # This ensures we see transactional changes in tests
    my @plugin_classes;
    if ( eval { require Koha::Plugins::Datas; 1 } ) {

        # Use DBIx::Class for proper transaction support
        eval {
            my $rs = Koha::Plugins::Datas->search( { plugin_key => '__ENABLED__', plugin_value => 1 } );
            @plugin_classes = $rs->get_column('plugin_class');
        };
    } else {

        # Fallback to raw DBI for early initialization
        my $plugin_classes_arrayref = $dbh->selectcol_arrayref(
            'SELECT plugin_class FROM plugin_data WHERE plugin_key = ? AND plugin_value = 1',
            {}, '__ENABLED__'
        ) || [];
        @plugin_classes = @$plugin_classes_arrayref;
    }

    # Load and instantiate plugins
    my @plugins;
    foreach my $plugin_class (@plugin_classes) {

        # Check if Koha::Plugins has a mocked can_load (for testing)
        # Otherwise use Module::Load::Conditional::can_load
        my $can_load_result;
        if ( eval { Koha::Plugins->can('can_load') } ) {

            # Use Koha::Plugins::can_load if it exists (might be mocked in tests)
            $can_load_result = eval {
                Koha::Plugins::can_load( modules => { $plugin_class => undef }, verbose => $verbose, nocache => 1 );
            };
        }
        if ( !defined $can_load_result ) {

            # Fall back to Module::Load::Conditional
            $can_load_result = can_load( modules => { $plugin_class => undef }, verbose => $verbose, nocache => 1 );
        }

        next unless $can_load_result;
        my $plugin = eval { $plugin_class->new() };
        push @plugins, $plugin if $plugin;
    }

    Koha::Cache::Memory::Lite->set_in_cache( $cache_key, \@plugins ) if @plugins;
    return @plugins;
}

=head1 AUTHOR

Koha Development Team

=cut

1;
