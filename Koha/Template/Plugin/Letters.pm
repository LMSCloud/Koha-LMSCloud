package Koha::Template::Plugin::Letters;

# Copyright 2017 LMSCloud GmbH
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

use C4::Letters qw( GetPatronLetters );

sub all {
    my ( $self, $params ) = @_;
    my $selected = $params->{selected};

    my $letters = GetPatronLetters();
    for my $letter ( @$letters ) {
        if ( $selected && $letter->{code} eq $selected ) {
            $letter->{selected} = 1;
        }
    }
    return $letters;
}

1;

=head1 NAME

Koha::Template::Plugin::Letters - TT Plugin for letter codes

=head1 SYNOPSIS

[% USE Letters %]

[% Letters.all() %]

=head1 ROUTINES

=head2 all

In a template, you can get the all letters with
the following TT code: [% Letters.all() %]

=head1 AUTHOR

Roger Grossmann <roger.grossmann@lmscloud.de>

=cut
