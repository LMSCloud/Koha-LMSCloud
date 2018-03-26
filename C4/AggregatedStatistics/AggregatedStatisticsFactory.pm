package C4::AggregatedStatistics::AggregatedStatisticsFactory;

use strict;
use warnings;
use Data::Dumper;

use C4::AggregatedStatistics::DBS;
#use C4::AggregatedStatistics::TEST1Class;    # for test only
#use C4::AggregatedStatistics::TEST2Class;    # for test only



my $debug = 1;


# build array of aggregated statistics types (currently this is 'DBS' only; can be extended in the future, even by "select distinct type from aggregated_statistics" etc.)
my $statisticstypesdesignations = [
    { 'type' => 'DBS', 'designation' => 'Deutsche Bibliotheksstatistik' },
# for test only:    { 'type' => 'TEST1', 'designation' => 'Statistiktyp TEST1' },
# for test only:    { 'type' => 'TEST2', 'designation' => 'Statistiktyp TEST2' }
];
    
# lists type names of aggregated statistics that are supported (these are used as values for database table field aggregated_statistics.type)
sub getAggregatedStatisticsTypes {
    my ($class) = @_;

    my @statisticstypeloop = ();
    foreach my $statisticstypesdesignation ( @{$statisticstypesdesignations} ) {
        push @statisticstypeloop, $statisticstypesdesignation->{'type'};   
print STDERR "AggregatedStatisticsFactory::getAggregatedStatisticsTypes pushed type:",$statisticstypesdesignation->{'type'},":\n" if $debug;
    }

    return \@statisticstypeloop;
}

sub getAggregatedStatisticsTypeDesignation {
    my ($class, $statisticstype) = @_;
    my $designation = 'not defined';   
print STDERR "AggregatedStatisticsFactory::getAggregatedStatisticsTypeDesignation statisticstype:",$statisticstype,":\n" if $debug;

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
print STDERR "AggregatedStatisticsFactory::getAggregatedStatisticsClass agstype:$agstype: Dumper(input):",Dumper($input),":\n" if $debug;


    if ( $agstype eq 'DBS' ) {
        $newObject = C4::AggregatedStatistics::DBS->new($input,$class->getAggregatedStatisticsTypeDesignation('DBS'));
#    } elsif ( $agstype eq 'TEST1' ) {    # for test only
#        $newObject = C4::AggregatedStatistics::TEST1Class->new($input,$class->getAggregatedStatisticsTypeDesignation('TEST1'));
#    } elsif ( $agstype eq 'TEST2' ) {    # for test only
#        $newObject = C4::AggregatedStatistics::TEST2Class->new($input,$class->getAggregatedStatisticsTypeDesignation('TEST2'));
    }

    return $newObject;
}

1;
