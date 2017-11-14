package C4::External::EKZ::EkzWsStandingOrder;

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
use Exporter;

use C4::Items qw(AddItem);
use C4::Branch qw(GetBranches);
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::External::EKZ::lib::EkzWebServices;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::lib::EkzKohaRecords;

our @ISA = qw(Exporter);
our @EXPORT = qw( getCurrentYear readStoFromEkzWsStoList genKohaRecords );


my $debugIt = 1;


###################################################################################################
# get the current year
###################################################################################################
sub getCurrentYear {
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    return 1900 + $year;
}

###################################################################################################
# read standing orders using ekz web service 'StoList' (overview data)
###################################################################################################
sub readStoFromEkzWsStoList {
    my $selJahr = shift;
    my $selStoId = shift;
	my $selMitTitel = shift;
    my $selMitKostenstellen = shift;
	my $selMitEAN = shift;
	my $selStatusUpdate = shift;
	my $selErweitert = shift;
    my $refStoListElement = shift;    # for storing the StoListElement of the SOAP request body

    my $result = ();    # hash reference
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() selJahr:", $selJahr, ": selStoId:", defined($selStoId) ? $selStoId : 'undef', ": selMitTitel:", defined($selMitTitel) ? $selMitTitel : 'undef', 
                                ": selMitKostenstellen:", defined($selMitKostenstellen) ? $selMitKostenstellen : 'undef', ": selMitEAN:", defined($selMitEAN) ? $selMitEAN : 'undef', 
                                ": selStatusUpdate:", defined($selStatusUpdate) ? $selStatusUpdate : 'undef', ": selErweitert:", defined($selErweitert) ? $selErweitert : 'undef', ":\n" if $debugIt;
    
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() \$refStoListElement:", $refStoListElement, ":\n" if $debugIt;
print STDERR Dumper($refStoListElement) if $debugIt;
	
	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsStoList($selJahr, $selStoId, $selMitTitel, $selMitKostenstellen, $selMitEAN, $selStatusUpdate, $selErweitert,$refStoListElement);
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() result->{'standingOrderCount'}:$result->{'standingOrderCount'}:\n" if $debugIt;
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() result->{'standingOrderRecords'}:$result->{'standingOrderRecords'}:\n" if $debugIt;

    return $result;
}

