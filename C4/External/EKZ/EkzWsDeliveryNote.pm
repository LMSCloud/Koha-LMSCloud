package C4::External::EKZ::EkzWsDeliveryNote;

# Copyright 2017-2024 (C) LMSCLoud GmbH
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
use DateTime::Format::MySQL;
use Exporter;
use Try::Tiny;

use C4::Acquisition qw( NewBasket GetBasket GetBaskets ModBasket ReopenBasket GetBasketgroupsGeneric NewBasketgroup CloseBasketgroup ReOpenBasketgroup GetOrderFromItemnumber ModOrderDeliveryNote );
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::Context;
use C4::Items qw( ModItemFromMarc );    # additionally GetMarcItem is required here, but it is not exported by C4::Items, so we have to use it inofficially
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::lib::EkzKohaRecords;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use Koha::Acquisition::Baskets;
use Koha::Acquisition::Order;
use Koha::Database;
use Koha::Item;
use Koha::Items;
use Koha::Logger;
use Koha::Patrons;
use Koha::Biblios;

our @ISA = qw(Exporter);
our @EXPORT = qw( readLSFromEkzWsLieferscheinList readLSFromEkzWsLieferscheinDetail genKohaRecords updBiblioIndex );


###################################################################################################
# read Lieferschein (delivery notes) using ekz web service 'LieferscheinList' (overview data)
###################################################################################################
sub readLSFromEkzWsLieferscheinList {
    my $ekzCustomerNumber = shift;
    my $selVon = shift;
    my $selBis = shift;
	my $selKundennummerWarenEmpfaenger = shift;

    my $result = ();    # hash reference
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsDeliveryNote' });

    $logger->info("readLSFromEkzWsLieferscheinList() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                        ": selVon:" . (defined($selVon) ? $selVon : 'undef') .
                                                        ": selBis:" . (defined($selBis) ? $selBis : 'undef') .
                                                        ": selKundennummerWarenEmpfaenger:" . (defined($selKundennummerWarenEmpfaenger) ? $selKundennummerWarenEmpfaenger : 'undef') .
                                                        ":");

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsLieferscheinList($ekzCustomerNumber, $selVon, $selBis, $selKundennummerWarenEmpfaenger);

    $logger->info("readLSFromEkzWsLieferscheinList() returns result:" .  Dumper($result) . ":");

    return $result;
}


###################################################################################################
# read single Lieferschein (delivery note) using ekz web service 'LieferscheinDetail' (detailed delivery note data)
###################################################################################################
sub readLSFromEkzWsLieferscheinDetail {
    my $ekzCustomerNumber = shift;
    my $selId = shift;
    my $selLieferscheinnummer = shift;
    my $refLieferscheinDetailElement = shift;    # for storing the LieferscheinDetailElement of the SOAP response body

    my $result = ();    # hash reference
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsDeliveryNote' });

    $logger->info("readLSFromEkzWsLieferscheinDetail() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                          ": selId:" . (defined($selId) ? $selId : 'undef') .
                                                          ": selLieferscheinnummer:" . (defined($selLieferscheinnummer) ? $selLieferscheinnummer : 'undef') .
                                                          ":");
    $logger->trace("readLSFromEkzWsLieferscheinDetail() START Dumper(\$refLieferscheinDetailElement):" . Dumper($refLieferscheinDetailElement) .
                                                           ":");

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsLieferscheinDetail($ekzCustomerNumber, $selId, $selLieferscheinnummer, $refLieferscheinDetailElement);

    $logger->info("readLSFromEkzWsLieferscheinList() returns result:" .  Dumper($result) . ":");

    return $result;
}


