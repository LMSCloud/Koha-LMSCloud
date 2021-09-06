#!/usr/bin/perl
#
# Find copyright and license problems in Koha source files. At this
# time it only looks for references to the old FSF address in GPLv2
# license notices, but it might in the future be extended to look for
# other things, too.
#
# Copyright 2010 Catalyst IT Ltd
# Copyright 2020 Koha Development Team
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

use Modern::Perl;
use Test::More;

use File::Spec;
use File::Find;

my @files;
sub wanted {
    my $name = $File::Find::name;
    push @files, $name
        unless $name =~ /\/(\.git|koha-tmpl|node_modules|swagger-ui)(\/.*)?$/ ||
               $name =~ /\.(gif|jpg|odt|ogg|pdf|png|po|psd|svg|swf|zip|patch)$/ ||
               $name =~ m[(xt/find-license-problems|xt/fix-old-fsf-address|misc/translator/po2json)] ||
               ! -f $name;
}

find({ wanted => \&wanted, no_chdir => 1 }, File::Spec->curdir());

foreach my $name (@files) {
    open( my $fh, '<', $name ) || die "cannot open file $name $!";
    my ( $hascopyright, $hasgpl, $hasv3, $hasorlater, $haslinktolicense,
        $hasfranklinst, $is_not_us ) = (0)x7;
    while ( my $line = <$fh> ) {
        $hascopyright = 1 if ( $line =~ /^(#|--)?\s*Copyright.*\d\d/ );
        $hasgpl       = 1 if ( $line =~ /GNU General Public License/ );
        $hasv3        = 1 if ( $line =~ /either version 3/ );
        $hasorlater   = 1
          if ( $line =~ /any later version/
            || $line =~ /at your option/ );
        $haslinktolicense = 1 if $line =~ m|http://www\.gnu\.org/licenses|;
        $hasfranklinst    = 1 if ( $line =~ /51 Franklin Street/ );
        $is_not_us        = 1 if $line =~ m|This file is part of the Zebra server|;
    }
    close $fh;
    next unless $hascopyright;
    next if $is_not_us;
    is(    $hasgpl
        && $hasv3
        && $hasorlater
        && $haslinktolicense
        && !$hasfranklinst,  1 ) or diag(sprintf "File %s has wrong copyright: hasgpl=%s, hasv3=%s, hasorlater=%s, haslinktolicense=%s, hasfranklinst=%s", $name, $hasgpl, $hasv3, $hasorlater, $haslinktolicense, $hasfranklinst);
}
done_testing;
