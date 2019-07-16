#!/usr/bin/perl

# Copyright 2018 LMSCloud GmbH
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


=head1 opac-browser-kab.pl

The script is used to read a classification values of the browser table if used to store
classification values of the German KAB (Klassifikation für Allgemeinbibliothekn). 

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
        template_name   => "opac-browser-kab.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
        debug           => 1,
    }
);

# the level of browser to display
my $level = $query->param('level') || 0;
my $filter = $query->param('filter');
my $prefix = $query->param('prefixed');
my ($countEntries,$countFolders,$youthcount,$adultcount,$child07count,$child10count,$musiccount,$gamescount,$regioncount,$levelEntries)=(0,0,0,0,0,0,0,0,0,0);

$filter = '' unless defined $filter;
$level++; # the level passed is the level of the PREVIOUS list, not the current one. Thus the ++

# build this level loop
my $sth;


my @level_loop;
my @level_entries_loop;
my @level_folder_loop;
my @youth_loop;
my @child07_loop;
my @child10_loop;
my @adult_loop;
my @music_loop;
my @games_loop;
my @region_loop;
my $myentry;

my $i=0;

if ( $filter ne '' ) {
     $sth = $dbh->prepare("SELECT * FROM browser WHERE parent = ? ORDER BY description");
    $sth->execute($filter);
    
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @level_entries_loop, $line if $line->{endnode};
        $countEntries++ if $line->{endnode};
        push @level_folder_loop, $line if !$line->{endnode};
        $countFolders++ if !$line->{endnode};
        push @level_loop, $line;
        $levelEntries++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ?");
    $sth->execute($filter);
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        $myentry = $line;
    }
}

if ($level == 1) {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND prefix = 'CHILD07' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @child07_loop, $line;
        $child07count++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND prefix = 'CHILD10' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @child10_loop, $line;
        $child10count++;
    }
	
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND prefix = 'YOUTH' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @youth_loop, $line;
        $youthcount++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND prefix = 'ADULT' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @adult_loop, $line;
        $adultcount++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=2 AND prefix = 'MUSIC' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @music_loop, $line;
        $musiccount++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=2 AND prefix = 'GAME' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @games_loop, $line;
        $gamescount++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND prefix = 'REGION' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @region_loop, $line;
        $regioncount++;
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
    my $maxloop = 100;
    while ( length($val)>0 && $maxloop > 0 ) {
        $maxloop--;
        $sth->execute($val);
        my $line = $sth->fetchrow_hashref;
        if ( $line ) {
            $val = $line->{'parent'};
            $line->{'search'} = createSearchString($line);
            unshift @hierarchy_loop, $line;
            last if ( $line->{'level'} eq '1' );
        }
        else {
            $val = '';
        }
    }
    $have_hierarchy = 1 if @hierarchy_loop;
}

$template->param(
    LEVEL_LOOP => \@level_loop,
    LEVEL_ENTRIES_LOOP => \@level_entries_loop,
    LEVEL_FOLDER_LOOP => \@level_folder_loop,
    YOUTH_LOOP => \@youth_loop,
    CHILD07_LOOP => \@child07_loop,
    CHILD10_LOOP => \@child10_loop,
    ADULT_LOOP => \@adult_loop,
    MUSIC_LOOP => \@music_loop,
    GAMES_LOOP => \@games_loop,
    REGION_LOOP => \@region_loop,
    HIERARCHY_LOOP => \@hierarchy_loop,
    ENTRY_COUNT => $countEntries,
    FOLDER_COUNT => $countFolders,
    YOUTH_COUNT => $youthcount,
    CHILD07_COUNT => $child07count,
    CHILD10_COUNT => $child10count,
    ADULT_COUNT => $adultcount,
    MUSIC_COUNT => $musiccount,
    GAMES_COUNT => $gamescount,
    REGION_COUNT => $regioncount,
    LEVEL_COUNT => $levelEntries,
    LOOP_COUNT => scalar(@level_loop),
    LEVEL => $level,
    have_hierarchy => $have_hierarchy,
    MYENTRY => $myentry,
    PREFIXED => $prefix
);

sub createSearchString {
    my $class = shift;
    my $search = '';
    
    if ( $class->{classification} =~ /^I$/ && $class->{prefix} eq 'ADULT' ) {
        $search .= 'sys,ext,first-in-subfield,rtrn:"I 0"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 1"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 2"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 3"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 4"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 5"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 6"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 7"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 8"';
        $search .= ' or sys,ext,first-in-subfield,rtrn:"I 9"';
    }
    elsif ( $class->{classification} ) {
        $search .= 'sys,ext,first-in-subfield,rtrn:"' . $class->{classification} . '"';
    }

    return $search;
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
