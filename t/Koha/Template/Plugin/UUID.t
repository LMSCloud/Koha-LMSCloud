#!/usr/bin/perl

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

use Test::More tests => 9;

BEGIN {
    use_ok('Koha::Template::Plugin::UUID');
}

my $plugin = Koha::Template::Plugin::UUID->new();
isa_ok( $plugin, 'Koha::Template::Plugin::UUID' );

subtest 'generate method exists' => sub {
    plan tests => 1;
    can_ok( $plugin, 'generate' );
};

subtest 'generate without prefix' => sub {
    plan tests => 3;

    my $uuid = $plugin->generate();
    ok( $uuid, 'UUID generated' );
    like(
        $uuid, qr/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
        'UUID has correct format (8-4-4-4-12)'
    );

    # Test that consecutive calls produce different UUIDs
    my $uuid2 = $plugin->generate();
    isnt( $uuid, $uuid2, 'Consecutive calls produce different UUIDs' );
};

subtest 'generate with custom prefix' => sub {
    plan tests => 2;

    my $uuid = $plugin->generate('auth');
    ok( $uuid, 'UUID with custom prefix generated' );
    like(
        $uuid, qr/^auth-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
        'UUID has correct format with custom prefix'
    );
};

subtest 'generate with empty prefix' => sub {
    plan tests => 2;

    my $uuid = $plugin->generate('');
    ok( $uuid, 'UUID with empty prefix generated' );
    like(
        $uuid, qr/^-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
        'UUID with empty prefix starts with hyphen'
    );
};

subtest 'uniqueness test' => sub {
    plan tests => 1;

    my %seen;
    my $duplicates = 0;

    # Generate 100 UUIDs and check for duplicates
    for my $i ( 1 .. 100 ) {
        my $uuid = $plugin->generate('test');
        if ( $seen{$uuid} ) {
            $duplicates++;
        }
        $seen{$uuid} = 1;
    }

    is( $duplicates, 0, 'No duplicates in 100 generated UUIDs' );
};

subtest 'different prefixes produce different results' => sub {
    plan tests => 2;

    my $uuid1 = $plugin->generate('prefix1');
    my $uuid2 = $plugin->generate('prefix2');

    like( $uuid1, qr/^prefix1-/, 'First UUID has correct prefix' );
    like( $uuid2, qr/^prefix2-/, 'Second UUID has correct prefix' );
};

subtest 'UUID v4 format compliance' => sub {
    plan tests => 3;

    my $uuid = $plugin->generate();

    # Check overall format
    like(
        $uuid, qr/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
        'UUID matches standard format'
    );

    # Extract version nibble (first character of 3rd group should be 4 for v4)
    my ($version_part) = $uuid =~ /^[0-9a-f]{8}-[0-9a-f]{4}-([0-9a-f])/i;
    is( lc($version_part), '4', 'UUID version nibble is 4 (UUID v4)' );

    # Extract variant bits (first character of 4th group should be 8, 9, a, or b)
    my ($variant_part) = $uuid =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-([0-9a-f])/i;
    like( lc($variant_part), qr/^[89ab]$/, 'UUID variant bits are correct (RFC 4122)' );
};
