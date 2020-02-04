package C4::External::EKZ::EkzWsDeliveryNote;

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
use DateTime::Format::MySQL;
use Exporter;

use C4::Items qw(AddItem);
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::External::EKZ::lib::EkzWebServices;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::lib::EkzKohaRecords;
use Koha::Acquisition::Order;
use C4::Acquisition;

our @ISA = qw(Exporter);
our @EXPORT = qw( readLSFromEkzWsLieferscheinList readLSFromEkzWsLieferscheinDetail genKohaRecords );


my $debugIt = 1;



###################################################################################################
# read Lieferschein (delivery notes) using ekz web service 'LieferscheinList' (overview data)
###################################################################################################
sub readLSFromEkzWsLieferscheinList {
    my $ekzCustomerNumber = shift;
    my $selVon = shift;
    my $selBis = shift;
	my $selKundennummerWarenEmpfaenger = shift;

    my $result = ();    # hash reference
print STDERR "ekzWsDeliveryNote::readLSFromEkzWsLieferscheinList() ekzCustomerNumber:", $ekzCustomerNumber, ": selVon:", $selVon, ": selBis:", defined($selBis) ? $selBis : "undef", ": selKundennummerWarenEmpfaenger:", defined($selKundennummerWarenEmpfaenger) ? $selKundennummerWarenEmpfaenger : "undef", ":\n" if $debugIt;

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsLieferscheinList($ekzCustomerNumber, $selVon, $selBis, $selKundennummerWarenEmpfaenger);
print STDERR "ekzWsDeliveryNote::readLSFromEkzWsLieferscheinList() result->{'lieferscheinCount'}:$result->{'lieferscheinCount'}:\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::readLSFromEkzWsLieferscheinList() result->{'lieferscheinRecords'}:$result->{'lieferscheinRecords'}:\n" if $debugIt;

    return $result;
}


###################################################################################################
# read single Lieferschein (delivery note) using ekz web service 'LieferscheinDetail' (detailed data)
###################################################################################################
sub readLSFromEkzWsLieferscheinDetail {
    my $ekzCustomerNumber = shift;
    my $selId = shift;
    my $selLieferscheinnummer = shift;
    my $refLieferscheinDetailElement = shift;    # for storing the LieferscheinDetailElement of the SOAP response body

    my $result = ();    # hash reference
print STDERR "ekzWsDeliveryNote::readLSFromEkzWsLieferscheinDetail() ekzCustomerNumber:", $ekzCustomerNumber, ": selId:", defined($selId) ? $selId : "undef", ": selLieferscheinnummer:", defined($selLieferscheinnummer) ? $selLieferscheinnummer : "undef", ":\n" if $debugIt;
    
print STDERR "ekzWsDeliveryNote::readLSFromEkzWsLieferscheinDetail() \$refLieferscheinDetailElement:", $refLieferscheinDetailElement, ":\n" if $debugIt;
print STDERR Dumper($refLieferscheinDetailElement) if $debugIt;

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsLieferscheinDetail($ekzCustomerNumber, $selId, $selLieferscheinnummer, $refLieferscheinDetailElement);
print STDERR "ekzWsDeliveryNote::readLSFromEkzWsLieferscheinDetail() result->{'lieferscheinCount'}:$result->{'lieferscheinCount'}:\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::readLSFromEkzWsLieferscheinDetail() result->{'lieferscheinRecords'}:$result->{'lieferscheinRecords'}:\n" if $debugIt;

    return $result;
}


