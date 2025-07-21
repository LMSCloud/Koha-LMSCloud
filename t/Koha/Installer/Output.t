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

use Modern::Perl;

use Test::More tests => 4;

use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

# Set up a temporary file for testing output
my $temp_file = "test_output.log";
open my $fh, '>', $temp_file or die "Cannot open $temp_file: $!";

# Redirect output to the temporary file
my $old_fh = select $fh;

# Test the output functions
say_warning( $fh, "Testing warning message" );
say_failure( $fh, "Testing failure message" );
say_success( $fh, "Testing success message" );
say_info( $fh, "Testing info message" );

# Restore the previous output filehandle
select $old_fh;

# Close the temporary file
close $fh;

# Read the contents of the temporary file for testing
open my $test_fh, '<', $temp_file or die "Cannot open $temp_file: $!";
my @lines = <$test_fh>;
close $test_fh;

# Test the output content
like( $lines[0], qr/\e\[\d+mTesting warning message\e\[0m/, "Warning message output with ANSI color code" );
like( $lines[1], qr/\e\[\d+mTesting failure message\e\[0m/, "Failure message output with ANSI color code" );
like( $lines[2], qr/\e\[\d+mTesting success message\e\[0m/, "Success message output with ANSI color code" );
like( $lines[3], qr/\e\[\d+mTesting info message\e\[0m/,    "Info message output with ANSI color code" );

# Remove the temporary file
unlink $temp_file;
