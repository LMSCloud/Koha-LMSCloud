package C4::AggregatedStatistics::AggregatedStatisticsFactory;


# Copyright 2018 (C) LMSCLoud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


# This script inserts / updates records in DB tables authorised_values and insertinto_marc_subfield_structure
# that are required for the aggregated statistics type 'DBS'.
# 'DBS' evaluates the field items.coded_location_qualifier in some sql select statements.
use strict;
use warnings;
use Data::Dumper;

use C4::AggregatedStatistics::DBS;
use C4::AggregatedStatistics::VGWort;


my $debug = 1;


# build array of aggregated statistics types (currently this is 'DBS' only; can be extended in the future, even by "select distinct type from aggregated_statistics" etc.)
my $statisticstypesdesignations = [
    { 'type' => 'DBS', 'designation' => 'Deutsche Bibliotheksstatistik' },
    { 'type' => 'VGWort', 'designation' => 'VG-WORT-Export' }
];
    
# lists type names of aggregated statistics that are supported (these are used as values for database table field aggregated_statistics.type)
sub getAggregatedStatisticsTypes {
    my ($class) = @_;

    my @statisticstypeloop = ();
    foreach my $statisticstypesdesignation ( @{$statisticstypesdesignations} ) {
        push @statisticstypeloop, $statisticstypesdesignation->{'type'};   
    }

    return \@statisticstypeloop;
}

sub getAggregatedStatisticsTypeDesignation {
    my ($class, $statisticstype) = @_;
    my $designation = 'not defined';   

    foreach my $statisticstypesdesignation ( @{$statisticstypesdesignations} ) {
        if ( $statisticstypesdesignation->{'type'} eq $statisticstype ) {
            $designation = $statisticstypesdesignation->{'designation'};
        }
    }
    return $designation;
}

# produce an object of the required type $agstype
sub getAggregatedStatisticsClass {
    my ($class, $agstype, $input) = @_;
    my $newObject;    

    if ( $agstype eq 'DBS' ) {
        $newObject = C4::AggregatedStatistics::DBS->new($input,$class->getAggregatedStatisticsTypeDesignation('DBS'));
    } elsif ( $agstype eq 'VGWort' ) {
        $newObject = C4::AggregatedStatistics::VGWort->new($input,$class->getAggregatedStatisticsTypeDesignation('VGWort'));
    }

    return $newObject;
}

1;
