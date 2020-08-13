#!/usr/bin/perl

# Copyright 2020 LMSCloud GmbH
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

use utf8;

use CGI;

use C4::Auth qw(checkauth);
use C4::Context;
use C4::Debug;
use C4::Output qw(:html :ajax pagination_bar);
use C4::External::Brockhaus;
use JSON;

my $query = CGI->new();
my ($userid, $cookie, $sessionID) = checkauth( $query, 1, {}, 'opac' );

my $result = undef;

if ( C4::Context->preference('BrockhausSearchActive') ) {
    my $search = $query->param('search');
    my $maxcount = $query->param('maxcount');
    my $offset = $query->param('offset');
    my $collection = $query->param('collection');
    my $brockhausService = C4::External::Brockhaus->new();
    
    my $searchWhere = [];
    $searchWhere = [$collection] if ( $collection );
    if ( !scalar(@$searchWhere) && C4::Context->preference('BrockhausSearchCollections') ) {
        $searchWhere =  [];
        my $colls = {};
        foreach my $collection( split(/\|/,C4::Context->preference('BrockhausSearchCollections')) ) {
            $collection =~ s/^\s+//;
            $collection =~ s/\s+$//;
            if ( $collection =~ /enzy/i ) {
                $collection = 'ecs.enzy';
            }
            elsif ( $collection =~ /julex/i ) {
                $collection = 'ecs.julex';
            }
            elsif ( $collection =~ /kilex/i ) {
                $collection = 'ecs.kilex';
            }
            elsif ( $collection =~ /ecs/i ) {
                $collection = 'ecs';
            }
            if ( ! exists($colls->{$collection}) ) {
                $colls->{$collection} = 1;
                push @$searchWhere,$collection;
            }
        }
        $searchWhere = ["ecs"] if (! scalar(@$searchWhere) );
    }
    
    $result = $brockhausService->simpleSearch($userid,$search,$searchWhere,$maxcount,$offset);
}

my $json_reply = JSON->new->encode( { result => $result } );

binmode STDOUT, ":encoding(UTF-8)";
print $query->header(
    -type => 'application/json',
    -charset => 'UTF-8'
);

print $json_reply;
