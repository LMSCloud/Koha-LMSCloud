package Koha::Template::Plugin::AdditionalContents;

# Copyright ByWater Solutions 2012
# Copyright BibLibre 2014
# Parts copyright Athens County Public Libraries 2019

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

use C4::Koha;
use C4::Context;
use Koha::AdditionalContents;

sub get {
    my ( $self, $params ) = @_;

    my $category   = $params->{category};
    my $location   = $params->{location};
    my $blocktitle = $params->{blocktitle};
    my $lang       = $params->{lang} || 'default';
    my $library    = $params->{library};

    my $content = Koha::AdditionalContents->search_for_display(
        {
            category   => $category,
            location   => $location,
            lang       => $lang,
            library_id => $library,
        }
    );

    if ( $content->count ) {
        return {
            content    => $content,
            location   => $location,
            blocktitle => $blocktitle
        };
    }
}

1;

=head1 NAME

Koha::Template::Plugin::AdditionalContents - TT Plugin for displaying additional contents

=head1 SYNOPSIS

[% USE AdditionalContents %]

[% AdditionalContents.get() %]

=head1 ROUTINES

=head2 get

In a template, you can get the all categories with
the following TT code: [% AdditionalContents.get() %]

=head1 AUTHOR

Owen Leonard <oleonard@myacpl.org>

=cut
