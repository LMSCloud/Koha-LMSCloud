package Koha::CoverGenerator;

# Copyright 2022 LMSCloud GmbH
#
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

use strict;
use warnings;
use Modern::Perl;

our $VERSION = 1.0.0;

# our (@EXPORT_OK);

# BEGIN {
#     require Exporter;
#     use base qw( Exporter );
#     @EXPORT_OK = qw( render_image );
# }

use GD::Image;
use GD::Text::Align;
use MIME::Base64;
use Koha::Exceptions;
use Try::Tiny;

use Data::Dumper;

=head1 NAME

C4::CoverGen - generate pngs as substitutes for missing cover images based 
on two input strings.

=head1 SYNOPSIS

  use C4::CoverGen;

=head1 DESCRIPTION

This module provides a public to draw an image based on two input 
strings through GD::Image and GD::Text::Align.

The module returns a base64 encoded string, that can be used as a
data url in JavaScript.

=head1 FUNCTIONS

=head2 render_image( %args )

my %args = (
    first_line      => $first_line,
    second_line     => $second_line,
    font            => $font,
    font_path       => $font_path,
    width           => $width,
    height          => $height,
    fontsize        => $fontsize,
    padding         => $padding
)

=over 4

=item C<first_line>

First and second line are the strings to be drawn on the canvas.

=item C<second_line>

First and second line are the strings to be drawn on the canvas.

=item C<font>

The exact filename of the font to be used while omitting any extensions 
like .ttf or .otf.

=item C<font_path>

The path to the fonts directory where $font is located. Don't forget the
'/' at the end of the path.

=item C<width>

Width of the canvas.

=item C<height>

Height of the canvas.

=item C<fontsize>

Fontsize of the text drawn to the canvas.

=item C<padding>

Padding of the text drawn to the canvas.

=back

=cut

use constant {
    TWO => 2,
    SIX => 6,

    RED   => 244,
    GREEN => 244,
    BLUE  => 244,
};

use constant SPACE => q{ };
use constant EMPTY => q{};

my @leftover_words = EMPTY;
my $leftover_words = EMPTY;

sub new {
    my ( $class, $args ) = @_;
    my $self = bless {
        first_line  => { string => $args->{'first_line'}, },
        second_line => { string => $args->{'second_line'}, },
        font        => {
            name => $args->{'font'},
            path => $args->{'font_path'},
            size => $args->{'fontsize'},
        },
        dimensions => {
            width         => $args->{'width'},
            height        => $args->{'height'},
            padding       => $args->{'padding'},
            content_width => $args->{'width'} - $args->{'padding'},
        },
        positions => {
            horizontal_center => $args->{'width'} / TWO,
            vertical_top      => $args->{'height'} / SIX,
            vertical_bottom   => $args->{'height'} / TWO,
        },

        image => GD::Image->new( $args->{'width'}, $args->{'height'} ),
    }, $class;

    $self->{'image'}->colorAllocate( RED, GREEN, BLUE );
    $self->{'font'}->{'color'} = $self->{'image'}->colorAllocate( 0, 0, 0 );

    $self->{'align'} = GD::Text::Align->new(
        $self->{'image'},
        valign => 'center',
        halign => 'center',
        color  => $self->{'font'}->{'color'},
    );
    $self->{'align'}->font_path( $args->{'font_path'} );

    return $self;

}

sub get_string_width_by_params {
    my ( $class, $args ) = @_;

    if ( !defined $class->{'align'} ) {
        Koha::Exceptions::MissingParameter->throw(
            'image is undefined as parameter in get_string_width_by_params');
    }

    $class->{'align'}->set_font( $class->{'font'}->{'name'},
        $args->{'fontsize'} || $class->{'font'}->{'size'} );
    $class->{'align'}->set_text( $args->{'string'} );

    return $class->{'align'}->get('width');
}

