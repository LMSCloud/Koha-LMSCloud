package C4::AggregatedStatistics::AggregatedStatisticsBase;

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

use strict;
use warnings;
use CGI qw ( -utf8 );
use Data::Dumper;

use Koha::DateUtils qw( dt_from_string output_pref );


my $debug = 1;

sub new {
    my $class = shift;
    #my $self  = bless { @_ }, $class;
    my $input = shift;
    my $self  = {   'id' => scalar $input->param('id'),
                    'statisticstype' => scalar $input->param('statisticstype'),
                    'statisticstypedesignation' => 'GeneralAggregatedStatisticsType',    # default dummy, has to be updated in derived classes
                    'name' => scalar $input->param('name'),
                    'description' => scalar $input->param('description'),
                    'startdate' => scalar $input->param('startdate'),
                    'enddate' => scalar $input->param('enddate'),
                    'op' => scalar $input->param('op')
                };
#    my $self  = {};
    
print STDERR "AggregatedStatisticsBase::new statisticstype:",$self->{'statisticstype'},": statisticstypedesignation:",$self->{'statisticstypedesignation'},": id:",$self->{'id'},": name:",$self->{'name'},": description:",$self->{'description'},": startdate:",$self->{'startdate'},": enddate:",$self->{'enddate'},": op:",$self->{'op'},":\n" if $debug;

#print STDERR "AggregatedStatisticsBase::new Dumper(class):", Dumper($class), ":\n" if $debug;
    #bless $self, $class;
    bless $self, 'C4::AggregatedStatistics::AggregatedStatisticsBase';
print STDERR "AggregatedStatisticsBase::new Dumper(self):", Dumper($self), ":\n" if $debug;
print STDERR "AggregatedStatisticsBase::new self->{'id'}:$self->{'id'}:\n" if $debug;
print STDERR "AggregatedStatisticsBase::new self->{'statisticstype'}:$self->{'statisticstype'}:\n" if $debug;
print STDERR "AggregatedStatisticsBase::new self->{'name'}:$self->{'name'}:\n" if $debug;
print STDERR "AggregatedStatisticsBase::new self->{'startdate'}:$self->{'startdate'}:\n" if $debug;

    
    return $self;
}



# prepare the form for adding / editing / copying an aggregated_statistics record
sub add_form {
    my $self = shift;
print STDERR "AggregatedStatisticsBase::add_form statisticstype:$self->{'statisticstype'}:  statisticstypedesignation:$self->{'statisticstypedesignation'}: name:$self->{'name'}:\n" if $debug;
    my $found = $self->readbyname();
print STDERR "AggregatedStatisticsBase::add_form returns found:$found: \$self->{'id'}:", $self->{'id'}, ":\n" if $debug;

    return $found;
}

sub readbyname {
    my $self = shift;
print STDERR "AggregatedStatisticsBase::readbyname statisticstype:$self->{'statisticstype'}:  statisticstypedesignation:$self->{'statisticstypedesignation'}: name:$self->{'name'}:\n" if $debug;
    my $found = 0;

    my $aggregatedStatistics;
    # if name has been passed we can identify aggregated_statistics record (aggregated_statistics.type && aggregated_statistics.name is unique)
    if ( $self->{'name'} ) {
        $aggregatedStatistics = C4::AggregatedStatistics::GetAggregatedStatistics(
            {
                type => $self->{'statisticstype'},
                name => $self->{'name'}
            }
        );
print STDERR "AggregatedStatisticsBase::readbyname count aggregatedStatistics:", $aggregatedStatistics->_resultset()+0, ":\n" if $debug;
    }

    if ($aggregatedStatistics && $aggregatedStatistics->_resultset() && $aggregatedStatistics->_resultset()->first()) {
        my $rsHit = $aggregatedStatistics->_resultset()->first();

        $self->{'id'} = $rsHit->get_column('id');
        $self->{'statisticstype'} = $rsHit->get_column('type');
        $self->{'name'} = $rsHit->get_column('name');
        $self->{'description'} = $rsHit->get_column('description');
        $self->{'startdate'} = $rsHit->get_column('startdate');
        $self->{'enddate'} = $rsHit->get_column('enddate');

        $found = 1;
    }
print STDERR "AggregatedStatisticsBase::readbyname returns found:$found: \$self->{'id'}:", $self->{'id'}, ":\n" if $debug;

    return $found;
}

