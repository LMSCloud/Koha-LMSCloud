package C4::External::EKZ::EkzWsInvoice;

# Copyright 2020-2024 (C) LMSCLoud GmbH
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

use Koha::Plugins;    # this is a hack to avoid the creation of additional database connections by plugins during our database transaction XXXWH
use C4::Acquisition qw( NewBasket GetBasket GetBaskets ModBasket ReopenBasket 
                        GetBasketgroupsGeneric NewBasketgroup CloseBasketgroup ReOpenBasketgroup 
                        GetOrder GetOrderFromItemnumber ModOrderDeliveryNote ModReceiveOrder 
                        GetInvoice GetInvoices AddInvoice CloseInvoice ReopenInvoice );
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::Context;
use C4::Items qw( ModItemFromMarc );    # additionally GetMarcItem is required here, but it is not exported by C4::Items, so we have to use it inofficially
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::lib::EkzKohaRecords;
use Koha::DateUtils qw( output_pref dt_from_string );
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use Koha::Acquisition::Baskets;
use Koha::Acquisition::Booksellers;
use Koha::Acquisition::Order;
use Koha::Database;
use Koha::Item;
use Koha::Items;
use Koha::Logger;
use Koha::Patrons;
use Koha::Biblios;

binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

our @ISA = qw(Exporter);
our @EXPORT = qw( readReFromEkzWsRechnungList readReFromEkzWsRechnungDetail genKohaRecords );



###################################################################################################
# read invoices (Rechnungen) using ekz web service 'RechnungList' (overview data)
###################################################################################################
sub readReFromEkzWsRechnungList {
    my $ekzCustomerNumber = shift;
    my $selVon = shift;
    my $selBis = shift;
	my $selKundennummerWarenEmpfaenger = shift;

    my $result = ();    # hash reference
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsInvoice' });

    $logger->info("readReFromEkzWsRechnungList() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                        ": selVon:" . (defined($selVon) ? $selVon : 'undef') .
                                                        ": selBis:" . (defined($selBis) ? $selBis : 'undef') .
                                                        ": selKundennummerWarenEmpfaenger:" . (defined($selKundennummerWarenEmpfaenger) ? $selKundennummerWarenEmpfaenger : 'undef') .
                                                        ":");

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsRechnungList($ekzCustomerNumber, $selVon, $selBis, $selKundennummerWarenEmpfaenger);

    $logger->info("readReFromEkzWsRechnungList() returns result:" .  Dumper($result) . ":");

    return $result;
}


###################################################################################################
# read single invoice (Rechnung) using ekz web service 'RechnungDetail' (detailed invoice data)
###################################################################################################
sub readReFromEkzWsRechnungDetail {
    my $ekzCustomerNumber = shift;
    my $selId = shift;
    my $selRechnungsnummer = shift;
    my $refRechnungDetailElement = shift;    # for storing the RechnungDetailElement of the SOAP response body

    my $result = ();    # hash reference
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsInvoice' });

    $logger->info("readReFromEkzWsRechnungDetail() START ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') .
                                                          ": selId:" . (defined($selId) ? $selId : 'undef') .
                                                          ": selRechnungsnummer:" . (defined($selRechnungsnummer) ? $selRechnungsnummer : 'undef') .
                                                          ":");
    $logger->trace("readReFromEkzWsRechnungDetail() START \$refRechnungDetailElement:" . $refRechnungDetailElement .
                                                           ": Dumper(\$refRechnungDetailElement):" . Dumper($refRechnungDetailElement) .
                                                           ":");

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $result = $ekzwebservice->callWsRechnungDetail($ekzCustomerNumber, $selId, $selRechnungsnummer, $refRechnungDetailElement);

    $logger->info("readReFromEkzWsRechnungDetail() returns result:" .  Dumper($result) . ":");

    return $result;
}


