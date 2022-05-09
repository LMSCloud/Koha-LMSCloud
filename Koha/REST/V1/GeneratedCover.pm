package Koha::REST::V1::GeneratedCover;

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
use utf8;

use C4::CoverGen;

use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::Items - Koha REST API for handling items (V1)

=head1 API

=head2 Methods

=cut

=head3 get

Controller function generates Covers from parameters and returns data urls.

=cut

sub flat(@) {
    return map { ref eq 'ARRAY' ? @$_ : $_ } @_;
}
use constant {
    FONT      => 'DejaVuSans',
    FONT_PATH => '/usr/share/fonts/truetype/dejavu/',
    WIDTH     => 400,
    HEIGHT    => 480,
    FONTSIZE  => 28,
    PADDING   => 20,
};

sub get {
    my $c           = shift->openapi->valid_input or return;
    my $first_line  = $c->validation->param('author');
    my $second_line = $c->validation->param('title');

    try {
        my $generated_cover_image_source = C4::CoverGen::render_image(
            (   first_line  => $first_line,
                second_line => $second_line,
                font        => FONT,
                font_path   => FONT_PATH,
                width       => WIDTH,
                height      => HEIGHT,
                fontsize    => FONTSIZE,
                padding     => PADDING,
            ),
        );

        if ( !$generated_cover_image_source ) {
            return $c->render(
                status  => 404,
                openapi => { error => 'No cover image could be generated' },
            );
        }

        return $c->render(
            status  => 200,
            openapi => "data:image/png;base64,$generated_cover_image_source"
        );
    }
    catch {
        $c->unhandled_exception($_);
    };

    return;
}

1;
