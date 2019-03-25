package C4::Divibib::NCIP::LookupUser;

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

use strict;
use warnings;

use C4::Context;
use Koha::Patrons;
use XML::Simple;

use Carp;

use Scalar::Util qw/reftype/;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    require Exporter;
    our $VERSION = 3.07.00.049;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        
    );
}

=head1 NAME

C4::Divibib::NCIP::Command::LookupUser - Command LookupUser of the Divibib NCIP interface.

=head1 SYNOPSIS

LookupUser - User login and forwards to a URL address

=head1 DESCRIPTION

The module implements the LookupUser command of the Divibib NCIP interface. 
It takes the borrower number or barcode and returns a URL to an authenticated user session 
of the divibib interface.

The command delivers the XML request data and parses the XML repsonse data.

=head1 FUNCTIONS

=cut

sub new {
    my $class = shift;
    my ( $borrowernumber, $withAccoutData ) = @_;
    if (! $withAccoutData ) {
        $withAccoutData = 0;
    }

    my $self = { 'withAccountData' => $withAccoutData };
    bless $self, $class;
    
    my $command = {
            'ncip:version'       => '2.0',
            'xmlns:ncip'         => 'http://www.niso.org/2008/ncip',
            'xmlns:xsi'           => 'http://www.w3.org/2001/XMLSchema-instance',
            'xsi:schemaLocation' => 'http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd'
        };
        
    my $borrower = Koha::Patrons->find( $borrowernumber );
    # if we did not find the borrowernumber
    # let's check whether the borrower userid is used instead
    if (! $borrower ) { 
        $borrower = Koha::Patrons->find({ userid => $borrowernumber} );
    }
    
    if ( $borrower ) {
        $borrower = $borrower->unblessed;
    }
    
    die "borrower not found" unless (  $borrower );

    if ( $borrower ) {
        my $agency = C4::Context->preference("DivibibAgencyId");
        if ( $agency ) {
            my @agencies = split(",",$agency);
            $agency = $agencies[0];
            for (my $i=1; $i<=$#agencies; $i++) {
                my @agencysplit = split("=",$agencies[$i]);
                if ( scalar(@agencysplit) == 2 && $borrower->{'branchcode'} eq $agencysplit[1] ) {
                    $agency = $agencysplit[0];
                }
            }
        }
        $command->{'LookupUser'} = {
                'AuthenticationInput' => [
                     {
                        'AuthenticationInputData'      =>  [ $borrowernumber ],
                        'AuthenticationDataFormatType' =>  [ 'text' ] ,
                        'AuthenticationInputType'      =>  [ 'UserId' ]
                     },
                     {
                        'AuthenticationInputData'      =>  [ $borrower->{'cardnumber'} ],
                        'AuthenticationDataFormatType' =>  [ 'text' ],
                        'AuthenticationInputType'      =>  [ 'CardId' ]
                     },
                     {
                        'AuthenticationInputData'      =>  [ $borrower->{'dateofbirth'}.'T00:00:00' ],
                        'AuthenticationDataFormatType' =>  [ 'text' ],
                        'AuthenticationInputType'      =>  [ 'DateOfBirth' ]
                     },
                     {
                        'AuthenticationInputData'      =>  [ $borrower->{'password'} ],
                        'AuthenticationDataFormatType' =>  [ 'text' ],
                        'AuthenticationInputType'      =>  [ 'Password' ]
                     }
                 ],
                 'LoanedItemsDesired' => [ 'true' ],
                 'RequestedItemsDesired' => [ 'true' ],
                 'Ext' => {
                         'AgencyId' => [ $agency ],
                         'Language' => [ 'de' ]
                      }
             };
          if (! $withAccoutData ) {
              delete $command->{'LookupUser'}->{'LoanedItemsDesired'};
              delete $command->{'LookupUser'}->{'RequestedItemsDesired'};
          }
     }
     
     $self->{'cmd'} = $command;
     
     $self->_initResponse();
     
     return $self;
}

sub getXML {
    my $self = shift;
    
    return XMLout( $self->{'cmd'}, RootName => 'NCIPMessage' );
}

sub _initResponse {
    my $self = shift;
    
    $self->{'response'} = {
             'UserId' => '',
             'CardId' => '',
             'TransactionId' => '',
             'URL' => '',
             'ErrorMessages' => ''
         };

    $self->{'responseOk'} = 0;
    $self->{'responseError'} = '';
}

sub responseError {
    my $self = shift;
    my ($errorMessage,$code) = @_;
    
    $self->_initResponse();
    
    $self->{'responseOk'} = 0;
    $self->{'responseError'} = $errorMessage;
    $self->{'responseErrorCode'} = $code;
}

sub getResponse {
    my $self = shift;
    
    return $self->{'response'};
}

sub getResponseOk {
    my $self = shift;
    
    return $self->{'responseOk'};
}

sub getResponseError {
    my $self = shift;
    
    return $self->{'responseError'};
}

sub getResponseErrorCode {
    my $self = shift;
    
    return $self->{'responseErrorCode'};
}