###################################################################################################
# go through the titles contained in the delivery note and handle items status, 
# generate title data and item data as required
###################################################################################################
sub genKohaRecords {
    my ($ekzCustomerNumber, $messageID, $lieferscheinDetailElement, $lieferscheinRecord, $createdTitleRecords, $updatedTitleRecords) = @_;
    my $ekzKohaRecord = C4::External::EKZ::lib::EkzKohaRecords->new();

    my $lieferscheinNummerIsDuplicate = 0;
    my $lieferscheinNummer = '';
    my $lieferscheinDatum = '';
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsDeliveryNote' });
    my $exceptionThrown;
    my $schema = Koha::Database->new->schema;
    $schema->storage->txn_begin;

    # variables for email log
    my $emaillog;
    $emaillog->{'logresult'} = [];    # array ref
    $emaillog->{'actionresult'} = [];    # array ref
    $emaillog->{'importerror'} = 0;    # flag if an insert error has happened
    $emaillog->{'importIds'} = {};    # hash ref
    $emaillog->{'dt'} = DateTime->now;
    $emaillog->{'dt'}->set_time_zone( 'Europe/Berlin' );
    my ($message, $subject, $haserror) = ('','',0);

    $logger->info("genKohaRecords() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                       ": messageID:" . (defined($messageID) ? $messageID : 'undef') .
                                       ": id:" . (defined($lieferscheinRecord->{'id'}) ? $lieferscheinRecord->{'id'} : 'undef') .
                                       ": Lieferscheinnummer:" . (defined($lieferscheinRecord->{'nummer'}) ? $lieferscheinRecord->{'nummer'} : 'undef') .
                                       ": teilLieferungCount:" . (defined($lieferscheinRecord->{'teilLieferungCount'}) ? $lieferscheinRecord->{'teilLieferungCount'} : 'undef') .
                                       ":");

    try {
    my $updOrInsItemsCount = 0;
    my $zweigstellencode = '';
    my $homebranch = $ekzKohaRecord->{ekzWsConfig}->getEkzWebServicesDefaultBranch($ekzCustomerNumber);
    $homebranch =~ s/^\s+|\s+$//g; # trim spaces
    if ( defined $homebranch && length($homebranch) > 0 ) {
        $zweigstellencode = $homebranch;
    }
    if ( ! $ekzKohaRecord->checkbranchcode($zweigstellencode) ) {
        $zweigstellencode = '';
    }
    my $titleSourceSequence = C4::Context->preference("ekzTitleDataServicesSequence");
    if ( !defined($titleSourceSequence) ) {
        $titleSourceSequence = '_LMSC|_EKZWSMD|DNB|_WS';
    }
    my $ekzWebServicesHideOrderedTitlesInOpac = C4::Context->preference("ekzWebServicesHideOrderedTitlesInOpac");
    my $ekzWebServicesSetItemSubfieldsWhenOrdered = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered");
    my $ekzWebServicesSetItemSubfieldsWhenReceived = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenReceived");
    my $ekzWsHideOrderedTitlesInOpac = 1;    # policy: hide title if not explictly set to 'show'
    if( defined($ekzWebServicesHideOrderedTitlesInOpac) && 
        length($ekzWebServicesHideOrderedTitlesInOpac) > 0 &&
        $ekzWebServicesHideOrderedTitlesInOpac == 0 ) {
            $ekzWsHideOrderedTitlesInOpac = 0;
    }
    my $ekzAqbooksellersId = $ekzKohaRecord->{ekzWsConfig}->getEkzAqbooksellersId($ekzCustomerNumber);
    $ekzAqbooksellersId =~ s/^\s+|\s+$//g;    # trim spaces
    my $acquisitionError = 0;
    my $basketno = -1;
    my $basketgroupid = undef;
    my $authorisedby = undef;

    $lieferscheinNummer = $lieferscheinRecord->{'nummer'};
    $lieferscheinNummer =~ s/^\s+|\s+$//g;    # trim spaces
    my $lsDatum = $lieferscheinRecord->{'datum'};
    $lieferscheinDatum = DateTime->new( year => substr($lsDatum,0,4), month => substr($lsDatum,5,2), day => substr($lsDatum,8,2), time_zone => 'local' );

    # values for order that eventually has to be created pro forma
    # (This is the case for orders that have not been announced by web services BestellInfo and StoList.)
    my $ekzBestellNr = 'delID' . $lieferscheinNummer;    # dummy order id in case we have to create an order entry
    my $bestellDatum = $lieferscheinDatum;               # dummy order date in case we have to create an order entry
    my $dateTimeNow = DateTime->now(time_zone => 'local');


    # Insert a record into table acquisition_import representing the delivery note.
    # If a delivery message record with this delivery note number exists already there will be written a log entry
    # and no further processing will be done.
    my $selParam = {
        vendor_id => "ekz",
        object_type => "delivery",
        object_number => $lieferscheinNummer,
        rec_type => "message",
        processingstate => "delivered"
    };
    my $insParam = {
        #id => 0, # AUTO
        vendor_id => "ekz",
        object_type => "delivery",
        object_number => $lieferscheinNummer,
        object_date => DateTime::Format::MySQL->format_datetime($lieferscheinDatum),    # in local time_zone
        rec_type => "message",
        #object_item_number => "", # NULL
        processingstate => "delivered",
        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
        payload => $lieferscheinDetailElement,
        #object_reference => undef # NULL
    };
    $logger->trace("genKohaRecords() search delivery note message record in acquisition_import selParam:" . Dumper($selParam) . ":");

    my $acquisitionImportIdLieferschein;
    my $acquisitionImportLieferschein = Koha::AcquisitionImport::AcquisitionImports->new();
    my $hit = $acquisitionImportLieferschein->_resultset()->search( $selParam )->first();
    $logger->trace("genKohaRecords() ref(acquisitionImportLieferschein):" . ref($acquisitionImportLieferschein) . ": ref(hit)" . ref($hit) . ":");
    if ( defined($hit) ) {
        $lieferscheinNummerIsDuplicate = 1;
        $logger->trace("genKohaRecords() hit->{_column_data}:" . Dumper($hit->{_column_data}) . ":");
        my $mess = sprintf("genKohaRecords(): The delivery note number '%s' has already been used at %s. Processing denied.",$lieferscheinNummer, $hit->get_column('processingtime'));
        $logger->error($mess);
        carp "EkzWsDeliveryNote::" . $mess . "\n";
    } else {
        my $schemaResultAcquitionImport = $acquisitionImportLieferschein->_resultset()->create($insParam);
        $acquisitionImportIdLieferschein = $schemaResultAcquitionImport->get_column('id');
        $logger->trace("genKohaRecords() ref(schemaResultAcquitionImport):" . ref($schemaResultAcquitionImport) . ":");
        #$logger->trace("genKohaRecords() Dumper(schemaResultAcquitionImport):" . Dumper($schemaResultAcquitionImport) . ":");
        $logger->trace("genKohaRecords() Dumper(schemaResultAcquitionImport->{_column_data}):" . Dumper($schemaResultAcquitionImport->{_column_data}) . ":");
        $logger->trace("genKohaRecords() acquisitionImportIdLieferschein:" . $acquisitionImportIdLieferschein . ":");
    }



    if ( !$lieferscheinNummerIsDuplicate ) {

        # handle each delivered title        
        foreach my $teilLieferungRecord ( @{$lieferscheinRecord->{'teilLieferungRecords'}} ) {

            my $titleHits = { 'count' => 0, 'records' => [] };
            my $biblioExisting = 0;
            my $biblioInserted = 0;
            my $biblionumber = 0;
            my $biblioitemnumber;
            my $lsEkzArtikelNr = '';

            $logger->trace("genKohaRecords() teilLieferungRecord gelieferteExemplare:$teilLieferungRecord->{'gelieferteExemplare'}: teilLieferung:$teilLieferungRecord->{'teilLieferung'}: auftragsPositionCount:$teilLieferungRecord->{'auftragsPositionCount'}:");
            my $auftragsPosition = $teilLieferungRecord->{'auftragsPositionRecords'}->[0];    # this array always consists of only 1 element
            $logger->trace("genKohaRecords() auftragsPosition ekzexemplarid:" . (defined($auftragsPosition->{'ekzexemplarid'}) ? $auftragsPosition->{'ekzexemplarid'} : 'undef') . ": ekzArtikelNr:$auftragsPosition->{'artikelNummer'}: isbn:$auftragsPosition->{'isbn'}: ean:$auftragsPosition->{'ean'}: kundenBestelldatum:$auftragsPosition->{'kundenBestelldatum'}:");
            my $deliveredItemsCount = $teilLieferungRecord->{'gelieferteExemplare'};
            $updOrInsItemsCount = 0;

            # additional variables for email log
            $emaillog->{'processedTitlesCount'} = 1;       # counts the title processed in this step (1)
            $emaillog->{'importedTitlesCount'} = 0;        # counts the title inserted in this step (0/1)
            $emaillog->{'foundTitlesCount'} = 0;           # counts the title found in this step (0/1)
            $emaillog->{'processedItemsCount'} = 0;        # counts the items processed in this step
            $emaillog->{'importedItemsCount'} = 0;         # counts the items inserted in this step
            $emaillog->{'updatedItemsCount'} = 0;          # counts the items updated in this step
            $emaillog->{'importresult'} = 0;               # insert result per title / item   OK:1   ERROR:-1
            $emaillog->{'problems'} = '';                  # string for error messages for this order
            $emaillog->{'records'} = [];                   # one record for the title and one for each item (array ref)
            my ($titeldata, $isbnean) = ("", "");

            my $reqParamTitelInfo = ();
            $reqParamTitelInfo->{'ekzArtikelNr'} = $auftragsPosition->{'artikelNummer'};
            my $isbn = $auftragsPosition->{'isbn'};
            if ( length($isbn) == 10 ) {
                $reqParamTitelInfo->{'isbn'} = $isbn;
            } else {
                $reqParamTitelInfo->{'isbn13'} = $isbn;
            }
            $reqParamTitelInfo->{'ean'} = $auftragsPosition->{'ean'};

            # search corresponding item hits with same ekzExemplarid in table acquisition_import, if sent in $auftragsPosition->{'ekzexemplarid'}.
            # otherwise:
            # search corresponding item hits with same ekzArtikelNr and same referenznummer in table acquisition_import, if sent in $auftragsPosition->{'artikelNummer'} and  in $auftragsPosition->{'referenzummer'}.
            # otherwise:
            # search corresponding order title hits with same ekzArtikelNr in table acquisition_import, if sent in $auftragsPosition->{'artikelNummer'}
            # In some cases (e.g. knv titles) the artikelNummer is 0, so it can't be used for search
            # if not found enough acquisition_import records of rec_type 'item' and processingstate 'ordered': 'invent' the underlying order and store it

            # we try maximal 4 methods for identifying an order, or 'inventing' one, if required:
            #
            # method1: searching for ekzExemplarid identity
            #          (which is preferable; typical for an item that was ordered in the ekz Medienshop or via webservice 'Bestellung')
            #
            # method2: searching for ekzArtikelNr and referenznummer identity if ekzArtikelNr > 0 and referenznummer > 0
            #          (Typical for an item of a running standing order (since 2020-09-14) or of a running serial order (since 2021-01-14),
            #           when referenznummer for standing order item and serial order item was introduced by ekz.)
            #
            # method3: searching for ekzArtikelNr identity if ekzArtikelNr > 0
            #          (Typical for an item of a running standing order (but only until 2020-09-13, before referenznummer for standing order item was introduced by ekz).)
            #          Method 3 is deactivated since april 2022 (from version 21.05 on) for two reasons:
            #          - It is quite shure that all standing order items that have been inserted without referenznummer before 2020-09-14 have already been delivered and invoiced before april 2022.
            #          - A item of a title of a current serial order that is also a title of a current standing order would incorrectly be identified as item of the standing order title.
            #
            # method4 is for all items for which no acquisition_import record representing the order title could be found
            #          (Typical for an item of a running continuation/serial order (but only until 2021-01-13, before referenznummer for serial order item was introduced by ekz).)


            # method1: searching for ekzExemplarid identity (which is preferable; typical for an item that was ordered in the ekz Medienshop or via webservice 'Bestellung')
            if (defined($auftragsPosition->{'ekzexemplarid'}) && length($auftragsPosition->{'ekzexemplarid'}) > 0 && $updOrInsItemsCount < $deliveredItemsCount ) {

                # search in acquisition_import for records representing ordered items with the same ekzExemplarid
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_item_number => $auftragsPosition->{'ekzexemplarid'},
                    rec_type => "item",
                    processingstate => 'ordered'
                };
                $logger->trace("genKohaRecords() method1: search order item record in acquisition_import selParam:" . Dumper($selParam) . ":");
                my $acquisitionImportEkzExemplarIdHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
                $logger->trace("genKohaRecords() method1: scalar acquisitionImportEkzExemplarIdHits:" . scalar $acquisitionImportEkzExemplarIdHits . ":");

                foreach my $acquisitionImportEkzExemplarIdHit ($acquisitionImportEkzExemplarIdHits->all()) {
                    if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                        last;
                    }
                    $logger->trace("genKohaRecords() method1: acquisitionImportEkzExemplarIdHit->{_column_data}:" . Dumper($acquisitionImportEkzExemplarIdHit->{_column_data}) . ":");

                    #read the corresponding title via its biblionumber from acquisition_import_objects
                    # search in acquisition_import for the record representing the ordered title belonging to this item
                    my $selParam = {
                        vendor_id => "ekz",
                        object_type => "order",
                        id => $acquisitionImportEkzExemplarIdHit->get_column('object_reference'),
                        rec_type => "title",
                        processingstate => 'ordered'
                    };
                    $logger->trace("genKohaRecords() method1: search title order record in acquisition_import selParam:" . Dumper($selParam) . ":");
                    my $acquisitionImportTitleHit = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->find($selParam);    # unique via 'id'
                    $logger->trace("genKohaRecords() method1: acquisitionImportTitleHit->{_column_data}::" . Dumper($acquisitionImportTitleHit->{_column_data}) . ":");
                    if ( defined($acquisitionImportTitleHit) ) {
                        my $selParam = {
                            acquisition_import_id => $acquisitionImportTitleHit->get_column('id'),
                            koha_object => "title"
                        };
                        $logger->trace("genKohaRecords() method1: search title order record in acquisition_import_objects selParam:" . Dumper($selParam) . ":");
                        my $titleObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                        my $titleObjectRS = $titleObject->_resultset()->search($selParam)->first();
                        my $selBiblionumber = $titleObjectRS->get_column('koha_object_id');
                        $logger->trace("genKohaRecords() method1: titleObjectRS->{_column_data}:" . Dumper($titleObjectRS->{_column_data}) . ":");

                        if ( defined($selBiblionumber) ) {
                            if ( $selBiblionumber != $biblionumber ) {
                                $titleHits = { 'count' => 0, 'records' => [] };
                                $biblionumber = 0;
                                $biblioExisting = 0;
                                $lsEkzArtikelNr = '';
                                my $biblio = Koha::Biblios->find( $selBiblionumber );
                                my $record = $biblio ? $biblio->metadata->record : undef;
                                if ( defined($record) ) {
                                    $titleHits->{'count'} = 1;
                                    $titleHits->{'records'}->[0] = $record;
                                }

                                if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                                    $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                                    my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                                    my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                                    if ( $tmp_cna eq "DE-Rt5" ) {
                                        $lsEkzArtikelNr = $tmp_cn;
                                    } else {
                                        $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                                    }
                                    $biblioExisting = 1;    # this flag may be required in method 4

                                    # Check if to reread title data via webservice MedienDaten etc. and, if required, (partially) overwrite the title record.
                                    $ekzKohaRecord->overwriteCatalogDataIfRequired($ekzCustomerNumber, $biblionumber, $reqParamTitelInfo, $titleHits->{'records'}->[0], $updatedTitleRecords);

                                    # positive message for log email
                                    $emaillog->{'importresult'} = 2;
                                    $emaillog->{'importedTitlesCount'} += 0;

                                    # add result of finding biblio to log email
                                    ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
                                    push @{$emaillog->{'records'}}, [$lsEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                                    $logger->trace("genKohaRecords() method1: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
                                } else {
                                    next;    # next in acquisitionImportEkzExemplarIdHits->all()
                                }
                            }
                            &processItemHit($lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsEkzArtikelNr, '', $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportEkzExemplarIdHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId, $logger);
                        }    #end defined($selBiblionumber)
                    }    # end defined($acquisitionImportTitleHit)
                }    # end foreach acquisitionImportEkzExemplarIdHits->all()
            }    # end method1
            $logger->debug("genKohaRecords() after method 1 deliveredItemsCount:$deliveredItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: lsEkzArtikelNr:$lsEkzArtikelNr:");


            # method2: searching for ekzArtikelNr and referenznummer identity if ekzArtikelNr > 0 and referenznummer > 0
            #          (Typical for an item of a running standing order since 2020-09-14 or of a running serial order since 2021-01-14,
            #           when referenznummer for standing order item and serial order item was introduced by ekz.)
            if (defined($auftragsPosition->{'artikelNummer'}) && $auftragsPosition->{'artikelNummer'} > 0 && 
                defined($auftragsPosition->{'referenznummer'}) && length($auftragsPosition->{'referenznummer'}) > 0 && 
                $updOrInsItemsCount < $deliveredItemsCount ) {
                # ekz has confirmed that there is sent maximal 1 <referenznummer> XML-element per <auftragsPosition>.
                # If the items of a title are spread over multiple (different) referenznummer values, then multiple <auftragsPosition> blocks will be sent.
                my $lsReferenznummer = $auftragsPosition->{'referenznummer'};

                # search in acquisition_import for records representing ordered items of a standing order or serial order with the same $ekzCustomerNumber, ekzArtikelNr and referenznummer
                
                # There exist at least four possible select strategies:
                # 1. Select strategy via '-or' will cause full table scan:
                # my $selParam = {
                #     vendor_id => "ekz",
                #     object_type => "order",
                #     -or =>
                #         [
                #             object_item_number => { 'like' => 'sto.' . $ekzCustomerNumber . '.ID%-' . $auftragsPosition->{'artikelNummer'} . '-' . $auftragsPosition->{'referenznummer'} },
                #             object_item_number => { 'like' => 'ser.' . $ekzCustomerNumber . '.ID%-' . $auftragsPosition->{'artikelNummer'} . '-' . $auftragsPosition->{'referenznummer'} },
                #         ],
                #     rec_type => "item",
                #     processingstate => 'ordered'
                # };

                # 2. Select strategy via 'UNION' avoids full table scan but would require additional (i.e. not Koha-standard) PERL module DBIx::Class::Helper::ResultSet::SetOperations:
                # my $rs1 = $rs->search({ ..., object_item_number => { 'like' => 'sto.' . $ekzCustomerNumber . '.ID%-' . $auftragsPosition->{'artikelNummer'} . '-' . $auftragsPosition->{'referenznummer'}, ... });  
                # my $rs2 = $rs->search({ ..., object_item_number => { 'like' => 'ser.' . $ekzCustomerNumber . '.ID%-' . $auftragsPosition->{'artikelNummer'} . '-' . $auftragsPosition->{'referenznummer'}, ... });  
                # for ($rs1->union($rs2)->all) { ... }

                # 3. Cheap and dirty select strategy (but sufficient in this case, i.e. searching for 'sto.' or 'ser.' via 's__.'):
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_item_number => { 'like' => 's__.' . $ekzCustomerNumber . '.ID%-' . $auftragsPosition->{'artikelNummer'} . '-' . $auftragsPosition->{'referenznummer'} },
                    rec_type => "item",
                    processingstate => 'ordered'
                };

                # 4. executing the whole action separately for sto.% and ser.%: That's just too boring.

                my $orderByParam = { order_by => { -asc => [ "id"] } };
                $logger->trace("genKohaRecords() method2: search order item record in acquisition_import selParam:" . Dumper($selParam) . ": orderByParam:" . Dumper($orderByParam) . ":");
                my $acquisitionImportEkzExemplarIdHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam, $orderByParam);
                $logger->trace("genKohaRecords() method2: scalar acquisitionImportEkzExemplarIdHits:" . scalar $acquisitionImportEkzExemplarIdHits . ":");

                foreach my $acquisitionImportEkzExemplarIdHit ($acquisitionImportEkzExemplarIdHits->all()) {
                    if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                        last;
                    }
                    $logger->trace("genKohaRecords() method2: acquisitionImportEkzExemplarIdHit->{_column_data}:" . Dumper($acquisitionImportEkzExemplarIdHit->{_column_data}) . ":");

                    #read the corresponding title via its biblionumber from acquisition_import_objects
                    # search in acquisition_import for the record representing the ordered title belonging to this item
                    my $selParam = {
                        vendor_id => "ekz",
                        object_type => "order",
                        id => $acquisitionImportEkzExemplarIdHit->get_column('object_reference'),
                        rec_type => "title",
                        processingstate => 'ordered'
                    };
                    $logger->trace("genKohaRecords() method2: search title order record in acquisition_import selParam:" . Dumper($selParam) . ":");
                    my $acquisitionImportTitleHit = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->find($selParam);    # unique via 'id'
                    $logger->trace("genKohaRecords() method2: acquisitionImportTitleHit->{_column_data}::" . Dumper($acquisitionImportTitleHit->{_column_data}) . ":");
                    if ( defined($acquisitionImportTitleHit) ) {
                        my $selParam = {
                            acquisition_import_id => $acquisitionImportTitleHit->get_column('id'),
                            koha_object => "title"
                        };
                        $logger->trace("genKohaRecords() method2: search title order record in acquisition_import_objects selParam:" . Dumper($selParam) . ":");
                        my $titleObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                        my $titleObjectRS = $titleObject->_resultset()->search($selParam)->first();
                        my $selBiblionumber = $titleObjectRS->get_column('koha_object_id');
                        $logger->trace("genKohaRecords() method2: titleObjectRS->{_column_data}:" . Dumper($titleObjectRS->{_column_data}) . ":");

                        if ( defined($selBiblionumber) ) {
                            if ( $selBiblionumber != $biblionumber ) {
                                $titleHits = { 'count' => 0, 'records' => [] };
                                $biblionumber = 0;
                                $biblioExisting = 0;
                                $lsEkzArtikelNr = '';
                                my $biblio = Koha::Biblios->find( $selBiblionumber );
                                my $record = $biblio ? $biblio->metadata->record : undef;
                                if ( defined($record) ) {
                                    $titleHits->{'count'} = 1;
                                    $titleHits->{'records'}->[0] = $record;
                                }

                                if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                                    $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                                    my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                                    my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                                    if ( $tmp_cna eq "DE-Rt5" ) {
                                        $lsEkzArtikelNr = $tmp_cn;
                                    } else {
                                        $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                                    }
                                    $biblioExisting = 1;    # this flag may be required in method 4

                                    # Check if to reread title data via webservice MedienDaten etc. and, if required, (partially) overwrite the title record.
                                    $ekzKohaRecord->overwriteCatalogDataIfRequired($ekzCustomerNumber, $biblionumber, $reqParamTitelInfo, $titleHits->{'records'}->[0], $updatedTitleRecords);

                                    # positive message for log email
                                    $emaillog->{'importresult'} = 2;
                                    $emaillog->{'importedTitlesCount'} += 0;

                                    # add result of finding biblio to log email
                                    ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
                                    push @{$emaillog->{'records'}}, [$lsEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                                    $logger->trace("genKohaRecords() method2: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
                                } else {
                                    next;    # next in acquisitionImportEkzExemplarIdHits->all()
                                }
                            }

                            &processItemHit($lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsEkzArtikelNr, $lsReferenznummer, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportEkzExemplarIdHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId, $logger);
                        }    #end defined($selBiblionumber)
                    }    # end defined($acquisitionImportTitleHit)
                }    # end foreach acquisitionImportEkzExemplarIdHits->all()
            }    # end method2
            $logger->debug("genKohaRecords() after method 2 deliveredItemsCount:$deliveredItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: lsEkzArtikelNr:$lsEkzArtikelNr:");


            # method3: searching for ekzArtikelNr identity if ekzArtikelNr > 0
            #          (Typical for an item of a running standing order (but only until 2020-09-13, before referenznummer for standing order item was introduced by ekz).)
            # This method is deactivated since april 2022 (from version 21.05 on) for two reasons:
            # - It is quite shure that all standing order items that have been inserted without referenznummer before 2020-09-14 have already been delivered and invoiced before april 2022.
            # - A item of a title of a current serial order that is also a title of a current standing order would incorrectly be identified as item of the standing order title.
#            if (defined($auftragsPosition->{'artikelNummer'}) && $auftragsPosition->{'artikelNummer'} > 0 && $updOrInsItemsCount < $deliveredItemsCount ) {
#            #if (defined($auftragsPosition->{'artikelNummer'})  && $updOrInsItemsCount < $deliveredItemsCount ) {    # XXXWH maybe there is an standing order that matches the auftragsPosition by ISBN or EAN even if $auftragsPosition->{'artikelNummer'} == 0 or empty
#
#                # search in acquisition_import for records representing ordered orders with the same ekzArtikelNr
#                my $selParam = {
#                    vendor_id => "ekz",
#                    object_type => "order",
#                    object_number => { 'like' => 'sto.' . $ekzCustomerNumber . '.ID%' },
#                    object_item_number => $auftragsPosition->{'artikelNummer'},
#                    rec_type => "title"
#                };
#                $logger->trace("genKohaRecords() method3: search title order record in acquisition_import selParam:" . Dumper($selParam) . ":");
#                my $acquisitionImportTitleHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
#                $logger->trace("genKohaRecords() method2: scalar acquisitionImportTitleHits:" . scalar $acquisitionImportTitleHits . ":");
#
#                # Search corresponding 'ordered' order items and set them to 'delivered' (in table 'acquisition_import' and in 'items' via system preference ekzWsItemSetSubfieldsWhenReceived).
#                # Insert records in table acquisition_import for the title and items.
#                foreach my $acquisitionImportTitleHit ($acquisitionImportTitleHits->all()) {
#                    if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
#                        last;
#                    }
#                    $logger->trace("genKohaRecords() method2: acquisitionImportTitleHit->{_column_data}:" . Dumper($acquisitionImportTitleHit->{_column_data}) . ":");
#
#                    if ( $titleHits->{'count'} == 0 || !defined $titleHits->{'records'}->[0] || !defined($titleHits->{'records'}->[0]->field("001")) || $titleHits->{'records'}->[0]->field("001")->data() != $auftragsPosition->{'artikelNummer'} || !defined($titleHits->{'records'}->[0]->field("003")) || $titleHits->{'records'}->[0]->field("003")->data() ne "DE-Rt5" ) {
#                        # search the biblio record; if not found, create the biblio record in the '$updOrInsItemsCount < $deliveredItemsCount' block below (= method4)
#
#                        $titleHits = { 'count' => 0, 'records' => [] };
#                        $biblionumber = 0;
#                        $biblioExisting = 0;
#                        $lsEkzArtikelNr = '';
#                        # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
#                        $titleHits = $ekzKohaRecord->readTitleInLocalDB($reqParamTitelInfo, 7, 1);
#                        $logger->trace("genKohaRecords() method2: from local DB titleHits->{'count'}:" . $titleHits->{'count'} . ":");
#                        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
#                            $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
#                            my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
#                            my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
#                            if ( $tmp_cna eq "DE-Rt5" ) {
#                                $lsEkzArtikelNr = $tmp_cn;
#                            } else {
#                                $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
#                            }
#                            $biblioExisting = 1;    # this flag may be required in method 4
#                            # positive message for log email
#                            $emaillog->{'importresult'} = 2;
#                            $emaillog->{'importedTitlesCount'} += 0;
#
#                            # add result of finding biblio to log email
#                            ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
#                            push @{$emaillog->{'records'}}, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
#                            $logger->trace("genKohaRecords() method3: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
#                        } else {
#                            last;   # create the biblio record in the '$updOrInsItemsCount < $deliveredItemsCount' block below (= method4)
#                        }
#                    }
#
#                    # for this title: search all records in acquisition_import representing its items that are 'ordered' (i.e. can still be delivered)
#                    my $selParam = {
#                        vendor_id => "ekz",
#                        object_type => "order",
#                        object_reference => $acquisitionImportTitleHit->get_column('id'),
#                        rec_type => "item",
#                        processingstate => 'ordered'
#                    };
#                    my $acquisitionImportTitleItemHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
#                    $logger->trace("genKohaRecords() method2: scalar acquisitionImportTitleItemHits:" . scalar $acquisitionImportTitleItemHits . ":");
#
#                    foreach my $acquisitionImportTitleItemHit ($acquisitionImportTitleItemHits->all()) {
#                        $logger->trace("genKohaRecords() method2: acquisitionImportTitleItemHit->{_column_data}:" . Dumper($acquisitionImportTitleItemHit->{_column_data}) . ":");
#                        if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
#                            last;    # now all $deliveredItemsCount delivered items have been handled 
#                        }
#
#                        &processItemHit($lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsEkzArtikelNr, '', $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId, $logger);
#                    }
#                }
#            }    # end method3
#            $logger->debug("genKohaRecords() after method 3 deliveredItemsCount:$deliveredItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: lsEkzArtikelNr:$lsEkzArtikelNr:");


            # method4 is for all items for which no acquisition_import record representing the order title could be found
            # If not enough matching items could be found, then we suppose a 'monograph' order (i.e. not standing, not serial) and create the corresponding entries for the remaining items.
            if ( $updOrInsItemsCount < $deliveredItemsCount) {
                $logger->debug("genKohaRecords() method4: create item for ekzArtikelNr:$auftragsPosition->{'artikelNummer'}:");

                if ( $titleHits->{'count'} == 0 || !defined $titleHits->{'records'}->[0] || !defined($titleHits->{'records'}->[0]->field("001")) || $titleHits->{'records'}->[0]->field("001")->data() != $auftragsPosition->{'artikelNummer'} || !defined($titleHits->{'records'}->[0]->field("003")) || $titleHits->{'records'}->[0]->field("003")->data() ne "DE-Rt5" ) {

                    # get additional fields of title data
                    $reqParamTitelInfo->{'ekzArtikelArt'}  = $auftragsPosition->{'artikelart'};    # TODO: this is not a code value as in BestellInfo, but plain text (e.g. 'Bücher' instead of 'B', so a mapping function is required
                    my $autorTitel = $auftragsPosition->{'autorTitel1'} . $auftragsPosition->{'autorTitel2'};
                    my ($author, $titel) = split(':',$autorTitel);
                    $reqParamTitelInfo->{'author'} = $author;
                    $reqParamTitelInfo->{'titel'} = $titel;
                    if ( $auftragsPosition->{'waehrung'} eq 'EUR' && defined($auftragsPosition->{'verkaufsPreis'}) ) {
                        $reqParamTitelInfo->{'preis'} = $auftragsPosition->{'verkaufsPreis'};    # without regard to $auftragsPosition->{'nachlass'}
                    }
                    $reqParamTitelInfo->{'auflage'} = $auftragsPosition->{'auflageText'};
                    $logger->debug("genKohaRecords() method4: reqParamTitelInfo->{'ekzArtikelNr'}:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ":");

                    $titleHits = { 'count' => 0, 'records' => [] };
                    $biblionumber = 0;
                    $biblioExisting = 0;
                    $lsEkzArtikelNr = '';

                    # New method of title search/identification since 2023-01:
                    # In a first run ($searchmode==1):
                    #   If ekzArtikelNr was sent in the request (in XML element artikelNummer) (and if it is != 0, of course):
                    #       Search in local database for cna = 'DE-Rt5' and cn = <ekzArtikelNr>.
                    #       If titles are found, take the one with the highest biblionumber. Only the items have to be added.
                    #
                    # In a second run (required only if title not found yet) ($searchmode==2):
                    #   Search in local database for ISBN, ISSN, ISMN, EAN (if at least one of those fields was sent in the request)
                    #   with additional condition for publishing year, if SOAP parameter 'erscheinungsJahr' is sent by ekz (possibly in the future).
                    #
                    # In a third run (required only if title not found yet) ($searchmode==2):
                    #   Search in different title sources in the sequence stored in system preference 'ekzTitleDataServicesSequence':
                    #       title source '_LMSC':
                    #           (will only be done in certain constellations of second run ($searchmode==2))
                    #           Search title in LMSPool using isbn / isbn13; if not found, search for issn / ismn / ean.
                    #       title source '_EKZWSMD':
                    #           (will only be done in certain constellations of second run ($searchmode==2))
                    #           Search via the ekz title information webservice ('MedienDaten') using ekzArtikelNr.
                    #       title source '_WS':
                    #           Use the sparse title data from the LieferscheinDetailResponseElement (tag auftragsPosition) for creating a title entry.
                    #       other title source:
                    #           The name of the title source is used as a name of a Z39/50 target with z3950servers.servername; a z39/50 query is sent to this target.
                    #
                    #   Now a title record has been found or has to be created in Koha with data from one of these alternatives, and an item record for each ordered copy has to be created.

                    # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
                    my $titleSelHashkey =
                        ( $reqParamTitelInfo->{'ekzArtikelNr'} ? $reqParamTitelInfo->{'ekzArtikelNr'} : '' ) . '.' .
                        ( $reqParamTitelInfo->{'isbn'} ? $reqParamTitelInfo->{'isbn'} : '' ) . '.' .
                        ( $reqParamTitelInfo->{'isbn13'} ? $reqParamTitelInfo->{'isbn13'} : '' ) . '.' .
                        ( $reqParamTitelInfo->{'issn'} ? $reqParamTitelInfo->{'issn'} : '' ) . '.' .
                        ( $reqParamTitelInfo->{'ismn'} ? $reqParamTitelInfo->{'ismn'} : '' ) . '.' .
                        ( $reqParamTitelInfo->{'ean'} ? $reqParamTitelInfo->{'ean'} : '' ) . '.';
                    $logger->debug("genKohaRecords() method4: titleSelHashkey:$titleSelHashkey:");

                    if ( length($titleSelHashkey) > 6 && defined( $createdTitleRecords->{$titleSelHashkey} ) ) {
                        $titleHits = $createdTitleRecords->{$titleSelHashkey}->{titleHits};
                        $biblionumber = $createdTitleRecords->{$titleSelHashkey}->{biblionumber};
                        $logger->info("genKohaRecords() method4: got used biblionumber:$biblionumber: from createdTitleRecords->{$titleSelHashkey}");
                    }

                    my @titleSourceSequence = split('\|',$titleSourceSequence);
                    my $volumeEkzArtikelNr = undef;

                    # searchmode 1: search in local database for cn==ekzArtikelNr and cna=='DE-Rt5'
                    # searchmode 2: search in local database for ISBN/ISBN13/ISMN/ISSN/EAN, and for publication year if parameter erscheinungsJahr is sent by ekz LieferscheinDetail (in future).
                    #               If no title found, then try to get title via LMS Pool search and ekz Webservice 'MedienDaten' request.
                    # searchmode 4: search in local database for author && title && publication year. Only used by webservice DublettenCheck ($strictMatch==0).
                    for ( my $searchmode = 1; $searchmode <= 2; $searchmode *= 2 ) {
                        $logger->info("genKohaRecords() method4: in loop searchmode:$searchmode: ekzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                            my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                            my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                            if ( $tmp_cna eq "DE-Rt5" ) {
                                $lsEkzArtikelNr = $tmp_cn;
                            } else {
                                $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                            }
                            $logger->debug("genKohaRecords() method4: in loop last; searchmode:$searchmode: ekzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": biblionumber:" . $biblionumber . ": lsEkzArtikelNr:" . $lsEkzArtikelNr . ":");
                            last;    # title data have been found in lastly tested title source
                        }
                        if ( $searchmode == 1 && ! $reqParamTitelInfo->{'ekzArtikelNr'} ) {
                            $logger->debug("genKohaRecords() method4: in loop next1; searchmode:$searchmode: ekzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                            next;    # ekzArtikelNr not sent in request, so search for remaining criteria (ISBN, EAN, etc.)
                        }
                        $titleHits = $ekzKohaRecord->readTitleInLocalDB($reqParamTitelInfo, $searchmode, 1);
                        $logger->info("genKohaRecords() method4: from local DB searchmode:$searchmode: titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                            $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                            $logger->debug("genKohaRecords() method4: in loop next2; searchmode:$searchmode: ekzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": biblionumber:" . $biblionumber . ":");
                            next;
                        }
                        if ( $searchmode < 2 ) {
                            next;
                        }

                        foreach my $titleSource (@titleSourceSequence) {
                            $logger->info("genKohaRecords() method4: searchmode:$searchmode: in loop titleSource:$titleSource:");
                            if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                                last;    # title data have been found in lastly tested title source
                            }

                            if ( $titleSource eq '_LMSC' ) {
                                if ( $searchmode == 2 ) {
                                    # search title in LMSPool
                                    $titleHits = $ekzKohaRecord->readTitleInLMSPool($reqParamTitelInfo, $searchmode);
                                    $logger->info("genKohaRecords() method4: from LMS Pool searchmode:$searchmode: titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                                }
                            } elsif ( $titleSource eq '_EKZWSMD' ) {
                                if ( $searchmode == 2 ) {
                                    # send query to the ekz title information webservice 'MedienDaten'
                                    # (This is the only case where we handle series titles in addition to the volume title.)
                                    $titleHits = $ekzKohaRecord->readTitleFromEkzWsMedienDaten($reqParamTitelInfo->{'ekzArtikelNr'});
                                    $logger->info("genKohaRecords() method4: from ekz Webservice 'MedienDaten' searchmode:$searchmode: titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                                    if ( $titleHits->{'count'} > 1 ) {
                                        $volumeEkzArtikelNr = $reqParamTitelInfo->{'ekzArtikelNr'};
                                    }
                                }
                            } elsif ( $titleSource eq '_WS' ) {
                                if ( $searchmode == 2 ) {
                                    # use sparse title data from the LieferscheinDetailElement
                                    $titleHits = $ekzKohaRecord->createTitleFromFields($reqParamTitelInfo);    # creates marc data, not a biblio DB record
                                    $logger->info("genKohaRecords() method4: from sent titel fields searchmode:$searchmode: titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                                }
                            } else {    # in this case $titleSource contains the name of a Z39/50 target
                                if ( $searchmode == 2 ) {
                                    # search title in the Z39.50 target with z3950servers.servername=$titleSource
                                    $titleHits = $ekzKohaRecord->readTitleFromZ3950Target($titleSource,$reqParamTitelInfo);
                                    $logger->info("genKohaRecords() method4: from z39.50 search on target:" . $titleSource . ": searchmode:$searchmode: titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                                }
                            }
                        }
                    }


                    if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                        if ( $biblionumber == 0 ) {    # title data have been found in one of the sources, but not in local DB
                            # Create a biblio record in Koha and enrich it with values of the hits found in one of the title sources.
                            my $newrec;
                            # addNewRecords() also registers all added new records in $createdTitleRecords
                            ($biblionumber,$biblioitemnumber,$newrec) = $ekzKohaRecord->addNewRecords($titleHits, $volumeEkzArtikelNr, $ekzBestellNr, $ekzWsHideOrderedTitlesInOpac, $createdTitleRecords, $titleSelHashkey);
                            $logger->info("genKohaRecords() method4: new biblionumber:" . $biblionumber . ": biblioitemnumber:" . $biblioitemnumber . ":");
                            $logger->debug("genKohaRecords() method4: titleHits:" . Dumper($titleHits) . ":");
                            $logger->trace("genKohaRecords() method4: titleSelHashkey:" . $titleSelHashkey . ": createdTitleRecords->{titleSelHashkey}->{biblionumber}:" . $createdTitleRecords->{$titleSelHashkey}->{biblionumber} . ": ->{titleHits}:" . Dumper($createdTitleRecords->{$titleSelHashkey}->{titleHits}) . ":");

                            if ( defined $biblionumber && $biblionumber > 0 ) {
                                $updatedTitleRecords->{$biblionumber} = $biblionumber;    # it makes no sense to overwrite title data that have been inserted in this run
                                $biblioInserted = 1;
                                # positive message for log
                                $emaillog->{'importresult'} = 1;
                                $emaillog->{'importedTitlesCount'} += 1;
                            } else {
                                # negative message for log
                                $emaillog->{'problems'} .= "\n" if ( $emaillog->{'problems'} );
                                $emaillog->{'problems'} .= "ERROR: Import der Titeldaten für EKZ Artikel: $reqParamTitelInfo->{'ekzArtikelNr'} wurde abgewiesen.\n";
                                $emaillog->{'importresult'} = -1;
                                $emaillog->{'importerror'} = 1;
                            }
                        } else {    # title record has been found in local database
                            $biblioExisting = 1;

                            # Check if to reread title data via webservice MedienDaten etc. and, if required, (partially) overwrite the title record.
                            $ekzKohaRecord->overwriteCatalogDataIfRequired($ekzCustomerNumber, $biblionumber, $reqParamTitelInfo, $titleHits->{'records'}->[0], $updatedTitleRecords);

                            # positive message for log
                            $emaillog->{'importresult'} = 2;
                            $emaillog->{'importedTitlesCount'} += 0;
                        }
                        my $tmp_biblionumber = defined($biblionumber) ? $biblionumber : "undef";
                        my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        if ( $tmp_cna eq "DE-Rt5" ) {
                            my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $tmp_biblionumber;
                            $lsEkzArtikelNr = $tmp_cn;
                        }
                        # add result of adding biblio to log email
                        ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
                        push @{$emaillog->{'records'}}, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                    }
                }
                $logger->info("genKohaRecords() method4: biblioExisting:$biblioExisting: biblioInserted:$biblioInserted: biblionumber:$biblionumber: lsEkzArtikelNr:$lsEkzArtikelNr:");

                # now add the acquisition_import and acquisition_import_objects record for the title
                if ( $biblioExisting || $biblioInserted ) {

                    if ( !defined($lsEkzArtikelNr) || $lsEkzArtikelNr eq '0' || $lsEkzArtikelNr eq '' ) {
                        my $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                        my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                        my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                        $logger->info("genKohaRecords() method4: created fallback lsEkzArtikelNr:$lsEkzArtikelNr:");
                    }
                    $logger->debug("genKohaRecords() method4: using lsEkzArtikelNr:$lsEkzArtikelNr:");

                    # Insert a record into table acquisition_import representing the title data of the 'invented' order.
                    my $insParam = {
                        #id => 0, # AUTO
                        vendor_id => "ekz",
                        object_type => "order",
                        object_number => $ekzBestellNr,
                        object_date => DateTime::Format::MySQL->format_datetime($bestellDatum),    # in local time_zone
                        rec_type => "title",
                        object_item_number => $lsEkzArtikelNr . '',
                        processingstate => "ordered",
                        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                        #payload => NULL, # NULL
                        object_reference => $acquisitionImportIdLieferschein
                    };
                    my $acquisitionImportTitle = Koha::AcquisitionImport::AcquisitionImports->new();
                    my $acquisitionImportTitleRS = $acquisitionImportTitle->_resultset()->create($insParam);
                    my $acquisitionImportIdTitle = $acquisitionImportTitleRS->get_column('id');
                    $logger->trace("genKohaRecords() method4: acquisitionImportTitleRS->{_column_data}:" . Dumper($acquisitionImportTitleRS->{_column_data}) . ":");

                    # Insert a record into table acquisition_import_object representing the Koha title data of the 'invented' order.
                    $insParam = {
                        #id => 0, # AUTO
                        acquisition_import_id => $acquisitionImportIdTitle,
                        koha_object => "title",
                        koha_object_id => $biblionumber . ''
                    };
                    my $titleImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                    my $titleImportObjectRS = $titleImportObject->_resultset()->create($insParam);
                    $logger->trace("genKohaRecords() method4: titleImportObjectRS->{_column_data}:" . Dumper($titleImportObjectRS->{_column_data}) . ":");

                    # Insert a record into table acquisition_import representing the delivery note title.
                    $insParam = {
                        #id => 0, # AUTO
                        vendor_id => "ekz",
                        object_type => "delivery",
                        object_number => $lieferscheinNummer,
                        object_date => DateTime::Format::MySQL->format_datetime($lieferscheinDatum),
                        rec_type => "title",
                        object_item_number => $lsEkzArtikelNr . '',
                        processingstate => "delivered",
                        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                        #payload => NULL, # NULL
                        object_reference => $acquisitionImportIdTitle
                    };
                    my $acquisitionImportTitleDelivery = Koha::AcquisitionImport::AcquisitionImports->new();
                    my $acquisitionImportTitleDeliveryRS = $acquisitionImportTitleDelivery->_resultset()->create($insParam);
                    $logger->trace("genKohaRecords() method4: acquisitionImportTitleDeliveryRS->{_column_data}:" . Dumper($acquisitionImportTitleDeliveryRS->{_column_data}) . ":");


                    # now add the items data for the new biblionumber
                    my $ekzExemplarID = $ekzBestellNr . '-' . $lsEkzArtikelNr;    # dummy item number for the 'invented' order
                    my $exemplarcount = $deliveredItemsCount - $updOrInsItemsCount;
                    $logger->trace("genKohaRecords() method4: exemplar ekzExemplarID:$ekzExemplarID: exemplarcount:$exemplarcount:");

                    # attaching ekz order to Koha acquisition: 
                    # If system preference ekzAqbooksellersId is not empty: create a Koha order basket for collecting the Koha orders created for each title contained in the request that can not be assigned to an existing order.
                    # policy: If ekzAqbooksellersId is not empty but does not identify an aqbooksellers record: create such an record and update ekzAqbooksellersId.
                    $ekzAqbooksellersId = $ekzKohaRecord->checkEkzAqbooksellersId($ekzAqbooksellersId,1);
                    if ( length($ekzAqbooksellersId) ) {
                        # Search or create a Koha acquisition order basket,
                        # i.e. search / insert a record in table aqbasket so that the following new aqorders records can link to it via aqorders.basketno = aqbasket.basketno .
                        my $basketname = 'L-' . $lieferscheinNummer . '/' .  'L-' . $lieferscheinNummer;
                        my $selbaskets = C4::Acquisition::GetBaskets( { 'basketname' => "\'$basketname\'" } );
                        if ( @{$selbaskets} > 0 ) {
                            $basketno = $selbaskets->[0]->{'basketno'};
                            $authorisedby = $selbaskets->[0]->{'authorisedby'};
                            $logger->info("genKohaRecords() method4: found aqbasket with basketname:$basketname: having basketno:" . $basketno . ":");
                        } else {
                            my $patron = Koha::Patrons->find( { surname => 'LCService' } );
                            if ( $patron ) {
                                $authorisedby = $patron->borrowernumber();
                                $logger->info("genKohaRecords() method4: found patron with surname = 'LCService' authorisedby:" . $authorisedby . ":");
                            }
                            my $branchcode = $ekzKohaRecord->branchcodeFallback('', $homebranch);
                            $basketno = C4::Acquisition::NewBasket($ekzAqbooksellersId, $authorisedby, $basketname, 'created by ekz LieferscheinDetail', '', undef, $branchcode, $branchcode, 0, 'ordering');    # XXXWH fixed text ok?
                            $logger->trace("genKohaRecords() method4: created new basket having basketno:" . Dumper($basketno) . ":");
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
                    $logger->info("genKohaRecords() method4: ekzAqbooksellersId:$ekzAqbooksellersId: acquisitionError:$acquisitionError: basketno:$basketno:");

                    # Get price info from auftragPosition of sent message, for creating aqorders and items records.
                    my $priceInfo = priceInfoFromMessage($lieferscheinRecord, $auftragsPosition, $logger);
                    # Attaching ekz order to Koha acquisition: Create a new Koha::Acquisition::Order in the same way as for a invoice.

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

                        my $haushaltsstelle = "";    # not sent in LieferscheinDetailResponseElement
                        my $kostenstelle = "";    # not sent in LieferscheinDetailResponseElement

                        my ($dummy1, $dummy2, $budgetid, $dummy3) = $ekzKohaRecord->checkAqbudget($ekzCustomerNumber, $haushaltsstelle, $kostenstelle, 1);

                        my $orderinfo = ();

                        # ordernumber is set by DBS
                        $orderinfo->{biblionumber} = $biblionumber;
                        # entrydate is set to today by Koha::Acquisition::Order->insert()
                        $orderinfo->{quantity} = $exemplarcount;
                        $orderinfo->{currency} = $priceInfo->{waehrung};    # currency of bookseller's list price
                        # XXXWH currency-Umrechnung fehlt in die eine oder andere Richtung
                        $orderinfo->{listprice} = $priceInfo->{verkaufsPreis};    # input field 'Vendor price' in UI (in foreign currency, not discounted, per item)
                        $orderinfo->{unitprice} = 0.0;    #  corresponds to input field 'Actual cost' in UI (discounted) and will be initialized with budgetedcost in the GUI in 'receiving' step
                        $orderinfo->{unitprice_tax_excluded} = 0.0;
                        $orderinfo->{unitprice_tax_included} = 0.0;
                        # quantityreceived is set to 0 by DBS
                        $orderinfo->{created_by} = $authorisedby;
                        $orderinfo->{order_internalnote} = '';
                        $orderinfo->{order_vendornote} = sprintf("Bestellung:\nVerkaufspreis: %.2f %s (Exemplare: %d)\n", $priceInfo->{verkaufsPreis}, $priceInfo->{waehrung}, $priceInfo->{exemplareBestellt});
                        if ( $priceInfo->{nachlass} != 0.0 ) {
                            $orderinfo->{order_vendornote} .= sprintf("Nachlass: %.2f %s\n", $priceInfo->{nachlass}, $priceInfo->{waehrung});
                        }
                        if ( $priceInfo->{wertPositionsTeil} != 0.0 ) {
                            $orderinfo->{order_vendornote} .= sprintf("Positionsteilwert: %.2f %s\n", $priceInfo->{wertPositionsTeil}, $priceInfo->{waehrung});
                        }
                        if ( $priceInfo->{wertMehrpreise} != 0.0 ) {
                            $orderinfo->{order_vendornote} .= sprintf("Mehrpreis: %.2f %s\n", $priceInfo->{wertMehrpreise}, $priceInfo->{waehrung});
                        }
                        if ( $priceInfo->{wertBearbeitung} != 0.0 ) {
                            $orderinfo->{order_vendornote} .= sprintf("Bearbeitungspreis: %.2f %s\n", $priceInfo->{wertBearbeitung}, $priceInfo->{waehrung});
                        }
                        $orderinfo->{basketno} = $basketno;
                        # timestamp is set to now by DBS
                        $orderinfo->{budget_id} = $budgetid;
                        $orderinfo->{'uncertainprice'} = 0;
                        $orderinfo->{subscriptionid} = undef;
                        $orderinfo->{orderstatus} = 'ordered';
                        $orderinfo->{rrp} = $priceInfo->{replacementcost_tax_included};    #  corresponds to input field 'Replacement cost' in UI (not discounted, per item)
                        $orderinfo->{replacementprice} = $priceInfo->{replacementcost_tax_included};
                        $orderinfo->{rrp_tax_excluded} = $priceInfo->{replacementcost_tax_excluded};
                        $orderinfo->{rrp_tax_included} = $priceInfo->{replacementcost_tax_included};
                        $orderinfo->{ecost} = $priceInfo->{gesamtpreis_tax_included};     #  corresponds to input field 'Budgeted cost' in UI (discounted, per item)
                        $orderinfo->{ecost_tax_excluded} = $priceInfo->{gesamtpreis_tax_excluded};    # discounted
                        $orderinfo->{ecost_tax_included} = $priceInfo->{gesamtpreis_tax_included};    # discounted
                        $orderinfo->{tax_rate_bak} = $priceInfo->{ustSatz};        #  corresponds to input field 'Tax rate' in UI (7% are stored as 0.07)
                        $orderinfo->{tax_rate_on_ordering} = $priceInfo->{ustSatz};
                        $orderinfo->{tax_rate_on_receiving} = undef;    # setting to NULL
                        $orderinfo->{tax_value_bak} = $priceInfo->{ust};        #  corresponds to input field 'Tax value' in UI
                        $orderinfo->{tax_value_on_ordering} = $priceInfo->{ust};
                        # XXXWH or alternatively: $orderinfo->{tax_value_on_ordering} = $orderinfo->{quantity} * $orderinfo->{ecost_tax_excluded} * $orderinfo->{tax_rate_on_ordering};    # see C4::Acquisition.pm
                        $orderinfo->{tax_value_on_receiving} = undef;    # setting to NULL
                        $orderinfo->{discount} = $priceInfo->{rabatt};        #  corresponds to input field 'Discount' in UI (5% are stored as 5.0)
                        # XXXWH activate logger! $logger->trace("genKohaRecords() method4: trying to create Koha order with orderinfo:" . Dumper($orderinfo) . ":");

                        $order = Koha::Acquisition::Order->new($orderinfo);
                        $order->store();
                        $ordernumber = $order->ordernumber();    # ordernumber value has been created by DBS
                    }

                    for ( my $j = 0; $j < $exemplarcount; $j++ ) {
                        $emaillog->{'problems'} = '';              # string for accumulating error messages for this order
                        my $item_hash;

                        $emaillog->{'processedItemsCount'} += 1;

                        $item_hash->{homebranch} = $zweigstellencode;
                        $item_hash->{booksellerid} = 'ekz';
                        if ( $auftragsPosition->{'waehrung'} eq 'EUR' && defined($auftragsPosition->{'verkaufsPreis'}) ) {
                            $item_hash->{price} = $priceInfo->{gesamtpreis_tax_included};
                            $item_hash->{replacementprice} = $priceInfo->{replacementcost_tax_included};    # without regard to $auftragsPosition->{'nachlass'}
                        }
                        $item_hash->{notforloan} = 0;    # item delivered -> can be loaned

                        $item_hash->{biblionumber} = $biblionumber;
                        $item_hash->{biblioitemnumber} = $biblionumber;
                        my $kohaItem = Koha::Item->new( $item_hash )->store;
                        my $itemnumber = $kohaItem->itemnumber;

                        if ( defined $itemnumber && $itemnumber > 0 ) {

                            # update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenOrdered> where itemnumber = <itemnumber from above Koha::Item->new()->store() call>
                            my $itemHitRs = Koha::Items->new()->_resultset();
                            my $itemSelParam = { itemnumber => $itemnumber };
                            my $itemHitCount = $itemHitRs->count( $itemSelParam );
                            my $itemHit = $itemHitRs->find( $itemSelParam );
                            $logger->trace("genKohaRecords() method4: searched first time for itemnumber:$itemnumber: itemHitCount:$itemHitCount: itemHit->{_column_data}:" . Dumper($itemHit->{_column_data}) . ":");
                            if ( $itemHitCount > 0 && defined($itemHit->{_column_data}) ) {
                                # configurable items record field initialization via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered")
                                # e.g. setting the 'item ordered' state in items.notforloan
                                if ( defined($ekzWebServicesSetItemSubfieldsWhenOrdered) && length($ekzWebServicesSetItemSubfieldsWhenOrdered) > 0 ) {
                                    my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenOrdered;
                                    $logger->debug("genKohaRecords() method4: has to do " . scalar @affects . " affects (ordering)");
                                    if ( @affects ) {
                                        my $frameworkcode = C4::Biblio::GetFrameworkCode($biblionumber);
                                        my ( $itemfield ) = C4::Biblio::GetMarcFromKohaField( 'items.itemnumber', $frameworkcode );
                                        my $item = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
                                        if ( $item ) {
                                            for my $affect ( @affects ) {
                                                my ( $sf, $v ) = split('=', $affect, 2);
                                                foreach ( $item->field($itemfield) ) {
                                                        $_->update( $sf => $v );
                                                }
                                            }
                                            C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber );
                                        }
                                    }
                                }
                            }

                            # update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenReceived> where itemnumber = <itemnumber from above Koha::Item->new()->store() call>
                            $itemHitCount = $itemHitRs->count( $itemSelParam );
                            $itemHit = $itemHitRs->find( $itemSelParam );
                            $logger->trace("genKohaRecords() method4: searched second time for itemnumber:$itemnumber: itemHitCount:$itemHitCount: itemHit->{_column_data}:" . Dumper($itemHit->{_column_data}) . ":");
                            if ( $itemHitCount > 0 && defined($itemHit->{_column_data}) ) {
                                # configurable items record field update via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenReceived")
                                # e.g. setting the 'item available' state (or 'item processed internally' state) in items.notforloan
                                if ( defined($ekzWebServicesSetItemSubfieldsWhenReceived) && length($ekzWebServicesSetItemSubfieldsWhenReceived) > 0 ) {
                                    my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenReceived;
                                    $logger->debug("genKohaRecords() method4: has to do " . scalar @affects . " affects (receiving)");
                                    if ( @affects ) {
                                        my $frameworkcode = C4::Biblio::GetFrameworkCode($biblionumber);
                                        my ( $itemfield ) = C4::Biblio::GetMarcFromKohaField( 'items.itemnumber', $frameworkcode );
                                        my $item = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
                                        if ( $item ) {
                                            for my $affect ( @affects ) {
                                                my ( $sf, $v ) = split('=', $affect, 2);
                                                foreach ( $item->field($itemfield) ) {
                                                    $_->update( $sf => $v );
                                                }
                                            }
                                            C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber );
                                        }
                                    }
                                }
                            }

                            # attaching ekz order to Koha acquisition: Insert an additional aqordersitem for the aqorder.
                            if ( defined($order) ) {
                                $order->add_item($itemnumber);
                            }

                            # Insert a record into table acquisition_import representing the item data of the 'invented' order.
                            my $insParam = {
                                #id => 0, # AUTO
                                vendor_id => "ekz",
                                object_type => "order",
                                object_number => $ekzBestellNr,
                                object_date => DateTime::Format::MySQL->format_datetime($bestellDatum),    # in local time_zone
                                rec_type => "item",
                                object_item_number => $ekzExemplarID . '',
                                processingstate => "delivered",
                                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                                #payload => NULL, # NULL
                                object_reference => $acquisitionImportIdTitle
                            };
                            my $acquisitionImportItem = Koha::AcquisitionImport::AcquisitionImports->new();
                            my $acquisitionImportItemRS = $acquisitionImportItem->_resultset()->create($insParam);
                            my $acquisitionImportIdItem = $acquisitionImportItemRS->get_column('id');
                            $logger->trace("genKohaRecords() method4: acquisitionImportItemRS->{_column_data}:" . Dumper($acquisitionImportItemRS->{_column_data}) . ":");

                            # Insert a record into acquisition_import_object representing the Koha item data.
                            $insParam = {
                                #id => 0, # AUTO
                                acquisition_import_id => $acquisitionImportIdItem,
                                koha_object => "item",
                                koha_object_id => $itemnumber . ''
                            };
                            my $itemImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                            my $itemImportObjectRS = $itemImportObject->_resultset()->create($insParam);
                            $logger->trace("genKohaRecords() method4: itemImportObjectRS->{_column_data}:" . Dumper($itemImportObjectRS->{_column_data}) . ":");

                            # Insert a record into table acquisition_import representing the the delivery note item data.
                            $insParam = {
                                #id => 0, # AUTO
                                vendor_id => "ekz",
                                object_type => "delivery",
                                object_number => $lieferscheinNummer,
                                object_date => DateTime::Format::MySQL->format_datetime($lieferscheinDatum),
                                rec_type => "item",
                                object_item_number => $lieferscheinNummer . '-' . $lsEkzArtikelNr,
                                processingstate => "delivered",
                                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                                #payload => NULL, # NULL
                                object_reference => $acquisitionImportIdItem
                            };
                            my $acquisitionImportItemDelivery = Koha::AcquisitionImport::AcquisitionImports->new();
                            my $acquisitionImportItemDeliveryRS = $acquisitionImportItemDelivery->_resultset()->create($insParam);
                            $logger->trace("genKohaRecords() method4: acquisitionImportItemDeliveryRS->{_column_data}:" . Dumper($acquisitionImportItemDeliveryRS->{_column_data}) . ":");

                            if ( $biblioExisting && $emaillog->{'foundTitlesCount'} == 0 ) {
                                $emaillog->{'foundTitlesCount'} = 1;
                            }
                            $updOrInsItemsCount += 1;
                            # positive message for log email
                            $emaillog->{'importresult'} = 1;
                            $emaillog->{'importedItemsCount'} += 1;
                        } else {
                            # negative message for log
                            $emaillog->{'problems'} .= "\n" if ( $emaillog->{'problems'} );
                            $emaillog->{'problems'} .= "ERROR: Import der Exemplardaten für EKZ Exemplar-ID: $ekzExemplarID wurde abgewiesen.\n";
                            $emaillog->{'importresult'} = -1;
                            $emaillog->{'importerror'} = 1;
                        }
                        my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                        my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        my $importId = '(ControlNumber)' . $tmp_cn . '(ControlNrId)' . $tmp_cna;    # if cna = 'DE-Rt5' then this cn is the ekz article number
                        $emaillog->{'importIds'}->{$importId} = $itemnumber;
                        $logger->trace("genKohaRecords() method4: importedItemsCount:$emaillog->{'importedItemsCount'}: set next importId:" . $importId . ":");
                        # add result of inserting item to log email
                        my ($titeldata, $isbnean) = ($itemnumber, '');
                        push @{$emaillog->{'records'}}, [$lsEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2, $ordernumber, $basketno];
                        $logger->trace("genKohaRecords() method4: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
                        $logger->trace("genKohaRecords() method4: emaillog->{'records'}->[1]:" . Dumper($emaillog->{'records'}->[1]) . ":");
                    } # foreach remainig delivered items: create koha item record
                } # koha biblio data have been found or created
            } # end method4: "if ( $updOrInsItemsCount < $deliveredItemsCount)"
            $logger->debug("genKohaRecords() after method 4 deliveredItemsCount:$deliveredItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: lsEkzArtikelNr:$lsEkzArtikelNr:");



            # create @actionresult message for log email, representing 1 title with all its processed items
            my @actionresultTit = ( 'insertRecords', 0, "X", "Y", $emaillog->{'processedTitlesCount'}, $emaillog->{'importedTitlesCount'}, $emaillog->{'foundTitlesCount'}, $emaillog->{'processedItemsCount'}, $emaillog->{'importedItemsCount'}, $emaillog->{'updatedItemsCount'}, $emaillog->{'records'} );
            $logger->debug("genKohaRecords() actionresultTit:" . Dumper(\@actionresultTit) . ":");
            push @{$emaillog->{'actionresult'}}, \@actionresultTit;

        }

        # create @logresult message for log email, representing all titles of the current $lieferscheinResult with all their processed items
        push @{$emaillog->{'logresult'}}, ['LieferscheinDetail', $messageID, $emaillog->{'actionresult'}, $acquisitionError, $ekzAqbooksellersId, undef];    # arg basketno is undef, because with standing orders multiple delivery baskets are possible
        $logger->trace("genKohaRecords() Dumper(emaillog->{'logresult'}):" . Dumper($emaillog->{'logresult'}) . ":");

        # attaching ekz order to Koha acquisition:
        if ( length($ekzAqbooksellersId) && defined($basketno) && $basketno > 0 ) {
            # create a basketgroup for this basket and close both basket and basketgroup
            my $aqbasket = &C4::Acquisition::GetBasket($basketno);
            $logger->trace("genKohaRecords() Dumper aqbasket:" . Dumper($aqbasket) . ":");
            if ( $aqbasket ) {
                # close the basket
                $logger->debug("genKohaRecords() is calling Koha::Acquisition::Baskets->find(basketno:" . $aqbasket->{basketno} . ")");
                my $kohabasket = Koha::Acquisition::Baskets->find($aqbasket->{basketno});
                if ( $kohabasket ) {
                    $logger->debug("genKohaRecords() is calling Koha::Acquisition::Baskets->find(basketno:" . $aqbasket->{basketno} . ")->close");
                    $kohabasket->close;
                }

                # search/create basket group with aqbasketgroups.name = ekz order number and aqbasketgroups.booksellerid = and update aqbasket accordingly
                my $params = {
                    name => "\'$aqbasket->{basketname}\'",
                    booksellerid => $aqbasket->{booksellerid}
                };
                $basketgroupid  = undef;
                my $aqbasketgroups = &C4::Acquisition::GetBasketgroupsGeneric($params, { orderby => "id DESC" } );
                $logger->trace("genKohaRecords() Dumper aqbasketgroups:" . Dumper($aqbasketgroups) . ":");

                # create basket group if not existing
                if ( !defined($aqbasketgroups) || scalar @{$aqbasketgroups} == 0 ) {
                    $params = { 
                        name => "$aqbasket->{basketname}",
                        closed => 0,
                        booksellerid => $aqbasket->{booksellerid},
                        deliveryplace => "$aqbasket->{deliveryplace}",
                        freedeliveryplace => undef,    # setting to NULL
                        deliverycomment => undef,    # setting to NULL
                        billingplace => "$aqbasket->{billingplace}",
                    };
                    $basketgroupid  = &C4::Acquisition::NewBasketgroup($params);
                    $logger->trace("genKohaRecords() created basketgroup with name:" . $aqbasket->{basketname} . ": having basketgroupid:$basketgroupid:");
                } else {
                    $basketgroupid = $aqbasketgroups->[0]->{id};
                    $logger->trace("genKohaRecords() found basketgroup with name:" . $aqbasket->{basketname} . ": having basketgroupid:$basketgroupid:");
                }

                if ( $basketgroupid ) {
                    # update basket, i.e. set basketgroupid
                    my $basketinfo = {
                        'basketno' => $aqbasket->{basketno},
                        'basketgroupid' => $basketgroupid
                    };
                    &C4::Acquisition::ModBasket($basketinfo);

                    # close the basketgroup
                    $logger->trace("genKohaRecords() is calling CloseBasketgroup basketgroupid:$basketgroupid:");
                    &C4::Acquisition::CloseBasketgroup($basketgroupid);
                }
            }
        }
    }
    }
    catch {
        $exceptionThrown = $_;

        if (ref($exceptionThrown) eq 'Koha::Exceptions::WrongParameter') {
            $logger->error("genKohaRecords() caught WrongParameter exception:" . Dumper($exceptionThrown) . ":");
        } else {
            $logger->error("genKohaRecords() caught generic exception:" . Dumper($exceptionThrown) . ":");    # unbelievable: croak throws a string
        }

        $logger->error("genKohaRecords() roll back based on thrown exception");
        $schema->storage->txn_rollback;    # roll back the complete delivery note import, based on thrown exception
        if ( $createdTitleRecords ) {
            foreach my $titleSelHashkey ( sort keys %{$createdTitleRecords} ) {
                if ( $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} ) {
                    next;    # keep elements of createdTitleRecords of preceeding calls
                }
                my $biblionumber = $createdTitleRecords->{$titleSelHashkey}->{biblionumber};
                $logger->debug("genKohaRecords() is calling ekzKohaRecord->deleteFromIndex() with bibliomumber:" . (defined($biblionumber)?$biblionumber:'undef') . ":");
                $ekzKohaRecord->deleteFromIndex($biblionumber);
                $logger->debug("genKohaRecords() is deleting createdTitleRecords->{$titleSelHashkey}");
                delete $createdTitleRecords->{$titleSelHashkey};    # remove elements of createdTitleRecords of current call because this transaction is rolled back
            }
        }

        $exceptionThrown->throw();
    };

    # commit the complete delivery note import (only as a single transaction)
    $schema->storage->txn_commit;    # in case of a thrown exception this statement is not executed
    if ( $createdTitleRecords ) {
        foreach my $titleSelHashkey ( sort keys %{$createdTitleRecords} ) {
            if ( $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} ) {
                next;    # keep elements of createdTitleRecords of preceeding calls
            }
            $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} = 1;    # mark elements of createdTitleRecords newly added by current call as committed
            $logger->debug("genKohaRecords() has set createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted}:" . $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} . ":");
        }
    }

    if ( $emaillog && defined($emaillog->{'logresult'}) && scalar(@{$emaillog->{'logresult'}}) > 0 ) {
        my @importIds = keys %{$emaillog->{'importIds'}};
        ($message, $subject, $haserror) = $ekzKohaRecord->createProcessingMessageText($emaillog->{'logresult'}, "headerTEXT", $emaillog->{'dt'}, \@importIds, $lieferscheinNummer);
        $ekzKohaRecord->sendMessage($ekzCustomerNumber, $message, $subject);
    }

    return 1;
}


