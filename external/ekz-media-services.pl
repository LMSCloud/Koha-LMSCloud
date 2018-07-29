#!/usr/bin/perl -w

# Copyright 2017 (C) LMSCLoud GmbH
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

use utf8;
use Data::Dumper;
use XML::Parser;
use XML::Writer;

use C4::External::EKZ::BestellsystemWSDL;


binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

select(STDERR);
$| = 1;
select(STDOUT); # default
$| = 1;

my $debugIt = 1;

my $soapEnvelope = '';
my $soapEnvelopeHash = {};
my $soapBody = '';
my $soapResponseElement;
my $httpResponse = '';

print STDERR "ekz-media-services.pl ENV:\n" if $debugIt;
print STDERR Dumper(\%ENV) if $debugIt;

# read the SOAP request from STDIN into $soapEnvelope
while (<STDIN>) {
    my $stdinLine = $_;
    print STDERR ("ekz-media-services.pl STDIN:" . $stdinLine) if $debugIt;
    $soapEnvelope .= $stdinLine;
}
print STDERR ("ekz-media-services.pl STDIN:" . "\n") if $debugIt;
  
my $p1 = new XML::Parser(Style => 'Tree', ProtocolEncoding => 'UTF-8');
my $soapEnvelopeDeserialized = $p1->parse($soapEnvelope);                    # this is an array ref on ('soap:Envelope', [ ... ])
print STDERR "ekz-media-services.pl soapEnvelopeDeserialized:\n" if $debugIt;
print STDERR Dumper($soapEnvelopeDeserialized) if $debugIt;

# bringing the request from array in hash form to enable easier field access in the application modules
$soapEnvelopeHash = &buildHashFromArray($soapEnvelopeDeserialized->[0], $soapEnvelopeDeserialized->[1]);
print STDERR "ekz-media-services.pl soapEnvelopeHash:\n" if $debugIt;
print STDERR Dumper($soapEnvelopeHash) if $debugIt;


my $requiredHttpSoapAction = $ENV{'HTTP_SOAPACTION'};    # get name of web service

# handle supported web service: budgetcheck, dublettencheck, bestellinfo
if ( $requiredHttpSoapAction =~ /.*urn:budgetcheck.*/ ) {
    $soapResponseElement = C4::External::EKZ::BestellsystemWSDL::BudgetCheckElement($soapEnvelopeHash);
} elsif ( $requiredHttpSoapAction =~ /.*urn:dublettencheck.*/ ) {
    $soapResponseElement = C4::External::EKZ::BestellsystemWSDL::DublettenCheckElement($soapEnvelopeHash);
} elsif ( $requiredHttpSoapAction =~ /.*urn:bestellinfo.*/ ) {
    if ( $soapEnvelope =~ /^.*?<.*?:Body>\n*(.*)<\/.*?:Body>.*?$/s ) {
        $soapBody = $1;
    }
    $soapResponseElement = C4::External::EKZ::BestellsystemWSDL::BestellInfoElement($soapBody, $soapEnvelopeHash);
} else {    # create error response for unsupported webservice
    $soapResponseElement = C4::External::EKZ::BestellsystemWSDL::NotImplementedElement($requiredHttpSoapAction, $soapEnvelopeHash);
}

# build the HTTP Response from the SOAP object $soapResponseElement
$httpResponse = buildSoapResponse([$soapResponseElement]);

print STDERR ("ekz-media-services.pl is writing this httpResponse to STDOUT:\n") if $debugIt;
print STDERR $httpResponse if $debugIt;

print STDOUT $httpResponse;



sub buildHashFromArray {
    my ($nodeName, $fields) = @_;
    my %retHash = ();
#print STDERR "ekz-media-services.pl::buildHashFromArray nodeName:",$nodeName, ": fields:", $fields, ": \@fields:", @$fields, ": field count:", @$fields+0, "\n" if $debugIt;
#print STDERR "ekz-media-services.pl::buildHashFromArray nodeName:",$nodeName, ": exists(\$retHash{$nodeName}:", exists($retHash{$nodeName}), "\n" if $debugIt;

    # check if to handle a leave of the tree        
    if ( !defined($fields) ) {
        #$retHash{$nodeName} = undef;
        $retHash{$nodeName} = '';       # being not so strict makes life easier
    } elsif ( @$fields+0 <= 1 ) {
        $retHash{$nodeName} = '';
    } elsif ( @$fields+0 == 2 && $fields->[1] eq '0' ) {
        $retHash{$nodeName} = '';
    } elsif ( @$fields+0 == 3 && $fields->[1] eq '0' ) {
        my $content = $fields->[2];
        $retHash{$nodeName} = $content;
    } else {
        # it is not a leaf
        my $attr = $fields->[0];
        for ( my $i = 1; $i < @$fields+0; $i += 2 ) {
            my $indicator;
            my $content;
            my $childName;
            my $child;

#print STDERR "ekz-media-services.pl::buildHashFromArray nodeName:",$nodeName, ": exists(\$retHash{$nodeName}2:", exists($retHash{$nodeName}), "\n" if $debugIt;
            if ( defined $fields->[$i] && length($fields->[$i]) > 0 ) {
#print STDERR "ekz-media-services.pl::buildHashFromArray nodeName:",$nodeName, ": exists(\$retHash{$nodeName}3:", exists($retHash{$nodeName}), "\n" if $debugIt;
                if ( $fields->[$i] eq '0' ) {
                    my $content = $fields->[$i+1];
                    #$retHash{$nodeName}->{'soapEnvelopeDeserializedContent'} .= $content;
                } else {
                    my $hashRef = buildHashFromArray($fields->[$i], $fields->[$i+1]);
                    if ( exists($retHash{$nodeName}) ) {
#print STDERR "ekz-media-services.pl::buildHashFromArray nodeName:",$nodeName, ": ref(\$retHash{\$nodeName}):", ref($retHash{$nodeName}), ":\n" if $debugIt;
                        if ( exists($retHash{$nodeName}->{$fields->[$i]}) ) {
                            if ( ref($retHash{$nodeName}->{$fields->[$i]}) eq 'ARRAY' ) {
                                push @{$retHash{$nodeName}->{$fields->[$i]}}, $hashRef->{$fields->[$i]};
                            } else {
                                my @tmpArray;
                                $tmpArray[0] = $retHash{$nodeName}->{$fields->[$i]};
                                $tmpArray[1] = $hashRef->{$fields->[$i]};
                                $retHash{$nodeName}->{$fields->[$i]} = \@tmpArray;
                            }
                        } else {
                            $retHash{$nodeName}->{$fields->[$i]} = $hashRef->{$fields->[$i]};
                        }
                    } else {
                        $retHash{$nodeName} = $hashRef;
                    }
                }
            }
        }
    }

#print STDERR "ekz-media-services.pl::buildHashFromArray nodeName:",$nodeName, ": retHash:", %retHash, ": \\\%retHash:", \%retHash, ": retHash{nodeName}:", $retHash{$nodeName}, ":\n" if $debugIt;
    return \%retHash;
}