###################################################################################################
# go through the titles contained in the invoice and handle items status and acquisition data, 
# generate title data and item data as required
###################################################################################################
sub genKohaRecords {
    my ($ekzCustomerNumber, $messageID, $rechnungDetailElement, $rechnungRecord, $createdTitleRecords, $updatedTitleRecords) = @_;
    my $ekzKohaRecord = C4::External::EKZ::lib::EkzKohaRecords->new();

    my $rechnungNummerIsDuplicate = 0;
    my $rechnungIsMehrpreisRechnung = 0;
    my $rechnungNummer = '';
    my $rechnungDatum = '';
    my $mehrpreisRechnung = '';
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsInvoice' });
    my $exceptionThrown;

    my @enabled_plugins = Koha::Plugins::get_enabled_plugins();    # this is a hack to avoid the creation of additional database connections by plugins during our database transaction XXXWH
    my $schema = Koha::Database->schema;
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
                                       ": id:" . (defined($rechnungRecord->{'id'}) ? $rechnungRecord->{'id'} : 'undef') .
                                       ": Rechnungsnummer:" . (defined($rechnungRecord->{'nummer'}) ? $rechnungRecord->{'nummer'} : 'undef') .
                                       ": mehrpreisRechnung:" . (defined($rechnungRecord->{'mehrpreisRechnung'}) ? $rechnungRecord->{'mehrpreisRechnung'} : 'undef') .
                                       ": auftragsPositionCount:" . (defined($rechnungRecord->{'auftragsPositionCount'}) ? $rechnungRecord->{'auftragsPositionCount'} : 'undef') .
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
    my $ekzWebServicesSetItemSubfieldsWhenInvoiced = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenInvoiced");
    # design decision by Norbert: 
    # acquisition_import processingstate 'invoiced' implies 'delivered'.
    # So if a delivery-note-synchronisation happens after the invoice-synchronisation, the delivery-note-synchronisation for the item has to be ignored.

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
    my $acquisitionImportIdRechnung;

    $rechnungNummer = $rechnungRecord->{'nummer'};
    $rechnungNummer =~ s/^\s+|\s+$//g;    # trim spaces
    my $reDatum = $rechnungRecord->{'datum'};
    $rechnungDatum = DateTime->new( year => substr($reDatum,0,4), month => substr($reDatum,5,2), day => substr($reDatum,8,2), time_zone => 'local' );
    $mehrpreisRechnung = $rechnungRecord->{'mehrpreisRechnung'};

    # values for order that eventually has to be created pro forma
    # (This is the case for orders that have not been announced by web services BestellInfo and StoList.)
    my $ekzBestellNr = 'invID' . $rechnungNummer;    # dummy order id in case we have to create an order entry
    my $bestellDatum = $rechnungDatum;               # dummy order date in case we have to create an order entry
    my $dateTimeNow = DateTime->now(time_zone => 'local');


    if ( defined($mehrpreisRechnung) && $mehrpreisRechnung eq 'true' ) {
        $rechnungIsMehrpreisRechnung = 1;
        my $mess = sprintf("The invoice '%s' is a so called 'Mehrpreisrechnung'. Processing denied.\n",$rechnungNummer);
        $logger->info("genKohaRecords() $mess");
    } else {
        # Insert a record into table acquisition_import representing the invoice.
        # If a invoice message record with this invoice number exists already there will be written a log entry
        # and no further processing will be done.
        my $selParam = {
            vendor_id => "ekz",
            object_type => "invoice",
            object_number => $rechnungNummer,
            rec_type => "message",
            processingstate => "invoiced"
        };
        my $insParam = {
            #id => 0, # AUTO
            vendor_id => "ekz",
            object_type => "invoice",
            object_number => $rechnungNummer,
            object_date => DateTime::Format::MySQL->format_datetime($rechnungDatum),    # in local time_zone
            rec_type => "message",
            #object_item_number => "", # NULL
            processingstate => "invoiced",
            processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
            payload => $rechnungDetailElement,
            #object_reference => undef # NULL
        };
        $logger->trace("genKohaRecords() search invoice message record in acquisition_import selParam:" . Dumper($selParam) . ":");

        my $acquisitionImportRechnung = Koha::AcquisitionImport::AcquisitionImports->new();
        my $hit = $acquisitionImportRechnung->_resultset()->search( $selParam )->first();
        if ( defined($hit) ) {
            $rechnungNummerIsDuplicate = 1;
            my $mess = sprintf("The invoice number '%s' has already been used at %s. Processing denied.",$rechnungNummer, $hit->get_column('processingtime'));
            $logger->warn("genKohaRecords() $mess");
            carp 'EkzWsInvoice::genKohaRecords() ' . $mess . "\n";
            $logger->trace("genKohaRecords() hit->{_column_data}:" . Dumper($hit->{_column_data}) . ":");
        } else {
            my $schemaResultAcquitionImport = $acquisitionImportRechnung->_resultset()->create($insParam);
            $acquisitionImportIdRechnung = $schemaResultAcquitionImport->get_column('id');
            $logger->trace("genKohaRecords() ref(schemaResultAcquitionImport):" . ref($schemaResultAcquitionImport) . ":");
            #$logger->trace("genKohaRecords() Dumper(schemaResultAcquitionImport):" . Dumper($schemaResultAcquitionImport) . ":");
            $logger->trace("genKohaRecords() Dumper(schemaResultAcquitionImport->{_column_data}):" . Dumper($schemaResultAcquitionImport->{_column_data}) . ":");
            $logger->trace("genKohaRecords() acquisitionImportIdRechnung:" . $acquisitionImportIdRechnung . ":");
        }
    }



    if ( ! $rechnungNummerIsDuplicate && ! $rechnungIsMehrpreisRechnung ) {
        my $invoiceids = ();    # if all works as designed, the referenced hash should hold exactly 1 element at the end of the loop (additional elements are stored for debugging only)

        # handle each invoiced title        
        foreach my $auftragsPosition ( @{$rechnungRecord->{'auftragsPositionRecords'}} ) {

            my $titleHits = { 'count' => 0, 'records' => [] };
            my $biblioExisting = 0;
            my $biblioInserted = 0;
            my $biblionumber = 0;
            my $biblioitemnumber;
            my $invEkzArtikelNr = '';

            $logger->trace("genKohaRecords() auftragsPosition ekzexemplarid:" . (defined($auftragsPosition->{'ekzexemplarid'}) ? $auftragsPosition->{'ekzexemplarid'} : 'undef') . ": referenznummer:" . (defined($auftragsPosition->{'referenznummer'}) ? $auftragsPosition->{'referenznummer'} : 'undef') . ": artikelNummer:$auftragsPosition->{'artikelNummer'}: isbn:$auftragsPosition->{'isbn'}: ean:$auftragsPosition->{'ean'}: exemplareBestellt:$auftragsPosition->{'exemplareBestellt'}: kundenBestelldatum:$auftragsPosition->{'kundenBestelldatum'}:");
            # according to R. Voitl of ekz one <auftragsposition> can represent multiple items of the same title.
            # RechnungDetail does not contain an 'invoiced items count of this auftragposition'.
            # This thesis of R.Voitl is not supported by H.Laun:
            #     The count of really delivered (and hence invoiced) items can only be deduced from the set of LieferscheinDetail responses that deal wit items of this title order.
            #     As LMSCloud does not use DeliveryNote synchronisation when Invoice synchronisation is activated,
            #     we handle all open (and deliverd, just in case) items having the corresponding ekzExemplarid or referenznummer
            #     # my $invoicedItemsCount = $auftragsPosition->{'exemplareBestellt'};    # This is not the invoiced (=delivered) item quantity but the quantity of items ordered, which may be higher.
            # At the moment we believe in the thesis of H.Laun:
            my $invoicedItemsCount = $auftragsPosition->{'exemplareBestellt'};    # This is the invoiced (=delivered) item quantity
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
            # if not found enough acquisition_import records of rec_type 'item' and processingstate 'ordered' or 'delivered': 'invent' the underlying order and store it

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
            if (defined($auftragsPosition->{'ekzexemplarid'}) && length($auftragsPosition->{'ekzexemplarid'}) > 0 && $updOrInsItemsCount < $invoicedItemsCount ) {

                # search in acquisition_import for records representing ordered or delivered items with the same ekzExemplarid
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_item_number => $auftragsPosition->{'ekzexemplarid'},
                    rec_type => "item",
                    processingstate => { '-IN' => [ 'ordered', 'delivered' ] }    # AND processingstate IN ('ordered', 'delivered')
                };
                $logger->trace("genKohaRecords() method1: search order item record in acquisition_import selParam:" . Dumper($selParam) . ":");
                my $acquisitionImportEkzExemplarIdHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
                $logger->trace("genKohaRecords() method1: scalar acquisitionImportEkzExemplarIdHits:" . scalar $acquisitionImportEkzExemplarIdHits . ":");

                foreach my $acquisitionImportEkzExemplarIdHit ($acquisitionImportEkzExemplarIdHits->all()) {
                    if ( $updOrInsItemsCount >= $invoicedItemsCount ) {
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
                        processingstate => 'ordered'    # processingstate of record with rec_type "title" and object_type => 'order' stays always in state 'ordered'
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
                                $invEkzArtikelNr = '';
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
                                        $invEkzArtikelNr = $tmp_cn;
                                    } else {
                                        $invEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                                    }
                                    $biblioExisting = 1;    # this flag may be required in method 4

                                    # Check if to reread title data via webservice MedienDaten etc. and, if required, (partially) overwrite the title record.
                                    $ekzKohaRecord->overwriteCatalogDataIfRequired($ekzCustomerNumber, $biblionumber, $reqParamTitelInfo, $titleHits->{'records'}->[0], $updatedTitleRecords);

                                    # positive message for log email
                                    $emaillog->{'importresult'} = 2;
                                    $emaillog->{'importedTitlesCount'} += 0;

                                    # add result of finding biblio to log email
                                    ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
                                    push @{$emaillog->{'records'}}, [$invEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                                    $logger->trace("genKohaRecords() method1: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
                                } else {
                                    next;    # next in acquisitionImportEkzExemplarIdHits->all()
                                }
                            }

                            my $invoiceid = &processItemHit($rechnungNummer, $rechnungDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenInvoiced, $invEkzArtikelNr, '', $rechnungRecord, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportEkzExemplarIdHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId, $updatedTitleRecords, $logger);
                            if ( $invoiceid ) {
                                $invoiceids->{$invoiceid} = $invoiceid;
                            }
                        }    #end defined($selBiblionumber)
                    }    # end defined($acquisitionImportTitleHit)
                }    # end foreach acquisitionImportEkzExemplarIdHits->all()
            }    # end method1
            $logger->debug("genKohaRecords() after method 1 invoicedItemsCount:$invoicedItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: invEkzArtikelNr:$invEkzArtikelNr:");


            # method2: searching for ekzArtikelNr and referenznummer identity if ekzArtikelNr > 0 and referenznummer > 0
            #          (Typical for an item of a running standing order since 2020-09-14 or of a running serial order since 2021-01-14,
            #           when referenznummer for standing order item and serial order item was introduced by ekz.)
            if (defined($auftragsPosition->{'artikelNummer'}) && $auftragsPosition->{'artikelNummer'} > 0 && 
                defined($auftragsPosition->{'referenznummer'}) && length($auftragsPosition->{'referenznummer'}) > 0 && 
                $updOrInsItemsCount < $invoicedItemsCount ) {
                # ekz has confirmed that there is sent maximal 1 <referenznummer> XML-element per <auftragsPosition>.
                # If the items of a title are spread over multiple (different) referenznummer values, then multiple <auftragsPosition> blocks will be sent.
                # But when multiple items are assigned to the same referenznummer, we have no information on the items count. So we handle all items having this referenznummer.
                my $invReferenznummer = $auftragsPosition->{'referenznummer'};

                # search in acquisition_import for records representing ordered or deliverd items of a standing order or serial order with the same $ekzCustomerNumber, ekzArtikelNr and referenznummer
                
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
                #     processingstate => { '-IN' => [ 'ordered', 'delivered' ] }    # AND processingstate IN ('ordered', 'delivered')
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
                    processingstate => { '-IN' => [ 'ordered', 'delivered' ] }    # AND processingstate IN ('ordered', 'delivered')
                };

                # 4. executing the whole action separately for sto.% and ser.%: That's just too boring.

                my $orderByParam = { order_by => { -asc => [ "id"] } };
                $logger->trace("genKohaRecords() method2: search order item record in acquisition_import selParam:" . Dumper($selParam) . ": orderByParam:" . Dumper($orderByParam) . ":");
                my $acquisitionImportEkzExemplarIdHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam, $orderByParam);
                $logger->trace("genKohaRecords() method2: scalar acquisitionImportEkzExemplarIdHits:" . scalar $acquisitionImportEkzExemplarIdHits . ":");

                foreach my $acquisitionImportEkzExemplarIdHit ($acquisitionImportEkzExemplarIdHits->all()) {
                    if ( $updOrInsItemsCount >= $invoicedItemsCount ) {
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
                                $invEkzArtikelNr = '';
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
                                        $invEkzArtikelNr = $tmp_cn;
                                    } else {
                                        $invEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                                    }
                                    $biblioExisting = 1;    # this flag may be required in method 4

                                    # Check if to reread title data via webservice MedienDaten etc. and, if required, (partially) overwrite the title record.
                                    $ekzKohaRecord->overwriteCatalogDataIfRequired($ekzCustomerNumber, $biblionumber, $reqParamTitelInfo, $titleHits->{'records'}->[0], $updatedTitleRecords);

                                    # positive message for log email
                                    $emaillog->{'importresult'} = 2;
                                    $emaillog->{'importedTitlesCount'} += 0;

                                    # add result of finding biblio to log email
                                    ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
                                    push @{$emaillog->{'records'}}, [$invEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                                    $logger->trace("genKohaRecords() method2: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
                                } else {
                                    next;    # next in acquisitionImportEkzExemplarIdHits->all()
                                }
                            }

                            my $invoiceid = &processItemHit($rechnungNummer, $rechnungDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenInvoiced, $invEkzArtikelNr, $invReferenznummer, $rechnungRecord, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportEkzExemplarIdHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId, $updatedTitleRecords, $logger);
                            if ( $invoiceid ) {
                                $invoiceids->{$invoiceid} = $invoiceid;
                            }
                        }    #end defined($selBiblionumber)
                    }    # end defined($acquisitionImportTitleHit)
                }    # end foreach acquisitionImportEkzExemplarIdHits->all()
            }    # end method2
            $logger->debug("genKohaRecords() after method 2 invoicedItemsCount:$invoicedItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: invEkzArtikelNr:$invEkzArtikelNr:");


            # method3: searching for ekzArtikelNr identity if ekzArtikelNr > 0
            #          (Typical for an item of a running standing order (but only until 2020-09-13, before referenznummer for standing order item was introduced by ekz).)
            # This method is deactivated since april 2022 (from version 21.05 on) for two reasons:
            # - It is quite shure that all standing order items that have been inserted without referenznummer before 2020-09-14 have already been delivered and invoiced before april 2022.
            # - A item of a title of a current serial order that is also a title of a current standing order would incorrectly be identified as item of the standing order title.