sub trim_string {
    my ( $class, $args ) = @_;

    # turning point for the trim_string function.
    if ( $args->{'string'} eq $leftover_words ) {
        $leftover_words = EMPTY;
    }

    # Break the string on spaces and assign to array.
    my @words = split SPACE, $args->{'string'};

    # Pop the last word and store in leftovers.
    $leftover_words .= pop(@words) . SPACE;

    # Set the return value to empty string.
    my $new_line = EMPTY;

    # Append the remaining words to the return value.
    for my $word (@words) {
        $new_line .= "$word ";
    }

    # Check if the new line fits into the box.
    my $new_string_width
        = $class->get_string_width_by_params( { string => $new_line } );

    # If it does, return the new line and handle the leftovers.
    if ( $new_string_width <= $class->{'dimensions'}->{'content_width'} ) {
        return $new_line;
    }

# If a single word is bigger than the box, we have to prevent an infinite loop.
    if ( $new_string_width > $class->{'dimensions'}->{'content_width'}
        && scalar @words == 1 )
    {
        return $new_line;
    }

    # If it doesn't, repeat the process until it does.
    return $class->trim_string( { string => $new_line, } );
}

sub format_string {
    my ( $class, $args ) = @_;

    my $string_width = $class->get_string_width_by_params(
        { string => $args->{'string'} } );

    if ( $string_width <= $class->{'dimensions'}->{'content_width'} ) {
        return $args->{'string'};
    }

    my $return_value;
    my $formatted_string = EMPTY;

    $return_value = $class->trim_string( { string => $args->{'string'}, } );
    $formatted_string .= "$return_value\n";

    # reverse order of the leftovers before entering the while loop.
    @leftover_words = reverse split SPACE, $leftover_words;
    $leftover_words = EMPTY;

    for my $word (@leftover_words) {
        $leftover_words .= "$word ";
    }

    while ( !$leftover_words eq EMPTY ) {
        $return_value = EMPTY;
        $return_value = $class->trim_string( { string => $leftover_words, } );

        $formatted_string .= "$return_value\n";

        @leftover_words = reverse split SPACE, $leftover_words;
        $leftover_words = EMPTY;

        for my $word (@leftover_words) {
            $leftover_words .= "$word ";
        }

        my $new_string_width = $class->get_string_width_by_params(
            { string => $leftover_words } );

        if ( $new_string_width <= $class->{'dimensions'}->{'content_width'} )
        {
            $formatted_string .= "$leftover_words\n";
            $leftover_words = EMPTY;
        }

        if ( $new_string_width > $class->{'dimensions'}->{'content_width'}
            && scalar @leftover_words == 1 )
        {
            $formatted_string .= "$leftover_words\n";
            $leftover_words = EMPTY;
        }

    }

    return $formatted_string;

}

sub draw_text {
    my ( $class, $args ) = @_;

    my $result_string
        = $class->format_string( { string => $args->{'content_string'}, } );

    my $new_image_width
        = $class->get_string_width_by_params( { string => $result_string, } );

    my $new_fontsize = 0;

    while ( $new_image_width > $class->{'dimensions'}->{'content_width'} ) {
        if ( !$new_fontsize ) {
            $new_fontsize = $class->{'font'}->{'size'} - 2;
        }
        $class->{'align'}
            ->set_font( $class->{'font'}->{'name'}, $new_fontsize );
        $new_image_width = $class->get_string_width_by_params(
            {   fontsize => $new_fontsize,
                string   => $result_string
            }
        );
        $new_fontsize -= 2;
    }

    my @centered_result = split m/[\n]/xms, $result_string;

    my $index = 0;
    for my $line (@centered_result) {
        $class->{'align'}->set_text($line);
        $class->{'align'}->draw(
            $class->{'positions'}->{'horizontal_center'},
            $args->{'vertical_position'} + $index * (
                $class->{'font'}->{'size'}
                    + ( $class->{'font'}->{'size'} / 2 )
            ),
            0
        );
        $index++;
    }

    return;
}

sub render_image {
    my $class = shift;

    if ( $class->{'first_line'}->{'string'} ) {
        $class->draw_text(
            {   content_string    => $class->{'first_line'}->{'string'},
                vertical_position => $class->{'positions'}->{'vertical_top'},
            }

        );
    }

    if ( $class->{'second_line'}->{'string'} ) {
        $class->draw_text(
            {   content_string    => $class->{'second_line'}->{'string'},
                vertical_position => !$class->{'first_line'}->{'string'}
                ? $class->{'positions'}->{'vertical_top'}
                : $class->{'positions'}->{'vertical_bottom'},
            }

        );
    }

    return encode_base64( $class->{'image'}->png );

}

1;

