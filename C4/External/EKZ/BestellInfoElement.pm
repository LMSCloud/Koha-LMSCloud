package C4::External::EKZ::BestellInfoElement;

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
use CGI::Carp;
use Time::HiRes qw(gettimeofday);

use C4::Context;
use C4::Koha;
use C4::Items qw(AddItem);
use C4::Branch qw(GetBranches);
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::External::EKZ::EkzAuthentication;
use C4::External::EKZ::lib::EkzKohaRecords;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;



my $debugIt = 1;

my $dateTimeNow;    # time stamp value, identical for message, titles and items
my $dbh = C4::Context->dbh;
my $homebranch = C4::Context->preference("ekzWebServicesDefaultBranch");
my $titleSourceSequence = C4::Context->preference("ekzTitleDataServicesSequence");
my $ekzWsHideOrderedTitlesInOpac = 1;    # policy: hide title if not explictly set to 'show'
my $ekzWebServicesHideOrderedTitlesInOpac = C4::Context->preference("ekzWebServicesHideOrderedTitlesInOpac");
my $ekzWebServicesSetItemSubfieldsWhenOrdered = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered");

# variables for email log
my @logresult = ();
my @actionresult = ();
my $importerror = 0;          # flag if an insert error happened
my %importIds = ();
my $dt = DateTime->now;
$dt->set_time_zone( 'Europe/Berlin' );
my ($message, $subject, $haserror) = ('','',0);

sub init {
    $debugIt = 1;
    $dbh = C4::Context->dbh;
    $dbh->{AutoCommit} = 0;
    $homebranch = C4::Context->preference("ekzWebServicesDefaultBranch");
    $homebranch =~ s/^\s+|\s+$//g; # trim spaces
    $titleSourceSequence = C4::Context->preference("ekzTitleDataServicesSequence");
    if ( !defined($titleSourceSequence) ) {
        $titleSourceSequence = '_LMSC|_EKZWSMD|DNB|_WS';
    }
    $ekzWebServicesHideOrderedTitlesInOpac = C4::Context->preference("ekzWebServicesHideOrderedTitlesInOpac");
    $ekzWsHideOrderedTitlesInOpac = 1;    # policy: hide title if not explictly set to 'show'
    if( defined($ekzWebServicesHideOrderedTitlesInOpac) && 
        length($ekzWebServicesHideOrderedTitlesInOpac) > 0 &&
        $ekzWebServicesHideOrderedTitlesInOpac == 0 ) {
            $ekzWsHideOrderedTitlesInOpac = 0;
    }
    $ekzWebServicesSetItemSubfieldsWhenOrdered = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered");

    @logresult = ();
    @actionresult = ();
    $importerror = 0;          # flag if an insert error happened
    %importIds = ();
    $dt = DateTime->now;
    $dt->set_time_zone( 'Europe/Berlin' );
    ($message, $subject, $haserror) = ('','',0);
}

sub BestellInfoElement {
    my ($soapBodyContent, $request) = @_;    # $request->{'soap:Envelope'}->{'soap:Body'} contains our deserialized BestellinfoElement of the HTTP request
    my $actionresultRef;

    my $soapEnvelopeHeader = $request->{'soap:Envelope'}->{'soap:Header'};
    my $soapEnvelopeBody = $request->{'soap:Envelope'}->{'soap:Body'};

print STDERR Dumper($soapEnvelopeHeader) if $debugIt;
print STDERR Dumper($soapEnvelopeBody->{'ns2:BestellInfoElement'}) if $debugIt;

print STDERR "BestellInfoElement::BestellInfoElement() HTTP request request->body:", $soapEnvelopeBody, ":\n" if $debugIt;
print STDERR "BestellInfoElement::BestellInfoElement() HTTP request request messageID:", $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'messageID'}, ":\n" if $debugIt;
print STDERR "BestellInfoElement::BestellInfoElement() HTTP request request ekzBestellNr:", $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'}, ":\n" if $debugIt; 

foreach my $tag  (keys %{$soapEnvelopeBody->{'ns2:BestellInfoElement'}}) {
    print STDERR "BestellInfoElement::BestellInfoElement() HTTP request tag:", $tag, ":\n" if $debugIt;
}

    my $wssusername = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'} : "WSS-username not defined";
    my $wsspassword = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'} : "WSS-username not defined";
