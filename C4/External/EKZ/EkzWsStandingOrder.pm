package C4::External::EKZ::EkzWsStandingOrder;

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
use Exporter;

use C4::Items qw(AddItem);
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::lib::EkzKohaRecords;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use C4::Acquisition;

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
    my $ekzCustomerNumber = shift;
    my $selJahr = shift;
    my $selStoId = shift;
	my $selMitTitel = shift;
    my $selMitKostenstellen = shift;
	my $selMitEAN = shift;
	my $selStatusUpdate = shift;
	my $selErweitert = shift;
    my $refStoListElement = shift;    # for storing the StoListElement of the SOAP request body

    my $result = ();    # hash reference
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() ekzCustomerNumber:", $ekzCustomerNumber, ": selJahr:", $selJahr, ": selStoId:", defined($selStoId) ? $selStoId : 'undef', ": selMitTitel:", defined($selMitTitel) ? $selMitTitel : 'undef', 
                                ": selMitKostenstellen:", defined($selMitKostenstellen) ? $selMitKostenstellen : 'undef', ": selMitEAN:", defined($selMitEAN) ? $selMitEAN : 'undef', 
                                ": selStatusUpdate:", defined($selStatusUpdate) ? $selStatusUpdate : 'undef', ": selErweitert:", defined($selErweitert) ? $selErweitert : 'undef', ":\n" if $debugIt;
    
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() \$refStoListElement:", $refStoListElement, ":\n" if $debugIt;
print STDERR Dumper($refStoListElement) if $debugIt;
	
	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsStoList($ekzCustomerNumber, $selJahr, $selStoId, $selMitTitel, $selMitKostenstellen, $selMitEAN, $selStatusUpdate, $selErweitert,$refStoListElement);
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() result->{'standingOrderCount'}:$result->{'standingOrderCount'}:\n" if $debugIt;
print STDERR "ekzWsStoList::readStoFromEkzWsStoList() result->{'standingOrderRecords'}:$result->{'standingOrderRecords'}:\n" if $debugIt;

    return $result;
}

