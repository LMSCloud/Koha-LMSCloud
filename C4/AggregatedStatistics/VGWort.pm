package C4::AggregatedStatistics::VGWort;

# Copyright 2023 (C) LMSCloud GmbH
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
use CGI qw ( -utf8 );
use Data::Dumper;

use C4::Auth;
use C4::Output;

use Koha::ItemTypes;
use Koha::Library::Groups;

use Unicode::Normalize;

use C4::External::VGWortExport;
use C4::AggregatedStatistics::AggregatedStatisticsBase;
use parent qw(C4::AggregatedStatistics::AggregatedStatisticsBase);

sub new {
    my $class = shift;
    my $input = shift;
    my $statisticstypedesignation = shift;

    my $self  = {};
    bless $self, $class;

    $self = $self->SUPER::new($input);
    $self->{'statisticstypedesignation'} = $statisticstypedesignation;
    bless $self, $class;

    $self->{'selectedgroup'}  = $input->param('selectedgroup') || '*';    # default, in case it can not be read from table aggregated_statistics_parameters
    $self->{'selectedbranch'} = $input->param('selectedbranch') || '*';   # default, in case it can not be read from table aggregated_statistics_parameters
    
    $self->{'itemtypes'} = Koha::ItemTypes->search_with_localization->unblessed;
    
    $self->{'vgworttypes'} = [   
                                 { name => 'ANTHOLOGIE', value => 'ANTHOLOGIE' },
                                 { name => 'AV-MEDIUM', value => 'AV-MEDIUM' },
                                 { name => 'BUCH', value => 'BUCH' },
                                 { name => 'SPIEL', value => 'SPIEL' },
                                 { name => 'ZEITSCHRIFT', value => 'ZEITSCHRIFT' }
                             ];
    
    return $self;
}

sub getadditionalparameters {
    my $self = shift;

    my $additionalparameters = {
        categories     => $self->{'categories'},
        branchloop     => $self->{'branchloop'},
        selectedgroup  => $self->{'selectedgroup'},
        selectedbranch => $self->{'selectedbranch'},
        itemtypes      => $self->{'itemtypes'},
        vgworttypes    => $self->{'vgworttypes'}
    };

    return $additionalparameters;
}



# 1. section: functions required for aggregated-statistics-parameters-VGWort.inc

# prepare the form part for adding / editing / copying aggregated_statistics_parameter records
# ( the form is contained in aggregated_statistics.tt, the form part in aggregated-statistics-parameters-VGWort.inc )
sub add_form {
    my $self = shift;
    my ($input) = @_;

    my $found = $self->SUPER::readbyname($input);

    $self->{'selectedgroup'}  = $input->param('selectedgroup') || '*';    # default, in case it can not be read from table aggregated_statistics_parameters
    $self->{'selectedbranch'} = $input->param('selectedbranch') || '*';   # default, in case it can not be read from table aggregated_statistics_parameters
    
    my $aggregated_statistics_id = $self->{'id'};
    
    my $itypemapping = {};
    
    if ( defined($aggregated_statistics_id) && length($aggregated_statistics_id) > 0 ) {
        my $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters(
            {
                statistics_id => $aggregated_statistics_id,
                name => 'branchgroup',
            }
        );
        if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset() && $aggregatedStatisticsParameters->_resultset()->first()) {
            my $rsHit = $aggregatedStatisticsParameters->_resultset()->first();
            if ( length($rsHit->get_column('value')) > 0 ) {
                $self->{'selectedgroup'} = $rsHit->get_column('value');
            }
        }

        $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters(
            {
                statistics_id => $aggregated_statistics_id,
                name => 'branchcode',
            }
        );
        if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset() && $aggregatedStatisticsParameters->_resultset()->first()) {
            my $rsHit = $aggregatedStatisticsParameters->_resultset()->first();
            if ( length($rsHit->get_column('value')) > 0 ) {
                $self->{'selectedbranch'} = $rsHit->get_column('value');
            }
        }
        
        # read existing mapping 
        $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters(
            {
                statistics_id => $aggregated_statistics_id
            }
        );
        if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset()) {
            while ( my $rsHit = $aggregatedStatisticsParameters->_resultset()->next() ) {
                my $value = $rsHit->get_column('value');
                my $name = $rsHit->get_column('name');
                if ( $name && $name =~ /^itype_/ ) {
                    $name =~ s/^itype_//;
                    $itypemapping->{$name} = $value;
                }
            }
        }
    }

    
    ($self->{'categories'},$self->{'branchloop'},$self->{'itemtypes'}) = $self->read_categories_branches_and_itemtypes($itypemapping);

    return $found;
}

