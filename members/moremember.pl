#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# Copyright 2010 BibLibre
# Copyright 2014 ByWater Solutions
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


=head1 moremember.pl

 script to do a borrower enquiry/bring up borrower details etc
 Displays all the details about a borrower
 written 20/12/99 by chris@katipo.co.nz
 last modified 21/1/2000 by chris@katipo.co.nz
 modified 31/1/2001 by chris@katipo.co.nz
   to not allow items on request to be renewed

 needs html removed and to use the C4::Output more, but its tricky

=cut

use strict;
#use warnings; FIXME - Bug 2505
use CGI qw ( -utf8 );
use Digest::MD5 qw(md5_base64);
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::AttributeTypes;
use C4::Reserves;
use C4::Circulation;
use C4::Koha;
use C4::Letters;
use C4::Biblio;
use C4::Branch; # GetBranchName
use C4::Form::MessagingPreferences;
use List::MoreUtils qw/uniq/;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::CashRegisterManagement qw(passCashRegisterCheck);
use Koha::Patron::Debarments qw(GetDebarments IsDebarred);
use Koha::Patron::Images;
use Module::Load;
if ( C4::Context->preference('NorwegianPatronDBEnable') && C4::Context->preference('NorwegianPatronDBEnable') == 1 ) {
    load Koha::NorwegianPatronDB, qw( NLGetSyncDataFromBorrowernumber );
}
#use Smart::Comments;
#use Data::Dumper;
use DateTime;
use Koha::DateUtils;
use Koha::Database;

use Koha::Patron::Categories;
use Koha::Token;

use vars qw($debug);

BEGIN {
	$debug = $ENV{DEBUG} || 0;
}

my $dbh = C4::Context->dbh;

my $input = CGI->new;
$debug or $debug = $input->param('debug') || 0;
my $print = $input->param('print');

my $template_name;
my $quickslip = 0;

my $flagsrequired;
if (defined $print and $print eq "page") {
    $template_name = "members/moremember-print.tt";
    # circ staff who process checkouts but can't edit
    # patrons still need to be able to access print view
    $flagsrequired = { circulate => "circulate_remaining_permissions" };
} elsif (defined $print and $print eq "slip") {
    $template_name = "members/moremember-receipt.tt";
    # circ staff who process checkouts but can't edit
    # patrons still need to be able to print receipts
    $flagsrequired =  { circulate => "circulate_remaining_permissions" };
} elsif (defined $print and $print eq "qslip") {
    $template_name = "members/moremember-receipt.tt";
    $quickslip = 1;
    $flagsrequired =  { circulate => "circulate_remaining_permissions" };
} elsif (defined $print and $print eq "brief") {
    $template_name = "members/moremember-brief.tt";
    $flagsrequired = { borrowers => 1 };
} else {
    $template_name = "members/moremember.tt";
    $flagsrequired = { borrowers => 1 };
}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => $template_name,
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => $flagsrequired,
        debug           => 1,
    }
);
my $borrowernumber = $input->param('borrowernumber');
my $error = $input->param('error');
$template->param( error => $error ) if ( $error );

my ( $od, $issue, $fines ) = GetMemberIssuesAndFines($borrowernumber);
$template->param( issuecount => $issue, fines => $fines );

my $data = GetMember( 'borrowernumber' => $borrowernumber );

if ( not defined $data ) {
    $template->param (unknowuser => 1);
	output_html_with_http_headers $input, $cookie, $template->output;
    exit;
}

my $category_type = $data->{'category_type'};

$debug and printf STDERR "dates (enrolled,expiry,birthdate) raw: (%s, %s, %s)\n", map {$data->{$_}} qw(dateenrolled dateexpiry dateofbirth);
foreach (qw(dateenrolled dateexpiry dateofbirth)) {
    my $userdate = $data->{$_};
    unless ($userdate) {
        $debug and warn sprintf "Empty \$data{%12s}", $_;
        $data->{$_} = '';
        next;
    }
    $template->param( $_ => dt_from_string( $userdate ) );
}
$data->{'IS_ADULT'} = ( $data->{'categorycode'} ne 'I' );

for (qw(gonenoaddress lost borrowernotes)) {
	 $data->{$_} and $template->param(flagged => 1) and last;
}

