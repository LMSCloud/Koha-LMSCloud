#!/usr/bin/perl

# Copyright 2026 LMSCloud GmbH
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

use Modern::Perl;
use CGI;

use C4::Auth qw(checkauth);
use C4::Context;
use C4::External::HeLiMa;
use JSON;

my $query = CGI->new;
my ($userid, $cookie, $sessionID) = checkauth( $query, 1, {}, 'opac' );

my $result = undef;

if ( C4::Context->preference('HelimaSearchActive') ) {
    my $search = $query->param('search');
    my $maxcount = $query->param('maxcount');
    my $offset = $query->param('offset');
    my $collection = $query->param('collection');
    my $objectid = $query->param('objectid');

    my $helimaService = C4::External::HeLiMa->new();
    
    if ( $objectid ) {
        my $url = $helimaService->getAuthLink($userid,$collection,$objectid);
        
        if ( $url ) {
            print $query->redirect($url);
        } else {
            print $query->redirect("/cgi-bin/koha/errors/404.pl");
        }
        exit;
    }
    
    $result = $helimaService->simpleSearch($userid,$search,$collection,$maxcount,$offset);
}

my $json_reply = JSON->new->encode( { result => $result } );

binmode STDOUT, ":encoding(UTF-8)";
print $query->header(
    -type => 'application/json',
    -charset => 'UTF-8'
);

print $json_reply;