# evaluate the form part for adding / editing / copying aggregated_statistics_parameter records
# ( the form is contained in aggregated_statistics.tt, the form part in aggregated-statistics-parameters-VGWort.inc )
sub add_validate {
    my $self = shift;
    my ($input) = @_;
    my $res;

    my $old_id = $self->{'id'};
    my $aggregatedStatistics = $self->SUPER::add_validate($input);

    $self->{'selectedgroup'} = $input->param('selectedgroup');
    $self->{'selectedbranch'} = $input->param('selectedbranch');

    my $selectedgroup = $self->{'selectedgroup'};
    my $selectedbranch = $self->{'selectedbranch'};
    $selectedgroup = '' if ( !defined($selectedgroup) or $selectedgroup eq '*' );
    $selectedbranch = '' if ( !defined($selectedbranch) or $selectedbranch eq '*' );
    
    my $new_id = $self->{'id'};
    if ( defined($new_id) && length($new_id) > 0 ) {

        # insert / update aggregated_statistics_parameters record set according to the new / updated aggregated_statistics record
        my $selParam = { 
            statistics_id => $new_id
        };
        $res = C4::AggregatedStatistics::DelAggregatedStatisticsParameters($selParam);    # delete all entries from aggregated_statistics_parameters where statistics_id = $id

        my $insParam = { 
            statistics_id => $new_id,
            name => 'branchgroup',
            value => $selectedgroup
        };
        $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );

        $insParam = { 
            statistics_id => $new_id,
            name => 'branchcode',
            value => $selectedbranch
        };
        $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );

        my $itemtypes = $self->{itemtypes};
    
        foreach my $itype(@$itemtypes) {
            my $paramname = "itype_" . normalizeItypeName($itype->{itemtype});
            my $paramvalue = $input->param($paramname) || '';
            
            if ( $paramname ) {
                my $stored = 0;
                foreach my $vgwortvalue ( @{$self->{'vgworttypes'}} ) {
                    if ( $paramvalue eq $vgwortvalue->{value} ) {
                        $insParam = { 
                            statistics_id => $new_id,
                            name => $paramname,
                            value => $paramvalue
                        };
                        $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );
                        $stored = 1;
                        last;
                    }
                }
                if ( !$stored ) {
                    $insParam = { 
                        statistics_id => $new_id,
                        name => $paramname,
                        value => ''
                    };
                    $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );
                }
            }
        }
    }

    return $aggregatedStatistics;
}

