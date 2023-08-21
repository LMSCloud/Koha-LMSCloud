#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );

use Koha::Script;
use C4::Biblio qw( DelBiblio );

my $help;
GetOptions(
    'h|help' => \$help,
);

pod2usage(1) if $help or not @ARGV;

for my $file ( @ARGV ) {
    say "Find biblionumber in file $file";
    my $fh;
    open($fh, '<', $file) or say "Error: '$file' $!" and next;

    while ( <$fh> ) {
        my $biblionumber = $_;
        $biblionumber =~ s/$1/\n/g if $biblionumber =~ m/(\r\n?|\n\r?)/;
        chomp $biblionumber;
        my $dbh = C4::Context->dbh;
        next if not $biblionumber =~ /^\d*$/;
        print "Delete biblionumber $biblionumber ";
        my $error;
        eval {
            $error = DelBiblio $biblionumber;
        };
        if ( $@ or $error) {
            say "KO $@ ($! | $error)";
        } else {
            say "OK";
        }
    }
}

exit(0);

__END__

=head1 NAME

batchdeletebiblios.pl

=head1 SYNOPSIS

./batchdeletebiblio.pl file1 [file2 ... filen]

This script batch deletes biblios which contain a biblionumber present in file passed in parameter.
If one biblio has items, it is not deleted.

=head1 OPTIONS

=over 8

=item B<-h|--help>

prints this help message

=back

=head1 AUTHOR

Jonathan Druart <jonathan.druart@biblibre.com>

=head1 COPYRIGHT

Copyright 2012 BibLibre

=head1 LICENSE

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Koha is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 DISCLAIMER OF WARRANTY

Koha is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=cut