if ( IsDebarred($borrowernumber) ) {
    $template->param( 'userdebarred' => 1, 'flagged' => 1 );
    my $debar = $data->{'debarred'};
    if ( $debar ne "9999-12-31" ) {
        $template->param( 'userdebarreddate' => output_pref( { dt => dt_from_string( $debar ), dateonly => 1 } ) );
        $template->param( 'debarredcomment'  => $data->{debarredcomment} );
    }
}

$data->{ "sex_".$data->{'sex'}."_p" } = 1 if defined $data->{sex};

if ( $category_type eq 'C') {
   my  ( $catcodes, $labels ) =  GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
   my $cnt = scalar(@$catcodes);

   $template->param( 'CATCODE_MULTI' => 1) if $cnt > 1;
   $template->param( 'catcode' =>    $catcodes->[0])  if $cnt == 1;
}

my $patron = Koha::Patrons->find($data->{borrowernumber});
my @relatives;
if ( my $guarantor = $patron->guarantor ) {
    $template->param( guarantor => $guarantor );
    push @relatives, $guarantor->borrowernumber;
    push @relatives, $_->borrowernumber for $patron->siblings;
} elsif ( $patron->contactname || $patron->contactfirstname ) {
    $template->param(
        guarantor => {
            firstname => $patron->contactfirstname,
            surname   => $patron->contactname,
        }
    );
} else {
    my @guarantees = $patron->guarantees;
    $template->param( guarantees => \@guarantees );
    push @relatives, $_->borrowernumber for @guarantees;
}

my $relatives_issues_count =
  Koha::Database->new()->schema()->resultset('Issue')
  ->count( { borrowernumber => \@relatives } );

$template->param( adultborrower => 1 ) if ( $category_type eq 'A' || $category_type eq 'I' );

my %bor;
$bor{'borrowernumber'} = $borrowernumber;

# Converts the branchcode to the branch name
my $samebranch;
if ( C4::Context->preference("IndependentBranches") ) {
    my $userenv = C4::Context->userenv;
    if ( C4::Context->IsSuperLibrarian() ) {
        $samebranch = 1;
    }
    else {
        $samebranch = ( $data->{'branchcode'} eq $userenv->{branch} );
    }
}
else {
    $samebranch = 1;
}
my $library = Koha::Libraries->find( $data->{branchcode})->unblessed;
@{$data}{keys %$library} = values %$library; # merge in all branch columns

my ( $total, $accts, $numaccts) = GetMemberAccountRecords( $borrowernumber );
my $lib1 = &GetSortDetails( "Bsort1", $data->{'sort1'} );
my $lib2 = &GetSortDetails( "Bsort2", $data->{'sort2'} );
$template->param( lib1 => $lib1 ) if ($lib1);
$template->param( lib2 => $lib2 ) if ($lib2);

# If printing a page, send the account informations to the template
if ($print eq "page") {
    foreach my $accountline (@$accts) {
        $accountline->{amount} = sprintf '%.2f', $accountline->{amount};
        $accountline->{amountoutstanding} = sprintf '%.2f', $accountline->{amountoutstanding};

        if ($accountline->{accounttype} ne 'F' && $accountline->{accounttype} ne 'FU'){
            $accountline->{printtitle} = 1;
        }
    }
    $template->param( accounts => $accts );
}

# Show OPAC privacy preference is system preference is set
if ( C4::Context->preference('OPACPrivacy') ) {
    $template->param( OPACPrivacy => 1);
    $template->param( "privacy".$data->{'privacy'} => 1);
}

my $today       = DateTime->now( time_zone => C4::Context->tz);
$today->truncate(to => 'day');
my $overdues_exist = 0;
my $totalprice = 0;

# Calculate and display patron's age
my $dateofbirth = $data->{ 'dateofbirth' };
my $age = GetAge($dateofbirth);
$template->param( age => $age );

### ###############################################################################
# BUILD HTML
# show all reserves of this borrower, and the position of the reservation ....
if ($borrowernumber) {
    $template->param(
        holds_count => Koha::Database->new()->schema()->resultset('Reserve')
          ->count( { borrowernumber => $borrowernumber } ) );
}

# current alert subscriptions
my $alerts = getalert($borrowernumber);
foreach (@$alerts) {
    $_->{ $_->{type} } = 1;
    $_->{relatedto} = findrelatedto( $_->{type}, $_->{externalid} );
}

