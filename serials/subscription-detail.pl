#!/usr/bin/perl

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

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Acquisition;
use C4::Auth;
use C4::Budgets;
use C4::Koha;
use C4::Serials;
use C4::Output;
use C4::Context;
use C4::Search qw/enabled_staff_search_views/;

use Koha::AuthorisedValues;
use Koha::DateUtils;
use Koha::Acquisition::Bookseller;

use Date::Calc qw/Today Day_of_Year Week_of_Year Add_Delta_Days/;
use Carp;

my $query = new CGI;
my $op = $query->param('op') || q{};
my $issueconfirmed = $query->param('issueconfirmed');
my $dbh = C4::Context->dbh;
my $subscriptionid = $query->param('subscriptionid');

if ( $op and $op eq "close" ) {
    C4::Serials::CloseSubscription( $subscriptionid );
} elsif ( $op and $op eq "reopen" ) {
    C4::Serials::ReopenSubscription( $subscriptionid );
}

# the subscription must be deletable if there is NO issues for a reason or another (should not happend, but...)

# Permission needed if it is a deletion (del) : delete_subscription
# Permission needed otherwise : *
my $permission = ($op eq "del") ? "delete_subscription" : "*";

my ($template, $loggedinuser, $cookie)
= get_template_and_user({template_name => "serials/subscription-detail.tt",
                query => $query,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {serials => $permission},
                debug => 1,
                });


my $subs = GetSubscription($subscriptionid);
$subs->{enddate} ||= GetExpirationDate($subscriptionid);

my ($totalissues,@serialslist) = GetSerials($subscriptionid);
$totalissues-- if $totalissues; # the -1 is to have 0 if this is a new subscription (only 1 issue)

if ($op eq 'del') {
	if ($$subs{'cannotedit'}){
		carp "Attempt to delete subscription $subscriptionid by ".C4::Context->userenv->{'id'}." not allowed";
		print $query->redirect("/cgi-bin/koha/serials/subscription-detail.pl?subscriptionid=$subscriptionid");
		exit;
	}
	
    # Asking for confirmation if the subscription has not strictly expired yet or if it has linked issues
    my $strictlyexpired = HasSubscriptionStrictlyExpired($subscriptionid);
    my $linkedissues = CountIssues($subscriptionid);
    my $countitems   = HasItems($subscriptionid);
    if ($strictlyexpired == 0 || $linkedissues > 0 || $countitems>0) {
		$template->param(NEEDSCONFIRMATION => 1);
		if ($strictlyexpired == 0) { $template->param("NOTEXPIRED" => 1); }
		if ($linkedissues     > 0) { $template->param("LINKEDISSUES" => 1); }
		if ($countitems       > 0) { $template->param("LINKEDITEMS"  => 1); }
    } else {
		$issueconfirmed = "1";
    }
    # If it's ok to delete the subscription, we do so
    if ($issueconfirmed eq "1") {
		&DelSubscription($subscriptionid);
        print $query->redirect("/cgi-bin/koha/serials/serials-home.pl");
        exit;
    }
}
my $hasRouting = check_routing($subscriptionid);

(undef, $cookie, undef, undef)
    = checkauth($query, 0, {catalogue => 1}, "intranet");

# COMMENT hdl : IMHO, we should think about passing more and more data hash to template->param rather than duplicating code a new coding Guideline ?

for my $date ( qw(startdate enddate firstacquidate histstartdate histenddate) ) {
    $subs->{$date} = output_pref( { str => $subs->{$date}, dateonly => 1 } )
        if $subs->{$date};
}
my $av = Koha::AuthorisedValues->search({ category => 'LOC', authorised_value => $subs->{location} });
$subs->{location} = $av->count ? $av->next->lib : '';
$subs->{abouttoexpire}  = abouttoexpire($subs->{subscriptionid});
$template->param(%{ $subs });
$template->param(biblionumber_for_new_subscription => $subs->{bibnum});
my @irregular_issues = split /;/, $subs->{irregularity};

my $frequency = C4::Serials::Frequency::GetSubscriptionFrequency($subs->{periodicity});
my $numberpattern = C4::Serials::Numberpattern::GetSubscriptionNumberpattern($subs->{numberpattern});

my $default_bib_view = get_default_view();