###################################################################################################
# Re-indexing of all titles registered in $updatedTitleRecords
###################################################################################################
sub updBiblioIndex {
    my ($updatedTitleRecords) = @_;
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsDeliveryNote' });

    $logger->debug("updBiblioIndex() Start updatedTitleRecords:" . Dumper($updatedTitleRecords) . ":");

    my @biblionumbers = ( sort keys %{$updatedTitleRecords} );
    if ( scalar @biblionumbers > 0 ) {
        my $ekzKohaRecord = C4::External::EKZ::lib::EkzKohaRecords->new();
        $logger->debug("updBiblioIndex() is calling ekzKohaRecord->updateInIndex() with biblionumbers:" . Dumper(@biblionumbers) . ":");
        $ekzKohaRecord->updateInIndex(@biblionumbers);
    }
    $logger->debug("updBiblioIndex() returns (scalar \@biblionumbers:" . scalar @biblionumbers . ":");
}


sub priceInfoFromMessage {
    my ($lieferscheinRecord, $auftragsPosition, $logger) = @_;
    $logger->trace("priceInfoFromMessage() Start auftragsPosition:" . Dumper($auftragsPosition) . ":");

    my $ekzInvoiceSkipAdditionalCosts = C4::Context->preference("ekzInvoiceSkipAdditionalCosts");    # 0 -> add wertMehrpreise and wertBearbeitung to wertPositionsTeil   1 -> skip wertMehrpreise and wertBearbeitung, i.e. take wertPositionsTeil only (as invoice item price)
    # At the moment ustProzentVoll and ustProzentHalb is not delivered by ekz in LieferscheinDetail response (only in RechnungDetail response).
    # So in reality this two lines always are an initlization via &C4::External::EKZ::lib::EkzKohaRecords::defaultUstSatz(...).
    my $ustProzentVoll = defined($lieferscheinRecord->{'ustProzentVoll'}) ? $lieferscheinRecord->{'ustProzentVoll'} : &C4::External::EKZ::lib::EkzKohaRecords::defaultUstSatz('V') * 100.0;    # e.g. 19.00 for VAT rate of 19% (0.19)
    my $ustProzentHalb = defined($lieferscheinRecord->{'ustProzentHalb'}) ? $lieferscheinRecord->{'ustProzentHalb'} : &C4::External::EKZ::lib::EkzKohaRecords::defaultUstSatz('E') * 100.0;    # e.g. 7.00 for VAT rate of 7% (0.07)
    my $priceInfo = {};

    $priceInfo->{exemplareBestellt} = defined($auftragsPosition->{'exemplareBestellt'}) && $auftragsPosition->{'exemplareBestellt'} != 0 ? $auftragsPosition->{'exemplareBestellt'} : "1";
    $priceInfo->{verkaufsPreis} = defined($auftragsPosition->{'verkaufsPreis'}) ? $auftragsPosition->{'verkaufsPreis'} : "0.00";
    $priceInfo->{nachlass} = defined($auftragsPosition->{'nachlass'}) ? $auftragsPosition->{'nachlass'} : "0.00";    # <nachlass> for all exemplareBestellt of this <auftragsPosition> in sum.
    $priceInfo->{nachlassProExemplar} = &C4::External::EKZ::lib::EkzKohaRecords::round( ($priceInfo->{nachlass} / ($priceInfo->{exemplareBestellt} * 1.0)), 2 );    # nachlass per exemplar
    $priceInfo->{rabatt} = "0.0";    # 'rabatt' not sent in LieferscheinDetailResponseElement.auftragsPosition, so we calculate it from verkaufsPreis and nachlass (15.0 means 15 %)
    if ( $priceInfo->{verkaufsPreis} != 0.0 ) {
        $priceInfo->{rabatt} = ($priceInfo->{nachlass} * 100.0) / ( $priceInfo->{verkaufsPreis} * $priceInfo->{exemplareBestellt} );    # (value 15.0 means 15 %)
    }
    # info by etecture (H. Appel): <wertPositionsTeil> = <verkaufsPreis> - <nachlass>
    # info by ekz (H. Hauke Laun): <wertPositionsTeil> = (<exemplareBestellt> * <verkaufsPreis>) - <nachlass>
    $priceInfo->{wertPositionsTeil} = defined($auftragsPosition->{'wertPositionsTeil'}) ? $auftragsPosition->{'wertPositionsTeil'} : "0.00";    # info by etecture: <wertPositionsTeil> = <verkaufsPreis> - <nachlass>
    $priceInfo->{wertMehrpreise} = defined($auftragsPosition->{'wertMehrpreise'}) ? $auftragsPosition->{'wertMehrpreise'} : "0.00";
    $priceInfo->{wertBearbeitung} = defined($auftragsPosition->{'wertBearbeitung'}) ? $auftragsPosition->{'wertBearbeitung'} : "0.00";
    $priceInfo->{waehrung} = defined($auftragsPosition->{'waehrung'}) ? $auftragsPosition->{'waehrung'} : "EUR";

    $priceInfo->{ust} = "0.00";    # 'ust' not sent in LieferscheinDetailResponseElement.auftragsPosition, so we will calculate it
    $priceInfo->{ustSatz} = $ustProzentHalb / 100.0;    # 'ustSatz' not sent in LieferscheinDetailResponseElement.auftragsPosition, so we evaluate XML element <ustProzentHalb> or <ustProzentVoll>
    $priceInfo->{mwst}  = defined($auftragsPosition->{'mwst'}) ? $auftragsPosition->{'mwst'} : "E";    # 'E':ermässigt 'V':voll
    if ( $priceInfo->{mwst} eq 'V') {
        $priceInfo->{ustSatz} = $ustProzentVoll / 100.0;
    }

    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it based on an info by etecture for LieferscheinDetail; total for a single item
    if ( $ekzInvoiceSkipAdditionalCosts ) {
        $priceInfo->{gesamtpreis_tax_included} = $priceInfo->{verkaufsPreis};
    } else {
        $priceInfo->{gesamtpreis_tax_included} = $priceInfo->{verkaufsPreis} + &C4::External::EKZ::lib::EkzKohaRecords::round( ($priceInfo->{wertMehrpreise} + $priceInfo->{wertBearbeitung}) / $priceInfo->{exemplareBestellt}, 2 );
    }

    if ( defined($auftragsPosition->{'wertPositionsTeil'}) ) {
        # obsolete hypotesis:
        ##   deduced from tests done in 2020-09: it seems that <wertMehrpreise> and <wertBearbeitung> are already contained in <verkaufsPreis>, so they must not be added to it
        ##   seems to be incorrect: $priceInfo->{gesamtpreis_tax_included} = $priceInfo->{wertPositionsTeil} + $priceInfo->{wertMehrpreise} + $priceInfo->{wertBearbeitung};    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item
        #$priceInfo->{gesamtpreis_tax_included} = $priceInfo->{wertPositionsTeil};    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item

        # Based on info by Hauke Laun the test quoted above was based on an invoice of Rechnungsstellungsart A.
        # Since 19.10.2020 the new system preference 'ekzInvoiceSkipAdditionalCosts' controls if the customer's invoices are treated conforming to Rechnungsstellungsart A or Rechnungsstellungsart B.
        if ( $ekzInvoiceSkipAdditionalCosts ) {
            $priceInfo->{gesamtpreis_tax_included} = &C4::External::EKZ::lib::EkzKohaRecords::round( $priceInfo->{wertPositionsTeil} / $priceInfo->{exemplareBestellt}, 2 );    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item
        } else {
            $priceInfo->{gesamtpreis_tax_included} = &C4::External::EKZ::lib::EkzKohaRecords::round( ($priceInfo->{wertPositionsTeil} + $priceInfo->{wertMehrpreise} + $priceInfo->{wertBearbeitung}) / $priceInfo->{exemplareBestellt}, 2 );    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item
        }
    } elsif ( defined($auftragsPosition->{'verkaufsPreis'}) && defined($auftragsPosition->{'nachlassProExemplar'}) ) {
        # obsolete hypotesis:
        ##   deduced from tests done in 2020-09: it seems that <wertMehrpreise> and <wertBearbeitung> are already contained in <verkaufsPreis>, so they must not be added to it
        ##   seems to be incorrect: $priceInfo->{gesamtpreis_tax_included} = $priceInfo->{verkaufsPreis} - $priceInfo->{nachlass} + $priceInfo->{wertMehrpreise} + $priceInfo->{wertBearbeitung};    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item
        #    $priceInfo->{gesamtpreis_tax_included} = $priceInfo->{verkaufsPreis} - $priceInfo->{nachlass};    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item

        # Based on info by Hauke Laun the test quoted above was based on an invoice of Rechnungsstellungsart A).
        # Since 19.10.2020 the new system preference 'ekzInvoiceSkipAdditionalCosts' controls if the customer's invoices are treated conforming to Rechnungsstellungsart A or Rechnungsstellungsart B.
        if ( $ekzInvoiceSkipAdditionalCosts ) {
            $priceInfo->{gesamtpreis_tax_included} = $priceInfo->{verkaufsPreis} - $priceInfo->{nachlassProExemplar};    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item
        } else {
            $priceInfo->{gesamtpreis_tax_included} = $priceInfo->{verkaufsPreis} - $priceInfo->{nachlassProExemplar} + &C4::External::EKZ::lib::EkzKohaRecords::round( ($priceInfo->{wertMehrpreise} + $priceInfo->{wertBearbeitung}) / $priceInfo->{exemplareBestellt}, 2 );    # 'gesamtpreis' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it; total for a single item
        }
    }
    if ( $priceInfo->{ust} == 0.0 && $priceInfo->{ustSatz} != 0.0 && $priceInfo->{ustSatz} != -1.0 ) {    # calculate ust from ustSatz
        $priceInfo->{ust} = $priceInfo->{gesamtpreis_tax_included} * $priceInfo->{ustSatz} / (1 + $priceInfo->{ustSatz});
        $priceInfo->{ust} =  &C4::External::EKZ::lib::EkzKohaRecords::round($priceInfo->{ust}, 2);
    }
    if ( $priceInfo->{ustSatz} == 0.0 && $priceInfo->{ust} != 0.0 && $priceInfo->{gesamtpreis_tax_included} != $priceInfo->{ust}) {    # calculate ustSatz from ust
        $priceInfo->{ustSatz} = $priceInfo->{ust} / ($priceInfo->{gesamtpreis_tax_included} - $priceInfo->{ust});
        $priceInfo->{ustSatz} =  &C4::External::EKZ::lib::EkzKohaRecords::round($priceInfo->{ustSatz}, 2);
    }
    my $divisor = 1.0 + $priceInfo->{ustSatz};

    $priceInfo->{gesamtpreis_tax_excluded} = $priceInfo->{gesamtpreis_tax_included};
    if ( defined( $priceInfo->{ust} ) ) {
        $priceInfo->{gesamtpreis_tax_excluded} = $priceInfo->{gesamtpreis_tax_included} - $priceInfo->{ust};
    } else {
        if ($divisor != 0 ) {
            $priceInfo->{gesamtpreis_tax_excluded} = $priceInfo->{gesamtpreis_tax_included} / $divisor;
        }
    }
    $priceInfo->{gesamtpreis_tax_excluded} = &C4::External::EKZ::lib::EkzKohaRecords::round($priceInfo->{gesamtpreis_tax_excluded}, 2);

    $priceInfo->{replacementcost_tax_included} = $priceInfo->{verkaufsPreis};    # list price of single item in library's currency, not discounted
    $priceInfo->{replacementcost_tax_excluded} = $divisor == 0.0 ? 0.0 : $priceInfo->{replacementcost_tax_included} / $divisor;
    $priceInfo->{replacementcost_tax_excluded} = &C4::External::EKZ::lib::EkzKohaRecords::round($priceInfo->{replacementcost_tax_excluded}, 2);

    $logger->trace("priceInfoFromMessage() returns priceInfo:" . Dumper($priceInfo) . ":");
    return $priceInfo;
}

