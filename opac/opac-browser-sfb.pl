#!/usr/bin/perl

# Copyright 2017-2018 LMSCloud GmbH
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


=head1 opac-browser-sfb.pl

The script is used to read a classification values of the browser table if used to store
classification values of the German SfB (Systematik for Bibliotheken). Supporting the SfB
requires additional indexes assuming that the classification values are stored in the 852$a
fields. Additionally its assumed that parts of the classification are split into 3 values:
852$k: prefix value that is used to specify a collection like childrens nonfiction, adults fiction and so on
852$h: SfB classification group like Bio (Biology) or HW (Hauswirtschaft)
852$n: numerical value of the SfB classifcation

A characteristic of the SfB is the that topics of a SfB group may span numeric ranges like 
the topic Ecology spans from Bio 329 to Bio 582. Supporting a classifcation browser for the SfB 
required to add the new fields prefix, classval, startrange, endrange, parent and exclude to 
the browser table which are likely helpful to support other types of classifications as well.
Parent is used to link to the parent classification value. Exclude can contain search extensions
that are used to search the titles that belong to a classification group.

Here is the complete browser table definition what is reuired to support a SfB classification
browser.

+----------------+---------------+------+-----+---------+-------+
| Field          | Type          | Null | Key | Default | Extra |
+----------------+---------------+------+-----+---------+-------+
| level          | int(11)       | NO   |     | NULL    |       |
| classification | varchar(255)  | YES  |     | NULL    |       |
| description    | varchar(255)  | NO   |     | NULL    |       |
| number         | bigint(20)    | NO   |     | NULL    |       |
| endnode        | tinyint(4)    | NO   |     | NULL    |       |
| prefix         | varchar(40)   | YES  |     | NULL    |       |
| classval       | varchar(40)   | YES  |     | NULL    |       |
| startrange     | varchar(20)   | YES  |     | NULL    |       |
| endrange       | varchar(20)   | YES  |     | NULL    |       |
| exclude        | varchar(1024) | YES  |     | NULL    |       |
| parent         | varchar(255)  | YES  |     | NULL    |       |
+----------------+---------------+------+-----+---------+-------+

Filling the browser table with the values that represent the systematic collection structure of a 
library is very specific for a library. Therefor no standard script is provided. 

Using the SfB requires to create additional indexes on the 3 value parts: 852$k, 852$h, 852$n:

/etc/zebradb/marc_defs/marc21/biblios/record.abs:
melm 852$k      SystematikPrefix:w,SystematikPrefix:p
melm 852$h      SystematikClassPart:w,SystematikClassPart:p
melm 852$j      SystematikNumPart:n,SystematikNumPart:w,SystematikNumPart:p

/etc/zebradb/biblios/etc/bib1.att:
att 1235    SystematikPrefix
att 1236    SystematikClassPart
att 1237    SystematikNumPart

/etc/zebradb/ccl.properties
SystematikPrefix 1=1235
sysp SystematikPrefix
SystematikClassPart 1=1236
sysc SystematikClassPart
SystematikNumPart 1=1237 r=r
sysn SystematikNumPart

/etc/zebradb/marc_defs/marc21/biblios/biblio-koha-indexdefs.xml:
  <!--record.abs addded line by roger: melm 852$k      SystematikPrefix:w,SystematikPrefix:p-->
  <index_subfields tag="852" subfields="k">
    <target_index>SystematikPrefix:w</target_index>
    <target_index>SystematikPrefix:p</target_index>
  </index_subfields>
  <!--record.abs addded line by roger: melm 852$h      SystematikClassPart:w,SystematikClassPart:p-->
  <index_subfields tag="852" subfields="h">
    <target_index>SystematikClassPart:w</target_index>
    <target_index>SystematikClassPart:p</target_index>
  </index_subfields>
  <!--record.abs addded line by roger: melm 852$j      SystematikNumPart:n,SystematikNumPart:w,SystematikNumPart:p-->
  <index_subfields tag="852" subfields="j">
    <target_index>SystematikNumPart:n</target_index>
    <target_index>SystematikNumPart:w</target_index>
    <target_index>SystematikNumPart:p</target_index>
  </index_subfields>
  
C4/Search.pm:
Add sysc, sysn and sysp as available index names.

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
        template_name   => "opac-browser-sfb.tt",
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
my ($countEntries,$countFolders,$youthcount,$adultcount,$childcount,$musiccount,$levelEntries)=(0,0,0,0,0,0,0);

$filter = '' unless defined $filter;
$level++; # the level passed is the level of the PREVIOUS list, not the current one. Thus the ++

# build this level loop
my $sth;


my @level_loop;
my @level_entries_loop;
my @level_folder_loop;
my @youth_loop;
my @child_loop;
my @adult_loop;
my @music_loop;
my $myentry;

my $i=0;