###################################################################################################
# go through the titles contained in the delivery note and handle items status, 
# generate title data and item data as required
###################################################################################################
sub genKohaRecords {
    my ($ekzCustomerNumber, $messageID, $lieferscheinDetailElement, $lieferscheinRecord) = @_;

    my $lieferscheinNummerIsDuplicate = 0;
    my $lieferscheinNummer = '';
    my $lieferscheinDatum = '';
    my $dbh = C4::Context->dbh;
    $dbh->{AutoCommit} = 0;

    # variables for email log
    my $emaillog;
    $emaillog->{'logresult'} = [];    # array ref
    $emaillog->{'actionresult'} = [];    # array ref
    $emaillog->{'importerror'} = 0;    # flag if an insert error has happened
    $emaillog->{'importIds'} = {};    # hash ref
    $emaillog->{'dt'} = DateTime->now;
    $emaillog->{'dt'}->set_time_zone( 'Europe/Berlin' );
    my ($message, $subject, $haserror) = ('','',0);

    print STDERR "ekzWsDeliveryNote::genKohaRecords() Start;  ekzCustomerNumber:$ekzCustomerNumber messageID:$messageID id:$lieferscheinRecord->{'id'}: Lieferscheinnummer:$lieferscheinRecord->{'nummer'}: lieferscheinRecord->{'teilLieferungCount'}:$lieferscheinRecord->{'teilLieferungCount'}\n" if $debugIt;

    my $updOrInsItemsCount = 0;
    my $zweigstellencode = '';
    my $homebranch = C4::External::EKZ::lib::EkzWebServices->new()->getEkzWebServicesDefaultBranch($ekzCustomerNumber);
    $homebranch =~ s/^\s+|\s+$//g; # trim spaces
    if ( defined $homebranch && length($homebranch) > 0 ) {
        $zweigstellencode = $homebranch;
    }
    if ( !&C4::External::EKZ::lib::EkzKohaRecords::checkbranchcode($zweigstellencode) ) {
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
    my $ekzAqbooksellersId = C4::Context->preference("ekzAqbooksellersId");
    $ekzAqbooksellersId =~ s/^\s+|\s+$//g;    # trim spaces
    my $acquisitionError = 0;
    my $basketno = -1;
    my $basketgroupid = undef;

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
print STDERR "ekzWsDeliveryNote::genKohaRecords() search delivery note message record in acquisition_import selParam:", Dumper($selParam), ":\n" if $debugIt;

    my $acquisitionImportIdLieferschein;
    my $acquisitionImportLieferschein = Koha::AcquisitionImport::AcquisitionImports->new();
    my $hit = $acquisitionImportLieferschein->_resultset()->find( $selParam );
print STDERR "ekzWsDeliveryNote::genKohaRecords() ref(acquisitionImportLieferschein):", ref($acquisitionImportLieferschein), ": ref(hit):", ref($hit), ":\n" if $debugIt;
    if ( defined($hit) ) {
        $lieferscheinNummerIsDuplicate = 1;
print STDERR "ekzWsDeliveryNote::genKohaRecords() hit->{_column_data}:", Dumper($hit->{_column_data}), ":\n" if $debugIt;
        my $mess = sprintf("The delivery note number '%s' has already been used at %s. Processing denied.\n",$lieferscheinNummer, $hit->get_column('processingtime'));
        carp $mess;
    } else {
        my $schemaResultAcquitionImport = $acquisitionImportLieferschein->_resultset()->create($insParam);
        $acquisitionImportIdLieferschein = $schemaResultAcquitionImport->get_column('id');
print STDERR "ekzWsDeliveryNote::genKohaRecords() ref(schemaResultAcquitionImport):", ref($schemaResultAcquitionImport), ":\n" if $debugIt;
#print STDERR "ekzWsDeliveryNote::genKohaRecords() Dumper(schemaResultAcquitionImport):", Dumper($schemaResultAcquitionImport), ":\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::genKohaRecords() Dumper(schemaResultAcquitionImport->{_column_data}):", Dumper($schemaResultAcquitionImport->{_column_data}), ":\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::genKohaRecords() acquisitionImportIdLieferschein:", $acquisitionImportIdLieferschein, ":\n" if $debugIt;
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

            print STDERR "ekzWsDeliveryNote::genKohaRecords() teilLieferungRecord gelieferteExemplare:$teilLieferungRecord->{'gelieferteExemplare'}: teilLieferung:$teilLieferungRecord->{'teilLieferung'}: auftragsPositionCount:$teilLieferungRecord->{'auftragsPositionCount'}:\n" if $debugIt;
            my $auftragsPosition = $teilLieferungRecord->{'auftragsPositionRecords'}->[0];    # this array always consists of only 1 element
            print STDERR "ekzWsDeliveryNote::genKohaRecords() auftragsPosition ekzexemplarid:", defined($auftragsPosition->{'ekzexemplarid'}) ? $auftragsPosition->{'ekzexemplarid'} : 'undef', ": ekzArtikelNr:$auftragsPosition->{'artikelNummer'}: isbn:$auftragsPosition->{'isbn'}: ean:$auftragsPosition->{'ean'}: kundenBestelldatum:$auftragsPosition->{'kundenBestelldatum'}:\n" if $debugIt;
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

            # search corresponding item hits with same ekzExemplarid in table acquisition_import, if sent in $auftragsPosition->{'ekzexemplarid'}.
            # otherwise:
            # search corresponding order title hits with same ekzArtikelNr in table acquisition_import, if sent in $auftragsPosition->{'artikelNummer'}
            # In some cases (e.g. knv titles) the artikelNummer is 0, so it can't be used for search

            # we try maximal 3 methods for identifying an order, or 'inventing' one, if required:
            # method1: searching for ekzExemplarid identity (which is preferable)
            # method2: searching for ekzArtikelNr identity if ekzArtikelNr > 0
            # method3 is for all items for which no acquisition_import record representing the order title could be found

            # method1: searching for ekzExemplarid identity (which is preferable; typical for an item that was ordered in the ekz Medienshop)
            if (defined($auftragsPosition->{'ekzexemplarid'}) && length($auftragsPosition->{'ekzexemplarid'}) > 0 && $updOrInsItemsCount < $deliveredItemsCount ) {

                # search in acquisition_import for records representing ordered items with the same ekzExemplarid
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_item_number => $auftragsPosition->{'ekzexemplarid'},
                    rec_type => "item",
                    processingstate => 'ordered'
                };
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: search order item record in acquisition_import selParam:", Dumper($selParam), ":\n" if $debugIt;
                my $acquisitionImportEkzExemplarIdHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: scalar acquisitionImportEkzExemplarIdHits:", scalar $acquisitionImportEkzExemplarIdHits, ":\n" if $debugIt;

                foreach my $acquisitionImportEkzExemplarIdHit ($acquisitionImportEkzExemplarIdHits->all()) {
                    if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                        last;
                    }
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: acquisitionImportEkzExemplarIdHit->{_column_data}:", Dumper($acquisitionImportEkzExemplarIdHit->{_column_data}), ":\n" if $debugIt;

                    #read the corresponding title via its biblionumber from acquisition_import_objects
                    # search in acquisition_import for the record representing the ordered title belonging to this item
                    my $selParam = {
                        vendor_id => "ekz",
                        object_type => "order",
                        id => $acquisitionImportEkzExemplarIdHit->get_column('object_reference'),
                        rec_type => "title",
                        processingstate => 'ordered'
                    };
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: search title order record in acquisition_import selParam:", Dumper($selParam), ":\n" if $debugIt;
                    my $acquisitionImportTitleHit = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->find($selParam);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: acquisitionImportTitleHit->{_column_data}:", Dumper($acquisitionImportTitleHit->{_column_data}), ":\n" if $debugIt;
                    if ( defined($acquisitionImportTitleHit) ) {
                        my $selParam = {
                            acquisition_import_id => $acquisitionImportTitleHit->get_column('id'),
                            koha_object => "title"
                        };
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: search title order record in acquisition_import_objects selParam:", Dumper($selParam), ":\n" if $debugIt;
                        my $titleObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                        my $titleObjectRS = $titleObject->_resultset()->find($selParam);
                        my $selBiblionumber = $titleObjectRS->get_column('koha_object_id');
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: titleObjectRS->{_column_data}:", Dumper($titleObjectRS->{_column_data}), ":\n" if $debugIt;

                        if ( defined($selBiblionumber) ) {
                            if ( $selBiblionumber != $biblionumber ) {
                                $titleHits = { 'count' => 0, 'records' => [] };
                                $biblionumber = 0;
                                $lsEkzArtikelNr = '';
                                my $record = C4::Biblio::GetMarcBiblio( $selBiblionumber, 0);
                                if ( defined($record) ) {
                                    $titleHits->{'count'} = 1;
                                    $titleHits->{'records'}->[0] = $record;
                                }

                                if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                                    $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                                    my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                                    my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                                    if ( $tmp_cna eq "DE-Rt5" ) {
                                        $lsEkzArtikelNr = $tmp_cn;
                                    } else {
                                        $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                                    }
                                    # positive message for log email
                                    $emaillog->{'importresult'} = 2;
                                    $emaillog->{'importedTitlesCount'} += 0;

                                    # add result of finding biblio to log email
                                    ($titeldata, $isbnean) = C4::External::EKZ::lib::EkzKohaRecords->getShortISBD($titleHits->{'records'}->[0]);
                                    push @{$emaillog->{'records'}}, [$tmp_cna, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
print STDERR "ekzWsDeliveryNote::genKohaRecords() method1: emaillog->{'records'}->[0]:", Dumper($emaillog->{'records'}->[0]), ":\n" if $debugIt;
                                } else {
                                    next;    # next in acquisitionImportEkzExemplarIdHits->all()
                                }
                            }
                            &processItemHit($lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsEkzArtikelNr, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportEkzExemplarIdHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId);
                        }    #end defined($selBiblionumber)
                    }    # end defined($acquisitionImportTitleHit)
                }    # end foreach acquisitionImportEkzExemplarIdHits->all()
            }    # end method1


            # method2: searching for ekzArtikelNr identity if ekzArtikelNr > 0 (typical for an item of a running standing order)
            if (defined($auftragsPosition->{'artikelNummer'}) && $auftragsPosition->{'artikelNummer'} > 0 && $updOrInsItemsCount < $deliveredItemsCount ) {
            #if (defined($auftragsPosition->{'artikelNummer'})  && $updOrInsItemsCount < $deliveredItemsCount ) {    # XXXWH maybe there is an standing order that matches the auftragsPosition by ISBN or EAN even if $auftragsPosition->{'artikelNummer'} == 0

                # search in acquisition_import for records representing ordered orders with the same ekzArtikelNr
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_item_number => $auftragsPosition->{'artikelNummer'},
                    rec_type => "title"
                };
                my $acquisitionImportTitleHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method2: scalar acquisitionImportTitleHits:", scalar $acquisitionImportTitleHits->{_column_data}, ":\n" if $debugIt;

                # Search corresponding 'ordered' order items and set them to 'delivered' (in table 'acquisition_import' and in 'items' via system preference ekzWsItemSetSubfieldsWhenReceived).
                # Insert records in table acquisition_import for the title and items.
                foreach my $acquisitionImportTitleHit ($acquisitionImportTitleHits->all()) {
                    if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                        last;
                    }
                    print STDERR "ekzWsDeliveryNote::genKohaRecords() method2: acquisitionImportTitleHit->{_column_data}:", Dumper($acquisitionImportTitleHit->{_column_data}), ":\n" if $debugIt;
                    
                    if ( $titleHits->{'count'} == 0 || !defined $titleHits->{'records'}->[0] || !defined($titleHits->{'records'}->[0]->field("001")) || $titleHits->{'records'}->[0]->field("001")->data() != $auftragsPosition->{'artikelNummer'} || !defined($titleHits->{'records'}->[0]->field("003")) || $titleHits->{'records'}->[0]->field("003")->data() ne "DE-Rt5" ) {
                        # search the biblio record; if not found, create the biblio record in the '$updOrInsItemsCount < $deliveredItemsCount' block below (= method3)
                        my $reqParamTitelInfo = ();
                        $reqParamTitelInfo->{'ekzArtikelNr'} = $auftragsPosition->{'artikelNummer'};
                        my $isbn = $auftragsPosition->{'isbn'};
                        if ( length($isbn) == 10 ) {
                            $reqParamTitelInfo->{'isbn'} = $isbn;
                        } else {
                            $reqParamTitelInfo->{'isbn13'} = $isbn;
                        }
                        $reqParamTitelInfo->{'ean'} = $auftragsPosition->{'ean'};

                        $titleHits = { 'count' => 0, 'records' => [] };
                        $biblionumber = 0;
                        $lsEkzArtikelNr = '';
                        # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
                        $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLocalDB($reqParamTitelInfo, 1);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method2: from local DB titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                            $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                            my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                            my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                            if ( $tmp_cna eq "DE-Rt5" ) {
                                $lsEkzArtikelNr = $tmp_cn;
                            } else {
                                $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                            }
                            $biblioExisting = 1;
                            # positive message for log email
                            $emaillog->{'importresult'} = 2;
                            $emaillog->{'importedTitlesCount'} += 0;

                            # add result of finding biblio to log email
                            ($titeldata, $isbnean) = C4::External::EKZ::lib::EkzKohaRecords->getShortISBD($titleHits->{'records'}->[0]);
                            push @{$emaillog->{'records'}}, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                        } else {
                            last;   # create the biblio record in the '$updOrInsItemsCount < $deliveredItemsCount' block below (= method3)
                        }
                    }
                    
                    # for this title: search all records in acquisition_import representing its items that are 'ordered' (i.e. can still be delivered)
                    my $selParam = {
                        vendor_id => "ekz",
                        object_type => "order",
                        object_reference => $acquisitionImportTitleHit->get_column('id'),
                        rec_type => "item",
                        processingstate => 'ordered'
                    };
                    my $acquisitionImportTitleItemHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method2: acquisitionImportTitleItemHits->{_column_data}:", Dumper($acquisitionImportTitleItemHits->{_column_data}), ":\n" if $debugIt;

                    foreach my $acquisitionImportTitleItemHit ($acquisitionImportTitleItemHits->all()) {
print STDERR "ekzWsDeliveryNote::genKohaRecords() method2: acquisitionImportTitleItemHit->{_column_data}:", Dumper($acquisitionImportTitleItemHit->{_column_data}), ":\n" if $debugIt;
                        if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                            last;    # now all $deliveredItemsCount delivered items have been handled 
                        }

                        &processItemHit($lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsEkzArtikelNr, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId);
                    }
                }
            }    # end method2

