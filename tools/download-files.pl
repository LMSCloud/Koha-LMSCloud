#!/usr/bin/perl

# Copyright 2016 LMSCLoud GmbH
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
use CGI qw ( -utf8 );
use C4::Context;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Branch;
use Koha::Libraries;
use Koha::DateUtils;
use POSIX qw( strftime );
use File::stat;
use File::Spec;

our $input = new CGI;
my $dbh = C4::Context->dbh;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/download-files.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'download_batchprint_files' },
        debug           => 1,
    }
);


my $branch = $input->param('branch');
$branch =
    defined $branch                                                    ? $branch
  : C4::Context->preference('DefaultToLoggedInLibraryOverdueTriggers') ? C4::Branch::mybranch()
  : Koha::Libraries->search->count() == 1                              ? undef
  :                                                                      undef;
$branch ||= q{};
$branch = q{} if $branch eq 'NO_LIBRARY_SET';

my $outputdir = C4::Context->config('outputdownloaddir') | '';
$outputdir = File::Spec->catpath( "", $outputdir, "batchprint" );

my $op = $input->param('op');
$op ||= q{};

if ( $op eq 'download' ) {
    my $content;
    my $filename = $input->param('filename');
    my $fullname = File::Spec->catfile( $outputdir, $filename);
    {
        local $/ = undef;
	open(my $fh, "<:encoding(UTF-8)", $fullname);
	$content = <$fh>;
	close $fh;
    }
    if ( $content eq '') {
	$content = "<html><head><title>No content</title></head><body>The requested file $filename has no content.</body></html>";
    }
    output_html_with_http_headers $input, $cookie, $content;
    exit 0;
}

my $files = {};
if ( -e "$outputdir") {
	opendir(my $dh, $outputdir);
	while (my $filename = readdir $dh) {
		my $fullname = File::Spec->catfile( $outputdir, $filename);
		if ( -f $fullname && -r $fullname ) {
			my $stat_epoch = stat($fullname)->mtime;
			my $sortdate = strftime('%Y-%m-%d', localtime( $stat_epoch ) );
                        my $formatdate = output_pref({dt => dt_from_string( $sortdate ), dateonly => 1 });
                        if (! exists($files->{$formatdate}) ) {
                            $files->{$formatdate} = { sortdate => $sortdate, files => []};
                        }
                        push @{$files->{$formatdate}->{files}}, $filename;
		}
	}
	closedir $dh;
}

my @dirlist;
foreach my $date (sort {$files->{$b}->{sortdate} cmp $files->{$a}->{sortdate}} keys %$files) {
    push @dirlist, { displaydate => $date, sortdate => $files->{$date}->{sortdate}, files => [] };
    my $index = $#dirlist;
    foreach my $file ( sort { $a cmp $b } @{$files->{$date}->{files}} ) {
            push @{$dirlist[$index]->{files}}, $file;
    }
}


########################################
#  Set template paramater
########################################
$template->param(
                        dirlist => \@dirlist,
                        branch => $branch,
);


output_html_with_http_headers $input, $cookie, $template->output;