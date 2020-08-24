package C4::IssuingStats;

# This file is part of Koha.
#
# Copyright 2020 LMSCloud GmbH
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
use C4::Context;
use DateTime;
use Carp;
use Data::Dumper;
use vars qw(@ISA @EXPORT);

BEGIN {
    require Exporter;
        @ISA    = qw(Exporter);
        @EXPORT = qw(
            GetIssuingStats
        );
}

=head1 NAME

C4::IssuingStats - retrieve issuing statistics of selected biblio numbers

=head1 SYNOPSYS

    my $stats = GetIssuingStats([2842],2,[]);

    # stats may contain a structure like the following
    [
        {
            'biblionumber' => '2842',
            'sumIssues' => 29,
            'issuestats' => [
                {'year' => 2020,'sumIssues' => 11},
                {'year' => 2019,'sumIssues' => 7}
            ],
            'items' => [
                {
                    'itemnumber' => '2517',
                    'sumIssues' => 17,
                    'issuestats' => [
                        {'year' => 2020,'sumIssues' => 6},
                        {'year' => 2019,'sumIssues' => 3}
                    ]
                },
                {
                    'itemnumber' => '2518',
                    'sumIssues' => 12,
                    'issuestats' => [
                        {'year' => 2020,'sumIssues' => 5},
                        {'year' => 2019,'sumIssues' => 4}
                    ]
                }
            ]
        }
    ];

=head1 DESCRIPTION

The module containes the function GetIssuingStats which can be used to 
retrieve issuing statistics data for items of selected biblio record
numbers

=cut

=head2 GetIssuingStats

  $result = GetIssuingStats($biblionumbers,$years,$ignotItemTypes);

Returns issuing statistics data for biblio numbers provided with parameter
$biblionumbers. 

=head3 Arguments

    * $biblionumbers needs to be an array reference of a list if biblionumbers
    * $years specifies the count of years used to calculate the statistics back from the current year. A value of one calculates only the current year.
    * $ignotItemTypes specifies item types to ignore for the statistical calculation

=head3 Returns

    * returns a data structure containing statistical data for bibliopnumbers and items

=cut

sub GetIssuingStats {
    my $biblionumbers = shift;
    my $years         = shift;
    my $ignoreTypes   = shift;
    
    return [] if (! $biblionumbers);
    return [] if (! $years || $years !~ /^[0-9]+$/ || $years <= 0 );
    
    my @seltypes;
    my @selparams;
    my $seladd = '';
    my $result = {};

    my $bibliosel = join(',',@$biblionumbers);
    
    if ( $ignoreTypes && scalar(@$ignoreTypes) ) {
        foreach my $itype (@$ignoreTypes) {
            push @selparams,'?';
            push @seltypes,$itype;
        }
        $seladd = ' AND i.itype NOT IN (' . join(',', @selparams) . ') ';
    }

    my $select = qq{SELECT i.biblionumber AS biblionumber,
                           s.itemnumber AS itemnumber,
                           YEAR(s.datetime) AS year,
                           count(*) AS cnt,
                           YEAR(dateaccessioned) AS yearacc
                    FROM   items i
                           JOIN statistics s ON (s.itemnumber = i.itemnumber)
                    WHERE  s.type in ('issue', 'renew')
                           AND YEAR(s.datetime) > YEAR(DATE_SUB(CURDATE(), INTERVAL $years YEAR))
                           AND i.biblionumber IN ($bibliosel) $seladd
                    GROUP BY i.biblionumber, s.itemnumber, YEAR(s.datetime), YEAR(dateaccessioned)
                    UNION ALL
                    SELECT i.biblionumber AS biblionumber,
                           i.itemnumber AS itemnumber,
                           0 AS year,
                           IFNULL(i.issues,0) + IFNULL(i.renewals,0) AS cnt,
                           YEAR(dateaccessioned)AS yearacc
                    FROM   items i
                    WHERE  i.biblionumber IN ($bibliosel) $seladd
                    ORDER BY 1,2,3};
                    
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($select);

    $sth->execute(@seltypes,@seltypes);

    while (my $stat = $sth->fetchrow_hashref ) {
        if ( $stat->{year} == 0 ) {
            $result->{$stat->{biblionumber}}->{items}->{$stat->{itemnumber}} = { sumIssues => $stat->{cnt}, yearAccession => $stat->{yearacc}, stats => {} };
            $result->{$stat->{biblionumber}}->{sumIssues} += $stat->{cnt};
        } else {
            $result->{$stat->{biblionumber}}->{items}->{$stat->{itemnumber}}->{stats}->{$stat->{year}}->{sumIssues} = $stat->{cnt} + 0;
            $result->{$stat->{biblionumber}}->{stats}->{$stat->{year}}->{sumIssues} += $stat->{cnt} + 0;
        }
    }

    $sth->finish;

    my @years;
    my $currYear = DateTime->now(time_zone => 'local')->year;

    for (my $i=0; $i < $years; $i++) {
        push @years, $currYear-$i;
    }

    # Array to store the reponse JSON
    my $response = [];

    foreach my $biblionumber(sort { $a <=> $b } keys %$result) {
        foreach my $itemnumber(sort { $a <=> $b } keys %{$result->{$biblionumber}->{items}} ) {
            foreach my $year(@years) {
                if ( $year >= $result->{$biblionumber}->{items}->{$itemnumber}->{yearAccession} ) {
                    $result->{$biblionumber}->{items}->{$itemnumber}->{stats}->{$year}->{sumIssues} += 0;
                    $result->{$biblionumber}->{stats}->{$year}->{sumIssues} += 0;
                }
            }
        }
        my $bibresult = { biblionumber => $biblionumber, issuestats => [], sumIssues => $result->{$biblionumber}->{sumIssues}, items => [] };
        foreach my $year(@years) {
            $result->{$biblionumber}->{stats}->{$year}->{sumIssues} += 0;
            push @{$bibresult->{issuestats}}, { 'year' => $year, 'sumIssues' => $result->{$biblionumber}->{stats}->{$year}->{sumIssues} };
        }
        foreach my $itemnumber(sort { $a <=> $b } keys %{$result->{$biblionumber}->{items}} ) {
            my $itemstats = [];
            foreach my $year(@years) {
                $result->{$biblionumber}->{items}->{$itemnumber}->{stats}->{$year}->{sumIssues} += 0;
                push @$itemstats, { 'year' => $year, 'sumIssues' => $result->{$biblionumber}->{items}->{$itemnumber}->{stats}->{$year}->{sumIssues} };
            }
            $result->{$biblionumber}->{items}->{$itemnumber}->{sumIssues} += 0;
            push @{$bibresult->{items}}, { itemnumber => $itemnumber, issuestats => $itemstats, sumIssues => $result->{$biblionumber}->{items}->{$itemnumber}->{sumIssues} };
        }
        push @$response, $bibresult;
    }
    # carp Dumper($response);
    return $response;
}

1;
__END__

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut