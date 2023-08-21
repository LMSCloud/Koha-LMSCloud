#!/usr/bin/perl

# Copyright 2017 LMSCloud GmbH
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
use C4::External::Munzinger;
use JSON;

my $query = CGI->new;
my ($userid, $cookie, $sessionID) = checkauth( $query, 1, {}, 'opac' );

my $result = undef;

if ( C4::Context->preference('MunzingerEncyclopediaSearchEnabled') ) {
    my $search = $query->param('search');
    my $publication = $query->param('publication');
    my $maxcount = $query->param('maxcount');
    my $offset = $query->param('offset');
    my $munzingerService = C4::External::Munzinger->new();
    $result = $munzingerService->getCategorySummary($userid,$search,$publication,$maxcount,$offset);
}

my $json_reply = JSON->new->encode( { result => $result } );

binmode STDOUT, ":encoding(UTF-8)";
print $query->header(
    -type => 'application/json',
    -charset => 'UTF-8'
);

print $json_reply;