###################################################################################################
# go through the titles contained in the response for the selected standing order, 
# generate title data and item data as required
###################################################################################################
sub genKohaRecords {
    my ($messageID, $stoListElement, $stoWithNewState, $lastRunDate, $todayDate) = @_;

    my $ekzBestellNr = '';
    my $lastRunDateIsSet = 0;
    my $dbh = C4::Context->dbh;

    # variables for email log
    my @logresult = ();
    my @actionresult = ();
    my $importerror = 0;          # flag if an insert error happened
    my %importIds = ();
    my $dt = DateTime->now;
    $dt->set_time_zone( 'Europe/Berlin' );
    my ($message, $subject, $haserror) = ('','',0);
    
    print STDERR "ekzWsStoList::genKohaRecords() Start;  messageID:$messageID stoID:$stoWithNewState->{'stoID'}: stoWithNewState->{'titelCount'}:$stoWithNewState->{'titelCount'}: lastRunDate:$lastRunDate: todayDate:$todayDate:\n" if $debugIt;

    my $zweigstellenname = '';
    my $homebranch = C4::Context->preference("ekzWebServicesDefaultBranch");
    $homebranch =~ s/^\s+|\s+$//g; # trim spaces
    if ( defined $homebranch && length($homebranch) > 0 ) {
        $zweigstellenname = $homebranch;
    }
    my $titleSourceSequence = C4::Context->preference("ekzTitleDataServicesSequence");
    if ( !defined($titleSourceSequence) ) {
        $titleSourceSequence = '_LMSC|_EKZWSMD|DNB|_WS';
    }
    my $ekzWebServicesHideOrderedTitlesInOpac = C4::Context->preference("ekzWebServicesHideOrderedTitlesInOpac");
    my $ekzWebServicesSetItemSubfieldsWhenOrdered = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered");
    my $ekzWsHideOrderedTitlesInOpac = 1;    # policy: hide title if not explictly set to 'show'
    if( defined($ekzWebServicesHideOrderedTitlesInOpac) && 
        length($ekzWebServicesHideOrderedTitlesInOpac) > 0 &&
        $ekzWebServicesHideOrderedTitlesInOpac == 0 ) {
            $ekzWsHideOrderedTitlesInOpac = 0;
    }
    if ( defined($lastRunDate) && $lastRunDate =~ /^\d\d\d\d-\d\d-\d\d$/ ) {    # format:yyyy-mm-dd
        $lastRunDateIsSet = 1;
    }
    # insert/update the order message if at least one item has got state 10 or 20 or 99 ( 99 only if lastRunDate is set)
    my $insOrUpd = 0;

    my $minStatusDatum = '9999-12-31';
    foreach my $titel ( @{$stoWithNewState->{'titelRecords'}} ) {
        my $statusDatum = substr($titel->{'statusDatum'},0,10);    # format yyyy-mm-ddT00:00:00.000 to yyyy-mm-dd
        if ( $minStatusDatum gt $statusDatum ) {
            $minStatusDatum = $statusDatum;
        }
        if ( $lastRunDateIsSet ) {
            if ( ($titel->{'status'} == 10 || $titel->{'status'} == 20 || $titel->{'status'} == 99) &&    # 'vorbreitet' || 'in nächster Lieferung' || 'Bereits geliefert' (i.e. 'prepared' || 'included in next delivery' || 'delivered')
                $statusDatum ge $lastRunDate && 
                $statusDatum lt $todayDate ) {
                    $insOrUpd = 1;    # the acquisition_import message record must be inserted or updated
                    last;
            }
        } else {
            if ( ($titel->{'status'} == 10 || $titel->{'status'} == 20) &&    # 'vorbreitet' || 'in nächster Lieferung' (i.e. 'prepared' || 'included in next delivery'
                $statusDatum lt $todayDate ) {
                    $insOrUpd = 1;    # the acquisition_import message record must be inserted or updated
                    last;
            }
        }
    }
    my $bestellDatum = DateTime->new( year => substr($minStatusDatum,0,4), month => substr($minStatusDatum,5,2), day => substr($minStatusDatum,8,2), time_zone => 'local' );
    my $dateTimeNow = DateTime->now(time_zone => 'local');
print STDERR "ekzWsStoList::genKohaRecords() insOrUpd:$insOrUpd:\n" if $debugIt;
    if ( $insOrUpd ) {

        # Insert/update record in table acquisition_import representing the standing order request.
        $dbh = C4::Context->dbh;
        $dbh->{AutoCommit} = 0;

        $ekzBestellNr = 'stoID' . $stoWithNewState->{'stoID'};    # StoList response contains no order number, so we create this dummy order number

        my $selParam = {
            vendor_id => "ekz",
            object_type => "order",
            object_number => $ekzBestellNr,
            rec_type => "message",
            processingstate => "ordered"
        };
        my $insParam = {
            #id => 0, # AUTO
            vendor_id => "ekz",
            object_type => "order",
            object_number => $ekzBestellNr,
            object_date => DateTime::Format::MySQL->format_datetime($bestellDatum),
            rec_type => "message",
            #object_item_number => "", # NULL
            processingstate => "ordered",
            processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
            payload => $stoListElement,
            #object_reference => undef # NULL
        };
        my $updParam = {
            processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
            payload => $stoListElement
        };
        my $acquisitionImportMessage = Koha::AcquisitionImport::AcquisitionImports->new();
        $acquisitionImportMessage = $acquisitionImportMessage->upd_or_ins($selParam, $updParam, $insParam);
#print STDERR "ekzWsStoList::genKohaRecords()) acquisitionImportMessage:", Dumper($acquisitionImportMessage), ":\n" if $debugIt;
print STDERR "ekzWsStoList::genKohaRecords() acquisitionImportMessage->_resultset()->{'_column_data'}:", Dumper($acquisitionImportMessage->_resultset()->{'_column_data'}), ":\n" if $debugIt;

        foreach my $titel ( @{$stoWithNewState->{'titelRecords'}} ) {
            print STDERR "ekzWsStoList::genKohaRecords() titel ekzArtikelNr:$titel->{'ekzArtikelNummer'}: isbn:$titel->{'isbn'}: status:$titel->{'status'}: statusDatum:$titel->{'statusDatum'}:\n" if $debugIt;
            if ( !(($lastRunDateIsSet &&
                    ($titel->{'status'} == 10 || $titel->{'status'} == 20 || $titel->{'status'} == 99) &&    # 'vorbreitet' || 'in nächster Lieferung' || 'Bereits geliefert' (i.e. 'prepared' || 'included in next delivery' || 'delivered')
                    $titel->{'statusDatum'} ge $lastRunDate && 
                    $titel->{'statusDatum'} lt $todayDate
                   ) ||
                   (!$lastRunDateIsSet &&
                    ($titel->{'status'} == 10 || $titel->{'status'} == 20) &&    # 'vorbreitet' || 'in nächster Lieferung (i.e. 'prepared' || 'included in next delivery')
                    $titel->{'statusDatum'} lt $todayDate
                   )
                  )
               ) {
                next;
            }

            my $titleHits = { 'count' => 0, 'records' => [] };
            my $biblioExisting = 0;
            my $biblioInserted = 0;
            my $biblionumber = 0;
            my $biblioitemnumber;

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

            my $reqParamTitelInfo = ();
            $reqParamTitelInfo->{'ekzArtikelArt'}  = $stoWithNewState->{'artikelArt'};
            $reqParamTitelInfo->{'ekzArtikelNr'} = $titel->{'ekzArtikelNummer'};
            $reqParamTitelInfo->{'isbn'} = '';
            $reqParamTitelInfo->{'isbn13'} = $titel->{'isbn'};    # field isbn transfers ISBN13
            $reqParamTitelInfo->{'ean'} = $titel->{'ean'};
            $reqParamTitelInfo->{'author'} = $titel->{'autor'};   # autor is german spelling of author
            $reqParamTitelInfo->{'titel'} = $titel->{'titel'};
            $reqParamTitelInfo->{'preis'} = $titel->{'preis'};
print STDERR "ekzWsStoList::genKohaRecords() reqParamTitelInfo->{'ekzArtikelNr'}:",$reqParamTitelInfo->{'ekzArtikelNr'},": \n" if $debugIt;

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

            # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLocalDB($reqParamTitelInfo, 1);
print STDERR "ekzWsStoList::genKohaRecords() from local DB titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
            if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
            }

            my @titleSourceSequence = split('\|',$titleSourceSequence);
            foreach my $titleSource (@titleSourceSequence) {
                if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                    last;    # title data have been found in lastly tested title source
                }
print STDERR "ekzWsStoList::genKohaRecords() titleSource:$titleSource:\n" if $debugIt;

                if ( $titleSource eq '_LMSC' ) {
                    # search title in LMSPool
                    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLMSPool($reqParamTitelInfo);
print STDERR "ekzWsStoList::genKohaRecords() from LMS Pool titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                } elsif ( $titleSource eq '_EKZWSMD' ) {
                    # send query to the ekz title information web service
                    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromEkzWsMedienDaten($reqParamTitelInfo->{'ekzArtikelNr'});
print STDERR "ekzWsStoList::genKohaRecords() from ekz Webservice titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                } elsif ( $titleSource eq '_WS' ) {
                    # use sparse title data from the StoListElement
                    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->createTitleFromFields($reqParamTitelInfo);    # creates marc data, not a biblio DB record
print STDERR "ekzWsStoList::genKohaRecords() from sent titel fields:",$titleHits->{'count'},": \n" if $debugIt;
                } else {
                    # search title in the Z39.50 target with z3950servers.servername=$titleSource
                    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromZ3950Target($titleSource,$reqParamTitelInfo);
print STDERR "ekzWsStoList::genKohaRecords() from z39.50 search on target:" . $titleSource . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": \n" if $debugIt;
                }
            }


            if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                if ( $biblionumber == 0 ) {    # title data have been found in one of the sources
                    # Create a biblio record in Koha and enrich it with values of the hits found in one of the title sources.
                    # It is sufficient to evaluate the first hit.
                    $titleHits->{'records'}->[0]->insert_fields_ordered(MARC::Field->new('035',' ',' ','a' => "(EKZImport)$ekzBestellNr"));    # system controll number
                    if( $ekzWsHideOrderedTitlesInOpac ) {
                        $titleHits->{'records'}->[0]->insert_fields_ordered(MARC::Field->new('942',' ',' ','n' => 1));           # hide this title in opac
                    }
                    ($biblionumber,$biblioitemnumber) = C4::Biblio::AddBiblio($titleHits->{'records'}->[0],'');
print STDERR "ekzWsStoList::genKohaRecords() new biblionumber:",$biblionumber,": biblioitemnumber:",$biblioitemnumber,": \n" if $debugIt;
                    if ( defined $biblionumber && $biblionumber > 0 ) {
                        $biblioInserted = 1;
                        # positive message for log
                        $importresult = 1;
                        $importedTitlesCount += 1;
                    } else {
                        # negative message for log
                        $problems .= "\n" if ( $problems );
                        $problems .= "ERROR: Import der Titeldaten für EKZ Artikel: $reqParamTitelInfo->{'ekzArtikelNr'} wurde abgewiesen.\n";
                        $importresult = -1;
                        $importerror = 1;
                    }
                } else {    # title record has been found in local database
                    $biblioExisting = 1;
                    # positive message for log
                    $importresult = 2;
                    $importedTitlesCount += 0;
                }
            }

            # now add the acquisition_import and acquisition_import_objects record  for the title
            my $dateTimeNow = DateTime->now(time_zone => 'local');
            if ($biblioExisting || $biblioInserted ) {

                # Insert a record into table acquisition_import representing the title data of the standing order.
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_number => $ekzBestellNr,
                    rec_type => "title",
                    object_item_number => $reqParamTitelInfo->{'ekzArtikelNr'} . '',
                    processingstate => "ordered"
                };
                my $insParam = {
                    #id => 0, # AUTO
                    vendor_id => "ekz",
                    object_type => "order",
                    object_number => $ekzBestellNr,
                    object_date => DateTime::Format::MySQL->format_datetime($bestellDatum),
                    rec_type => "title",
                    object_item_number => $reqParamTitelInfo->{'ekzArtikelNr'} . '',
                    processingstate => "ordered",
                    processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),
                    #payload => NULL, # NULL
                    object_reference => $acquisitionImportMessage->_resultset()->get_column('id')
                };
