package C4::External::EKZ::lib::EkzWebServices;

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
use Time::HiRes qw(gettimeofday);
use Carp;
use Data::Dumper;
use LWP::UserAgent;
use XML::Writer;
use XML::LibXML;
use MIME::Base64;

use C4::Context;
use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );



binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

our $VERSION = '0.01';

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

#use constant EKZWSURL => 'https://87.137.73.13:9443/epmw-2.0/services/BestellsystemService'; # do not use regularily, because fixed IP address is inflexible
use constant EKZWSURL => 'https://mbk.ekz.de:9443/epmw-2.0/services/BestellsystemService'; # explicitly not a system preference
#use constant EKZWSURL => 'http://mbk.ekz.de:9080/epmw-2.0/services/BestellsystemService'; # do not use regularily, because credentials are sent in cleartext

my $debugIt = 1;

BEGIN {
    require Exporter;
    $VERSION = 1.00.00.000;
    @ISA = qw(Exporter);
    @EXPORT = qw(EKZWSURL);
}

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	$self->{'url'} = EKZWSURL;
	
    my $ua = LWP::UserAgent->new;
	$ua->timeout(60);
	$ua->env_proxy;
    $ua->ssl_opts( "verify_hostname" => 0 );
    push @{ $ua->requests_redirectable }, 'POST';

	$self->{'ua'} = $ua;
    
    
    # Get credentials for web service 'MedienDaten' from file /etc/koha/ekz-title-service.key.
    my %config = ();
    my $file = '/etc/koha/ekz-title-service.key';
    if ( -e $file && -f $file ) {
        open(my $fh, '<:encoding(UTF-8)', $file) or carp "Could not open ekz title service configuration file '$file' $!";
        while (<$fh>) {
            next if /^#/; # skip line if it starts with a hash
            chomp; # remove \n 
            my($name,$val) = split '=', $_, 2; #split line into two values, on an = sign
            $name =~ s/^\s+//;
            $name =~ s/\s+$//;
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            next unless ($name && $val); # make sure the value is set
            $config{$name} = $val;
        }
        close $fh;
    }
    carp "ekzKundenNr value not defined in ekz title service config '$file'" if (! exists($config{'ekzKundenNr'}) );
    carp "passwort value not defined in ekz title service config '$file'" if (! exists($config{'passwort'}) );
    carp "lmsNutzer value not defined in ekz title service config '$file'" if (! exists($config{'lmsNutzer'}) );
    $self->{'ekzKundenNrWSMD'} = defined($config{'ekzKundenNr'}) ? $config{'ekzKundenNr'} : 'UNDEFINED';
    $self->{'passwortWSMD'}  = defined($config{'passwort'}) ? $config{'passwort'} : 'UNDEFINED';
    $self->{'lmsNutzerWSMD'}  = defined($config{'lmsNutzer'}) ? $config{'lmsNutzer'} : 'UNDEFINED';


    ## Get credentials of customer specific login at ekz for the other ekz web services from system preferences.
    ## Some libraries use different ekz Kundennummer for different branches; in this case the system preferences contain '|'-separated lists.
    my $ekzWebServicesCustomerNumber = C4::Context->preference('ekzWebServicesCustomerNumber');
    my $ekzWebServicesPassword = C4::Context->preference('ekzWebServicesPassword');
    my $ekzWebServicesUserName = C4::Context->preference('ekzWebServicesUserName');
    my $ekzProcessingNoticesEmailAddress = C4::Context->preference('ekzProcessingNoticesEmailAddress');
    my $ekzWebServicesDefaultBranch = C4::Context->preference('ekzWebServicesDefaultBranch');

    carp "ekzWebServicesCustomerNumber value not defined in system preferences" if ( !defined($ekzWebServicesCustomerNumber) );
    carp "ekzWebServicesPassword value not defined in system preferences" if ( !defined($ekzWebServicesPassword) );
    carp "ekzWebServicesUserName value not defined in system preferences" if ( !defined($ekzWebServicesUserName) );
    carp "ekzProcessingNoticesEmailAddress value not defined in system preferences" if ( !defined($ekzProcessingNoticesEmailAddress) );
    carp "ekzWebServicesDefaultBranch value not defined in system preferences" if ( !defined($ekzWebServicesDefaultBranch) );
print STDERR "EkzWebServices::new() ekzWebServicesCustomerNumber:$ekzWebServicesCustomerNumber:\n" if $debugIt;

    my @ekzWebServicesCustomerNumbers = split( /\|/, $ekzWebServicesCustomerNumber );
    my @ekzWebServicesPasswords = split( /\|/, $ekzWebServicesPassword );
    my @ekzWebServicesUserNames = split( /\|/, $ekzWebServicesUserName );
    my @ekzProcessingNoticesEmailAddresses = split( /\|/, $ekzProcessingNoticesEmailAddress );
    my @ekzWebServicesDefaultBranches = split( /\|/, $ekzWebServicesDefaultBranch );

    if ( defined($ekzProcessingNoticesEmailAddresses[0]) ){
        $self->{'fallBackEkzProcessingNoticesEmailAddress'} = $ekzProcessingNoticesEmailAddresses[0];
    } else {
        $self->{'fallBackEkzProcessingNoticesEmailAddress'} = '';
    }

    if ( defined($ekzWebServicesDefaultBranches[0]) ){
        $self->{'fallBackEkzWebServicesDefaultBranch'} = $ekzWebServicesDefaultBranches[0];
    } else {
        $self->{'fallBackEkzWebServicesDefaultBranch'} = '';
    }

    my $ekzWebServicesCustomerNumbersCnt = scalar @ekzWebServicesCustomerNumbers;
