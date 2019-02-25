package C4::Divibib::NCIP::LookupItem;

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
    my $itemId = shift;
    
    my $self  = bless { }, $class;

    my $command = {
            'ncip:version'       => '2.0',
            'xmlns:ncip'         => 'http://www.niso.org/2008/ncip',
            'xmlns:xsi'           => 'http://www.w3.org/2001/XMLSchema-instance',
            'xsi:schemaLocation' => 'http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd'
        };

    my $agency = C4::Context->preference("DivibibAgencyId");
    if ( $agency ) {
        my @agencies = split(",",$agency);
        $agency = $agencies[0];
    }
    
    $command->{'LookupItem'} = {
        'ItemId' => [ { 'ItemIdentifierValue' => [ $itemId ] } ],
	,
	'Ext' => [ {
			'AgencyId' => [ $agency ],
			'Language' => [ 'de' ]
			} ]
    };
        
    $self->{'cmd'} = $command;
    
    $self->{'itemId'} = $itemId;
    
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
             'ItemId' => $self->{'itemId'},
             'ItemType' => '',
             'BibliographicDescription' => {},
             'Available' => 0,
             'DateAvailable' => '',
             'Reservable' => 0,
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
    
    if ( exists($response->{'LookupItemResponse'}) && 
         exists($response->{'LookupItemResponse'}->{'Problem'}) ) 
    {
        $self->responseError(
                $response->{'LookupItemResponse'}->{'Problem'}->{'ProblemDetail'},
                $response->{'LookupItemResponse'}->{'Problem'}->{'ProblemType'});
    }
    else {
        if ( exists($response->{'LookupItemResponse'}) && 
            exists($response->{'LookupItemResponse'}->{'ItemId'}) )
        {
            $self->{'response'}->{'ItemId'} = $response->{'LookupItemResponse'}->{'ItemId'}->{'ItemIdentifierValue'};
        }
    
        if ( exists($response->{'LookupItemResponse'}) && 
            exists($response->{'LookupItemResponse'}->{'Ext'}) )
        {
            if ( exists($response->{'LookupItemResponse'}->{'Ext'}->{'BibliographicDescription'} ) )
            {
                $self->{'response'}->{'ItemType'} = $response->{'LookupItemResponse'}->{'Ext'}->{'BibliographicDescription'}->{'MediumType'};
                $self->{'response'}->{'BibliographicDescription'}->{'Title'} = $response->{'LookupItemResponse'}->{'Ext'}->{'BibliographicDescription'}->{'Title'};
                $self->{'response'}->{'BibliographicDescription'}->{'Author'} = $response->{'LookupItemResponse'}->{'Ext'}->{'BibliographicDescription'}->{'Author'};
                $self->{'response'}->{'BibliographicDescription'}->{'Publisher'} = $response->{'LookupItemResponse'}->{'Ext'}->{'BibliographicDescription'}->{'Publisher'};
                $self->{'response'}->{'BibliographicDescription'}->{'PublicationDate'} = $response->{'LookupItemResponse'}->{'Ext'}->{'BibliographicDescription'}->{'PublicationDate'};
                $self->{'response'}->{'BibliographicDescription'}->{'MediumType'} = $response->{'LookupItemResponse'}->{'Ext'}->{'BibliographicDescription'}->{'MediumType'};
            }
            if ( exists($response->{'LookupItemResponse'}->{'Ext'}->{'DateAvailable'})  &&
                $response->{'LookupItemResponse'}->{'Ext'}->{'DateAvailable'} =~ /^(\d\d\d\d-\d\d-\d\d)/
            )
            {
                $self->{'response'}->{'DateAvailable'} = $1;
            }
            if ( exists($response->{'LookupItemResponse'}->{'Ext'}->{'ItemIdentifierType'}) &&
                reftype($response->{'LookupItemResponse'}->{'Ext'}->{'ItemIdentifierType'}) eq 'ARRAY' &&
                exists($response->{'LookupItemResponse'}->{'Ext'}->{'ItemIdentifierValue'}) &&
                reftype($response->{'LookupItemResponse'}->{'Ext'}->{'ItemIdentifierValue'}) eq 'ARRAY' )
            {
                # read attributes
                my $fnames  = $response->{'LookupItemResponse'}->{'Ext'}->{'ItemIdentifierType'};
                my $fvalues = $response->{'LookupItemResponse'}->{'Ext'}->{'ItemIdentifierValue'};
            
                my $i = 0;
                foreach ( @$fnames ) {
                    if ( exists($fvalues->[$i]) && ref($fvalues->[$i]) ne 'HASH' ) {
                        my $val = $fvalues->[$i];
                        $val =~ s/^\s+|\s+$//g;
                        if ( $val eq 'true' && ($_ eq 'Available' || $_ eq 'Reservable') ) {
                            $self->{'response'}->{$_} = 1;
                        }
                        elsif ($_ eq 'ISBN' ) {
                            $self->{'response'}->{'BibliographicDescription'}->{'ISBN'} = $val;
                        }
                        elsif ( ($_ eq 'StateCode' || $_ eq 'StateMessage') ) {
                            $self->{'response'}->{$_} = $val;
                        }
                    }
                    $i++;
                }
            }
        }
        else {
            $self->responseError('Incomplete item data','0');
        }
    }

}
1;