print STDERR "ekzWsStoList::genKohaRecords() selParam:", Dumper($selParam), ":\n" if $debugIt;

                my $acquisitionImportIdTitle;
                my $acquisitionImportTitle = Koha::AcquisitionImport::AcquisitionImports->new();
                my $hit = $acquisitionImportTitle->_resultset()->find( $selParam );
print STDERR "ekzWsStoList::genKohaRecords() ref(acquisitionImportTitle):", ref($acquisitionImportTitle), ": ref(hit):", ref($hit), ":\n" if $debugIt;
                if ( defined($hit) ) {
print STDERR "ekzWsStoList::genKohaRecords() hit->{_column_data}:", Dumper($hit->{_column_data}), ":\n";
                    my $mess = sprintf("The ekz article number '%s' has already been used in the standing order %s at %s. Processing skipped for this title in order to avoid repeated item record creation.\n",$reqParamTitelInfo->{'ekzArtikelNr'}, $stoWithNewState->{'stoID'}, $hit->get_column('processingtime')) if $debugIt;
                    carp $mess;

                    next;    # The ekz article number has already been used in this standing. Skip processing of this title in order to avoid repeated item record creation.

                } else {
                    my $schemaResultAcquitionImport = $acquisitionImportTitle->_resultset()->create($insParam);
                    $acquisitionImportIdTitle = $schemaResultAcquitionImport->get_column('id');
print STDERR "ekzWsStoList::genKohaRecords() Dumper(schemaResultAcquitionImport->{_column_data}):", Dumper($schemaResultAcquitionImport->{_column_data}), ":\n" if $debugIt;
print STDERR "ekzWsStoList::genKohaRecords() acquisitionImportIdTitle:", $acquisitionImportIdTitle, ":\n" if $debugIt;
                }

                # Insert a record into table acquisition_import_object representing the Koha title data.
                $insParam = {
                    #id => 0, # AUTO
                    acquisition_import_id => $acquisitionImportIdTitle,
                    koha_object => "title",
                    koha_object_id => $biblionumber . ''
                };
                my $titleImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                my $titleImportObjectRS = $titleImportObject->_resultset()->create($insParam);