sub processItemHit
{
    my ( $lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsArtikelNr, $lsReferenznummer, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog, $updOrInsItemsCountRef, $ekzAqbooksellersId, $logger ) = @_;
    my $selParam = '';
    my $updParam = '';
    my $insParam = '';
    my $order = undef;
    my $ordernumberFound = undef;
    my $basketnoFound = undef;

    # update the item's 'acquisition_import' record and the 'items' record in 3 steps:
    # 1. step: get itemnumber: select koha_object_id from acquisition_import_objects where acquisition_import_id = acquisition_import.id of current $acquisitionImportTitleItemHit
    $logger->info("processItemHit() update item for lsArtikelNr:$lsArtikelNr: lsReferenznummer:$lsReferenznummer:");
    $selParam = {
        acquisition_import_id => $acquisitionImportTitleItemHit->get_column('id'),
        koha_object => "item"
    };
    my $titleItemObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
    my $titleItemObjectRS = $titleItemObject->_resultset()->search($selParam)->first();
    my $itemnumber = $titleItemObjectRS->get_column('koha_object_id');
    $logger->trace("processItemHit() titleItemObjectRS->{_column_data}:" . Dumper($titleItemObjectRS->{_column_data}) . ":");
    $logger->trace("processItemHit() candidate item for update has itemnumber:" . $itemnumber . ":");

    # void the itemnumber if meanwhile the order has been transferred by the library to another bookseller than ekz
    if ( defined $itemnumber ) {
        my $schema = Koha::Database->new()->schema();
        # try to find the aqorders record for this item
        $selParam = {
            itemnumber => $itemnumber
        };
        my $aqorders_itemsRS = $schema->resultset('AqordersItem')->search($selParam)->first();    # ordernumber is an unique key in table aqorders_items
        my $ordernumber = $aqorders_itemsRS->get_column('ordernumber');
        $logger->trace("processItemHit() aqorders_itemsRS->{_column_data}:" . Dumper($aqorders_itemsRS->{_column_data}) . ": ordernumber:" . $ordernumber . ":");

        if ( $ordernumber ) {
            # try to get the basketno of the aqorders record for this item
            $selParam = {
                ordernumber => $ordernumber
            };
            my $aqordersRS = $schema->resultset('Aqorder')->search($selParam)->first();    # ordernumber is an unique key in table aqorders
            my $basketno = $aqordersRS->get_column('basketno');
            $logger->trace("processItemHit() aqordersRS->{_column_data}:" . Dumper($aqordersRS->{_column_data}) . ": basketno:" . $basketno . ":");

            if ( $basketno ) {
                # compare the booksellerid of this aqbasket with the systempreferences variable for bookseller ekz
                $selParam = {
                    basketno => $basketno
                };
                my $aqbasketRS = $schema->resultset('Aqbasket')->search($selParam)->first();    # basketno is an unique key in table aqbasket
                my $booksellerid = $aqbasketRS->get_column('booksellerid');
                $logger->trace("processItemHit() aqbasketRS->{_column_data}:" . Dumper($aqbasketRS->{_column_data}) . ": booksellerid:" . $booksellerid . ": ekzAqbooksellersId:" . $ekzAqbooksellersId . ":");

                if ( defined($ekzAqbooksellersId) && length($ekzAqbooksellersId) ) {
                    if ( ! defined $booksellerid || $booksellerid != $ekzAqbooksellersId ) {
                         $logger->warn("processItemHit() will not use itemnumber:$itemnumber: as ordernumber:$ordernumber: leads to basketno:$basketno: but booksellerid:$booksellerid: differs from ekzAqbooksellersId:$ekzAqbooksellersId:");
                        $itemnumber = undef;    # void this itemnumber - this item now belongs to another aqbookseller and so may not be used for ekz data import any more
                    }
                }
            }
        }
        $logger->trace("processItemHit() candidate item for update has itemnumber:" . $itemnumber . ": (after order transfer check)");
    }
    
    # 2. step: update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenReceived> where itemnumber = acquisition_import_objects.koha_object_id (from above result)
    my $itemHitCount = 0;
    my $itemHit = undef;
    my $res = undef;
    if ( defined $titleItemObjectRS && defined $itemnumber ) {
        my $itemHitRs = Koha::Items->new()->_resultset();
        my $itemSelParam = { itemnumber => $itemnumber };
        $itemHitCount = $itemHitRs->count( $itemSelParam );
        $itemHit = $itemHitRs->find( $itemSelParam );
        $logger->trace("processItemHit() searched for itemnumber:$itemnumber: itemHitCount:$itemHitCount: itemHit->{_column_data}:" . Dumper($itemHit->{_column_data}) . ":");

        if ( $itemHitCount > 0 && defined($itemHit->{_column_data}) ) {
            # configurable items record field update via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenReceived")
            # e.g. setting the 'item available' state (or 'item processed internally' state) in items.notforloan
            if ( defined($ekzWebServicesSetItemSubfieldsWhenReceived) && length($ekzWebServicesSetItemSubfieldsWhenReceived) > 0 ) {
                my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenReceived;
                $logger->debug("processItemHit() has to do " . scalar @affects . " affects");
                if ( @affects ) {
                    my $frameworkcode = C4::Biblio::GetFrameworkCode($biblionumber);
                    my ( $itemfield ) = C4::Biblio::GetMarcFromKohaField( 'items.itemnumber', $frameworkcode );
                    my $item = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
                    if ( $item ) {
                        for my $affect ( @affects ) {
                            my ( $sf, $v ) = split('=', $affect, 2);
                            foreach ( $item->field($itemfield) ) {
                                $_->update( $sf => $v );
                            }
                        }
                        C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber );
                        $logger->trace("processItemHit() after calling C4::Items::ModItemFromMarc biblionumber:$biblionumber: itemnumber:$itemnumber:");
                    }
                }
            }
            $itemHitCount = $itemHitRs->count( $itemSelParam );    # one never knows ...
            $itemHit = $itemHitRs->find( $itemSelParam );    # re-read the item in order to get the modified field values
            $logger->trace("processItemHit() after re-reading itemHit itemnumber:$itemnumber: itemHitCount:$itemHitCount: itemHit->{_column_data}:" . Dumper($itemHit->{_column_data}) . ":");

            # Before version 21.05 the following actions would have been done (but that did not work for technical reasons) even if the items record has been deleted.
            # Design decision:
            # We trust in method 4 that will create a supplementary order title and order item if no items record is found here (even if order item record exists in acquisition_import table).
            # So it seems to be less confusing to do the following actions here only if the item has been found instead of doing them anyway.
            # Otherwise there would be created 2 acquisition_import delivery item records instead of 1: one for the old original order item and one for the supplementary order item.
            # It is clearer if only the one for the supplementary order item exists.

            # attaching ekz order to Koha acquisition:
            if ( defined($ekzAqbooksellersId) && length($ekzAqbooksellersId) ) {
                # update Koha acquisition order
                ($ordernumberFound, $basketnoFound) = processItemOrder( $lieferscheinNummer, $lieferscheinDatum, $biblionumber, $itemnumber, $auftragsPosition, $acquisitionImportTitleItemHit, $logger );
                $logger->trace("processItemHit() processItemOrder() returned ordernumberFound:$ordernumberFound: basketnoFound:$basketnoFound:");
            }

            # 3. step: update acquisition_import set processingstate = 'delivered' of current $acquisitionImportTitleItemHit
            $res = $acquisitionImportTitleItemHit->update( { processingstate => 'delivered' } );
            $logger->trace("processItemHit() acquisitionImportTitleItemHit->update res:" . Dumper($res->{_column_data}) . ":");

            # Insert information on the item delivery in 2 steps:
            # 3.1. step: Insert an acquisition_import record for the delivery note title, if it does not exist already.
            $selParam = {
                vendor_id => "ekz",
                object_type => "delivery",
                object_number => $lieferscheinNummer,
                object_date => DateTime::Format::MySQL->format_datetime($lieferscheinDatum),
                rec_type => "title",
                object_item_number => $lsArtikelNr,
                processingstate => "delivered",
                object_reference => $acquisitionImportTitleHit->get_column('id')
            };
            $updParam = {
                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow)    # in local time_zone
            };
            $insParam = {
                #id => 0, # AUTO
                vendor_id => "ekz",
                object_type => "delivery",
                object_number => $lieferscheinNummer,
                object_date => DateTime::Format::MySQL->format_datetime($lieferscheinDatum),
                rec_type => "title",
                object_item_number => $lsArtikelNr,
                processingstate => "delivered",
                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                #payload => undef # NULL
                object_reference => $acquisitionImportTitleHit->get_column('id')
            };
            $logger->trace("processItemHit() update or insert acquisition_import record for title calling Koha::AcquisitionImport::AcquisitionImports->new()->upd_or_ins(selParam, updParam, insParam) with selParam:" . Dumper($selParam) . ": updParam:" . Dumper($updParam) . ": insParam:" . Dumper($insParam) . ":");
            my $acquisitionImportDeliveryNoteTitle = Koha::AcquisitionImport::AcquisitionImports->new();
            my $resDeliveryTitle = $acquisitionImportDeliveryNoteTitle->upd_or_ins($selParam, $updParam, $insParam);   # TODO: evaluate $resDeliveryTitle
            $logger->trace("processItemHit() insert acquisition_import record for delivery title res:" . Dumper($resDeliveryTitle->_resultset()->{_column_data}) . ":");

            # 3.2. step: Insert an acquisition_import record for the delivery note item.
            my $object_item_number;
            if ( $lsReferenznummer ) {
                $object_item_number = $lieferscheinNummer . '-' . $lsArtikelNr . '-' . $lsReferenznummer;
            } else {
                $object_item_number = $lieferscheinNummer . '-' . $lsArtikelNr;
            }
            $insParam = {
                #id => 0, # AUTO
                vendor_id => "ekz",
                object_type => "delivery",
                object_number => $lieferscheinNummer,
                object_date => DateTime::Format::MySQL->format_datetime($lieferscheinDatum),
                rec_type => "item",
                object_item_number => $object_item_number,
                processingstate => "delivered",
                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                #payload => undef # NULL
                object_reference => $acquisitionImportTitleItemHit->get_column('id')
            };
            $logger->trace("processItemHit() insert acquisition_import record for item calling Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->create(insParam) with insParam:" . Dumper($insParam) . ":");
            my $acquisitionImportDeliveryNoteItem = Koha::AcquisitionImport::AcquisitionImports->new();
            my $resDeliveryItem = $acquisitionImportDeliveryNoteItem->_resultset()->create($insParam);   # TODO: evaluate $resDeliveryItem
            $logger->trace("processItemHit() insert acquisition_import record for item res:" . Dumper($resDeliveryItem->{_column_data}) . ":");
        }
    }

    # set variables of log email
    if ( $emaillog->{'foundTitlesCount'} == 0 ) {
        $emaillog->{'foundTitlesCount'} = 1;
    }
    if ( defined $titleItemObjectRS && defined $itemnumber && $itemHitCount > 0 && defined($itemHit->{_column_data}) && defined $res ) {    # item successfully updated
        $$updOrInsItemsCountRef += 1;
        # positive message for log email
        $emaillog->{'importresult'} = 1;
        $emaillog->{'processedItemsCount'} += 1;
        $emaillog->{'updatedItemsCount'} += 1;
    } else {
        # negative message for log email
        $emaillog->{'problems'} .= "\n" if ( $emaillog->{'problems'} );
        $emaillog->{'problems'} .= "ERROR: Update der Exemplardaten für EKZ ArtikelNr.: " . $lsArtikelNr . " wurde abgewiesen.\n";
        $emaillog->{'importresult'} = -1;
        $emaillog->{'importerror'} = 1;
        $emaillog->{'processedItemsCount'} += 0;    # The item could not be processed here in processItemHit(). But probably it soon will be processed by method4.
    }
    my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
    my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
    my $importId = '(ControlNumber)' . $tmp_cn . '(ControlNrId)' . $tmp_cna;    # if cna = 'DE-Rt5' then this cn is the ekz article number
    $emaillog->{'importIds'}->{$importId} = $itemnumber;
    $logger->trace("processItemHit() updatedItemsCount:$emaillog->{'updatedItemsCount'}: set next importIds:" . $importId . ":");
    
    # add result of updating item to log email
    my ($titeldata, $isbnean) = ($itemnumber, '');
    push @{$emaillog->{'records'}}, [$lsArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2, $ordernumberFound, $basketnoFound];

    $logger->trace("processItemHit() END");
}

