package C4::AggregatedStatistics;

# Copyright 2017 LMSCloud GmbH
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

use utf8;
use Data::Dumper;


use Modern::Perl;
use C4::Context;
use Koha::AggregatedStatistics::AggregatedStatistic;
use Koha::AggregatedStatistics::AggregatedStatistics;
use Koha::AggregatedStatistics::AggregatedStatisticsParameters;
use Koha::AggregatedStatistics::AggregatedStatisticsValues;


use vars qw(@ISA @EXPORT);

BEGIN {
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        &CreateAggregatedStatistics
        &GetAggregatedStatistics
        &DelAggregatedStatistics

        &UpdAggregatedStatisticsParameters
        &GetAggregatedStatisticsParameters

        &UpdAggregatedStatisticsValues
        &GetAggregatedStatisticsValues

        &CalculateAggregatedStatisticsValuesDBS
        &StoreAggregatedStatisticsValues
    );
}

my $debugIt = 1;

=head1 NAME

C4::AggregatedStatistics - Koha functions for dealing with customized statistics

=head1 SYNOPSIS

use C4::AggregatedStatistics;

=head1 DESCRIPTION

The functions in this module deal with creating, calculating, modifying and comparing
customized statistics.

=head1 FUNCTIONS

=head2 FUNCTIONS ABOUT DEFINING AGGREGATED STATISTICS

=head3 CreateAggregatedStatistics

  $aggregatedStatistics = &CreateAggregatedStatistics( { 'type' => 'DBS', 'name' => 'DBS 2017', 'description' => 'Deutsche Bibliotheksstatistik für 2017', 'startdate' => '2017-01-01', 'enddate' => '2017-12-31' } );

Create a new customized statistics for the given type/period combination, or update it if already existing.
Identity is defined by id or by type/name.

B<returns:> AggregatedStatistics object containing the values of the new / updated record from table aggregated_statistics.

=cut

sub CreateAggregatedStatistics {
    my ($param) = @_;
  
    my $selParam;
    my $updParam;
    if ( defined($param->{'id'}) && length($param->{'id'}) > 0 ) {
        $selParam = {
            id => $param->{'id'}
        };
        $updParam = {
            type => $param->{'type'},
            name => $param->{'name'},
            description => $param->{'description'},
            startdate => $param->{'startdate'},
            enddate => $param->{'enddate'}
        };
    } else {
        $selParam = {
            type => $param->{'type'},
            name => $param->{'name'}
        };
        $updParam = {
            description => $param->{'description'},
            startdate => $param->{'startdate'},
            enddate => $param->{'enddate'}
        };
    }
    my $insParam = {
        #id => 0, # AUTO
        type => $param->{'type'},
        name => $param->{'name'},
        description => $param->{'description'},
        startdate => $param->{'startdate'},
        enddate => $param->{'enddate'}
    };
    my $aggregatedStatistics = Koha::AggregatedStatistics::AggregatedStatistics->new();
    my $res = $aggregatedStatistics->upd_or_ins($selParam, $updParam, $insParam);
    
    return $res;
}

#------------------------------------------------------------#

=head3 GetAggregatedStatistics

  $aggregatedStatistics = &GetAggregatedStatistics( { 'type' => 'DBS', 'name' => 'DBS 2017' } );

Read the customer defined statistics header record (i.e. without the connected aggregated_statistics_parameters and aggregated_statistics_values).

=over

=item C<$param> the aggregated statistics may be uniquely identified by primary key param->{'id'} or by param->{'type'} and param->{'name'}

=back

B<returns:> AggregatedStatistics object containing the found records from table aggregated_statistics.

=cut

sub GetAggregatedStatistics {
    my ($param) = @_;
    my $selParam = {};
    my $orderByParam = { order_by => { -desc => 'id' } };

    if ( defined($param->{'id'}) ) {
        $selParam = {
            id => $param->{'id'}
        };
    } else {
        $selParam->{'type'} = $param->{'type'} if defined($param->{'type'});
        $selParam->{'name'} = $param->{'name'} if defined($param->{'name'});
        $selParam->{'startdate'} = $param->{'startdate'} if defined($param->{'startdate'});
        $selParam->{'enddate'} = $param->{'enddate'} if defined($param->{'enddate'});
    }
    my $aggregatedStatistics = Koha::AggregatedStatistics::AggregatedStatistics->new();
    my $res = $aggregatedStatistics->search($selParam, $orderByParam);
    return $res;
}

#------------------------------------------------------------#

=head3 DelAggregatedStatistics

  &DelAggregatedStatistics( { 'id' => 123 } );

Delete the customer defined statistics, including the connected aggregated_statistics_parameters and aggregated_statistics_values.

=over