#            if (defined($auftragsPosition->{'artikelNummer'}) && $auftragsPosition->{'artikelNummer'} > 0 && $updOrInsItemsCount < $invoicedItemsCount ) {
#            #if (defined($auftragsPosition->{'artikelNummer'})  && $updOrInsItemsCount < $invoicedItemsCount ) {    # XXXWH maybe there is an standing order that matches the auftragsPosition by ISBN or EAN even if $auftragsPosition->{'artikelNummer'} == 0
#
#                # search in acquisition_import for records representing ordered titles with the same ekzArtikelNr
#                my $selParam = {
#                    vendor_id => "ekz",
#                    object_type => "order",
#                    object_number => { 'like' => 'sto.' . $ekzCustomerNumber . '.ID%' },
#                    object_item_number => $auftragsPosition->{'artikelNummer'},
#                    rec_type => "title"
#                };
#                $logger->trace("genKohaRecords() method3: search title order record in acquisition_import selParam:" . Dumper($selParam) . ":");
#                my $acquisitionImportTitleHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
#                $logger->trace("genKohaRecords() method3: scalar acquisitionImportTitleHits:" . scalar $acquisitionImportTitleHits . ":");
#
#                # Search corresponding 'ordered' or 'delivered' order items and set them to 'invoiced' (in table 'acquisition_import', and in 'items' via system preference ekzWsItemSetSubfieldsWhenInvoiced).
#                # Insert records in table acquisition_import for the title and items.
#                foreach my $acquisitionImportTitleHit ($acquisitionImportTitleHits->all()) {
#                    if ( $updOrInsItemsCount >= $invoicedItemsCount ) {
#                        last;
#                    }
#                    $logger->trace("genKohaRecords() method3: acquisitionImportTitleHit->{_column_data}:" . Dumper($acquisitionImportTitleHit->{_column_data}) . ":");
#
#                    if ( $titleHits->{'count'} == 0 || !defined $titleHits->{'records'}->[0] || !defined($titleHits->{'records'}->[0]->field("001")) || $titleHits->{'records'}->[0]->field("001")->data() != $auftragsPosition->{'artikelNummer'} || !defined($titleHits->{'records'}->[0]->field("003")) || $titleHits->{'records'}->[0]->field("003")->data() ne "DE-Rt5" ) {
#                        # search the biblio record; if not found, create the biblio record in the '$updOrInsItemsCount < $invoicedItemsCount' block below (= method4)
#
#                        $titleHits = { 'count' => 0, 'records' => [] };
#                        $biblionumber = 0;
#                        $biblioExisting = 0;
#                        $invEkzArtikelNr = '';
#                        # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
#                        $titleHits = $ekzKohaRecord->readTitleInLocalDB($reqParamTitelInfo, 7, 1);
#                        $logger->trace("genKohaRecords() method3: from local DB titleHits->{'count'}:" . $titleHits->{'count'} . ":");
#                        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
#                            $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
#                            my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
#                            my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
#                            if ( $tmp_cna eq "DE-Rt5" ) {
#                                $invEkzArtikelNr = $tmp_cn;
#                            } else {
#                                $invEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
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
#                            last;   # create the biblio record in the '$updOrInsItemsCount < $invoicedItemsCount' block below (= method4)
#                        }
#                    }
#
#                    # for this title: search all records in acquisition_import representing its items that are 'ordered' OR 'delivered' (i.e. can still be invoiced)
#                    my $selParam = {
#                        vendor_id => "ekz",
#                        object_type => "order",
#                        object_reference => $acquisitionImportTitleHit->get_column('id'),
#                        rec_type => "item",
#                        processingstate => { '-IN' => [ 'ordered', 'delivered' ] }    # AND processingstate IN ('ordered', 'delivered')
#                    };
#                    my $acquisitionImportTitleItemHits = Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->search($selParam);
#                    $logger->trace("genKohaRecords() method3: scalar acquisitionImportTitleItemHits:" . scalar $acquisitionImportTitleItemHits . ":");
#
#                    foreach my $acquisitionImportTitleItemHit ($acquisitionImportTitleItemHits->all()) {
#                        $logger->trace("genKohaRecords() method3: acquisitionImportTitleItemHit->{_column_data}:" . Dumper($acquisitionImportTitleItemHit->{_column_data}) . ":");
#                        if ( $updOrInsItemsCount >= $invoicedItemsCount ) {
#                            last;    # now all the $invoicedItemsCount invoiced items have been handled 
#                        }
#
#                        my $invoiceid = &processItemHit($rechnungNummer, $rechnungDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenInvoiced, $invEkzArtikelNr, '', $rechnungRecord, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog, \$updOrInsItemsCount, $ekzAqbooksellersId, $updatedTitleRecords, $logger);
#                        if ( $invoiceid ) {
#                            $invoiceids->{$invoiceid} = $invoiceid;
#                        }
#                    }
#                }
#            }    # end method3
#            $logger->debug("genKohaRecords() after method 3 invoicedItemsCount:$invoicedItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: invEkzArtikelNr:$invEkzArtikelNr:");


            # method4 is for all items for which no acquisition_import record representing the order title could be found
            # If not enough matching items could be found, then we suppose a 'monograph' order (i.e. not standing, not serial) and create the corresponding entries for the remaining items.
            if ( $updOrInsItemsCount < $invoicedItemsCount) {
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
                    $reqParamTitelInfo->{'auflage'} = $auftragsPosition->{'auflageNummer'} . $auftragsPosition->{'auflageText'};
                    $logger->debug("genKohaRecords() method4: reqParamTitelInfo->{'ekzArtikelNr'}:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ":");

                    $titleHits = { 'count' => 0, 'records' => [] };
                    $biblionumber = 0;
                    $biblioExisting = 0;
                    $invEkzArtikelNr = '';

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
                    #           Use the sparse title data from the RechnungDetailResponseElement (tag auftragsPosition) for creating a title entry.
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
                                $invEkzArtikelNr = $tmp_cn;
                            } else {
                                $invEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                            }
                            $logger->debug("genKohaRecords() method4: in loop last; searchmode:$searchmode: ekzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": biblionumber:" . $biblionumber . ": invEkzArtikelNr:" . $invEkzArtikelNr . ":");
                            last;    # title data have been found in lastly tested title source
                        }
                        if ( $searchmode == 1 && ! $reqParamTitelInfo->{'ekzArtikelNr'} ) {
                            $logger->debug("genKohaRecords() method4: in loop next1; searchmode:$searchmode: ekzArtikelNr:" . $reqParamTitelInfo->{'ekzArtikelNr'} . ": titleHits->{'count'}:" . $titleHits->{'count'} . ":");
                            next;    # ekzArtikelNr not sent in request, so search for remaining criteria (ISBN, EAN, etc.)
                        }
                        $titleHits = $ekzKohaRecord->readTitleInLocalDB($reqParamTitelInfo, $searchmode, 1);
                        $logger->info("genKohaRecords() method4: in loop searchmode:$searchmode: from local DB titleHits->{'count'}:" . $titleHits->{'count'} . ":");
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
                                    # use sparse title data from the RechnungDetailElement
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
                                $updatedTitleRecords->{$biblionumber}->{biblionumber} = $biblionumber;    # it makes no sense to overwrite title data that have been inserted in this run
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
                            $invEkzArtikelNr = $tmp_cn;
                        }
                        # add result of adding biblio to log email
                        ($titeldata, $isbnean) = $ekzKohaRecord->getShortISBD($titleHits->{'records'}->[0]);
                        push @{$emaillog->{'records'}}, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 1, undef, undef];
                        $logger->trace("genKohaRecords() method4: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
                    }
                }
                $logger->info("genKohaRecords() method4: biblioExisting:$biblioExisting: biblioInserted:$biblioInserted: biblionumber:$biblionumber: invEkzArtikelNr:$invEkzArtikelNr:");

                # now add the acquisition_import and acquisition_import_objects record for the title
                if ( $biblioExisting || $biblioInserted ) {

                    if ( !defined($invEkzArtikelNr) || $invEkzArtikelNr eq '0' || $invEkzArtikelNr eq '' ) {
                        my $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
                        my $tmp_cn = (defined($titleHits->{'records'}->[0]->field("001")) && $titleHits->{'records'}->[0]->field("001")->data()) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                        my $tmp_cna = (defined($titleHits->{'records'}->[0]->field("003")) && $titleHits->{'records'}->[0]->field("003")->data()) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                        $invEkzArtikelNr = $tmp_cna . '-' . $tmp_cn;
                        $logger->info("genKohaRecords() method4: created fallback invEkzArtikelNr:$invEkzArtikelNr:");
                    }
                    $logger->debug("genKohaRecords() method4: using invEkzArtikelNr:$invEkzArtikelNr:");

                    # Insert a record into table acquisition_import representing the title data of the 'invented' order.
                    my $insParam = {
                        #id => 0, # AUTO
                        vendor_id => "ekz",
                        object_type => "order",
                        object_number => $ekzBestellNr,
                        object_date => DateTime::Format::MySQL->format_datetime($bestellDatum),    # in local time_zone
                        rec_type => "title",
                        object_item_number => $invEkzArtikelNr . '',
                        processingstate => "ordered",
                        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                        #payload => NULL, # NULL
                        object_reference => $acquisitionImportIdRechnung
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

                    # Insert a record into table acquisition_import representing the invoice title.
                    $insParam = {
                        #id => 0, # AUTO
                        vendor_id => "ekz",
                        object_type => "invoice",
                        object_number => $rechnungNummer,
                        object_date => DateTime::Format::MySQL->format_datetime($rechnungDatum),
                        rec_type => "title",
                        object_item_number => $invEkzArtikelNr . '',
                        processingstate => "invoiced",
                        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                        #payload => NULL, # NULL
                        object_reference => $acquisitionImportIdTitle
                    };
                    my $acquisitionImportTitleInvoice = Koha::AcquisitionImport::AcquisitionImports->new();
                    my $acquisitionImportTitleInvoiceRS = $acquisitionImportTitleInvoice->_resultset()->create($insParam);
                    $logger->trace("genKohaRecords() method4: acquisitionImportTitleInvoiceRS->{_column_data}:" . Dumper($acquisitionImportTitleInvoiceRS->{_column_data}) . ":");


                    # now add the items data for the new biblionumber
                    my $ekzExemplarID = $ekzBestellNr . '-' . $invEkzArtikelNr;    # dummy item number for the 'invented' order
                    my $exemplarcount = $invoicedItemsCount - $updOrInsItemsCount;
                    $logger->trace("genKohaRecords() method4: exemplar ekzExemplarID:$ekzExemplarID: exemplarcount:$exemplarcount:");

                    # attaching ekz order to Koha acquisition: 
                    # If system preference ekzAqbooksellersId is not empty: create a Koha order basket for collecting the Koha orders created for each title contained in the request that can not be assigned to an existing order.
                    # policy: If ekzAqbooksellersId is not empty but does not identify an aqbooksellers record: create such an record and update ekzAqbooksellersId.
                    $ekzAqbooksellersId = $ekzKohaRecord->checkEkzAqbooksellersId($ekzAqbooksellersId,1);
                    if ( length($ekzAqbooksellersId) ) {
                        # Search or create a Koha acquisition order basket,
                        # i.e. search / insert a record in table aqbasket so that the following new aqorders records can link to it via aqorders.basketno = aqbasket.basketno .
                        my $basketname = 'R-' . $rechnungNummer . '/' .  'R-' . $rechnungNummer;
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
                            $basketno = C4::Acquisition::NewBasket($ekzAqbooksellersId, $authorisedby, $basketname, 'created by ekz RechnungDetail', '', undef, $branchcode, $branchcode, 0, 'ordering');    # XXXWH fixed text ok?
                            $logger->trace("genKohaRecords() method4: created new basket having basketno:" . Dumper($basketno) . ":");
                            if ( $basketno ) {
                                my $basketinfo = {};
                                $basketinfo->{'basketno'} = $basketno;
                                $basketinfo->{'branch'} = $branchcode;
                                $basketinfo->{'booksellerinvoicenumber'} = $rechnungNummer;
                                C4::Acquisition::ModBasket($basketinfo);
                            }
                        }
                        if ( !defined($basketno) || $basketno < 1 ) {
                            $acquisitionError = 1;
                        }
                    }
                    $logger->info("genKohaRecords() method4: ekzAqbooksellersId:$ekzAqbooksellersId: acquisitionError:$acquisitionError: basketno:$basketno:");

                    # Get price info from auftragPosition of sent message, for creating aqorders and items records.
                    my $priceInfo = priceInfoFromMessage($rechnungRecord, $auftragsPosition, $logger);
                        # Attaching ekz order to Koha acquisition: Create a new Koha::Acquisition::Order in the same way as for a delivery note.

                    my $order = undef;
                    my $ordernumber = undef;
                    my $ordernumberFound = undef;
                    my $basketnoFound = undef;
                    my $invoiceid = undef;
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

                        my $haushaltsstelle = "";    # not sent in RechnungDetailResponseElement
                        my $kostenstelle = "";    # not sent in RechnungDetailResponseElement

                        my ($dummy1, $dummy2, $budgetid, $dummy3) = $ekzKohaRecord->checkAqbudget($ekzCustomerNumber, $haushaltsstelle, $kostenstelle, 1);

                        my $orderinfo = {};

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
                        $orderinfo->{orderstatus} = 'ordered';    # This orderstatus is transient; it will immediately be updated by the following call of processItemInvoice().
                        $orderinfo->{rrp} = $priceInfo->{replacementcost_tax_included};    #  corresponds to input field 'Replacement cost' in UI (not discounted, per item)
                        $orderinfo->{replacementprice} = $priceInfo->{replacementcost_tax_included};
                        $orderinfo->{rrp_tax_excluded} = $priceInfo->{replacementcost_tax_excluded};
                        $orderinfo->{rrp_tax_included} = $priceInfo->{replacementcost_tax_included};
                        $orderinfo->{ecost} = $priceInfo->{gesamtpreis_tax_included};     #  corresponds to input field 'Budgeted cost' in UI (discounted, per item); discounted
                        $orderinfo->{ecost_tax_excluded} = $priceInfo->{gesamtpreis_tax_excluded};    # discounted
                        $orderinfo->{ecost_tax_included} = $priceInfo->{gesamtpreis_tax_included};    # discounted
                        $orderinfo->{tax_rate_bak} = $priceInfo->{ustSatz};        #  corresponds to input field 'Tax rate' in UI (7% are stored as 0.07)
                        $orderinfo->{tax_rate_on_ordering} = $priceInfo->{ustSatz};
                        $orderinfo->{tax_rate_on_receiving} = undef;    # This fieldvalue is transient; it will immediately be updated by the following call of processItemInvoice().
                        $orderinfo->{tax_value_bak} = $priceInfo->{ust};        #  corresponds to input field 'Tax value' in UI
                        $orderinfo->{tax_value_on_ordering} = $priceInfo->{ust};
                        # XXXWH or alternatively: $orderinfo->{tax_value_on_ordering} = $orderinfo->{quantity} * $orderinfo->{ecost_tax_excluded} * $orderinfo->{tax_rate_on_ordering};    # see C4::Acquisition.pm
                        $orderinfo->{tax_value_on_receiving} = undef;    # This fieldvalue is transient; it will immediately be updated by the following call of processItemInvoice().
                        $orderinfo->{discount} = $priceInfo->{rabatt};        #  corresponds to input field 'Discount' in UI (5% are stored as 5.0)
                        $logger->trace("genKohaRecords() method4: trying to create Koha order with orderinfo:" . Dumper($orderinfo) . ":");

                        $order = Koha::Acquisition::Order->new($orderinfo);
                        $order->store();
                        $ordernumber = $order->ordernumber();    # ordernumber value has been created by DBS

                        # The aqorders record now is initialized as it would have been by EkzWsDeliveryNote.pm. So it is prepared for the following call of processItemInvoice().
                        # The related aqorders_items records will will be created in one of the next steps, as soon as the items have been created. 
                    }

                    for ( my $j = 0; $j < $exemplarcount; $j++ ) {
                        $ordernumberFound = undef;
                        $basketnoFound = undef;
                        $emaillog->{'problems'} = '';              # string for accumulating error messages for this order
                        my $item_hash;

                        $emaillog->{'processedItemsCount'} += 1;

                        $item_hash->{homebranch} = $zweigstellencode;
                        $item_hash->{booksellerid} = 'ekz';
                        if ( $auftragsPosition->{'waehrung'} eq 'EUR' && defined($auftragsPosition->{'verkaufsPreis'}) ) {
                            $item_hash->{price} = $priceInfo->{gesamtpreis_tax_included};
                            $item_hash->{replacementprice} = $priceInfo->{replacementcost_tax_included};    # without regard to $auftragsPosition->{'nachlass'}
                        }
                        $item_hash->{notforloan} = 0;    # default initialization: 'item is invoiced' implicitly means 'item is delivered' -> can be loaned (may be overwritten via sysprefs ekzWebServicesSetItemSubfieldsWhenOrdered and ekzWebServicesSetItemSubfieldsWhenInvoiced)

                        $item_hash->{biblionumber} = $biblionumber;
                        $item_hash->{biblioitemnumber} = $biblionumber;
                        my $kohaItem = Koha::Item->new( $item_hash )->store( { skip_record_index => 1 } );
                        my $titleRecordBiblionumber = $item_hash->{biblionumber};
                        $updatedTitleRecords->{$titleRecordBiblionumber}->{biblionumber} = $titleRecordBiblionumber;
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
                                            C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber, { skip_record_index => 1 } );   # $updatedTitleRecords->{$titleRecordBiblionumber} has already been set a few lines ago
                                        }
                                    }
                                }
                            }

                            # update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenInvoiced> where itemnumber = <itemnumber from above Koha::Item->new()->store() call>
                            $itemHitCount = $itemHitRs->count( $itemSelParam );
                            $itemHit = $itemHitRs->find( $itemSelParam );
                            $logger->trace("genKohaRecords() method4: searched second time for itemnumber:$itemnumber: itemHitCount:$itemHitCount: itemHit->{_column_data}:" . Dumper($itemHit->{_column_data}) . ":");
                            if ( $itemHitCount > 0 && defined($itemHit->{_column_data}) ) {
                                # configurable items record field update via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenInvoiced")
                                # e.g. setting the 'item available' state (or 'item processed internally' state) in items.notforloan
                                if ( defined($ekzWebServicesSetItemSubfieldsWhenInvoiced) && length($ekzWebServicesSetItemSubfieldsWhenInvoiced) > 0 ) {
                                    my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenInvoiced;
                                    $logger->debug("genKohaRecords() method4: has to do " . scalar @affects . " affects (invoicing)");
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
                                            C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber, { skip_record_index => 1 } );   # $updatedTitleRecords->{$titleRecordBiblionumber} has already been set a few lines ago
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
                                processingstate => "invoiced",
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


                            if ( defined($order) ) {
                                # update Koha acquisition order and update/insert invoice data:
                                my $acquisitionImportTitleItemHit = $acquisitionImportItemRS;
                                if ( defined($ekzAqbooksellersId) && length($ekzAqbooksellersId) ) {
$logger->debug("genKohaRecords() method4: is calling processItemInvoice() itemnumber:$itemnumber: ordernumber:$ordernumber: basketno:$basketno:");
                                    ($ordernumberFound, $basketnoFound, $invoiceid) = processItemInvoice( $rechnungNummer, $rechnungDatum, $biblionumber, $itemnumber, $rechnungRecord, $auftragsPosition, $acquisitionImportTitleItemHit, $updatedTitleRecords, $logger );
$logger->debug("genKohaRecords() method4: after processItemInvoice() itemnumber:$itemnumber: ordernumberFound:$ordernumberFound: basketnoFound:$basketnoFound:");
                                    if ( $invoiceid ) {
                                        $invoiceids->{$invoiceid} = $invoiceid;
                                    }
                                }
                            }

                            # Insert a record into table acquisition_import representing the invoice item data.
                            $insParam = {
                                #id => 0, # AUTO
                                vendor_id => "ekz",
                                object_type => "invoice",
                                object_number => $rechnungNummer,
                                object_date => DateTime::Format::MySQL->format_datetime($rechnungDatum),
                                rec_type => "item",
                                object_item_number => $rechnungNummer . '-' . $invEkzArtikelNr,
                                processingstate => "invoiced",
                                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                                #payload => NULL, # NULL
                                object_reference => $acquisitionImportIdItem
                            };
                            my $acquisitionImportItemInvoice = Koha::AcquisitionImport::AcquisitionImports->new();
                            my $acquisitionImportItemInvoiceRS = $acquisitionImportItemInvoice->_resultset()->create($insParam);
                            $logger->trace("genKohaRecords() method4: acquisitionImportItemInvoiceRS->{_column_data}:" . Dumper($acquisitionImportItemInvoiceRS->{_column_data}) . ":");

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
                        push @{$emaillog->{'records'}}, [$invEkzArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2, $ordernumberFound, $basketnoFound];
                        $logger->trace("genKohaRecords() method4: emaillog->{'records'}->[0]:" . Dumper($emaillog->{'records'}->[0]) . ":");
                        $logger->trace("genKohaRecords() method4: emaillog->{'records'}->[1]:" . Dumper($emaillog->{'records'}->[1]) . ":");
                    } # foreach remainig invoiced items: create koha item record
                } # koha biblio data have been found or created
            } # end method4: "if ( $updOrInsItemsCount < $invoicedItemsCount)"
            $logger->debug("genKohaRecords() after method 4 invoicedItemsCount:$invoicedItemsCount: updOrInsItemsCount:$updOrInsItemsCount: titleHits->{'count'}:$titleHits->{'count'}: biblionumber:$biblionumber: invEkzArtikelNr:$invEkzArtikelNr:");



            # create @actionresult message for log email, representing 1 title with all its processed items
            my @actionresultTit = ( 'insertRecords', 0, "X", "Y", $emaillog->{'processedTitlesCount'}, $emaillog->{'importedTitlesCount'}, $emaillog->{'foundTitlesCount'}, $emaillog->{'processedItemsCount'}, $emaillog->{'importedItemsCount'}, $emaillog->{'updatedItemsCount'}, $emaillog->{'records'} );
            $logger->debug("genKohaRecords() actionresultTit:" . Dumper(\@actionresultTit) . ":");
            push @{$emaillog->{'actionresult'}}, \@actionresultTit;

        }

        my $ekzInvoiceCloseWhenCreated = C4::Context->preference("ekzInvoiceCloseWhenCreated");
        if ( defined($ekzInvoiceCloseWhenCreated)  && $ekzInvoiceCloseWhenCreated eq '1' ) {
            # close the aqinvoices (if all went well, then $invoiceids contains exactly 1 invoiceid)
            foreach my $invoiceid ( sort(keys %{$invoiceids}) ) {
                if ( $invoiceid ) {
                    $logger->debug("genKohaRecords() is calling C4::Acquisition::GetInvoice($invoiceid)");
                    my $invoice = C4::Acquisition::GetInvoice($invoiceid);
                    if ( $invoice && ! $invoice->{closedate} ) {
                        $logger->debug("genKohaRecords() is calling C4::Acquisition::CloseInvoice($invoiceid)");
                        C4::Acquisition::CloseInvoice($invoiceid);
                    }
                }
            }
        }

        # create @logresult message for log email, representing all titles of the current $rechnungResult with all their processed items
        push @{$emaillog->{'logresult'}}, ['RechnungDetail', $messageID, $emaillog->{'actionresult'}, $acquisitionError, $ekzAqbooksellersId, undef, $invoiceids ];    # arg basketno is undef, because with standing orders multiple delivery/invoice baskets are possible
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
        $schema->storage->txn_rollback;    # roll back the complete invoice import, based on thrown exception

        if ( $createdTitleRecords ) {
            foreach my $titleSelHashkey ( sort keys %{$createdTitleRecords} ) {
                if ( $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} ) {
                    next;    # keep elements of createdTitleRecords of preceeding calls that have not been rolled back
                }
                $logger->debug("genKohaRecords() is deleting createdTitleRecords->{$titleSelHashkey} because of database rollback and no other use of this title data");
                delete $createdTitleRecords->{$titleSelHashkey};    # remove elements of createdTitleRecords inserted by current call because this transaction is rolled back
            }
        }
        if ( $updatedTitleRecords ) {
            foreach my $titleRecordBiblionumber ( sort keys %{$updatedTitleRecords} ) {
                if ( $updatedTitleRecords->{$titleRecordBiblionumber}->{isAlreadyCommitted} ) {
                    next;    # keep elements of updatedTitleRecords of preceeding calls that have not been rolled back
                }
                $logger->debug("genKohaRecords() is deleting updatedTitleRecords->{$titleRecordBiblionumber} because of database rollback and no other use of this title/items data");
                delete $updatedTitleRecords->{$titleRecordBiblionumber};    # remove elements of updatedTitleRecords inserted by current call because this transaction is rolled back
            }
        }

        $exceptionThrown->throw();
    };

    # commit the complete invoice import (only as a single transaction)
    $schema->storage->txn_commit;    # in case of a thrown exception this statement is not executed

    my @biblionumbers = ();
    if ( $createdTitleRecords ) {
        foreach my $titleSelHashkey ( sort keys %{$createdTitleRecords} ) {
            if ( $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} ) {
                next;    # keep elements of createdTitleRecords of preceeding calls
            }
            my $biblionumber = $createdTitleRecords->{$titleSelHashkey}->{biblionumber};
            if ( defined $biblionumber ) {
                push @biblionumbers, $biblionumber;
                $logger->debug("genKohaRecords() pushed biblionumber:$biblionumber: to array biblionumbers (new length:" . scalar @biblionumbers . ":).");
            }
            $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} = 1;    # mark elements of createdTitleRecords newly added by current call as committed
            $logger->debug("genKohaRecords() has set createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted}:" . $createdTitleRecords->{$titleSelHashkey}->{isAlreadyCommitted} . ":");
        }
    }
    if ( $updatedTitleRecords ) {
        foreach my $titleRecordBiblionumber ( sort keys %{$updatedTitleRecords} ) {
            if ( defined $titleRecordBiblionumber ) {
                $logger->debug("genKohaRecords() updated title has biblionumber:" . $titleRecordBiblionumber . ":");
                if ( grep( /^$titleRecordBiblionumber$/, @biblionumbers ) == 0 ) {
                    push @biblionumbers, $titleRecordBiblionumber;
                    $logger->debug("genKohaRecords() pushed biblionumber:$titleRecordBiblionumber: of updatedTitleRecords to array biblionumbers (new length:" . scalar @biblionumbers . ":).");
                }
                $updatedTitleRecords->{$titleRecordBiblionumber}->{isAlreadyCommitted} = 1;    # mark elements of updatedTitleRecords newly added by current call as committed
                $logger->debug("genKohaRecords() has set updatedTitleRecords->{$titleRecordBiblionumber}->{isAlreadyCommitted}:" . $updatedTitleRecords->{$titleRecordBiblionumber}->{isAlreadyCommitted} . ":");
            }
        }
    }
    if ( @biblionumbers ) {
        my $indexer = Koha::SearchEngine::Indexer->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );
        $logger->debug("genKohaRecords() is calling indexer->index_records() with biblionumbers:" . Dumper(@biblionumbers) . ":");
        # 1. version works, but works asynchronously:
        #$indexer->index_records( \@biblionumbers, 'specialUpdate', "biblioserver", undef );
        # 2. version works, and hopefully works synchronously:
        try {
            $indexer->update_index( \@biblionumbers, undef );
        } catch {
            my $mess = sprintf("genKohaRecords(): Exception thrown by update_index:%s:, so the index has to be rebuilt manually!!!", $_[0]);
            $logger->error($mess);
            carp "EkzWsSerialOrder::" . $mess . "\n";
        };
    }

    if ( $emaillog && defined($emaillog->{'logresult'}) && scalar(@{$emaillog->{'logresult'}}) > 0 ) {
        my @importIds = keys %{$emaillog->{'importIds'}};
        ($message, $subject, $haserror) = $ekzKohaRecord->createProcessingMessageText($emaillog->{'logresult'}, "headerTEXT", $emaillog->{'dt'}, \@importIds, $rechnungNummer);
        $ekzKohaRecord->sendMessage($ekzCustomerNumber, $message, $subject);
    }

    return 1;
}


