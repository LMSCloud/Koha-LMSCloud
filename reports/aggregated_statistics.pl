#!/usr/bin/perl

# Copyright 2017 LMSCloud
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

=head1 reports/aggregated_statistics.pl

 This script manages the create / read / update / delete operations  on the DB tables
 aggregated_statistics, aggregated_statistics_parameters and aggregated_statistics_values.
 The DB interactions are handled by calls to C4/AggregatedStatistics.pm.
 DBS specific functions are managed by 'perl using' the module C4::AggregatedStatistics::DBS.

 The cgi param 'op' signals which operation to perform.

 General $op values (manage table aggregated_statistics):
 if $op is empty or none of the values listed below,
	- the default screen is built with all records.
	- the user can click on add, copy, parameter_edit, delete or edit (i.e. evaluate) record.

 if $op eq 'add_form'
	- if primary key (id or type&name) exists, this is a modification, so the required record will be read
	- builds the add/modify form

 if $op eq 'add_validate'
	- the user has just sent data, so the record will be created/modified

 if $op eq 'delete_confirm'
	- the selected record is shown and a confirmation for deleting is asked for

 if $op eq 'delete_confirmed'
	- deletion task has been confirmed by the user, so the selected record will be deleted

 $op values for managing functions of statistics derived from AggregatedStatisticsBase (e.g. having aggregated_statistics.type = "DBS"):
if $op eq 'eval_form'
    - display the form that is used for evaluating and editing a statistics derived from AggregatedStatisticsBase (e.g. DBS)

 if $op eq 'dcv_calc'
	- (re-)calculate values for a statistics derived from AggregatedStatisticsBase ( e.g. DBS (Deutsche Bibliotheksstatistik))

 if $op eq 'dcv_save'
	- save the calculated and edited values a the statistics derived from AggregatedStatisticsBase (e.g. DBS) into table aggregated_statistics_values

 if $op eq 'dcv_del'
	- delete values for a statistics derived from AggregatedStatisticsBase (e.g. DBS) from table aggregated_statistics_values

=cut

use strict;
use warnings;
use CGI qw ( -utf8 );
use Data::Dumper;

use Koha::DateUtils;
use C4::Auth;
use C4::Output;
use C4::AggregatedStatistics;
use C4::AggregatedStatistics::AggregatedStatisticsFactory;


my $debug = 1;

my $html_output_done = 0;
our $input = new CGI;
our $script_name  = '/cgi-bin/koha/reports/aggregated_statistics.pl';
our $op = $input->param('op') || '';

our $aggregatedstatistics = C4::AggregatedStatistics::AggregatedStatisticsFactory->getAggregatedStatisticsClass(scalar $input->param('statisticstype'),$input);    # creat instance of class derived from AggregatedStatisticsBase


our ( $template, $borrowernumber, $cookie, $staffflags ) = get_template_and_user(
    {
        template_name   => 'reports/aggregated_statistics.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => {reports => '*'},
        debug           => 1,
    }
);

print STDERR "aggregated_statistics::main statisticstype:$aggregatedstatistics->{'statisticstype'}: statisticstypedesignation:$aggregatedstatistics->{'statisticstypedesignation'}: id:$aggregatedstatistics->{'id'}: name:$aggregatedstatistics->{'name'}: description:$aggregatedstatistics->{'description'}: startdate:$aggregatedstatistics->{'startdate'}: enddate:$aggregatedstatistics->{'enddate'}: op:$aggregatedstatistics->{'op'}:\n" if $debug;
#print STDERR "aggregated_statistics::main Dumper(input):", Dumper($input), ":\n" if $debug;
#print STDERR "aggregated_statistics::main op:$op: input->param(st_gen_population):", scalar $input->param('st_gen_population'), ": input->param(st_gen_libcount):", scalar $input->param('st_gen_libcount'), ":\n" if $debug;

