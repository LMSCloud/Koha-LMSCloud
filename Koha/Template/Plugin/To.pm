package Koha::Template::Plugin::To;

# This file is part of Koha.
#
# Copyright BibLibre 2014
# parts Copyright 2018 (C) LMSCLoud GmbH
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use base qw( Template::Plugin );

use JSON qw( to_json );

sub json {
    my ( $self, $value ) = @_;

    my $json = JSON->new->allow_nonref(1);
    $json = $json->encode($value);
    $json =~ s/^"|"$//g; # Remove quotes around the strings
    $json =~ s/\\r/\\\\r/g; # Convert newlines to escaped newline characters
    $json =~ s/\\n/\\\\n/g;
    return $json;
}

# If using the json() function above for strings that are transformed to HTML text in a following step (e.g. by template tool), 
# the replacement of character " by string \", done by JSON->encode(), would in the end yield string \&quot; , 
# which is considered as invalid JSON when ajax parses the json response.
# In this case one can simply use jsonForHTMLEscaping() instead of json() in one's tt-file.
sub jsonForHTMLEscaping {
    my ( $self, $value ) = @_;

    $value =~ s/"/_Koha_Quote_Placeholder_/g;    # thus JSON->encode() will not be upset

    $value = $self->json($value);
    $value =~ s/_Koha_Quote_Placeholder_/"/g;    # so the " has survived uncluttered, the following [% ... | html %] will transform it to a simple %quot;
    return $value;
}

1;