print STDERR "ekzWsStoList::genKohaRecords() titleImportObjectRS->{_column_data}:", Dumper($titleImportObjectRS->{_column_data}), ":\n" if $debugIt;

                # add result of adding biblio to log email
                ($titeldata, $isbnean) = C4::External::EKZ::lib::EkzKohaRecords->getShortISBD($titleHits->{'records'}->[0]);
                push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $importerror, 1];


                # now add the items data for the new or found biblionumber
                my $ekzExemplarID = $ekzBestellNr . '-' . $reqParamTitelInfo->{'ekzArtikelNr'};    # StoList response contains no item number, so we create this dummy item number
                my $exemplarcount = $titel->{'anzahl'};
                print STDERR "ekzWsStoList::genKohaRecords() exemplar ekzExemplarID:$ekzExemplarID: exemplarcount:$exemplarcount:\n" if $debugIt;

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
                    $item_hash->{price} = $titel->{'preis'};
                    $item_hash->{replacementprice} = $titel->{'preis'};
                    
                    my ( $biblionumberItem, $biblioitemnumberItem, $itemnumber ) = C4::Items::AddItem($item_hash, $biblionumber);
                    $importIds{'(ControlNumber)' . $titleHits->{'records'}->[0]->field("001")->data()} = $itemnumber;    # maybe this cn is the ekz article number

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

                        # Insert a record into table acquisition_import representing item data of the standing order.
                        my $insParam = {
                            #id => 0, # AUTO
                            vendor_id => "ekz",
                            object_type => "order",
                            object_number => $ekzBestellNr,
                            object_date => DateTime::Format::MySQL->format_datetime($bestellDatum),
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
print STDERR "ekzWsStoList::genKohaRecords() acquisitionImportItemRS->{_column_data}:", Dumper($acquisitionImportItemRS->{_column_data}), ":\n" if $debugIt;

                        # Insert a record into table acquisition_import_object representing the Koha item data.
                        $insParam = {
                            #id => 0, # AUTO
                            acquisition_import_id => $acquisitionImportIdItem,
                            koha_object => "item",
                            koha_object_id => $itemnumber . ''
                        };
                        my $itemImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                        my $itemImportObjectRS = $itemImportObject->_resultset()->create($insParam);
print STDERR "ekzWsStoList::genKohaRecords() itemImportObjectRS->{_column_data}:", Dumper($itemImportObjectRS->{_column_data}), ":\n" if $debugIt;

                        # positive message for log email
                        $importresult = 1;
                        $importedItemsCount += 1;
                        if ( $biblioExisting > 0 && $updatedTitlesCount == 0 ) {
                            $updatedTitlesCount = 1;
                        }
                    } else {
                        # negative message for log email
                        $problems .= "\n" if ( $problems );
                        $problems .= "ERROR: Import der Exemplardaten für EKZ Exemplar-ID: $ekzExemplarID wurde abgewiesen.\n";
                        $importresult = -1;
                        $importerror = 1;
                    }
                    # add result of adding item to log email
                    my ($titeldata, $isbnean) = ($itemnumber, '');
