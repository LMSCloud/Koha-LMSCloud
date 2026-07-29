package Koha::Template::Plugin::BibtipToken;

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

use Digest::SHA qw( sha256_hex );

use C4::Context;

=head1 NAME

Koha::Template::Plugin::BibtipToken - Template plugin for generating BibTip API tokens

=head1 SYNOPSIS

In templates:

    [% USE BibtipToken %]
    <div id="bibtip_api_token" style="display:none">[% BibtipToken.generate | html %]</div>

=head1 DESCRIPTION

This plugin generates the C<X-API-Token> value expected by the BibTip recommender
service (REST API V5).

=head1 METHODS

=head2 generate

Return a token of the form C<1:$unix_time:$hex_digest>, where the digest is the
SHA-256 of C<$unix_time:$api_key>. The key defaults to the C<BibtipApiKey> system
preference; an explicit key overrides it.

    BibtipToken.generate
    BibtipToken.generate('secret')

=cut

sub generate {
    my ( $self, $api_key ) = @_;

    $api_key //= C4::Context->preference('BibtipApiKey') // q{};

    my $unix_time  = int time;
    my $hex_digest = sha256_hex( join q{:}, $unix_time, $api_key );

    return "1:$unix_time:$hex_digest";
}

1;
