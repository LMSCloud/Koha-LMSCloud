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


=head1 opac-browser-asb-generic.pl

The script is used to read a classification values of the browser table 
with a generic ASB-like classification with . 

=cut

use strict;
use warnings;

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use CGI qw ( -utf8 );

my $query = new CGI;

my $dbh = C4::Context->dbh;

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-browser-asb-generic.tt",
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
	my @level_entries_loop;
    my @level_folder_loop;
    my @level_loop;
    my @hierarchy_loop;
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE BINARY parent = ? ORDER BY description");
    $sth->execute($filter);
    
    while (my $line = $sth->fetchrow_hashref) {
        push @level_entries_loop, $line if $line->{endnode};
        push @level_folder_loop, $line if !$line->{endnode};
        push @level_loop, $line;
    }
    
    my $myentry;
    $sth = $dbh->prepare("SELECT * FROM browser WHERE BINARY classification = ?");
    $sth->execute($filter);
    while (my $line = $sth->fetchrow_hashref) {
        $myentry = $line;
        last;
    }

    $sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ?");
    my $val = $filter;
    my $maxloop = 100;
    while ( length($val)>0 && $maxloop > 0 ) {
        $maxloop--;
        $sth->execute($val);
        my $line = $sth->fetchrow_hashref;
        if ( $line ) {
            $val = $line->{'parent'};
            unshift @hierarchy_loop, $line;
            last if ( $line->{'level'} eq '1' );
        }
        else {
            $val = '';
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
	my @level_entries_loop;
    my @level_folder_loop;
    my @level_loop;
    
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level = 1 ORDER BY description");
    $sth->execute();
    while (my $line = $sth->fetchrow_hashref) {
        push @level_entries_loop, $line if $line->{endnode};
        push @level_folder_loop, $line if !$line->{endnode};
        push @level_loop, $line;
    }
    $template->param(
				LEVEL_LOOP => \@level_loop,
                LEVEL_ENTRIES_LOOP => \@level_entries_loop,
                LEVEL_FOLDER_LOOP => \@level_folder_loop,
				LEVEL => 1
			);
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
