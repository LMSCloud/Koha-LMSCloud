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
use C4::Branch qw(GetBranches);
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::External::EKZ::lib::EkzWebServices;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::lib::EkzKohaRecords;

our @ISA = qw(Exporter);
our @EXPORT = qw( readLSFromEkzWsLieferscheinList readLSFromEkzWsLieferscheinDetail genKohaRecords );


my $debugIt = 1;
my $updOrInsItemsCount = 0;


###################################################################################################
# read Lieferschein (delivery notes) using ekz web service 'LieferscheinList' (overview data)
###################################################################################################
sub readLSFromEkzWsLieferscheinList {
    my $selVon = shift;
    my $selBis = shift;
	my $selKundennummerWarenEmpfaenger = shift;

    my $result = ();    # hash reference
print STDERR "ekzWsLieferschein::readLSFromEkzWsLieferscheinList() selVon:", $selVon, ": selBis:", defined($selBis) ? $selBis : "undef", ": selKundennummerWarenEmpfaenger:", defined($selKundennummerWarenEmpfaenger) ? $selKundennummerWarenEmpfaenger : "undef", ":\n" if $debugIt;

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsLieferscheinList($selVon, $selBis, $selKundennummerWarenEmpfaenger);
print STDERR "ekzWsLieferschein::readLSFromEkzWsLieferscheinList() result->{'lieferscheinCount'}:$result->{'lieferscheinCount'}:\n" if $debugIt;
print STDERR "ekzWsLieferschein::readLSFromEkzWsLieferscheinList() result->{'lieferscheinRecords'}:$result->{'lieferscheinRecords'}:\n" if $debugIt;

    return $result;
}


###################################################################################################
# read single Lieferschein (delivery note) using ekz web service 'LieferscheinDetail' (detailed data)
###################################################################################################
sub readLSFromEkzWsLieferscheinDetail {
    my $selId = shift;
    my $selLieferscheinnummer = shift;
    my $refLieferscheinDetailElement = shift;    # for storing the LieferscheinDetailElement of the SOAP response body

    my $result = ();    # hash reference
print STDERR "ekzWsLieferschein::readLSFromEkzWsLieferscheinDetail() selId:", defined($selId) ? $selId : "undef", ": selLieferscheinnummer:", defined($selLieferscheinnummer) ? $selLieferscheinnummer : "undef", ":\n" if $debugIt;
    
print STDERR "ekzWsLieferschein::readLSFromEkzWsLieferscheinDetail() \$refLieferscheinDetailElement:", $refLieferscheinDetailElement, ":\n" if $debugIt;
print STDERR Dumper($refLieferscheinDetailElement) if $debugIt;

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsLieferscheinDetail($selId, $selLieferscheinnummer, $refLieferscheinDetailElement);
print STDERR "ekzWsLieferschein::readLSFromEkzWsLieferscheinDetail() result->{'lieferscheinCount'}:$result->{'lieferscheinCount'}:\n" if $debugIt;
print STDERR "ekzWsLieferschein::readLSFromEkzWsLieferscheinDetail() result->{'lieferscheinRecords'}:$result->{'lieferscheinRecords'}:\n" if $debugIt;

    return $result;
}


