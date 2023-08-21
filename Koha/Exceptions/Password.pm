package Koha::Exceptions::Password;

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

use Koha::Exception;

use Exception::Class (

    'Koha::Exceptions::Password' => {
        isa => 'Koha::Exception',
    },
    'Koha::Exceptions::Password::Invalid' => {
        isa => 'Koha::Exceptions::Password',
        description => 'Invalid password'
    },
    'Koha::Exceptions::Password::TooShort' => {
        isa => 'Koha::Exceptions::Password',
        description => 'Password is too short',
        fields => ['length','min_length']
    },
    'Koha::Exceptions::Password::TooWeak' => {
        isa => 'Koha::Exceptions::Password',
        description => 'Password is too weak'
    },
    'Koha::Exceptions::Password::WhitespaceCharacters' => {
        isa => 'Koha::Exceptions::Password',
        description => 'Password contains leading/trailing whitespace character(s)'
    },
    'Koha::Exceptions::Password::Plugin' => {
        isa => 'Koha::Exceptions::Password',
        description => 'The password was rejected by a plugin'
    },
    'Koha::Exceptions::Password::NoCategoryProvided' => {
        isa => 'Koha::Exceptions::Password',
        description => 'You must provide a patron\'s category to validate password\'s strength and length'
    }
);

sub full_message {
    my $self = shift;

    my $msg = $self->message;

    unless ( $msg) {
        if ( $self->isa('Koha::Exceptions::Password::TooShort') ) {
            $msg = sprintf("Password length (%s) is shorter than required (%s)", $self->length, $self->min_length );
        }
    }

    return $msg;
}

=head1 NAME

Koha::Exceptions::Password - Base class for password exceptions

=head1 Exceptions

=head2 Koha::Exceptions::Password

Generic password exception

=head2 Koha::Exceptions::Password::Invalid

The supplied password is invalid.

=head2 Koha::Exceptions::Password::TooShort

Password is too short.

=head2 Koha::Exceptions::Password::TooWeak

Password is too weak.

=head2 Koha::Exceptions::Password::WhitespaceCharacters

Password contains leading/trailing spaces, which is forbidden.

=head1 Class methods

=head2 full_message

Overloaded method for exception stringifying.

=cut

1;
