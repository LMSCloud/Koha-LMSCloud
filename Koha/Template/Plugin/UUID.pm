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

Generate a UUID, optionally with a prefix.

    UUID.generate()         # Returns: uuid-abc123def456
    UUID.generate('auth')   # Returns: auth-abc123def456

=cut

sub generate {
    my ( $self, $prefix ) = @_;

    # Fast hex generation using time and random component
    my $uuid = sprintf( "%x%x", time(), int( rand(0xFFFFFF) ) );

    return join( '-', $prefix // 'uuid', $uuid );
}

1;