print STDERR "BestellInfoElement::BestellInfoElement() HTTP request header wss username/password:" . $wssusername . "/" . $wsspassword . ":\n" if $debugIt;
    my $authenticated = C4::External::EKZ::EkzAuthentication::authenticate($wssusername, $wsspassword);
    my $ekzLocalServicesEnabled = C4::External::EKZ::EkzAuthentication::ekzLocalServicesEnabled();


    my $ekzBestellNrIsDuplicate = 0;
    my $reqEkzBestellNr = defined $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'} && length($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'})
                            ? $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'} : 'UNDEFINED';
    my $zeitstempel = $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'zeitstempel'};
    my $reqEkzBestellDatum = DateTime->new( year => substr($zeitstempel,0,4), month => substr($zeitstempel,5,2), day => substr($zeitstempel,8,2), time_zone => 'local' );
    $dateTimeNow = DateTime->now(time_zone => 'local');

    # result values
    my $respStatusCode = 'UNDEF';
    my $respStatusMessage = 'UNDEF';
    my $timeOfDay = [gettimeofday];
    my $respTransactionID = sprintf("%d.%06d", $timeOfDay->[0], $timeOfDay->[1]);     # seconds.microseconds
    my @idPaarListe = ();
    
    
print STDERR "BestellInfoElement::BestellInfoElement() authenticated:" . $authenticated . ": reqEkzBestellNr:" . $reqEkzBestellNr . ":\n" if $debugIt;
    if ( $authenticated && $ekzLocalServicesEnabled && $reqEkzBestellNr ne 'UNDEFINED' ) {

        # Insert a record into table acquisition_import representing the BestellInfo request.
        # If a order message record with this $reqEkzBestellNr exists already there will be written a log entry
        # and no further processing will be done.

        my $selParam = {
            vendor_id => "ekz",
            object_type => "order",
            object_number => $reqEkzBestellNr,
            rec_type => "message",
            processingstate => "ordered"
        };
        my $insParam = {
            #id => 0, # AUTO
            vendor_id => "ekz",
            object_type => "order",
            object_number => $reqEkzBestellNr,
            object_date => DateTime::Format::MySQL->format_datetime($reqEkzBestellDatum),    # in local time_zone
            rec_type => "message",
            #object_item_number => "", # NULL
            processingstate => "ordered",
            processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
            payload => $soapBodyContent,
            #object_reference => undef # NULL
        };
        my $acquisitionImportIdBestellInfo;
        my $acquisitionImportBestellInfo = Koha::AcquisitionImport::AcquisitionImports->new();
        my $hit = $acquisitionImportBestellInfo->_resultset()->find( $selParam );
print STDERR "BestellInfoElement::BestellInfoElement() ref(hit):", ref($hit), ":\n" if $debugIt;
        if ( defined($hit) ) {
            $ekzBestellNrIsDuplicate = 1;
            my $mess = sprintf("The ekzBestellNr '%s' has already been used at %s. Processing denied.\n",$reqEkzBestellNr, $hit->get_column('processingtime'));
            carp $mess;
print STDERR "BestellInfoElement::BestellInfoElement() hit->{_column_data}:", Dumper($hit->{_column_data}), ":\n" if $debugIt;
        } else {
            $acquisitionImportIdBestellInfo = $acquisitionImportBestellInfo->_resultset()->create($insParam)->get_column('id');
print STDERR "BestellInfoElement::BestellInfoElement() acquisitionImportIdBestellInfo:", $acquisitionImportIdBestellInfo, ":\n" if $debugIt;
        }

        print STDERR "BestellInfoElement::BestellInfoElement() HTTP request titel:",$soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'},":\n" if $debugIt;
        print STDERR "BestellInfoElement::BestellInfoElement() HTTP request ref(titel):",ref($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'}),":\n" if $debugIt;
        # look for XML <titel> blocks
        my $titeldefined = ( exists $soapEnvelopeBody->{'ns2:BestellInfoElement'} && defined $soapEnvelopeBody->{'ns2:BestellInfoElement'} &&
                             exists $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'} && defined $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'});
        my $titelArrayRef = [];    #  using ref to empty array if there are sent no titel blocks
        # if there is sent only one titel block, it is delivered here as hash ref
        if ( $titeldefined && ref($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'}) eq 'HASH' ) {
            $titelArrayRef = [ $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'} ]; # ref to anonymous array containing the single hash reference
        } else {
            # if there are sent more than one titel blocks, they are delivered here as array ref
            if ( $titeldefined && ref($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'}) eq 'ARRAY' ) {
                $titelArrayRef = $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'}; # ref to deserialized array containing the hash references
            }
        }
        print STDERR "BestellInfoElement::BestellInfoElement() HTTP request titel array:",@$titelArrayRef," AnzElem:", scalar @$titelArrayRef,":\n" if $debugIt;

        my $titleCount = scalar @$titelArrayRef;
        print STDERR "BestellInfoElement::BestellInfoElement() HTTP titleCount:",$titleCount, ":\n" if $debugIt;
        # for each titel
        for ( my $i = 0; $i < $titleCount && $reqEkzBestellNr ne 'UNDEFINED' && !$ekzBestellNrIsDuplicate; $i++ ) {
            print STDERR "BestellInfoElement::BestellInfoElement() title loop $i\n" if $debugIt;
            my $titel = $titelArrayRef->[$i];

            # extracting the search criteria
            my $reqParamTitelInfo->{'ekzArtikelNr'} = $titel->{'ekzArtikelNr'};
            $reqParamTitelInfo->{'ekzArtikelArt'} = $titel->{'titelInfo'}->{'ekzArtikelArt'};
            $reqParamTitelInfo->{'ekzVerkaufsEinheitsNr'} = $titel->{'titelInfo'}->{'ekzVerkaufsEinheitsNr'};
            $reqParamTitelInfo->{'ekzSystematik'} = $titel->{'titelInfo'}->{'ekzSystematik'};
            $reqParamTitelInfo->{'nonBookBestellCode'} = $titel->{'titelInfo'}->{'nonBookBestellCode'};
            $reqParamTitelInfo->{'ekzInteressenKreis'} = $titel->{'titelInfo'}->{'ekzInteressenKreis'};
            $reqParamTitelInfo->{'StOkennung'} = $titel->{'titelInfo'}->{'StOkennung'};
            $reqParamTitelInfo->{'StOklartext'} = $titel->{'titelInfo'}->{'StOklartext'};
            $reqParamTitelInfo->{'fortsetzung'} = $titel->{'titelInfo'}->{'fortsetzung'};
            $reqParamTitelInfo->{'urn'} = $titel->{'titelInfo'}->{'urn'};
            $reqParamTitelInfo->{'isbn'} = $titel->{'titelInfo'}->{'isbn'};
            $reqParamTitelInfo->{'isbn13'} = $titel->{'titelInfo'}->{'isbn13'};
            $reqParamTitelInfo->{'issn'} = $titel->{'titelInfo'}->{'issn'};
            $reqParamTitelInfo->{'ismn'} = $titel->{'titelInfo'}->{'ismn'};
            $reqParamTitelInfo->{'author'} = $titel->{'titelInfo'}->{'author'};
            $reqParamTitelInfo->{'titel'} = $titel->{'titelInfo'}->{'titel'};
            $reqParamTitelInfo->{'verlag'} = $titel->{'titelInfo'}->{'verlag'};
            $reqParamTitelInfo->{'erscheinungsJahr'} = $titel->{'titelInfo'}->{'erscheinungsJahr'};
            $reqParamTitelInfo->{'auflage'} = $titel->{'titelInfo'}->{'auflage'};
            
            if ( $debugIt ) {
            # log request parameters
                my $logstr = $titel->{'ekzArtikelNr'} ? $titel->{'ekzArtikelNr'} : "<undef>";
                print STDERR "BestellInfoElement::BestellInfoElement() HTTP request ekzArtikelNr:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'isbn'} ? $titel->{'titelInfo'}->{'isbn'} : "<undef>";
                print STDERR "BestellInfoElement::BestellInfoElement() HTTP request isbn:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'isbn13'} ? $titel->{'titelInfo'}->{'isbn13'} : "<undef>";
                print STDERR "BestellInfoElement::BestellInfoElement() HTTP request isbn13:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'author'} ? $titel->{'titelInfo'}->{'author'} : "<undef>";
                print STDERR "BestellInfoElement::BestellInfoElement() HTTP request author:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'titel'} ? $titel->{'titelInfo'}->{'titel'} : "<undef>";
                print STDERR "BestellInfoElement::BestellInfoElement() HTTP request titel:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'erscheinungsJahr'} ? $titel->{'titelInfo'}->{'erscheinungsJahr'} : "<undef>";
                print STDERR "BestellInfoElement::BestellInfoElement() HTTP request erscheinungsJahr:$logstr:\n";
            }

            print STDERR "BestellInfoElement::BestellInfoElement() HTTP request exemplar:",$titel->{'exemplar'},":\n" if $debugIt;
            print STDERR "BestellInfoElement::BestellInfoElement() HTTP request ref(exemplar):",ref($titel->{'exemplar'}),":\n" if $debugIt;
            # look for XML <exemplar> blocks within current <titel> block
            my $exemplardefined = ( exists $titel->{'exemplar'} && defined $titel->{'exemplar'} );
            my $exemplarArrayRef = [];    #  using ref to empty array if there are sent no exemplar blocks
            # if there is sent only one exemplar block, it is delivered here as hash ref
            if ( $exemplardefined && ref($titel->{'exemplar'}) eq 'HASH' ) {
                $exemplarArrayRef = [ $titel->{'exemplar'} ]; # ref to anonymous array containing the single hash reference
            } else {
                # if there are sent more than one exemplar blocks, they are delivered here as array ref
                if ( $exemplardefined && ref($titel->{'exemplar'}) eq 'ARRAY' ) {
                     $exemplarArrayRef = $titel->{'exemplar'};  # ref to deserialized array containing the hash references
                }
            }
            print STDERR "BestellInfoElement::BestellInfoElement() HTTP request exemplarArray:",@$exemplarArrayRef," AnzElem:", 0+@$exemplarArrayRef,":\n" if $debugIt;
            my @idPaarListeTmp = &handleTitelBestellInfo($acquisitionImportIdBestellInfo, $reqEkzBestellNr, $reqEkzBestellDatum, $reqParamTitelInfo, $exemplarArrayRef, \$actionresultRef); ## add title data to table biblio, biblioitems, and exemplar data to table items

            print STDERR "BestellInfoElement::BestellInfoElement() Anzahl idPaarListe:",@idPaarListeTmp+0, "\n" if $debugIt;
            print STDERR "BestellInfoElement::BestellInfoElement() idPaarListe:",@idPaarListeTmp, "\n" if $debugIt;
            push @actionresult, @$actionresultRef;

            push @idPaarListe, @idPaarListeTmp;
        }   
    }

    print STDERR "BestellInfoElement::BestellInfoElement() Anzahl idPaarListe:",@idPaarListe+0, "\n" if $debugIt;
    print STDERR "BestellInfoElement::BestellInfoElement() idPaarListe:",@idPaarListe, "\n" if $debugIt;

    #$dbh->rollback;    # roll it back for TEST XXXWH
    #@idPaarListe = ();


    $respStatusCode = 'ERROR';
    if ( !$authenticated ) {
        $respStatusMessage = "nicht authentifiziert";
    } elsif ( !$ekzLocalServicesEnabled ) {
        $respStatusMessage = "Webservices für ekz-Anfragen sind in der Koha-Instanz " . C4::External::EKZ::EkzAuthentication::kohaInstanceName() . " nicht aktiviert.";
    } elsif ( $reqEkzBestellNr eq 'UNDEFINED' )
    {
        $respStatusMessage = "keine ekzBestellNr empfangen";
    } elsif ( $ekzBestellNrIsDuplicate )
    {
        $respStatusMessage = "Die ekz-BestellNr '$reqEkzBestellNr' wurde bereits verwendet (Duplikat).";
    } elsif ( @idPaarListe+0 == 0 )    # no title or item inserted
    {
        $respStatusMessage = "nicht korrekt verarbeitet";
    } else
    {
        $respStatusCode = 'SUCCESS';    # at least one title or item inserted
        $respStatusMessage = "korrekt verarbeitet";

    }

    my $soapStatusCode = SOAP::Data->name( 'statusCode'    => $respStatusCode )->type( 'string' );
    my $soapStatusMessage = SOAP::Data->name( 'statusMessage'  => $respStatusMessage )->type( 'string' );
    my $soapTransactionID = SOAP::Data->name( 'transactionID'  => $respTransactionID )->type( 'string' );

    my @soapIdPaarListe = ();
    foreach my $idPaar (@idPaarListe)
    {
        print STDERR "BestellInfoElement::BestellInfoElement(); ekzExemplarID:",$idPaar->{'ekzExemplarID'},":\n" if $debugIt;

        my $soapIdPaar = SOAP::Data->name( 'idPaar' => \SOAP::Data->value(
                SOAP::Data->name( 'ekzExemplarID' => $idPaar->{'ekzExemplarID'} )->type( 'string' ),
                SOAP::Data->name( 'lmsExemplarID' => $idPaar->{'lmsExemplarID'} )->type( 'string' )
        ));

        push @soapIdPaarListe, $soapIdPaar;
    }

    # create @logresult message for log email, representing all titles of the BestellInfo with all their processed items
    push @logresult, ['BestellInfo', $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'messageID'}, \@actionresult];
print STDERR "Dumper(\\\@logresult): ####################################################################################################################\n" if $debugIt;
print STDERR Dumper(\@logresult) if $debugIt;



    # commit the complete BestellInfo (only as a single transaction)
    $dbh->commit();
    $dbh->{AutoCommit} = 1;
    
    if ( scalar(@logresult) > 0 ) {
        my @importIds = keys %importIds;
        ($message, $subject, $haserror) = C4::External::EKZ::lib::EkzKohaRecords->createProcessingMessageText(\@logresult, "headerTEXT", $dt, \@importIds, $reqEkzBestellNr);  # we use ekzBestellNr as part of importID in MARc field 025.a: (EKZImport)$importIDs->[0]
        C4::External::EKZ::lib::EkzKohaRecords->sendMessage($message, $subject);
    }

    my $soapResponseElement = SOAP::Data->name( 'ns2:BestellInfoResultatElement' )->SOAP::Header::value(
        [$soapStatusCode,
         $soapStatusMessage,
         $soapTransactionID,
         @soapIdPaarListe])->SOAP::Header::attr('xmlns:ns2="http://www.ekz.de/BestellsystemWSDL"');

    return $soapResponseElement;
     
}

sub handleTitelBestellInfo {
    my ( $acquisitionImportIdBestellInfo, $reqEkzBestellNr, $reqEkzBestellDatum, $reqParamTitelInfo, $exemplare, $retactionresult ) = @_;

    my $query = "cn:\"-1\"";                    # control number search, definition for no hit
    my $error = undef;
    my $marcresults = \();
    my $total_hits = 0;
    my $hits = 0;
    my $titleHits = { 'count' => 0, 'records' => [] };
    my $itemtypes;
    my $biblioExisting = 0;
    my $biblioInserted = 0;
    my $biblionumber = 0;
    my $biblioitemnumber;
    my $acquisitionImportIdTitle = 0;

    # variables for email log
    my $processedTitlesCount = 1;       # counts the title processed in this step (1)
    my $importedTitlesCount = 0;        # counts the title inserted in this step (0/1)
    my $updatedTitlesCount = 0;         # counts the found title with added items in this step (0/1)
    my $processedItemsCount = 0;        # counts the items processed in this step
    my $importedItemsCount = 0;         # counts the items inserted in this step
    my $importresult = 0;               # insert result per title / item   OK:1   ERROR:-1
    my $problems = '';                  # string for error messages for this order
    my @records = ();                   # one record for the title and one for each item
    my ($titeldata, $isbnean) = ("", "");
    
    # variables for result structure
    my @idPaarListe = ();

    # priority of title sources to be checked:
    # In any case:
    #     Search title in local database using ekzArtikelNr; if not found, search for isbn / isbn13; if not found, search for issn / ismn / ean.
    #     If title found, only the items have to be added.
    #
    # Otherwise search in different title sources in the sequence stored in system preference 'ekzTitleDataServicesSequence':
    #   title source '_LMSC':
    #     Search title in LMSPool using ekzArtikelNr; if not found, search for isbn / isbn13; if not found, search for issn / ismn / ean.
    #   title source '_EKZWSMD':
    #     Send a query to the ekz title information web service ('MedienDaten') using ekzArtikelNr.
    #   title source '_WS':
    #     Use the sparse title data from the BestellinfoElement (tag titelInfo) for creating a title entry.
    #   other title source:
    #     The name of the title source is used as a name of a Z39/50 target with z3950servers.servername; a z39/50 query is sent to this target.
    #
    #   With data from one of these alternatives a title record has to be created in Koha, and an item record for each ordered copy.

    $titleHits->{'count'} = 0;
    $titleHits->{'records'} = ();

    # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLocalDB($reqParamTitelInfo, 1);
print STDERR "BestellInfoElement::handleTitelBestellInfo() from local DB titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
    if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
        $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
    }

    my @titleSourceSequence = split('\|',$titleSourceSequence);
    foreach my $titleSource (@titleSourceSequence) {
print STDERR "BestellInfoElement::handleTitelBestellInfo() titleSource:$titleSource:\n" if $debugIt;
        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
            last;    # title data have been found in lastly tested title source
        }

        if ( $titleSource eq '_LMSC' ) {
            # search title in LMSPool
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLMSPool($reqParamTitelInfo);
print STDERR "BestellInfoElement::handleTitelBestellInfo() from LMS Pool titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
        } elsif ( $titleSource eq '_EKZWSMD' ) {
            # send query to the ekz title information web service
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromEkzWsMedienDaten($reqParamTitelInfo->{'ekzArtikelNr'});
print STDERR "BestellInfoElement::handleTitelBestellInfo() from ekz Webservice titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
        } elsif ( $titleSource eq '_WS' ) {
            # use sparse title data from the BestellinfoElement
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->createTitleFromFields($reqParamTitelInfo);    # creates marc data, not a biblio DB record
print STDERR "BestellInfoElement::handleTitelBestellInfo() from sent titelinfo fields titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
        } else {
            # search title in in the Z39.50 target with z3950servers.servername=$titleSource
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromZ3950Target($titleSource,$reqParamTitelInfo);
print STDERR "BestellInfoElement::handleTitelBestellInfo() from z39.50 search on target:" . $titleSource . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": \n" if $debugIt;
        }
    }


    if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
        if ( $biblionumber == 0 ) {    # title data have been found in one of the sources
            # Create a biblio record in Koha and enrich it with values of the hits found in one of the title sources.
            # It is sufficient to evaluate the first hit.

            $titleHits->{'records'}->[0]->insert_fields_ordered(MARC::Field->new('035',' ',' ','a' => "(EKZImport)$reqEkzBestellNr"));    # system controll number
            if( $ekzWsHideOrderedTitlesInOpac ) {
                $titleHits->{'records'}->[0]->insert_fields_ordered(MARC::Field->new('942',' ',' ','n' => 1));           # hide this title in opac
            }
            ($biblionumber,$biblioitemnumber) = C4::Biblio::AddBiblio($titleHits->{'records'}->[0],'');
print STDERR "BestellInfoElement::handleTitelBestellInfo() new biblionumber:",$biblionumber,": biblioitemnumber:",$biblioitemnumber,": \n" if $debugIt;
            if ( defined $biblionumber && $biblionumber > 0 ) {
                $biblioInserted = 1;
                # positive message for log
                $importresult = 1;
                $importedTitlesCount += 1;
            } else {
                # negative message for log
                $problems .= "\n" if ( $problems );
                $problems .= "ERROR: Import der Titeldaten für ekz Artikel: " . $reqParamTitelInfo->{'ekzArtikelNr'} . " wurde abgewiesen.\n";
                $importresult = -1;
                $importerror = 1;
            }
        } else {    # title record has been found in local database
            $biblioExisting = 1;
            # positive message for log
            $importresult = 2;
            $importedTitlesCount += 0;
        }
        # add result of adding biblio to log email
        ($titeldata, $isbnean) = C4::External::EKZ::lib::EkzKohaRecords->getShortISBD($titleHits->{'records'}->[0]);
        push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $importerror, 1];
    }

    # now add the acquisition_import and acquisition_import_objects record  for the title
    if ( $biblioExisting || $biblioInserted ) {

        # Insert a record into table acquisition_import representing the title data of the BestellInfo <titelInfo>.
        my $insParam = {
            #id => 0, # AUTO
            vendor_id => "ekz",
            object_type => "order",
            object_number => $reqEkzBestellNr,
            object_date => DateTime::Format::MySQL->format_datetime($reqEkzBestellDatum),    # in local time_zone
            rec_type => "title",
            object_item_number => $reqParamTitelInfo->{'ekzArtikelNr'},
            processingstate => "ordered",
            processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
            #payload => NULL, # NULL
            object_reference => $acquisitionImportIdBestellInfo
        };
        my $acquisitionImportTitle = Koha::AcquisitionImport::AcquisitionImports->new();
        my $acquisitionImportTitleRS = $acquisitionImportTitle->_resultset()->create($insParam);
        $acquisitionImportIdTitle = $acquisitionImportTitleRS->get_column('id');
print STDERR "BestellInfoElement::handleTitelBestellInfo() acquisitionImportTitleRS->{_column_data}:", Dumper($acquisitionImportTitleRS->{_column_data}), ":\n" if $debugIt;
print STDERR "BestellInfoElement::handleTitelBestellInfo() acquisitionImportIdTitle:", $acquisitionImportIdTitle, ":\n" if $debugIt;

        # Insert a record into table acquisition_import_object representing the Koha title data.
        $insParam = {
            #id => 0, # AUTO
            acquisition_import_id => $acquisitionImportIdTitle,
            koha_object => "title",
            koha_object_id => $biblionumber . ''
        };
        my $titleImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
        my $titleImportObjectRS = $titleImportObject->_resultset()->create($insParam);

print STDERR "BestellInfoElement::handleTitelBestellInfo() titleImportObjectRS->{_column_data}:", Dumper($titleImportObjectRS->{_column_data}), ":\n" if $debugIt;

        # now add the items data for the new or found biblionumber
        my $itemCount = scalar @{$exemplare};
        for ( my $i = 0; $i < $itemCount; $i++ ) {
            my $ekzExemplarID = (defined $exemplare->[$i]->{'ekzExemplarID'} && length($exemplare->[$i]->{'ekzExemplarID'}) > 0) ? $exemplare->[$i]->{'ekzExemplarID'} : "ekzExemplarID not set";
            my $exemplarcount = $exemplare->[$i]->{'konfiguration'}->{'anzahl'};
            print STDERR "BestellInfoElement::handleTitelBestellInfo() exemplar itemCount $itemCount loop $i exemplarcount $exemplarcount\n" if $debugIt;

        # look for XML <ExemplarFeldElement> blocks within current <exemplar> block
            my $exemplarfelderArrayRef = [];    # using ref to empty array if there are sent no ExemplarFeldElement blocks
            # if there is sent only one ExemplarFeldElement block, it is delivered here as hash ref
            if ( ref($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'}) eq 'HASH' ) {
                $exemplarfelderArrayRef = [ $exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'} ]; # ref to anonymous array containing the single hash reference
            } else {
                # if there are sent more than one ExemplarFeldElement blocks, they are delivered here as array ref
                if ( ref($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'}) eq 'ARRAY' ) {
                    $exemplarfelderArrayRef = $exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'}; # ref to deserialized array containing the hash references
                }
            }
print STDERR "BestellInfoElement::handleTitelBestellInfo() HTTP request ExemplarFeldElement array:",@$exemplarfelderArrayRef," AnzElem:", scalar @$exemplarfelderArrayRef,":\n" if $debugIt;

            my $exemplarfeldercount = scalar @$exemplarfelderArrayRef;
            my $zweigstellenname = '';
print STDERR "BestellInfoElement::handleTitelBestellInfo() HTTP exemplarfeldercount:",$exemplarfeldercount, ":\n" if $debugIt;
            for ( my $j = 0; $j < $exemplarfeldercount; $j++ ) {
                print STDERR "BestellInfoElement::handleTitelBestellInfo() HTTP request ExemplarFeldElement name:", $exemplarfelderArrayRef->[$j]->{'name'}, ": inhalt:", $exemplarfelderArrayRef->[$j]->{'inhalt'},":\n" if $debugIt;
                if ( $exemplarfelderArrayRef->[$j]->{'name'} eq 'zweigstelle' ) {
                    $zweigstellenname = $exemplarfelderArrayRef->[$j]->{'inhalt'};
                    $zweigstellenname =~ s/^\s+|\s+$//g; # trim spaces
                }
            }
            if ( length($zweigstellenname) == 0 && defined $homebranch && length($homebranch) > 0 ) {
                    $zweigstellenname = $homebranch;
            }
print STDERR "BestellInfoElement::handleTitelBestellInfo() zweigstelle:", $zweigstellenname, ":\n" if $debugIt;

            for ( my $j = 0; $j < $exemplarcount; $j++ ) {
                my $problems = '';              # string for accumulating error messages for this order
                my $item_hash;

                $processedItemsCount += 1;

                if ( &C4::External::EKZ::lib::EkzKohaRecords::checkbranchcode($zweigstellenname) ) {
                    $item_hash->{homebranch} = $zweigstellenname;
                } else {
                    $item_hash->{homebranch} = '';
                }
                $item_hash->{booksellerid} = 'ekz';
                $item_hash->{price} = $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'gesamtpreis'};             # yes, [$i], not [$j]!
                $item_hash->{replacementprice} = $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'gesamtpreis'};
                
                # finally add the next items record
                my ( $biblionumberItem, $biblioitemnumberItem, $itemnumber ) = C4::Items::AddItem($item_hash, $biblionumber);

                # collect title controlnumbers for HTML URL to Koha records of handled titles
                my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                my $importId = '(ControlNumber)' . $tmp_cn . '(ControlNrId)' . $tmp_cna;    # if cna = 'DE-Rt5' then this cn is the ekz article number
                $importIds{$importId} = $itemnumber;
print STDERR "BestellInfoElement::genKohaRecords() importedItemsCount:$importedItemsCount; set next importIds:", $importId, ":\n" if $debugIt;

                if ( defined $itemnumber && $itemnumber > 0 ) {

                    # configurable items record field initialization via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered")
                    # e.g. setting the 'item ordered' state in items.notforloan
                    if ( defined($ekzWebServicesSetItemSubfieldsWhenOrdered) && length($ekzWebServicesSetItemSubfieldsWhenOrdered) > 0 ) {
                        my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenOrdered;
                        if ( @affects ) {
                            my $frameworkcode = GetFrameworkCode($biblionumber);
                            my ( $itemfield ) = GetMarcFromKohaField( 'items.itemnumber', $frameworkcode );
                            my $item = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
                            for my $affect ( @affects ) {
                                my ( $sf, $v ) = split('=', $affect, 2);
                                foreach ( $item->field($itemfield) ) {
                                        $_->update( $sf => $v );
                                }
                            }
                            C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber );
                        }
                    }

                    # Insert a record into table acquisition_import representing the item data of BestellInfo.
                    my $insParam = {
                        #id => 0, # AUTO
                        vendor_id => "ekz",
                        object_type => "order",
                        object_number => $reqEkzBestellNr,
                        object_date => DateTime::Format::MySQL->format_datetime($reqEkzBestellDatum),    # in local time_zone
                        rec_type => "item",
                        object_item_number => $ekzExemplarID . '',
                        processingstate => "ordered",
                        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                        #payload => NULL, # NULL
                        object_reference => $acquisitionImportIdTitle
                    };
                    my $acquisitionImportItem = Koha::AcquisitionImport::AcquisitionImports->new();
                    my $acquisitionImportItemRS = $acquisitionImportItem->_resultset()->create($insParam);
                    my $acquisitionImportIdItem = $acquisitionImportItemRS->get_column('id');
print STDERR "BestellInfoElement::handleTitelBestellInfo() acquisitionImportItemRS->{_column_data}:", Dumper($acquisitionImportItemRS->{_column_data}), ":\n" if $debugIt;

                    # Insert a record into table acquisition_import_object representing the Koha item data.
                    $insParam = {
                        #id => 0, # AUTO
                        acquisition_import_id => $acquisitionImportIdItem,
                        koha_object => "item",
                        koha_object_id => $itemnumber . ''
                    };
                    my $itemImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                    my $itemImportObjectRS = $itemImportObject->_resultset()->create($insParam);
print STDERR "BestellInfoElement::BestellInfoElement() itemImportObjectRS->{_column_data}:", Dumper($itemImportObjectRS->{_column_data}), ":\n" if $debugIt;

                    # add to response
                    my %idPaar = ();
                    $idPaar{'ekzExemplarID'} = $ekzExemplarID;
                    $idPaar{'lmsExemplarID'} = $itemnumber;
                    push @idPaarListe, \%idPaar;

                    # positive message for log
                    $importresult = 1;
                    $importedItemsCount += 1;
                    if ( $biblioExisting > 0 && $updatedTitlesCount == 0 ) {
                        $updatedTitlesCount = 1;
                    }
                } else {
                    # negative message for log
                    $problems .= "\n" if ( $problems );
                    $problems .= "ERROR: Import der Exemplardaten für ekz Exemplar-ID: $ekzExemplarID wurde abgewiesen.\n";
                    $importresult = -1;
                    $importerror = 1;
                }
                # add result of adding item to log email
                my ($titeldata, $isbnean) = ($itemnumber, '');
print STDERR "BestellInfoElement::handleTitelBestellInfo() item titeldata:", $titeldata, ":\n" if $debugIt;
                push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $importerror, 2];
            }
        }
    }    # End $biblioExisting || $biblioInserted

    # create @actionresult message for log email, representing 1 title with all its processed items
    my @actionresult = ();
    push @actionresult, [ 'insertRecords', 0, "X", "Y", $processedTitlesCount, $importedTitlesCount, $updatedTitlesCount, $processedItemsCount, $importedItemsCount, 0, \@records];
    $$retactionresult = \@actionresult;
print STDERR "BestellInfoElement::handleTitelBestellInfo() actionresult:", @actionresult, ":\n" if $debugIt;
print STDERR "BestellInfoElement::handleTitelBestellInfo() actionresult[0]:", @{$actionresult[0]}, ":\n" if $debugIt;
#####print STDERR "BestellInfoElement::handleTitelBestellInfo() actionresult[0]->[10]->[0]:", @{$actionresult[0]->[10]->[0]}, ":\n" if $debugIt;
print STDERR "BestellInfoElement::handleTitelBestellInfo() retactionresult:", $retactionresult, ":\n" if $debugIt;

    return (@idPaarListe);
}

1;
