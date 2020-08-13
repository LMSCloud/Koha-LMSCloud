package C4::External::EKZ::DublettenCheckElement;

# Copyright 2017-2020 (C) LMSCLoud GmbH
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
use CGI::Carp;
use Time::HiRes qw(gettimeofday);

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );    # required for MARC::File::XML->decode(...)
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::External::EKZ::EkzAuthentication;
use C4::External::EKZ::lib::EkzKohaRecords;


sub new {
    my $class = shift;

    my $self  = {};
    bless $self, $class;

    $self->{logger} = Koha::Logger->get({ interface => 'C4::External::EKZ::DublettenCheckElement' });

    return $self;
}

sub process {
    my ($self, $request) = @_;    # $request->{'soap:Envelope'}->{'soap:Body'} contains our deserialized DublettenCheckElement of the HTTP request

    my $soapEnvelopeHeader = $request->{'soap:Envelope'}->{'soap:Header'};
    my $soapEnvelopeBody = $request->{'soap:Envelope'}->{'soap:Body'};

    $self->{logger}->debug("process() START request->{'soap:Envelope'}->{'soap:Header'}:" . Dumper($request->{'soap:Envelope'}->{'soap:Header'}) . ":");
    $self->{logger}->debug("process() START request->{'soap:Envelope'}->{'soap:Body'}:" . Dumper($request->{'soap:Envelope'}->{'soap:Body'}) . ":");

foreach my $tag  (keys %{$soapEnvelopeBody->{'ns2:DublettenCheckElement'}}) {
    $self->{logger}->trace("process() HTTP request tag:" . $tag . ":");
}

    my $wssusername = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'} : "WSS-username not defined";
    my $wsspassword = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'} : "WSS-username not defined";
    my $authenticated = C4::External::EKZ::EkzAuthentication::authenticate($wssusername, $wsspassword);
    my $ekzLocalServicesEnabled = C4::External::EKZ::EkzAuthentication::ekzLocalServicesEnabled();

    # result values
    my $respStatusCode = 'UNDEF';
    my $respStatusMessage = 'UNDEF';
    my $timeOfDay = [gettimeofday];
    my $respTransactionID = sprintf("%d.%06d", $timeOfDay->[0], $timeOfDay->[1]);     # seconds.microseconds
    my $titleCount = 0;
    my $titleWithDubCount = 0;
    my @dublettenInfoListe = ();
    

    if ( $authenticated && $ekzLocalServicesEnabled )
    {
        $self->{logger}->trace("process() HTTP request titel:" . $soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'} . ":");
        $self->{logger}->trace("process() HTTP request ref(titel):" . ref($soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'}) . ":");

        my $titeldefined = ( exists $soapEnvelopeBody->{'ns2:DublettenCheckElement'} && defined $soapEnvelopeBody->{'ns2:DublettenCheckElement'} &&
                             exists $soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'} && defined $soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'});
        my $titelArrayRef = [];    #  using ref to empty array if there are sent no titel blocks
        # if there is sent only one titel block, it is delivered here as hash ref
        if ( $titeldefined && ref($soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'}) eq 'HASH' ) {
            $titelArrayRef = [ $soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'} ]; # ref to anonymous array containing the single hash reference
        } else {
            # if there are sent more than one titel blocks, they are delivered here as array ref
            if ( $titeldefined && ref($soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'}) eq 'ARRAY' ) {
                 $titelArrayRef = $soapEnvelopeBody->{'ns2:DublettenCheckElement'}->{'titel'}; # ref to deserialized array containing the hash references
            }
        }
        $self->{logger}->debug("process() HTTP request titel array:" . @$titelArrayRef . ": scalar @$titelArrayRef:" . @$titelArrayRef . ":");

        $titleCount = scalar @$titelArrayRef;
        $self->{logger}->trace("process() HTTP titleCount:" . $titleCount . ":");
        for ( my $i = 0; $i < $titleCount; $i++ ) {
            $self->{logger}->trace("process() title loop i:$i:");
            my $titel = $titelArrayRef->[$i];

            # handle title block only if title info is not empty
            if ( $titel && defined($titel->{'titelInfo'}) && ref($titel->{'titelInfo'}) eq 'HASH' ) {

                # extracting the search criteria
                my $reqParamTitelInfo = {};
                $reqParamTitelInfo->{'ekzArtikelNr'} = $titel->{'ekzArtikelNr'};
                $reqParamTitelInfo->{'isbn'} = $titel->{'titelInfo'}->{'isbn'};
                $reqParamTitelInfo->{'isbn13'} = $titel->{'titelInfo'}->{'isbn13'};
                $reqParamTitelInfo->{'issn'} = $titel->{'titelInfo'}->{'issn'};
                $reqParamTitelInfo->{'ismn'} = $titel->{'titelInfo'}->{'ismn'};
                $reqParamTitelInfo->{'ean'} = $titel->{'titelInfo'}->{'ean'};
                $reqParamTitelInfo->{'author'} = $titel->{'titelInfo'}->{'author'};
                $reqParamTitelInfo->{'titel'} = $titel->{'titelInfo'}->{'titel'};
                $reqParamTitelInfo->{'erscheinungsJahr'} = $titel->{'titelInfo'}->{'erscheinungsJahr'};

                # log request parameters
                $self->{logger}->debug("process() HTTP request ekzArtikelNr:" . (defined($reqParamTitelInfo->{'ekzArtikelNr'}) ? $reqParamTitelInfo->{'ekzArtikelNr'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request isbn:" . (defined($reqParamTitelInfo->{'isbn'}) ? $reqParamTitelInfo->{'isbn'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request isbn13:" . (defined($reqParamTitelInfo->{'isbn13'}) ? $reqParamTitelInfo->{'isbn13'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request issn:" . (defined($reqParamTitelInfo->{'issn'}) ? $reqParamTitelInfo->{'issn'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request ismn:" . (defined($reqParamTitelInfo->{'ismn'}) ? $reqParamTitelInfo->{'ismn'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request ean:" . (defined($reqParamTitelInfo->{'ean'}) ? $reqParamTitelInfo->{'ean'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request author:" . (defined($reqParamTitelInfo->{'author'}) ? $reqParamTitelInfo->{'author'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request titel:" . (defined($reqParamTitelInfo->{'titel'}) ? $reqParamTitelInfo->{'titel'} : 'undef') . ":");
                $self->{logger}->debug("process() HTTP request erscheinungsJahr:" . (defined($reqParamTitelInfo->{'erscheinungsJahr'}) ? $reqParamTitelInfo->{'erscheinungsJahr'} : 'undef') . ":");

                my @dublettenInfo = $self->searchDubletten($reqParamTitelInfo);

                if(scalar(@dublettenInfo) > 0 ) {
                    $titleWithDubCount += 1;
                }

                $self->{logger}->debug("process() reqEkzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": Anzahl dublettenInfo:" . scalar @dublettenInfo . ":");
                $self->{logger}->trace("process() reqEkzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": dublettenInfo:" . @dublettenInfo . ":");

                push @dublettenInfoListe, @dublettenInfo;
            }
        }
    }

    $self->{logger}->debug("process() Anzahl dublettenInfoListe:" . scalar @dublettenInfoListe . ":");

    $respStatusCode = 'ERROR';
    if ( !$authenticated ) {
        $respStatusMessage = "nicht authentifiziert";
    } elsif ( !$ekzLocalServicesEnabled ) {
        $respStatusMessage = "Webservices für ekz-Anfragen sind in der Koha-Instanz " . C4::External::EKZ::EkzAuthentication::kohaInstanceName() . " nicht aktiviert.";
    } elsif ( @dublettenInfoListe+0 == 0 )
    {
        $respStatusMessage = "Keine Dubletten für $titleCount Titel gefunden";
    } else {
        $respStatusCode = 'SUCCESS';
        $respStatusMessage = "Dublette(n) für $titleWithDubCount Titel gefunden";
    }


    my $soapStatusCode = SOAP::Data->name( 'statusCode'    => $respStatusCode )->type( 'string' );
    my $soapStatusMessage = SOAP::Data->name( 'statusMessage'  => $respStatusMessage )->type( 'string' );
    my $soapTransactionID = SOAP::Data->name( 'transactionID'  => $respTransactionID )->type( 'string' );

    my @soapTitelListe = ();
    foreach my $dublettenInfo (@dublettenInfoListe)
    {
        $self->{logger}->debug("process() Anzahl EkzArtikelNr:" . $dublettenInfo->{'ekzArtikelNr'} . ":");

        my $soapEkzArtikelNr = SOAP::Data->name( 'ekzArtikelNr' => $dublettenInfo->{'ekzArtikelNr'} )->type( 'string' );
        my @soapExemplare = ();

        foreach my $dupExemplar (@{$dublettenInfo->{'exemplare'}})
        {
            $self->{logger}->debug("process() Anzahl dupExemplar->{'zweigstelle'}:" . $dupExemplar->{'zweigstelle'} . ":");

            my $soapExemplarVal;
            # Avoid sending an empty or invalid 'erscheinungsjahr' because this would cause an 'Unmarshalling Error' in the ekz software.
            if ( $dupExemplar->{'erscheinungsjahr'} && length($dupExemplar->{'erscheinungsjahr'}) == 4 ) {
                $soapExemplarVal = \SOAP::Data->value(
                    SOAP::Data->name( 'zweigstelle' => $dupExemplar->{'zweigstelle'} )->type( 'string' ),                
                    SOAP::Data->name( 'erscheinungsjahr' => $dupExemplar->{'erscheinungsjahr'} )->type( 'string' ),
                    SOAP::Data->name( 'auflage' => $dupExemplar->{'auflage'} )->type( 'string' )
                );
            } else {
                $soapExemplarVal = \SOAP::Data->value(
                    SOAP::Data->name( 'zweigstelle' => $dupExemplar->{'zweigstelle'} )->type( 'string' ), 
                    SOAP::Data->name( 'auflage' => $dupExemplar->{'auflage'} )->type( 'string' )
                );
            }
            my $soapExemplar = SOAP::Data->name( 'exemplar' => $soapExemplarVal );

            push @soapExemplare, $soapExemplar;
        }
        my $soapTitel = SOAP::Data->name( 'titel'  => \SOAP::Data->value($soapEkzArtikelNr,@soapExemplare));

        push @soapTitelListe, $soapTitel;
    }

    my $soapResponseElement = SOAP::Data->name( 'ns1:DublettenCheckResultatElement' )->SOAP::Header::value(
        [$soapStatusCode,
         $soapStatusMessage,
         $soapTransactionID,
         @soapTitelListe])->SOAP::Header::attr('xmlns:ns1="http://www.ekz.de/BestellsystemWSDL"');

    return $soapResponseElement;
     
}

sub searchDubletten {
    my ($self, $reqParamTitelInfo) = @_;
    my $ekzKohaRecord = C4::External::EKZ::lib::EkzKohaRecords->new();

    my $testIt = 0;
    my ( $marcresults, $hits ) = ( [], 0 );
    my $marc_titledata = '';
    
    # variables for result structure
    my @titelListe = ();
    my %titel = ();
    my @exemplare = ();

    if ( $testIt ) {
        $titel{'ekzArtikelNr'} = '3297876';
        my %exemplar = ();
        $exemplar{'zweigstelle'} = '1006286';
        $exemplar{'erscheinungsjahr'} = '2013';
        $exemplar{'auflage'} = '2';
        push @exemplare, \%exemplar;
        push @exemplare, \%exemplar;
        push @exemplare, \%exemplar;
        $titel{'exemplare'} = \@exemplare;
        push @titelListe, \%titel;
        push @titelListe, \%titel;

        $self->{logger}->debug("searchDubletten() titelListe:" . Dumper(@titelListe) . ":");
        $self->{logger}->debug("searchDubletten() Exemplare:" . Dumper(@exemplare) . ":");
        $self->{logger}->debug("searchDubletten() Anz. Exemplare:" . scalar @exemplare . ":");
        $self->{logger}->debug("searchDubletten() titel-Exemplare:" . Dumper(@{$titel{'exemplare'}}) . ":");
        $self->{logger}->debug("searchDubletten() Anz. titel-Exemplare:" . scalar @{$titel{'exemplare'}} . ":");
    } else
    {
        # search priority:  1. ekzArtikelNr  /  2. isbn or isbn13  /  3. issn or ismn or ean  /  4. titel and author and erscheinungsJahr
        $marcresults = $ekzKohaRecord->readTitleDubletten($reqParamTitelInfo,0);
    }

    $hits = scalar @{$marcresults} if $marcresults;
    $self->{logger}->debug("searchDubletten() hits:" . $hits . ":");
    
    # Search the items of the catalogue titles found (= candidates for duplicates). 
    # The caller of this web service expects in the response 1 XML 'titel' block for each XML 'titel' block in the request.
    # So we have to accumulate all items of the found duplicates candidates in 1 XML 'titel' block even if we found more than one duplicate candidates title.
    for (my $i = 0; $i < $hits and defined $marcresults->[$i]; $i++)
    {
        my $marcrecord;
        eval {
            $marcrecord =  MARC::Record::new_from_xml( $marcresults->[$i], "utf8", 'MARC21' );
        };
        carp "main: error in MARC::Record::new_from_xml:$@:\n" if $@;

        if ( $marcrecord )
        {
            my $biblionumber = $marcrecord->subfield("999","c");

            if ( !exists($titel{'ekzArtikelNr'}) ) {
                my $ekzArtikelNr = 'ohne ekz-Artikelnr.';
                my $kontrollNrID = defined($marcrecord->field("003")) ? $marcrecord->field("003")->data() : "undef";

                if ( defined($reqParamTitelInfo->{'ekzArtikelNr'}) && length($reqParamTitelInfo->{'ekzArtikelNr'}) > 0 ) {
                    $ekzArtikelNr = $reqParamTitelInfo->{'ekzArtikelNr'};    # effect of returning this value: the ekz web site displays title and ISBN of this medium; otherwise these two columns stay empty
                } else {
                    # the ekz web site displays column Artikelnummer; we use it to display title or isbn
                    if ( $kontrollNrID eq "DE-Rt5" && defined($marcrecord->field("001")) ) {
                        $ekzArtikelNr = $marcrecord->field("001")->data();    # the cn is a ekz article number only if cna == "DE-Rt5"
                    } else {
                        my $id = '';
                        if ( defined($reqParamTitelInfo->{'titel'}) && length($reqParamTitelInfo->{'titel'}) > 0 ) {
                            $id = $reqParamTitelInfo->{'titel'};
                        } elsif ( defined($reqParamTitelInfo->{'isbn13'}) && length($reqParamTitelInfo->{'isbn13'}) > 0 ) {
                            $id = $reqParamTitelInfo->{'isbn13'};
                        } elsif ( defined($reqParamTitelInfo->{'isbn'}) && length($reqParamTitelInfo->{'isbn'}) > 0 ) {
                            $id = $reqParamTitelInfo->{'isbn'};
                        }
                        if ( length($id) > 0 ) {
                            $ekzArtikelNr = 'keine ekz-Artikelnr. für: ' . $id;
                        }
                    }
                }
                $titel{'ekzArtikelNr'} = $ekzArtikelNr;
                $self->{logger}->debug("searchDubletten() marcrecord->field('003'):" . (defined($marcrecord->field("003")) ? $marcrecord->field("003")->data() : 'undef') . ": marcrecord->field('001'):" . (defined($marcrecord->field('001')) ? $marcrecord->field('001') : 'undef') . ": ekzArtikelNr:" . $ekzArtikelNr . ":");
            }

            
            $self->{logger}->debug("searchDubletten() reqParamTitelInfo->{'ekzArtikelNr'}:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": duplicate candidate biblionumber:" . $biblionumber . ":");
            # read items of this biblio number
            my @itemnumbers = @{ C4::Items::GetItemnumbersForBiblio( $biblionumber ) };
            for my $itemnumber ( @itemnumbers )
            {
                
                my %exemplar = ();
                my $itemrecord = C4::Items::GetItem( $itemnumber, 0, 0);

                $exemplar{'zweigstelle'} = defined $itemrecord->{'homebranch'} ? $itemrecord->{'homebranch'} : "";

                my $erscheinungsjahr = '';
                if ( defined $marcrecord->subfield("260","c") && length $marcrecord->subfield("260","c") > 0 ) {
                    $erscheinungsjahr = $marcrecord->subfield("260","c");
                } else {
                    $erscheinungsjahr = defined $marcrecord->subfield("264","c") ? $marcrecord->subfield("264","c") : "";
                }
                if ( $erscheinungsjahr =~ /^.*?(\d\d\d\d).*$/m ) {
                    $exemplar{'erscheinungsjahr'} =  $1;
                } 

                my $auflage =  defined $marcrecord->subfield("250","a") ? $marcrecord->subfield("250","a") : "";
                # It would be nice to display also the itemstypes.description here, but only integers are allowed in XML element <auflage> of response:
                if ( $auflage =~ /^.*?(\d+).*$/m ) {
                    $exemplar{'auflage'} =  $1;
                }
            
                push @exemplare, \%exemplar;
            }
        }
    }
    if ( exists($titel{'ekzArtikelNr'}) ) {
        $titel{'exemplare'} = \@exemplare;
        push @titelListe, \%titel;
    }

    return @titelListe;
}

1;
