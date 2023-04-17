#!/usr/bin/perl

# Copyright 2023 LMSCloud GmbH
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


=head1 opac-browser-sys-generic.pl

The script is used to read a classification values of the browser table if used to store
classification values of the German KAB (Klassifikation für Allgemeinbibliothekn). 

=cut

use strict;
use warnings;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use Data::Dumper;

my $query = new CGI;

my $dbh = C4::Context->dbh;

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-browser-sys-generic.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
        debug           => 1,
    }
);

# the level of browser to display
my $level = $query->param('level') || 0;
my $filter = $query->param('filter');
my $entries = [];

$filter = '' unless defined $filter;
$level++; # the level passed is the level of the PREVIOUS list, not the current one. Thus the ++

# build this level loop
my $sth;

my $i=0;

if ( $filter ne '' ) {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE parent = ? ORDER BY description");
    $sth->execute($filter);
    
    my @level_entries_loop;
    my @level_folder_loop;
    my @level_loop;
    my @hierarchy_loop;
    
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        push @level_entries_loop, $line if $line->{endnode};
        push @level_folder_loop, $line if !$line->{endnode};
        push @level_loop, $line;
    }
    
    my $myentry;
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ?");
    $sth->execute($filter);
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        $myentry = $line;
    }

    my %washere;
    $sth = $dbh->prepare("SELECT * FROM browser WHERE description = ? ORDER BY description");
    my $val = $filter;
    while ( $val ) {
        $sth->execute($val);
        my $line = $sth->fetchrow_hashref;
        if ( $line ) {
			$line->{'browse_classification'} = $line->{'classification'};
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
    
    $template->param(
			LEVEL_LOOP => \@level_loop,
			LEVEL_ENTRIES_LOOP => \@level_entries_loop,
			LEVEL_FOLDER_LOOP => \@level_folder_loop,
			LEVEL => $level,
			FILTER => $filter,
			HIERARCHY_LOOP => \@hierarchy_loop,
			MYENTRY => $myentry,
		);
}
else {
	my $systree = [];
	my $parents = {};
    $sth = $dbh->prepare("SELECT * FROM browser ORDER BY level, description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'} = createSearchString($line);
        
        my $level = 1;
        $level = $line->{level} if ( $line->{level} ); 
        if ( $level == 1 ) {
			$parents->{$line->{description}} = $line;
			push @$systree, $line;
		}
		else {
			if ( exists($parents->{$line->{parent}}) ) {
				my $parent = $parents->{$line->{parent}};
				if ( ! exists($parent->{childs}) ) {
					$parent->{childs} = [];
				}
				push @{$parent->{childs}}, $line;
				$parents->{$line->{parent} . ' | ' . $line->{description} } = $line;
			}
		}
    }
    $template->param(
				LEVEL_LOOP => $systree,
				LEVEL => $level
			);
}

sub createSearchString {
    my $class = shift;
    my $search = '';
    
    if ( $class->{classification} ) {
        my $searchval = $class->{classification};
        $searchval =~ s/ /\\ /g;
        $search .= 'sys.phrase:"' . $searchval . '"';
    }

    return $search;
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
