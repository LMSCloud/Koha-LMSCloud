#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# Copyright 2010 BibLibre
# Copyright 2010,2011 PTFS-Europe Ltd
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

=head1 pay.pl

 written 11/1/2000 by chris@katipo.oc.nz
 part of the koha library system, script to facilitate paying off fines

=cut

use Modern::Perl;

use URI::Escape;
use C4::Context;
use C4::Auth;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Members;
use C4::Accounts;
use C4::Stats;
use C4::Koha;
use C4::Overdues;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::CashRegisterManagement qw(passCashRegisterCheck);
use Koha::Patrons;

use Koha::Patron::Categories;
use URI::Escape;

use Koha::Patron::Categories;
use URI::Escape;

our $input = CGI->new;

my $updatecharges_permissions = $input->param('woall') ? 'writeoff' : $input->param('cancelall') ? 'cancel_fee': 'remaining_permissions';
our ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => 'members/pay.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 'edit_borrowers', updatecharges => $updatecharges_permissions },
        debug           => 1,
    }
);

my @names = $input->param;

our $borrowernumber = $input->param('borrowernumber');
if ( !$borrowernumber ) {
    $borrowernumber = $input->param('borrowernumber0');
}

# get borrower details
my $logged_in_user = Koha::Patrons->find( $loggedinuser ) or die "Not logged in";
our $patron         = Koha::Patrons->find($borrowernumber);
output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

our $user = $input->remote_user;
$user ||= q{};

our $branch = C4::Context->userenv->{'branch'};

my $checkCashRegisterOk = passCashRegisterCheck($branch,$loggedinuser);

my $writeoff_item = $input->param('confirm_writeoff');
my $cancel_item = $input->param('confirm_cancelfee');
my $paycollect    = $input->param('paycollect');
if ($paycollect && $checkCashRegisterOk ) {
    print $input->redirect(
        "/cgi-bin/koha/members/paycollect.pl?borrowernumber=$borrowernumber");
}
my $payselected = $input->param('payselected');
if ($payselected && $checkCashRegisterOk) {
    payselected(@names);
}

my $writeoff_all = $input->param('woall');    # writeoff all fines
my $cancel_all   = $input->param('cancelall');    # cancel all fines
if ($writeoff_all || $cancel_all) {
    writeoff_or_cancel_all(@names);
} elsif ($writeoff_item || $cancel_item) {
    my $accountlines_id = $input->param('accountlines_id');
    my $amount       = $input->param('amountwrittenoff');
    my $payment_note = $input->param("payment_note");

    my $accountline = Koha::Account::Lines->find( $accountlines_id );

    $amount = $accountline->amountoutstanding if (abs($amount - $accountline->amountoutstanding) < 0.01);
    if ( $amount > $accountline->amountoutstanding ) {
        my $redirectURL = "/cgi-bin/koha/members/paycollect.pl?"
            . "borrowernumber=$borrowernumber"
            . "&amount=" . $accountline->amount
            . "&amountoutstanding=" . $accountline->amountoutstanding
            . "&accounttype=" . $accountline->accounttype
            . "&accountlines_id=" . $accountlines_id
            . "&error_over=1";
        if ($cancel_item) {
            $redirectURL .= "&cancel_individual=1";
        } else {
            $redirectURL .= "&writeoff_individual=1";
        }
        print $input->redirect( $redirectURL );

    } else {
        my $actiontype = $cancel_item ? 'cancelfee' : 'writeoff';
        Koha::Account->new( { patron_id => $borrowernumber } )->pay(
            {
                amount     => $amount,
                lines      => [ scalar Koha::Account::Lines->find($accountlines_id) ],
                type       => $actiontype,
                note       => $payment_note,
                library_id => $branch,
            }
        );
    }
}

for (@names) {
    if (/^pay_indiv_(\d+)$/) {
        my $line_no = $1;
        redirect_to_paycollect( 'pay_individual', $line_no );
    } elsif (/^wo_indiv_(\d+)$/) {
        my $line_no = $1;
        redirect_to_paycollect( 'writeoff_individual', $line_no );
    } elsif (/^cancel_indiv_(\d+)$/) {
        my $line_no = $1;
        redirect_to_paycollect( 'cancel_individual', $line_no );
    }
}

$template->param(
    finesview => 1,
    checkCashRegisterFailed   => (! $checkCashRegisterOk)
);

add_accounts_to_template();

output_html_with_http_headers $input, $cookie, $template->output;