# evaluate the form for adding / editing / copying an aggregated_statistics record
sub add_validate {
    my $self = shift;
    my $input = shift;

    $self->{'id'}             = $input->param('id');
    $self->{'statisticstype'} = $input->param('statisticstype');
    $self->{'name'}           = $input->param('name');
    $self->{'description'}    = $input->param('description');
    $self->{'startdateDB'}    = output_pref({ dt => dt_from_string( scalar $input->param('startdate') ), dateformat => 'iso', dateonly => 1 });
    $self->{'enddateDB'}      = output_pref({ dt => dt_from_string( scalar $input->param('enddate') ), dateformat => 'iso', dateonly => 1 });
    $self->{'op'}             = $input->param('op');

    my %param;

print STDERR "AggregatedStatisticsBase::add_validate  op:",$self->{'op'},": statisticstype:",$self->{'statisticstype'},": name:",$self->{'name'},": id:",$self->{'id'},":\n" if $debug;

    if ( $self->{'op'} ne 'copy_validate' ) {
print STDERR "AggregatedStatisticsBase::add_validate op ne 'copy_validate'   \$self->{'id'}:", $self->{'id'}, ":\n" if $debug;
        $param{'id'} = $self->{'id'};    # record selected by id if defined id, otherwise selected by type & name
    }
    $param{'type'} = $self->{'statisticstype'};
    $param{'name'} = $self->{'name'};
    $param{'description'} = $self->{'description'};
    $param{'startdate'} = $self->{'startdateDB'};
    $param{'enddate'}   = $self->{'enddateDB'};
    my $aggregatedStatistics = C4::AggregatedStatistics::CreateAggregatedStatistics(\%param);    # updates a record if found via id or via type & name

print STDERR "AggregatedStatisticsBase::add_validate result \$!:$!:\n";
    $self->{'id'} = $aggregatedStatistics->_resultset()->get_column('id');
    return $aggregatedStatistics;
}

# delete an aggregated_statistics record and joined records from aggregated_statistics_parameters and aggregated_statistics_values
sub delete {
    my $self = shift;

print STDERR "AggregatedStatisticsBase::delete statisticstype:",$self->{'statisticstype'},": name:",$self->{'name'},": id:",$self->{'id'},":\n" if $debug;
    C4::AggregatedStatistics::DelAggregatedStatistics(
        {
            type => $self->{'statisticstype'},
            name => $self->{'name'},
        }
    );
}

sub getadditionalparameters {
    my $self = shift;

    my $additionalparameters = {};    # for AggregatedStatisticsBase there are no additional aggregated_statistics_parameters

    return $additionalparameters;
}

sub readAll {
    my $self = shift;
    my @hits;

print STDERR "AggregatedStatisticsBase::readAll  self->statisticstype:",$self->{'statisticstype'},":\n";
    my $aggregatedStatistics = C4::AggregatedStatistics::GetAggregatedStatistics(
        {
            type => $self->{'statisticstype'}
        }
    );
    if ($aggregatedStatistics && $aggregatedStatistics->_resultset()) {
        foreach my $rsHit ($aggregatedStatistics->_resultset()->all()) {
            my $hit = {
                id => $rsHit->get_column('id'),
                type => $rsHit->get_column('type'),
                name => $rsHit->get_column('name'),
                description => $rsHit->get_column('description'),
                startdate => $rsHit->get_column('startdate'),
                enddate => $rsHit->get_column('enddate')
            };
            push @hits, $hit;
        }
    }
    return \@hits;
}

sub readAggregatedStatisticsParametersValue {
    my $self = shift;
    my $name = shift;
print STDERR "C4::AggregatedStatistics::AggregatedStatisticsBase::readAggregatedStatisticsParametersValue Start self->id:", $self->{'id'}, ": name:$name:\n" if $debug;
    my %param;
    my $value;

    if ( defined($self->{'id'}) && length($self->{'id'}) > 0 ) {    # this should always be the case / only for safety's sake
        if ( defined($name) ) {    # this should always be the case / only for safety's sake
            $param{'statistics_id'} = $self->{'id'};
            $param{'name'} = $name;

            my $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters(\%param);
print STDERR "C4::AggregatedStatistics::AggregatedStatisticsBase::readAggregatedStatisticsParametersValue statistics_id:", $self->{'id'}, ": name:$name:   count aggregatedStatisticsParameters:", $aggregatedStatisticsParameters->_resultset()+0, ":\n" if $debug;
            if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset() && $aggregatedStatisticsParameters->_resultset()->first()) {
                my $rsHit = $aggregatedStatisticsParameters->_resultset()->first();
                if ( length($rsHit->get_column('value')) > 0 ) {
                    $value = $rsHit->get_column('value');
                }
            }
        }
    }
    return $value;
}

