package C4::External::EKZ::lib::EkzWebServices;

# Copyright 2017-2021 (C) LMSCLoud GmbH
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
use C4::External::EKZ::lib::EkzWsConfig;
use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );



binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

our $VERSION = '0.01';

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# until 13.01.2020: URL of old ekz Medienservices: https://mbk.ekz.de:9443/epmw-2.0/services/BestellsystemService 
# ekz Medienwelten ( since 14.01.2020 (production environment) )
use constant EKZWSURL => 'https://medienwelten.ekz.de/epmw-2.0/services/BestellsystemService'; # explicitly not a system preference
#medienwelten-INT.ekz.de (integration and test environment)
#use constant EKZWSURL => 'https://medienwelten-INT.ekz.de/epmw-2.0/services/BestellsystemService'; # explicitly not a system preference

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
    $self->{'logger'} = Koha::Logger->get({ interface => 'C4::External::EKZ::lib::EkzWebServices' });
    
    
    # Get credentials for web service 'MedienDaten' from file /etc/koha/ekz-title-service.key.
    my %configWsMedienDaten = ();
    my $file = '/etc/koha/ekz-title-service.key';
    if ( -e $file && -f $file ) {
        my $res = open(my $fh, '<:encoding(UTF-8)', $file);
        if ( ! defined($res) ) {
            my $mess = "Could not open ekz title service configuration file '$file' $!";
            $self->{'logger'}->warn("new() $mess");
            carp "EkzWebServices::new(): " . $mess;
        }
        while (<$fh>) {
            next if /^#/; # skip line if it starts with a hash
            chomp; # remove \n 
            my($name,$val) = split '=', $_, 2; #split line into two values, on an = sign
            $name =~ s/^\s+//;
            $name =~ s/\s+$//;
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            next unless ($name && $val); # make sure the value is set
            $configWsMedienDaten{$name} = $val;
        }
        close $fh;
    }
    if ( ! exists($configWsMedienDaten{'ekzKundenNr'}) ) {
        my $mess = "ekzKundenNr value not defined in ekz title service config '$file'";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    }
    if (! exists($configWsMedienDaten{'passwort'}) ) {
        my $mess = "passwort value not defined in ekz title service config '$file'";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    }
    if (! exists($configWsMedienDaten{'lmsNutzer'}) ) {
        my $mess = "lmsNutzer value not defined in ekz title service config '$file'";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    }

    $self->{'ekzKundenNrWSMD'} = defined($configWsMedienDaten{'ekzKundenNr'}) ? $configWsMedienDaten{'ekzKundenNr'} : 'UNDEFINED';
    $self->{'passwortWSMD'}  = defined($configWsMedienDaten{'passwort'}) ? $configWsMedienDaten{'passwort'} : 'UNDEFINED';
    $self->{'lmsNutzerWSMD'}  = defined($configWsMedienDaten{'lmsNutzer'}) ? $configWsMedienDaten{'lmsNutzer'} : 'UNDEFINED';

    # get the systempreferences concerning ekz media services configuration for variing ekzKundenNr
    $self->{'ekzWsConfig'} = C4::External::EKZ::lib::EkzWsConfig->new();

	return $self;
}

sub getEkzKundenNr {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($self->{'ekzWsConfig'}) ) {
        $ret = $self->{'ekzWsConfig'}->getEkzKundenNr($ekzCustomerNumber) ;
    }
    $self->{'logger'}->trace("getEkzKundenNr(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzPasswort {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($self->{'ekzWsConfig'}) ) {
        $ret = $self->{'ekzWsConfig'}->getEkzPasswort($ekzCustomerNumber);
    }
    $self->{'logger'}->trace("getEkzPasswort(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzLmsNutzer {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($self->{'ekzWsConfig'}) ) {
        $ret = $self->{'ekzWsConfig'}->getEkzLmsNutzer($ekzCustomerNumber);
    }
    $self->{'logger'}->trace("getEkzLmsNutzer(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzProcessingNoticesEmailAddress {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($self->{'ekzWsConfig'}) ) {
        $ret = $self->{'ekzWsConfig'}->getEkzProcessingNoticesEmailAddress($ekzCustomerNumber);
    }
    $self->{'logger'}->trace("getEkzProcessingNoticesEmailAddress(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzWebServicesDefaultBranch {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($self->{'ekzWsConfig'}) ) {
        $ret = $self->{'ekzWsConfig'}->getEkzWebServicesDefaultBranch($ekzCustomerNumber);
    }
    $self->{'logger'}->trace("getEkzWebServicesDefaultBranch(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzAqbooksellersId {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($self->{'ekzWsConfig'}) ) {
        $ret = $self->{'ekzWsConfig'}->getEkzAqbooksellersId($ekzCustomerNumber);
    }
    $self->{'logger'}->trace("getEkzAqbooksellersId(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzCustomerNumbers {
	my $self = shift;
    my @ekzWebServicesCustomerNumbers = ();

    if ( defined($self->{'ekzWsConfig'}) ) {
        @ekzWebServicesCustomerNumbers = $self->{'ekzWsConfig'}->getEkzCustomerNumbers();
    }
    return @ekzWebServicesCustomerNumbers;
}