$template->param(
	script_name => $script_name,
	action => $script_name,
	id => $aggregatedstatistics->{'id'},
    statisticstype => $aggregatedstatistics->{'statisticstype'},
	name => $aggregatedstatistics->{'name'},
	description => $aggregatedstatistics->{'description'},
	startdate => $aggregatedstatistics->{'startdate'},
	enddate => $aggregatedstatistics->{'enddate'}
);

if ( $op eq 'add_validate' or $op eq 'copy_validate' ) {
    add_validate();
    $op = q{}; # we return to the default screen for the next operation
}

if ($op eq 'copy_form') {
    add_form();
    $template->param(
        copying => 1,
        modify => 0,
    );
}
elsif ( $op eq 'add_form' ) {
    add_form();
}
elsif ( $op eq 'delete_confirm' ) {
    delete_confirm();
}
elsif ( $op eq 'delete_confirmed' ) {
    delete_confirmed();
    $op = q{}; # next operation is to return to default screen
}
elsif ( $op eq 'eval_form' ) {
    eval_form();    # show form triggered by 'edit' button - evaluate subclass functionality
}
elsif ( $op eq 'dcv_calc' ) {    # derived class values - calculate
    if ( $aggregatedstatistics->supports('dcv_calc') ) {
        $aggregatedstatistics->dcv_calc($input);
    }
    eval_form();    # handle form triggered by 'edit' button - evaluate subclass functionality
}
elsif ( $op eq 'dcv_save' ) {    # derived class values - save into database
    if ( $aggregatedstatistics->supports('dcv_save') ) {
        $aggregatedstatistics->dcv_save($input);
    }
    eval_form();    # handle form triggered by 'edit' button - evaluate subclass functionality
}
elsif ( $op eq 'dcv_del' ) {    # derived class values - delete from database
    if ( $aggregatedstatistics->supports('dcv_del') ) {
        $aggregatedstatistics->dcv_del($input);
    }
    eval_form();    # handle form triggered by 'edit' button - evaluate subclass functionality
}
else {
    default_display($aggregatedstatistics->{'statisticstype'});
}

if ( !$html_output_done ) {
    # do this as last step because delete_confirmed resets params
    if ($op) {
        $template->param($op => 1);
    } else {
        $template->param(no_op_set => 1);
    }

    output_html_with_http_headers $input, $cookie, $template->output;
}



# prepare the form for adding / editing / copying an aggregated_statistics record
sub add_form {
print STDERR "aggregated_statistics::add_form statisticstype:$aggregatedstatistics->{'statisticstype'}:  statisticstypedesignation:$aggregatedstatistics->{'designation'}: name:$aggregatedstatistics->{'name'}:\n" if $debug;
print STDERR "aggregated_statistics::add_form input->param('statisticstype'):scalar $input->param('statisticstype'):\n" if $debug;

    my $found = $aggregatedstatistics->add_form($input);
print STDERR "aggregated_statistics::add_form found:$found:\n" if $debug;

    if ( $found ) {
        $template->param(
            modify => 1,
            id => $aggregatedstatistics->{'id'},
            statisticstype => $aggregatedstatistics->{'statisticstype'},
            statisticstypedesignation => $aggregatedstatistics->{'statisticstypedesignation'},
            name => $aggregatedstatistics->{'name'},
            description => $aggregatedstatistics->{'description'},
            startdate => $aggregatedstatistics->{'startdate'},
            enddate => $aggregatedstatistics->{'enddate'}
        );
    }
    else { # create new record
        $template->param(
            adding => 1,
            id => $aggregatedstatistics->{'id'},
            statisticstype => $aggregatedstatistics->{'statisticstype'},
            statisticstypedesignation => $aggregatedstatistics->{'statisticstypedesignation'}
        );
    }

    $template->param(
        additionalparameters => $aggregatedstatistics->getadditionalparameters()
    );
}