sub saveAggregatedStatisticsValue {
    my $self = shift;
    my ($name, $type, $value) = @_;
print STDERR "C4::AggregatedStatistics::AggregatedStatisticsBase::saveAggregatedStatisticsValue Start name:", $name, ": type:", $type, ": value:", $value, ":\n" if $debug;

    if ( defined($self->{'id'}) && length($self->{'id'}) > 0 ) {    # this should always be the case / only for safety's sake
        if ( !defined($value) && $type eq 'bool' ) {
            $value = '0';
        }
        if ( defined($value) ) {
            my %param;
            $param{'statistics_id'} = $self->{'id'};
            $param{'name'} = $name;
            if ( $type eq 'float' ) {
                my $thousands_sep = ' ';    # default, correct if Koha.Preference("CurrencyFormat") == 'FR'  (i.e. european format like "1 234 567,89")
                if ( substr($value,-3,1) eq '.' ) {    # american format, like "1,234,567.89"
                    $thousands_sep = ',';
                }
                $value =~ s/$thousands_sep//g;    # get rid of the thousands separator
                $value =~ tr/,/./;      # decimal separator in DB is '.'
            }
            $param{'value'} = $value;
            $param{'type'} = $type;
            
            my $aggregatedStatisticsValues = C4::AggregatedStatistics::UpdAggregatedStatisticsValues(\%param);
        } else {
            if ( defined($name) ) {
                # delete the record
                my %param;
                $param{'statistics_id'} = $self->{'id'};
                $param{'name'} = $name;

                my $aggregatedStatisticsValues = C4::AggregatedStatistics::DelAggregatedStatisticsValues(\%param);
            }
        }
    }
}

sub readAggregatedStatisticsValue {
    my $self = shift;
    my ($name, $type, $hit) = @_;
print STDERR "C4::AggregatedStatistics::AggregatedStatisticsBase::readAggregatedStatisticsValue Start self->id:", $self->{'id'}, ": name:", $name, ":\n" if $debug;
    my %param;

    if ( defined($self->{'id'}) && length($self->{'id'}) > 0 ) {    # this should always be the case / only for safety's sake
        if ( defined($name) ) {    # this should always be the case / only for safety's sake
            $param{'statistics_id'} = $self->{'id'};
            $param{'name'} = $name;
            
            my $aggregatedStatisticsValuesRS = C4::AggregatedStatistics::GetAggregatedStatisticsValues(\%param);
            if ( defined($aggregatedStatisticsValuesRS->_resultset()->first()) ) {
                $param{'value'} = $aggregatedStatisticsValuesRS->_resultset()->first()->get_column('value');
                $param{'type'} = defined($type) ? $type : $aggregatedStatisticsValuesRS->_resultset()->first()->get_column('type');
            }
        }
    }
    $$hit = \%param;
}

sub delAggregatedStatisticsValue {
    my $self = shift;
    my ($name) = @_;
print STDERR "C4::AggregatedStatistics::AggregatedStatisticsBase::delAggregatedStatisticsValue Start self->id:", $self->{'id'}, ": name:", $name, ":\n" if $debug;
    my %param;

    if ( defined($self->{'id'}) && length($self->{'id'}) > 0 ) {    # this should always be the case / only for safety's sake
        $param{'statistics_id'} = $self->{'id'};
        if ( defined($name) ) {
            $param{'name'} = $name;
        }
        my $aggregatedStatisticsValuesRS = C4::AggregatedStatistics::DelAggregatedStatisticsValues(\%param);
    }
}

sub supports {
    my $self = shift;
    my $method = shift;
    my $ret = 0;

    return $ret;
}

1;