# read ekz title data in MARC21 XML format using web service MedienDaten, search by ekzArtikelNr
sub callWsMedienDaten {
	my $self = shift;
	my $ekzArtikelNr = shift;

    # <messageId> is definded as xs:int in the wsdl.
    # So we calculate (current seconds * 1000 + milliseconds) modulo 1000000000 to get a quite unique number that fits in a 32-bit integer the ekz seems to use for this purpose.
    my $messageId = substr(substr($self->genTransactionId(''),0,-3),-9) + 0;
	my $zeitstempel = $self->genZeitstempel();

	my $soapResponseBody = '';
    my $result = {  'count' => 0,
                    'records' => []
    };
	
    $self->{'logger'}->debug("callWsMedienDaten() START ekzArtikelNr:" . (defined($ekzArtikelNr) ? $ekzArtikelNr : 'undef') . ":");
	
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

    $self->{'logger'}->trace("callWsMedienDaten() Dumper(soapResponse):" . Dumper($soapResponse) . ":");
    

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->trace("callWsMedienDaten() root-element:" . $root . ":");
        $self->{'logger'}->trace("callWsMedienDaten() Dumper(root):" . Dumper($root) . ":");

        my $titelnodes = $root->findnodes('soap:Body/*/titel');
        $self->{'logger'}->trace("callWsMedienDaten() titelnodes:" . $titelnodes . ":");
        $self->{'logger'}->trace("callWsMedienDaten() Dumper(titelnodes):" . Dumper($titelnodes) . ":");

		foreach my $titelnode ( $titelnodes->get_nodelist() ) {
            $self->{'logger'}->trace("callWsMedienDaten() titelnode->nodeName:" . $titelnode->nodeName . ":");
			foreach my $child ( $titelnode->childNodes() ) {
                $self->{'logger'}->trace("callWsMedienDaten() child->nodeName:" . $child->nodeName . ":");
                # check if it is the hit with correct ekzArtikelNr
				if ( $child->nodeName eq 'ekzArtikelNr' ) {
				    if ( $child->textContent eq $ekzArtikelNr ) {
	                    my $datenSatzNodes = $titelnode->findnodes('datenSatz');
                        $self->{'logger'}->trace("callWsMedienDaten() datenSatzNodes:" . $datenSatzNodes . ":");
                        $self->{'logger'}->trace("callWsMedienDaten() Dumper(datenSatzNodes):" . Dumper($datenSatzNodes) . ":");

                        my $datenSatzNode = $datenSatzNodes->[0];
                        if ( defined $datenSatzNode && defined $datenSatzNode->textContent ) {
                            my $marc21XmlData = decode_base64($datenSatzNode->textContent);
                            $self->{'logger'}->trace("callWsMedienDaten() marc21XmlData:" . $marc21XmlData . ":");
                            if ( defined($marc21XmlData) && length($marc21XmlData) > 0 ) {
                                my $marcrecord;
                                eval {
                                    $marcrecord =  MARC::Record::new_from_xml( $marc21XmlData, "utf8", 'MARC21' );
                                };
                                if ( $@ ) {
                                    my $mess = "error in MARC::Record::new_from_xml:$@:\nmarc21XmlData:$marc21XmlData";
                                    $self->{'logger'}->warn("callWsMedienDaten() $mess");
                                    carp "EkzWebServices::callWsMedienDaten: " . $mess;
                                }

                                if ( $marcrecord ) {
                                    push @{$result->{'records'}}, $marcrecord;
                                    $result->{'count'} += 1;
                                    $self->{'logger'}->trace("callWsMedienDaten() Dumper(result->{'records'}->[0]):" . Dumper($result->{'records'}->[0]) . ":");
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
    my $selMitReferenznummer = shift;               # optional
    my $refStoListElement = shift;                  # for storing the StoListElement of the SOAP response body

	my $result = {  'standingOrderCount' => 0,
                    'standingOrderRecords' => [],
                    'messageID' => ''
    };

    $self->{'logger'}->info("callWsStoList() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                ": selJahr:" . (defined($selJahr) ? $selJahr : 'undef') .
                                                ": selStoId:" . (defined($selStoId) ? $selStoId : 'undef') .
                                                ": selMitTitel:" . (defined($selMitTitel) ? $selMitTitel : 'undef') .
                                                ": selMitKostenstellen:" . (defined($selMitKostenstellen) ? $selMitKostenstellen : 'undef') .
                                                ": selMitEAN:" . (defined($selMitEAN) ? $selMitEAN : 'undef') .
                                                ": selStatusUpdate:" . (defined($selStatusUpdate) ? $selStatusUpdate : 'undef') .
                                                ": selErweitert:" . (defined($selErweitert) ? $selErweitert : 'undef') .
                                                ": selMitReferenznummer:" . (defined($selMitReferenznummer) ? $selMitReferenznummer : 'undef') .
                                                ":");

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
    if ( defined $selMitReferenznummer && length($selMitReferenznummer) > 0 ) {
        $xmlwriter->dataElement('mitReferenznummer' => $selMitReferenznummer);    # <!-- entscheidet, ob die Referenznummern (und deren Exemplaranzahl) zu den Titeln geliefert werden sollen, OPTIONAL -->
    }
    $xmlwriter->endTag(       'bes:StoListElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();
	
	my $soapResponse = $self->doQuery('"urn:stolist"', $soapEnvelope);

    $self->{'logger'}->debug("callWsStoList() Dumper(soapResponse):" . Dumper($soapResponse) . ":");
    $self->{'logger'}->trace("callWsStoList() Dumper(\$refStoListElement):" . Dumper($refStoListElement) . ":");
    
    if ( defined ($$refStoListElement) ) {
        $$refStoListElement = '';
        if ( $soapResponse->content =~ /^.*?<.*?:Body>\n*(.*)<\/.*?:Body>.*?$/s ) {
            $$refStoListElement = $1;
        }
    }
    $self->{'logger'}->trace("callWsStoList() Dumper(\$\$refStoListElement):" . Dumper($$refStoListElement) . ":");

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->trace("callWsStoList() root-element:" . $root . ":");
        $self->{'logger'}->trace("callWsStoList() Dumper(root):" . Dumper($root) . ":");

        my $messageIdNodes = $root->findnodes('soap:Body/*/messageID');
        foreach my $messageIdNode ( $messageIdNodes->get_nodelist() ) {
            $result->{'messageID'} = $messageIdNode->textContent;
            last;
        }

        my $stoNodes = $root->findnodes('soap:Body/*/standingOrderVariante');
        $self->{'logger'}->trace("callWsStoList() stoNodes:" . $stoNodes . ":");
        $self->{'logger'}->trace("callWsStoList() Dumper(stoNodes):" . Dumper($stoNodes) . ":");

		foreach my $stoNode ( $stoNodes->get_nodelist() ) {
            $self->{'logger'}->trace("callWsStoList() stoNode->nodeName:" . $stoNode->nodeName . ":");
            my $stoRecord = {'titelCount' => 0, 'titelRecords' => []};
			foreach my $stoChild ( $stoNode->childNodes() ) {    # <stoID> <name> <titel> nodes are of interest here
                $self->{'logger'}->trace("callWsStoList() stoChild->nodeName:" . $stoChild->nodeName . ":");
                # copy values of hit into stoRecord
				if ( $stoChild->nodeName eq 'titel' ) {
                    my $titelRecord = ();
                    foreach my $titelChild ( $stoChild->childNodes() ) {
                        if ( $titelChild->nodeName eq 'kostenstelle' ) {    # may be sent multiple times
                            if ( ! exists($titelRecord->{$titelChild->nodeName}) ) {
                                $titelRecord->{$titelChild->nodeName} = [];
                            }
                            push @{$titelRecord->{$titelChild->nodeName}}, $titelChild->textContent;
                        } elsif ( $titelChild->nodeName eq 'referenznummer' ) {
                            my $referenznummerRecord = {};
                            foreach my $referenznummerChild ( $titelChild->childNodes() ) {
                                if ( $referenznummerChild->nodeName !~ /^#/ ) {
                                    $referenznummerRecord->{$referenznummerChild->nodeName} = $referenznummerChild->textContent;
                                }
                            }
                            if ( ! exists($titelRecord->{$titelChild->nodeName}) ) {
                                $titelRecord->{$titelChild->nodeName} = [];
                            }
                            push @{$titelRecord->{$titelChild->nodeName}}, $referenznummerRecord;
                        } else {
                            if ( $titelChild->nodeName !~ /^#/ ) {
                                $titelRecord->{$titelChild->nodeName} = $titelChild->textContent;
                            }
                        }
                    }
                    push @{$stoRecord->{'titelRecords'}}, $titelRecord;
                    $stoRecord->{'titelCount'} += 1;
                } else {
                    $stoRecord->{$stoChild->nodeName} = $stoChild->textContent;
                }
			}
            push @{$result->{'standingOrderRecords'}}, $stoRecord;
            $result->{'standingOrderCount'} += 1;
            $self->{'logger'}->trace("callWsStoList() Dumper(result->{'standingOrderRecords'}->[i]):" . Dumper($result->{'standingOrderRecords'}->[$result->{'standingOrderCount'}-1]) . ":");
		}
	}
	
	return $result;
}

# search serial orders using web service FortsetzungList
sub callWsFortsetzungList {
    my $self = shift;
    my $ekzCustomerNumber = shift;                 # mandatory
    my $selVon = shift;                            # mandatory
    my $selBis = shift;                            # optional

    my $result = {  'fortsetzungStatusCount' => 0,
                    'fortsetzungStatusRecords' => {}
    };

    $self->{'logger'}->info("callWsFortsetzungList() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                        ": selVon:" . (defined($selVon) ? $selVon : 'undef') .
                                                        ": selBis:" . (defined($selBis) ? $selBis : 'undef') .
                                                        ":");

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
    $xmlwriter->startTag(     'bes:FortsetzungListElement',
                                  'xmlns:bes' => 'http://www.ekz.de/BestellsystemWSDL');
    $xmlwriter->dataElement(    'kundenNummer' => $self->getEkzKundenNr($ekzCustomerNumber));
    $xmlwriter->dataElement(    'passwort' => $self->getEkzPasswort($ekzCustomerNumber));
    $xmlwriter->dataElement(    'lmsNutzer' => $self->getEkzLmsNutzer($ekzCustomerNumber));

    if ( defined $selVon && length($selVon) > 0 ) {
        $xmlwriter->dataElement('von' => $selVon);    # optional
    }
    if ( defined $selBis && length($selBis) > 0 ) {
        $xmlwriter->dataElement('bis' => $selBis);    # optional
    }
    $xmlwriter->endTag(       'bes:FortsetzungListElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();
	
    my $soapResponse = $self->doQuery('"urn:fortsetzunglist"', $soapEnvelope);

    $self->{'logger'}->debug("callWsFortsetzungList() Dumper(soapResponse):" . Dumper($soapResponse) . ":");
    $self->{'logger'}->debug("callWsFortsetzungList() soapResponse->is_success:" . Dumper($soapResponse->is_success) . ":");

    if ($soapResponse->is_success) {
        $self->{'logger'}->debug("callWsFortsetzungList() Dumper(soapResponse->content):" . Dumper($soapResponse->content) . ":");
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->debug("callWsFortsetzungList() root-element:" . $root . ":");
        $self->{'logger'}->debug("callWsFortsetzungList() Dumper(root):" . Dumper($root) . ":");

        my $fortsetzungStatusNodes = $root->findnodes('soap:Body/*/fortsetzungStatus');
        $self->{'logger'}->debug("callWsFortsetzungList() Dumper(fortsetzungStatusNodes):" . Dumper($fortsetzungStatusNodes) . ":");
        #my $lieferscheinNodes = $root->findnodes('soap:Body/*/lieferschein');
        #$self->{'logger'}->trace("callWsFortsetzungList() lieferscheinNodes:" . $lieferscheinNodes . ":");
        #$self->{'logger'}->trace("callWsFortsetzungList() Dumper(lieferscheinNodes):" . Dumper($lieferscheinNodes) . ":");

        
        foreach my $fortsetzungStatusNode ( $fortsetzungStatusNodes->get_nodelist() ) {
            $self->{'logger'}->trace("callWsFortsetzungList() fortsetzungStatusNode->nodeName:" . $fortsetzungStatusNode->nodeName . ":");
            my $fortsetzungStatusRecord = ();
            foreach my $fortsetzungStatusChild ( $fortsetzungStatusNode->childNodes() ) {    # <status>, <fortsetzungVariante>
                $self->{'logger'}->trace("callWsFortsetzungList() fortsetzungStatusChild->nodeName:" . $fortsetzungStatusChild->nodeName . ":");
                # copy relevant values of hit into lieferscheinrecord
                if ( $fortsetzungStatusChild->nodeName !~ /^#/ ) {
                    if ( $fortsetzungStatusChild->nodeName eq 'status' ) {
                        $fortsetzungStatusRecord->{$fortsetzungStatusChild->nodeName} = $fortsetzungStatusChild->textContent;
                    } elsif ( $fortsetzungStatusChild->nodeName eq 'fortsetzungVariante' ) {
                        my $fortsetzungVarianteRecord = ();
                        foreach my $fortsetzungVarianteChild ( $fortsetzungStatusChild->childNodes() ) {    # <artikelArt>, <fortsetzungRubrik>
                            $self->{'logger'}->trace("callWsFortsetzungList() fortsetzungVarianteChild->nodeName:" . $fortsetzungVarianteChild->nodeName . ":");
                            $self->{'logger'}->trace("callWsFortsetzungList() ref(fortsetzungVarianteChild->textContent):" . ref($fortsetzungVarianteChild->textContent) . ":");
                            if ( $fortsetzungVarianteChild->nodeName eq 'artikelArt' ) {
                                $fortsetzungVarianteRecord->{$fortsetzungVarianteChild->nodeName} = $fortsetzungVarianteChild->textContent;
                            } elsif ( $fortsetzungVarianteChild->nodeName eq 'fortsetzungRubrik' ) {
                                my $fortsetzungRubrikRecord = ();
                                foreach my $fortsetzungRubrikChild ( $fortsetzungVarianteChild->childNodes() ) {    # <rubrik>, <fortsezungTitel>
                                    $self->{'logger'}->trace("callWsFortsetzungList() fortsetzungRubrikChild->nodeName:" . $fortsetzungRubrikChild->nodeName . ":");
                                    if ( $fortsetzungRubrikChild->nodeName eq 'rubrik' ) {
                                        $fortsetzungRubrikRecord->{$fortsetzungRubrikChild->nodeName} = $fortsetzungRubrikChild->textContent;
                                    } elsif ( $fortsetzungRubrikChild->nodeName eq 'fortsetzungTitel' ) {
                                        my $fortsetzungTitelRecord = ();
                                        foreach my $fortsetzungTitelChild ( $fortsetzungRubrikChild->childNodes() ) {    # <artikelnum>, <artikelname> usw.
                                            $self->{'logger'}->trace("callWsFortsetzungList() fortsetzungTitelChild->nodeName:" . $fortsetzungTitelChild->nodeName . ":");
                                            $fortsetzungTitelRecord->{$fortsetzungTitelChild->nodeName} = $fortsetzungTitelChild->textContent;
                                        }
                                        push @{$fortsetzungRubrikRecord->{$fortsetzungRubrikChild->nodeName}}, $fortsetzungTitelRecord;
                                    }
                                }
                                push @{$fortsetzungVarianteRecord->{$fortsetzungVarianteChild->nodeName}}, $fortsetzungRubrikRecord;
                            }
                        }
                        push @{$fortsetzungStatusRecord->{$fortsetzungStatusChild->nodeName}}, $fortsetzungVarianteRecord;
                    }
                }
            }
            $result->{'fortsetzungStatusRecords'}->{$fortsetzungStatusRecord->{'status'}} = $fortsetzungStatusRecord;    # 'inProgress', 'canceled', 'finished'
            $result->{'fortsetzungStatusCount'} += 1;
            $self->{'logger'}->trace("callWsFortsetzungList() Dumper(result->{'fortsetzungStatusRecords'}->{$fortsetzungStatusRecord->{'status'}}):" . Dumper($result->{'fortsetzungStatusRecords'}->{$fortsetzungStatusRecord->{'status'}}) . ":");
       }
    }
	
	return $result;
}

# read all data of one serial order using web service FortsetzungDetail
sub callWsFortsetzungDetail {
    my $self = shift;
    my $ekzCustomerNumber = shift;                 # mandatory
    my $selFortsetzungsId = shift;                 # mandatory
    my $selBearbeitungsGruppe = shift;             # optional
    my $selBearbeitungsNummer = shift;             # optional
    my $selFortsetzungsAuftragsNummer = shift;     # optional
    my $selMitReferenznummer = shift;              # optional
    my $refFortsetzungDetailElement = shift;       # for storing the read FortsetzungDetailResponseElement of the SOAP response body in DB table acquisition_import

    my $result = {  'fortsetzungStatusCount' => 0,
                    'fortsetzungRecords' => []
    };
    my $fortsetzungRecord = {};

    $self->{'logger'}->info("callWsFortsetzungDetail() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                          ": selFortsetzungsId:" . (defined($selFortsetzungsId) ? $selFortsetzungsId : 'undef') .
                                                          ": selBearbeitungsGruppe:" . (defined($selBearbeitungsGruppe) ? $selBearbeitungsGruppe : 'undef') .
                                                          ": selBearbeitungsNummer:" . (defined($selBearbeitungsNummer) ? $selBearbeitungsNummer : 'undef') .
                                                          ": selFortsetzungsAuftragsNummer:" . (defined($selFortsetzungsAuftragsNummer) ? $selFortsetzungsAuftragsNummer : 'undef') .
                                                          ": selMitReferenznummer:" . (defined($selMitReferenznummer) ? $selMitReferenznummer : 'undef') .
                                                          ":");

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
    $xmlwriter->startTag(     'bes:FortsetzungDetailElement',
                                  'xmlns:bes' => 'http://www.ekz.de/BestellsystemWSDL');
    $xmlwriter->dataElement(    'kundenNummer' => $self->getEkzKundenNr($ekzCustomerNumber));
    $xmlwriter->dataElement(    'passwort' => $self->getEkzPasswort($ekzCustomerNumber));
    $xmlwriter->dataElement(    'lmsNutzer' => $self->getEkzLmsNutzer($ekzCustomerNumber));
    $xmlwriter->dataElement(    'fortsetzungsId' => $selFortsetzungsId);

    if ( defined $selBearbeitungsGruppe && length($selBearbeitungsGruppe) > 0 ) {
        $xmlwriter->dataElement('bearbeitungsGruppe' => $selBearbeitungsGruppe);
    }
    if ( defined $selFortsetzungsAuftragsNummer && length($selFortsetzungsAuftragsNummer) > 0 ) {
        $xmlwriter->dataElement('fortsetzungsAuftragsNummer' => $selFortsetzungsAuftragsNummer);    # alternativ zu id
    }
    if ( defined $selMitReferenznummer && length($selMitReferenznummer) > 0 ) {
        $xmlwriter->dataElement('mitReferenznummer' => $selMitReferenznummer);    # optional (Entscheidet, ob die Referenznummern (und deren Exemplaranzahl) zu den Titeln geliefert werden sollen.)
    }
    $xmlwriter->endTag(       'bes:FortsetzungDetailElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();

    my $soapResponse = $self->doQuery('"urn:fortsetzungdetail"', $soapEnvelope);

    $self->{'logger'}->debug("callWsFortsetzungDetail() Dumper(soapResponse):" . Dumper($soapResponse) . ":");
    $self->{'logger'}->trace("callWsFortsetzungDetail() Dumper(\$refFortsetzungDetailElement):" . Dumper($refFortsetzungDetailElement) . ":");

    if ( defined ($$refFortsetzungDetailElement) ) {
        $$refFortsetzungDetailElement = '';
        if ( $soapResponse->content =~ /^.*?<.*?:Body>\n*(.*)<\/.*?:Body>.*?$/s ) {
            $$refFortsetzungDetailElement = $1;
        }
    }
    $self->{'logger'}->trace("callWsFortsetzungDetail() Dumper(\$\$refFortsetzungDetailElement):" . Dumper($$refFortsetzungDetailElement) . ":");

    if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->trace("callWsFortsetzungDetail() root-element:" . $root . ":");
        $self->{'logger'}->trace("callWsFortsetzungDetail() Dumper(root):" . Dumper($root) . ":");

        my $responseNodes = $root->findnodes('soap:Body/*/*');
        foreach my $responseNode ( $responseNodes->get_nodelist() ) {
            $self->{'logger'}->trace("callWsFortsetzungDetail() responseNode->nodeName:" . $responseNode->nodeName . ":");
            if ($responseNode->nodeName eq 'fortsetzungDetailStatus') {
                my $fortsetzungDetailStatusRecord = ();
                foreach my $fortsetzungDetailStatusChild ( $responseNode->childNodes() ) {    # <status>, <jahresSummen>, <erfuellungsGrad>, <detail>
                    $self->{'logger'}->trace("callWsFortsetzungDetail() fortsetzungDetailStatusChild->nodeName:" . $fortsetzungDetailStatusChild->nodeName . ":");
                    # copy relevant values of hit into lieferscheinrecord
                    if ( $fortsetzungDetailStatusChild->nodeName !~ /^#/ ) {
                        if ( $fortsetzungDetailStatusChild->nodeName eq 'jahresSummen' ) {
                            my $jahresSummenRecord = ();
                            foreach my $jahresSummenChild ( $fortsetzungDetailStatusChild->childNodes() ) {
                                # <jahresTyp>, <sumArtikelPreise>, <sumAnderePreise>, <sumBearbeitungsPreise>, <sumGesamt>
                                $self->{'logger'}->trace("callWsFortsetzungDetail() jahresSummenChild->nodeName:" . $jahresSummenChild->nodeName . ": jahresSummenChild->textContent:" . $jahresSummenChild->textContent . ":");
                                $jahresSummenRecord->{$jahresSummenChild->nodeName} = $jahresSummenChild->textContent;
                            }
                            push @{$fortsetzungDetailStatusRecord->{$fortsetzungDetailStatusChild->nodeName}}, $jahresSummenRecord;
                        } elsif ( $fortsetzungDetailStatusChild->nodeName eq 'detail' ) {
                            my $detailRecord = ();
                            foreach my $detailChild ( $fortsetzungDetailStatusChild->childNodes() ) {
                                # <artikelNummer>, <artikelName>, <artikelTypText>, <volumeNummer>, 
                                # <veroeffentlichungsDatum>, <preis>, <artikelPreis>, <anderePreis>, 
                                # <bearbeitungsPreis>, <BestellDatum>, <menge>, <status>, <referenznummer>
                                $self->{'logger'}->trace("callWsFortsetzungDetail() detailChild->nodeName:" . $detailChild->nodeName . ": detailChild->textContent:" . $detailChild->textContent . ":");
                                if ( $detailChild->nodeName eq 'referenznummer' ) {
                                    my $referenznummerRecord = ();
                                    foreach my $referenznummerChild ( $detailChild->childNodes() ) {
                                        # <exemplare>, <referenznummer>
                                        if ( $referenznummerChild->nodeName !~ /^#/ ) {
                                            $self->{'logger'}->trace("callWsFortsetzungDetail() referenznummerChild->nodeName:" . $referenznummerChild->nodeName . ": referenznummerChild->textContent:" . $referenznummerChild->textContent . ":");
                                            $referenznummerRecord->{$referenznummerChild->nodeName} = $referenznummerChild->textContent;
                                        }
                                    }
                                    if ( ! exists($detailRecord->{$detailChild->nodeName}) ) {
                                        $detailRecord->{$detailChild->nodeName} = [];
                                    }
                                    push @{$detailRecord->{$detailChild->nodeName}}, $referenznummerRecord;
                                } else {
                                    $detailRecord->{$detailChild->nodeName} = $detailChild->textContent;
                                }
                            }
                            push @{$fortsetzungDetailStatusRecord->{$fortsetzungDetailStatusChild->nodeName}}, $detailRecord;
                        } else {
                            $fortsetzungDetailStatusRecord->{$fortsetzungDetailStatusChild->nodeName} = $fortsetzungDetailStatusChild->textContent;
                        }
                    }
                }
                $fortsetzungRecord->{fortsetzungDetailStatusRecords}->{$fortsetzungDetailStatusRecord->{status}}->{$responseNode->nodeName} = $fortsetzungDetailStatusRecord;

            } else {
                $fortsetzungRecord->{$responseNode->nodeName} = $responseNode->textContent;
            }
        }
        $fortsetzungRecord->{'fortsetzungsId'} = $selFortsetzungsId;
        push @{$result->{'fortsetzungRecords'}}, $fortsetzungRecord;
        $result->{'fortsetzungCount'} += 1;
        $self->{'logger'}->trace("callWsFortsetzungDetail() Dumper(result->{'fortsetzungRecords'}->[i]):" . Dumper($result->{'fortsetzungRecords'}->[$result->{'fortsetzungCount'}-1]) . ":");
	}
	
	return $result;
}

# search delivery notes using web service LieferscheinList
sub callWsLieferscheinList {
	my $self = shift;
    my $ekzCustomerNumber = shift;                 # mandatory
	my $selVon = shift;                            # mandatory
	my $selBis = shift;                            # optional
	my $selKundennummerWarenEmpfaenger = shift;    # optional

	my $result = {  'lieferscheinCount' => 0,
                    'lieferscheinRecords' => []
    };

    $self->{'logger'}->info("callWsLieferscheinList() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                         ": selVon:" . (defined($selVon) ? $selVon : 'undef') .
                                                         ": selBis:" . (defined($selBis) ? $selBis : 'undef') .
                                                         ": selKundennummerWarenEmpfaenger:" . (defined($selKundennummerWarenEmpfaenger) ? $selKundennummerWarenEmpfaenger : 'undef') .
                                                         ":");

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
	
	my $soapResponse = $self->doQuery('"urn:lieferscheinlist"', $soapEnvelope);

    $self->{'logger'}->debug("callWsLieferscheinList() Dumper(soapResponse):" . Dumper($soapResponse) . ":");

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->trace("callWsLieferscheinList() root-element:" . $root . ":");
        $self->{'logger'}->trace("callWsLieferscheinList() Dumper(root):" . Dumper($root) . ":");

        my $lieferscheinNodes = $root->findnodes('soap:Body/*/lieferschein');
        $self->{'logger'}->trace("callWsLieferscheinList() lieferscheinNodes:" . $lieferscheinNodes . ":");
        $self->{'logger'}->trace("callWsLieferscheinList() Dumper(lieferscheinNodes):" . Dumper($lieferscheinNodes) . ":");

		foreach my $lieferscheinNode ( $lieferscheinNodes->get_nodelist() ) {
            $self->{'logger'}->trace("callWsLieferscheinList() lieferscheinNode->nodeName:" . $lieferscheinNode->nodeName . ":");
            my $lieferscheinRecord = ();
			foreach my $lieferscheinChild ( $lieferscheinNode->childNodes() ) {    # <id> <nummer> <datum> sind hier interessant
                $self->{'logger'}->trace("callWsLieferscheinList() lieferscheinChild->nodeName:" . $lieferscheinChild->nodeName . ":");
                # copy values of hit into lieferscheinrecord
                if ( $lieferscheinChild->nodeName !~ /^#/ ) {
				    $lieferscheinRecord->{$lieferscheinChild->nodeName} = $lieferscheinChild->textContent;
                }
			}
            push @{$result->{'lieferscheinRecords'}}, $lieferscheinRecord;
            $result->{'lieferscheinCount'} += 1;
            $self->{'logger'}->trace("callWsLieferscheinList() Dumper(result->{'lieferscheinRecords'}->[i]):" . Dumper($result->{'lieferscheinRecords'}->[$result->{'lieferscheinCount'}-1]) . ":");
		}
	}
	
	return $result;
}

# read all data of one delivery note using web service LieferscheinDetail
sub callWsLieferscheinDetail {
	my $self = shift;
    my $ekzCustomerNumber = shift;                  # mandatory
	my $selId = shift;                              # alternative for selLieferscheinnummer (it is mandatory to send one of the two)
	my $selLieferscheinnummer = shift;              # alternative for selId (it is mandatory to send one of the two)
    my $refLieferscheinDetailElement = shift;       # for storing the read LieferscheinDetailResponseElement of the SOAP response body in DB table acquisition_import

	my $result = {  'lieferscheinCount' => 0, 
			        'lieferscheinRecords' => [],
                    'messageID' => ''
	};

    $self->{'logger'}->info("callWsLieferscheinDetail() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                           ": selId:" . (defined($selId) ? $selId : 'undef') .
                                                           ": selLieferscheinnummer:" . (defined($selLieferscheinnummer) ? $selLieferscheinnummer : 'undef') .
                                                           ":");

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

    $self->{'logger'}->debug("callWsLieferscheinDetail() Dumper(soapResponse):" . Dumper($soapResponse) . ":");
    $self->{'logger'}->trace("callWsLieferscheinDetail() Dumper(\$refLieferscheinDetailElement):" . Dumper($refLieferscheinDetailElement) . ":");

    if ( defined ($$refLieferscheinDetailElement) ) {
        $$refLieferscheinDetailElement = '';
        if ( $soapResponse->content =~ /^.*?<.*?:Body>\n*(.*)<\/.*?:Body>.*?$/s ) {
            $$refLieferscheinDetailElement = $1;
        }
    }
    $self->{'logger'}->trace("callWsLieferscheinDetail() Dumper(\$\$refLieferscheinDetailElement):" . Dumper($$refLieferscheinDetailElement) . ":");

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->trace("callWsLieferscheinDetail() root-element:" . $root . ":");
        $self->{'logger'}->trace("callWsLieferscheinDetail() Dumper(root):" . Dumper($root) . ":");

        my $messageIdNodes = $root->findnodes('soap:Body/*/messageID');
        foreach my $messageIdNode ( $messageIdNodes->get_nodelist() ) {
            $result->{'messageID'} = $messageIdNode->textContent;
            last;
        }

        my $lieferscheinNodes = $root->findnodes('soap:Body/*/lieferschein');
        $self->{'logger'}->trace("callWsLieferscheinDetail() lieferscheinNodes:" . $lieferscheinNodes . ":");
        $self->{'logger'}->trace("callWsLieferscheinDetail() Dumper(lieferscheinNodes):" . Dumper($lieferscheinNodes) . ":");

		foreach my $lieferscheinNode ( $lieferscheinNodes->get_nodelist() ) {
            $self->{'logger'}->trace("callWsLieferscheinDetail() lieferscheinNode->nodeName:" . $lieferscheinNode->nodeName . ":");
            my $lieferscheinRecord = {'teilLieferungCount' => 0, 'teilLieferungRecords' => []};
			foreach my $lieferscheinChild ( $lieferscheinNode->childNodes() ) {    # <id> <nummer> <datum> <teilLieferung> are of interest
                $self->{'logger'}->trace("callWsLieferscheinDetail() lieferscheinChild->nodeName:" . $lieferscheinChild->nodeName . ":");
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
            $self->{'logger'}->trace("callWsLieferscheinDetail() Dumper(result->{'lieferscheinRecords'}->[i]):" . Dumper($result->{'lieferscheinRecords'}->[$result->{'lieferscheinCount'}-1]) . ":");
		}
	}
	
	return $result;
}

# read all data of one invoice using web service RechnungDetail
sub callWsRechnungDetail {
	my $self = shift;
    my $ekzCustomerNumber = shift;                  # mandatory
	my $selId = shift;                              # alternative for selRechnungsnummer (it is mandatory to send one of the two)
	my $selRechnungsnummer = shift;                 # alternative for selId (it is mandatory to send one of the two)
    my $refRechnungDetailElement = shift;           # for storing the read RechnungDetailResponseElement of the SOAP response body

	my $result = {  'rechnungCount' => 0, 
			        'rechnungRecords' => [],
                    'messageID' => ''
	};

    $self->{'logger'}->info("callWsRechnungDetail() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                           ": selId:" . (defined($selId) ? $selId : 'undef') .
                                                           ": selRechnungsnummer:" . (defined($selRechnungsnummer) ? $selRechnungsnummer : 'undef') .
                                                           ":");

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
    $xmlwriter->startTag(     'bes:RechnungDetailElement',
                                  'xmlns:bes' => 'http://www.ekz.de/BestellsystemWSDL');
    $xmlwriter->dataElement(    'kundenNummer' => $self->getEkzKundenNr($ekzCustomerNumber));    # mandatory
    $xmlwriter->dataElement(    'passwort' => $self->getEkzPasswort($ekzCustomerNumber));    # mandatory
    $xmlwriter->dataElement(    'lmsNutzer' => $self->getEkzLmsNutzer($ekzCustomerNumber));    # mandatory
    if ( defined $selId && length($selId) > 0 ) {
        $xmlwriter->dataElement('id' => $selId);    # alternativ zu selRechnungsnummer
    }
    if ( defined $selRechnungsnummer && length($selRechnungsnummer) > 0 ) {
        $xmlwriter->dataElement('rechnungsnummer' => $selRechnungsnummer);    # alternativ zu selId
    }
    $xmlwriter->endTag(       'bes:RechnungDetailElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();

	my $soapResponse = $self->doQuery('"urn:rechnungdetail"', $soapEnvelope);

    $self->{'logger'}->debug("callWsRechnungDetail() Dumper(soapResponse):" . Dumper($soapResponse) . ":");
    $self->{'logger'}->trace("callWsRechnungDetail() Dumper(\$refRechnungDetailElement):" . Dumper($refRechnungDetailElement) . ":");

    if ( defined ($$refRechnungDetailElement) ) {
        $$refRechnungDetailElement = '';
        if ( $soapResponse->content =~ /^.*?<.*?:Body>\n*(.*)<\/.*?:Body>.*?$/s ) {
            $$refRechnungDetailElement = $1;
        }
    }
    $self->{'logger'}->trace("callWsRechnungDetail() Dumper(\$\$refRechnungDetailElement):" . Dumper($$refRechnungDetailElement) . ":");

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->trace("callWsRechnungDetail() root-element:" . $root . ":");
        $self->{'logger'}->trace("callWsRechnungDetail() Dumper(root):" . Dumper($root) . ":");

        my $messageIdNodes = $root->findnodes('soap:Body/*/messageID');
        foreach my $messageIdNode ( $messageIdNodes->get_nodelist() ) {
            $result->{'messageID'} = $messageIdNode->textContent;
            last;
        }

        my $rechnungNodes = $root->findnodes('soap:Body/*/rechnung');
        $self->{'logger'}->trace("callWsRechnungDetail() rechnungNodes:" . $rechnungNodes . ":");
        $self->{'logger'}->trace("callWsRechnungDetail() Dumper(rechnungNodes):" . Dumper($rechnungNodes) . ":");

		foreach my $rechnungNode ( $rechnungNodes->get_nodelist() ) {    # regularly there is only one rechnung node
            $self->{'logger'}->trace("callWsRechnungDetail() rechnungNode->nodeName:" . $rechnungNode->nodeName . ":");
            my $rechnungRecord = {'auftragsPositionCount' => 0, 'auftragsPositionRecords' => []};
			foreach my $rechnungChild ( $rechnungNode->childNodes() ) {    # <id> <nummer> <datum> <auftragsPosition> are of interest
                $self->{'logger'}->trace("callWsRechnungDetail() rechnungChild->nodeName:" . $rechnungChild->nodeName . ":");
                # copy values of hit into rechnungrecord
                if ( $rechnungChild->nodeName eq 'auftragsPosition' ) {
                    my $auftragsPositionRecord = ();
                    foreach my $auftragsPositionChild ( $rechnungChild->childNodes() ) {
                        if ( $auftragsPositionChild->nodeName !~ /^#/ ) {
                            $auftragsPositionRecord->{$auftragsPositionChild->nodeName} = $auftragsPositionChild->textContent;
                        }
                    }
                    push @{$rechnungRecord->{'auftragsPositionRecords'}}, $auftragsPositionRecord;
                    $rechnungRecord->{'auftragsPositionCount'} += 1;
                } else {
                    if ( $rechnungChild->nodeName !~ /^#/ ) {
                        $rechnungRecord->{$rechnungChild->nodeName} = $rechnungChild->textContent;
                    }
                }
			}
            push @{$result->{'rechnungRecords'}}, $rechnungRecord;
            $result->{'rechnungCount'} += 1;
            $self->{'logger'}->trace("callWsRechnungDetail() Dumper(result->{'rechnungRecords'}->[i]):" . Dumper($result->{'rechnungRecords'}->[$result->{'rechnungCount'}-1]) . ":");
		}
	}
	
	return $result;
}

# search invoices using web service RechnungList
sub callWsRechnungList {
	my $self = shift;
    my $ekzCustomerNumber = shift;                 # mandatory
	my $selVon = shift;                            # mandatory
	my $selBis = shift;                            # optional
	my $selKundennummerWarenEmpfaenger = shift;    # optional

	my $result = {  'rechnungCount' => 0,
                    'rechnungRecords' => []
    };

    $self->{'logger'}->info("callWsRechnungList() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                         ": selVon:" . (defined($selVon) ? $selVon : 'undef') .
                                                         ": selBis:" . (defined($selBis) ? $selBis : 'undef') .
                                                         ": selKundennummerWarenEmpfaenger:" . (defined($selKundennummerWarenEmpfaenger) ? $selKundennummerWarenEmpfaenger : 'undef') .
                                                         ":");

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
    $xmlwriter->startTag(     'bes:RechnungListElement',
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
    $xmlwriter->endTag(       'bes:RechnungListElement');
    $xmlwriter->endTag(     'soap:Body');

    $xmlwriter->endTag(   'soap:Envelope');

    my $soapEnvelope = "\n";
    $soapEnvelope .= $xmlwriter->end();
	
	my $soapResponse = $self->doQuery('"urn:rechnunglist"', $soapEnvelope);

    $self->{'logger'}->debug("callWsRechnungList() Dumper(soapResponse):" . Dumper($soapResponse) . ":");

	if ($soapResponse->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($soapResponse->content);

	    my $root = $dom->documentElement();

        $self->{'logger'}->trace("callWsRechnungList() root-element:" . $root . ":");
        $self->{'logger'}->trace("callWsRechnungList() Dumper(root):" . Dumper($root) . ":");

        my $rechnungNodes = $root->findnodes('soap:Body/*/rechnung');
        $self->{'logger'}->trace("callWsRechnungList() rechnungNodes:" . $rechnungNodes . ":");
        $self->{'logger'}->trace("callWsRechnungList() Dumper(rechnungNodes):" . Dumper($rechnungNodes) . ":");

		foreach my $rechnungNode ( $rechnungNodes->get_nodelist() ) {
            $self->{'logger'}->trace("callWsRechnungList() rechnungNode->nodeName:" . $rechnungNode->nodeName . ":");
            my $rechnungRecord = ();
			foreach my $rechnungChild ( $rechnungNode->childNodes() ) {    # <id> <nummer> <datum> sind hier interessant
                $self->{'logger'}->trace("callWsRechnungList() rechnungChild->nodeName:" . $rechnungChild->nodeName . ":");
                # copy values of hit into rechnungRecord
                if ( $rechnungChild->nodeName !~ /^#/ ) {
				    $rechnungRecord->{$rechnungChild->nodeName} = $rechnungChild->textContent;
                }
			}
            push @{$result->{'rechnungRecords'}}, $rechnungRecord;
            $result->{'rechnungCount'} += 1;
            #$self->{'logger'}->debug("callWsRechnungList() result->{'rechnungRecords'}->[i]:" . $result->{'rechnungRecords'}->[$result->{'rechnungCount'}-1] . ":");
            $self->{'logger'}->trace("callWsRechnungList() Dumper(result->{'rechnungRecords'}->[i]):" . Dumper($result->{'rechnungRecords'}->[$result->{'rechnungCount'}-1]) . ":");
		}
	}
	
	return $result;
}

# send a media items order using web service Bestellung
sub callWsBestellung {
	my $self = shift;
    my $ekzCustomerNumber = shift;                  # mandatory
	my $param = shift;                              # mandatory (containing values required for BestellungElement request)
    my $splitOperationMode = shift;                 # if 0: build request and call webservice;   if 1: build request if ! preparedRequest , call webservice if preparedRequest
    my $preparedRequest = shift;
    my $soapRequest;
    my $soapResponse;
    my $result = {  'statusCode' => '',
                    'statusMessage' => '',
                    'ekzBestellNr' => 0
                 };
	
    $self->{'logger'}->info("callWsBestellung() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                   ": param:" . (defined($param) ? Dumper($param) : 'undef') .
                                                   ": splitOperationMode:" . (defined($splitOperationMode) ? $splitOperationMode : 'undef') .
                                                   ":");
    $self->{'logger'}->trace("callWsBestellung() START preparedRequest:" . (defined($preparedRequest) ? Dumper($preparedRequest) : 'undef') . ":");

    if ( $splitOperationMode && $preparedRequest ) {
        # use prepared request
        $soapRequest = $preparedRequest
    } else {
        # build request

        # <messageId> is definded as xs:int in the wsdl.
        # So we calculate (current seconds * 1000 + milliseconds) modulo 1000000000 to get a quite unique number that fits in a 32-bit integer the ekz seems to use for this purpose.
        my $messageId = substr(substr($self->genTransactionId(''),0,-3),-9) + 0;
	    my $zeitstempel = $self->genZeitstempel();

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
        $xmlwriter->startTag(     'ns1:BestellungElement',
                                      'xmlns:ns1' => 'http://www.ekz.de/BestellsystemWSDL');

        $xmlwriter->dataElement(    'messageID' => $messageId);    # really required?
        $xmlwriter->dataElement(    'zeitstempel' => $zeitstempel);    # really required?
        $xmlwriter->dataElement(    'lmsBestellCode' => $param->{lmsBestellCode});
        $xmlwriter->dataElement(    'waehrung' => $param->{waehrung});
        $xmlwriter->dataElement(    'gesamtpreis' => sprintf("%.2f",$param->{gesamtpreis}));
        $xmlwriter->dataElement(    'hauptstelle' => $param->{hauptstelle});    # mandatory field
        $xmlwriter->dataElement(    'isTestBestellung' => 'false');    # not required?
#        $xmlwriter->dataElement(    'mehrpreisSeparateRechnung' => 'false');    # not required? wovon abhängig?

        if ( $param->{rechnungsEmpfaenger} ) {
        # rechnungsEmpfaenger should contain one of ekzKundenNr / lmsKundenNr / adresseElement
        $xmlwriter->startTag(       'rechnungsEmpfaenger');    # not required (ekz believes that it is useless except for subfield ekzKundenNr)
        $xmlwriter->dataElement(      'ekzKundenNr' => $param->{rechnungsEmpfaenger}->{ekzKundenNr}) if $param->{rechnungsEmpfaenger}->{ekzKundenNr};    # not required
        $xmlwriter->dataElement(      'lmsKundenNr' => $param->{rechnungsEmpfaenger}->{lmsKundenNr}) if $param->{rechnungsEmpfaenger}->{lmsKundenNr};    # not required
        if ( $param->{rechnungsEmpfaenger}->{adresseElement} ) {
        $xmlwriter->startTag(         'adresseElement');    # not required
        $xmlwriter->dataElement(        'name1' => $param->{rechnungsEmpfaenger}->{adresseElement}->{name1}) if $param->{rechnungsEmpfaenger}->{adresseElement}->{name1};    # formally not required
        $xmlwriter->dataElement(        'name2' => $param->{rechnungsEmpfaenger}->{adresseElement}->{name2}) if $param->{rechnungsEmpfaenger}->{adresseElement}->{name2};    # formally not required
        $xmlwriter->dataElement(        'name3' => $param->{rechnungsEmpfaenger}->{adresseElement}->{name3}) if $param->{rechnungsEmpfaenger}->{adresseElement}->{name3};    # formally not required
        $xmlwriter->dataElement(        'strasse' => $param->{rechnungsEmpfaenger}->{adresseElement}->{strasse}) if $param->{rechnungsEmpfaenger}->{adresseElement}->{strasse};    # formally not required
        $xmlwriter->dataElement(        'ort' => $param->{rechnungsEmpfaenger}->{adresseElement}->{ort}) if $param->{rechnungsEmpfaenger}->{adresseElement}->{ort};    # formally not required
        $xmlwriter->dataElement(        'plz' => $param->{rechnungsEmpfaenger}->{adresseElement}->{plz}) if $param->{rechnungsEmpfaenger}->{adresseElement}->{plz};    # formally not required
        $xmlwriter->dataElement(        'land' => $param->{rechnungsEmpfaenger}->{adresseElement}->{land}) if $param->{rechnungsEmpfaenger}->{adresseElement}->{land};    # formally not required
        $xmlwriter->endTag(           'adresseElement');    # not required
        }
        $xmlwriter->endTag(         'rechnungsEmpfaenger');    # not required
        }

        if ( $param->{rechnungsKopieEmpfaenger} ) {
        # rechnungsKopieEmpfaenger should contain one of ekzKundenNr / lmsKundenNr / adresseElement
        $xmlwriter->startTag(       'rechnungsKopieEmpfaenger');    # not required (ekz believes that it is useless except for subfield ekzKundenNr)
        $xmlwriter->dataElement(      'ekzKundenNr' => $param->{rechnungsKopieEmpfaenger}->{ekzKundenNr}) if $param->{rechnungsKopieEmpfaenger}->{ekzKundenNr};    # not required
        $xmlwriter->dataElement(      'lmsKundenNr' => $param->{rechnungsKopieEmpfaenger}->{lmsKundenNr}) if $param->{rechnungsKopieEmpfaenger}->{lmsKundenNr};    # not required
        if ( $param->{rechnungsKopieEmpfaenger}->{adresseElement} ) {
        $xmlwriter->startTag(         'adresseElement');    # not required
        $xmlwriter->dataElement(        'name1' => $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{name1}) if $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{name1};    # formally not required
        $xmlwriter->dataElement(        'name2' => $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{name2}) if $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{name2};    # formally not required
        $xmlwriter->dataElement(        'name3' => $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{name3}) if $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{name3};    # formally not required
        $xmlwriter->dataElement(        'strasse' => $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{strasse}) if $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{strasse};    # formally not required
        $xmlwriter->dataElement(        'ort' => $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{ort}) if $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{ort};    # formally not required
        $xmlwriter->dataElement(        'plz' => $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{plz}) if $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{plz};    # formally not required
        $xmlwriter->dataElement(        'land' => $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{land}) if $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{land};    # formally not required
        $xmlwriter->endTag(           'adresseElement');    # not required
        }
        $xmlwriter->endTag(         'rechnungsKopieEmpfaenger');    # not required
        }

        $xmlwriter->dataElement(    'kundenBestellNotiz' => $param->{kundenBestellNotiz}) if $param->{kundenBestellNotiz};    # not required
        $xmlwriter->dataElement(    'rfidDatenModell' => $param->{rfidDatenModell}) if $param->{rfidDatenModell};    # not required
        $xmlwriter->dataElement(    'auftragsnummer' => $param->{auftragsnummer}) if $param->{auftragsnummer};    # not required
        
        # mandatory field, but may be empty
        $xmlwriter->startTag(       'besteller');    # required, but may be empty (ekz believes that it is useless)
        if ( $param->{besteller} ) {
        $xmlwriter->dataElement(      'name' => $param->{besteller}->{name}) if $param->{besteller}->{name};
        $xmlwriter->dataElement(      'vorname' => $param->{besteller}->{vorname}) if $param->{besteller}->{vorname};
        $xmlwriter->dataElement(      'email' => $param->{besteller}->{email}) if $param->{besteller}->{email};
        $xmlwriter->dataElement(      'ekzid' => $param->{besteller}->{ekzid}) if $param->{besteller}->{ekzid};
        }
        $xmlwriter->endTag(         'besteller');

        $xmlwriter->dataElement(    'quellSystem' => $param->{quellSystem}) if $param->{quellSystem};    # not required

        for ( my $iTitel = 0; $iTitel < scalar @{$param->{titel}}; $iTitel += 1 ) {
        $xmlwriter->startTag(       'titel');
        $xmlwriter->startTag(         'titelangabe');
        if ( $param->{titel}->[$iTitel]->{titelangabe}->{ekzArtikelNr} ) {
        $xmlwriter->dataElement(        'ekzArtikelNr' => $param->{titel}->[$iTitel]->{titelangabe}->{ekzArtikelNr});
        }
        $xmlwriter->startTag(           'titelInfo');
        $xmlwriter->dataElement(          'ekzArtikelArt' => $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{ekzArtikelArt}) if $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{ekzArtikelArt};
        $xmlwriter->dataElement(          'author' => $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{author}) if $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{author};
        $xmlwriter->dataElement(          'titel' => $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{titel}) if $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{titel};
        $xmlwriter->dataElement(          'isbn13' => $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{isbn13}) if $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{isbn13};
        $xmlwriter->dataElement(          'verlag' => $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{verlag}) if $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{verlag};
        $xmlwriter->dataElement(          'erscheinungsJahr' => $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{erscheinungsJahr}) if $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{erscheinungsJahr};
        $xmlwriter->endTag(             'titelInfo');
        $xmlwriter->endTag(           'titelangabe');

        $xmlwriter->dataElement(      'dublettenCheckAusgefuehrt' => $param->{titel}->[$iTitel]->{dublettenCheckAusgefuehrt} ? $param->{titel}->[$iTitel]->{dublettenCheckAusgefuehrt} : 'true');
        $xmlwriter->dataElement(      'datensatz' => $param->{titel}->[$iTitel]->{datensatz} ? $param->{titel}->[$iTitel]->{datensatz} : 'false');
        $xmlwriter->dataElement(      'datensatzOnly' => $param->{titel}->[$iTitel]->{datensatzOnly} ? $param->{titel}->[$iTitel]->{datensatzOnly} : 'false');

        for ( my $iEx = 0; $iEx < scalar @{$param->{titel}->[$iTitel]->{exemplar}}; $iEx += 1 ) {
        $xmlwriter->startTag(         'exemplar');
        # lmsExemplarID is optional, but maybe useful to store aqorders.ordernumber
        $xmlwriter->dataElement(        'lmsExemplarID' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{lmsExemplarID}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{lmsExemplarID};
        $xmlwriter->startTag(           'konfiguration');
        $xmlwriter->dataElement(          'anzahl' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{anzahl} + 0);

        if ( $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{besteller} ) {
        $xmlwriter->dataElement(      'ekzKundenNr' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{besteller});    # not required
        }

        if ( $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger} ) {
        # warenEmpfaenger should contain one of ekzKundenNr / lmsKundenNr / adresseElement
        $xmlwriter->startTag(       'warenEmpfaenger');    # not required (ekz believes that it is useless except for subfield ekzKundenNr)
        $xmlwriter->dataElement(      'ekzKundenNr' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{ekzKundenNr}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{ekzKundenNr};    # not required
        $xmlwriter->dataElement(      'lmsKundenNr' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{lmsKundenNr}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{lmsKundenNr};    # not required
        if ( $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement} ) {
        $xmlwriter->startTag(         'adresseElement');    # not required
        $xmlwriter->dataElement(        'name1' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{name1}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{name1};    # formally not required
        $xmlwriter->dataElement(        'name2' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{name2}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{name2};    # formally not required
        $xmlwriter->dataElement(        'name3' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{name3}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{name3};    # formally not required
        $xmlwriter->dataElement(        'strasse' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{strasse}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{strasse};    # formally not required
        $xmlwriter->dataElement(        'ort' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{ort}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{ort};    # formally not required
        $xmlwriter->dataElement(        'plz' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{plz}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{plz};    # formally not required
        $xmlwriter->dataElement(        'land' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{land}) if $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{land};    # formally not required
        $xmlwriter->endTag(           'adresseElement');    # not required
        }
        $xmlwriter->endTag(         'warenEmpfaenger');    # not required
        }

        for ( my $iBudget = 0; $iBudget < scalar @{$param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{budget}}; $iBudget += 1 ) {
        $xmlwriter->startTag(             'budget');
        $xmlwriter->dataElement(            'anteil' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{budget}->[$iBudget]->{anteil});
        $xmlwriter->dataElement(            'haushaltsstelle' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{budget}->[$iBudget]->{haushaltsstelle});
        $xmlwriter->dataElement(            'kostenstelle' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{budget}->[$iBudget]->{kostenstelle});
        $xmlwriter->endTag(               'budget');
        }

        $xmlwriter->startTag(             'preis');
        $xmlwriter->dataElement(            'rabatt' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{preis}->{rabatt});
        $xmlwriter->dataElement(            'fracht' => sprintf("%.2f",$param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{preis}->{fracht}));    # also required, may be 0.00 of course
        $xmlwriter->dataElement(            'einband' => sprintf("%.2f",$param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{preis}->{einband}));    # also required, may be 0.00 of course
        $xmlwriter->dataElement(            'bearbeitung' => sprintf("%.2f",$param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{preis}->{bearbeitung}));    # also required, may be 0.00 of course
        $xmlwriter->dataElement(            'ustSatz' => $param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{preis}->{ustSatz});
        $xmlwriter->dataElement(            'ust' => sprintf("%.2f",$param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{preis}->{ust}));
        $xmlwriter->dataElement(            'gesamtpreis' => sprintf("%.2f",$param->{titel}->[$iTitel]->{exemplar}->[$iEx]->{konfiguration}->{preis}->{gesamtpreis}));
        $xmlwriter->endTag(               'preis');

        # mandatory field, but may be empty
        $xmlwriter->startTag(             'ExemplarFelderElement');    # required
        $xmlwriter->endTag(               'ExemplarFelderElement');    # required

        $xmlwriter->endTag(             'konfiguration');
        $xmlwriter->endTag(           'exemplar');
        }

        $xmlwriter->endTag(         'titel');
        }    # end loop for my $iTitel = 0; $iTitel < scalar @{$param->{titel}}

        $xmlwriter->endTag(       'ns1:BestellungElement');
        $xmlwriter->endTag(     'soap:Body');

        $xmlwriter->endTag(   'soap:Envelope');

        $soapRequest = "\n" . $xmlwriter->end();
	}
        
    if ( ! $splitOperationMode || $preparedRequest ) {
	    $soapResponse = $self->doQuery('"urn:bestellung"', $soapRequest);

        $self->{'logger'}->debug("callWsBestellung() Dumper(soapResponse):" . Dumper($soapResponse) . ":");

	    if ($soapResponse->is_success) {
		    my $parser = XML::LibXML->new;
		    my $dom = $parser->parse_string($soapResponse->content);

	        my $root = $dom->documentElement();

            $self->{'logger'}->trace("callWsBestellung() root-element:" . $root . ":");
            $self->{'logger'}->trace("callWsBestellung() Dumper(root):" . Dumper($root) . ":");

            my $statusCodeNodes = $root->findnodes('soap:Body/*/statusCode');
            foreach my $statusCodeNode ( $statusCodeNodes->get_nodelist() ) {
                $result->{'statusCode'} = $statusCodeNode->textContent;
                last;
            }

            my $statusMessageNodes = $root->findnodes('soap:Body/*/statusMessage');
            foreach my $statusMessageNode ( $statusMessageNodes->get_nodelist() ) {
                $result->{'statusMessage'} = $statusMessageNode->textContent;
                last;
            }

            my $ekzBestellNrNodes = $root->findnodes('soap:Body/*/ekzBestellNr');
            $self->{'logger'}->trace("callWsBestellung() ekzBestellNrNodes:" . $ekzBestellNrNodes . ":");
            $self->{'logger'}->trace("callWsBestellung() Dumper(ekzBestellNrNodes):" . Dumper($ekzBestellNrNodes) . ":");
            foreach my $ekzBestellNrNode ( $ekzBestellNrNodes->get_nodelist() ) {
                $result->{'ekzBestellNr'} = $ekzBestellNrNode->textContent;
                last;
            }
        }
	}

	$self->{'logger'}->info("callWsBestellung() result->{statusCode}:" . $result->{'statusCode'} . ": ->{statusMessage}:" . $result->{'statusMessage'} . ": ->{ekzBestellNr}:" . $result->{'ekzBestellNr'} . ":");
    if ( wantarray() ) {
        return ($result, $soapRequest, $soapResponse);
    }
	return $result;
}

sub doQuery {
	my $self = shift;
    my $soapAction = shift;
    my $soapEnvelope = shift;

    my $soapEnvelopeAsOctets = Encode::encode('UTF-8', $soapEnvelope, Encode::FB_CROAK);    # 'encode' required for avoiding error: HTTP::Message content must be bytes at /usr/share/perl5/HTTP/Request/Common.pm line 94.

	my $soapResponse = $self->{'ua'}->post($self->{'url'}, 'Content-Type' => 'text/xml; charset="utf-8"', 'SOAPAction' => $soapAction, Content => $soapEnvelopeAsOctets);

    $self->{'logger'}->debug("doQuery() soapResponse:" . $soapResponse . ":");
    $self->{'logger'}->trace("doQuery() Dumper(soapResponse):" . Dumper(\$soapResponse) . ":");
	
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
# read date of last execution of ekz web service (e.g. StoList, LieferscheinDetail, RechnungDetail) from system preferences
###################################################################################################
sub getLastRunDate {
    my ($ekzWSName, $dateForm) = @_;
    my $ekzWSLastRunDateSysPrefName = '';
    my $ekzWsLastRunDate;
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::lib::EkzWebServices' });

    if ( $ekzWSName eq 'StoList' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzStandingOrderWSLastRunDate';
    } elsif ( $ekzWSName eq 'FortsetzungDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzSerialOrderWSLastRunDate';
    } elsif ( $ekzWSName eq 'LieferscheinDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzDeliveryNoteWSLastRunDate';
    } elsif ( $ekzWSName eq 'RechnungDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzInvoiceWSLastRunDate';
    }

    if ( length($ekzWSLastRunDateSysPrefName) > 0 ) {
        $ekzWsLastRunDate = C4::Context->preference($ekzWSLastRunDateSysPrefName);    # stored in american form yyyy-mm-dd
        $logger->trace("getLastRunDate() ekzWSName:" . (defined($ekzWSName) ? $ekzWSName : 'undef') .
                                                 " ekzWSLastRunDateSysPrefName:" . (defined($ekzWSLastRunDateSysPrefName) ? $ekzWSLastRunDateSysPrefName : 'undef') .
                                                 " ekzWsLastRunDate:" . (defined($ekzWsLastRunDate) ? $ekzWsLastRunDate : 'undef') .
                                                ":");
        if ( defined($ekzWsLastRunDate) && length($ekzWsLastRunDate) > 0 && $ekzWsLastRunDate !~ /^\d\d\d\d-\d\d-\d\d$/ ) {
            my $mess = "got invalid ekzWsLastRunDate value:" . $ekzWsLastRunDate . ": by ekzWSLastRunDateSysPrefName:" . $ekzWSLastRunDateSysPrefName . ":";
            $logger->warn("getLastRunDate() $mess");
            croak "EkzWebServices::getLastRunDate() " . $mess;
        }
        if ( defined($ekzWsLastRunDate) && length($ekzWsLastRunDate) > 0 && $dateForm eq 'E' ) {    # transform it into european form dd.mm.yyyy
            $ekzWsLastRunDate = substr($ekzWsLastRunDate,8,2) . '.' . substr($ekzWsLastRunDate,5,2) . '.' . substr($ekzWsLastRunDate,0,4);
        }
    }
    if ( length($ekzWsLastRunDate) == 0 ) {
        $ekzWsLastRunDate = undef;
    }
    $logger->trace("getLastRunDate(ekzWSName:$ekzWSName) returns ekzWsLastRunDate:" . $ekzWsLastRunDate . ":");
    return $ekzWsLastRunDate;    # undef is also a valid value: it disables the from-date selection in StoList
}


###################################################################################################
# set date of last execution of ekz web service (e.g. StoList, LieferscheinDetail) in system preferences
###################################################################################################
sub setLastRunDate {
    my ($ekzWSName, $ekzWsLastRunDate) = @_;
    my $ekzWSLastRunDateSysPrefName;
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::lib::EkzWebServices' });

    if ( $ekzWSName eq 'StoList' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzStandingOrderWSLastRunDate';
    } elsif ( $ekzWSName eq 'FortsetzungDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzSerialOrderWSLastRunDate';
    } elsif ( $ekzWSName eq 'LieferscheinDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzDeliveryNoteWSLastRunDate';
    } elsif ( $ekzWSName eq 'RechnungDetail' ) {
        $ekzWSLastRunDateSysPrefName = 'ekzInvoiceWSLastRunDate';
    }

    if ( length($ekzWSLastRunDateSysPrefName) > 0 ) {
        $logger->trace("setLastRunDate(ekzWSName:$ekzWSName) ref(ekzWsLastRunDate):" . ref($ekzWsLastRunDate) . ":");
        $logger->trace("setLastRunDate(ekzWSName:$ekzWSName) ekzWsLastRunDate->ymd:" . $ekzWsLastRunDate->ymd . ":");
        C4::Context->set_preference($ekzWSLastRunDateSysPrefName, $ekzWsLastRunDate->ymd, "Date of last execution of ekz web service $ekzWSName.", "Free");    # store the date in american form yyyy-mm-dd
    }
}

1;