sub parseResponse {
    my $self = shift;
    
    my $dvbresponse = shift;
    
    $self->_initResponse();
    
    my $response = XMLin( $dvbresponse, ForceArray => [ 'LoanedItem', 'RequestedItem' ] );
    
    return unless ($response);
    
    $self->{'responseOk'} = 1;
    
    if ( exists($response->{'LookupUserResponse'}) && 
         exists($response->{'LookupUserResponse'}->{'UserId'}) &&
	 exists($response->{'LookupUserResponse'}->{'UserId'}->{'UserIdentifierType'}) &&
	 reftype($response->{'LookupUserResponse'}->{'UserId'}->{'UserIdentifierType'}) eq 'ARRAY' &&
	 exists($response->{'LookupUserResponse'}->{'UserId'}->{'UserIdentifierValue'}) &&
	 reftype($response->{'LookupUserResponse'}->{'UserId'}->{'UserIdentifierValue'}) eq 'ARRAY'
	 ) 
    {
         # read attributes
         my $fnames  = $response->{'LookupUserResponse'}->{'UserId'}->{'UserIdentifierType'};
         my $fvalues = $response->{'LookupUserResponse'}->{'UserId'}->{'UserIdentifierValue'};
         my $i = 0;
         foreach ( @$fnames ) {
             if ( exists($fvalues->[$i]) ) {
                 $self->{'response'}->{$_} = $fvalues->[$i++];
                 $self->{'response'}->{$_} =~ s/^\s+|\s+$//g;
             }
         }
    }
    else {
        $self->{'responseOk'} = 0;
    }
    
    if ( exists($response->{'LookupUserResponse'}) && 
         exists($response->{'LookupUserResponse'}->{'Ext'}) &&
         exists($response->{'LookupUserResponse'}->{'Ext'}->{'Locality'}) )
    {
        $self->{'response'}->{'URL'} = $response->{'LookupUserResponse'}->{'Ext'}->{'Locality'};
        $self->{'response'}->{'URL'} =~ s/^\s+|\s+$//g;
    }
    else {
        $self->{'responseOk'} = 0;
    }
    
    if ( exists($response->{'LookupUserResponse'}) && 
         exists($response->{'LookupUserResponse'}->{'Ext'}) &&
         exists($response->{'LookupUserResponse'}->{'Ext'}->{'BlockOrTrap'}) )
    {
        $self->{'response'}->{'ErrorMessages'} = $response->{'LookupUserResponse'}->{'Ext'}->{'BlockOrTrap'};
        $self->{'response'}->{'ErrorMessages'} =~ s/^\s+|\s+$//g;
        $self->{'responseOk'} = 0;
    }
    
    if ( exists($response->{'LookupUserResponse'}) && 
         exists($response->{'LookupUserResponse'}->{'LoanedItemsCount'}) ) 
    {
        $self->{'response'}->{'LoanedItemsCount'} = $response->{'LookupUserResponse'}->{'LoanedItemsCount'}->{'LoanedItemCountValue'};
        
        if ( exists($response->{'LookupUserResponse'}->{'LoanedItem'}) ) {
            $self->{'response'}->{'LoanedItems'} = restructureItemData($response->{'LookupUserResponse'}->{'LoanedItem'});
        }
    }
    elsif ( $self->{'withAccountData'} == 1 )  {
        $self->{'response'}->{'LoanedItemsCount'} = 0;
    }
   
    if ( exists($response->{'LookupUserResponse'}) && 
         exists($response->{'LookupUserResponse'}->{'RequestedItemsCount'}) ) 
    {
         $self->{'response'}->{'RequestedItemsCount'} = $response->{'LookupUserResponse'}->{'RequestedItemsCount'}->{'RequestedItemCountValue'};
        
        if ( exists($response->{'LookupUserResponse'}->{'RequestedItem'}) ) {
            $self->{'response'}->{'RequestedItems'} = restructureItemData($response->{'LookupUserResponse'}->{'RequestedItem'});
        }
    }
    elsif ( $self->{'withAccountData'} == 1 )  {
        $self->{'response'}->{'RequestedItemsCount'} = 0;
    }
    
    
    if ( exists($response->{'LookupUserResponse'}) && 
         exists($response->{'LookupUserResponse'}->{'Problem'}) ) 
    {
        $self->responseError(
                $response->{'LookupUserResponse'}->{'Problem'}->{'ProblemDetail'},
                $response->{'LookupUserResponse'}->{'Problem'}->{'ProblemType'});
    }
}

sub restructureItemData {
    my $items = shift;
    foreach my $item (@$items) {
        my $fnames  = $item->{'Ext'}->{'ItemIdentifierType'};
        my $fvalues = $item->{'Ext'}->{'ItemIdentifierValue'};
        my $i = 0;
        foreach ( @$fnames ) {
            if ( exists($fvalues->[$i]) ) {
                if ( $_ eq 'ISBN' ) {
                    $item->{'Ext'}->{'BibliographicDescription'}->{$_} = $fvalues->[$i];
                }
                if ( $_ eq 'StateCode' ) {
                    $item->{'Ext'}->{$_} = $fvalues->[$i];
                }
            }
            $i++;
        }
        delete($item->{'Ext'}->{'ItemIdentifierType'});
        delete($item->{'Ext'}->{'ItemIdentifierValue'});
        foreach my $key(keys %{$item->{'Ext'}}) {
            $item->{$key} = $item->{'Ext'}->{$key};
        }
        delete($item->{'Ext'});
        my $id = $item->{'ItemId'}->{'ItemIdentifierValue'};
        delete($item->{'ItemId'});
        $item->{'ItemId'} = $id;
    }
    return $items;
}
    
1;