###################################################################################################
# go through the titles contained in the delivery note and handle items status, 
# generate title data and item data as required
###################################################################################################
sub genKohaRecords {
    my ($messageID, $lieferscheinDetailElement, $lieferscheinRecord) = @_;

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

    print STDERR "ekzWsLieferschein::genKohaRecords() Start;  messageID:$messageID id:$lieferscheinRecord->{'id'}: Lieferscheinnummer:$lieferscheinRecord->{'nummer'}: lieferscheinRecord->{'teilLieferungCount'}:$lieferscheinRecord->{'teilLieferungCount'}\n" if $debugIt;

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
    my $ekzWebServicesSetItemSubfieldsWhenReceived = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenReceived");
    my $ekzWsHideOrderedTitlesInOpac = 1;    # policy: hide title if not explictly set to 'show'
    if( defined($ekzWebServicesHideOrderedTitlesInOpac) && 
        length($ekzWebServicesHideOrderedTitlesInOpac) > 0 &&
        $ekzWebServicesHideOrderedTitlesInOpac == 0 ) {
            $ekzWsHideOrderedTitlesInOpac = 0;
    }

    $lieferscheinNummer = $lieferscheinRecord->{'nummer'};
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
print STDERR "ekzWsLieferschein::genKohaRecords() search delivery note message record in acquisition_import selParam:", Dumper($selParam), ":\n" if $debugIt;

    my $acquisitionImportIdLieferschein;
    my $acquisitionImportLieferschein = Koha::AcquisitionImport::AcquisitionImports->new();
    my $hit = $acquisitionImportLieferschein->_resultset()->find( $selParam );
print STDERR "ekzWsLieferschein::genKohaRecords() ref(acquisitionImportLieferschein):", ref($acquisitionImportLieferschein), ": ref(hit):", ref($hit), ":\n" if $debugIt;
    if ( defined($hit) ) {
        $lieferscheinNummerIsDuplicate = 1;
print STDERR "ekzWsLieferschein::genKohaRecords() hit->{_column_data}:", Dumper($hit->{_column_data}), ":\n" if $debugIt;
        my $mess = sprintf("The delivery note number '%s' has already been used at %s. Processing denied.\n",$lieferscheinNummer, $hit->get_column('processingtime'));
        carp $mess;
    } else {
        my $schemaResultAcquitionImport = $acquisitionImportLieferschein->_resultset()->create($insParam);
        $acquisitionImportIdLieferschein = $schemaResultAcquitionImport->get_column('id');
print STDERR "ekzWsLieferschein::genKohaRecords() ref(schemaResultAcquitionImport):", ref($schemaResultAcquitionImport), ":\n" if $debugIt;
#print STDERR "ekzWsLieferschein::genKohaRecords() Dumper(schemaResultAcquitionImport):", Dumper($schemaResultAcquitionImport), ":\n" if $debugIt;
print STDERR "ekzWsLieferschein::genKohaRecords() Dumper(schemaResultAcquitionImport->{_column_data}):", Dumper($schemaResultAcquitionImport->{_column_data}), ":\n" if $debugIt;
print STDERR "ekzWsLieferschein::genKohaRecords() acquisitionImportIdLieferschein:", $acquisitionImportIdLieferschein, ":\n" if $debugIt;
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

            print STDERR "ekzWsLieferschein::genKohaRecords() teilLieferungRecord gelieferteExemplare:$teilLieferungRecord->{'gelieferteExemplare'}: teilLieferung:$teilLieferungRecord->{'teilLieferung'}: auftragsPositionCount:$teilLieferungRecord->{'auftragsPositionCount'}:\n" if $debugIt;
            my $auftragsPosition = $teilLieferungRecord->{'auftragsPositionRecords'}->[0];    # this array always consists of only 1 element
            print STDERR "ekzWsLieferschein::genKohaRecords() auftragsPosition ekzexemplarid:", defined($auftragsPosition->{'ekzexemplarid'}) ? $auftragsPosition->{'ekzexemplarid'} : 'undef', ": ekzArtikelNr:$auftragsPosition->{'artikelNummer'}: isbn:$auftragsPosition->{'isbn'}: ean:$auftragsPosition->{'ean'}: kundenBestelldatum:$auftragsPosition->{'kundenBestelldatum'}:\n" if $debugIt;
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

            # method1: searching for ekzExemplarid identity (which is preferable)
            if (defined($auftragsPosition->{'ekzexemplarid'}) && length($auftragsPosition->{'ekzexemplarid'}) > 0 && $updOrInsItemsCount < $deliveredItemsCount ) {

                # search in acquisition_import for records representing ordered items with the same ekzExemplarid
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_item_number => $auftragsPosition->{'ekzexemplarid'},
                    rec_type => "item",
                    processingstate => 'ordered'
                };
print STDERR "ekzWsLieferschein::genKohaRecords() method1: search order item record in acquisition_import selParam:", Dumper($selParam), ":\n" if $debugIt;
                my $acquisitionImportEkzExemplarIdHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
print STDERR "ekzWsLieferschein::genKohaRecords() method1: scalar acquisitionImportEkzExemplarIdHits:", scalar $acquisitionImportEkzExemplarIdHits, ":\n" if $debugIt;

                foreach my $acquisitionImportEkzExemplarIdHit ($acquisitionImportEkzExemplarIdHits->all()) {
                    if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                        last;
                    }
print STDERR "ekzWsLieferschein::genKohaRecords() method1: acquisitionImportEkzExemplarIdHit->{_column_data}:", Dumper($acquisitionImportEkzExemplarIdHit->{_column_data}), ":\n" if $debugIt;

                    #read the corresponding title via its biblionumber from acquisition_import_objects
                    # search in acquisition_import for the record representing the ordered title belonging to this item
                    my $selParam = {
                        vendor_id => "ekz",
                        object_type => "order",
                        id => $acquisitionImportEkzExemplarIdHit->get_column('object_reference'),
                        rec_type => "title",
                        processingstate => 'ordered'
                    };
print STDERR "ekzWsLieferschein::genKohaRecords() method1: search title order record in acquisition_import selParam:", Dumper($selParam), ":\n" if $debugIt;
                    my $acquisitionImportTitleHit = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->find($selParam);
print STDERR "ekzWsLieferschein::genKohaRecords() method1: acquisitionImportTitleHit->{_column_data}:", Dumper($acquisitionImportTitleHit->{_column_data}), ":\n" if $debugIt;
                    if ( defined($acquisitionImportTitleHit) ) {
                        my $selParam = {
                            acquisition_import_id => $acquisitionImportTitleHit->get_column('id'),
                            koha_object => "title"
                        };
print STDERR "ekzWsLieferschein::genKohaRecords() method1: search title order record in acquisition_import_objects selParam:", Dumper($selParam), ":\n" if $debugIt;
                        my $titleObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                        my $titleObjectRS = $titleObject->_resultset()->find($selParam);
                        my $selBiblionumber = $titleObjectRS->get_column('koha_object_id');
print STDERR "ekzWsLieferschein::genKohaRecords() method1: titleObjectRS->{_column_data}:", Dumper($titleObjectRS->{_column_data}), ":\n" if $debugIt;

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
                                    push @{$emaillog->{'records'}}, [$tmp_cna, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1];
print STDERR "ekzWsLieferschein::genKohaRecords() method1: emaillog->{'records'}->[0]:", Dumper($emaillog->{'records'}->[0]), ":\n" if $debugIt;
                                } else {
                                    next;    # next in acquisitionImportEkzExemplarIdHits->all()
                                }
                            }
                            &processItemHit($lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsEkzArtikelNr, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportEkzExemplarIdHit, $emaillog);
                        }    #end defined($selBiblionumber)
                    }    # end defined($acquisitionImportTitleHit)
                }    # end foreach acquisitionImportEkzExemplarIdHits->all()
            }    # end method1


            # method2: searching for ekzArtikelNr identity if ekzArtikelNr > 0
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
print STDERR "ekzWsLieferschein::genKohaRecords() method2: scalar acquisitionImportTitleHits:", scalar $acquisitionImportTitleHits->{_column_data}, ":\n" if $debugIt;

                # Search corresponding 'ordered' order items and set them to 'delivered' (in table 'acquisition_import' and in 'items' via system preference ekzWsItemSetSubfieldsWhenReceived).
                # Insert records in table acquisition_import for the title and items.
                foreach my $acquisitionImportTitleHit ($acquisitionImportTitleHits->all()) {
                    if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                        last;
                    }
                    print STDERR "ekzWsLieferschein::genKohaRecords() method2: acquisitionImportTitleHit->{_column_data}:", Dumper($acquisitionImportTitleHit->{_column_data}), ":\n" if $debugIt;
                    
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
print STDERR "ekzWsLieferschein::genKohaRecords() method2: from local DB titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
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
                            push @{$emaillog->{'records'}}, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1];
                        } else {
                            last;   # create the biblio record in the '$updOrInsItemsCount < $deliveredItemsCount' block below (= method3)
                        }
                    }
                    
                    # for this title: search all records in acquisition_order representing its items that are 'ordered' (i.e. can still be delivered)
                    my $selParam = {
                        vendor_id => "ekz",
                        object_type => "order",
                        object_reference => $acquisitionImportTitleHit->get_column('id'),
                        rec_type => "item",
                        processingstate => 'ordered'
                    };
                    my $acquisitionImportTitleItemHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