=item C<$param> the aggregated statistics may be uniquely identified by primary key param->{'id'} or by param->{'type'} and param->{'name'}

=back

=cut

sub DelAggregatedStatistics {
    my ($param) = @_;

    my $aggregatedStatistics = &GetAggregatedStatistics($param);
print STDERR "AggregatedStatistics::DelAggregatedStatistics() read aggregated_statistics records countXXXX:", $aggregatedStatistics->_resultset()+0, ":\n" if $debugIt;
    if ( $aggregatedStatistics->_resultset()+0 == 1 ) {
print STDERR "AggregatedStatistics::DelAggregatedStatistics() read aggregated_statistics record id:", $aggregatedStatistics->_resultset()->first()->get_column('id'), ":\n" if $debugIt;
        my $id = $aggregatedStatistics->_resultset()->first()->get_column('id');
        my $res;

        # delete the linked aggregated_statistics_parameters records
        DelAggregatedStatisticsParameters( { statistics_id => $id } );

        # delete the linked aggregated_statistics_values records
        DelAggregatedStatisticsValues( { statistics_id => $id } );


        # delete the linked aggregated_statistics record (anchor)
        my $selParam = {
            id => $id
        };
print STDERR "AggregatedStatistics::DelAggregatedStatistics() read aggregated_statistics_parameters records by calling Koha::AggregatedStatistics::AggregatedStatistics->new\n" if $debugIt;
        my $aggregatedStatistics = Koha::AggregatedStatistics::AggregatedStatistics->new();
print STDERR "AggregatedStatistics::DelAggregatedStatistics() aggregatedStatistics:", Dumper($aggregatedStatistics), ":\n" if $debugIt;
print STDERR "AggregatedStatistics::DelAggregatedStatistics() read aggregated_statistics records by calling Koha::AggregatedStatistics::AggregatedStatistics->search \nselParam:", Dumper($selParam), ":\n" if $debugIt;
        my $resAS = $aggregatedStatistics->search($selParam);
print STDERR "AggregatedStatistics::DelAggregatedStatistics() read aggregated_statistics records count:", $resAS->_resultset()+0, ":\n" if $debugIt;
print STDERR "AggregatedStatistics::DelAggregatedStatistics() delete aggregated_statistics record by calling resAS->_resultset()->delete_all \n" if $debugIt;
        $res = $resAS->_resultset()->delete_all();
        
    }
}

#------------------------------------------------------------#

=head3 UpdAggregatedStatisticsParameters

  $aggregatedStatisticsParameter = &UpdAggregatedStatisticsParameters( { 'statistics_id' => 12, 'name' => 'branch', 'value' => 'Ros' }, {}, 'statistics_id' => 12, 'name' => 'branch', 'value' => 'Ros' } );

Create a new paramter entry for the selected customized statistics or update it if already existing.
The first hash contains the select condition, the second one the updated fields and the third one the fields for insert

B<returns:> AggregatedStatisticsParameters object containing the values of the new / updated record from table aggregated_statistics_parameters.

=cut

sub UpdAggregatedStatisticsParameters {
    my ($param) = @_;
    my $res;

    if ( length($param->{'statistics_id'}) and length($param->{'name'}) and defined($param->{'value'}) ) {
        my $selParam = {
            'statistics_id' => $param->{'statistics_id'},
            'name' => $param->{'name'}
        };
        my $updParam = {
            'value' => $param->{'value'}
        };
        my $insParam = {
            'statistics_id' => $param->{'statistics_id'},
            'name' => $param->{'name'},
            'value' => $param->{'value'}
        };
 
print STDERR "AggregatedStatistics::UpdAggregatedStatisticsParameters() update or insert aggregated_statistics_parameters record calling Koha::AggregatedStatistics::AggregatedStatisticsParameters->new()->upd_or_ins(selParam, updParam, insParam) \nselParam:", Dumper($selParam), ": updParam:", Dumper($updParam), ": insParam:", Dumper($insParam), ":\n" if $debugIt;
        my $aggregatedStatisticsParameters = Koha::AggregatedStatistics::AggregatedStatisticsParameters->new();
        my $res = $aggregatedStatisticsParameters->upd_or_ins($selParam, $updParam, $insParam);   # TODO: evaluate $res
print STDERR "AggregatedStatistics::UpdAggregatedStatisticsParameters() insert aggregated_statistics_parameters record res:", Dumper($res->_resultset()->{_column_data}), ":\n" if $debugIt;
    }
    return $res;
}

#------------------------------------------------------------#

=head3 GetAggregatedStatisticsParameters

  $aggregatedStatisticsParameters = &GetAggregatedStatisticsParameters( { 'statistics_id' => 14 } );