print STDERR "ekzWsDeliveryNote::genKohaRecords() deliveredItemsCount:$deliveredItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: lsEkzArtikelNr:$lsEkzArtikelNr:\n" if $debugIt;

            # method3 is for all items for which no acquisition_import record representing the order title could be found
            # if not enough matching items could be found: we suppose a 'normal' order and create the corresponding entries for the remaining items
            if ( $updOrInsItemsCount < $deliveredItemsCount) {
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: create item for ekzArtikelNr:$auftragsPosition->{'artikelNummer'}:\n" if $debugIt;

                if ( $titleHits->{'count'} == 0 || !defined $titleHits->{'records'}->[0] || !defined($titleHits->{'records'}->[0]->field("001")) || $titleHits->{'records'}->[0]->field("001")->data() != $auftragsPosition->{'artikelNummer'} || !defined($titleHits->{'records'}->[0]->field("003")) || $titleHits->{'records'}->[0]->field("003")->data() ne "DE-Rt5" ) {

                    my $reqParamTitelInfo = ();
                    $reqParamTitelInfo->{'ekzArtikelArt'}  = $auftragsPosition->{'artikelart'};    # TODO: this is not a code value as in BestellInfo, but plain text (e.g. 'Bücher' instead of 'B', so a mapping function is required
                    $reqParamTitelInfo->{'ekzArtikelNr'} = $auftragsPosition->{'artikelNummer'};
                    my $isbn = $auftragsPosition->{'isbn'};
                    if ( length($isbn) == 10 ) {
                        $reqParamTitelInfo->{'isbn'} = $isbn;
                    } else {
                        $reqParamTitelInfo->{'isbn13'} = $isbn;
                    }
                    $reqParamTitelInfo->{'ean'} = $auftragsPosition->{'ean'};
                    my $autorTitel = $auftragsPosition->{'autorTitel1'} . $auftragsPosition->{'autorTitel2'};
                    my ($author, $titel) = split(':',$autorTitel);
                    $reqParamTitelInfo->{'author'} = $author;
                    $reqParamTitelInfo->{'titel'} = $titel;
                    if ( $auftragsPosition->{'waehrung'} eq 'EUR' && defined($auftragsPosition->{'verkaufsPreis'}) ) {
                        $reqParamTitelInfo->{'preis'} = $auftragsPosition->{'verkaufsPreis'};    # without regard to $auftragsPosition->{'nachlass'}
                    }
                    $reqParamTitelInfo->{'auflage'} = $auftragsPosition->{'auflageText'};
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: reqParamTitelInfo->{'ekzArtikelNr'}:",$reqParamTitelInfo->{'ekzArtikelNr'},": \n" if $debugIt;

                    $titleHits = { 'count' => 0, 'records' => [] };
                    $biblionumber = 0;
                    $lsEkzArtikelNr = '';
                    # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
                    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLocalDB($reqParamTitelInfo, 1);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: from local DB titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                    if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                        $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                        my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                        my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        if ( $tmp_cna eq "DE-Rt5" ) {
                            $lsEkzArtikelNr = $tmp_cn;
                        } else {
                            $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                        }
                    }

                    my @titleSourceSequence = split('\|',$titleSourceSequence);
                    foreach my $titleSource (@titleSourceSequence) {
                        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
                            last;    # title has been found in lastly tested title source
                        }
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: titleSource:$titleSource:\n" if $debugIt;

                        if ( $titleSource eq '_LMSC' ) {
                            # search title in LMSPool
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLMSPool($reqParamTitelInfo);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: from LMS Pool titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                        } elsif ( $titleSource eq '_EKZWSMD' ) {
                            # detailed query to the ekz title information web service
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromEkzWsMedienDaten($reqParamTitelInfo->{'ekzArtikelNr'});
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: from ekz Webservice titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                        } elsif ( $titleSource eq '_WS' ) {
                            # use sparse title data from the LieferscheinDetailElement
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->createTitleFromFields($reqParamTitelInfo);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: from sent titel fields:",$titleHits->{'count'},": \n" if $debugIt;
                        } else {
                            # search title in in the Z39.50 target with z3950servers.servername=$titleSource
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromZ3950Target($titleSource,$reqParamTitelInfo);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: from z39.50 search on target:" . $titleSource . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": \n" if $debugIt;
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
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: new biblionumber:",$biblionumber,": biblioitemnumber:",$biblioitemnumber,": \n" if $debugIt;
                            if ( defined $biblionumber && $biblionumber > 0 ) {
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
                            # positive message for log
                            $emaillog->{'importresult'} = 2;
                            $emaillog->{'importedTitlesCount'} += 0;
                        }
                        my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        if ( $tmp_cna eq "DE-Rt5" ) {
                            my $tmp_biblionumber = defined($biblionumber) ? $biblionumber : "undef";
                            my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $tmp_biblionumber;
                            $lsEkzArtikelNr = $tmp_cn;
                        }
                        # add result of adding biblio to log email
                        ($titeldata, $isbnean) = C4::External::EKZ::lib::EkzKohaRecords->getShortISBD($titleHits->{'records'}->[0]);
                        push @{$emaillog->{'records'}}, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                    }
                }
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: biblioExisting:$biblioExisting: biblioInserted:$biblioInserted: biblionumber:$biblionumber:\n" if $debugIt;

                # now add the acquisition_import and acquisition_import_objects record for the title
                if ( $biblioExisting || $biblioInserted ) {

                    if ( !defined($lsEkzArtikelNr) || $lsEkzArtikelNr eq '0' ) {
                        my $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                        my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                        my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        $lsEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                    }

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
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: acquisitionImportTitleRS->{_column_data}:", Dumper($acquisitionImportTitleRS->{_column_data}), ":\n" if $debugIt;

                    # Insert a record into table acquisition_import_object representing the Koha title data of the 'invented' order.
                    $insParam = {
                        #id => 0, # AUTO
                        acquisition_import_id => $acquisitionImportIdTitle,
                        koha_object => "title",
                        koha_object_id => $biblionumber . ''
                    };
                    my $titleImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                    my $titleImportObjectRS = $titleImportObject->_resultset()->create($insParam);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: titleImportObjectRS->{_column_data}:", Dumper($titleImportObjectRS->{_column_data}), ":\n" if $debugIt;

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
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: acquisitionImportTitleDeliveryRS->{_column_data}:", Dumper($acquisitionImportTitleDeliveryRS->{_column_data}), ":\n" if $debugIt;


                    # now add the items data for the new biblionumber
                    my $ekzExemplarID = $ekzBestellNr . '-' . $lsEkzArtikelNr;    # dummy item number for the 'invented' order
                    my $exemplarcount = $deliveredItemsCount - $updOrInsItemsCount;
                    print STDERR "ekzWsDeliveryNote::genKohaRecords() exemplar ekzExemplarID $ekzExemplarID exemplarcount $exemplarcount\n" if $debugIt;

                    # attaching ekz order to Koha acquisition: 
                    # If system preference ekzAqbooksellersId is not empty: create a Koha order basket for collecting the Koha orders created for each title contained in the request that can not be assigned to an existing order.
                    # policy: If ekzAqbooksellersId is not empty but does not identify an aqbooksellers record: create such an record and update ekzAqbooksellersId.
                    $ekzAqbooksellersId = C4::External::EKZ::lib::EkzKohaRecords->checkEkzAqbooksellersId($ekzAqbooksellersId,1);
                    if ( length($ekzAqbooksellersId) ) {
                        # Search or create a Koha acquisition order basket,
                        # i.e. search / insert a record in table aqbasket so that the following new aqorders records can link to it via aqorders.basketno = aqbasket.basketno .
                        my $basketname = 'L-' . $lieferscheinNummer . '/' .  'L-' . $lieferscheinNummer;
                        my $selbaskets = C4::Acquisition::GetBaskets( { 'basketname' => "\'$basketname\'" } );
                        if ( @{$selbaskets} > 0 ) {
                            $basketno = $selbaskets->[0]->{'basketno'};
                            print STDERR "ekzWsDeliveryNote::genKohaRecords() found aqbasket with basketno:$basketno:\n" if $debugIt;
                        } else {
                            my $authorisedby = undef;
                            my $sth = $dbh->prepare("select borrowernumber from borrowers where surname = 'LCService'");
                            $sth->execute();
                            if ( my $hit = $sth->fetchrow_hashref ) {
                                $authorisedby = $hit->{borrowernumber};
                            }
                            my $branchcode = C4::External::EKZ::lib::EkzKohaRecords->branchcodeFallback('', $homebranch);
                            $basketno = C4::Acquisition::NewBasket($ekzAqbooksellersId, $authorisedby, $basketname, 'created by ekz LieferscheinDetail', '', undef, $branchcode, $branchcode, 0, 'ordering');    # XXXWH
                            print STDERR "ekzWsDeliveryNote::genKohaRecords() created new basket having basketno:", Dumper($basketno), ":\n" if $debugIt;
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
                    print STDERR "ekzWsDeliveryNote::genKohaRecords() ekzAqbooksellersId:$ekzAqbooksellersId: acquisitionError:$acquisitionError: basketno:$basketno:\n" if $debugIt;

                    # attaching ekz order to Koha acquisition: Create a new Koha::Acquisition::Order.
                    my $verkaufsPreis = defined($auftragsPosition->{'verkaufsPreis'}) ? $auftragsPosition->{'verkaufsPreis'} : "0.00";
                    my $nachlass = defined($auftragsPosition->{'nachlass'}) ? $auftragsPosition->{'nachlass'} : "0.00";
                    my $rabatt = "0.0";    # not sent in LieferscheinDetailResponseElement, so we calculate it from verkaufsPreis and nachlass
                    if ( $verkaufsPreis != 0.0 ) {
                        $rabatt = ($nachlass * 100.0) / $verkaufsPreis
                    }
                    my $wertPositionsTeil = defined($auftragsPosition->{'wertPositionsTeil'}) ? $auftragsPosition->{'wertPositionsTeil'} : "0.00";    # info by etecture: <wertPositionsTeil> = <verkaufsPreis> - <nachlass>
                    my $wertMehrpreise = defined($auftragsPosition->{'wertMehrpreise'}) ? $auftragsPosition->{'wertMehrpreise'} : "0.00";
                    my $wertBearbeitung = defined($auftragsPosition->{'wertBearbeitung'}) ? $auftragsPosition->{'wertBearbeitung'} : "0.00";
                    my $waehrung = defined($auftragsPosition->{'waehrung'}) ? $auftragsPosition->{'waehrung'} : "EUR";
                    my $ustSatz = "0.07";    # not sent in LieferscheinDetailResponseElement, so we evaluate XML element <mwst>
                    my $ust = "0.00";    # not sent in LieferscheinDetailResponseElement
                    my $mwst  = defined($auftragsPosition->{'mwst'}) ? $auftragsPosition->{'mwst'} : "E";
                    if ( $mwst eq 'V') {
                        $ustSatz = "0.19";
                    }
                    
                    my $gesamtpreis_tax_included = $verkaufsPreis;    # not sent in LieferscheinDetailResponseElement, so we calculate it based on an info by etecture; total for a single item
                    if ( defined($auftragsPosition->{'verkaufsPreis'}) && defined($auftragsPosition->{'nachlass'}) ) {
                        $gesamtpreis_tax_included = $verkaufsPreis - $nachlass + $wertMehrpreise + $wertBearbeitung;    # not sent in LieferscheinDetailResponseElement, so we calculate it; total for a single item
                    } elsif ( defined($auftragsPosition->{'wertPositionsTeil'}) ) {
                        $gesamtpreis_tax_included = $wertPositionsTeil + $wertMehrpreise + $wertBearbeitung;    # not sent in LieferscheinDetailResponseElement, so we calculate it; total for a single item
                    }
                    if ( $ust == 0.0 && $ustSatz != 0.0 ) {    # Bruttopreise
                        $ust = $gesamtpreis_tax_included * $ustSatz / (1 + $ustSatz);
                        $ust =  &C4::External::EKZ::lib::EkzKohaRecords::round($ust, 2);
                    }
                    if ( $ustSatz == 0.0 && $ust != 0.0 && $gesamtpreis_tax_included != 0.0) {    # Nettopreise
                        $ustSatz = $ust / $gesamtpreis_tax_included;
                        $ustSatz =  &C4::External::EKZ::lib::EkzKohaRecords::round($ustSatz, 2);
                    }
                    my $divisor = 1.0 + $ustSatz;
                    my $gesamtpreis_tax_excluded = $divisor == 0.0 ? 0.0 : $gesamtpreis_tax_included / $divisor;
                    $gesamtpreis_tax_excluded = &C4::External::EKZ::lib::EkzKohaRecords::round($gesamtpreis_tax_excluded, 2);

                    my $replacementcost_tax_included =  $verkaufsPreis;    # list price of single item in library's currency, not discounted
                    my $replacementcost_tax_excluded = $divisor == 0.0 ? 0.0 : $replacementcost_tax_included / $divisor;
                    $replacementcost_tax_excluded = &C4::External::EKZ::lib::EkzKohaRecords::round($replacementcost_tax_excluded, 2);

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

                        my ($dummy1, $dummy2, $budgetid, $dummy3) = C4::External::EKZ::lib::EkzKohaRecords->checkAqbudget($haushaltsstelle, $kostenstelle, 1);

                        my $quantity = $exemplarcount;
                        my $budgetedcost_tax_included =  $gesamtpreis_tax_included;    # discounted
                        my $budgetedcost_tax_excluded =  $gesamtpreis_tax_excluded;    # discounted

                        my $orderinfo = ();

                        # ordernumber is set by DBS
                        $orderinfo->{biblionumber} = $biblionumber;
                        # entrydate is set to today by Koha::Acquisition::Order->insert()
                        $orderinfo->{quantity} = $quantity;
                        $orderinfo->{currency} = $waehrung;    # currency of bookseller's list price
                        # XXXWH currency-Umrechnung fehlt in die eine oder andere Richtung
                        $orderinfo->{'listprice'} = $verkaufsPreis;    # input field 'Vendor price' in UI (in foreign currency, not discounted, per item)
                        $orderinfo->{unitprice} = 0.0;    #  corresponds to input field 'Actual cost' in UI (discounted) and will be initialized with budgetedcost in the GUI in 'receiving' step
                        $orderinfo->{unitprice_tax_excluded} = 0.0;
                        $orderinfo->{unitprice_tax_included} = 0.0;
                        # quantityreceived is set to 0 by DBS
                        $orderinfo->{order_internalnote} = '';
                        $orderinfo->{order_vendornote} = 'Verkaufspreis: ' . "$verkaufsPreis $waehrung\n";
                        if ( $nachlass != 0.0 ) {
                            $orderinfo->{order_vendornote} .= 'Nachlass: ' . "$nachlass $waehrung\n";
                        }
                        if ( $wertPositionsTeil != 0.0 ) {
                            $orderinfo->{order_vendornote} .= 'Positionsteilwert: ' . "$wertPositionsTeil $waehrung\n";
                        }
                        if ( $wertMehrpreise != 0.0 ) {
                            $orderinfo->{order_vendornote} .= 'Mehrpreis: ' . "$wertMehrpreise $waehrung\n";
                        }
                        if ( $wertBearbeitung != 0.0 ) {
                            $orderinfo->{order_vendornote} .= 'Bearbeitungspreis: ' . "$wertBearbeitung $waehrung\n";
                        }
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
                        $emaillog->{'problems'} = '';              # string for accumulating error messages for this order
                        my $item_hash;

                        $emaillog->{'processedItemsCount'} += 1;

                        $item_hash->{homebranch} = $zweigstellencode;
                        $item_hash->{booksellerid} = 'ekz';
                        if ( $auftragsPosition->{'waehrung'} eq 'EUR' && defined($auftragsPosition->{'verkaufsPreis'}) ) {
                            $item_hash->{price} = $gesamtpreis_tax_included;
                            $item_hash->{replacementprice} = $replacementcost_tax_included;    # without regard to $auftragsPosition->{'nachlass'}
                        }
                        $item_hash->{notforloan} = 0;    # item delivered -> can be loaned
                        
                        my ( $biblionumberItem, $biblioitemnumberItem, $itemnumber ) = C4::Items::AddItem($item_hash, $biblionumber);

                        if ( defined $itemnumber && $itemnumber > 0 ) {

                            # update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenReceived> where itemnumber = <itemnumberfrom above C4::Items::AddItem call>
                            my $itemHitRs = undef;
                            my $res = undef;
                            $itemHitRs = Koha::Items->new()->_resultset()->find( { itemnumber => $itemnumber } );
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: itemHitRs->{_column_data}:", Dumper($itemHitRs->{_column_data}), ":\n" if $debugIt;
                            if ( defined $itemHitRs ) {
                                # configurable items record field update via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenReceived")
                                # e.g. setting the 'item available' state (or 'item processed internally' state) in items.notforloan
                                if ( defined($ekzWebServicesSetItemSubfieldsWhenReceived) && length($ekzWebServicesSetItemSubfieldsWhenReceived) > 0 ) {
                                    my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenReceived;
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
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: acquisitionImportItemRS->{_column_data}:", Dumper($acquisitionImportItemRS->{_column_data}), ":\n" if $debugIt;

                            # Insert a record into acquisition_import_object representing the Koha item data.
                            $insParam = {
                                #id => 0, # AUTO
                                acquisition_import_id => $acquisitionImportIdItem,
                                koha_object => "item",
                                koha_object_id => $itemnumber . ''
                            };
                            my $itemImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                            my $itemImportObjectRS = $itemImportObject->_resultset()->create($insParam);
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: itemImportObjectRS->{_column_data}:", Dumper($itemImportObjectRS->{_column_data}), ":\n" if $debugIt;

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
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: acquisitionImportItemDeliveryRS->{_column_data}:", Dumper($acquisitionImportItemDeliveryRS->{_column_data}), ":\n" if $debugIt;

                            if ( $biblioExisting && $emaillog->{'foundTitlesCount'} == 0 ) {
                                $emaillog->{'foundTitlesCount'} = 1;
                            }
                            # positive message for log
                            $emaillog->{'importresult'} = 1;
                            $emaillog->{'importedItemsCount'} += 1;
                        } else {
                            # negative message for log
                            $emaillog->{'problems'} .= "\n" if ( $emaillog->{'problems'} );
                            $emaillog->{'problems'} .= "ERROR: Import der Exemplardaten für EKZ Exemplar-ID: $ekzExemplarID wurde abgewiesen.\n";
                            $emaillog->{'importresult'} = -1;
                            $emaillog->{'importerror'} = 1;
                        }
                        my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                        my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        my $importId = '(ControlNumber)' . $tmp_cn . '(ControlNrId)' . $tmp_cna;    # if cna = 'DE-Rt5' then this cn is the ekz article number
                        $emaillog->{'importIds'}->{$importId} = $itemnumber;
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: importedItemsCount:$emaillog->{'importedItemsCount'}; set next importIds:", $importId, ":\n" if $debugIt;
                        # add result of inserting item to log email
                        my ($titeldata, $isbnean) = ($itemnumber, '');
                        push @{$emaillog->{'records'}}, [$lsEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2, $ordernumber, $basketno];
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: emaillog->{'records'}->[0]:", Dumper($emaillog->{'records'}->[0]), ":\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::genKohaRecords() method3: emaillog->{'records'}->[1]:", Dumper($emaillog->{'records'}->[1]), ":\n" if $debugIt;
                    } # foreach remainig delivered items: create koha item record
                } # koha biblio data have been found or created
            } # end method3: "if ( $updOrInsItemsCount < $deliveredItemsCount)"



            # create @actionresult message for log email, representing 1 title with all its processed items
            my @actionresultTit = ( 'insertRecords', 0, "X", "Y", $emaillog->{'processedTitlesCount'}, $emaillog->{'importedTitlesCount'}, $emaillog->{'foundTitlesCount'}, $emaillog->{'processedItemsCount'}, $emaillog->{'importedItemsCount'}, $emaillog->{'updatedItemsCount'}, $emaillog->{'records'} );
print STDERR "ekzWsDeliveryNote::genKohaRecords() actionresultTit:", @actionresultTit, ":\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::genKohaRecords() actionresultTit->[10]->[0]:", @{$actionresultTit[10]->[0]}, ":\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::genKohaRecords() actionresultTit->[10]->[1]:", @{$actionresultTit[10]->[1]}, ":\n" if $debugIt;
            push @{$emaillog->{'actionresult'}}, \@actionresultTit;
        }

        # create @logresult message for log email, representing all titles of the current $lieferscheinResult with all their processed items
        push @{$emaillog->{'logresult'}}, ['LieferscheinDetail', $messageID, $emaillog->{'actionresult'}, $acquisitionError, $ekzAqbooksellersId, undef];    # arg basketno is undef, because with standing orders multiple delivery baskets are possible
print STDERR "ekzWsDeliveryNote::genKohaRecords() Dumper($emaillog->{'logresult'}): ####################################################################################################################\n" if $debugIt;
print STDERR Dumper($emaillog->{'logresult'}) if $debugIt;
        
        if ( scalar(@{$emaillog->{'logresult'}}) > 0 ) {
            my @importIds = keys %{$emaillog->{'importIds'}};
            ($message, $subject, $haserror) = C4::External::EKZ::lib::EkzKohaRecords->createProcessingMessageText($emaillog->{'logresult'}, "headerTEXT", $emaillog->{'dt'}, \@importIds, $lieferscheinNummer);
            C4::External::EKZ::lib::EkzKohaRecords->sendMessage($ekzCustomerNumber, $message, $subject);
        }

        # attaching ekz order to Koha acquisition:
        if ( length($ekzAqbooksellersId) && defined($basketno) && $basketno > 0 ) {
            # create a basketgroup for this basket and close both basket and basketgroup
            my $aqbasket = &C4::Acquisition::GetBasket($basketno);
print STDERR "ekzWsDeliveryNote::genKohaRecords() Dumper aqbasket:", Dumper($aqbasket), ":\n" if $debugIt;
            if ( $aqbasket ) {
                # close the basket
print STDERR "ekzWsDeliveryNote::genKohaRecords() is calling CloseBasket basketno:", $aqbasket->{basketno}, ":\n" if $debugIt;
                &C4::Acquisition::CloseBasket($aqbasket->{basketno});

                # search/create basket group with aqbasketgroups.name = ekz order number and aqbasketgroups.booksellerid = and update aqbasket accordingly
                my $params = {
                    name => "\'$aqbasket->{basketname}\'",
                    booksellerid => $aqbasket->{booksellerid}
                };
                $basketgroupid  = undef;
                my $aqbasketgroups = &C4::Acquisition::GetBasketgroupsGeneric($params, { orderby => "id DESC" } );
print STDERR "ekzWsDeliveryNote::genKohaRecords() Dumper aqbasketgroups:", Dumper($aqbasketgroups), ":\n" if $debugIt;

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
print STDERR "ekzWsDeliveryNote::genKohaRecords() created basketgroup with name:", $aqbasket->{basketname}, ": having basketgroupid:$basketgroupid:\n" if $debugIt;
                } else {
                    $basketgroupid = $aqbasketgroups->[0]->{id};
print STDERR "ekzWsDeliveryNote::genKohaRecords() found basketgroup with name:", $aqbasket->{basketname}, ": having basketgroupid:$basketgroupid:\n" if $debugIt;
                }

                if ( $basketgroupid ) {
                    # update basket, i.e. set basketgroupid
                    my $basketinfo = {
                        'basketno' => $aqbasket->{basketno},
                        'basketgroupid' => $basketgroupid
                    };
                    &C4::Acquisition::ModBasket($basketinfo);

                    # close the basketgroup
print STDERR "ekzWsDeliveryNote::genKohaRecords() is calling CloseBasketgroup basketgroupid:$basketgroupid:\n" if $debugIt;
                    &C4::Acquisition::CloseBasketgroup($basketgroupid);
                }
            }
        }

    }


    #$dbh->rollback;    # roll it back for TEST XXXWH

    # commit the complete delivery note (only as a single transaction)
    $dbh->commit();
    $dbh->{AutoCommit} = 1;

    return 1;
}