#  copy all records from aggregated_statistics_values where statistics_id = $id_source to records with statistics_id = $self->{'id'}
sub copy_ag_values {
    my $self = shift;
    my $id_source = shift;
    my $id_target = $self->{'id'};
    my $res;

    if ( defined($id_source) && length($id_source) > 0 && defined($id_target) && length($id_target) > 0 && $id_source ne $id_target) {
        my $selParam = { 
            statistics_id => $id_target
        };
        $res = C4::AggregatedStatistics::DelAggregatedStatisticsValues($selParam);    # delete all entries from aggregated_statistics_parameters where statistics_id = $id_target

        my $aggregatedStatisticsValues = C4::AggregatedStatistics::GetAggregatedStatisticsValues(
            {
                statistics_id => $id_source,
            }
        );
        if ($aggregatedStatisticsValues && $aggregatedStatisticsValues->_resultset() && $aggregatedStatisticsValues->_resultset()->all()) {
            foreach my $rsHit ($aggregatedStatisticsValues->_resultset()->all()) {
                C4::AggregatedStatistics::UpdAggregatedStatisticsValues(
                    {
                        statistics_id => $id_target,
                        name => $rsHit->get_column('name'),
                        value => $rsHit->get_column('value'),
                        type => $rsHit->get_column('type'),
                    }
                );
            }
        }
    }
}

sub read_categories_branches_and_itemtypes {
    my $self = shift;
    my $itypemapping = shift;
    
    # read library categories into variable @categories
    my @categories = ();
    for my $category ( Koha::Library::Groups->get_search_groups( { interface => 'staff' } ) ) {    # fields used in template: category.id and category.categoryname
        push @categories, { categorycode => $category->id, categoryname => $category->title };
    }

    # read branch information into variable @branchloop
    my $branches = { map { $_->branchcode => $_->unblessed } Koha::Libraries->search };
    my @branchloop = ();
    for my $loopbranch (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %$branches) {
        push @branchloop, {
            value      => $loopbranch,
            selected   => 0,
            branchname => $branches->{$loopbranch}->{'branchname'},
            branchcode => $branches->{$loopbranch}->{'branchcode'},
            category   => $branches->{$loopbranch}->{'category'}
        };
    }
    
    # read itemtypes
    my $itemtypes = $self->{itemtypes};
    
    if ( $itypemapping ) {
        foreach my $itype(@$itemtypes) {
            $itype->{mapped} = '';
            
            $itype->{name} = normalizeItypeName($itype->{itemtype});

            if ( exists( $itypemapping->{ $itype->{name} } ) ) {
                $itype->{mapped} = $itypemapping->{ $itype->{name} };
            }
            else {
                if ($itype->{name} !~ /^(ebook|eaudio|evideo|emusic|epaper|elearning)$/ ) {
                    $itype->{mapped} = 'BUCH';
                }
            }
        }
    }
    
    return (\@categories, \@branchloop, $itemtypes);
}

sub normalizeItypeName {
    my $s = shift;
    $s = NFD($s); 
    $s =~ s/^[^a-zA-Z_:]/_/;
    $s =~ s/[^-a-zA-Z0-9_:.]/_/g;
    return $s;
}

sub get_branchgroup_branchcode_selection {
    my $self = shift;

    my $branchgroupSel = 0;    # default: no selection for branchgroup
    my $branchgroup = $self->readAggregatedStatisticsParametersValue('branchgroup');
    if ( !defined($branchgroup) || length($branchgroup) == 0 || $branchgroup eq '*' ) {
        $branchgroup = '';
    } else {
        $branchgroupSel = 1;
    }
    my $branchcodeSel = 0;    # default: no selection for branchcode
    my $branchcode = $self->readAggregatedStatisticsParametersValue('branchcode');
    if ( !defined($branchcode) || length($branchcode) == 0 || $branchcode eq '*' ) {
        $branchcode = '';
    } else {
        $branchcodeSel = 1;
        $branchgroupSel = 0;    # of course the finer selection 'branchcode' has to be used, if existing, in favour of 'branchgroup'
    }
    return ($branchgroupSel, $branchgroup, $branchcodeSel, $branchcode);
}

# 2. section: functions required for aggregated_statistics_DBS.tt

sub supports {
    my $self = shift;
    my $method = shift;
    my $ret = 0;

    if ( $method eq 'eval_form' ) {
        $ret = 1;
    } elsif ( $method eq 'dcv_del' ) {
        $ret = 1;
    }
    return $ret;
}