print STDERR "ekzWsLieferschein::genKohaRecords() method2: acquisitionImportTitleItemHits->{_column_data}:", Dumper($acquisitionImportTitleItemHits->{_column_data}), ":\n" if $debugIt;

                    foreach my $acquisitionImportTitleItemHit ($acquisitionImportTitleItemHits->all()) {
print STDERR "ekzWsLieferschein::genKohaRecords() method2: acquisitionImportTitleItemHit->{_column_data}:", Dumper($acquisitionImportTitleItemHit->{_column_data}), ":\n" if $debugIt;
                        if ( $updOrInsItemsCount >= $deliveredItemsCount ) {
                            last;    # now all $deliveredItemsCount delivered items have been handled 
                        }

                        &processItemHit($lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsEkzArtikelNr, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog);
                    }
                }
            }    # end method2

print STDERR "ekzWsLieferschein::genKohaRecords() deliveredItemsCount:$deliveredItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: lsEkzArtikelNr:$lsEkzArtikelNr:\n" if $debugIt;

            # method3 is for all items for which no acquisition_import record representing the order title could be found
            # if not enough matching items could be found: we suppose a 'normal' order and create the corresponding entries for the remaining items
            if ( $updOrInsItemsCount < $deliveredItemsCount) {
print STDERR "ekzWsLieferschein::genKohaRecords() method3: create item for ekzArtikelNr:$auftragsPosition->{'artikelNummer'}:\n" if $debugIt;

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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: reqParamTitelInfo->{'ekzArtikelNr'}:",$reqParamTitelInfo->{'ekzArtikelNr'},": \n" if $debugIt;

                    $titleHits = { 'count' => 0, 'records' => [] };
                    $biblionumber = 0;
                    $lsEkzArtikelNr = '';
                    # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
                    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLocalDB($reqParamTitelInfo, 1);
print STDERR "ekzWsLieferschein::genKohaRecords() method3: from local DB titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: titleSource:$titleSource:\n" if $debugIt;

                        if ( $titleSource eq '_LMSC' ) {
                            # search title in LMSPool
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLMSPool($reqParamTitelInfo);
print STDERR "ekzWsLieferschein::genKohaRecords() method3: from LMS Pool titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                        } elsif ( $titleSource eq '_EKZWSMD' ) {
                            # detailed query to the ekz title information web service
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromEkzWsMedienDaten($reqParamTitelInfo->{'ekzArtikelNr'});
print STDERR "ekzWsLieferschein::genKohaRecords() method3: from ekz Webservice titleHits->{'count'}:",$titleHits->{'count'},": \n" if $debugIt;
                        } elsif ( $titleSource eq '_WS' ) {
                            # use sparse title data from the LieferscheinDetailElement
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->createTitleFromFields($reqParamTitelInfo);
print STDERR "ekzWsLieferschein::genKohaRecords() method3: from sent titel fields:",$titleHits->{'count'},": \n" if $debugIt;
                        } else {
                            # search title in in the Z39.50 target with z3950servers.servername=$titleSource
                            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromZ3950Target($titleSource,$reqParamTitelInfo);
print STDERR "ekzWsLieferschein::genKohaRecords() method3: from z39.50 search on target:" . $titleSource . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": \n" if $debugIt;
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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: new biblionumber:",$biblionumber,": biblioitemnumber:",$biblioitemnumber,": \n" if $debugIt;
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
                        push @{$emaillog->{'records'}}, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1];
                    }
                }