# Info der ekz (Hauke Laun) vom 30.09.2020 zu den Geldbetrag-Angaben innerhalb des XML-Elements <auftragsPosition>:
#
# <verkaufspreis> ist der Brutto-Listenpreis eines einzelnen Exemplars (d.h. Einzelpreis) dieses Rechnungspostens
# <exemplareBestellt> ist die Anzahl der in Rechnung gestellten Exemplare dieses Rechnungspostens
# <nachlass> ist der Rabattbetrag, in Summe über alle <exemplareBestellt> Exemplare dieses Rechnungspostens
# <wertMehrpreise> ist die Summe über die Preise aller applizierten Ausstattungen (Foliierung, Fadenheftung etc.) über alle in Rechnung gestellten Exemplare dieses Rechnungspostens
# <wertBearbeitung> ist die Summe über alle Bearbeitungsgebühren über alle in Rechnung gestellten Exemplare dieses Rechnungspostens
# <wertPositionsTeil> = (<exemplareBestellt> * <verkaufsPreis>) - <nachlass>
#
# Es gibt zwei Arten von Rechnungsstellung, nämlich 
# Rechnungsstellungsart A: Mittels einer Rechnung, die im <zahlungsBetrag> nicht nur die Summe der <wertPositionsTeil> Angaben, sondern auch die Summe der <wertBearbeitung> und <wertPositionsTeil> Angaben enthält.
# Rechnungsstellungsart B: Mittels zweier Rechnungen; 
#                              die erste Rechnung, genannt 'Positionsrechnung' oder 'Medienrechnung', enthält im <zahlungsBetrag> nur die Summe der <wertPositionsTeil> Angaben
#                              die zweite Rechnung, genannt 'Mehrpreisrechnung', enthält im <zahlungsBetrag> nur die Summe der <wertMehrpreise> und <wertBearbeitung> Angaben
#                          Die Mehrpreisrechnung ist am Eintrag <mehrpreisRechnung>true</mehrpreisRechnung> zu erkennen, die 'Positionsrechnung' hat den Eintrag <mehrpreisRechnung>false</mehrpreisRechnung>.
# Ob eine Rechnung der Rechnungsstellungsart A vorliegt oder eine Positionsrechnung der Rechnungsstellungsart B läßt sich nur feststellen, wenn mindestens 1 <wertBearbeitung> oder <wertPositionsTeil> größer 0 vorliegt,
# denn dann ergeben sich andere Werte in <zahlungsBetrag>.
#
# Für eine Rechnung der Rechnungsstellungsart A gilt:
#   Bruttopreis einer Auftragsposition = <wertPositionsTeil> + <wertMehrpreise> + <wertBearbeitung>
#   <zahlungsBetrag> = Summe der Bruttopreise aller Auftragspositionen
# Für eine Positionsrechnung der Rechnungsstellungsart B gilt:
#   Bruttopreis einer Auftragsposition = <wertPositionsTeil>
#   <zahlungsBetrag> = Summe der Bruttopreise aller Auftragspositionen
# Für eine Mehrpreisrechnung der Rechnungsstellungsart B gilt:
#   Bruttopreis einer Auftragsposition = <wertMehrpreise> + <wertBearbeitung>
#   <zahlungsBetrag> = Summe der Bruttopreise aller Auftragspositionen
#
# Wir unterstützen ab 19.10.2020 beide Rechnungsstellungsarten und ignorieren dabei die übermittelten Mehrpreisrechnungen.
# Pro Kunde muss aber eine der beiden Rechnungsstellungsarten festgelegt werden, wozu die Systempräferenz 'ekzInvoiceSkipAdditionalCosts' dient.