###################################################################################################
# go through the titles contained in the response for the selected standing order, 
# generate title data and item data as required
###################################################################################################
sub genKohaRecords {
    my ($ekzCustomerNumber, $messageID, $stoListElement, $stoWithNewState, $lastRunDate, $todayDate) = @_;
    my $ekzKohaRecord = C4::External::EKZ::lib::EkzKohaRecords->new();

    my $ekzBestellNr = '';
    my $lastRunDateIsSet = 0;
    my $dbh = C4::Context->dbh;
    my $acquisitionError = 0;
    my $basketno = -1;
    my $basketgroupid = undef;

    # variables for email log
    my @logresult = ();
    my @actionresult = ();
    my $importerror = 0;          # flag if an insert error happened
    my %importIds = ();
    my $dt = DateTime->now;
    $dt->set_time_zone( 'Europe/Berlin' );
    my ($message, $subject, $haserror) = ('','',0);
    my $cntTitlesHandled = 0;
    my $cntItemsHandled = 0;
    
    print STDERR "ekzWsStoList::genKohaRecords() Start;  ekzCustomerNumber:$ekzCustomerNumber messageID:$messageID stoID:$stoWithNewState->{'stoID'}: stoWithNewState->{'titelCount'}:$stoWithNewState->{'titelCount'}: lastRunDate:$lastRunDate: todayDate:$todayDate:\n" if $debugIt;

    my $zweigstellencode = '';
    # XXXWH hau wech (OLD) my $homebranch = C4::External::EKZ::lib::EkzWebServices->new()->getEkzWebServicesDefaultBranch($ekzCustomerNumber);
    my $homebranch = $ekzKohaRecord->{ekzWsConfig}->getEkzWebServicesDefaultBranch($ekzCustomerNumber);
    $homebranch =~ s/^\s+|\s+$//g; # trim spaces
    if ( defined $homebranch && length($homebranch) > 0 && $ekzKohaRecord->checkbranchcode($homebranch) ) {
        $zweigstellencode = $homebranch;
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
    # XXXWH hau wech (OLD) my $ekzAqbooksellersId = C4::Context->preference("ekzAqbooksellersId");
    my $ekzAqbooksellersId = $ekzKohaRecord->{ekzWsConfig}->getEkzAqbooksellersId($ekzCustomerNumber);
    $ekzAqbooksellersId =~ s/^\s+|\s+$//g;    # trim spaces

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

        $ekzBestellNr = 'sto.' . $ekzCustomerNumber . '.ID' . $stoWithNewState->{'stoID'};    # StoList response contains no order number, so we create this dummy order number

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

        # attaching ekz order to Koha acquisition: Create new basket.
        # if system preference ekzAqbooksellersId is not empty: Create a Koha order basket for collecting the Koha orders created for each title contained in the request in the following steps.
        if ( scalar @{$stoWithNewState->{'titelRecords'}} > 0 ) {
            # policy: if ekzAqbooksellersId is not empty but does not identify an aqbooksellers record: create such an record and update ekzAqbooksellersId
            $ekzAqbooksellersId = $ekzKohaRecord->checkEkzAqbooksellersId($ekzAqbooksellersId,1);
            if ( length($ekzAqbooksellersId) ) {
                # Search or create a Koha acquisition order basket,
                # i.e. search / insert a record in table aqbasket so that the following new aqorders records can link to it via aqorders.basketno = aqbasket.basketno .
                my $basketname = 'S-' . $ekzBestellNr;
                my $selbaskets = C4::Acquisition::GetBaskets( { 'basketname' => "\'$basketname\'" } );
                if ( @{$selbaskets} > 0 ) {
                    $basketno = $selbaskets->[0]->{'basketno'};
                    print STDERR "ekzWsStoList::genKohaRecords() found aqbasket with basketno:", $basketno, ":\n" if $debugIt;
                } else {
                    my $authorisedby = undef;
                    my $sth = $dbh->prepare("select borrowernumber from borrowers where surname = 'LCService'");
                    $sth->execute();
                    if ( my $hit = $sth->fetchrow_hashref ) {
                        $authorisedby = $hit->{borrowernumber};
                    }
                    my $branchcode = $ekzKohaRecord->branchcodeFallback('', $homebranch);
                    $basketno = C4::Acquisition::NewBasket($ekzAqbooksellersId, $authorisedby, $basketname, 'created by ekz StoList', '', undef, $branchcode, $branchcode, 0, 'ordering');    # XXXWH
                    print STDERR "ekzWsStoList::genKohaRecords() created new basket having basketno:", Dumper($basketno), ":\n" if $debugIt;
                    if ( $basketno ) {
                        my $basketinfo = {};
                        $basketinfo->{'basketno'} = $basketno;
                        $basketinfo->{'branch'} = $branchcode;
                        C4::Acquisition::ModBasket($basketinfo);
                    }
                }
                if ( !defined($basketno) || $basketno < 1 ) {
                    $acquisitionError = 1;
                }
            }
        }
        print STDERR "ekzWsStoList::genKohaRecords() ekzAqbooksellersId:$ekzAqbooksellersId: acquisitionError:$acquisitionError: basketno:$basketno:\n" if $debugIt;


        # for each titel

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
            $titleHits = $ekzKohaRecord->readTitleInLocalDB($reqParamTitelInfo, 1);
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
                    $titleHits = $ekzKohaRecord->readTitleInLMSPool($reqParamTitelInfo);
print STDERR "ekzWsStoList::genKohaRecords() from LMS Pool titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                } elsif ( $titleSource eq '_EKZWSMD' ) {
                    # send query to the ekz title information web service
                    $titleHits = $ekzKohaRecord->readTitleFromEkzWsMedienDaten($reqParamTitelInfo->{'ekzArtikelNr'});
print STDERR "ekzWsStoList::genKohaRecords() from ekz Webservice titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                } elsif ( $titleSource eq '_WS' ) {
                    # use sparse title data from the StoListElement
                    $titleHits = $ekzKohaRecord->createTitleFromFields($reqParamTitelInfo);    # creates marc data, not a biblio DB record
print STDERR "ekzWsStoList::genKohaRecords() from sent titel fields:",$titleHits->{'count'},": \n" if $debugIt;
                } else {
                    # search title in the Z39.50 target with z3950servers.servername=$titleSource
                    $titleHits = $ekzKohaRecord->readTitleFromZ3950Target($titleSource,$reqParamTitelInfo);
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
                    my $newrec;
                    ($biblionumber,$biblioitemnumber,$newrec) = $ekzKohaRecord->addNewRecord($titleHits->{'records'}->[0]);
                    $titleHits->{'records'}->[0] = $newrec if ($newrec);
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
print STDERR "ekzWsStoList::genKohaRecords() hit->{_column_data}:", Dumper($hit->{_column_data}), ":\n" if $debugIt;
                    my $mess = sprintf("The ekz article number '%s' has already been used in the standing order %s at %s. Processing skipped for this title in order to avoid repeated item record creation.\n",$reqParamTitelInfo->{'ekzArtikelNr'}, $stoWithNewState->{'stoID'}, $hit->get_column('processingtime'));
                    carp $mess;

                    next;    # The ekz article number has already been used in this standing. Skip processing of this title in order to avoid repeated item record creation.

                } else {
                    my $schemaResultAcquitionImport = $acquisitionImportTitle->_resultset()->create($insParam);
                    $acquisitionImportIdTitle = $schemaResultAcquitionImport->get_column('id');
print STDERR "ekzWsStoList::genKohaRecords() Dumper(schemaResultAcquitionImport->{_column_data}):", Dumper($schemaResultAcquitionImport->{_column_data}), ":\n" if $debugIt;
print STDERR "ekzWsStoList::genKohaRecords() acquisitionImportIdTitle:", $acquisitionImportIdTitle, ":\n" if $debugIt;
                }
                $cntTitlesHandled += 1;

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
                ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
                push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $importerror, 1, undef, undef];


                # now add the items data for the new or found biblionumber
                my $ekzExemplarID = $ekzBestellNr . '-' . $reqParamTitelInfo->{'ekzArtikelNr'};    # StoList response contains no item number, so we create this dummy item number
                my $exemplarcount = $titel->{'anzahl'};
                print STDERR "ekzWsStoList::genKohaRecords() exemplar ekzExemplarID:$ekzExemplarID: exemplarcount:$exemplarcount:\n" if $debugIt;


                $titel->{'preis'} =~ tr/,/./;


                    # attaching ekz order to Koha acquisition: Create a new Koha::Acquisition::Order.
                    my $rabatt = 0.0;    # not sent in StoListElement
                    my $fracht = 0.00;    # not sent in StoListElement
                    my $einband = 0.00;    # not sent in StoListElement
                    my $bearbeitung = 0.00;    # not sent in StoListElement
                    my $ustSatz = &C4::External::EKZ::lib::EkzKohaRecords::defaultUstSatz('E');    # not sent in StoListElement
                    my $ust = 0.00;    # not sent in StoListElement
                    my $gesamtpreis = defined($titel->{'preis'}) ? $titel->{'preis'} : "0.00";    # total for a single item
                    my $reqWaehrung = 'EUR';

                    if ( $ust == 0.0 && $ustSatz != 0.0 ) {    # Bruttopreise
                        $ust = $gesamtpreis * $ustSatz / (1 + $ustSatz);
                        $ust =  &C4::External::EKZ::lib::EkzKohaRecords::round($ust, 2);
                    }
                    if ( $ustSatz == 0.0 && $ust != 0.0 && $gesamtpreis != 0.0) {    # Nettopreise
                        $ustSatz = $ust / $gesamtpreis;
                        $ustSatz =  &C4::External::EKZ::lib::EkzKohaRecords::round($ustSatz, 2);
                    }

                    # the following calculation is correct only where aqbooksellers.gstreg=1 and  aqbooksellers.listincgst=1 and  aqbooksellers.invoiceincgst=1 and aqbooksellers.listprice = aqbooksellers.invoiceprice = the library's currency
                    my $listprice_tax_included = $gesamtpreis - $fracht - $einband - $bearbeitung;    # not sent in StoListElement, so we calculate it
                    if ( $rabatt != 0.0 ) {
                        my $divisor = 1.0 - ($rabatt / 100.0);
                        $listprice_tax_included =  $divisor == 0.0 ? $listprice_tax_included : $listprice_tax_included / $divisor;    # list price of single item in vendor's currency, not discounted
                        $listprice_tax_included =  &C4::External::EKZ::lib::EkzKohaRecords::round($listprice_tax_included, 2);
                    }
                    my $divisor = 1.0 + $ustSatz;
                    my $listprice_tax_excluded = $divisor == 0.0 ? 0.0 : $listprice_tax_included / $divisor;
                    $listprice_tax_excluded = &C4::External::EKZ::lib::EkzKohaRecords::round($listprice_tax_excluded, 2);
                    my $replacementcost_tax_included =  $listprice_tax_included;    # list price of single item in library's currency, not discounted (at the moment no exchange rate calculation implemented)
                    my $replacementcost_tax_excluded =  $listprice_tax_excluded;    # list price of single item in library's currency, not discounted, tax excluded (at the moment no exchange rate calculation implemented)

                    my $order = undef;
                    my $ordernumber = undef;
                    if ( defined($basketno) && $basketno > 0 ) {
                        # Add a Koha acquisition order to the order basket,
                        # i.e. insert an additional aqorder and add it to the aqbasket.

                        # conventions:
                        # It depends on aqbooksellers.listincgst if prices include gst or not. Exception: For 'Actual cost' (aqorder.unitprice) this depends on aqbooksellers.invoiceincgst.
                        # aqorders.listprice:   input field 'Vendor price' in UI       single item list price in foreign currency
                        # aqorders.rrp:         input field 'Replacement cost' in UI   single item listprice recalculated in library's currency
                        # aqorders.ecost:       input field 'Budgeted cost' in UI      quantity * single item listprice recalculated in library's currency, discount applied
                        # aqorders.unitprice:   input field 'Actual cost' in UI        entered cost, handling etc. incl.
                        #
                        # Here exclusively the aqbookseller 'ekz' is used, so we assume listprice=EUR, invoiceprice=EUR, gstreg=1, listincgst=1, invoiceincgst=1, tax_rate_bak=0.07 and the library's currency = EUR.

                        my $haushaltsstelle = defined($titel->{'haushaltsstelle'}) ? $titel->{'haushaltsstelle'} : "";
                        my $kostenstelle = defined($titel->{'kostenstelle'}) ? $titel->{'kostenstelle'} : "";

                        my ($dummy1, $dummy2, $budgetid, $dummy3) = $ekzKohaRecord->checkAqbudget($ekzCustomerNumber, $haushaltsstelle, $kostenstelle, 1);

                        my $quantity = $exemplarcount;
                        my $budgetedcost_tax_included = $gesamtpreis;    # discounted
                        my $divisor = 1.0 + $ustSatz;
                        my $budgetedcost_tax_excluded = $divisor == 0.0 ? 0.0 : $budgetedcost_tax_included / $divisor;
                        $budgetedcost_tax_excluded = &C4::External::EKZ::lib::EkzKohaRecords::round($budgetedcost_tax_excluded, 2);

                        my $orderinfo = ();

                        # ordernumber is set by DBS
                        $orderinfo->{biblionumber} = $biblionumber;
                        # entrydate is set to today by Koha::Acquisition::Order->insert()
                        $orderinfo->{quantity} = $quantity;
                        $orderinfo->{currency} = $reqWaehrung;    # currency of bookseller's list price
                        # XXXWH currency-Umrechnung fehlt in die eine oder andere Richtung
                        $orderinfo->{'listprice'} = $listprice_tax_included;    # input field 'Vendor price' in UI (in foreign currency, not discounted, per item)
                        $orderinfo->{unitprice} = 0.0;    #  corresponds to input field 'Actual cost' in UI (discounted) and will be initialized with budgetedcost in the GUI in 'receiving' step
                        $orderinfo->{unitprice_tax_excluded} = 0.0;
                        $orderinfo->{unitprice_tax_included} = 0.0;
                        # quantityreceived is set to 0 by DBS
                        $orderinfo->{order_internalnote} = '';
                        $orderinfo->{order_vendornote} = '';
                        $orderinfo->{basketno} = $basketno;
                        # timestamp is set to now by DBS
                        $orderinfo->{budget_id} = $budgetid;
                        $orderinfo->{'uncertainprice'} = 0;
                        # claims_count is set to 0 by DBS
                        $orderinfo->{subscriptionid} = undef;
                        $orderinfo->{orderstatus} = 'ordered';
                        $orderinfo->{rrp} = $replacementcost_tax_included;    #  corresponds to input field 'Replacement cost' in UI (not discounted, per item)
                        $orderinfo->{rrp_tax_excluded} = $replacementcost_tax_excluded;
                        $orderinfo->{rrp_tax_included} = $replacementcost_tax_included;
                        $orderinfo->{ecost} = $budgetedcost_tax_included;     #  corresponds to input field 'Budgeted cost' in UI (discounted, per item)
                        $orderinfo->{ecost_tax_excluded} = $budgetedcost_tax_excluded;
                        $orderinfo->{ecost_tax_included} = $budgetedcost_tax_included;
                        $orderinfo->{tax_rate_bak} = $ustSatz;        #  corresponds to input field 'Tax rate' in UI (7% are stored as 0.07)
                        $orderinfo->{tax_rate_on_ordering} = $ustSatz;
                        $orderinfo->{tax_rate_on_receiving} = $ustSatz;
                        $orderinfo->{tax_value_bak} = $ust;        #  corresponds to input field 'Tax value' in UI
                        $orderinfo->{tax_value_on_ordering} = $ust;
                        # XXXWH or alternatively: $orderinfo->{tax_value_on_ordering} = $orderinfo->{quantity} * $orderinfo->{ecost_tax_excluded} * $orderinfo->{tax_rate_on_ordering};    # see C4::Acquisition.pm
                        $orderinfo->{tax_value_on_receiving} = $ust;
                        # XXXWH or alternatively: $orderinfo->{tax_value_on_receiving} = $orderinfo->{quantity} * $orderinfo->{unitprice_tax_excluded} * $orderinfo->{tax_rate_on_receiving};    # see C4::Acquisition.pm
                        $orderinfo->{discount} = $rabatt;        #  corresponds to input field 'Discount' in UI (5% are stored as 5.0)

                        $order = Koha::Acquisition::Order->new($orderinfo);
                        $order->store();
                        $ordernumber = $order->{ordernumber};
                    }


                for ( my $j = 0; $j < $exemplarcount; $j++ ) {
                    my $problems = '';              # string for accumulating error messages for this order
                    my $item_hash;

                    $processedItemsCount += 1;
                    $cntItemsHandled += 1;

                    $item_hash->{homebranch} = $zweigstellencode;
                    $item_hash->{booksellerid} = 'ekz';
                    $item_hash->{price} = $gesamtpreis;
                    $item_hash->{replacementprice} = $replacementcost_tax_included;
                    
                    my ( $biblionumberItem, $biblioitemnumberItem, $itemnumber ) = C4::Items::AddItem($item_hash, $biblionumber);
                    my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                    my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                    my $importId = '(ControlNumber)' . $tmp_cn . '(ControlNrId)' . $tmp_cna;    # if cna = 'DE-Rt5' then this cn is the ekz article number
                    $importIds{$importId} = $itemnumber;
print STDERR "ekzWsStoList::genKohaRecords() importedItemsCount:$importedItemsCount; set next importIds:", $importId, ":\n" if $debugIt;

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

                        # attaching ekz order to Koha acquisition: Insert an additional aqordersitem for the aqorder.
                        # Insert an additional aqordersitem for the aqorder.
                        if ( defined($order) ) {
                            $order->add_item($itemnumber);
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
                    push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $importerror, 2, $ordernumber, $basketno];
                }
            }

            # create @actionresult message for log email, representing 1 title with all its processed items
            my @actionresultTit = ( 'insertRecords', 0, "X", "Y", $processedTitlesCount, $importedTitlesCount, $updatedTitlesCount, $processedItemsCount, $importedItemsCount, 0, \@records );