print STDERR "EkzWebServices::new() ekzWebServicesCustomerNumbersCnt:$ekzWebServicesCustomerNumbersCnt:\n" if $debugIt;
#print STDERR "EkzWebServices::new() Dumper(ekzWebServicesCustomerNumbers):", Dumper(@ekzWebServicesCustomerNumbers), ":\n" if $debugIt;

    for ( my $i = 0; $i < $ekzWebServicesCustomerNumbersCnt; $i += 1 ) {
        if ( defined($ekzWebServicesCustomerNumbers[$i]) && length($ekzWebServicesCustomerNumbers[$i]) ) {
            $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzKundenNr'} = $ekzWebServicesCustomerNumbers[$i];
            if ( defined($ekzWebServicesPasswords[$i]) && length($ekzWebServicesPasswords[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzPasswort'} = $ekzWebServicesPasswords[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzPasswort'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzPasswort'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzPasswort'} : 'UNDEFINED';
            }
            if ( defined($ekzWebServicesUserNames[$i]) && length($ekzWebServicesUserNames[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzLmsNutzer'} = $ekzWebServicesUserNames[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzLmsNutzer'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzLmsNutzer'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzLmsNutzer'} : 'UNDEFINED';
            }
            if ( defined($ekzProcessingNoticesEmailAddresses[$i]) && length($ekzProcessingNoticesEmailAddresses[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzProcessingNoticesEmailAddress'} = $ekzProcessingNoticesEmailAddresses[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzProcessingNoticesEmailAddress'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzProcessingNoticesEmailAddress'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzProcessingNoticesEmailAddress'} : 'UNDEFINED';
            }
            if ( defined($ekzWebServicesDefaultBranches[$i]) && length($ekzWebServicesDefaultBranches[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzWebServicesDefaultBranch'} = $ekzWebServicesDefaultBranches[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzWebServicesDefaultBranch'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzWebServicesDefaultBranch'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzWebServicesDefaultBranch'} : 'UNDEFINED';
            }
        }
#print STDERR "EkzWebServices::new() Dumper(self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}):", Dumper($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}), ":\n" if $debugIt;
    }

	return $self;
}

sub getEkzKundenNr {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzKundenNr'}) ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzKundenNr'};
        }
    }
print STDERR "EkzWebServices::getEkzKundenNr(ekzCustomerNumber:$ekzCustomerNumber) returns ret:$ret:\n" if $debugIt;
    return $ret;
}

sub getEkzPasswort {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzPasswort'}) ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzPasswort'};
        }
    }
print STDERR "EkzWebServices::getEkzPasswort(ekzCustomerNumber:$ekzCustomerNumber) returns ret:$ret:\n" if $debugIt;
    return $ret;
}

sub getEkzLmsNutzer {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzLmsNutzer'}) ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzLmsNutzer'};
        }
    }
print STDERR "EkzWebServices::getEkzLmsNutzer(ekzCustomerNumber:$ekzCustomerNumber) returns ret:$ret:\n" if $debugIt;
    return $ret;
}

sub getEkzProcessingNoticesEmailAddress {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = $self->{'fallBackEkzProcessingNoticesEmailAddress'};

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzProcessingNoticesEmailAddress'}) && $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzProcessingNoticesEmailAddress'} ne 'UNDEFINED' ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzProcessingNoticesEmailAddress'};
        }
    }
print STDERR "EkzWebServices::getEkzProcessingNoticesEmailAddress(ekzCustomerNumber:$ekzCustomerNumber) returns ret:$ret:\n" if $debugIt;
    return $ret;
}

sub getEkzWebServicesDefaultBranch {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = $self->{'fallBackEkzWebServicesDefaultBranch'};

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzWebServicesDefaultBranch'}) && $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzWebServicesDefaultBranch'} ne 'UNDEFINED' ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzWebServicesDefaultBranch'};
        }
    }
print STDERR "EkzWebServices::getEkzProcessingNoticesEmailAddress(ekzCustomerNumber:$ekzCustomerNumber) returns ret:$ret:\n" if $debugIt;
    return $ret;
}

sub getEkzCustomerNumbers {
	my $self = shift;

    my @ekzWebServicesCustomerNumbers = keys %{$self->{'ekzCustomerBranch'}};

    return @ekzWebServicesCustomerNumbers;
}

