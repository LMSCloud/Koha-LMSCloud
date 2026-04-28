#!/usr/bin/perl

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

use GD::Image;
use GD::Text::Align;
use MIME::Base64;

use C4::CoverGen;

use Test::More tests => 5;
use Data::Dumper;
use Try::Tiny;

BEGIN {
    use_ok('C4::CoverGen');
    use_ok('GD::Image');
    use_ok('GD::Text::Align');
    use_ok('MIME::Base64');
}

subtest 'get_string_width_based_on_params() tests' => sub {
    my $image = GD::Image->new( 400, 480 );
    $image->colorAllocate( 244, 244, 244 );
    my $font_color = $image->colorAllocate( 0, 0, 0 );

    my $align = GD::Text::Align->new(
        $image,
        valign => 'center',
        halign => 'center',
        color  => $font_color,
    );

    isa_ok( $align, 'GD::Text::Align' );

    my $test_cases = {
        basic => {
            image    => $align,
            font     => q{DejaVuSans},
            fontsize => 28,
            string   => q{test},
        },
        long => {
            image    => $align,
            font     => q{DejaVuSans},
            fontsize => 28,
            string   => q{test} x 30,
        },
        missing_image => {
            font     => q{DejaVuSans},
            fontsize => 28,
            string   => q{test},
        }
    };

    my $string_basic_width
        = C4::CoverGen::get_string_width_based_on_params(
        $test_cases->{'basic'} );

    ok( $string_basic_width == 24, 'basic string produces correct width' );

    my $string_long_width
        = C4::CoverGen::get_string_width_based_on_params(
        $test_cases->{'long'} );

    ok( $string_long_width == 720, 'long string produces correct width' );

    try {
        my $string_missing_image
            = C4::CoverGen::get_string_width_based_on_params(
            $test_cases->{'missing_image'} );
        ok( 0, 'image parameter is set' );
    }
    catch {
        is( ref($_),
            'Koha::Exceptions::MissingParameter',
            'image parameter is undefined'
        );
    };

};

# subtest 'trim_string() tests' => sub {

# };

