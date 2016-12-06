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
use C4::Auth qw/:DEFAULT get_session/;
use C4::Koha;
use C4::Branch;
use Koha::DateUtils;
use C4::CashRegisterManagement;

##########################################################
#
# Initialize seesion and parameters
#
##########################################################
my $query = CGI->new();
my ( $template, $loggedinuser, $cookie ) = get_template_and_user({
    template_name   => "circ/managecashregister.tt",
    query           => $query,
    type            => "intranet",
    debug           => 1,
    authnotrequired => 0,
    flagsrequired   => { updatecharges => 'cash_management' },
});
my $sessionID = $query->cookie("CGISESSID");
my $session = get_session($sessionID);
if ($session->param('branch') eq 'NO_LIBRARY_SET'){
    # no branch set we can't return
    print $query->redirect("/cgi-bin/koha/circ/managecashregister.pl");
    exit;
}
my $branch = $session->param('branch');

my $status = '';
my $debug = '';

########################################
#  Read branches
########################################
my $branches = GetBranches();
my @branchloop;
for my $thisbranch (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %$branches) {
    push @branchloop, $branches->{$thisbranch};
}

##########################################################
#
# Check, whether there are open cash registers of the user
#
##########################################################
my $cash_management = C4::CashRegisterManagement->new($branch,$loggedinuser);

my @cash_registers = $cash_management->getPermittedCashRegisters($loggedinuser);
my $cash_register = $cash_management->getOpenCashRegister($loggedinuser);
if ( $cash_register ) {
    if ( $cash_register->{cash_register_branchcode} ne $branch ) {
        $status = 'close';
    } else {
        $status = 'manage';
    }
}
elsif ( scalar(@cash_registers)>0 ) {
    $status = 'open';
}
elsif ( scalar(@cash_registers)==0 ) {
    $status = 'no';
}

##########################################################
#
# Check, whether there are open cash registers of the user
#
##########################################################
my $op = $query->param('op') || '';
my $cash_register_id = $query->param('cash_register_id');
my $lastTransaction = undef;

my $manageaction = 'journal';
my $cash_register_info;

# we only try to open a cash register if there is no opened cash register
# of the user
if ( $op eq 'open' && $status eq 'open' && $cash_register_id) {
    my $cashreg = $cash_management->loadCashRegister($cash_register_id);
    if ( $cashreg && !$cashreg->{cash_register_manager_id} ) {
        if ( $cash_management->openCashRegister($cash_register_id, $loggedinuser) ) {
            $status = 'manage';
            $cash_register = $cash_management->getOpenCashRegister($loggedinuser);
            # redirect to self to avoid form submission on refresh
            print $query->redirect("/cgi-bin/koha/circ/managecashregister.pl");
        }
    }
}
elsif (  $op eq 'close' && ($status eq 'close' || $status eq 'manage') && $cash_register_id ) {
    my $cashreg = $cash_management->loadCashRegister($cash_register_id);
    if ( $cashreg && $cashreg->{cash_register_manager_id} ) {
        if ( $cash_management->closeCashRegister($cash_register_id, $loggedinuser) ) {
            $status = 'open';
            # redirect to self to avoid form submission on refresh
            print $query->redirect("/cgi-bin/koha/circ/managecashregister.pl");
        }
    }
}
elsif ( $op eq 'dopayout' && $status eq 'manage' ) {
    $manageaction = 'payout';
    $template->param( 
        description => '',
        cash_payment => '0.00'
    );
}
elsif ( $op eq 'doadjust' && $status eq 'manage' ) {
    $manageaction = 'adjust';
    $template->param( 
        description => '',
        cash_adjustment => '0.00'
    );
}
elsif ( $op eq 'doclose' && $status eq 'manage' ) {
    $manageaction = 'close';
}
elsif ( $op eq 'payout' && $status eq 'manage' ) {
    my $cash_payment = $query->param('cash_payment');
    my $description = $query->param('description');
    my $current_balance = $cash_management->getCurrentBalance($cash_register_id);
    if ( $cash_payment && $cash_payment > 0.00 && $cash_payment <= $current_balance ) {
        $cash_management->registerCashPayment($branch, $loggedinuser, $cash_payment, $description);

        # redirect to self to avoid form submission on refresh
        print $query->redirect("/cgi-bin/koha/circ/managecashregister.pl");
    }
    else {
        $manageaction = 'payout';
        $template->param( 
            description => $description,
            cash_payment => $cash_payment
        );
    }
}
elsif ( $op eq 'adjust' && $status eq 'manage' ) {
    my $cash_adjustment = $query->param('cash_adjustment');
    my $description = $query->param('description');
    my $current_balance = $cash_management->getCurrentBalance($cash_register_id);
    if ( $cash_adjustment && $cash_adjustment != 0.00 
        && !($current_balance < 0.00 && $cash_adjustment < 0.00)
        && !($current_balance >= 0.00 && ($cash_adjustment+$current_balance) < 0.00) ) {
        $cash_management->registerAdjustment($branch, $loggedinuser, $cash_adjustment, $description);
        $manageaction = 'journal';
        
        # redirect to self to avoid form submission on refresh
        print $query->redirect("/cgi-bin/koha/circ/managecashregister.pl");
    }
    else {
        $manageaction = 'adjust';
        $template->param( 
            description => $description,
            cash_adjustment => $cash_adjustment
        );
    }
}

my ($journalfrom,$journalto);

my $wrongBranch=0;
my @transactions = ();
if ( $cash_register ) {
    $lastTransaction = $cash_management->getLastBooking($cash_register->{cash_register_id});
    $cash_register_info = $cash_management->getCashRegisterHandoverInformationByLastOpeningAction($cash_register->{cash_register_id});
    if ( $cash_register->{cash_register_branchcode} ne $branch ) {
        $wrongBranch = 1;
    }
    if ( $status eq 'manage' && $manageaction eq 'journal' ) {
        $journalfrom = $query->param('journalfrom');
        $journalto = $query->param('journalto');
        my $allFromOpening = $query->param('allFromOpening');
        my $trans;
        if ($allFromOpening) {
            $trans = $cash_management->getBookingsSinceLastOpening($cash_register->{cash_register_id});
        } else {
            ($trans,$journalfrom,$journalto) = $cash_management->getLastBookingsFromTo($cash_register->{cash_register_id}, $journalfrom, $journalto);
        }
        @transactions = @$trans;
    }
}

#use Data::Dumper;
#$debug = Dumper($cash_register_info);

$template->param(
    status => $status,
    cash_registers => \@cash_registers,
    cash_register => $cash_register,
    branchloop => \@branchloop,
    lastTransaction => $lastTransaction,
    sessionbranch => $branch,
    wrongBranch => $wrongBranch,
    transactions => \@transactions,
    journalfrom => $journalfrom,
    journalto => $journalto,
    manageaction => $manageaction,
    cash_register_info => $cash_register_info,
    debug => $debug
);

output_html_with_http_headers $query, $cookie, $template->output;

exit 0;
