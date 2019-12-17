package Koha::REST::V1::BZSH::IdMapping;

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

sub add {
    
    my $argvalue = shift;
    my $c = $argvalue->openapi->valid_input or return;
    my $apiparams = $c->req->json; # $c->validation->param('body');

    return try {
        my ($responsecode, $responsetext) = &handleBZSHIdMappingRequest($apiparams);
        return $c->render( status => $responsecode, openapi => { process_info => $responsetext }  );
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

    
sub handleBZSHIdMappingRequest {
    my $mappings = shift;

    my $respcode = '552';
    my $resptext = 'No mapping request received';

    if ( $mappings ) {
        my $mapcount = 0;
        
        # print STDERR Dumper($mappings);
        
        my $dbh = C4::Context->dbh;
        
        my $raiseError = $dbh->{RaiseError};
        $dbh->{AutoCommit} = 0;
        $dbh->{RaiseError} = 1;
        
        foreach my $mapping(@$mappings) {
            my ($biblionumber,$bzshid);
            
            if ( exists($mapping->{localId}) ) {
                $biblionumber = $mapping->{localId};
            }
            
            if ( exists($mapping->{bzshId}) ) {
                $bzshid = $mapping->{bzshId};
            }
            
            if ( $biblionumber && $bzshid ) {
                my $record;
                
                eval {
                    $record = GetMarcBiblio( { biblionumber => $biblionumber } );
                };
                
                if ( $@ ) {
                     warn 'handleBZSHIdMappingRequest: unable to read biblio record '.$biblionumber.' : '.$@;
                     next;
                }
                if ( $record ) {
                    my $changed = 0;
                    my $found = 0; 
                    
                    foreach my $field( $record->field("998") ) {
                        my $fieldval = $field->subfield('a');
                        my $i1 = $field->indicator(1);
                        my $i2 = $field->indicator(2);
                        if ( $i1 eq 'i' && $i2 eq ' ' ) {
                            $found = 1;
                            if ( (!$fieldval) || $fieldval ne $bzshid ) {
                                $field->update( 'a' => $bzshid );
                                $changed = 1;
                            }
                        }
                    }
                    
                    if ( !$found ) {    
                        $record->insert_fields_ordered(MARC::Field->new(998, 'i', ' ', 'a' => $bzshid));
                        $changed = 1;
                    }
                    
                    if ( $changed ) {
                        $mapcount++;
                        ModBiblio($record, $biblionumber, GetFrameworkCode($biblionumber));
                        $dbh->commit if ( $mapcount%100 == 0 );
                    }
                }
            }
        }
        
        $dbh->commit if ($mapcount);
        
        $dbh->{AutoCommit} = 1;
        $dbh->{RaiseError} = $raiseError;
        
        $respcode = '201';
        $resptext = "$mapcount BZSH-ID mappings updated.";
    }
    
    # return $c->render( status => 200, openapi => _to_api( $patron->TO_JSON ) );
    return ($respcode,$resptext);
}

1;