print STDERR "ekzWsLieferschein::genKohaRecords() method3: biblioExisting:$biblioExisting: biblioInserted:$biblioInserted: biblionumber:$biblionumber:\n" if $debugIt;

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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: acquisitionImportTitleRS->{_column_data}:", Dumper($acquisitionImportTitleRS->{_column_data}), ":\n" if $debugIt;

                    # Insert a record into table acquisition_import_object representing the Koha title data of the 'invented' order.
                    $insParam = {
                        #id => 0, # AUTO
                        acquisition_import_id => $acquisitionImportIdTitle,
                        koha_object => "title",
                        koha_object_id => $biblionumber . ''
                    };
                    my $titleImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                    my $titleImportObjectRS = $titleImportObject->_resultset()->create($insParam);
print STDERR "ekzWsLieferschein::genKohaRecords() method3: titleImportObjectRS->{_column_data}:", Dumper($titleImportObjectRS->{_column_data}), ":\n" if $debugIt;

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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: acquisitionImportTitleDeliveryRS->{_column_data}:", Dumper($acquisitionImportTitleDeliveryRS->{_column_data}), ":\n" if $debugIt;


                    # now add the items data for the new biblionumber
                    my $ekzExemplarID = $ekzBestellNr . '-' . $lsEkzArtikelNr;    # dummy item number for the 'invented' order
                    my $exemplarcount = $deliveredItemsCount - $updOrInsItemsCount;
                    print STDERR "ekzWsLieferschein::genKohaRecords() exemplar ekzExemplarID $ekzExemplarID exemplarcount $exemplarcount\n" if $debugIt;

                    for ( my $j = 0; $j < $exemplarcount; $j++ ) {
                        $emaillog->{'problems'} = '';              # string for accumulating error messages for this order
                        my $item_hash;

                        $emaillog->{'processedItemsCount'} += 1;

                        if ( &C4::External::EKZ::lib::EkzKohaRecords::checkbranchcode($zweigstellenname) ) {
                            $item_hash->{homebranch} = $zweigstellenname;
                        } else {
                            $item_hash->{homebranch} = '';
                        }
                        $item_hash->{booksellerid} = 'ekz';
                        if ( $auftragsPosition->{'waehrung'} eq 'EUR' && defined($auftragsPosition->{'verkaufsPreis'}) ) {
                            if ( defined($auftragsPosition->{'nachlass'}) ) {
                                $item_hash->{price} = $auftragsPosition->{'verkaufsPreis'} - $auftragsPosition->{'nachlass'};
                            } else {
                                $item_hash->{price} = $auftragsPosition->{'verkaufsPreis'};
                            }
                            $item_hash->{replacementprice} = $auftragsPosition->{'verkaufsPreis'};    # without regard to $auftragsPosition->{'nachlass'}
                        }
                        $item_hash->{notforloan} = 0;    # item delivered -> can be loaned
                        
                        my ( $biblionumberItem, $biblioitemnumberItem, $itemnumber ) = C4::Items::AddItem($item_hash, $biblionumber);

                        if ( defined $itemnumber && $itemnumber > 0 ) {

                            # update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenReceived> where itemnumber = <itemnumberfrom above C4::Items::AddItem call>
                            my $itemHitRs = undef;
                        my $res = undef;
                            $itemHitRs = Koha::Items->new()->_resultset()->find( { itemnumber => $itemnumber } );
print STDERR "ekzWsLieferschein::genKohaRecords() method3: itemHitRs->{_column_data}:", Dumper($itemHitRs->{_column_data}), ":\n" if $debugIt;
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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: acquisitionImportItemRS->{_column_data}:", Dumper($acquisitionImportItemRS->{_column_data}), ":\n" if $debugIt;

                            # Insert a record into acquisition_import_object representing the Koha item data.
                            $insParam = {
                                #id => 0, # AUTO
                                acquisition_import_id => $acquisitionImportIdItem,
                                koha_object => "item",
                                koha_object_id => $itemnumber . ''
                            };
                            my $itemImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                            my $itemImportObjectRS = $itemImportObject->_resultset()->create($insParam);
print STDERR "ekzWsLieferschein::genKohaRecords() method3: itemImportObjectRS->{_column_data}:", Dumper($itemImportObjectRS->{_column_data}), ":\n" if $debugIt;

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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: acquisitionImportItemDeliveryRS->{_column_data}:", Dumper($acquisitionImportItemDeliveryRS->{_column_data}), ":\n" if $debugIt;

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
print STDERR "ekzWsLieferschein::genKohaRecords() method3: importedItemsCount:$emaillog->{'importedItemsCount'}; set next importIds:", $importId, ":\n" if $debugIt;
                        # add result of inserting item to log email
                        my ($titeldata, $isbnean) = ($itemnumber, '');
                        push @{$emaillog->{'records'}}, [$lsEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2];
print STDERR "ekzWsLieferschein::genKohaRecords() method3: emaillog->{'records'}->[0]:", Dumper($emaillog->{'records'}->[0]), ":\n" if $debugIt;
print STDERR "ekzWsLieferschein::genKohaRecords() method3: emaillog->{'records'}->[1]:", Dumper($emaillog->{'records'}->[1]), ":\n" if $debugIt;
                    } # foreach remainig delivered items: create koha item record
                } # koha biblio data have been found or created
            } # end method3: "if ( $updOrInsItemsCount < $deliveredItemsCount)"



            # create @actionresult message for log email, representing 1 title with all its processed items
            my @actionresultTit = ( 'insertRecords', 0, "X", "Y", $emaillog->{'processedTitlesCount'}, $emaillog->{'importedTitlesCount'}, $emaillog->{'foundTitlesCount'}, $emaillog->{'processedItemsCount'}, $emaillog->{'importedItemsCount'}, $emaillog->{'updatedItemsCount'}, $emaillog->{'records'} );
