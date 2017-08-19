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
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Branch;
use C4::Circulation;
use Koha::Libraries;
use Koha::LibraryCategories;
use Koha::Issues;
use Koha::DateUtils;

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
    my $datedues = Koha::Issues->getIssueDatesAndBranches({ categorycode => $groupselect, branchcode => $branchselect });
    foreach my $duedate ( sort { $a cmp $b } keys %$datedues ) {
        push @duedates, [ $duedate, $datedues->{$duedate} ];
    }
    $founddates = scalar(@duedates);
}


########################################
#  Read branches
########################################
my $branches = GetBranches();
my @branchloop;
for my $thisbranch (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %$branches) {
    push @branchloop, {
        value      => $thisbranch,
        selected   => $thisbranch eq $branch,
        branchname => $branches->{$thisbranch}->{'branchname'},
        branchcode => $branches->{$thisbranch}->{'branchcode'},
        category   => $branches->{$thisbranch}->{'category'}
    };
}

########################################
#  Read library categories
########################################
my @categories;
for my $category ( Koha::LibraryCategories->search ) {
    push @categories, $category->unblessed();
}



########################################
#  Read message transport types
########################################
my @line_loop;
my $message_transport_types = C4::Letters::GetMessageTransportTypes();


########################################
#  Set template paramater
########################################
$template->param(
                        humanbranch => ($branch ne '*' ? $branches->{$branch}->{branchname} : ''),
                        current_branch => $branch,
                        branchloop => \@branchloop,
                        branch => $branch,
                        categories => \@categories,
                        duedates => \@duedates,
                        founddates => $founddates,
                        branches => $branches,
                        selectedgroup => $selectedgroup,
                        selectedbranch => $selectedbranch,
                        processerrors => \@errors,
                        itemschanged => $itemschanged,
                        action => $op
                        
);
output_html_with_http_headers $input, $cookie, $template->output;

