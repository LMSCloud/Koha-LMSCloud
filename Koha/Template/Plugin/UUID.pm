package Koha::Template::Plugin::UUID;

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

use Template::Plugin;
use base qw( Template::Plugin );
use UUID;

=head1 NAME

Koha::Template::Plugin::UUID - Template plugin for generating UUIDs

=head1 SYNOPSIS

In templates:

    [% USE UUID %]
    [% SET unique_id = UUID.generate %]
    <div id="[% unique_id %]">...</div>

    Or with a prefix:

    [% SET auth_id = UUID.generate('auth') %]
    <a class="[% auth_id %]">...</a>

=head1 DESCRIPTION

This plugin provides a simple way to generate unique identifiers in Template Toolkit templates.

=head1 METHODS

=head2 generate

Generate a UUID v4 (random), optionally with a prefix.

    UUID.generate()         # Returns: 550e8400-e29b-41d4-a716-446655440000
    UUID.generate('auth')   # Returns: auth-550e8400-e29b-41d4-a716-446655440000

=cut

sub generate {
    my ( $self, $prefix ) = @_;

    # Generate a proper UUID v4
    my ( $uuid, $uuidstring );
    UUID::generate($uuid);
    UUID::unparse( $uuid, $uuidstring );

    return defined($prefix) ? "$prefix-$uuidstring" : $uuidstring;
}

1;