# Das heisst also auch:
# obige Elemente kommen pro <auftragsPosition> (d.h. pro Rechnungsposten) maximal 1 mal vor

sub priceInfoFromMessage {
    my ($rechnungRecord, $auftragsPosition, $logger) = @_;
    $logger->trace("priceInfoFromMessage() Start auftragsPosition:" . Dumper($auftragsPosition) . ":");

    my $ekzInvoiceSkipAdditionalCosts = C4::Context->preference("ekzInvoiceSkipAdditionalCosts");    # 0 -> add wertMehrpreise and wertBearbeitung to wertPositionsTeil   1 -> skip wertMehrpreise and wertBearbeitung, i.e. take wertPositionsTeil only (as invoice item price)
    my $ustProzentVoll = defined($rechnungRecord->{'ustProzentVoll'}) ? $rechnungRecord->{'ustProzentVoll'} : &C4::External::EKZ::lib::EkzKohaRecords::defaultUstSatz('V') * 100.0;    # e.g. 19.00 for VAT rate of 19% (0.19)
    my $ustProzentHalb = defined($rechnungRecord->{'ustProzentHalb'}) ? $rechnungRecord->{'ustProzentHalb'} : &C4::External::EKZ::lib::EkzKohaRecords::defaultUstSatz('E') * 100.0;    # e.g. 7.00 for VAT rate of 7% (0.07)
    my $priceInfo = {};

    $priceInfo->{exemplareBestellt} = defined($auftragsPosition->{'exemplareBestellt'}) && $auftragsPosition->{'exemplareBestellt'} != 0 ? $auftragsPosition->{'exemplareBestellt'} : "1";
    $priceInfo->{verkaufsPreis} = defined($auftragsPosition->{'verkaufsPreis'}) ? $auftragsPosition->{'verkaufsPreis'} : "0.00";
    $priceInfo->{nachlass} = defined($auftragsPosition->{'nachlass'}) ? $auftragsPosition->{'nachlass'} : "0.00";    # <nachlass> for all exemplareBestellt of this <auftragsPosition> in sum.
    $priceInfo->{nachlassProExemplar} = &C4::External::EKZ::lib::EkzKohaRecords::round( ($priceInfo->{nachlass} / ($priceInfo->{exemplareBestellt} * 1.0)), 2 );    # nachlass per exemplar
    $priceInfo->{rabatt} = "0.0";    # 'rabatt' not sent in RechnungDetailResponseElement.auftragsPosition, so we calculate it from verkaufsPreis and nachlass (15.0 means 15 %)
    if ( $priceInfo->{verkaufsPreis} != 0.0 ) {
        $priceInfo->{rabatt} = ($priceInfo->{nachlass} * 100.0) / ( $priceInfo->{verkaufsPreis} * $priceInfo->{exemplareBestellt} );    # (value 15.0 means 15 %)
    }
    # info by etecture (H. Appel): <wertPositionsTeil> = <verkaufsPreis> - <nachlass>
    # info by ekz (H. Hauke Laun): <wertPositionsTeil> = (<exemplareBestellt> * <verkaufsPreis>) - <nachlass>
    $priceInfo->{wertPositionsTeil} = defined($auftragsPosition->{'wertPositionsTeil'}) ? $auftragsPosition->{'wertPositionsTeil'} : "0.00";
    $priceInfo->{wertMehrpreise} = defined($auftragsPosition->{'wertMehrpreise'}) ? $auftragsPosition->{'wertMehrpreise'} : "0.00";
    $priceInfo->{wertBearbeitung} = defined($auftragsPosition->{'wertBearbeitung'}) ? $auftragsPosition->{'wertBearbeitung'} : "0.00";
    $priceInfo->{waehrung} = defined($auftragsPosition->{'waehrung'}) ? $auftragsPosition->{'waehrung'} : "EUR";
    $priceInfo->{ust} = "0.00";    # 'ust' not sent in RechnungDetailResponseElement.auftragsPosition, so we will calculate it
    $priceInfo->{ustSatz} = $ustProzentHalb / 100.0;    # 'ustSatz' not sent in RechnungDetailResponseElement.auftragsPosition, so we evaluate XML element <ustProzentHalb> or <ustProzentVoll>
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
    my ( $rechnungNummer, $rechnungDatum, $dateTimeNow, $ekzWebServicesSetItemSubfieldsWhenInvoiced, $reArtikelNr, $reReferenznummer, $rechnungRecord, $auftragsPosition, $acquisitionImportTitleHit, $titleHits, $biblionumber, $acquisitionImportTitleItemHit, $emaillog, $updOrInsItemsCountRef, $ekzAqbooksellersId, $updatedTitleRecords, $logger ) = @_;
    my $selParam = '';
    my $updParam = '';
    my $insParam = '';
    my $order = undef;
    my $ordernumberFound = undef;
    my $basketnoFound = undef;
    my $invoiceid_ret = undef;

    # update the item's 'acquisition_import' record and the 'items' record in 3 steps:
    # 1. step: get itemnumber: select koha_object_id from acquisition_import_objects where acquisition_import_id = acquisition_import.id of current $acquisitionImportTitleItemHit
    $logger->info("processItemHit() update item for reArtikelNr:$reArtikelNr: reReferenznummer:$reReferenznummer:");
    $selParam = {
        acquisition_import_id => $acquisitionImportTitleItemHit->get_column('id'),
        koha_object => "item"
    };
    my $titleItemObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
    my $titleItemObjectRS = $titleItemObject->_resultset()->search($selParam)->first();
    my $itemnumber = $titleItemObjectRS->get_column('koha_object_id');
    $logger->trace("processItemHit() titleItemObjectRS->{_column_data}:" . Dumper($titleItemObjectRS->{_column_data}) . ":");
    $logger->trace("processItemHit() candidate item for update has itemnumber:" . $itemnumber . ":");

    # Void the itemnumber if meanwhile the order has been transferred by the library to another bookseller than ekz.
    if ( defined $itemnumber ) {
        my $schema = Koha::Database->schema();
        # try to find the aqorders record for this item
        my $ordernumber;    # stays undefined unless an aqorders_items record exists with this itemnumber
        $selParam = {
            itemnumber => $itemnumber
        };
        my $aqorders_itemsRS = $schema->resultset('AqordersItem')->search($selParam);
        if ( $aqorders_itemsRS && $aqorders_itemsRS->first() ) {
            my $aqorders_itemsHit = $aqorders_itemsRS->first();    # itemnumber is an unique key in table aqorders_items
            if ( $aqorders_itemsHit ) {    # The aqorders_items record does not exist any more if the items record meanwhile has been deleted.
                $ordernumber = $aqorders_itemsHit->get_column('ordernumber');
                $logger->trace("processItemHit() aqorders_itemsHit->{_column_data}:" . Dumper($aqorders_itemsHit->{_column_data}) . ": ordernumber:" . $ordernumber . ":");
            }
        }
        $logger->trace("processItemHit() searched via itemnumber:$itemnumber: in table aqorders_items, found ordernumber:" . $ordernumber . ":");

        if ( $ordernumber ) {
            # try to get the basketno of the aqorders record for this item
            my $basketno;    # stays undefined unless an aqorders record exists with this ordernumber
            $selParam = {
                ordernumber => $ordernumber
            };
            my $aqordersRS = $schema->resultset('Aqorder')->search($selParam);
            if ( $aqordersRS && $aqordersRS->first() ) {
                my $aqordersHit = $aqordersRS->first();    # ordernumber is an unique key in table aqorders
                if ( $aqordersHit ) {    # always true if there is no database inconsistency
                    $basketno = $aqordersHit->get_column('basketno');
                    $logger->trace("processItemHit() aqordersHit->{_column_data}:" . Dumper($aqordersHit->{_column_data}) . ": basketno:" . $basketno . ":");
                }
            }
            $logger->trace("processItemHit() searched via ordernumber:$ordernumber: in table aqorders, found basketno:" . $basketno . ":");

            if ( $basketno ) {
                # compare the booksellerid of this aqbasket with the systempreferences variable for bookseller ekz
                my $booksellerid;    # stays undefined unless an aqbasket record exists with this basketno
                $selParam = {
                    basketno => $basketno
                };
                my $aqbasketRS = $schema->resultset('Aqbasket')->search($selParam);
                if ( $aqbasketRS && $aqbasketRS->first() ) {
                    my $aqbasketHit = $aqbasketRS->first();    # basketno is an unique key in table aqbasket
                    if ( $aqbasketHit ) {    # always true if there is no database inconsistency
                        $booksellerid = $aqbasketHit->get_column('booksellerid');
                        $logger->trace("processItemHit() aqbasketHit->{_column_data}:" . Dumper($aqbasketHit->{_column_data}) . ": booksellerid:" . $booksellerid . ":");
                    }
                }
                $logger->trace("processItemHit() searched via basketno:$basketno: in table aqbasket, found booksellerid:" . $booksellerid . ": for comparing with ekzAqbooksellersId:" . $ekzAqbooksellersId . ":");

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
    
    # 2. step: update items set <fields like specified in ekzWebServicesSetItemSubfieldsWhenInvoiced> where itemnumber = acquisition_import_objects.koha_object_id (from above result)
    #          and, if configured so, update Koha acquisition data via processItemInvoice()
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
            # configurable items record field update via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenInvoiced")
            # e.g. setting the 'item available' state (or 'item processed internally' state) in items.notforloan
            if ( defined($ekzWebServicesSetItemSubfieldsWhenInvoiced) && length($ekzWebServicesSetItemSubfieldsWhenInvoiced) > 0 ) {
                my @affects = split q{\|}, $ekzWebServicesSetItemSubfieldsWhenInvoiced;
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
                        C4::Items::ModItemFromMarc( $item, $biblionumber, $itemnumber, { skip_record_index => 1 } );
                        $logger->trace("processItemHit() after calling C4::Items::ModItemFromMarc biblionumber:$biblionumber: itemnumber:$itemnumber:");
                        my $titleRecordBiblionumber = $biblionumber;
                        $updatedTitleRecords->{$titleRecordBiblionumber}->{biblionumber} = $titleRecordBiblionumber;
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
            # Otherwise there would be created 2 acquisition_import invoice item records instead of 1: one for the old original order item and one for the supplementary order item.
            # It is clearer if only the one for the supplementary order item exists.

            # attaching ekz order to Koha acquisition:
            if ( defined($ekzAqbooksellersId) && length($ekzAqbooksellersId) ) {
                # update Koha acquisition order and update/insert invoice data
                ($ordernumberFound, $basketnoFound, $invoiceid_ret) = processItemInvoice( $rechnungNummer, $rechnungDatum, $biblionumber, $itemnumber, $rechnungRecord, $auftragsPosition, $acquisitionImportTitleItemHit, $updatedTitleRecords, $logger );
                $logger->trace("processItemHit() processItemInvoice() returned ordernumberFound:$ordernumberFound: basketnoFound:$basketnoFound: invoiceid_ret:$invoiceid_ret:");
            } else {
                # no synchronisation with Koha acquisition configured, so just update item prices

                # Get price info from auftragPosition of sent message, for updating/creating aqorders.
                my $priceInfo = priceInfoFromMessage($rechnungRecord, $auftragsPosition, $logger);

                # update item prices
                my $item = Koha::Items->find($itemnumber);
                if ( $item ) {
                    $item->price( $priceInfo->{gesamtpreis_tax_included} );
                    $item->replacementprice( $priceInfo->{replacementcost_tax_included} );
                    $item->replacementpricedate( dt_from_string() );
                    $logger->debug("processItemHit() item->store() itemnumber:" . $itemnumber . ": gesamtpreis:" . $priceInfo->{gesamtpreis_tax_included} . ": replacementcost_tax_included:" . $priceInfo->{replacementcost_tax_included} . ":");
                    $item->store( { skip_record_index => 1 } );
                    my $titleRecordBiblionumber = $item->biblionumber();
                    $updatedTitleRecords->{$titleRecordBiblionumber}->{biblionumber} = $titleRecordBiblionumber;
                } else {
                    $logger->error("processItemHit() item not found for update of price and replacementprice! itemnumber:" . $itemnumber . ": gesamtpreis:" . $priceInfo->{gesamtpreis_tax_included} . ": replacementcost_tax_included:" . $priceInfo->{replacementcost_tax_included} . ":");
                }
            }

            # 3. step: update acquisition_import set processingstate = 'invoiced' of current $acquisitionImportTitleItemHit
            $res = $acquisitionImportTitleItemHit->update( { processingstate => 'invoiced' } );
            $logger->trace("processItemHit() acquisitionImportTitleItemHit->update res:" . Dumper($res->{_column_data}) . ":");

            # Insert information on the invoiced item in 2 steps:
            # 3.1. step: Insert an acquisition_import record for the invoice title, if it does not exist already.
            $selParam = {
                vendor_id => "ekz",
                object_type => "invoice",
                object_number => $rechnungNummer,
                object_date => DateTime::Format::MySQL->format_datetime($rechnungDatum),
                rec_type => "title",
                object_item_number => $reArtikelNr,
                processingstate => "invoiced",
                object_reference => $acquisitionImportTitleHit->get_column('id')
            };
            $updParam = {
                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow)    # in local time_zone
            };
            $insParam = {
                #id => 0, # AUTO
                vendor_id => "ekz",
                object_type => "invoice",
                object_number => $rechnungNummer,
                object_date => DateTime::Format::MySQL->format_datetime($rechnungDatum),
                rec_type => "title",
                object_item_number => $reArtikelNr,
                processingstate => "invoiced",
                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                #payload => undef # NULL
                object_reference => $acquisitionImportTitleHit->get_column('id')
            };
            $logger->trace("processItemHit() update or insert acquisition_import record for title calling Koha::AcquisitionImport::AcquisitionImports->new()->upd_or_ins(selParam, updParam, insParam) with selParam:" . Dumper($selParam) . ": updParam:" . Dumper($updParam) . ": insParam:" . Dumper($insParam) . ":");
            my $acquisitionImportInvoiceTitle = Koha::AcquisitionImport::AcquisitionImports->new();
            my $resInvoiceTitle = $acquisitionImportInvoiceTitle->upd_or_ins($selParam, $updParam, $insParam);   # TODO: evaluate $resInvoiceTitle
            $logger->trace("processItemHit() insert acquisition_import record for invoice title res:" . Dumper($resInvoiceTitle->_resultset()->{_column_data}) . ":");

            # 3.2. step: Insert an acquisition_import record for the invoiced item.
            my $object_item_number;
            if ( $reReferenznummer ) {
                $object_item_number = $rechnungNummer . '-' . $reArtikelNr . '-' . $reReferenznummer;
            } else {
                $object_item_number = $rechnungNummer . '-' . $reArtikelNr;
            }
            $insParam = {
                #id => 0, # AUTO
                vendor_id => "ekz",
                object_type => "invoice",
                object_number => $rechnungNummer,
                object_date => DateTime::Format::MySQL->format_datetime($rechnungDatum),
                rec_type => "item",
                object_item_number => $object_item_number,
                processingstate => "invoiced",
                processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNow),    # in local time_zone
                #payload => undef # NULL
                object_reference => $acquisitionImportTitleItemHit->get_column('id')
            };
            $logger->trace("processItemHit() insert acquisition_import record for item calling Koha::AcquisitionImport::AcquisitionImports->new()->_resultset()->create(insParam) with insParam:" . Dumper($insParam) . ":");
            my $acquisitionImportInvoiceItem = Koha::AcquisitionImport::AcquisitionImports->new();
            my $resInvoiceItem = $acquisitionImportInvoiceItem->_resultset()->create($insParam);   # TODO: evaluate $resInvoiceItem
            $logger->trace("processItemHit() END insert acquisition_import record for item res:" . Dumper($resInvoiceItem->{_column_data}) . ":");
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
        $emaillog->{'problems'} .= "ERROR: Update der Exemplardaten für EKZ ArtikelNr.: " . $reArtikelNr . " wurde abgewiesen.\n";
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
    push @{$emaillog->{'records'}}, [$reArtikelNr, defined $biblionumber ? $biblionumber : "no biblionumber", $emaillog->{'importresult'}, $titeldata, $isbnean, $emaillog->{'problems'}, $emaillog->{'importerror'}, 2, $ordernumberFound, $basketnoFound];

    $logger->trace("processItemHit() END returns invoiceid_ret:$invoiceid_ret:");

    return $invoiceid_ret;
}

# when processing an invoice for an item we have to do the following steps
# - search the corresponding aqinvoices record or create it
# - search the aqorders record representing this item (and may be additional ones) via itemnumber in aqorders_items
# - if the aqorders record stands for one remaining item: update this aqorders record
# - if the aqorders record stands for this and additional items: update this aqorders record and create an additional aqorders record containing data for this item
# - update the corresponding aqinvoices record or create it
# - update of planned and invoiced means etc. will happen automatically
sub processItemInvoice
{
    my ( $rechnungNummer, $rechnungDatum, $biblionumber, $itemnumber, $rechnungRecord, $auftragsPosition, $acquisitionImportTitleItemHit, $updatedTitleRecords, $logger ) = @_;

    my $ordernumber_ret = undef;
    my $basketno_ret = undef;
    my $invoiceid_ret = undef;
    my $basketgroupid = undef;

    $logger->info("processItemInvoice() Start rechnungNummer:$rechnungNummer: rechnungDatum:$rechnungDatum: biblionumber:$biblionumber: itemnumber:$itemnumber: acquisitionImportTitleItemHit id:" . $acquisitionImportTitleItemHit->id . "object_item_number:" . $acquisitionImportTitleItemHit->object_item_number . ":");

    my $isStoOrSer = 0;    # indicates if it is a item of a standing or serial order
    if ( $acquisitionImportTitleItemHit->object_number =~ /^(sto|ser)\.\d+\.ID\d+/ ) {
        $isStoOrSer = 1;    # aqorders record of standing/serial order title has to be shifted from the general aqbaskets record of the standing/serial order to an specific one, if not done already by delivery note synchronisation
    }
    $logger->debug("processItemInvoice() acquisitionImportTitleItemHit isStoOrSer:$isStoOrSer:");

    # 1. step: search the aqorders record of the item via select * from aqorders where ordernumber = (select ordernumber from aqorders_items where itemnumber = $itemnumber)
    my $orderRecord = C4::Acquisition::GetOrderFromItemnumber($itemnumber);

    $logger->debug("processItemInvoice() Dumper orderRecord:" . Dumper($orderRecord) . ":");
    if ( ! $orderRecord ) {
        $logger->error("processItemInvoice() could not find orderRecord via itemnumber:" . $itemnumber . ":");
        # XXXWH signal this error in emaillog
        return ($ordernumber_ret, $basketno_ret, $invoiceid_ret);    # all values still undef
    }
    $ordernumber_ret = $orderRecord->{ordernumber};
    $basketno_ret = $orderRecord->{basketno};
    $logger->debug("processItemInvoice() ordernumber_ret:$ordernumber_ret: basketno_ret:$basketno_ret:");

    # 2. step: search basket of order
    my $aqbasket_of_order = &C4::Acquisition::GetBasket($basketno_ret);
    $logger->debug("processItemInvoice() Dumper aqbasket_of_order:" . Dumper($aqbasket_of_order) . ":");
    if ( !$aqbasket_of_order ) {
        $logger->error("processItemInvoice() could not find aqbasket of order via basketno_ret:" . $basketno_ret . ":");
        # XXXWH signal this error in emaillog
        return ($ordernumber_ret, $basketno_ret, $invoiceid_ret);
    }


    # 3. step: in case of standing or serial order: shift order into separate basket if this has not been done already by delivery note synchronisation
    #
    # In case of standing orders, aqbasket with basketname like S-sto.1005145.ID319 contains aqorders of titles that have been announced via StoList synchronisation.
    # If such an aqorder has already been handled by delivery note synchronisation, it has already been shifted to a basket with basketname 'L-' . $lieferscheinNummer . '/' . $aqbasket_of_order->{basketname};
    # (e.g. L-20343434/S-sto.1005145.ID319)
    # To allow for the case that the delivery note synchronisation has not run yet for this STO title or has not succeeded, we have to do something similar here.
    # difference: we use basketname   'R-' . $rechnungNummer . '/' . $aqbasket_of_order->{basketname}
    #                    instead of   'L-' . $lieferscheinNummer . '/' . $aqbasket_of_order->{basketname}
    # In case of serial orders it is similar, the difference is in the basketname that has the form F-ser.1109403.ID0513230.

    if ( $isStoOrSer && 
         ( $aqbasket_of_order->{basketname} =~ /^S-sto\.\d+\.ID\d+/ ||    # order is part of a standing order and has not been shifted into separate basket by delivery note synchronisation
           $aqbasket_of_order->{basketname} =~ /^F-ser\.\d+\.ID\d+/    )  # order is part of a serial order and has not been shifted into separate basket by delivery note synchronisation
       ) {
        # search/create new basket of same bookseller with basketname derived from ekz invoice plus pseudo order number derived from customer number and stoID
        my $aqbasket_of_invoice_name = 'R-' . $rechnungNummer . '/' . $aqbasket_of_order->{basketname};
        my $aqbasket_of_invoice = undef;
        my $params = {
            basketname => '"'.$aqbasket_of_invoice_name.'"',
            booksellerid => "$aqbasket_of_order->{booksellerid}"
        };
        my $aqbasket_of_invoice_hits = &C4::Acquisition::GetBaskets($params, { orderby => "basketno DESC" });
        $logger->debug("processItemInvoice() Dumper aqbasket_of_invoice_hits:" . Dumper($aqbasket_of_invoice_hits) . ":");
        if ( defined($aqbasket_of_invoice_hits) && scalar @{$aqbasket_of_invoice_hits} > 0 ) {
            $aqbasket_of_invoice = $aqbasket_of_invoice_hits->[0];
            
            # reopen basket
            &C4::Acquisition::ReopenBasket($aqbasket_of_invoice->{basketno});
            $logger->debug("processItemInvoice() after ReopenBasket");

            my $note = $aqbasket_of_invoice->{note};
            if ( index($note, $aqbasket_of_order->{basketname}) == -1 ) {
                my $basketinfo = {
                    basketno => $aqbasket_of_invoice->{basketno},
                    note => $note . ', ' . $aqbasket_of_order->{basketname}
                };
                &C4::Acquisition::ModBasket($basketinfo);
            }
        } else {
            my $aqbasket_of_invoice_no  = &C4::Acquisition::NewBasket($aqbasket_of_order->{booksellerid}, $aqbasket_of_order->{authorisedby}, $aqbasket_of_invoice_name,
                                                                $aqbasket_of_order->{basketname},"", $aqbasket_of_order->{basketcontractnumber}, $aqbasket_of_order->{deliveryplace}, $aqbasket_of_order->{billingplace}, $aqbasket_of_order->{is_standing}, $aqbasket_of_order->{create_items});
            if ( $aqbasket_of_invoice_no ) {
                my $basketinfo = {
                    basketno => $aqbasket_of_invoice_no,
                    branch => "$aqbasket_of_order->{branch}"
                };
                &C4::Acquisition::ModBasket($basketinfo);
                $aqbasket_of_invoice = &C4::Acquisition::GetBasket($aqbasket_of_invoice_no);
            }
        }
        $logger->debug("processItemInvoice() Dumper aqbasket_of_invoice:" . Dumper($aqbasket_of_invoice) . ":");
        if ( !$aqbasket_of_invoice ) {
            $logger->error("processItemInvoice() could NOT find or create aqbasket of invoice; aqbasket_of_invoice_name:" . $aqbasket_of_invoice_name . ":");
            # XXXWH signal this error in emaillog
            return ($ordernumber_ret, $basketno_ret, $invoiceid_ret);
        }
        $basketno_ret = $aqbasket_of_invoice->{basketno};

        # shift order to this new basket
        $params = {
            ordernumber => $orderRecord->{ordernumber},
            biblionumber => $orderRecord->{biblionumber},
            quantitydelivered => 1,
            delivered_items => [$itemnumber],
            basketno_delivery => $aqbasket_of_invoice->{basketno}
        };
        $ordernumber_ret = &C4::Acquisition::ModOrderDeliveryNote($params);
        # the order now resembles an order that is created by delivery note synchronisation (i.e. contains no invoice info yet)
        $orderRecord = C4::Acquisition::GetOrderFromItemnumber($itemnumber);
        $logger->debug("processItemInvoice() Dumper separated for STO orderRecord:" . Dumper($orderRecord) . ":");
        if ( ! $orderRecord ) {
            $logger->error("processItemInvoice() could not find orderRecord for STO; selection params:" . Dumper($params) . ":");
            # XXXWH signal this error in emaillog
            return ($ordernumber_ret, $basketno_ret, $invoiceid_ret);
        }
        $ordernumber_ret = $orderRecord->{ordernumber};
        $basketno_ret = $orderRecord->{basketno};
    
        # close basket searched or created for the invoice handling of the order
        $logger->debug("processItemInvoice() is calling Koha::Acquisition::Baskets->find(basketno:" . $aqbasket_of_invoice->{basketno} . ")");
        my $kohabasket = Koha::Acquisition::Baskets->find($aqbasket_of_invoice->{basketno});
        if ( $kohabasket ) {
            $logger->debug("processItemInvoice() is calling Koha::Acquisition::Baskets->find(basketno:" . $aqbasket_of_invoice->{basketno} . ")->close");
            $kohabasket->close;
        }

        # search/create basket group with name derived from invoice and same bookseller and update aqbasket_of_invoice accordingly
        $params = {
            name => '"'.$aqbasket_of_invoice_name.'"',
            booksellerid => $aqbasket_of_order->{booksellerid}
        };
        $basketgroupid  = undef;
        my $aqbasketgroups = &C4::Acquisition::GetBasketgroupsGeneric($params, { orderby => "id DESC" } );
        $logger->debug("processItemInvoice() Dumper aqbasketgroups:" . Dumper($aqbasketgroups) . ":");

        # create basket group if not existing
        if ( !defined($aqbasketgroups) || scalar @{$aqbasketgroups} == 0 ) {
            $params = { 
                name => $aqbasket_of_invoice_name,
                closed => 0,
                booksellerid => $aqbasket_of_invoice->{booksellerid},
                deliveryplace => "$aqbasket_of_invoice->{deliveryplace}",
                freedeliveryplace => undef,    # setting to NULL
                deliverycomment => undef,    # setting to NULL
                billingplace => "$aqbasket_of_invoice->{billingplace}",
            };
            $basketgroupid  = &C4::Acquisition::NewBasketgroup($params);
        } else {
            $basketgroupid = $aqbasketgroups->[0]->{id};
            
            # reopen basketgroup
            &C4::Acquisition::ReOpenBasketgroup($basketgroupid);
            $logger->debug("processItemInvoice() after ReOpenBasketgroup");
        }
        $logger->info("processItemInvoice() basketgroup with name:R-$rechnungNummer: has basketgroupid:$basketgroupid:");

        if ( $basketgroupid ) {
            
            # update basket
            my $basketinfo = {
                'basketno' => $aqbasket_of_invoice->{basketno},
                'basketgroupid' => $basketgroupid
            };
            &C4::Acquisition::ModBasket($basketinfo);
            $logger->debug("processItemInvoice() after ModBasket");
            
            # close basketgroup
            &C4::Acquisition::CloseBasketgroup($basketgroupid);
            $logger->debug("processItemInvoice() after CloseBasketgroup");
        }
    }

    
    # 4. step: search aqinvoices record of this aqbookseller with invoicenumber = $rechnungNummer
    my $invoice;
    my $invoices = [];
    $logger->debug("processItemInvoice() is calling C4::Acquisition::GetInvoices(invoicenumber_equal:$rechnungNummer, supplierid:" . $aqbasket_of_order->{booksellerid} . ", billingdatefrom:$rechnungDatum, billingdateto:$rechnungDatum)");
    @{$invoices} = C4::Acquisition::GetInvoices(
        invoicenumber_equal => $rechnungNummer,
        supplierid          => $aqbasket_of_order->{booksellerid},
        #billingdatefrom     => $shipmentdatefrom ? output_pref( { str => $rechnungDatum, dateformat => 'iso' } ) : undef,    # rechnungDatum has to be sent, no reformatting required
        #billingdateto       => $shipmentdateto   ? output_pref( { str => $rechnungDatum,   dateformat => 'iso' } ) : undef,    # rechnungDatum has to be sent, no reformatting required
        billingdatefrom     => $rechnungDatum,
        billingdateto       => $rechnungDatum
    );
    $logger->debug("processItemInvoice() found aqinvoices:" . Dumper($invoices) . ":");

    # 5. step: read aqinvoices record or create the aqinvoices record if not existing
    if ( scalar @{$invoices} == 0 ) {
        $logger->debug("processItemInvoice() is calling C4::Acquisition::AddInvoice(invoicenumber:$rechnungNummer: booksellerid:" . $aqbasket_of_order->{booksellerid} . ": billingdate:" . $rechnungDatum . ": shipmentdate:" . dt_from_string . ":");
        my $invoiceid = C4::Acquisition::AddInvoice(
            invoicenumber => $rechnungNummer,
            booksellerid => $aqbasket_of_order->{booksellerid},
            billingdate => $rechnungDatum,
            shipmentdate => dt_from_string
            # not needed until now: shipmentcost => ...,
            # not needed until now: shipmentcost_budgetid => ...,
        );
        if( ! defined $invoiceid ) {
            $logger->error("processItemInvoice() could NOT create invoice via C4::Acquisition::AddInvoice(invoicenumber:$rechnungNummer: booksellerid:" . $aqbasket_of_order->{booksellerid} . ": billingdate:" . $rechnungDatum . ": shipmentdate:" . dt_from_string . ":");
            # XXXWH signal this error in emaillog
            return ($ordernumber_ret, $basketno_ret, $invoiceid_ret);
        }
        $invoice = C4::Acquisition::GetInvoice($invoiceid);
    } else {
        $invoice = C4::Acquisition::GetInvoice($invoices->[0]->{invoiceid});
    }
    $logger->trace("processItemInvoice() found or created invoice:" . Dumper($invoice) . ":");
    $invoiceid_ret = $invoice->{invoiceid};

    # 6. step: reopen aqinvoice if closed (this should not happen in reality)
    if ( $invoice->{closedate} ) {
        C4::Acquisition::ReopenInvoice($invoiceid_ret);
    }

    # 7. step: update and possibly split the aqorders record

    # Get price info from auftragPosition of sent message, for updating/creating aqorders.
    my $priceInfo = priceInfoFromMessage($rechnungRecord, $auftragsPosition, $logger);

    my $order = Koha::Acquisition::Orders->find( $ordernumber_ret );    # contains more fields then $orderRecord; needed for populate_with_prices_for_receiving and ModReceiveOrder()

    ### XXXWH $order->{quantityreceived} += 1; nein, das läuft über ModReceiveOrder
    $order->listprice($priceInfo->{verkaufsPreis});    # in supplier's currency, not discounted, per item (input field 'Vendor price' in UI)
    $order->tax_rate_on_receiving($priceInfo->{ustSatz});    # tax_value_on_receiving is calculated in populate_with_prices_for_receiving() based on this
    my $bookseller = Koha::Acquisition::Booksellers->find( $aqbasket_of_order->{booksellerid} );    # id is primary key
    if ( $bookseller->listincgst ) {    # as far as we know this is always true for bookseller 'ekz'
        $order->unitprice($priceInfo->{gesamtpreis_tax_included});    # discounted price per item (input field 'Actual cost' in UI / entered cost, handling etc. incl. (set to 0.0 in the phase  before receipt))
    } else {
        $order->unitprice($priceInfo->{gesamtpreis_tax_excluded});    # discounted price per item (input field 'Actual cost' in UI / entered cost, handling etc. incl. (set to 0.0 in the phase  before receipt))
    }

    # additional remarks in order_vendornote
    my $new_order_vendornote = $order->{order_vendornote};
    if ( ! $new_order_vendornote ) {
        $new_order_vendornote = '';
    }
    if ( length($new_order_vendornote) && substr($new_order_vendornote,-1) ne "\n" ) {
        $new_order_vendornote .= "\n";
    }
    $new_order_vendornote .= sprintf("Rechnung:\nVerkaufspreis: %.2f %s (Exemplare: %d)\n", $priceInfo->{verkaufsPreis}, $priceInfo->{waehrung}, $priceInfo->{exemplareBestellt});
    if ( $priceInfo->{nachlass} != 0.0 ) {
        $new_order_vendornote .= sprintf("Nachlass: %.2f %s\n", $priceInfo->{nachlass}, $priceInfo->{waehrung});
    }
    if ( $priceInfo->{wertPositionsTeil} != 0.0 ) {
        $new_order_vendornote .= sprintf("Positionsteilwert: %.2f %s\n", $priceInfo->{wertPositionsTeil}, $priceInfo->{waehrung});
    }
    if ( $priceInfo->{wertMehrpreise} != 0.0 ) {
        $new_order_vendornote .= sprintf("Mehrpreis: %.2f %s\n", $priceInfo->{wertMehrpreise}, $priceInfo->{waehrung});
    }
    if ( $priceInfo->{wertBearbeitung} != 0.0 ) {
        $new_order_vendornote .= sprintf("Bearbeitungspreis: %.2f %s\n", $priceInfo->{wertBearbeitung}, $priceInfo->{waehrung});
    }
    $order->order_vendornote($new_order_vendornote);
    $order->discount($priceInfo->{rabatt});    # rabatt value of ekz quotes percents, so 15.0 means 15 %. So the value of $priceInfo->{rabatt} can be used without transformation for aqorders.discount.

    # We explicitly do not manipulate $order->{ecost}, $order->{ecost_tax_excluded} and $order->{ecost_tax_included} here.
    # The simple reason is that also the Koha staff interface does not do this when items are receipt-booked in the Koha acquisition.
    # Probably it is wanted that aqorders.ecost* always shows the estimated costs of the ordering time - even later, when the real cost is known and differing.

    $order->populate_with_prices_for_receiving();
    $logger->trace("processItemInvoice() order->populate_with_prices_for_receiving done, order->{_result}->{_column_data}:" . Dumper($order->{_result}->{_column_data}) . ":");

    # save the quantity received.
    my @received_items = ( $itemnumber );
    my ( $datereceived, $new_ordernumber ) = C4::Acquisition::ModReceiveOrder(
        {
            biblionumber     => $orderRecord->{biblionumber},
            order            => $order->unblessed,
            quantityreceived => 1,    # we are working item by item, i.e. processItemInvoice() is called per item, even if $priceInfo->{exemplareBestellt} > 1
            user             => undef,    # XXXWH welchen $user denn sonst?
            invoice          => $invoice,
            budget_id        => $orderRecord->{budget_id},
            received_items   => \@received_items
        }
    );
    $ordernumber_ret = $new_ordernumber;
    $order = GetOrder($ordernumber_ret);
    $logger->trace("processItemInvoice() ModReceiveOrder done, datereceived:$datereceived: new_ordernumber:$new_ordernumber: (new) order:" . Dumper($order) . ":");

    # update item
    my $item = Koha::Items->find($itemnumber);
    if ( $item ) {
        $item->booksellerid( 'ekz' );    # same value as in BestellInfo, probably better than the correct but 'random' $aqbasket_of_order->{booksellerid} as done by staff interface
        $item->dateaccessioned( $datereceived );
        $item->datelastseen( $datereceived );
        #$item->price( $unitprice );    oder besser:
        $item->price( $priceInfo->{gesamtpreis_tax_included} );
        $item->replacementprice( $priceInfo->{replacementcost_tax_included} );
        $item->replacementpricedate( dt_from_string() );
        $logger->debug("processItemInvoice() item->store() itemnumber:" . $itemnumber . ": gesamtpreis:" . $priceInfo->{gesamtpreis_tax_included} . ": replacementcost_tax_included:" . $priceInfo->{replacementcost_tax_included} . ":");
        $item->store( { skip_record_index => 1 } );
        my $titleRecordBiblionumber = $item->biblionumber();
        $updatedTitleRecords->{$titleRecordBiblionumber}->{biblionumber} = $titleRecordBiblionumber;
    } else {
        $logger->error("processItemInvoice() item not found for update of price and replacementprice! itemnumber:" . $itemnumber . ": gesamtpreis:" . $priceInfo->{gesamtpreis_tax_included} . ": replacementcost_tax_included:" . $priceInfo->{replacementcost_tax_included} . ":");
    }



    $logger->info("processItemInvoice() returns ordernumber_ret:" . $ordernumber_ret . ": basketno_ret:" . $basketno_ret . ": invoiceid_ret:" . $invoiceid_ret . ":");

    return ($ordernumber_ret, $basketno_ret, $invoiceid_ret);
}


1;