print STDERR "ekzWsLieferschein::genKohaRecords() actionresultTit:", @actionresultTit, ":\n" if $debugIt;
print STDERR "ekzWsLieferschein::genKohaRecords() actionresultTit->[10]->[0]:", @{$actionresultTit[10]->[0]}, ":\n" if $debugIt;
print STDERR "ekzWsLieferschein::genKohaRecords() actionresultTit->[10]->[1]:", @{$actionresultTit[10]->[1]}, ":\n" if $debugIt;
            push @{$emaillog->{'actionresult'}}, \@actionresultTit;
        }

        # create @logresult message for log email, representing all titles of the current $lieferscheinResult with all their processed items
        push @{$emaillog->{'logresult'}}, ['LieferscheinDetail', $messageID, $emaillog->{'actionresult'}];
print STDERR "ekzWsLieferschein::genKohaRecords() Dumper($emaillog->{'logresult'}): ####################################################################################################################\n" if $debugIt;
print STDERR Dumper($emaillog->{'logresult'}) if $debugIt;
        
        if ( scalar(@{$emaillog->{'logresult'}}) > 0 ) {
            my @importIds = keys %{$emaillog->{'importIds'}};
            ($message, $subject, $haserror) = C4::External::EKZ::lib::EkzKohaRecords->createProcessingMessageText($emaillog->{'logresult'}, "headerTEXT", $emaillog->{'dt'}, \@importIds, $lieferscheinNummer);
            C4::External::EKZ::lib::EkzKohaRecords->sendMessage($message, $subject);
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
    my ( $lieferscheinNummer, $lieferscheinDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenReceived, $lsArtikelNr, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog ) = @_;
    my $selParam = '';
    my $updParam = '';
    my $insParam = '';

    # update the item's 'acquisition_import' record and the 'items' record in 3 steps:
    # 1. step: get itemnumber: select koha_object_id from acquisition_import_objects where acquisition_import_id = acquisition_import.id of current $acquisitionImportTitleItemHit
print STDERR "ekzWsLieferschein::processItemHit() update item for lsArtikelNr:$lsArtikelNr:\n" if $debugIt;
    $selParam = {
        acquisition_import_id => $acquisitionImportTitleItemHit->get_column('id'),
        koha_object => "item"
    };
    my $titleItemObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
    my $titleItemObjectRS = $titleItemObject->_resultset()->find($selParam);
    my $itemnumber = $titleItemObjectRS->get_column('koha_object_id');
print STDERR "ekzWsLieferschein::processItemHit() titleItemObjectRS->{_column_data}:", Dumper($titleItemObjectRS->{_column_data}), ":\n" if $debugIt;
print STDERR "ekzWsLieferschein::processItemHit() update item with itemnumber:" . $itemnumber . ":\n" if $debugIt;
    
    # 2. step: update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenReceived> where itemnumber = acquisition_import_objects.koha_object_id (from above result)
    my $itemHitRs = undef;
    my $res = undef;
    if ( defined $titleItemObjectRS && defined $itemnumber ) {
        $itemHitRs = Koha::Items->new()->_resultset()->find( { itemnumber => $itemnumber } );
print STDERR "ekzWsLieferschein::processItemHit() 1. itemHitRs->{_column_data}:", Dumper($itemHitRs->{_column_data}), ":\n" if $debugIt;
        if ( defined $itemHitRs ) {
            # configurable items record field update via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenReceived")
            # e.g. setting the 'item available' state (or 'item processed internally' state) in items.notforloan
            if ( defined($ekzWebServicesSetItemSubfieldsWhenReceived) && length($ekzWebServicesSetItemSubfieldsWhenReceived) > 0 ) {
                my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenReceived;
                if ( @affects ) {
                    my $frameworkcode = GetFrameworkCode($biblionumber);
print STDERR "ekzWsLieferschein::processItemHit() Dumper(frameworkcode):", Dumper($frameworkcode), ":\n" if $debugIt;    # XXXWH
                    my ( $itemfield ) = GetMarcFromKohaField( 'items.itemnumber', $frameworkcode );
print STDERR "ekzWsLieferschein::processItemHit() Dumper(itemfield):", Dumper($itemfield), ":\n" if $debugIt;    # XXXWH
                    my $item = C4::Items::GetMarcItem( $biblionumber, $itemnumber );
print STDERR "ekzWsLieferschein::processItemHit() 1. Dumper(item):", Dumper($item), ":\n" if $debugIt;    # XXXWH
                    for my $affect ( @affects ) {
                        my ( $sf, $v ) = split('=', $affect, 2);
                        foreach ( $item->field($itemfield) ) {
                            $_->update( $sf => $v );
                        }
                    }
print STDERR "ekzWsLieferschein::processItemHit() 2. Dumper(item):", Dumper($item), ":\n" if $debugIt;    # XXXWH
                    C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber );
print STDERR "ekzWsLieferschein::processItemHit() 3. Dumper(item):", Dumper($item), ":\n" if $debugIt;    # XXXWH
                }
            }
            $itemHitRs = Koha::Items->new()->_resultset()->find( { itemnumber => $itemnumber } );    # XXXWH
print STDERR "ekzWsLieferschein::processItemHit() 2. itemHitRs->{_column_data}:", Dumper($itemHitRs->{_column_data}), ":\n" if $debugIt;    # XXXWH
        }
    }

    # 3. step: update acquisition_import set processingstate = 'delivered' of current $acquisitionImportTitleItemHit
    $res = $acquisitionImportTitleItemHit->update( { processingstate => 'delivered' } );