sub buildSoapResponse {
    my @soapResponseElements = @_;
    my $header = '';
    my $content = '';
    my $response = '';

print STDERR "ekz-media-services.pl::buildSoapResponse soapResponseElements:\n" if $debugIt;
print STDERR Dumper(@soapResponseElements) if $debugIt;
    
    my $xmlwriter = XML::Writer->new(OUTPUT => 'self', NEWLINES => 0, DATA_MODE => 1, DATA_INDENT => 2, ENCODING => 'utf-8' );

    $content = "\n";
    $xmlwriter->xmlDecl("UTF-8");
    $xmlwriter->startTag('soap:Envelope',
                            'soap:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/',
                            'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                            'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/',
                            'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                            'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance');
    $xmlwriter->startTag('soap:Body');

    buildSoapContent($xmlwriter, @soapResponseElements);

    $xmlwriter->endTag('soap:Body');
    $xmlwriter->endTag('soap:Envelope');
    $content .= $xmlwriter->end();

    my $contentLen = length($content);
    $header = "Content-Type: text/xml; charset=\"utf-8\"\nContent-Length: $contentLen\n";
    $response = $header . $content;

    return $response;
}


sub buildSoapContent {
    my ($xmlwriter, @elements) = @_;

    foreach my $element (@elements) {
print STDERR "ekz-media-services.pl::buildSoapContent element is a :", $element, ": and ref gives:", ref($element), "\n" if $debugIt;
print STDERR "ekz-media-services.pl::buildSoapContent element:\n" if $debugIt;
print STDERR Dumper($element) if $debugIt;
        if ( ref($element) eq 'ARRAY' ) {
            foreach my $subelement (@$element) {
                print STDERR "ekz-media-services.pl::buildSoapContent handling subelement:\n" if $debugIt;
                buildSoapContent($xmlwriter, $subelement);
            }
        } else
        {
            if ( ref($element) eq 'REF' ) {
                print STDERR "ekz-media-services.pl::buildSoapContent handling extra reference:\n" if $debugIt;
                buildSoapContent($xmlwriter, $$element->SOAP::Data::value());
            } else {
                my $name = $element->SOAP::Data::name();
                #my $type = $element->SOAP::Data::type();   # does not work with any $element
                #my $type = $element->type();               # does not work with any $element
                my $type = $element->{'_type'};             # seems to work with any $element
                my $value = $element->SOAP::Data::value();
                my $prefix = $element->SOAP::Data::prefix();
                my $attr = $element->SOAP::Data::attr();
                my $attrKey = '';
                my $attrVal = '';

                if ( defined($prefix) && length($prefix) > 0 ) {
                    $name = $prefix . ':' . $name;
                }
                print STDERR "ekz-media-services.pl::buildSoapContent  attr:$attr: ref(attr):", ref($attr), ": isa(attr):",  ":\n" if $debugIt;

                # Maximal 1 attribute is handled, which is sufficient at the moment.
                if ( defined($attr) && ref($attr) eq "" && length($attr) > 0 && index($attr, '=') != -1 ) {
                    ($attrKey, $attrVal) = split('=', $attr);
                    if ( $attrVal =~ /^"*(.*?)"*$/ ) {
                        $attrVal = $1;
                   }
                }
        
                if ( defined($type) && $type eq 'string' ) { # finally at a leaf of the tree
                    # element is no ARRAY, no REF, type is string
                    print STDERR "ekz-media-services.pl::buildSoapContent element is no ARRAY, no REF, type is string:\n" if $debugIt;
                    if ( defined($value) && length($value) > 0 ) {
                        if ( length($attrKey) > 0 && length($attrVal) > 0 ) {
                            $xmlwriter->startTag($name, $attrKey => $attrVal);
                        } else {
                            $xmlwriter->startTag($name);
                        }
                        $xmlwriter->characters($value);
                        $xmlwriter->endTag($name);
                    } else {
                        if ( length($attrKey) > 0 && length($attrVal) > 0 ) {
                            $xmlwriter->emptyTag($name, $attrKey => $attrVal);
                        } else {
                            $xmlwriter->emptyTag($name);
                        }
                    }
                } else {
                    # element is no ARRAY, no REF, no string
                    print STDERR "ekz-media-services.pl::buildSoapContent element is no ARRAY, no REF, no string:\n" if $debugIt;
                    if ( length($attrKey) > 0 && length($attrVal) > 0 ) {
                        $xmlwriter->startTag($name, $attrKey => $attrVal);
                    } else {
                        $xmlwriter->startTag($name);
                    }
                    buildSoapContent($xmlwriter, $value);
                    $xmlwriter->endTag($name);
                }
            }
        }
    }
}
