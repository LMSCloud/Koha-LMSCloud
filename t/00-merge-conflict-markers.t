# Copyright 2010 Galen Charlton
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

use Test::More tests => 1;
use File::Spec;
use File::Find;
use IO::File;

my @failures;
find({
    bydepth => 1,
    no_chdir => 1,
    wanted => sub {
        my $file = $_;

        return if $file =~ /\.(ico|jpg|gif|ogg|pdf|png|psd|swf|zip|.*\~)$/;
        return unless -f $file;

        my @name_parts = File::Spec->splitpath($file);
        my %dirs = map { $_ => 1 } File::Spec->splitdir($name_parts[1]);
        return if exists $dirs{'.git'};

        my $fh = IO::File->new($file, 'r');
        my $marker_found = 0;
        while (my $line = <$fh>) {
            # could check for ^=====, but that's often used in text files
            $marker_found++ if $line =~ m|^<<<<<<|;
            $marker_found++ if $line =~ m|^>>>>>>|;
            last if $marker_found;
        }
        close $fh;
        push @failures, $file if $marker_found;
},
}, File::Spec->curdir());

is( @failures, 0, 'Files should not contain merge markers' . ( @failures ? ( ' (' . join( ', ', @failures ) . ' )' ) : '' ) );
