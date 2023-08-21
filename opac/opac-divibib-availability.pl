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

use C4::Context;
use C4::Output qw(output_ajax_with_http_headers);
use C4::Divibib::NCIPService;

use JSON;

my $query = CGI->new();

my @divibibIDs = ();

my $reqId = $query->param('divibibID');
foreach my $splitId( split /\s+/, $reqId  ) {
    if ( $splitId ) {
        push @divibibIDs, $splitId;
    }
}

my $divibibService = C4::Divibib::NCIPService->new();

my @js_reply = ();

foreach my $divibibID ( @divibibIDs ) {
    my ($result, $resultOk, $resultError, $resultErrorCode) = $divibibService->lookupItem($divibibID);

    push @js_reply, {
                        result        => $result,
                        resultOk      => $resultOk,
                        resultError   => $resultError,
                      };
}

my $json_reply = JSON->new->encode( { titles => \@js_reply } );

output_ajax_with_http_headers( $query, $json_reply );
exit;