sub add_accounts_to_template {

    my $patron = Koha::Patrons->find( $borrowernumber );
    my $account_lines = $patron->account->outstanding_debits;
    my $total = $account_lines->total_outstanding;
    my @accounts;
    while ( my $account_line = $account_lines->next ) {
        $account_line = $account_line->unblessed;
        if ( $account_line->{itemnumber} ) {
            my $item = Koha::Items->find( $account_line->{itemnumber} );
            my $biblio = $item->biblio;
            $account_line->{biblionumber} = $biblio->biblionumber;
            $account_line->{title}        = $biblio->title;
        }
        push @accounts, $account_line;
    }
    borrower_add_additional_fields($patron);

    $template->param(
        patron   => $patron,
        accounts => \@accounts,
        total    => $total,
    );
    return;

}

sub get_for_redirect {
    my ( $name, $name_in, $money ) = @_;
    my $s     = q{&} . $name . q{=};
    my $value;
    if (defined $input->param($name_in)) {
        $value = uri_escape_utf8( scalar $input->param($name_in) );
    }
    if ( !defined $value ) {
        $value = ( $money == 1 ) ? 0 : q{};
    }
    if ($money) {
        $s .= sprintf '%.2f', $value;
    } else {
        $s .= $value;
    }
    return $s;
}

sub redirect_to_paycollect {
    my ( $action, $line_no ) = @_;
    my $redirect =
      "/cgi-bin/koha/members/paycollect.pl?borrowernumber=$borrowernumber";
    $redirect .= q{&};
    $redirect .= "$action=1";
    $redirect .= get_for_redirect( 'accounttype', "accounttype$line_no", 0 );
    $redirect .= get_for_redirect( 'accounttypename', "accounttypename$line_no", 0);
    $redirect .= get_for_redirect( 'amount', "amount$line_no", 1 );
    $redirect .=
      get_for_redirect( 'amountoutstanding', "amountoutstanding$line_no", 1 );
    $redirect .= get_for_redirect( 'description', "description$line_no", 0 );
    $redirect .= get_for_redirect( 'title', "title$line_no", 0 );
    $redirect .= get_for_redirect( 'itemnumber',   "itemnumber$line_no",   0 );
    $redirect .= get_for_redirect( 'accountlines_id', "accountlines_id$line_no", 0 );
    $redirect .= q{&} . 'payment_note' . q{=} . uri_escape_utf8( scalar $input->param("payment_note_$line_no") );
    $redirect .= '&remote_user=';
    $redirect .= $user;
    return print $input->redirect($redirect);
}

sub writeoff_or_cancel_all {
    my @params = @_;
    my @wo_lines = grep { /^accountlines_id\d+$/ } @params;
    
    my $borrowernumber = $input->param('borrowernumber');
    my $actiontype = $input->param('woall') ? 'writeoff' : 'cancelfee';
    
    for (@wo_lines) {
        if (/(\d+)/) {
            my $value           = $1;
            my $amount          = $input->param("amountoutstanding$value");
            my $accountlines_id = $input->param("accountlines_id$value");
            my $payment_note    = $input->param("payment_note_$value");
            my $description     = $input->param("description$value");
            Koha::Account->new( { patron_id => $borrowernumber } )->pay(
                {
                    amount => $amount,
                    lines  => [ scalar Koha::Account::Lines->find($accountlines_id) ],
                    type   => $actiontype,
                    note   => $payment_note,
                    library_id => $branch,
                    description => $description,
                }
            );
        }
    }

    print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
    return;
}

sub borrower_add_additional_fields {
    my $patron = shift;

# some borrower info is not returned in the standard call despite being assumed
# in a number of templates. It should not be the business of this script but in lieu of
# a revised api here it is ...
    if ( $patron->is_child ) {
        my $patron_categories = Koha::Patron::Categories->search_limited({ category_type => 'A' }, {order_by => ['categorycode']});
        $template->param( 'CATCODE_MULTI' => 1) if $patron_categories->count > 1;
        $template->param( 'catcode' => $patron_categories->next->categorycode )  if $patron_categories->count == 1;
    }

    if (C4::Context->preference('ExtendedPatronAttributes')) {
        my $extendedattributes = GetBorrowerAttributes($patron->borrowernumber);
        $template->param(
            extendedattributes       => $extendedattributes,
            ExtendedPatronAttributes => 1,
        );
    }

    return;
}

sub payselected {
    my @params = @_;
    my $amt    = 0;
    my @lines_to_pay;
    foreach (@params) {
        if (/^incl_par_(\d+)$/) {
            my $index = $1;
            push @lines_to_pay, scalar $input->param("accountlines_id$index");
            $amt += $input->param("amountoutstanding$index");
        }
    }
    $amt = '&amt=' . $amt;
    my $sel = '&selected=' . join ',', @lines_to_pay;
    my $notes = '&notes=' . join("%0A", map { scalar $input->param("payment_note_$_") } @lines_to_pay );
    my $redirect =
        "/cgi-bin/koha/members/paycollect.pl?borrowernumber=$borrowernumber"
      . $amt
      . $sel
      . $notes;

    print $input->redirect($redirect);
    return;
}