if ( $filter ne '' ) {
     $sth = $dbh->prepare("SELECT * FROM browser WHERE parent = ? ORDER BY prefix, classval, startrange, description");
    $sth->execute($filter);
    
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        if ( defined($line->{'classification'}) ) {
            $line->{'classification'} =~ s/^[CZMNYS]:\s*//;
        }
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
        $line->{'classification'} =~ s/^[CZMNYS]:\s*// if ( defined($line->{'classification'}) );
        $line->{'search'} = createSearchString($line);
        $myentry = $line;
    }
}

if ($level == 1) {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND classification rlike '^C[:]' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[CZMNYS]:\s*// if ( defined($line->{'classification'}) );
        $line->{'search'} = createSearchString($line);
        push @child_loop, $line;
        $childcount++;
    }
	
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND classification rlike '^Y[:]' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[CZMNYS]:\s*// if ( defined($line->{'classification'}) );
        $line->{'search'} = createSearchString($line);
        push @youth_loop, $line;
        $youthcount++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND classification rlike '^S[:]' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[CZMNYS]:\s*// if ( defined($line->{'classification'}) );
        $line->{'search'} = createSearchString($line);
        push @adult_loop, $line;
        $adultcount++;
    }
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level=1 AND classification rlike '^N[:]' ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[CZMNYS]:\s*// if ( defined($line->{'classification'}) );
        $line->{'search'} = createSearchString($line);
        push @music_loop, $line;
        $musiccount++;
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
    my %washere;
    $sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ? ORDER BY prefix, classval, startrange, description");
    my $val = $filter;
    while (length($val)>0) {
        $sth->execute($val);
        my $line = $sth->fetchrow_hashref;
        if ( $line ) {
            $val = $line->{'parent'};
            last if ( exists($washere{$val}) );
            $line->{'search'} = createSearchString($line);
            unshift @hierarchy_loop, $line;
            last if ( $line->{'level'} eq '1' );
            $washere{$val} = 1;
        }
        else {
            last;
        }
    }
    $have_hierarchy = 1 if @hierarchy_loop;
}

$template->param(
    LEVEL_LOOP => \@level_loop,
    LEVEL_ENTRIES_LOOP => \@level_entries_loop,
    LEVEL_FOLDER_LOOP => \@level_folder_loop,
    YOUTH_LOOP => \@youth_loop,
    CHILD_LOOP => \@child_loop,
    ADULT_LOOP => \@adult_loop,
    MUSIC_LOOP => \@music_loop,
    HIERARCHY_LOOP => \@hierarchy_loop,
    ENTRY_COUNT => $countEntries,
    FOLDER_COUNT => $countFolders,
    YOUTH_COUNT => $youthcount,
    CHILD_COUNT => $childcount,
    ADULT_COUNT => $adultcount,
    MUSIC_COUNT => $musiccount,
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
    
    if ( $class->{prefix} && $class->{prefix} eq 'JUGMUS' ) {
        if ( $class->{level} && $class->{level} == 1 ) {
            $search .= 'su:"Jugend Musiziert" and su,rtrn:Grad';
        }
        elsif ( $class->{level} && $class->{level} =~ /^(3|4)$/ && $class->{classval} ) {
            $search .= 'su:"Jugend Musiziert ' . $class->{classval} . '"';
        }
        return $search;
    }
    
    if ( $class->{prefix} && $class->{prefix} eq 'NOTEN' && $class->{classification} ) {
        my $sval = $class->{classification};
        $sval =~ s/^(NOTEN \/ [A-Y])([^O]?)/$1.'O'.($2 ? $2 : '')/e;
        $search .= 'sys,phr,ext,rtrn:"' . $class->{classification} . '"';
        $search .= ' or sys,phr,ext,rtrn:"' . $sval . '"' if ( $sval ne $class->{classification});
        return $search;
    }
    if ( $class->{prefix} && $class->{prefix} eq 'MUSIK' && $class->{classification} ) {
        $search .= 'sys,phr,ext,rtrn:"' . $class->{classification} . '"';
        return $search;
    }
    
    if ( $class->{classification} =~ /,[0-9]$/ ) {
        $search .= 'sys,phr,ext,rtrn:"' . $class->{classification} . '"';
        return $search;
    }
    if ( $class->{prefix} ) {
        $search .= ' and ' if ( $search ne '' );
        $search .= 'sysp,phr,ext,rtrn:"' . $class->{prefix} . '"';
    }
    
    if ( $class->{classval} ) {
        $search .= ' and ' if ( $search ne '' );
        $search .= 'sysc:"' . $class->{classval} . '"';
    }
    
    if ( $class->{startrange} && $class->{endrange} ) {
        $search .= ' and ' if ( $search ne '' );
        $search .= 'sysn,st-numeric,ge:"' . $class->{startrange} . '" and sysn,st-numeric,le:"' . $class->{endrange}. '"';
    }
    elsif ( $class->{startrange} ) {
        $search .= ' and ' if ( $search ne '' );
        $search .= 'sysn,st-numeric:"' . $class->{startrange}. '"';
    }
    if ( $class->{exclude} ) {
        $search .= $class->{exclude};
    }
    return $search;
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