# read ekz title data in MARC21 XML format using web service MedienDaten, search by ekzArtikelNr
sub callWsMedienDaten {
	my $self = shift;
	my $ekzArtikelNr = shift;

	my $messageId = $self->genTransactionId('');
	my $zeitstempel = $self->genZeitstempel();

	my $soapResponseBody = '';
    my $result = {  'count' => 0,
                    'records' => []
    };
	
	
    my $xmlwriter = XML::Writer->new(OUTPUT => 'self', NEWLINES => 0, DATA_MODE => 1, DATA_INDENT => 2, ENCODING => 'utf-8' );

    #$xmlwriter->xmlDecl("UTF-8");    # seems to be not necessary
    $xmlwriter->startTag( 'soap:Envelope',
                              'soap:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/',
                              'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/');
    
    $xmlwriter->startTag(   'soap:Header');
    $xmlwriter->startTag(     'wsse:Security',
                                  'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
                                  'xmlns:wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd',
                                  'soap:mustUnderstand' => '1');
    $xmlwriter->startTag(       'wsse:UsernameToken',
                                    'wsu:Id' => 'UsernameToken-3d1e2053-4b6d-41c0-bb25-ba7ab39ce6dc');    # it seems that we can use a constant non varying UUID here
    $xmlwriter->dataElement(      'wsse:Username' => 'bob');
    $xmlwriter->dataElement(      'wsse:Password', 'bobPW', 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText');
    $xmlwriter->endTag(         'wsse:UsernameToken');
    $xmlwriter->endTag(       'wsse:Security');
    $xmlwriter->endTag(     'soap:Header');
    
    $xmlwriter->startTag(   'soap:Body');
    $xmlwriter->startTag(     'bes:MedienDatenElement',
                                  'xmlns:bes' => 'http://www.ekz.de/BestellsystemWSDL');
    $xmlwriter->dataElement(    'messageID' => $messageId);
    $xmlwriter->dataElement(    'zeitstempel' => $zeitstempel);
    $xmlwriter->dataElement(    'ekzKundenNr' => $self->{'ekzKundenNrWSMD'});
    $xmlwriter->dataElement(    'passwort' => $self->{'passwortWSMD'});
    $xmlwriter->dataElement(    'lmsNutzer' => $self->{'lmsNutzerWSMD'});
    $xmlwriter->dataElement(    'datenTyp' => 'MARC21XML');
    $xmlwriter->dataElement(    'einkauf' => 'true');    # required if title data are not paid already
    $xmlwriter->dataElement(    'ekzArtikelNr' => $ekzArtikelNr);
    $xmlwriter->endTag(       'bes:MedienDatenElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();
	
	my $soapResponse = $self->doQuery('"urn:mediendaten"', $soapEnvelope);

print STDERR "EkzWebServices::callWsMedienDaten() soapResponse:", $soapResponse, ":\n" if $debugIt;
print STDERR Dumper($soapResponse) if $debugIt;
    

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

print STDERR "EkzWebServices::callWsMedienDaten() root Elem:", $root, ":\n" if $debugIt;
print STDERR Dumper($root) if $debugIt;

        my $titelnodes = $root->findnodes('soap:Body/*/titel');
print STDERR "EkzWebServices::callWsMedienDaten() titelnodes:", $titelnodes, ":\n" if $debugIt;
print STDERR Dumper($titelnodes) if $debugIt;

		foreach my $titelnode ( $titelnodes->get_nodelist() ) {
print STDERR "EkzWebServices::callWsMedienDaten() titelnode->nodeName:", $titelnode->nodeName, ":\n" if $debugIt;
			foreach my $child ( $titelnode->childNodes() ) {
print STDERR "EkzWebServices::callWsMedienDaten() child->nodeName:", $child->nodeName, ":\n" if $debugIt;
                # check if it is the hit with correct ekzArtikelNr
				if ( $child->nodeName eq 'ekzArtikelNr' ) {
				    if ( $child->textContent eq $ekzArtikelNr ) {
	                    my $datenSatzNodes = $titelnode->findnodes('datenSatz');
print STDERR "EkzWebServices::callWsMedienDaten() datenSatzNodes:", $datenSatzNodes, ":\n" if $debugIt;
print STDERR Dumper($datenSatzNodes) if $debugIt;
                        my $datenSatzNode = $datenSatzNodes->[0];
                        if ( defined $datenSatzNode && defined $datenSatzNode->textContent ) {
                            my $marc21XmlData = decode_base64($datenSatzNode->textContent);
print STDERR "EkzWebServices::callWsMedienDaten() marc21XmlData:", $marc21XmlData, ":\n" if $debugIt;
                            if ( defined($marc21XmlData) && length($marc21XmlData) > 0 ) {
                                my $marcrecord;
                                eval {
                                    $marcrecord =  MARC::Record::new_from_xml( $marc21XmlData, "utf8", 'MARC21' );
                                };
                                carp "EkzWebServices::callWsMedienDaten: error in MARC::Record::new_from_xml:$@:\nmarc21XmlData:$marc21XmlData" if $@;

                                if ( $marcrecord ) {
                                    push @{$result->{'records'}}, $marcrecord;
print STDERR Dumper($result->{'records'}->[0]) if $debugIt;
print STDERR Dumper($result->{'records'}->[0]) if $debugIt;
                                    $result->{'count'} += 1;
                                    last;
                                }
                            }
				        }
				    }
				}
			}
            if ( $result->{'count'} > 0 ) {    # one hit is sufficient
                last;
            }
		}
	}
	
	return $result;
}

# read standing order information using web service StoList
sub callWsStoList {
	my $self = shift;
    my $ekzCustomerNumber = shift;                  # mandatory
	my $selJahr = shift;                            # mandatory
	my $selStoId = shift;                           # optional
	my $selMitTitel = shift;                        # optional
    my $selMitKostenstellen = shift;                # optional
	my $selMitEAN = shift;                          # optional
	my $selStatusUpdate = shift;                    # optional
	my $selErweitert = shift;                       # optional
    my $refStoListElement = shift;                  # for storing the StoListElement of the SOAP response body

	my $result = {  'standingOrderCount' => 0,
                    'standingOrderRecords' => [],
                    'messageID' => ''
    };
	
	
print STDERR "EkzWebServices::callWsStoList() ekzCustomerNumber:", $ekzCustomerNumber, ": selJahr:", $selJahr, ": selStoId:", defined($selStoId) ? $selStoId : 'undef', ": selMitTitel:", defined($selMitTitel) ? $selMitTitel : 'undef',
                                ": selMitKostenstellen:", defined($selMitKostenstellen) ? $selMitKostenstellen : 'undef', ": selMitEAN:", defined($selMitEAN) ? $selMitEAN : 'undef',
                                ": selStatusUpdate:", defined($selStatusUpdate) ? $selStatusUpdate : 'undef', ": selErweitert:", defined($selErweitert) ? $selErweitert : 'undef', ":\n" if $debugIt;

    my $xmlwriter = XML::Writer->new(OUTPUT => 'self', NEWLINES => 0, DATA_MODE => 1, DATA_INDENT => 2, ENCODING => 'utf-8' );

    #$xmlwriter->xmlDecl("UTF-8");    # seems to be not necessary
    $xmlwriter->startTag( 'soap:Envelope',
                              'soap:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/',
                              'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/');
    
    $xmlwriter->startTag(   'soap:Header');
    $xmlwriter->startTag(     'wsse:Security',
                                  'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
                                  'xmlns:wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd',
                                  'soap:mustUnderstand' => '1');
    $xmlwriter->startTag(       'wsse:UsernameToken',
                                    'wsu:Id' => 'UsernameToken-3d1e2053-4b6d-41c0-bb25-ba7ab39ce6dc');    # it seems that we can use a constant non varying UUID here
    $xmlwriter->dataElement(      'wsse:Username' => 'bob');
    $xmlwriter->dataElement(      'wsse:Password', 'bobPW', 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText');
    $xmlwriter->endTag(         'wsse:UsernameToken');
    $xmlwriter->endTag(       'wsse:Security');
    $xmlwriter->endTag(     'soap:Header');
    
    $xmlwriter->startTag(   'soap:Body');
    $xmlwriter->startTag(     'bes:StoListElement',
                                  'xmlns:bes' => 'http://www.ekz.de/BestellsystemWSDL');
    $xmlwriter->dataElement(    'kundenNummer' => $self->getEkzKundenNr($ekzCustomerNumber));
    $xmlwriter->dataElement(    'passwort' => $self->getEkzPasswort($ekzCustomerNumber));
    $xmlwriter->dataElement(    'lmsNutzer' => $self->getEkzLmsNutzer($ekzCustomerNumber));
    $xmlwriter->dataElement(    'jahr' => $selJahr);

    if ( defined $selStoId && length($selStoId) > 0 ) {
        $xmlwriter->dataElement('stoID' => $selStoId);    # <!--Optional. Wird eine StoID übergeben, werden die Infos nur für diese Sto übermittelt, ansonsten für alle StOs des angefragten Jahres-->
    }
    if ( defined $selMitTitel && length($selMitTitel) > 0 ) {
        $xmlwriter->dataElement('mitTitel' => $selMitTitel);    # <!--Wird hier true übergeben, dann werden die Titel in der Antwort Nachricht mit übermittelt. Bei false werden nur die StO Varianten geliefert (für eine übersicht und gezielte Abfragen)-->
    }
    if ( defined $selMitKostenstellen && length($selMitKostenstellen) > 0 ) {
        $xmlwriter->dataElement('mitKostenstellen' => $selMitKostenstellen);    # <!-- entscheidet, ob die Kostenstellen zu den Titeln geliefert werden sollen, OPTIONAL →
    }
    if ( defined $selMitEAN && length($selMitEAN) > 0 ) {
        $xmlwriter->dataElement('mitEAN' => $selMitEAN);    # <!-- entscheidet, ob die ggf. vorhandene EAN zu den Titeln geliefert werden soll OPTIONAL -->
    }
    if ( defined $selStatusUpdate && length($selStatusUpdate) > 0 ) {
        $xmlwriter->dataElement('statusUpdate' => $selStatusUpdate);    # <!-- liefert nur Titel, deren Status sich seit dem dd.mm.yyyy geändert haben, OPTIONAL -->
    }
    if ( defined $selErweitert && length($selErweitert) > 0 ) {
        $xmlwriter->dataElement('erweitert' => $selErweitert);    # <!—Steuerung, ob statusdatum und anzahl in Antwort geliefert wird, OPTIONAL -->
    }
    $xmlwriter->endTag(       'bes:StoListElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();
	
	my $soapResponse = $self->doQuery('"urn:stolist"', $soapEnvelope);

print STDERR "EkzWebServices::callWsStoList() soapResponse:", $soapResponse, ":\n" if $debugIt;
print STDERR Dumper($soapResponse) if $debugIt;
    
print STDERR "EkzWebServices::callWsStoList() \$refStoListElement:", $refStoListElement, ":\n" if $debugIt;
print STDERR Dumper($refStoListElement) if $debugIt;
    if ( defined ($$refStoListElement) ) {
        $$refStoListElement = '';
        if ( $soapResponse->content =~ /^.*?<.*?:Body>\n*(.*)<\/.*?:Body>.*?$/s ) {
            $$refStoListElement = $1;
        }
    }
print STDERR "EkzWebServices::callWsStoList() \$\$refStoListElement:", $$refStoListElement, ":\n" if $debugIt;
print STDERR Dumper($$refStoListElement) if $debugIt;

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

print STDERR "EkzWebServices::callWsStoList() root Elem:", $root, ":\n" if $debugIt;
print STDERR Dumper($root) if $debugIt;

        my $messageIdNodes = $root->findnodes('soap:Body/*/messageID');
        foreach my $messageIdNode ( $messageIdNodes->get_nodelist() ) {
            $result->{'messageID'} = $messageIdNode->textContent;
            last;
        }

        my $stoNodes = $root->findnodes('soap:Body/*/standingOrderVariante');
print STDERR "EkzWebServices::callWsStoList() stoNodes:", $stoNodes, ":\n" if $debugIt;
print STDERR Dumper($stoNodes) if $debugIt;

		foreach my $stoNode ( $stoNodes->get_nodelist() ) {
print STDERR "EkzWebServices::callWsStoList() stoNode->nodeName:", $stoNode->nodeName, ":\n" if $debugIt;
            my $stoRecord = {'titelCount' => 0, 'titelRecords' => []};
			foreach my $stoChild ( $stoNode->childNodes() ) {    # <stoID> <name> <titel> sind hier interessant
print STDERR "EkzWebServices::callWsStoList() stoChild->nodeName:", $stoChild->nodeName, ":\n" if $debugIt;
                # copy values of hit into stoRecord
				if ( $stoChild->nodeName eq 'titel' ) {
                    my $titelRecord = ();
                    foreach my $titelChild ( $stoChild->childNodes() ) {
                        $titelRecord->{$titelChild->nodeName} = $titelChild->textContent;
                    }
                    push @{$stoRecord->{'titelRecords'}}, $titelRecord;
                    $stoRecord->{'titelCount'} += 1;
                } else {
                    $stoRecord->{$stoChild->nodeName} = $stoChild->textContent;
                }
			}
            push @{$result->{'standingOrderRecords'}}, $stoRecord;
            $result->{'standingOrderCount'} += 1;
print STDERR "EkzWebServices::callWsStoList() result->{'standingOrderRecords'}->[i]:", $result->{'standingOrderRecords'}->[$result->{'standingOrderCount'}-1], ":\n" if $debugIt;
print STDERR Dumper($result->{'standingOrderRecords'}->[$result->{'standingOrderCount'}-1]) if $debugIt;
		}
	}
	
	return $result;
}

# search delivery notes using web service LieferscheinList
sub callWsLieferscheinList {
	my $self = shift;
    my $ekzCustomerNumber = shift;                  # mandatory
	my $selVon = shift;                            # mandatory
	my $selBis = shift;                            # optional
	my $selKundennummerWarenEmpfaenger = shift;    # optional

	my $result = {  'lieferscheinCount' => 0,
                    'lieferscheinRecords' => []
    };

print STDERR "EkzWebServices::callWsLieferscheinList() ekzCustomerNumber:", $ekzCustomerNumber, ": selVon:", $selVon, ": selBis:", defined($selBis) ? $selBis : 'undef', ": selkundennummerWarenEmpfaenger:", defined($selKundennummerWarenEmpfaenger) ? $selKundennummerWarenEmpfaenger : 'undef', ":\n" if $debugIt;

    my $xmlwriter = XML::Writer->new(OUTPUT => 'self', NEWLINES => 0, DATA_MODE => 1, DATA_INDENT => 2, ENCODING => 'utf-8' );

    #$xmlwriter->xmlDecl("UTF-8");    # seems to be not necessary
    $xmlwriter->startTag( 'soap:Envelope',
                              'soap:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/',
                              'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/');
    
    $xmlwriter->startTag(   'soap:Header');
    $xmlwriter->startTag(     'wsse:Security',
                                  'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
                                  'xmlns:wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd',
                                  'soap:mustUnderstand' => '1');
    $xmlwriter->startTag(       'wsse:UsernameToken',
                                    'wsu:Id' => 'UsernameToken-3d1e2053-4b6d-41c0-bb25-ba7ab39ce6dc');    # it seems that we can use a constant non varying UUID here
    $xmlwriter->dataElement(      'wsse:Username' => 'bob');
    $xmlwriter->dataElement(      'wsse:Password', 'bobPW', 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText');
    $xmlwriter->endTag(         'wsse:UsernameToken');
    $xmlwriter->endTag(       'wsse:Security');
    $xmlwriter->endTag(     'soap:Header');
    
    $xmlwriter->startTag(   'soap:Body');
    $xmlwriter->startTag(     'bes:LieferscheinListElement',
                                  'xmlns:bes' => 'http://www.ekz.de/BestellsystemWSDL');
    $xmlwriter->dataElement(    'kundenNummer' => $self->getEkzKundenNr($ekzCustomerNumber));
    $xmlwriter->dataElement(    'passwort' => $self->getEkzPasswort($ekzCustomerNumber));
    $xmlwriter->dataElement(    'lmsNutzer' => $self->getEkzLmsNutzer($ekzCustomerNumber));
    $xmlwriter->dataElement(    'von' => $selVon);

    if ( defined $selBis && length($selBis) > 0 ) {
        $xmlwriter->dataElement('bis' => $selBis);    # optional
    }
    if ( defined $selKundennummerWarenEmpfaenger && length($selKundennummerWarenEmpfaenger) > 0 ) {
        $xmlwriter->dataElement('kundennummerWarenEmpfaenger' => $selKundennummerWarenEmpfaenger);    # optional
    }
    $xmlwriter->endTag(       'bes:LieferscheinListElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();
print STDERR "EkzWebServices::callWsLieferscheinList() soapEnvelope:", $soapEnvelope, ":\n" if $debugIt;
	
	my $soapResponse = $self->doQuery('"urn:lieferscheinlist"', $soapEnvelope);

print STDERR "EkzWebServices::callWsLieferscheinList() soapResponse:", $soapResponse, ":\n" if $debugIt;
print STDERR Dumper($soapResponse) if $debugIt;

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

print STDERR "EkzWebServices::callWsLieferscheinList() root Elem:", $root, ":\n" if $debugIt;
print STDERR Dumper($root) if $debugIt;

        my $lieferscheinNodes = $root->findnodes('soap:Body/*/lieferschein');
print STDERR "EkzWebServices::callWsLieferscheinList() lieferscheinNodes:", $lieferscheinNodes, ":\n" if $debugIt;
print STDERR Dumper($lieferscheinNodes) if $debugIt;

		foreach my $lieferscheinNode ( $lieferscheinNodes->get_nodelist() ) {
print STDERR "EkzWebServices::callWsLieferscheinList() lieferscheinNode->nodeName:", $lieferscheinNode->nodeName, ":\n" if $debugIt;
            my $lieferscheinRecord = ();
			foreach my $lieferscheinChild ( $lieferscheinNode->childNodes() ) {    # <id> <nummer> <datum> sind hier interessant
print STDERR "EkzWebServices::callWsLieferscheinList() lieferscheinChild->nodeName:", $lieferscheinChild->nodeName, ":\n" if $debugIt;
                # copy values of hit into lieferscheinrecord
                if ( $lieferscheinChild->nodeName !~ /^#/ ) {
				    $lieferscheinRecord->{$lieferscheinChild->nodeName} = $lieferscheinChild->textContent;
                }
			}
            push @{$result->{'lieferscheinRecords'}}, $lieferscheinRecord;
            $result->{'lieferscheinCount'} += 1;
print STDERR "EkzWebServices::callWsLieferscheinList() result->{'lieferscheinRecords'}->[i]:", $result->{'lieferscheinRecords'}->[$result->{'lieferscheinCount'}-1], ":\n" if $debugIt;
print STDERR Dumper($result->{'lieferscheinRecords'}->[$result->{'lieferscheinCount'}-1]) if $debugIt;
		}
	}
	
	return $result;
}

# read all data of one delivery note using web service LieferscheinDetail
sub callWsLieferscheinDetail {
	my $self = shift;
    my $ekzCustomerNumber = shift;                  # mandatory
	my $selId = shift;                            # alternative for selLieferscheinnummer
	my $selLieferscheinnummer = shift;            # alternative for selId
    my $refLieferscheinDetailElement = shift;     # for storing the read LieferscheinDetailResponseElement of the SOAP response body

	my $result = {  'lieferscheinCount' => 0, 
			        'lieferscheinRecords' => [],
                    'messageID' => ''
	};
	
	
print STDERR "EkzWebServices::callWsLieferscheinDetail() ekzCustomerNumber:", $ekzCustomerNumber, ": selId:", defined($selId) ? $selId : "undef", ": selLieferscheinnummer:", defined($selLieferscheinnummer) ? $selLieferscheinnummer : "undef", ":\n" if $debugIt;

    my $xmlwriter = XML::Writer->new(OUTPUT => 'self', NEWLINES => 0, DATA_MODE => 1, DATA_INDENT => 2, ENCODING => 'utf-8' );

    #$xmlwriter->xmlDecl("UTF-8");    # seems to be not necessary
    $xmlwriter->startTag( 'soap:Envelope',
                              'soap:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/',
                              'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/');
    
    $xmlwriter->startTag(   'soap:Header');
    $xmlwriter->startTag(     'wsse:Security',
                                  'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
                                  'xmlns:wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd',
                                  'soap:mustUnderstand' => '1');
    $xmlwriter->startTag(       'wsse:UsernameToken',
                                    'wsu:Id' => 'UsernameToken-3d1e2053-4b6d-41c0-bb25-ba7ab39ce6dc');    # it seems that we can use a constant non varying UUID here
    $xmlwriter->dataElement(      'wsse:Username' => 'bob');
    $xmlwriter->dataElement(      'wsse:Password', 'bobPW', 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText');
    $xmlwriter->endTag(         'wsse:UsernameToken');
    $xmlwriter->endTag(       'wsse:Security');
    $xmlwriter->endTag(     'soap:Header');
    
    $xmlwriter->startTag(   'soap:Body');
    $xmlwriter->startTag(     'bes:LieferscheinDetailElement',
                                  'xmlns:bes' => 'http://www.ekz.de/BestellsystemWSDL');
    $xmlwriter->dataElement(    'kundenNummer' => $self->getEkzKundenNr($ekzCustomerNumber));
    $xmlwriter->dataElement(    'passwort' => $self->getEkzPasswort($ekzCustomerNumber));
    $xmlwriter->dataElement(    'lmsNutzer' => $self->getEkzLmsNutzer($ekzCustomerNumber));

    if ( defined $selId && length($selId) > 0 ) {
        $xmlwriter->dataElement('id' => $selId);    # alternativ zu lieferscheinnummer
    }
    if ( defined $selLieferscheinnummer && length($selLieferscheinnummer) > 0 ) {
        $xmlwriter->dataElement('lieferscheinnummer' => $selLieferscheinnummer);    # alternativ zu id
    }
    $xmlwriter->endTag(       'bes:LieferscheinDetailElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();
	
	my $soapResponse = $self->doQuery('"urn:lieferscheindetail"', $soapEnvelope);

print STDERR "EkzWebServices::callWsLieferscheinDetail() soapResponse:", $soapResponse, ":\n" if $debugIt;
print STDERR Dumper($soapResponse) if $debugIt;
    
print STDERR "EkzWebServices::callWsLieferscheinDetail() \$refLieferscheinDetailElement:", $refLieferscheinDetailElement, ":\n" if $debugIt;
print STDERR Dumper($refLieferscheinDetailElement) if $debugIt;
    if ( defined ($$refLieferscheinDetailElement) ) {
        $$refLieferscheinDetailElement = '';
        if ( $soapResponse->content =~ /^.*?<.*?:Body>\n*(.*)<\/.*?:Body>.*?$/s ) {
            $$refLieferscheinDetailElement = $1;
        }
    }
print STDERR "EkzWebServices::callWsLieferscheinDetail() \$\$refLieferscheinDetailElement:", $$refLieferscheinDetailElement, ":\n" if $debugIt;
print STDERR Dumper($$refLieferscheinDetailElement) if $debugIt;

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

print STDERR "EkzWebServices::callWsLieferscheinDetail() root Elem:", $root, ":\n" if $debugIt;
print STDERR Dumper($root) if $debugIt;

        my $messageIdNodes = $root->findnodes('soap:Body/*/messageID');
        foreach my $messageIdNode ( $messageIdNodes->get_nodelist() ) {
            $result->{'messageID'} = $messageIdNode->textContent;
            last;
        }

        my $lieferscheinNodes = $root->findnodes('soap:Body/*/lieferschein');
print STDERR "EkzWebServices::callWsLieferscheinDetail() lieferscheinNodes:", $lieferscheinNodes, ":\n" if $debugIt;
print STDERR Dumper($lieferscheinNodes) if $debugIt;

		foreach my $lieferscheinNode ( $lieferscheinNodes->get_nodelist() ) {
print STDERR "EkzWebServices::callWsLieferscheinDetail() lieferscheinNode->nodeName:", $lieferscheinNode->nodeName, ":\n" if $debugIt;
            my $lieferscheinRecord = {'teilLieferungCount' => 0, 'teilLieferungRecords' => []};
			foreach my $lieferscheinChild ( $lieferscheinNode->childNodes() ) {    # <id> <nummer> <datum> <teilLieferung> are of interest
print STDERR "EkzWebServices::callWsLieferscheinDetail() lieferscheinChild->nodeName:", $lieferscheinChild->nodeName, ":\n" if $debugIt;
                # copy values of hit into lieferscheinrecord
                if ( $lieferscheinChild->nodeName eq 'teilLieferung' ) {
                    my $teilLieferungRecord = {'auftragsPositionCount' => 0, 'auftragsPositionRecords' => []};
                    foreach my $teilLieferungChild ( $lieferscheinChild->childNodes() ) {
                        if ( $teilLieferungChild->nodeName eq 'auftragsPosition' ) {
                            my $auftragsPositionRecord = ();
                            foreach my $auftragsPositionChild ( $teilLieferungChild->childNodes() ) {
                                if ( $auftragsPositionChild->nodeName !~ /^#/ ) {
                                    $auftragsPositionRecord->{$auftragsPositionChild->nodeName} = $auftragsPositionChild->textContent;
                                }
                            }
                            push @{$teilLieferungRecord->{'auftragsPositionRecords'}}, $auftragsPositionRecord;
                            $teilLieferungRecord->{'auftragsPositionCount'} += 1;
                        } else {
                            if ( $teilLieferungChild->nodeName !~ /^#/ ) {
                                $teilLieferungRecord->{$teilLieferungChild->nodeName} = $teilLieferungChild->textContent;
                            }
                        }
                    }
                    push @{$lieferscheinRecord->{'teilLieferungRecords'}}, $teilLieferungRecord;
                    $lieferscheinRecord->{'teilLieferungCount'} += 1;
                } elsif ( $lieferscheinChild->nodeName eq 'rechnungsAnschrift' ) {
                    my $rechnungsAnschriftRecord = ();
                    foreach my $rechnungsAnschriftChild ( $lieferscheinChild->childNodes() ) {
                        if ( $rechnungsAnschriftChild->nodeName !~ /^#/ ) {
                             $rechnungsAnschriftRecord->{$rechnungsAnschriftChild->nodeName} = $rechnungsAnschriftChild->textContent;
                        }
                    }
                    $lieferscheinRecord->{$lieferscheinChild->nodeName} = $rechnungsAnschriftRecord;
                } else {
                    if ( $lieferscheinChild->nodeName !~ /^#/ ) {
                        $lieferscheinRecord->{$lieferscheinChild->nodeName} = $lieferscheinChild->textContent;
                    }
                }
			}
            push @{$result->{'lieferscheinRecords'}}, $lieferscheinRecord;
            $result->{'lieferscheinCount'} += 1;
print STDERR "EkzWebServices::callWsLieferscheinDetail() result->{'lieferscheinRecords'}->[i]:", $result->{'lieferscheinRecords'}->[$result->{'lieferscheinCount'}-1], ":\n" if $debugIt;
print STDERR Dumper($result->{'lieferscheinRecords'}->[$result->{'lieferscheinCount'}-1]) if $debugIt;
		}
	}
	
	return $result;
}

sub doQuery {
	my $self = shift;
    my $soapAction = shift;
    my $soapEnvelope = shift;

    my $soapEnvelopeAsOctets = Encode::encode('UTF-8', $soapEnvelope, Encode::FB_CROAK);    # 'encode' required for avoiding error: HTTP::Message content must be bytes at /usr/share/perl5/HTTP/Request/Common.pm line 94.

	my $soapResponse = $self->{'ua'}->post($self->{'url'}, 'Content-Type' => 'text/xml; charset="utf-8"', 'SOAPAction' => $soapAction, Content => $soapEnvelopeAsOctets);

print STDERR "EkzWebServices::doQuery() soapResponse:", $soapResponse, ":\n" if $debugIt;
print STDERR Dumper(\$soapResponse) if $debugIt;
	
	return $soapResponse;
	
}

sub genZeitstempel {
    my $self = shift;

    # e.g.: 2017-09-30T16:35:59.788
    my $t = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($t);
    my $tsdate = sprintf("%04d-%02d-%02d",1900+$year,1+$mon,$mday);
    my $tstime = sprintf("%02d:%02d:%02d.%03d",$hour,$min,$sec,($t-int($t))*1000);    # calculate milli seconds without rounding

    my $zeitstempel = $tsdate . "T" . $tstime;

    return $zeitstempel;
}

sub genTransactionId {
    my $self = shift;
    my $decimalSeparator = shift;

    my $timeOfDay = [gettimeofday];
    my $transactionID = sprintf("%d%s%06d", $timeOfDay->[0], $decimalSeparator, $timeOfDay->[1]);     # seconds.microseconds

    return $transactionID;
}


###################################################################################################
# read date of last execution of ekz web service (e.g. StoList, LieferscheinDetail) from system preferences
###################################################################################################
sub getLastRunDate {
    my ($ekzWSName, $dateForm) = @_;
    my $ekzWSLastRunDateSysPrefName = '';
    my $ekzWsLastRunDate;

    if ( $ekzWSName eq 'StoList' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzStandingOrderWSLastRunDate';
    } elsif ( $ekzWSName eq 'LieferscheinDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzDeliveryNoteWSLastRunDate';
    }

    if ( length($ekzWSLastRunDateSysPrefName) > 0 ) {
        $ekzWsLastRunDate = C4::Context->preference($ekzWSLastRunDateSysPrefName);    # stored in american form yyyy-mm-dd
print STDERR "EkzWebServices::getLastRunDate($ekzWSName) ekzWSLastRunDateSysPrefName:$ekzWSLastRunDateSysPrefName: ekzWsLastRunDate:", defined($ekzWsLastRunDate) ? $ekzWsLastRunDate : 'undef', ":\n" if $debugIt;
        if ( defined($ekzWsLastRunDate) && length($ekzWsLastRunDate) > 0 && $ekzWsLastRunDate !~ /^\d\d\d\d-\d\d-\d\d$/ ) {
            croak "EkzWebServices::getLastRunDate($ekzWSName) got invalid ekzWsLastRunDate value:" . $ekzWsLastRunDate . ": for ekzWSLastRunDateSysPrefName:", $ekzWSLastRunDateSysPrefName, "\n";
        }
        if ( defined($ekzWsLastRunDate) && length($ekzWsLastRunDate) > 0 && $dateForm eq 'E' ) {    # transform it into european form dd.mm.yyyy
            $ekzWsLastRunDate = substr($ekzWsLastRunDate,8,2) . '.' . substr($ekzWsLastRunDate,5,2) . '.' . substr($ekzWsLastRunDate,0,4);
        }
    }
    if ( length($ekzWsLastRunDate) == 0 ) {
        $ekzWsLastRunDate = undef;
    }
print STDERR "EkzWebServices::getLastRunDate($ekzWSName) returns ekzWsLastRunDate:", $ekzWsLastRunDate, ":\n" if $debugIt;
    return $ekzWsLastRunDate;    # undef is also a valid value: it disables the from-date selection in StoList
}


###################################################################################################
# set date of last execution of ekz web service (e.g. StoList, LieferscheinDetail) in system preferences
###################################################################################################
sub setLastRunDate {
    my ($ekzWSName, $ekzWsLastRunDate) = @_;
    my $ekzWSLastRunDateSysPrefName;

    if ( $ekzWSName eq 'StoList' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzStandingOrderWSLastRunDate';
    } elsif ( $ekzWSName eq 'LieferscheinDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzDeliveryNoteWSLastRunDate';
    }

    if ( length($ekzWSLastRunDateSysPrefName) > 0 ) {
print STDERR "EkzWebServices::setLastRunDate($ekzWSName) ref(ekzWsLastRunDate):", ref($ekzWsLastRunDate), ":\n" if $debugIt;
print STDERR "EkzWebServices::setLastRunDate($ekzWSName) ekzWsLastRunDate->ymd:", $ekzWsLastRunDate->ymd, ":\n" if $debugIt;
        C4::Context->set_preference($ekzWSLastRunDateSysPrefName, $ekzWsLastRunDate->ymd, "Date of last execution of ekz web service $ekzWSName.", "Free");    # store the date in american form yyyy-mm-dd
    }
}

1;


