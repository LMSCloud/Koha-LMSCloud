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
use Koha::Libraries;
use C4::CashRegisterManagement;

our $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/cash-register-management.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'cash_register_manage' },
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

my $action = '';

###########################################################
# load all staff data that is involved with cash registers
###########################################################

my $cashmanagement = C4::CashRegisterManagement->new($branch, $loggedinuser);

my $cash_register=undef;
my @enabled_staff = ();
my %staff_enabled = ();
my $cash_register_id = undef;

if ( $op eq 'new' ) {
    $action = 'edit';
}
elsif ( $op eq 'edit' ) {
    $action = 'edit';
    $cash_register_id = $input->param('cash_register_id') ;
}
elsif ( $op eq 'save' ) {
    $action = '';

    $cash_register_id = $input->param('cash_register_id') ;
    my $cash_register_name = $input->param('cash_register_name') ;
    my $cash_register_branchcode = $input->param('cash_register_branchcode') ;
    my $cash_register_no_branch_restriction = $input->param('cash_register_no_branch_restriction') ;
    
    my $params = {};
    $params->{name}                    = $cash_register_name if ( defined($cash_register_name) );
    $params->{branchcode}              = $cash_register_branchcode if ( defined($cash_register_branchcode));
    $params->{no_branch_restriction}   = ($cash_register_no_branch_restriction ? 1 : 0);
    
    my $manager_list = $input->param('cash_register_manager_list') || '';
    
    $cash_register = $cashmanagement->saveCashRegister(
        $params, 
        $manager_list, 
        $cash_register_id);
    $cash_register_id = $cash_register->id();
    
    print $input->redirect("/cgi-bin/koha/tools/cash-register-management.pl");
}

if ( $cash_register_id ) {
    $template->param( %{$cashmanagement->loadCashRegister($cash_register_id)});
    @enabled_staff = $cashmanagement->getEnabledStaff($cash_register_id);
}

########################################
#  Read permitted staff (either superlibrarians or staff with permission 'cash_management'
########################################
my @permitted_staff = $cashmanagement->readPermittedStaff($cash_register_id);

########################################
# Read cash registers
########################################
if ( $action ne 'edit' ) {
    my @cash_registers = $cashmanagement->getAllCashRegisters();
    $template->param( cash_registers => \@cash_registers );
}
########################################
#  Set template paramater
########################################
$template->param(
                        branch => $branch,
                        permitted_staff => \@permitted_staff,
                        enabled_staff => \@enabled_staff,
                        action => $action
);
output_html_with_http_headers $input, $cookie, $template->output;

exit 0;