print STDERR "ekzWsStoList::genKohaRecords() actionresultTit:", @actionresultTit, ":\n" if $debugIt;
print STDERR "ekzWsStoList::genKohaRecords() actionresultTit->[10]->[0]:", @{$actionresultTit[10]->[0]}, ":\n" if $debugIt;
            push @actionresult, \@actionresultTit;

        }

        # attaching ekz order to Koha acquisition: Because handling standing orders here, we do not close the basket, but create (but also not close) the corresponding basketgroup.
        if ( length($ekzAqbooksellersId) && defined($basketno) && $basketno > 0 ) {
            # create a basketgroup for this basket and keep open both basket and basketgroup
            my $aqbasket = &C4::Acquisition::GetBasket($basketno);
print STDERR "ekzWsStoList::genKohaRecords() Dumper aqbasket:", Dumper($aqbasket), ":\n" if $debugIt;
            if ( $aqbasket ) {
                # do not close the basket with standing orders

                # search/create basket group with aqbasketgroups.name = pseudo ekz order number and aqbasketgroups.booksellerid = and update aqbasket accordingly
                my $params = {
                    name => "\'$aqbasket->{basketname}\'",
                    booksellerid => $aqbasket->{booksellerid}
                };
                $basketgroupid  = undef;
                my $aqbasketgroups = &C4::Acquisition::GetBasketgroupsGeneric($params, { orderby => "id DESC" } );
print STDERR "ekzWsStoList::genKohaRecords() Dumper aqbasketgroups:", Dumper($aqbasketgroups), ":\n" if $debugIt;

                # create basket group if not existing
                if ( !defined($aqbasketgroups) || scalar @{$aqbasketgroups} == 0 ) {
                    $params = { 
                        name => "$aqbasket->{basketname}",
                        closed => 0,
                        booksellerid => $aqbasket->{booksellerid},
                        deliveryplace => "$aqbasket->{deliveryplace}",
                        freedeliveryplace => "$aqbasket->{freedeliveryplace}",
                        deliverycomment => "$aqbasket->{deliverycomment}",
                        billingplace => "$aqbasket->{billingplace}",
                    };
                    $basketgroupid  = &C4::Acquisition::NewBasketgroup($params);
print STDERR "ekzWsStoList::genKohaRecords() created basketgroup with name:", $aqbasket->{basketname}, ": having basketgroupid:$basketgroupid:\n" if $debugIt;
                } else {
                    $basketgroupid = $aqbasketgroups->[0]->{id};
print STDERR "ekzWsStoList::genKohaRecords() found basketgroup with name:", $aqbasket->{basketname}, ": having basketgroupid:$basketgroupid:\n" if $debugIt;
                }

                if ( $basketgroupid ) {
                    # update basket, i.e. set basketgroupid
                    my $basketinfo = {
                        'basketno' => $aqbasket->{basketno},
                        'basketgroupid' => $basketgroupid
                    };
                    &C4::Acquisition::ModBasket($basketinfo);

                    # do not close the basketgroup with standing orders
                }
            }
        }


        # create @logresult message for log email, representing all titles of the StoList $stoWithNewState with all their processed items
        push @logresult, ['StoList', $messageID, \@actionresult, $acquisitionError, $ekzAqbooksellersId, $basketno];
print STDERR "Dumper(\\\@logresult): ####################################################################################################################\n" if $debugIt;
print STDERR Dumper(\@logresult) if $debugIt;


        #$dbh->rollback;    # roll it back for TEST XXXWH

        # commit the complete standing order update (only as a single transaction)
        $dbh->commit();
        $dbh->{AutoCommit} = 1;

print STDERR "ekzWsStoList::genKohaRecords() cntTitlesHandled:$cntTitlesHandled: cntItemsHandled:$cntItemsHandled:\n" if $debugIt;
        if ( scalar(@logresult) > 0 && ($cntTitlesHandled > 0 || $cntItemsHandled > 0) ) {
            my @importIds = keys %importIds;
            ($message, $subject, $haserror) = $ekzKohaRecord->createProcessingMessageText(\@logresult, "headerTEXT", $dt, \@importIds, $ekzBestellNr);  # we use ekzBestellNr as part of importID in MARC field 025.a: (EKZImport)$importIDs->[0]
            $ekzKohaRecord->sendMessage($ekzCustomerNumber, $message, $subject);
        }
    }

    return 1;
}

1;
