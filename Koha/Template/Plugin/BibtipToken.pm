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

use Carp        qw( carp );
use Digest::SHA qw( sha256_hex );

use constant CONFIG_FILE => '/etc/koha/BibtipApiKey.key';

my $config_cache;
my $carped;

=head1 NAME

Koha::Template::Plugin::BibtipToken - Template plugin for generating BibTip API tokens

=head1 SYNOPSIS

In templates:

    [% USE BibtipToken %]
    <div id="bibtip_api_token" style="display:none">[% BibtipToken.generate | html %]</div>

=head1 DESCRIPTION

This plugin generates the C<X-API-Token> value expected by the BibTip recommender
service (REST API V5).

The API key is read from F</etc/koha/BibtipApiKey.key>, a file of C<name=value> lines
(C<#> starts a comment); the key itself lives in C<key>:

    key=<KEY>

The file is kept in memory once it has been read successfully, so a page embedding the
BibTip client does not hit the disk on every request. Restart the OPAC (plack) after
changing the key file.

=head1 METHODS

=head2 generate

Return a token of the form C<1:$unix_time:$hex_digest>, where the digest is the
SHA-256 of C<$unix_time:$api_key>. The key defaults to the C<key> entry of
F</etc/koha/BibtipApiKey.key>; an explicit key overrides it.

Return the empty string if no key is configured, so that the client skips the request
instead of authenticating with a token that cannot be valid.

    BibtipToken.generate
    BibtipToken.generate('secret')

=cut

sub generate {
    my ( $self, $api_key ) = @_;

    $api_key //= _api_key();
    return q{} unless length $api_key;

    my $unix_time  = int time;
    my $hex_digest = sha256_hex( join q{:}, $unix_time, $api_key );

    return "1:$unix_time:$hex_digest";
}

=head2 _api_key

Return the C<key> entry of the BibTip configuration file, or the empty string if it
is not set.

=cut

sub _api_key {
    return _config()->{key} // q{};
}

=head2 _config

Return the contents of F</etc/koha/BibtipApiKey.key> as a hashref of C<name=value>
entries. A successful read is cached for the lifetime of the process. A missing or
unreadable file yields an empty configuration and is not cached, so that repairing the
file takes effect without a restart; it is reported once per process.

=cut

sub _config {
    return $config_cache if $config_cache;

    my $file = CONFIG_FILE;

    my $fh;
    if ( !open $fh, '<:encoding(UTF-8)', $file ) {
        carp "Could not read BibTip configuration file '$file': $!" unless $carped;
        $carped = 1;
        return {};
    }

    my $config = {};
    while ( my $line = <$fh> ) {
        next if $line =~ /^\s*#/;
        chomp $line;

        my ( $name, $value ) = split /=/, $line, 2;
        next unless defined $name && defined $value;

        for ( $name, $value ) {
            s/^\s+//;
            s/\s+$//;
        }
        next unless length $name && length $value;

        $config->{$name} = $value;
    }
    close $fh;

    $carped       = 0;
    $config_cache = $config;

    return $config_cache;
}

1;