# evaluate the form for adding / editing / copying an aggregated_statistics record
sub add_validate {

    my $aggregatedStatistics = $aggregatedstatistics->add_validate($input);

    # set up default display
    default_display($aggregatedStatistics->{'statisticstype'});
}

# prepare the form for deleting an aggregated_statistics record
sub delete_confirm {
print STDERR "aggregated_statistics::delete_confirm  op:$aggregatedstatistics->{'op'}: statisticstype:$aggregatedstatistics->{'statisticstype'}: name:$aggregatedstatistics->{'name'}:\n" if $debug;
    my $found = $aggregatedstatistics->readbyname($input);
print STDERR "aggregated_statistics::delete_confirm found:$found:\n" if $debug;

    if ($found) {
        my $hit = {
            id => $aggregatedstatistics->{'id'},
            type => $aggregatedstatistics->{'statisticstype'},
            name => $aggregatedstatistics->{'name'},
            description => $aggregatedstatistics->{'description'},
            startdate => $aggregatedstatistics->{'startdate'},
            enddate => $aggregatedstatistics->{'enddate'}
        };
        $template->param(
            hit => $hit,
        );
    }
}

# evaluate the form for deleting an aggregated_statistics record
sub delete_confirmed {
print STDERR "aggregated_statistics::delete_confirmed  op:$aggregatedstatistics->{'op'}: statisticstype:$aggregatedstatistics->{'statisticstype'}: name:$aggregatedstatistics->{'name'}:\n" if $debug;
    $aggregatedstatistics->delete();

    # setup default display for screen
    default_display($aggregatedstatistics->{'statisticstype'});
}

# prepare the form for evaluating / editing the specific statistics (e.g. DBS)
sub eval_form {
    # the evaluation depends on statisticstype
print STDERR "aggregated_statistics::eval_form Start statisticstype:$aggregatedstatistics->{'statisticstype'}: id:$aggregatedstatistics->{'id'}: op:$aggregatedstatistics->{'op'}:\n" if $debug;
    if ( $aggregatedstatistics->supports('eval_form') ) {
        $aggregatedstatistics->eval_form($script_name, $input);
        $html_output_done = 1;
    } else {
        # not implemented for remaining statistics types, so avoid HTTP error 500:
        default_display($aggregatedstatistics->{'statisticstype'});
        $op = q{}; # next operation is to return to default screen
    }
}

sub default_display {
    my ($preselected_statisticstype) = @_;
print STDERR "aggregated_statistics::default_display  op:$aggregatedstatistics->{'op'}: preselected_statisticstype:$preselected_statisticstype:aggregatedstatistics->statisticstype:$aggregatedstatistics->{'statisticstype'}: name:$aggregatedstatistics->{'name'}:\n" if $debug;

    unless ( defined $preselected_statisticstype ) {
        my $statisticstypes = C4::AggregatedStatistics::AggregatedStatisticsFactory->getAggregatedStatisticsTypes();
        $preselected_statisticstype = $statisticstypes->[0];    # take the first entry as default statisticstype
    }
    my $aggregatedstatistics = C4::AggregatedStatistics::AggregatedStatisticsFactory->getAggregatedStatisticsClass($preselected_statisticstype,$input);
    my $results = $aggregatedstatistics->readAll();

    my $ags_hits = [];
    foreach my $row (@{$results}) {
        push @{$ags_hits}, $row;
    }

    my $statisticstypeloop = [];
    my $statisticstypes = C4::AggregatedStatistics::AggregatedStatisticsFactory->getAggregatedStatisticsTypes();
    foreach my $agstype (@{$statisticstypes}) {
        push @{$statisticstypeloop}, {
            type        => $agstype,
            designation => C4::AggregatedStatistics::AggregatedStatisticsFactory->getAggregatedStatisticsTypeDesignation($agstype),
            selected    => $preselected_statisticstype && ( $agstype eq $preselected_statisticstype )
        };
    }

    $template->param(
        hits => $ags_hits,
        statisticstypeloop => $statisticstypeloop
    );
}
