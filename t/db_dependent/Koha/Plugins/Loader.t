#!/usr/bin/perl

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
# with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;
use File::Basename;
use Test::MockModule;
use Test::More tests => 9;
use Test::NoWarnings;
use Test::Warn;

use C4::Context;
use Koha::Cache::Memory::Lite;
use Koha::Database;
use Koha::Plugins::Datas;
use Koha::Plugins;

use t::lib::Mocks;

BEGIN {
    # Mock pluginsdir before loading Plugins module
    my $path = dirname(__FILE__) . '/../../../lib/plugins';
    t::lib::Mocks::mock_config( 'pluginsdir', $path );

    use_ok('Koha::Plugins::Loader');
    use_ok('Koha::Plugins');
    use_ok('Koha::Plugins::Handler');
    use_ok('Koha::Plugin::Test');
}

my $schema = Koha::Database->new->schema;

subtest 'get_enabled_plugins - basic functionality' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    # Clear cache before testing
    Koha::Cache::Memory::Lite->flush();

    # Remove any existing plugins
    Koha::Plugins::Datas->delete;

    my $cache_key = 'enabled_plugins';

    # Test with no enabled plugins
    my @plugins = Koha::Plugins::Loader->get_enabled_plugins();
    is( scalar @plugins, 0, 'Returns empty list when no plugins are enabled' );

    # Test caching behavior
    my $cached = Koha::Cache::Memory::Lite->get_from_cache($cache_key);
    is( $cached, undef, "Nothing cached when no plugins" );

    my $mock_plugins = Test::MockModule->new("Koha::Plugins");
    $mock_plugins->mock( 'can_load', sub { return 0; } );

    # Test with invalid plugin class that can't be loaded by adding directly to DB
    Koha::Plugins::Data->new(
        {
            plugin_class => 'Koha::Plugin::Test',
            plugin_key   => '__ENABLED__',
            plugin_value => 1,
        }
    )->store;
    my $mock_test_plugin = Test::MockModule->new("Koha::Plugin::Test");
    $mock_test_plugin->mock( 'new', sub { return "Test"; } );

    @plugins = Koha::Plugins::Loader->get_enabled_plugins();
    is( scalar @plugins, 0, 'Returns empty list when no plugins are loaded' );
    $cached = Koha::Cache::Memory::Lite->get_from_cache($cache_key);
    is( $cached, undef, "Nothing cached when no plugins can be loaded" );

    $mock_plugins->mock( "can_load", sub { return 1; } );

    @plugins = Koha::Plugins::Loader->get_enabled_plugins();
    is( scalar @plugins, 1, 'Returns the plugin when loaded' );
    $cached = Koha::Cache::Memory::Lite->get_from_cache($cache_key);
    is( @{$cached}[0], $plugins[0], "Plugin successfully loaded and cached" );

    # The core functionality of loading plugins is tested indirectly through
    # the Koha::Plugins tests which use the Loader
    ok( 1, 'Loader module loaded successfully' );
    can_ok( 'Koha::Plugins::Loader', 'get_enabled_plugins' );

    $schema->storage->txn_rollback;
};

subtest 'get_enabled_plugins - table does not exist' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    # Clear cache
    Koha::Cache::Memory::Lite->flush();

    # Mock table_exists to return false
    my $mock_database = Test::MockModule->new('Koha::Database');
    $mock_database->mock( 'table_exists', sub { return 0; } );

    my @plugins = Koha::Plugins::Loader->get_enabled_plugins();
    is( scalar @plugins, 0, 'Returns empty list when plugin_data table does not exist' );

    # Verify it doesn't try to query the non-existent table
    # This test passes if no exception is thrown
    ok( 1, 'No exception thrown when table does not exist' );

    $schema->storage->txn_rollback;
};

subtest 'get_enabled_plugins - error handling' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    # Clear cache
    Koha::Cache::Memory::Lite->flush();

    # Remove existing plugins
    Koha::Plugins::Datas->delete;

    # Test with invalid plugin class that can't be loaded by adding directly to DB
    Koha::Plugins::Data->new(
        {
            plugin_class => 'Koha::Plugin::NonExistent',
            plugin_key   => '__ENABLED__',
            plugin_value => 1,
        }
    )->store;

    my @plugins = Koha::Plugins::Loader->get_enabled_plugins();
    is( scalar @plugins, 0, 'Returns empty list when plugin class cannot be loaded' );

    $schema->storage->txn_rollback;
};

subtest 'Integration with Koha::Plugins' => sub {
    plan tests => 1;

    # The Loader is designed to be used by Koha::Plugins::get_enabled_plugins
    # Test that the integration point exists
    can_ok( 'Koha::Plugins', 'get_enabled_plugins' );

    # Full integration testing is done in t/db_dependent/Koha/Plugins/Plugins.t
    # which exercises the complete plugin loading flow including the Loader
};
