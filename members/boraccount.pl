#!/usr/bin/perl


#written 11/1/2000 by chris@katipo.oc.nz
#script to display borrowers account details


# Copyright 2000-2002 Katipo Communications
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

use C4::Auth;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Members;
use C4::Branch;
use C4::Accounts;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::CashRegisterManagement qw(passCashRegisterCheck);
use Koha::Patron::Images;

my $input=new CGI;


my ($template, $loggedinuser, $cookie) = get_template_and_user(
    {
        template_name   => "members/boraccount.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers     => 1,
                             updatecharges => 'remaining_permissions'},
        debug           => 1,
    }
);

my $borrowernumber=$input->param('borrowernumber');
my $action = $input->param('action') || '';

#get borrower details
my $data=GetMember('borrowernumber' => $borrowernumber);

my $branch = C4::Context->userenv->{'branch'};
my $checkCashRegisterOk = passCashRegisterCheck($branch,$loggedinuser);

if ( $action eq 'reverse' && $checkCashRegisterOk ) {
  ReversePayment( $input->param('accountlines_id') );
}

if ( $data->{'category_type'} eq 'C') {
   my  ( $catcodes, $labels ) =  GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
   my $cnt = scalar(@$catcodes);
   $template->param( 'CATCODE_MULTI' => 1) if $cnt > 1;
   $template->param( 'catcode' =>    $catcodes->[0])  if $cnt == 1;
}

#get account details
my ($total,$accts,undef)=GetMemberAccountRecords($borrowernumber);
my $totalcredit;
if($total <= 0){
        $totalcredit = 1;
}

my $reverse_col = 0; # Flag whether we need to show the reverse column
foreach my $accountline ( @{$accts}) {
    $accountline->{amount} += 0.00;
    if ($accountline->{amount} <= 0 ) {
        $accountline->{amountcredit} = 1;
    }
    $accountline->{amountoutstanding} += 0.00;
    if ( $accountline->{amountoutstanding} <= 0 ) {
        $accountline->{amountoutstandingcredit} = 1;
    }

    $accountline->{amount} = sprintf '%.2f', $accountline->{amount};
    $accountline->{amountoutstanding} = sprintf '%.2f', $accountline->{amountoutstanding};
    if ($accountline->{accounttype} =~ /^Pay/) {
        $accountline->{payment} = 1;
        $reverse_col = 1;
    }
}

$template->param( adultborrower => 1 ) if ( $data->{'category_type'} eq 'A' );

my $patron_image = Koha::Patron::Images->find($data->{borrowernumber});
$template->param( picture => 1 ) if $patron_image;

if (C4::Context->preference('ExtendedPatronAttributes')) {
    my $attributes = GetBorrowerAttributes($borrowernumber);
    $template->param(
        ExtendedPatronAttributes => 1,
        extendedattributes => $attributes
    );
}

$template->param(%$data);

$template->param(
    finesview           => 1,
    borrowernumber      => $borrowernumber,
    branchname          => GetBranchName($data->{'branchcode'}),
    total               => sprintf("%.2f",$total),
    totalcredit         => $totalcredit,
    is_child            => ($data->{'category_type'} eq 'C'),
    reverse_col         => $reverse_col,
    accounts            => $accts,
    checkCashRegisterFailed => (! $checkCashRegisterOk),
    activeBorrowerRelationship => (C4::Context->preference('borrowerRelationship') ne ''),
    RoutingSerials => C4::Context->preference('RoutingSerials'),
);

output_html_with_http_headers $input, $cookie, $template->output;
