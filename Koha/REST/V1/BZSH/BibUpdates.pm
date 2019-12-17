package Koha::REST::V1::BZSH::BibUpdates;

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

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

use Scalar::Util qw(blessed);
use Try::Tiny;

use C4::Biblio;
use C4::Context;

=head1 NAME

Koha::REST::V1::BZSHIdMapping

=head1 API

=head2 Methods


=head3 add

Controller function that handles BZSHId mapping requests. The handler calls functions 
to update local catalog requests.

=cut

sub getBibUpdates {
    
    my $argvalue = shift;
    my $c = $argvalue->openapi->valid_input or return;
    my $since = $c->validation->param('since');

    return try {
        my ($response) = &handleBZSHBibUpdatesRequest($since);
        return $c->render( status => 200, openapi => $response );
    }
    catch {
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
        if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => $_->error, conflict => $_->duplicate_id }
            );
        }
        else {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
    };
}

    
sub handleBZSHBibUpdatesRequest {
    my $since = shift;
    my $datesel;
    
    if ( $since && $since =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
        $datesel = $since;
    }
    
    my $response = { updated => [], created => [], deleted => [] };

    if ( $datesel ) {
        my $dbh = C4::Context->dbh;

        my $sql = qq{
            SELECT b.biblionumber, IF( i.datecreated >= CAST(DATE('$datesel') AS DATETIME ), 1, 0)
            FROM   biblio_metadata b, biblio i
            WHERE  i.biblionumber = b.biblionumber 
               AND b.timestamp >= CAST(DATE('$datesel') AS DATETIME)
               AND ExtractValue(b.metadata,'//datafield[\@tag="998" and \@ind1="b" and \@ind2="z"]/subfield[\@code="n"]') = 'BZShopJa'
            ORDER BY biblionumber
            };

        my $sth = $dbh->prepare($sql);
        $sth->execute();
        
        while ( my ($biblionumber,$created) = $sth->fetchrow ) {
            if ( $created ) {
                push @{$response->{created}}, { "bzshId" => $biblionumber };
            } else {
                push @{$response->{updated}}, { "bzshId" => $biblionumber };
            }
        }
        $sth->finish();
        
        $sql = qq{
            SELECT b.biblionumber
            FROM   deletedbiblio_metadata b, deletedbiblio i
            WHERE  i.biblionumber = b.biblionumber 
               AND b.timestamp >= CAST(DATE('$datesel') AS DATETIME)
               AND ExtractValue(b.metadata,'//datafield[\@tag="998" and \@ind1="b" and \@ind2="z"]/subfield[\@code="n"]') = 'BZShopJa'
            ORDER BY biblionumber
            };
            
        $sth = $dbh->prepare($sql);
        $sth->execute();
        
        while ( my ($biblionumber,$created) = $sth->fetchrow ) {
            push @{$response->{deleted}}, { "bzshId" => $biblionumber };
        }
        $sth->finish();
    }
    
    return ($response);
}

1;