# If it's an item for Standing Order, that is:
# <ekzexemplarid> is not sent, but 
# -    ekzArtikelNr and referenznummer matches a record in acquisition_import with object_item_number like 'sto.%.ID%-$ekzArtikelNr-$referenznummer' and rec_type = 'item'
# - or ekzArtikelNr matches a record in acquisition_import with object_number like 'sto.%.ID%' and object_item_number = '$ekzArtikelNr' and rec_type = 'title'
#
# or if it's an item for Serial Order, that is:
# <ekzexemplarid> is not sent, but 
# -    ekzArtikelNr and referenznummer matches a record in acquisition_import with object_item_number like 'ser.%.ID%-$ekzArtikelNr-$referenznummer' and rec_type = 'item'
# - or ekzArtikelNr matches a record in acquisition_import with object_number like 'ser.%.ID%' and object_item_number = '$ekzArtikelNr' and rec_type = 'title'
#
# then:
#   Search the matching aqorders record via aqorders_items.
#   Create a basket for this delivery note if not existing,
#   'shift' the order into this basket. Append the old basketname in note field of the new basket (may become a list). Do not delete the old basket even if empty now.
#   If no basketgroup exists for the new basket that contains this order, create such an basketgroup with same name.
#   
sub processItemOrder
{
    my ( $lieferscheinNummer, $lieferscheinDatum, $biblionumber, $itemnumber, $auftragsPosition, $acquisitionImportTitleItemHit, $logger ) = @_;

    my $ordernumber_ret = undef;
    my $basketno_ret = undef;
    my $basketgroupid = undef;

    $logger->info("processItemOrder() Start biblionumber:$biblionumber: itemnumber:$itemnumber: acquisitionImportTitleItemHit object_number:" . $acquisitionImportTitleItemHit->object_number . ":");

    my $isStoOrSer = 0;    # indicates if it is a item of a standing or serial order
    if ( $acquisitionImportTitleItemHit->object_number =~ /^(sto|ser)\.\d+\.ID\d+/ ) {
        $isStoOrSer = 1;
    }
    $logger->trace("processItemOrder() acquisitionImportTitleItemHit isStoOrSer:$isStoOrSer:");

    # search the aqorders record via select * from aqorders where ordernumber = (select ordernumber from aqorders_items where itemnumber = $itemnumber)
    my $orderRecord = C4::Acquisition::GetOrderFromItemnumber($itemnumber);

    $logger->trace("processItemOrder() Dumper orderRecord:" . Dumper($orderRecord) . ":");
    if ( ! $orderRecord ) {
        $logger->error("processItemInvoice() could not find orderRecord via itemnumber:" . $itemnumber . ":");
        return ($ordernumber_ret, $basketno_ret);    # both values still undef
    }
    $ordernumber_ret = $orderRecord->{ordernumber};
    $basketno_ret = $orderRecord->{basketno};
    $logger->debug("processItemOrder() ordernumber_ret:$ordernumber_ret: basketno_ret:$basketno_ret:");

    # search basket of order
    my $aqbasket_of_order = &C4::Acquisition::GetBasket($orderRecord->{basketno});
    $logger->trace("processItemOrder() Dumper aqbasket_of_order:" . Dumper($aqbasket_of_order) . ":");
    if ( !$aqbasket_of_order ) {
        return ($ordernumber_ret, $basketno_ret);
    }

    if ( $isStoOrSer ) {    # it is a item of a standing or serial order
        # search/create new basket of same bookseller with basketname derived from Delivery note plus pseudo order number derived from customer number and stoID
        my $aqbasket_delivery_name = 'L-' . $lieferscheinNummer . '/' . $aqbasket_of_order->{basketname};
        my $aqbasket_delivery = undef;
        my $params = {
            basketname => '"'.$aqbasket_delivery_name.'"',
            booksellerid => "$aqbasket_of_order->{booksellerid}"
        };
        my $aqbasket_delivery_hits = &C4::Acquisition::GetBaskets($params, { orderby => "basketno DESC" });
        $logger->trace("processItemOrder() Dumper aqbasket_delivery_hits:" . Dumper($aqbasket_delivery_hits) . ":");
        if ( defined($aqbasket_delivery_hits) && scalar @{$aqbasket_delivery_hits} > 0 ) {
            $aqbasket_delivery = $aqbasket_delivery_hits->[0];
            
            # reopen basket
            &C4::Acquisition::ReopenBasket($aqbasket_delivery->{basketno});
            $logger->trace("processItemOrder() after ReopenBasket");

            my $note = $aqbasket_delivery->{note};
            if ( index($note, $aqbasket_of_order->{basketname}) == -1 ) {
                my $basketinfo = {
                    basketno => $aqbasket_delivery->{basketno},
                    note => $note . ', ' . $aqbasket_of_order->{basketname}
                };
                &C4::Acquisition::ModBasket($basketinfo);
            }
        } else {
            my $aqbasket_delivery_no  = &C4::Acquisition::NewBasket($aqbasket_of_order->{booksellerid}, $aqbasket_of_order->{authorisedby}, $aqbasket_delivery_name,
                                                                $aqbasket_of_order->{basketname},"", $aqbasket_of_order->{basketcontractnumber}, $aqbasket_of_order->{deliveryplace}, $aqbasket_of_order->{billingplace}, $aqbasket_of_order->{is_standing}, $aqbasket_of_order->{create_items});
            if ( $aqbasket_delivery_no ) {
                my $basketinfo = {
                    basketno => $aqbasket_delivery_no,
                    branch => "$aqbasket_of_order->{branch}"
                };
                &C4::Acquisition::ModBasket($basketinfo);
                $aqbasket_delivery = &C4::Acquisition::GetBasket($aqbasket_delivery_no);
            }
        }
        $logger->trace("processItemOrder() Dumper aqbasket_delivery:" . Dumper($aqbasket_delivery) . ":");
        if ( !$aqbasket_delivery ) {
            return ($ordernumber_ret, $basketno_ret);
        }
        $basketno_ret = $aqbasket_delivery->{basketno};

        # shift order to this new basket
        $params = {
            ordernumber => $orderRecord->{ordernumber},
            biblionumber => $orderRecord->{biblionumber},
            quantitydelivered => 1,
            delivered_items => [$itemnumber],
            basketno_delivery => $aqbasket_delivery->{basketno}
        };
        $ordernumber_ret = &C4::Acquisition::ModOrderDeliveryNote($params);
            
        # close basket
        $logger->debug("processItemOrder() is calling Koha::Acquisition::Baskets->find(basketno:" . $aqbasket_delivery->{basketno} . ")");
        my $kohabasket = Koha::Acquisition::Baskets->find($aqbasket_delivery->{basketno});
        if ( $kohabasket ) {
            $logger->debug("processItemOrder() is calling Koha::Acquisition::Baskets->find(basketno:" . $aqbasket_delivery->{basketno} . ")->close");
            $kohabasket->close;
        }

        # search/create basket group with name derived from Delivery note and same bookseller and update aqbasket_delivery accordingly
        $params = {
            name => '"'.$aqbasket_delivery_name.'"',
            booksellerid => $aqbasket_of_order->{booksellerid}
        };
        $basketgroupid  = undef;
        my $aqbasketgroups = &C4::Acquisition::GetBasketgroupsGeneric($params, { orderby => "id DESC" } );
        $logger->trace("processItemOrder() Dumper aqbasketgroups:" . Dumper($aqbasketgroups) . ":");

        # create basket group if not existing
        if ( !defined($aqbasketgroups) || scalar @{$aqbasketgroups} == 0 ) {
            $params = { 
                name => $aqbasket_delivery_name,
                closed => 0,
                booksellerid => $aqbasket_delivery->{booksellerid},
                deliveryplace => "$aqbasket_delivery->{deliveryplace}",
                freedeliveryplace => undef,    # setting to NULL
                deliverycomment => undef,    # setting to NULL
                billingplace => "$aqbasket_delivery->{billingplace}",
            };
            $basketgroupid  = &C4::Acquisition::NewBasketgroup($params);
        } else {
            $basketgroupid = $aqbasketgroups->[0]->{id};
            
            # reopen basketgroup
            &C4::Acquisition::ReOpenBasketgroup($basketgroupid);
            $logger->trace("processItemOrder() after ReOpenBasketgroup");
        }
        $logger->info("processItemOrder() basketgroup with name:$aqbasket_delivery_name: has basketgroupid:$basketgroupid:");

        if ( $basketgroupid ) {
            
            # update basket
            my $basketinfo = {
                'basketno' => $aqbasket_delivery->{basketno},
                'basketgroupid' => $basketgroupid
            };
            &C4::Acquisition::ModBasket($basketinfo);
            $logger->trace("processItemOrder() after ModBasket");
            
            # close basketgroup
            &C4::Acquisition::CloseBasketgroup($basketgroupid);
            $logger->trace("processItemOrder() after CloseBasketgroup");
        }
    }
    $logger->info("processItemOrder() returns ordernumber_ret:" . $ordernumber_ret . ": and basketno_ret:" . $basketno_ret . ":");

    return ($ordernumber_ret, $basketno_ret);
}

1;