# prepare the form for evaluating / editing the specific statistics DBS
sub eval_form {
    my $self = shift;
    my ($script_name, $input) = @_;
    my $res;

    our ( $template, $borrowernumber, $cookie, $staffflags ) = get_template_and_user(
        {
            template_name   => 'reports/aggregated_statistics_VGWort.tt',
            query           => $input,
            type            => 'intranet',
            authnotrequired => 0,
            flagsrequired   => { },
            debug           => 1,
        }
    );

    my $branchgroup = $self->readAggregatedStatisticsParametersValue('branchgroup');
    my $branchcode = $self->readAggregatedStatisticsParametersValue('branchcode');

    $self->{'selectedgroup'}  = $branchgroup || '*';
    $self->{'selectedbranch'} = $branchcode || '*';

    my $group = Koha::Library::Groups->find( $branchgroup );
    $group = $group->unblessed if ( $group );
    my $selectedgroupname = ($group && $group->{title}) ? $group->{title} : '*';
    my $library = Koha::Libraries->find($branchcode);
    my $selectedbranchname = ($library && $library->branchname) ? $library->branchname : '';
    
    # get media export statistics

    my $mediaTypeMapping = {};
    my $fromDate;
    my $toDate;
    my $libraryGroup = undef;
    my $library = undef;
    my $exportData = [];

    my $aggregatedStatisticsId = $self->{id};

    if ( $aggregatedStatisticsId && $aggregatedStatisticsId =~ /^[0-9]+$/ ) {

        my $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters({ statistics_id => $aggregatedStatisticsId } );

        if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset()) {
            while ( my $rsHit = $aggregatedStatisticsParameters->_resultset()->next() ) {
                my $value = $rsHit->get_column('value');
                my $name = $rsHit->get_column('name');
                if ( $name && $name =~ /^itype_/ ) {
                    $name =~ s/^itype_//;
                    $mediaTypeMapping->{$name} = $value;
                }
                elsif ( $name && $name =~ /^branchcode$/ && $value ) {
                    $library = $value;
                }
                elsif ( $name && $name =~ /^branchgroup$/ && $value ) {
                    $libraryGroup = $value;
                }
            }
        }

        my $aggregatedStatistics = C4::AggregatedStatistics::GetAggregatedStatistics({ id => $aggregatedStatisticsId } );

        if ($aggregatedStatistics && $aggregatedStatistics->_resultset()) {
            while ( my $rsHit = $aggregatedStatistics->_resultset()->next() ) {
                if ( $rsHit->get_column('type') eq 'VGWort' ) {
                    $fromDate = $rsHit->get_column('startdate');
                    $toDate = $rsHit->get_column('enddate');
                }
            }
        }

        if ( $fromDate && $toDate ) {
            my $exporter = C4::External::VGWortExport->new($fromDate,$toDate,$mediaTypeMapping,$libraryGroup,$library);
            $exportData = $exporter->getExportCountsPerVGWortMediaType();
        }
    }

    # export params
    $template->param(
        script_name => $script_name,
        action => $script_name,
        id => $self->{'id'},
        statisticstype => $self->{'statisticstype'},
        statisticstypedesignation => $self->{'statisticstypedesignation'},
        name => $self->{'name'},
        description => $self->{'description'},
        startdate => $self->{'startdate'},
        enddate => $self->{'enddate'},
        selectedgroup => $self->{'selectedgroup'},
        selectedbranch => $self->{'selectedbranch'},
        selectedgroupname => $selectedgroupname,
        selectedbranchname => $selectedbranchname,
        exportData => $exportData
    );

    output_html_with_http_headers $input, $cookie, $template->output;
}

sub dcv_del {
    my $self = shift;

    # delete all records from aggregated_statistics_values having this statistics_id
    my $name = undef;
    $self->delAggregatedStatisticsValue($name);

    # read it from database into hash $as_values
    $self->dcv_read();
}


1;