print STDERR "ekzWsLieferschein::processItemHit() acquisitionImportTitleItemHit->update res:", Dumper($res->{_column_data}), ":\n" if $debugIt;


    # set variables of log email
    if ( $emaillog->{'foundTitlesCount'} == 0 ) {
        $emaillog->{'foundTitlesCount'} = 1;
    }
    $emaillog->{'processedItemsCount'} += 1;
    if ( defined $titleItemObjectRS && defined $itemnumber && defined $itemHitRs && defined $res ) {    # item successfully updated
        $updOrInsItemsCount += 1;
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
print STDERR "ekzWsLieferschein::processItemHit() updatedItemsCount:$emaillog->{'updatedItemsCount'}; set next importIds:", $importId, ":\n" if $debugIt;
    
    # add result of updating item to log email
    my ($titeldata, $isbnean) = ($itemnumber, '');
    push @{$emaillog->{'records'}}, [$lsArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2];

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
print STDERR "ekzWsLieferschein::processItemHit() update or insert acquisition_import record for title calling Koha::AcquisitionImport::AcquisitionImports->new()->upd_or_ins(selParam, updParam, insParam) selParam:", Dumper($selParam), ": updParam:", Dumper($updParam), ": insParam:", Dumper($insParam), ":\n" if $debugIt;
    my $acquisitionImportDeliveryNoteTitle = Koha::AcquisitionImport::AcquisitionImports->new();
    $res = $acquisitionImportDeliveryNoteTitle->upd_or_ins($selParam, $updParam, $insParam);   # TODO: evaluate $res
print STDERR "ekzWsLieferschein::processItemHit() insert acquisition_import record for delivery title res:", Dumper($res->_resultset()->{_column_data}), ":\n" if $debugIt;

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
print STDERR "ekzWsLieferschein::processItemHit() insert acquisition_import record for item calling Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->insert(insParam) insParam:", Dumper($insParam), ":\n" if $debugIt;
    my $acquisitionImportDeliveryNoteItem = Koha::AcquisitionImport::AcquisitionImports->new();
    $res = $acquisitionImportDeliveryNoteItem->_resultset()->create($insParam);   # TODO: evaluate $res
print STDERR "ekzWsLieferschein::processItemHit() insert acquisition_import record for item res:", Dumper($res->{_column_data}), ":\n" if $debugIt;
}

1;
