#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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


=head1 opac-browser.pl

TODO :: Description here

=cut

use strict;
use warnings;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Biblio;
use C4::Koha;       # use getitemtypeinfo

my $query = new CGI;

my $dbh = C4::Context->dbh;

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-browser-asb.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
        debug           => 1,
    }
);

# the level of browser to display
my $level = $query->param('level') || 0;
my $filter = $query->param('filter');
my ($countEntries,$countFolders,$mediacount,$childcount)=(0,0,0);

$filter = '' unless defined $filter;
$level++; # the level passed is the level of the PREVIOUS list, not the current one. Thus the ++

# build this level loop
my $sth;

if ( $level == 2 && $filter =~ /^[BCD]$/ ) {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification NOT rlike '^(CD|DVD|BD)' AND classification like ? ORDER BY description");
	$sth->execute($level,$filter."%");
}
else {
	if ( $level > 1) {
		$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification like BINARY ? ORDER BY description");
		$sth->execute($level,$filter."%");
	}
	else {
		$sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND classification rlike '^[A-Z]' AND classification NOT IN ('CD','DVD','BD') ORDER BY description");
		$sth->execute();
	}
}

my @level_loop;
my @level_entries_loop;
my @level_folder_loop;
my @media_loop;
my @child_loop;
my $myentry;

my $i=0;
while (my $line = $sth->fetchrow_hashref) {
    push @level_entries_loop, $line if $line->{endnode};
    $countEntries++ if $line->{endnode};
    push @level_folder_loop, $line if !$line->{endnode};
    $countFolders++ if !$line->{endnode};
    push @level_loop, $line;
}

if ( $filter ne '' ) {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ? ");
	$sth->execute($filter);
	while (my $line = $sth->fetchrow_hashref) {
	    $myentry = $line;
	}
}

if ($level == 1) {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND classification IN ('CD','DVD','BD') ORDER BY classification");
	$sth->execute();
	while (my $line = $sth->fetchrow_hashref) {
	    push @media_loop, $line;
	    $mediacount++;
	}
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND classification rlike '^[0-9]' ORDER BY classification");
	$sth->execute();
	while (my $line = $sth->fetchrow_hashref) {
	    push @child_loop, $line;
	    $childcount;
	}	
}

my $have_hierarchy = 0;

# now rebuild hierarchy loop
# $filter =~ s/\.//g;
my @hierarchy_loop;
if ($filter eq '' and $level == 1) {
    # we're starting from the top
    $have_hierarchy = 1 if @level_loop;
} 
else {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ?");
    my $val = $filter;
    	while (length($val)>0) {
    		if ( $val =~ /[[:alnum:]]$/ ) {
			$sth->execute($val);
        		my $line = $sth->fetchrow_hashref;
        		if ( $line ) {
        			unshift @hierarchy_loop, $line;
        		}
		}
		# now remove the last character or the complete value if it is a BD, DVD or CD
		if ( $val =~ /^(CD|BD|DVD)$/ ) {
			$val = '';
		} else {
			$val =~ s/.$//;
		}
	}
    #for (my $i=1;$i <=length($filter);$i++) {
    #    $sth->execute(substr($filter,0,$i));
    #    my $line = $sth->fetchrow_hashref;
    #    push @hierarchy_loop,$line;
    #}
    $have_hierarchy = 1 if @hierarchy_loop;
}

$template->param(
    LEVEL_LOOP => \@level_loop,
    LEVEL_ENTRIES_LOOP => \@level_entries_loop,
    LEVEL_FOLDER_LOOP => \@level_folder_loop,
    MEDIA_LOOP => \@media_loop,
    CHILD_LOOP => \@child_loop,
    HIERARCHY_LOOP => \@hierarchy_loop,
    ENTRY_COUNT => $countEntries,
    FOLDER_COUNT => $countFolders,
    MEDIA_COUNT => $mediacount,
    CHILD_COUNT => $childcount,
    LEVEL => $level,
    have_hierarchy => $have_hierarchy,
    MYENTRY => $myentry
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
