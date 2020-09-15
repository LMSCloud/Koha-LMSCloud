#!/usr/bin/perl

# Copyright 2016 LMSCloud GmbH
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

=head1 DESCRIPTION

This script is used to return availability information of digital material 
of the German eBook/eMedia vendor Divibib via ajax json response. Since retrieving
availability information from the Divivbib Onleihe may take some seconds,
we retrieve this information for each title of a result separatly,

=cut

use strict;
use warnings;

use CGI qw ( -utf8 );
use CGI::Cookie;  # need to check cookies before having CGI parse the POST request

use C4::Auth qw(:DEFAULT check_cookie_auth);
use C4::Context;
use C4::Debug;
use C4::Output qw(:html :ajax pagination_bar);
use C4::Divibib::NCIPService;

use JSON;

my $is_ajax = is_ajax();

my ($query, $auth_status);
if ($is_ajax) {
    ( $query, $auth_status ) = &ajax_auth_cgi( {} );
}
else {
    $auth_status = 'unauthorized';
    $query = CGI->new();
}

my @js_reply = ();
my $json_reply;
    
if ( $auth_status eq 'ok' ) {
    my $isLoan=0;
    
    my @divibibIDs = ();
    my $loggedinuser = C4::Context->userenv->{'number'};

    foreach my $reqId ( $query->param('divibibID') ) {
	foreach my $splitId( split /\s+/, $reqId  ) {
	    if ( $splitId ) {
               push @divibibIDs, $splitId;
            }
        }
    }

    my $action = $query->param('action');
    
    if ( $action eq 'loan' ) {
        $isLoan = 1;
    }

    my $divibibService = C4::Divibib::NCIPService->new();

    foreach my $divibibID ( @divibibIDs ) {
        my ($result, $resultOk, $resultError, $resultErrorCode) = $divibibService->requestItem($loggedinuser, $divibibID, $isLoan);

        push @js_reply, {
                            result           => $result,
                            resultOk         => $resultOk,
                            resultError      => $resultError,
                            resultErrorCode  => $resultErrorCode
                          };
    }

    $json_reply = JSON->new->utf8->encode( { titles => \@js_reply } );
    
}
else {
    $json_reply = JSON->new->utf8->encode( { error => "No valid user session status: " . $auth_status } );
}

output_ajax_with_http_headers( $query, $json_reply );
exit;

# copied from opac-ratings-ajax.pl
# a ratings specific ajax return sub, returns CGI object, and an 'auth_success' value
sub ajax_auth_cgi {
    my $needed_flags = shift;
    my %cookies      = CGI::Cookie->fetch;
    my $input        = CGI->new;
    my $sessid = $cookies{'CGISESSID'}->value || $input->param('CGISESSID');
    my ( $auth_status, $auth_sessid ) =
      check_cookie_auth( $sessid, $needed_flags );
    return $input, $auth_status;
}
