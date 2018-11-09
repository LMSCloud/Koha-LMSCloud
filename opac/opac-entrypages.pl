#!/usr/bin/perl

# Copyright 2016-2018 LMSCloud GmbH
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


=head1 opac-entrypages.pl

ToDo

=cut

use strict;
use warnings;

use DateTime;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Biblio;
use C4::Koha;       # use getitemtypeinfo

my $query = new CGI;

my $dbh = C4::Context->dbh;

# open template
my ( $template, $loggedinuser, $cookie, $templatename);

my $enduser = $query->param("interestGroup") || 'A';
my $classlevel = $query->param("classlevel");
my $filter = $query->param("filter");
my $mediafilter = $query->param("mediafilter");
my $medialevel = $query->param("medialevel");
my $newAcquisitionMonthes = $query->param("monthesback") || C4::Context->preference("OpacSelectNewAcquisitionsMonthes") || 12;
my $page = $query->param("page");
my $pagename = '';

my (@ElectronicMedia,@ClassificationTopLevelEntries);


sub getCurrentDateMinusXMonth {
	my ($minusmonth) = @_;
	
	my $dt = DateTime->now;
	$dt->add( months => -$minusmonth );
	return $dt->ymd;
}

my $foundEEntries = 0;
my $firstDateOfNew = getCurrentDateMinusXMonth($newAcquisitionMonthes);

if ( $page ) {
    $templatename = 'opac-entrypages.tt';
    $pagename = 'OpacEntryPage' . $page;    # e.g. OpacEntryPageChild
} else {
    $templatename = "opac-entryadult.tt" if ( $enduser eq 'A' );
    $templatename = "opac-entrychildto9.tt" if ( $enduser eq '9' );
    $templatename = "opac-entrychildfrom9.tt" if ( $enduser eq 'T' );
}

( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => $templatename,
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
        debug           => 1,
    }
);

if ( $enduser eq 'A' ) {
    # select top-level CD-DVD-BD entries of the ASB classification if available
    
    my $sth;
    my $mlevel = 1;
    $mlevel = $medialevel if ( $medialevel );
    
    if ( $mediafilter ) {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification rlike ? ORDER BY classification");
	$sth->execute($mlevel,$mediafilter);
    }
    else {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification IN (?,?,?) ORDER BY classification");
	$sth->execute($mlevel,'CD','DVD','BD');
    }
    while (my $line = $sth->fetchrow_hashref)
    {
	$line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[MCZYS]:\s*// if ( defined($line->{'classification'}) );
        push @ElectronicMedia, $line;
        $foundEEntries++;
    }
}

if ( $enduser eq 'A' ) {
    # select top-level CD-DVD-BD entries of the ASB classification if available
    my $level=1;
    $level = $classlevel if ( $classlevel );
    
    
    my $sth;
    if ( $filter ) {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification rlike ? ORDER BY classification");
	$sth->execute($level,$filter);
    }
    else {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification IN ('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z') ORDER BY description");
	$sth->execute($level);
    }
    
    while (my $line = $sth->fetchrow_hashref)
    {
	$line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[MCZYS]:\s*// if ( defined($line->{'classification'}) );
        push @ClassificationTopLevelEntries, $line;
    }
    $sth->finish;
    
    if (! scalar(@ClassificationTopLevelEntries) ) {
        $sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification NOT REGEXP '^([0-9].*|CD.*|DVD.*)' ORDER BY description");
        $sth->execute($level);
        while (my $line = $sth->fetchrow_hashref)
        {
	    $line->{'browse_classification'} = $line->{'classification'};
            $line->{'classification'} =~ s/^[MCZYS]:\s*// if ( defined($line->{'classification'}) );
            push @ClassificationTopLevelEntries, $line;
	}
    }
}

if ( $enduser eq '9' ) {
    # select top-level CD-DVD-BD entries of the ASB classification if available
    my $level=3;
    $level = $classlevel if ( $classlevel );

    my $sth;
	
    if ( $filter ) {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification rlike ? ORDER BY classification");
	$sth->execute($level,$filter);
    }
    else {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND (classification like ? or classification like ?) ORDER BY description");
	$sth->execute($level,"4.3/%","4.3 %");
    }
    
    while (my $line = $sth->fetchrow_hashref)
    {
	$line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[MCZYS]:\s*// if ( defined($line->{'classification'}) );
        $line->{description} =~ s/^Kindersach[^\s\\]+: //;
        push @ClassificationTopLevelEntries, $line;
    }
    $sth->finish;
	
    if (! scalar(@ClassificationTopLevelEntries) ) {
        $sth->execute($level-1,"4.3%");
        while (my $line = $sth->fetchrow_hashref)
        {
	    $line->{'browse_classification'} = $line->{'classification'};
            $line->{'classification'} =~ s/^[MCZYS]:\s*// if ( defined($line->{'classification'}) );
            push @ClassificationTopLevelEntries, $line;
        }
    }
}

if ( $enduser eq 'T' ) {
    # select top-level CD-DVD-BD entries of the ASB classification if available
    my $level=3;
    $level = $classlevel if ( $classlevel );
    
    my $sth;
    
    if ( $filter ) {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification rlike ? ORDER BY classification");
	$sth->execute($level,$filter);
    }
    else {
	$sth = $dbh->prepare("SELECT * FROM browser WHERE level=? AND classification like ? ORDER BY description");
	$sth->execute($level,"6.%");
    }
    
    while (my $line = $sth->fetchrow_hashref)
    {
	$line->{'browse_classification'} = $line->{'classification'};
        $line->{'classification'} =~ s/^[MCZYS]:\s*// if ( defined($line->{'classification'}) );
        $line->{description} =~ s/^Kindersach[^\s\\]+: //;
        push @ClassificationTopLevelEntries, $line;
    }
    $sth->finish;
    if (! scalar(@ClassificationTopLevelEntries) ) {
        $sth->execute($level,"4.3%");
        while (my $line = $sth->fetchrow_hashref)
        {
	    $line->{'browse_classification'} = $line->{'classification'};
            $line->{'classification'} =~ s/^[MCZYS]:\s*// if ( defined($line->{'classification'}) );
            push @ClassificationTopLevelEntries, $line;
        }
    }
}

$template->param(
	end_user => $enduser,
	electronic_media => \@ElectronicMedia,
	classification_top_level_entries => \@ClassificationTopLevelEntries,
	count_eentries => $foundEEntries,
	first_date_of_new => $firstDateOfNew,
	pagename => $pagename                   # required for template opac-entrypages.tt only
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