# Add sync data to the user data
if ( C4::Context->preference('NorwegianPatronDBEnable') && C4::Context->preference('NorwegianPatronDBEnable') == 1 ) {
    my $sync = NLGetSyncDataFromBorrowernumber( $borrowernumber );
    if ( $sync ) {
        $data->{'sync'}       = $sync->sync;
        $data->{'syncstatus'} = $sync->syncstatus;
        $data->{'lastsync'}   = $sync->lastsync;
    }
}

# check to see if patron's image exists in the database
# basically this gives us a template var to condition the display of
# patronimage related interface on
my $patron_image = Koha::Patron::Images->find($data->{borrowernumber});
$template->param( picture => 1 ) if $patron_image;
# Generate CSRF token for upload and delete image buttons
$template->param(
    csrf_token => Koha::Token->new->generate_csrf({ session_id => $input->cookie('CGISESSID'),}),
);

my $branch=C4::Context->userenv->{'branch'};

$template->param(%$data);

if (C4::Context->preference('ExtendedPatronAttributes')) {
    my $attributes = C4::Members::Attributes::GetBorrowerAttributes($borrowernumber);
    my @classes = uniq( map {$_->{class}} @$attributes );
    @classes = sort @classes;

    my @attributes_loop;
    for my $class (@classes) {
        my @items;
        for my $attr (@$attributes) {
            push @items, $attr if $attr->{class} eq $class
        }
        my $lib = GetAuthorisedValueByCode( 'PA_CLASS', $class ) || $class;
        push @attributes_loop, {
            class => $class,
            items => \@items,
            lib   => $lib,
        };
    }

    $template->param(
        ExtendedPatronAttributes => 1,
        attributes_loop => \@attributes_loop
    );

    my @types = C4::Members::AttributeTypes::GetAttributeTypes();
    if (scalar(@types) == 0) {
        $template->param(no_patron_attribute_types => 1);
    }
}

if (C4::Context->preference('EnhancedMessagingPreferences')) {
    C4::Form::MessagingPreferences::set_form_values({ borrowernumber => $borrowernumber }, $template);
    $template->param(messaging_form_inactive => 1);
    $template->param(SMSSendDriver => C4::Context->preference("SMSSendDriver"));
    $template->param(SMSnumber     => $data->{'smsalertnumber'});
    $template->param(TalkingTechItivaPhone => C4::Context->preference("TalkingTechItivaPhoneNotification"));
}

# Check whether the library uses cash registers and if so, that the current staff user
# has opened the cash for payment actions
my $checkCashRegisterOk = passCashRegisterCheck($branch,$loggedinuser);

# in template <TMPL_IF name="I"> => instutitional (A for Adult, C for children) 
$template->param( $data->{'categorycode'} => 1 ); 
$template->param(
    detailview => 1,
    borrowernumber  => $borrowernumber,
    othernames      => $data->{'othernames'},
    categoryname    => $data->{'description'},
    was_renewed     => scalar $input->param('was_renewed') ? 1 : 0,
    branch          => $branch,
    todaysdate      => output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 }),
    totalprice      => sprintf("%.2f", $totalprice),
    totaldue        => sprintf("%.2f", $total),
    totaldue_raw    => $total,
    overdues_exist  => $overdues_exist,
    StaffMember     => ($category_type eq 'S'),
    is_child        => ($category_type eq 'C'),
    samebranch      => $samebranch,
    quickslip       => $quickslip,
    privacy_guarantor_checkouts => $data->{'privacy_guarantor_checkouts'},
    AutoResumeSuspendedHolds => C4::Context->preference('AutoResumeSuspendedHolds'),
    SuspendHoldsIntranet => C4::Context->preference('SuspendHoldsIntranet'),
    RoutingSerials => C4::Context->preference('RoutingSerials'),
    debarments => GetDebarments({ borrowernumber => $borrowernumber }),
    PatronsPerPage => C4::Context->preference("PatronsPerPage") || 20,
    relatives_issues_count => $relatives_issues_count,
    relatives_borrowernumbers => \@relatives,
    checkCashRegisterFailed   => (! $checkCashRegisterOk)
);

output_html_with_http_headers $input, $cookie, $template->output;