print STDERR "ekzWsStoList::genKohaRecords() item titeldata:", $titeldata, ":\n" if $debugIt;
                    push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $importerror, 2];
                }
            }

            # create @actionresult message for log email, representing 1 title with all its processed items
            my @actionresultTit = ( 'insertRecords', 0, "X", "Y", $processedTitlesCount, $importedTitlesCount, $updatedTitlesCount, $processedItemsCount, $importedItemsCount, 0, \@records );
print STDERR "ekzWsStoList::genKohaRecords() actionresultTit:", @actionresultTit, ":\n" if $debugIt;
print STDERR "ekzWsStoList::genKohaRecords() actionresultTit->[10]->[0]:", @{$actionresultTit[10]->[0]}, ":\n" if $debugIt;
            push @actionresult, \@actionresultTit;

        }

        # create @logresult message for log email, representing all titles of the StoList $stoWithNewState with all their processed items
        push @logresult, ['StoList', $messageID, \@actionresult];
print STDERR "Dumper(\\\@logresult): ####################################################################################################################\n" if $debugIt;
print STDERR Dumper(\@logresult) if $debugIt;


        #$dbh->rollback;    # roll it back for TEST XXXWH

        # commit the complete standing order update (only as a single transaction)
        $dbh->commit();
        $dbh->{AutoCommit} = 1;
    
        if ( scalar(@logresult) > 0 ) {
            my @importIds = keys %importIds;
            ($message, $subject, $haserror) = C4::External::EKZ::lib::EkzKohaRecords->createProcessingMessageText(\@logresult, "headerTEXT", $dt, \@importIds, $ekzBestellNr);  # we use ekzBestellNr as part of importID in MARC field 025.a: (EKZImport)$importIDs->[0]
            C4::External::EKZ::lib::EkzKohaRecords->sendMessage($message, $subject);
        }
    }

    return 1;
}

1;
