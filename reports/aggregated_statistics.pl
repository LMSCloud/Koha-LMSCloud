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
	- the user can click on add, copy, edit or delete record.

 if $op eq 'add_form'
	- if primary key (id or type&name) exists, this is a modification, so the required record will be read
	- builds the add/modify form

 if $op eq 'add_validate'
	- the user has just sent data, so the record will be created/modified

 if $op eq 'delete_confirm'
	- the selected record is shown and a confirmation for deleting is asked for

 if $op eq 'delete_confirmed'
	- deletion task has been confirmed by the user, so the selected record will be deleted

 $op values for managing functions of statistics having aggregated_statistics.type = "DBS":
 if $op eq 'dbs_calc'
	- (re-)calculate values for the DBS (Deutsche Bibliotheksstatistik)

 if $op eq 'dbs_save'
	- save the calculated and edited values for the DBS into table aggregated_statistics_values

 if $op eq 'dbs_del'
	- delete values for the DBS from table aggregated_statistics_values

=cut

use strict;
use warnings;
use CGI qw ( -utf8 );
use Data::Dumper;

use Koha::DateUtils;
use C4::Auth;
use C4::Output;
use C4::AggregatedStatistics;


my $debug = 1;

our $input         = new CGI;
our $script_name  = '/cgi-bin/koha/reports/aggregated_statistics.pl';
our $statisticstype  = $input->param('statisticstype');
our $statisticstypedesignation  = $input->param('statisticstypedesignation');
our $id          = $input->param('id');
our $name        = $input->param('name');
our $description = $input->param('description');
our $startdate   = $input->param('startdate');
our $enddate     = $input->param('enddate');
our $op          = $input->param('op') || '';


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

print STDERR "aggregated_statistics::main statisticstype:$statisticstype: statisticstypedesignation:$statisticstypedesignation: id:$id: name:$name: description:$description: startdate:$startdate: enddate:$enddate: op:$op:\n" if $debug;
#print STDERR "aggregated_statistics::main Dumper(input):", Dumper($input), ":\n" if $debug;
#print STDERR "aggregated_statistics::main op:$op: input->param(selectedgroup):", scalar $input->param('selectedgroup'), ": input->param(selectedbranch):", scalar $input->param('selectedbranch'), ":\n" if $debug;
#print STDERR "aggregated_statistics::main op:$op: input->param(st_gen_population):", scalar $input->param('st_gen_population'), ": input->param(st_gen_libcount):", scalar $input->param('st_gen_libcount'), ":\n" if $debug;

$template->param(
	script_name => $script_name,
	action => $script_name,    # XXXWH hier doch noch id !
    statisticstype => $statisticstype,
	name => $name,
	description => $description,
	startdate => $startdate,
	enddate => $enddate
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
    eval_form();
}
elsif ( $op eq 'dbs_calc' ) {
    C4::AggregatedStatistics::DBS::dbs_calc($input, $id);
    eval_form();
}
elsif ( $op eq 'dbs_save' ) {
    C4::AggregatedStatistics::DBS::dbs_save($input, $id);
    eval_form();
}
elsif ( $op eq 'dbs_del' ) {
    C4::AggregatedStatistics::DBS::dbs_del($input, $id);
    eval_form();
}
else {
    default_display($statisticstype);
}

# Do this as last step because delete_confirmed resets params
if ($op) {
    $template->param($op => 1);
} else {
    $template->param(no_op_set => 1);
}

if (  $op ne 'eval_form' &&
      $op ne 'dbs_calc' &&
      $op ne 'dbs_save' &&
      $op ne 'dbs_del'
   ) {
    output_html_with_http_headers $input, $cookie, $template->output;
}



# prepare the form for adding / editing / copying an aggregated_statistics record
sub add_form {
print STDERR "aggregated_statistics::add_form statisticstype:$statisticstype:  statisticstypedesignation:$statisticstypedesignation: name:$name:\n" if $debug;
print STDERR "aggregated_statistics::add_form statisticstype:input->param('statisticstype'):$input->param('statisticstype'):\n" if $debug;

    my $aggregatedStatistics;
    my $aggregatedStatisticsId = undef;
    # if name has been passed we can identify aggregated_statistics record, and it is an update action (aggregated_statistics.type && aggregated_statistics.name is unique)
    if ($name) {
        $aggregatedStatistics = C4::AggregatedStatistics::GetAggregatedStatistics(
            {
                type => $statisticstype,
                name => $name,
            }
        );
print STDERR "aggregated_statistics::add_form count aggregatedStatistics:", $aggregatedStatistics->_resultset()+0, ":\n" if $debug;
    }

    if ($aggregatedStatistics && $aggregatedStatistics->_resultset() && $aggregatedStatistics->_resultset()->first()) {
        my $rsHit = $aggregatedStatistics->_resultset()->first();
        $aggregatedStatisticsId = $rsHit->get_column('id');
        $template->param(
            modify => 1,
            id => $rsHit->get_column('id'),
            statisticstype => $rsHit->get_column('type'),
            name => $rsHit->get_column('name'),
            description => $rsHit->get_column('description'),
            startdate => $rsHit->get_column('startdate'),
            enddate => $rsHit->get_column('enddate')
        );
    }
    else { # create new record
        $template->param( adding => 1 );
    }

    $template->param(
        statisticstype => $statisticstype,
        statisticstypedesignation => $statisticstypedesignation,
    );


    # the handling of aggregated_statistics_parameters depends on statisticstype
print STDERR "aggregated_statistics::add_form statisticstype:$statisticstype: eq DBS:", $statisticstype eq 'DBS', ":\n" if $debug;
    if ( $statisticstype eq 'DBS' ) {

        #XXXWH use C4::AggregatedStatistics::DBS;
        #XXXWH eval {use C4::AggregatedStatistics::DBS};
        eval "use C4::AggregatedStatistics::$statisticstype";

print STDERR "aggregated_statistics::add_form NOW IS CALLING C4::AggregatedStatistics::DBS::add_form_parameters(...)\n" if $debug;
        C4::AggregatedStatistics::DBS::add_form_parameters($template, $input, $aggregatedStatisticsId);


    }

    return;
}

# evaluate the form for adding / editing / copying an aggregated_statistics record
sub add_validate {
    my $statisticstype = $input->param('statisticstype');
    my $name           = $input->param('name');
    my $description    = $input->param('description');
    my $startdateDB    = output_pref({ dt => dt_from_string( scalar $input->param('startdate') ), dateformat => 'iso', dateonly => 1 });
    my $enddateDB      = output_pref({ dt => dt_from_string( scalar $input->param('enddate') ), dateformat => 'iso', dateonly => 1 });
    my $op             = $input->param('op');

    my %param;

print STDERR "aggregated_statistics::add_validate  op:$op: statisticstype:$statisticstype: name:$name: id:$id:\n" if $debug;
print STDERR "aggregated_statistics::add_validate  op:$op: input->param(selectedgroup):", scalar $input->param('selectedgroup'), ": input->param(selectedbranch):", scalar $input->param('selectedbranch'), ":\n" if $debug;
    if ( $op eq 'copy_validate' ) {
        $param{'type'} = $statisticstype;
        $param{'name'} = $name;
        $param{'description'} = $description;
        $param{'startdate'} = $startdateDB;
        $param{'enddate'}   = $enddateDB;
    } else {
        
print STDERR "aggregated_statistics::add_validate op ne 'copy_validate'   id:", $id, ":\n" if $debug;
        $param{'id'} = $id;
        $param{'type'} = $statisticstype;
        $param{'name'} = $name;
        $param{'description'} = $description;
        $param{'startdate'} = $startdateDB;
        $param{'enddate'}   = $enddateDB;
    }
    my $aggregatedStatistics = C4::AggregatedStatistics::CreateAggregatedStatistics(\%param);

    # the handling of aggregated_statistics_parameters and aggregated_statistics_values depends on statisticstype
print STDERR "aggregated_statistics::add_validate statisticstype:$statisticstype: eq DBS:", $statisticstype eq 'DBS', ":\n" if $debug;
    if ( $statisticstype eq 'DBS' ) {
        eval {use C4::AggregatedStatistics::DBS};
print STDERR "aggregated_statistics::add_validate NOW IS CALLING C4::AggregatedStatistics::DBS::add_validate_parameters(...)\n" if $debug;
        C4::AggregatedStatistics::DBS::add_validate_parameters($input, $aggregatedStatistics->_resultset()->get_column('id'));
        if ( $op eq 'copy_validate' ) {
            C4::AggregatedStatistics::DBS::copy_ag_values($id, $aggregatedStatistics->_resultset()->get_column('id'));
            C4::AggregatedStatistics::DBS::recalculate_ag_values($aggregatedStatistics->_resultset()->get_column('id'), $startdateDB, $enddateDB);
        }
    }

print STDERR "aggregated_statistics::add_validate result \$!:$!:\n";
    # set up default display
    default_display($statisticstype);
    return 1;
}

# prepare the form for deleting an aggregated_statistics record
sub delete_confirm {
print STDERR "aggregated_statistics::delete_confirm  op:$op: statisticstype:$statisticstype: name:$name:\n" if $debug;
    my $aggregatedStatistics = C4::AggregatedStatistics::GetAggregatedStatistics(
        {
            type => $statisticstype,
            name => $name,
        }
    );
    if ($aggregatedStatistics && $aggregatedStatistics->_resultset() && $aggregatedStatistics->_resultset()->first()) {
        my $rsHit = $aggregatedStatistics->_resultset()->first();
        my $hit = {
            id => $rsHit->get_column('id'),
            type => $rsHit->get_column('type'),
            name => $rsHit->get_column('name'),
            description => $rsHit->get_column('description'),
            startdate => $rsHit->get_column('startdate'),
            enddate => $rsHit->get_column('enddate')
        };
        $template->param(
            hit => $hit,
        );
    }

    return;
}

# evaluate the form for deleting an aggregated_statistics record
sub delete_confirmed {
    C4::AggregatedStatistics::DelAggregatedStatistics(
        {
            type => $statisticstype,
            name => $name,
        }
    );
    # setup default display for screen
    default_display($statisticstype);
    return;
}

# prepare the form for evaluating / editing the specific statistics (e.g. DBS)
sub eval_form {
    # the evaluation depends on statisticstype
print STDERR "aggregated_statistics::eval_form Sart statisticstype:$statisticstype: eq DBS:", $statisticstype eq 'DBS', ": id:$id: op:$op: input:", $input, ":\n" if $debug;
    if ( $statisticstype eq 'DBS' ) {
        eval {use C4::AggregatedStatistics::DBS};
print STDERR "aggregated_statistics::eval_form NOW IS CALLING C4::AggregatedStatistics::DBS::eval_form(...)\n" if $debug;
        if ( $op eq 'dbs_calc' ) {
            C4::AggregatedStatistics::DBS::eval_form($script_name, $input, $id, $input);    # take values from 4th argument (i.e. from %input in this case)
        } else {
            C4::AggregatedStatistics::DBS::eval_form($script_name, $input, $id);    # read values from table aggregated_statistics_values
        }
    } else {
        # not implemented for remaining statistics types, so avoid HTTP error 500:
        default_display($statisticstype);
        $op = q{}; # next operation is to return to default screen
    }
}

sub default_display {
    my ($statisticstype) = @_;
print STDERR "aggregated_statistics::default_display  op:$op: statisticstype:$statisticstype: name:$name:\n" if $debug;

    unless ( defined $statisticstype ) {
        $statisticstype = 'DBS';
    }
    my $results = &retrieve_aggregated_statistics($statisticstype);

    my $loop_data = [];
    foreach my $row (@{$results}) {
        push @{$loop_data}, $row;

    }

    $template->param(
        hits => $loop_data,
        statisticstypeloop => &statisticstypeloop($statisticstype),
    );
}

sub retrieve_aggregated_statistics {
    my ($statisticstype, $searchstring) = @_;
print STDERR "aggregated_statistics::retrieve_aggregated_statistics  statisticstype:$statisticstype: searchstring:$searchstring:\n";
    my @hits;
    my $aggregatedStatistics = C4::AggregatedStatistics::GetAggregatedStatistics(
        {
            type => $statisticstype
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

# lists types of aggregated statistics that are supported
sub statisticstypeloop {
    my ($preselectedstatisticstype) = @_;

    # build array of aggregated statistics types (currently this is 'DBS' only; can be extended in the future, even by "select distinct type from aggregated_statistics" etc.)
    my $statisticstypes = {};
    $statisticstypes->{'DBS'}->{'designation'} = 'Deutsche Bibliotheksstatistik';
# XXXWH hau wech    $statisticstypes->{'TEST1'}->{'designation'} = 'Statistiktyp TEST1';    # XXXWH hau wech
# XXXWH hau wech    $statisticstypes->{'TEST2'}->{'designation'} = 'Statistiktyp TEST2';    # XXXWH hau wech

    my @statisticstypeloop;
    for my $statisticstype (sort { $statisticstypes->{$a}->{designation} cmp $statisticstypes->{$b}->{designation} } keys %$statisticstypes) {
        push @statisticstypeloop, {
            value      => $statisticstype,
            selected   => $preselectedstatisticstype && $statisticstype eq $preselectedstatisticstype,
            designation => $statisticstypes->{$statisticstype}->{'designation'},
        };
    }

    return \@statisticstypeloop;
}
