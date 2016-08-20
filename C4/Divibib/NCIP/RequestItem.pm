package C4::Divibib::NCIP::RequestItem;

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
use C4::Members;
use XML::Simple;

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

C4::Divibib::NCIP::Command::LookupItem - Command LookupItem of the Divibib NCIP interface.

=head1 SYNOPSIS

LookupItem - Check Item availability

=head1 DESCRIPTION

The module implements the LookupItem command of the Divibib NCIP interface. 
It takes an id of an item (divibib item number), agency id (library id at divibib)
and a required language to deliver the status of an item.

=head1 FUNCTIONS

=cut

sub new {
    my $class = shift;
    
    my ( $borrowernumber, $itemId, $loan ) = @_;
    
    my $action = 'PreBook';
    if ( $loan && ($loan eq 'true' || $loan == 1 || lc($loan) eq 'loan' ) ) {
        $action = 'Loan';
    }
    
    my $self  = bless { }, $class;

    my $command = {
            'ncip:version'       => '2.0',
            'xmlns:ncip'         => 'http://www.niso.org/2008/ncip',
            'xmlns:xsi'           => 'http://www.w3.org/2001/XMLSchema-instance',
            'xsi:schemaLocation' => 'http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd'
        };
        
    my $borrower = &GetMember( userid => $borrowernumber );
    # we did not find the borrower by userid
    # let's check whether the borrower number is used instead
    if (! $borrower ) { 
        $borrower = &GetMemberDetails($borrowernumber);
    }
    
    die "borrower not found" unless (  $borrower );

    if ( $borrower ) {
        # $borrower = &GetMemberDetails($borrower->{'borrowernumber'});
        
        $command->{'RequestItem'} = {
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
                 'ItemId' => [ { 'ItemIdentifierValue' => [ $itemId ] } ],               
                 'RequestType' => [ $action ],
                 'Ext' => {
                         'AgencyId' => [ C4::Context->preference("DivibibAgencyId") ],
                         'Language' => [ 'de' ],
                         'UnstructuredAddressType' =>  [ 'EmailAddress' ],
                         'UnstructuredAddressData' =>  [ $borrower->{'email'} ]
                      }
             };
    }
        
    $self->{'cmd'} = $command;   
    
    $self->_initResponse();

    return $self;
}

sub getXML {
    my $self = shift;
    
    return XMLout( $self->{'cmd'}, RootName => 'NCIPMessage', ValueAttr => {} );
}

sub _initResponse {
    my $self = shift;
    
    $self->{'response'} = {
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
    
    $self->_initResponse();
    
    my $response = XMLin( shift, ForceArray => [ ] );
    
    return unless ($response);
    
    $self->{'responseOk'} = 1;
    
    if ( exists($response->{'RequestItemResponse'}) && 
         exists($response->{'RequestItemResponse'}->{'Ext'}) &&
         exists($response->{'RequestItemResponse'}->{'Ext'}->{'Locality'}) )
    {
        $self->{'response'}->{'URL'} = $response->{'RequestItemResponse'}->{'Ext'}->{'Locality'};
    }
    else {
         $self->responseError('Incomplete item data','0');
    }
    
    
    if ( exists($response->{'LookupUserResponse'}) && 
         exists($response->{'LookupUserResponse'}->{'Problem'}) ) 
    {
        $self->responseError(
                $response->{'LookupUserResponse'}->{'Problem'}->{'ProblemDetail'},
                $response->{'LookupUserResponse'}->{'Problem'}->{'ProblemType'});
    }
}
1;