my ( $order, $bookseller, $tmpl_infos );
if ( defined $subscriptionid ) {
    my $lastOrderNotReceived = GetLastOrderNotReceivedFromSubscriptionid $subscriptionid;
    my $lastOrderReceived = GetLastOrderReceivedFromSubscriptionid $subscriptionid;
    if ( defined $lastOrderNotReceived ) {
        my $basket = GetBasket $lastOrderNotReceived->{basketno};
        my $bookseller = Koha::Acquisition::Booksellers->find( $basket->{booksellerid} );
        ( $tmpl_infos->{value_tax_included_ordered}, $tmpl_infos->{value_tax_excluded_ordered} ) = get_value_with_gst_params ( $lastOrderNotReceived->{ecost}, $lastOrderNotReceived->{tax_rate}, $bookseller );
        $tmpl_infos->{value_tax_included_ordered} = sprintf( "%.2f", $tmpl_infos->{value_tax_included_ordered} );
        $tmpl_infos->{value_tax_excluded_ordered} = sprintf( "%.2f", $tmpl_infos->{value_tax_excluded_ordered} );
        $tmpl_infos->{budget_name_ordered} = GetBudgetName $lastOrderNotReceived->{budget_id};
        $tmpl_infos->{basketno} = $lastOrderNotReceived->{basketno};
        $tmpl_infos->{ordered_exists} = 1;
    }
    if ( defined $lastOrderReceived ) {
        my $basket = GetBasket $lastOrderReceived->{basketno};
        my $bookseller = Koha::Acquisition::Booksellers->find( $basket->{booksellerid} );
        ( $tmpl_infos->{value_tax_included_spent}, $tmpl_infos->{value_tax_excluded_spent} ) = get_value_with_gst_params ( $lastOrderReceived->{unitprice}, $lastOrderReceived->{tax_rate}, $bookseller );
        $tmpl_infos->{value_tax_included_spent} = sprintf( "%.2f", $tmpl_infos->{value_tax_included_spent} );
        $tmpl_infos->{value_tax_excluded_spent} = sprintf( "%.2f", $tmpl_infos->{value_tax_excluded_spent} );
        $tmpl_infos->{budget_name_spent} = GetBudgetName $lastOrderReceived->{budget_id};
        $tmpl_infos->{invoiceid} = $lastOrderReceived->{invoiceid};
        $tmpl_infos->{spent_exists} = 1;
    }
}

my $additional_fields = Koha::AdditionalField->all( { tablename => 'subscription' } );
for my $field ( @$additional_fields ) {
    if ( $field->{authorised_value_category} ) {
        $field->{authorised_value_choices} = GetAuthorisedValues( $field->{authorised_value_category} );
    }
}
$template->param( additional_fields_for_subscription => $additional_fields );

$template->param(
    subscriptionid => $subscriptionid,
    serialslist => \@serialslist,
    hasRouting  => $hasRouting,
    routing => C4::Context->preference("RoutingSerials"),
    totalissues => $totalissues,
    cannotedit => (not C4::Serials::can_edit_subscription( $subs )),
    frequency => $frequency,
    numberpattern => $numberpattern,
    has_X           => ($numberpattern->{'numberingmethod'} =~ /{X}/) ? 1 : 0,
    has_Y           => ($numberpattern->{'numberingmethod'} =~ /{Y}/) ? 1 : 0,
    has_Z           => ($numberpattern->{'numberingmethod'} =~ /{Z}/) ? 1 : 0,
    intranetstylesheet => C4::Context->preference('intranetstylesheet'),
    intranetcolorstylesheet => C4::Context->preference('intranetcolorstylesheet'),
    irregular_issues => scalar @irregular_issues,
    default_bib_view => $default_bib_view,
    (uc(C4::Context->preference("marcflavour"))) => 1,
    show_acquisition_details => defined $tmpl_infos->{ordered_exists} || defined $tmpl_infos->{spent_exists} ? 1 : 0,
    basketno => $order->{basketno},
    %$tmpl_infos,
);

output_html_with_http_headers $query, $cookie, $template->output;

sub get_default_view {
    my $defaultview = C4::Context->preference('IntranetBiblioDefaultView');
    my %views       = C4::Search::enabled_staff_search_views();
    if ( $defaultview eq 'isbd' && $views{can_view_ISBD} ) {
        return 'ISBDdetail';
    }
    elsif ( $defaultview eq 'marc' && $views{can_view_MARC} ) {
        return 'MARCdetail';
    }
    elsif ( $defaultview eq 'labeled_marc' && $views{can_view_labeledMARC} ) {
        return 'labeledMARCdetail';
    }
    return 'detail';
}

sub get_value_with_gst_params {
    my $value = shift;
    my $tax_rate = shift;
    my $bookseller = shift;
    if ( $bookseller->listincgst ) {
        return ( $value, $value / ( 1 + $tax_rate ) );
    } else {
        return ( $value * ( 1 + $tax_rate ), $value );
    }
}

sub get_tax_excluded {
    my $value = shift;
    my $tax_rate = shift;
    my $bookseller = shift;
    if ( $bookseller->invoiceincgst ) {
        return $value / ( 1 + $tax_rate );
    } else {
        return $value;
    }
}

sub get_gst {
    my $value = shift;
    my $tax_rate = shift;
    my $bookseller = shift;
    if ( $bookseller->invoiceincgst ) {
        return $value / ( 1 + $tax_rate ) * $tax_rate;
    } else {
        return $value * ( 1 + $tax_rate ) - $value;
    }
}