sub processItemHit
{
    my ( $lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsArtikelNr, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog, $updOrInsItemsCountRef, $ekzAqbooksellersId ) = @_;
    my $selParam = '';
    my $updParam = '';
    my $insParam = '';
    my $order = undef;
    my $ordernumber = undef;
    my $basketno = undef;

    # update the item's 'acquisition_import' record and the 'items' record in 3 steps:
    # 1. step: get itemnumber: select koha_object_id from acquisition_import_objects where acquisition_import_id = acquisition_import.id of current $acquisitionImportTitleItemHit
print STDERR "ekzWsDeliveryNote::processItemHit() update item for lsArtikelNr:$lsArtikelNr:\n" if $debugIt;
    $selParam = {
        acquisition_import_id => $acquisitionImportTitleItemHit->get_column('id'),
        koha_object => "item"
    };
    my $titleItemObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
    my $titleItemObjectRS = $titleItemObject->_resultset()->find($selParam);
    my $itemnumber = $titleItemObjectRS->get_column('koha_object_id');
print STDERR "ekzWsDeliveryNote::processItemHit() titleItemObjectRS->{_column_data}:", Dumper($titleItemObjectRS->{_column_data}), ":\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::processItemHit() update item with itemnumber:" . $itemnumber . ":\n" if $debugIt;
    
    # 2. step: update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenReceived> where itemnumber = acquisition_import_objects.koha_object_id (from above result)
    my $itemHitRs = undef;
    my $res = undef;
    if ( defined $titleItemObjectRS && defined $itemnumber ) {
        $itemHitRs = Koha::Items->new()->_resultset()->find( { itemnumber => $itemnumber } );
print STDERR "ekzWsDeliveryNote::processItemHit() 1. itemHitRs->{_column_data}:", Dumper($itemHitRs->{_column_data}), ":\n" if $debugIt;
        if ( defined $itemHitRs ) {
            # configurable items record field update via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenReceived")
            # e.g. setting the 'item available' state (or 'item processed internally' state) in items.notforloan
            if ( defined($ekzWebServicesSetItemSubfieldsWhenReceived) && length($ekzWebServicesSetItemSubfieldsWhenReceived) > 0 ) {
                my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenReceived;
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
            $itemHitRs = Koha::Items->new()->_resultset()->find( { itemnumber => $itemnumber } );

            # attaching ekz order to Koha acquisition: 
            if ( defined($ekzAqbooksellersId) && length($ekzAqbooksellersId) ) {
                ($ordernumber, $basketno) = processItemOrder( $lieferscheinNummer, $lieferscheinDatum, $biblionumber, $itemnumber, $auftragsPosition, $acquisitionImportTitleItemHit );
            }

        }
    }

    # 3. step: update acquisition_import set processingstate = 'delivered' of current $acquisitionImportTitleItemHit
    $res = $acquisitionImportTitleItemHit->update( { processingstate => 'delivered' } );
print STDERR "ekzWsDeliveryNote::processItemHit() acquisitionImportTitleItemHit->update res:", Dumper($res->{_column_data}), ":\n" if $debugIt;

    # set variables of log email
    if ( $emaillog->{'foundTitlesCount'} == 0 ) {
        $emaillog->{'foundTitlesCount'} = 1;
    }
    $emaillog->{'processedItemsCount'} += 1;
    if ( defined $titleItemObjectRS && defined $itemnumber && defined $itemHitRs && defined $res ) {    # item successfully updated
        $$updOrInsItemsCountRef += 1;
        # positive message for log email
        $emaillog->{'importresult'} = 1;
        $emaillog->{'updatedItemsCount'} += 1;
    } else {
        # negative message for log email
        $emaillog->{'problems'} .= "\n" if ( $emaillog->{'problems'} );
        $emaillog->{'problems'} .= "ERROR: Update der Exemplardaten für EKZ ArtikelNr.: " . $lsArtikelNr . " wurde abgewiesen.\n";
        $emaillog->{'importresult'} = -1;
        $emaillog->{'importerror'} = 1;
    }
    my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
    my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
    my $importId = '(ControlNumber)' . $tmp_cn . '(ControlNrId)' . $tmp_cna;    # if cna = 'DE-Rt5' then this cn is the ekz article number
    $emaillog->{'importIds'}->{$importId} = $itemnumber;
print STDERR "ekzWsDeliveryNote::processItemHit() updatedItemsCount:$emaillog->{'updatedItemsCount'}; set next importIds:", $importId, ":\n" if $debugIt;
    
    # add result of updating item to log email
    my ($titeldata, $isbnean) = ($itemnumber, '');
    push @{$emaillog->{'records'}}, [$lsArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2, $ordernumber, $basketno];

    # Insert information on the item delivery in 2 steps:
    # 1. step: Insert an acquisition_import record for the delivery note title, if it does not exist already.
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
print STDERR "ekzWsDeliveryNote::processItemHit() update or insert acquisition_import record for title calling Koha::AcquisitionImport::AcquisitionImports->new()->upd_or_ins(selParam, updParam, insParam) selParam:", Dumper($selParam), ": updParam:", Dumper($updParam), ": insParam:", Dumper($insParam), ":\n" if $debugIt;
    my $acquisitionImportDeliveryNoteTitle = Koha::AcquisitionImport::AcquisitionImports->new();
    $res = $acquisitionImportDeliveryNoteTitle->upd_or_ins($selParam, $updParam, $insParam);   # TODO: evaluate $res
print STDERR "ekzWsDeliveryNote::processItemHit() insert acquisition_import record for delivery title res:", Dumper($res->_resultset()->{_column_data}), ":\n" if $debugIt;

    # 2. step: Insert an acquisition_import record for the delivery note item.
    $insParam = {
        #id => 0, # AUTO
        vendor_id => "ekz",
        object_type => "delivery",
        object_number => $lieferscheinNummer,
        object_date => DateTime::Format::MySQL->format_datetime($lieferscheinDatum),
        rec_type => "item",
        object_item_number => $lieferscheinNummer . '-' . $lsArtikelNr,
        processingstate => "delivered",
        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
        #payload => undef # NULL
        object_reference => $acquisitionImportTitleItemHit->get_column('id')
    };
print STDERR "ekzWsDeliveryNote::processItemHit() insert acquisition_import record for item calling Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->insert(insParam) insParam:", Dumper($insParam), ":\n" if $debugIt;
    my $acquisitionImportDeliveryNoteItem = Koha::AcquisitionImport::AcquisitionImports->new();
    $res = $acquisitionImportDeliveryNoteItem->_resultset()->create($insParam);   # TODO: evaluate $res
print STDERR "ekzWsDeliveryNote::processItemHit() insert acquisition_import record for item res:", Dumper($res->{_column_data}), ":\n" if $debugIt;
}

# If it's an item for Standing Order (<ekzexemplarid> is not sent, but ekzArtikelNr matches a record in acquisition_import with object_number like 'sto.%.ID%' ):
#   Search the matching aqorders record via aqorders_items.
#   Create a basket for this delivery note if not existing,
#   'shift' the order into this basket. Append the old basketname in note field of the new basket (may become a list). Do not delete the old basket even if empty now.
#   If no basketgroup exists for the new basket that contains this order, create such an basketgroup with same name.
#   
sub processItemOrder
{
    #my ( $lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsArtikelNr, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog,  ) = @_;
    my ( $lieferscheinNummer, $lieferscheinDatum, $biblionumber, $itemnumber, $auftragsPosition, $acquisitionImportTitleItemHit ) = @_;

    my $ordernumber_ret = undef;
    my $basketno_ret = undef;
    my $basketgroupid = undef;

print STDERR "ekzWsDeliveryNote::processItemOrder() Start biblionumber:$biblionumber: itemnumber:$itemnumber:\n" if $debugIt;
print STDERR "ekzWsDeliveryNote::processItemOrder() Start acquisitionImportTitleItemHit object_number:", $acquisitionImportTitleItemHit->object_number, ":\n" if $debugIt;

    my $isSTO = 0;
    if ( $acquisitionImportTitleItemHit->object_number =~ /^sto\.\d+\.ID\d+/ ) {
        $isSTO = 1;
    }
print STDERR "ekzWsDeliveryNote::processItemOrder() Start acquisitionImportTitleItemHit isSTO:$isSTO:\n" if $debugIt;

    # search the aqorders record via select * from aqorders where ordernumber = (select ordernumber from aqorders_items where itemnumber = $itemnumber)
    my $aqorder = Koha::Acquisition::Order->new()->search_order_by_item($itemnumber);

print STDERR "ekzWsDeliveryNote::processItemOrder() Dumper aqorder:", Dumper($aqorder), ":\n" if $debugIt;
    if ( !$aqorder ) {
        return ($ordernumber_ret, $basketno_ret);    # both values still undef
    }
    $ordernumber_ret = $aqorder->{ordernumber};
    $basketno_ret = $aqorder->{basketno};

    # search basket of order
    my $aqbasket_order = &C4::Acquisition::GetBasket($aqorder->{basketno});
print STDERR "ekzWsDeliveryNote::processItemOrder() Dumper aqbasket_order:", Dumper($aqbasket_order), ":\n" if $debugIt;
    if ( !$aqbasket_order ) {
        return ($ordernumber_ret, $basketno_ret);
    }

    if ( $isSTO ) {
        # search/create new basket of same bookseller with basketname derived from Delivery note plus pseudo order number derived from customer number and stoID
        my $aqbasket_delivery_name = 'L-' . $lieferscheinNummer . '/' . $aqbasket_order->{basketname};
        my $aqbasket_delivery = undef;
        my $params = {
            basketname => '"'.$aqbasket_delivery_name.'"',
            booksellerid => "$aqbasket_order->{booksellerid}"
        };
        my $aqbasket_delivery_hits = &C4::Acquisition::GetBaskets($params, { orderby => "basketno DESC" });
print STDERR "ekzWsDeliveryNote::processItemOrder() Dumper aqbasket_delivery_hits:", Dumper($aqbasket_delivery_hits), ":\n" if $debugIt;
        if ( defined($aqbasket_delivery_hits) && scalar @{$aqbasket_delivery_hits} > 0 ) {
            $aqbasket_delivery = $aqbasket_delivery_hits->[0];
            
            # reopen basket
            &C4::Acquisition::ReopenBasket($aqbasket_delivery->{basketno});
print STDERR "ekzWsDeliveryNote::processItemOrder() after ReopenBasket\n" if $debugIt;

            my $note = $aqbasket_delivery->{note};
            if ( index($note, $aqbasket_order->{basketname}) == -1 ) {
                my $basketinfo = {
                    basketno => $aqbasket_delivery->{basketno},
                    note => $note . ', ' . $aqbasket_order->{basketname}
                };
                &C4::Acquisition::ModBasket($basketinfo);
            }
        } else {
            my $aqbasket_delivery_no  = &C4::Acquisition::NewBasket($aqbasket_order->{booksellerid}, $aqbasket_order->{authorisedby}, $aqbasket_delivery_name,
                                                                $aqbasket_order->{basketname},"", $aqbasket_order->{basketcontractnumber}, $aqbasket_order->{deliveryplace}, $aqbasket_order->{billingplace}, $aqbasket_order->{is_standing}, $aqbasket_order->{create_items});
            if ( $aqbasket_delivery_no ) {
                my $basketinfo = {
                    basketno => $aqbasket_delivery_no,
                    branch => "$aqbasket_order->{branch}"
                };
                &C4::Acquisition::ModBasket($basketinfo);
                $aqbasket_delivery = &C4::Acquisition::GetBasket($aqbasket_delivery_no);
            }
        }
print STDERR "ekzWsDeliveryNote::processItemOrder() Dumper aqbasket_delivery:$aqbasket_delivery:\n" if $debugIt;
        if ( !$aqbasket_delivery ) {
            return ($ordernumber_ret, $basketno_ret);
        }
        $basketno_ret = $aqbasket_delivery->{basketno};

        # shift order to this new basket
        $params = {
            ordernumber => $aqorder->{ordernumber},
            biblionumber => $aqorder->{biblionumber},
            quantitydelivered => 1,
            delivered_items => [$itemnumber],
            basketno_delivery => $aqbasket_delivery->{basketno}
        };
        $ordernumber_ret = &C4::Acquisition::ModOrderDeliveryNote($params);
            
        # close basket
        &C4::Acquisition::CloseBasket($aqbasket_delivery->{basketno});
print STDERR "ekzWsDeliveryNote::processItemOrder() after CloseBasket\n" if $debugIt;

        # search/create basket group with name derived from Delivery note and same bookseller and update aqbasket_delivery accordingly
        $params = {
            name => '"'.$aqbasket_delivery_name.'"',
            booksellerid => $aqbasket_order->{booksellerid}
        };
        $basketgroupid  = undef;
        my $aqbasketgroups = &C4::Acquisition::GetBasketgroupsGeneric($params, { orderby => "id DESC" } );
print STDERR "ekzWsDeliveryNote::processItemOrder() Dumper aqbasketgroups:", Dumper($aqbasketgroups), ":\n" if $debugIt;

        # create basket group if not existing
        if ( !defined($aqbasketgroups) || scalar @{$aqbasketgroups} == 0 ) {
            $params = { 
                name => $aqbasket_delivery_name,
                closed => 0,
                booksellerid => $aqbasket_delivery->{booksellerid},
                deliveryplace => "$aqbasket_delivery->{deliveryplace}",
                freedeliveryplace => "$aqbasket_delivery->{freedeliveryplace}",
                deliverycomment => "$aqbasket_delivery->{deliverycomment}",
                billingplace => "$aqbasket_delivery->{billingplace}",
            };
            $basketgroupid  = &C4::Acquisition::NewBasketgroup($params);
        } else {
            $basketgroupid = $aqbasketgroups->[0]->{id};
            
            # reopen basketgroup
            &C4::Acquisition::ReOpenBasketgroup($basketgroupid);
print STDERR "ekzWsDeliveryNote::processItemOrder() after ReOpenBasketgroup\n" if $debugIt;
        }
print STDERR "ekzWsDeliveryNote::processItemOrder() basketgroup with name:L-$lieferscheinNummer: has basketgroupid:$basketgroupid:\n" if $debugIt;

        if ( $basketgroupid ) {
            
            # update basket
            my $basketinfo = {
                'basketno' => $aqbasket_delivery->{basketno},
                'basketgroupid' => $basketgroupid
            };
            &C4::Acquisition::ModBasket($basketinfo);
print STDERR "ekzWsDeliveryNote::processItemOrder() after ModBasket\n" if $debugIt;
            
            # close basketgroup
            &C4::Acquisition::CloseBasketgroup($basketgroupid);
print STDERR "ekzWsDeliveryNote::processItemOrder() after CloseBasketgroup\n" if $debugIt;
        }
    }
print STDERR "ekzWsDeliveryNote::processItemOrder() returns ordernumber_ret:", $ordernumber_ret , ": and basketno_ret:$basketno_ret:\n" if $debugIt;

    return ($ordernumber_ret, $basketno_ret);
}

1;
