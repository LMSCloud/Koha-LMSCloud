package Koha::REST::V1::BZSH::OrderStatus;

# Copyright 2019 LMSCloud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Carp;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

use Scalar::Util qw(blessed);
use Try::Tiny;
use DateTime::Format::W3CDTF;
use DateTime::Format::MySQL;

use C4::Biblio qw(GetMarcBiblio);
use C4::Context;

use LWP::UserAgent;

=head1 NAME

Koha::REST::V1::ExternalOrder

=head1 API

=head2 Methods


=head3 add

Controller function that handles external aquisition order requests.

=cut

sub getOrderItemStatus {
    
    my $argvalue = shift;
    my $c = $argvalue->openapi->valid_input or return;

    return try {
        my ($responsecode, $orderItems, $count) = &handleBZSHOrderStatusRequest($c);
        return $c->render( status => $responsecode, openapi => { count_items => $count, order_items => $orderItems } );
    }
    catch {
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
        return $c->render(
            status  => 500,
            openapi => { error => "Something went wrong, check Koha logs for details." }
        );
    };
}

    
sub handleBZSHOrderStatusRequest {
    my $orderItemStatusRequestRarams = shift;
    
    my $respcode = '200';
    my $orderItems = [];
    my $resultcount = 0;

    # check biblionumbers
    my $biblionumbers = {};
    my $params = $orderItemStatusRequestRarams->every_param('biblionumber');
    if ( $params && scalar(@$params) ) {
        foreach my $biblionumber( @$params ) {
            $biblionumbers->{$biblionumber} = 1;
        }
    }
    
    # check external_order_id
    my $externalOrderIds = {};
    $params = $orderItemStatusRequestRarams->every_param('external_order_id');
    if ( $params && scalar(@$params) ) {
        foreach my $externalOrderId ( @$params ) {
            $externalOrderIds->{$externalOrderId} = 1;
        }
    }
    
    # check library_id
    my $branchcodes = {};
    $params = $orderItemStatusRequestRarams->every_param('library_id');
    if ( $params && scalar(@$params) ) {
        foreach my $branchcode ( @$params ) {
            $branchcodes->{$branchcode} = 1;
        }
    }
    
    # check order_status_code
    my $orderStatusCodes = {};
    $params = $orderItemStatusRequestRarams->every_param('order_status_code');
    if ( $params && scalar(@$params) ) {
        foreach my $orderStatusCode ( @$params ) {
            $orderStatusCodes->{$orderStatusCode} = 1;
        }
    }
    
    # get sort parameter values
    my $sortParams = [];
    $params = $orderItemStatusRequestRarams->every_param('_order_by');
    if ( $params && scalar(@$params) ) {
        foreach my $sortParam ( @$params ) {
            if ( $sortParam =~ /^\s*(biblionumber|library_id|external_order_id|order_status_code|order_status_text|date_last_changed|copies)(\s+(ASC|DESC))?\s*$/i ) {
                my $sortField = lc($1);
                my $sortDirection = 'ASC';
                $sortDirection = uc($3) if ($3);
                
                push @$sortParams, "$sortField $sortDirection";
            }
        }
    }
    
    # print STDERR Dumper($biblionumbers,$externalOrderIds,$branchcodes);
    
    my @biblionumberList =  keys %$biblionumbers;
    my @externalOrderIdList = keys %$externalOrderIds;
    my @branchcodeList = keys %$branchcodes;
    my @orderStatusList = keys %$orderStatusCodes;

    my $dbh = C4::Context->dbh;
    
    my $select = qq{
        SELECT i.biblionumber AS biblionumber,
               i.homebranch AS library_id,
               i.stocknumber AS external_order_id,
               i.notforloan AS order_status_code,
               v.lib_opac AS order_status_text,
               DATE(i.timestamp) AS date_last_changed,
               count(*) AS copies
        FROM   items i
               JOIN aqorders_items o ON (o.itemnumber = i.itemnumber)
               JOIN authorised_values v ON (v.category = 'NOT_LOAN' AND i.notforloan = v.authorised_value)
        };

    my @addselect = ();
    my @addparameter;
    if ( scalar(@biblionumberList) ) {
        push @addselect, "i.biblionumber IN (" . join(",", map { ($_) x scalar(@biblionumberList) } ("?")) . ")";
        push @addparameter, @biblionumberList;
    }
    if ( scalar(@externalOrderIdList) ) {
        push @addselect, "i.stocknumber IN (" . join(",", map { ($_) x scalar(@externalOrderIdList) } ("?")) . ")";
        push @addparameter, @externalOrderIdList;
    }
    if ( scalar(@branchcodeList) ) {
        push @addselect, "i.homebranch IN (" . join(",", map { ($_) x scalar(@branchcodeList) } ("?")) . ")";
        push @addparameter, @branchcodeList;
    }
    if ( scalar(@orderStatusList) ) {
        push @addselect, "i.notforloan IN (" . join(",", map { ($_) x scalar(@orderStatusList) } ("?")) . ")";
        push @addparameter, @orderStatusList;
    }
    if ( scalar(@addselect) ) {
        $select .= " WHERE " . join(" AND ",@addselect);
        $select .= " GROUP BY i.biblionumber, i.homebranch, i.stocknumber, i.notforloan, v.lib_opac, DATE(i.timestamp)";
        $select .= " ORDER BY " . join(", ",@$sortParams) if ( scalar(@$sortParams) );
        
        my $pagesize   = $orderItemStatusRequestRarams->param('_per_page');
        my $pagenumber = $orderItemStatusRequestRarams->param('_page');
        
        if ( $pagesize ) {
            $pagenumber = 1 if (! $pagenumber);
            my $offset = $pagesize * ($pagenumber - 1);
            $select .= " LIMIT $offset, $pagesize";
        }
        
        my $sth = $dbh->prepare($select);
        $sth->execute(@addparameter);
        
        while ( my $itemline = $sth->fetchrow_hashref ) {
            push @$orderItems, $itemline;
            $resultcount++;
        }
        $sth->finish();
    }
    
    return ($respcode,$orderItems,$resultcount);
}

1;