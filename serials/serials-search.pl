#!/usr/bin/perl

# Copyright 2012 Koha Team
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


=head1 NAME

serials-search.pl

=head1 DESCRIPTION

this script is the search page for serials

=cut

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Auth;
use C4::Context;
use C4::Koha qw( GetAuthorisedValues );
use C4::Output;
use C4::Serials;
use Koha::AdditionalFields;

use Koha::DateUtils;
use Koha::SharedContent;

my $query         = CGI->new;
my $title         = $query->param('title_filter') || '';
my $ISSN          = $query->param('ISSN_filter') || '';
my $EAN           = $query->param('EAN_filter') || '';
my $callnumber    = $query->param('callnumber_filter') || '';
my $publisher     = $query->param('publisher_filter') || '';
my $bookseller    = $query->param('bookseller_filter') || '';
my $biblionumber  = $query->param('biblionumber') || '';
my $branch        = $query->param('branch_filter') || '';
my $location      = $query->param('location_filter') || '';
my $expiration_date = $query->param('expiration_date_filter') || '';
my $routing       = $query->param('routing') || C4::Context->preference("RoutingSerials");
my $searched      = $query->param('searched') || 0;
my $mana      = $query->param('mana') || 0;
my @subscriptionids = $query->multi_param('subscriptionid');
my $op            = $query->param('op');

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "serials/serials-search.tt",
        query           => $query,
        type            => "intranet",
        flagsrequired   => { serials => '*' },
        debug           => 1,
    }
);

if ( $op and $op eq "close" ) {
    for my $subscriptionid ( @subscriptionids ) {
        C4::Serials::CloseSubscription( $subscriptionid );
    }
} elsif ( $op and $op eq "reopen" ) {
    for my $subscriptionid ( @subscriptionids ) {
        C4::Serials::ReopenSubscription( $subscriptionid );
    }
}


my @additional_fields = Koha::AdditionalFields->search( { tablename => 'subscription', searchable => 1 } );
my @additional_field_filters;
for my $field ( @additional_fields ) {
    my $value = $query->param( 'additional_field_' . $field->id );
    if ( defined $value and $value ne '' ) {
        push @additional_field_filters, {
            id => $field->id,
            value => $value,
        };
    }
}

my $expiration_date_dt = $expiration_date ? dt_from_string( $expiration_date ) : undef;
my @subscriptions;
my $mana_statuscode;
if ($searched){
    if ($mana) {
        my $result = Koha::SharedContent::search_entities("subscription",{
            title        => $title,
            issn         => $ISSN,
            ean          => $EAN,
            publisher    => $publisher
        });
        $mana_statuscode = $result->{code};
        @subscriptions = @{ $result->{data} };
    }
    else {
        @subscriptions = SearchSubscriptions(
        {
            biblionumber => $biblionumber,
            title        => $title,
            issn         => $ISSN,
            ean          => $EAN,
            callnumber   => $callnumber,
            publisher    => $publisher,
            bookseller   => $bookseller,
            branch       => $branch,
            additional_fields => \@additional_field_filters,
            location     => $location,
            expiration_date => $expiration_date_dt,
        });
    }
}

if ($mana) {
    $template->param(
        subscriptions => \@subscriptions,
        statuscode    => $mana_statuscode,
        total         => scalar @subscriptions,
        title_filter  => $title,
        ISSN_filter   => $ISSN,
        EAN_filter    => $EAN,
        callnumber_filter => $callnumber,
        publisher_filter => $publisher,
        bookseller_filter  => $bookseller,
        branch_filter => $branch,
        location_filter => $location,
        expiration_date_filter => $expiration_date_dt,
        done_searched => $searched,
        routing       => $routing,
        additional_field_filters => \@additional_field_filters,
        additional_fields_for_subscription => \@additional_fields,
        marcflavour   => (uc(C4::Context->preference("marcflavour"))),
        mana => $mana,
        search_only => 1
    );
}
else
{
    # to toggle between create or edit routing list options
    if ($routing) {
        for my $subscription ( @subscriptions) {
            $subscription->{routingedit} = check_routing( $subscription->{subscriptionid} );
        }
    }

    my (@openedsubscriptions, @closedsubscriptions);
    for my $sub ( @subscriptions ) {
        unless ( $sub->{closed} ) {
            push @openedsubscriptions, $sub
                unless $sub->{cannotdisplay};
        } else {
            push @closedsubscriptions, $sub
                unless $sub->{cannotdisplay};
        }
    }

    my @branches = Koha::Libraries->search( {}, { order_by => ['branchcode'] } );
    my @branches_loop;
    foreach my $b ( @branches ) {
        my $selected = 0;
        $selected = 1 if( defined $branch and $branch eq $b->branchcode );
        push @branches_loop, {
            branchcode  => $b->branchcode,
            branchname  => $b->branchname,
            selected    => $selected,
        };
    }

    $template->param(
        openedsubscriptions => \@openedsubscriptions,
        closedsubscriptions => \@closedsubscriptions,
        total         => @openedsubscriptions + @closedsubscriptions,
        title_filter  => $title,
        ISSN_filter   => $ISSN,
        EAN_filter    => $EAN,
        callnumber_filter => $callnumber,
        publisher_filter => $publisher,
        bookseller_filter  => $bookseller,
        branch_filter => $branch,
        location_filter => $location,
        expiration_date_filter => $expiration_date_dt,
        branches_loop => \@branches_loop,
        done_searched => $searched,
        routing       => $routing,
        additional_field_filters => { map { $_->{id} => $_->{value} } @additional_field_filters },
        additional_fields_for_subscription => \@additional_fields,
        marcflavour   => (uc(C4::Context->preference("marcflavour"))),
        mana => $mana
    );
}
output_html_with_http_headers $query, $cookie, $template->output;