Read the customer defined statistics parameters records.

=over

=item C<$param> the aggregated statistics parameters are identified by primary key param->{'statistics_id'}

=back

B<returns:> AggregatedStatisticsParameters object containing the found records from table aggregated_statistics_parameters.

=cut

sub GetAggregatedStatisticsParameters {
    my ($selParam) = @_;
    my $res;

    if ( defined($selParam->{'statistics_id'}) ) {
        my $aggregatedStatisticsParameters = Koha::AggregatedStatistics::AggregatedStatisticsParameters->new();

        $res = $aggregatedStatisticsParameters->search($selParam);
    }

    return $res;
}

#------------------------------------------------------------#

=head3 DelAggregatedStatisticsParameters

  $aggregatedStatisticsParameters = &DelAggregatedStatisticsParameters( { 'statistics_id' => 14, 'name' => 'branchcode' } );

Delete the customer defined statistics parameters records, selected at least by statistics_id

=over

=item C<$param> the aggregated statistics parameters are identified by param->{'statistics_id'} (mandatory) and name (optional) and value (optional)

=back

B<returns:> AggregatedStatisticsParameters object containing the found records from table aggregated_statistics_parameters.

=cut

sub DelAggregatedStatisticsParameters {
    my ($selParam) = @_;
    my $res;

    if ( length($selParam->{'statistics_id'}) > 0 ) {
        my $aggregatedStatisticsParameters = Koha::AggregatedStatistics::AggregatedStatisticsParameters->new();
        my $resASP = $aggregatedStatisticsParameters->search($selParam);
        $res = $resASP->_resultset()->delete_all();

    }

    return $res;
}

#------------------------------------------------------------#

=head3 UpdAggregatedStatisticsValues

  $aggregatedStatisticsValue = &UpdAggregatedStatisticsValues( { 'statistics_id' => 12, 'name' => 'total_issues', 'value' => '3588', 'type' => 'int' } );

Create a new value entry for the selected customized statistics or update it if already existing.
Identity is defined by statistics_id/name.

B<returns:> AggregatedStatisticsValues object containing the values of the new / updated record from table aggregated_statistics_values.

=cut

sub UpdAggregatedStatisticsValues {
    my ($param) = @_;
 
    my $selParam = {
        statistics_id => $param->{'statistics_id'},
        name => $param->{'name'}
    };
    my $updParam = {
        value => $param->{'value'},
        type => $param->{'type'}
    };
    my $insParam = {
        statistics_id => $param->{'statistics_id'},
        name => $param->{'name'},
        value => $param->{'value'},
        type => $param->{'type'}
    };
    my $aggregatedStatisticsValues = Koha::AggregatedStatistics::AggregatedStatisticsValues->new();
    my $res = $aggregatedStatisticsValues->upd_or_ins($selParam, $updParam, $insParam);   # TODO: evaluate $res

    return $res;
}

#------------------------------------------------------------#

=head3 GetAggregatedStatisticsValues

  $aggregatedStatisticsValues = &GetAggregatedStatisticsValues( { 'statistics_id' => 14 } );

Read the customer defined statistics values records.

=over

=item C<$param> the aggregated statistics values are identified by primary key param->{'statistics_id'}

=back

B<returns:> AggregatedStatisticsValues object containing the found records from table aggregated_statistics_values.

=cut

sub GetAggregatedStatisticsValues {
    my ($selParam) = @_;
    my $res;

    if ( defined($selParam->{'statistics_id'}) ) {
        my $aggregatedStatisticsValues = Koha::AggregatedStatistics::AggregatedStatisticsValues->new();
        $res = $aggregatedStatisticsValues->search($selParam);
    }

    return $res;
}

#------------------------------------------------------------#

=head3 DelAggregatedStatisticsValues

  $aggregatedStatisticsValues = &DelAggregatedStatisticsValues( { 'statistics_id' => 14, 'name' => 'st_gen_libcount' } );

Delete the calculated / edited statistics values records, selected at least by statistics_id

=over

=item C<$param> the aggregated statistics values are identified by param->{'statistics_id'} (mandatory) and name (optional) and value (optional)

=back

B<returns:> AggregatedStatisticsValues object containing the found records from table aggregated_statistics_values.

=cut

sub DelAggregatedStatisticsValues {
    my ($selParam) = @_;
    my $res;

    if ( length($selParam->{'statistics_id'}) > 0 ) {
        my $aggregatedStatisticsValues = Koha::AggregatedStatistics::AggregatedStatisticsValues->new();
        my $resASV = $aggregatedStatisticsValues->search($selParam);
        $res = $resASV->_resultset()->delete_all();

    }

    return $res;
}

#------------------------------------------------------------#

1;
__END__

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut
