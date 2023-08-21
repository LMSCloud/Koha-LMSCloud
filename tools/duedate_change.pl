#!/usr/bin/perl

# Copyright 2016 LMSCLoud GmbH
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
use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use C4::Auth qw( get_template_and_user );
use C4::Koha;
use C4::Circulation qw( SetDueDateOfItems );
use Koha::Libraries;
use Koha::Library::Groups;
use Koha::Checkouts;
use Koha::DateUtils qw ( output_pref dt_from_string );

my $input = new CGI;
my $dbh = C4::Context->dbh;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/duedate_change.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'duedate_update' },
        debug           => 1,
    }
);

my $branch = $input->param('branch');
$branch =
    defined $branch                                                    ? $branch
  : Koha::Libraries->search->count() == 1                              ? undef
  :                                                                      undef;
$branch ||= q{};
$branch = q{} if $branch eq 'NO_LIBRARY_SET';

my $op = $input->param('op');
$op ||= q{};

my @duedates;
my $founddates=0;

my $selectedgroup  = $input->param('groupselect') || '*';
my $selectedbranch = $input->param('branchselect') || '*';

########################################
#  Process the request
########################################
my $groupselect = $input->param('groupselect');
$groupselect = '' if ( defined($groupselect) and $groupselect eq '*' );
my $branchselect = $input->param('branchselect');
$branchselect = '' if ( defined($branchselect) and $branchselect eq '*' );

my @errors = ();
my $itemschanged = 0;
    
if ($op eq 'update' ) {
    my $duedates = $input->param('duedates');
    my $getdate = $input->param('newduedate');
    my $parsedate = eval { dt_from_string( $getdate ) };
    my $newduedate = undef;
    $newduedate = output_pref ( { dt => $parsedate, dateonly => 1, dateformat => 'iso' } ) if ( $parsedate );
    
    my $paramgrpoup = $input->param('groupselect');
    my $parambranch = $input->param('branchselect');
    
    foreach my $currentDueDate( split(/\r\n/,$duedates) ) {
        my ($cnt,$error) = SetDueDateOfItems( 
                { 
                    currentDueDate => $currentDueDate, 
                    newDueDate => $newduedate, 
                    libraryCategory => $paramgrpoup,
                    branchcode => $parambranch
                });
        $itemschanged += $cnt;
        if ( defined($error) && $error ne '' ) {
            push @errors, { errorcode => $error, currentDueDate => $currentDueDate, newDueDate => $newduedate };
        }
    }
    $op = 'select';
}
if ($op eq 'select') {
    my $datedues = Koha::Checkouts->get_issue_dates_and_branches({ categorycode => $groupselect, branchcode => $branchselect });
    foreach my $duedate ( sort { $a cmp $b } keys %$datedues ) {
        push @duedates, [ $duedate, $datedues->{$duedate} ];
    }
    $founddates = scalar(@duedates);
}

########################################
#  Read library groups
########################################
my @search_groups = Koha::Library::Groups->get_search_groups( { interface => 'staff' } )->as_list;
@search_groups = sort { $a->title cmp $b->title } @search_groups;


########################################
#  Set template paramater
########################################
$template->param(
                        branch => $branch,
                        librarygroups => \@search_groups,
                        duedates => \@duedates,
                        founddates => $founddates,
                        selectedgroup => $selectedgroup,
                        selectedbranch => $selectedbranch,
                        processerrors => \@errors,
                        itemschanged => $itemschanged,
                        action => $op
                        
);
output_html_with_http_headers $input, $cookie, $template->output;

