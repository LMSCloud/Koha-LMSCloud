package C4::External::EKZ::EkzWsBestellung;

# Copyright 2020-2022 (C) LMSCLoud GmbH
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

use C4::Context;
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::lib::EkzKohaRecords;
use Koha::Biblios;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use Koha::Logger;

our @ISA = qw(Exporter);
our @EXPORT = qw( BestelleBeiEkz BestelleBeiEkz_Test );

binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );


sub BestelleBeiEkz {
    my ($basketgroupList) = @_;
    my $result = [];
    my $dbh = C4::Context->dbh;

    my $aqbooksellers_hit;    # We assume here exclusive use of aqbookseller 'ekz'. But each library may have a distinct acbooksellers record with name 'ekz.
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::EkzWsBestellung' });

    $logger->info("BestelleBeiEkz() START scalar basketgroupList:" . scalar @{$basketgroupList} . ":");

    foreach my $basketgroup ( @{$basketgroupList} ) {
        $logger->debug("BestelleBeiEkz() basketgroup->basketgroupid:" . $basketgroup->{basketgroupid} . ": ->supplyOption:" . $basketgroup->{supplyOption} . ":");
        my $query_aqbasketgroups = "SELECT * FROM aqbasketgroups WHERE id = ? ";
        my $sth = $dbh->prepare($query_aqbasketgroups);
        $sth->execute($basketgroup->{basketgroupid});

        if ( my $aqbasketgroups_hit = $sth->fetchrow_hashref ) {
            if ( ! defined($aqbooksellers_hit) ) {
                my $query_aqbooksellers = "SELECT * FROM aqbooksellers WHERE id = ? ";
                my $sth = $dbh->prepare($query_aqbooksellers);
                $sth->execute($aqbasketgroups_hit->{'booksellerid'});
                $aqbooksellers_hit = $sth->fetchrow_hashref;

                if ( ! $aqbooksellers_hit ) {
                    my $mess = sprintf("aqbooksellers WHERE id = %s : Not found.",$aqbasketgroups_hit->{'booksellerid'});
                    $logger->warn("BestelleBeiEkz() error: $mess");
                    my $aqbasketgroupRes = {
                        basketgroupid => $basketgroup->{basketgroupid},
                        resultStatus => 0,
                        errorText => $mess
                    };
                    push @{$result}, $aqbasketgroupRes;
                    $sth->finish();    # finish $query_aqbooksellers
                    next;
                }
                $sth->finish();    # finish $query_aqbooksellers
            }
        } else {
            my $mess = sprintf("aqbasketgroups WHERE id = %s : Not found.",$basketgroup->{'basketgroupid'});
            $logger->warn("BestelleBeiEkz() error: $mess");
            my $aqbasketgroupRes = {
                basketgroupid => $basketgroup->{'basketgroupid'},
                resultStatus => 0,
                errorText => $mess
            };
            push @{$result}, $aqbasketgroupRes;
            $sth->finish();    # finish $query_aqbasketgroups
            next;
        }
        $sth->finish();    # finish $query_aqbasketgroups


        my $query_aqbasket = "SELECT * FROM aqbasket WHERE basketgroupid = ? ";

        $sth = $dbh->prepare($query_aqbasket);
        $sth->execute($basketgroup->{basketgroupid});
	    my $aqbasket_hits = $sth->fetchall_arrayref({});

        $logger->info("BestelleBeiEkz() scalar aqbasket_hits:" . scalar @{$aqbasket_hits} . ":");
        if ( ! $aqbasket_hits || scalar @{$aqbasket_hits} == 0 ) {
            my $mess = sprintf("aqbasket WHERE basketgroupid = %s : Not found.",$basketgroup->{'basketgroupid'});
            $logger->warn("BestelleBeiEkz() error: $mess");
            my $aqbasketgroupRes = {
                basketgroupid => $basketgroup->{'basketgroupid'},
                resultStatus => 0,
                errorText => $mess
            };
            push @{$result}, $aqbasketgroupRes;
            $sth->finish();    # finish $query_aqbasket
            next;
        } else {
            # initialize the aqbasketgroupRes result hash
            my $aqbasketgroupRes = {
                basketgroupid => $basketgroup->{'basketgroupid'},
                resultStatus => 1,
                errorText => ''
            };
            my $wsResult;
            my $wsRequest;
            my $wsResponse;

            foreach my $aqbasket_hit ( @{$aqbasket_hits} ) {
                $logger->debug("BestelleBeiEkz() aqbasket_hit->{basketno}:" . $aqbasket_hit->{basketno} . ":");
                $logger->trace("BestelleBeiEkz() aqbasket_hit:" . Dumper($aqbasket_hit) . ":");

                # one basketgroup, containing one basket in our case, triggers one call of ekz webservice 'Bestellung'
                $aqbasketgroupRes->{basketno} = $aqbasket_hit->{basketno};

                # set title-independent parameters for callWsBestellung
                my $param = {};
                $param->{lmsBestellCode} = $aqbasket_hit->{'basketno'};
                # XXXWH $param->{waehrung} = 'EUR';    # or preferably:
                $param->{waehrung} = $aqbooksellers_hit->{'listprice'};    # currency of listprices
                $param->{hauptstelle} = $aqbooksellers_hit->{'accountnumber'};

                $param->{rechnungsEmpfaenger}->{ekzKundenNr} = $aqbooksellers_hit->{'accountnumber'};    # rechnungsEmpfaenger is optional
                # $param->{rechnungsEmpfaenger}->{adresseElement}->{...}     # (ekz believes that adresseElement will be ignored)

                $param->{rechnungsKopieEmpfaenger}->{ekzKundenNr} = $aqbooksellers_hit->{'accountnumber'};    # rechnungsKopieEmpfaenger is optional
                # $param->{rechnungsKopieEmpfaenger}->{adresseElement}->{...}     # (ekz believes that adresseElement will be ignored)

                #$param->{kundenBestellNotiz} = ...;    # 'kundenBestellNotiz' ist optional.    Oder verwenden / woher nehmen?
                #$param->{rfidDatenModell} = ...;    # 'rfidDatenModell' ist optional.    Oder verwenden / woher nehmen?

                #$param->{besteller}->{name} = ...;    # besteller ist Pflichtfeld, darf aber auch leer sein.  Bedeutung: Ansprechpartner für die ekz   Könnte man aus aqcontacts versorgen.
                #$param->{besteller}->{vorname} = ...; # besteller ist Pflichtfeld, darf aber auch leer sein.
                #$param->{besteller}->{email} = ...;   # besteller ist Pflichtfeld, darf aber auch leer sein.
                #$param->{besteller}->{ekzid} = ...;   # besteller ist Pflichtfeld, darf aber auch leer sein.

                $param->{quellSystem} = 'LMSCloud';    # 'quellSystem' ist optional.  Oder Angabe der Untergruppe, z.B. DKSH Rendsburg? Woher dann nehmen?



                # now accumulate the title- and item-dependent parameters
                my $query_aqorders = "SELECT * FROM aqorders WHERE basketno = ? ORDER BY ordernumber";

                my $sth = $dbh->prepare($query_aqorders);
                $sth->execute($aqbasket_hit->{'basketno'});
	            my $aqorders_hits = $sth->fetchall_arrayref({});

                $logger->info("BestelleBeiEkz() scalar aqorders_hits:" . scalar @{$aqorders_hits} . ":");
                my $iTitel = 0;
                my $gesamtpreisSum = 0.0;
                foreach my $aqorders_hit ( @{$aqorders_hits} ) {
                    $logger->debug("BestelleBeiEkz() aqorders_hit->{ordernumber}:" . $aqorders_hit->{'ordernumber'} . ":");
                    $logger->trace("BestelleBeiEkz() aqorders_hit:" . Dumper($aqorders_hit) . ":");

                    $aqbasketgroupRes->{aqorders}->{$aqorders_hit->{'ordernumber'}} = 
                        { ordernumber => $aqorders_hit->{'ordernumber'},
                          biblionumber => $aqorders_hit->{'biblionumber'},
                          quantity => $aqorders_hit->{'quantity'},
                          orderstatus => $aqorders_hit->{'orderstatus'},
                          orderitemnumbers => []
                        };
                    my $query_aqorders_items = "SELECT * FROM aqorders_items WHERE ordernumber = ? ORDER BY itemnumber ";
                    my $sth = $dbh->prepare($query_aqorders_items);
                    $sth->execute($aqorders_hit->{'ordernumber'});
	                my $aqorders_items_hits = $sth->fetchall_arrayref({});
                    $logger->info("BestelleBeiEkz() scalar aqorders_items_hits:" . scalar @{$aqorders_items_hits} . ":");
                    foreach my $aqorders_items_hit ( @{$aqorders_items_hits} ) {
                        push @{$aqbasketgroupRes->{aqorders}->{$aqorders_hit->{'ordernumber'}}->{orderitemnumbers}}, $aqorders_items_hit->{'itemnumber'};
                    }
                    $sth->finish();    # finish $query_aqorders_items

                    # Do not accept Koha orders with order status != 'new' or quantity == 0 or without aqorders_items.
                    # If no regular (new, ordered, etc.) order with items exists in this aqbasket at all, then no BestellInfo request for this aqbasket/aqbasketgroup will be sent.
                    if ( $aqorders_hit->{'orderstatus'} eq 'cancelled' ||
                         $aqorders_hit->{'quantity'} < 1 ||
                         scalar @{$aqbasketgroupRes->{aqorders}->{$aqorders_hit->{'ordernumber'}}->{orderitemnumbers}} < 1 ) {

                        my $mess = sprintf("warning: Koha aqorder is skipped! (ordernumber:%s: orderstatus:%s: quantity:%s: items:%s:.",
                                            $aqorders_hit->{'ordernumber'}, $aqorders_hit->{'orderstatus'}, $aqorders_hit->{'quantity'},
                                            scalar @{$aqbasketgroupRes->{aqorders}->{$aqorders_hit->{'ordernumber'}}->{orderitemnumbers}});
                        $logger->warn("BestelleBeiEkz() error: $mess");

                        next;    # trying our luck with next aqorders hit
                    }

                    # set aqorder specific parameters for callWsBestellung (representing all items of one title)
                    
                    my $ekzArtikelNr = '';
                    my $isbnEan = '';
                    my $author = '';
                    my $titel = '';
                    my $verlag = '';
                    my $erscheinungsJahr = '';

                    $logger->debug("BestelleBeiEkz() Koha::Biblios->find->metadata->record of biblionumber:" . $aqorders_hit->{'biblionumber'} . ":");
                    my $biblio = Koha::Biblios->find( $aqorders_hit->{'biblionumber'} );
                    my $marcrecord = $biblio ? $biblio->metadata->record : undef;

                    if ( $marcrecord ) {
                        my ( @fields, $field );

                        # get ekz-Artikelnummer
                        # field 035 is multiple; select entry for DE-Rt5
                        @fields = $marcrecord->field('035');
                        foreach $field ( @fields ) {
                            if ( $field ) {
                                my $subfield = $field->subfield('a');    # format: (DE-Rt5)nnn...nnn
                                if ( $subfield ) {
                                    if ( $subfield =~ /^\s*\(DE\-Rt5\)(.*?)\s*$/ ) {
                                        $ekzArtikelNr = $1;
                                        if ( $ekzArtikelNr =~ /^\s*([0-9]+)\s*$/ ) {
                                            $ekzArtikelNr = $1;
                                        } else {
                                            $ekzArtikelNr = '';
                                        }
                                        last;
                                    }
                                }
                            }
                        }

                        # get ISBN / EAN
                        # fields 020 and 024 are multiple; select a syntactically correct ISBN if possible
                        @fields = $marcrecord->field('020');
                        my $firstIsbn;
                        foreach $field ( @fields ) {
                            my $isbn = $field->subfield('a');
                            if ( $isbn ) {
                                eval {
                                    my $val = Business::ISBN->new($isbn);
                                    $isbn = $val->as_isbn13()->as_string([]);
                                };
                                if ( ! $firstIsbn ) {
                                    $firstIsbn = $isbn;    # found fall back ISBN
                                }
                                if ( $isbn =~ /^\d{13}$/ ) {
                                    $isbnEan = $isbn;    # found syntactically correct ISBN
                                    last;
                                }
                            }
                        }
                        if ( ! $isbnEan ) {
                            $isbnEan = $firstIsbn;
                        }
                        $field = $marcrecord->field('024');
                        if ( $field && ((! defined($isbnEan)) || $isbnEan eq '') ) {
                            my $ean = $field->subfield('a');
                            $isbnEan = $ean;
                        }

                        # get author
                        $field = $marcrecord->field('100');
                        if ( $field ) {
                            my $subfield = $field->subfield('a');
                            if ( $subfield ) {
                                $author = $subfield;
                            }
                        }

                        # get titel
                        $field = $marcrecord->field('245');
                        if ( $field ) {
                            my $subfield = $field->subfield('a');
                            if ( $subfield ) {
                                $titel = $subfield;
                            }
                            $subfield = $field->subfield('b');
                            if ( $subfield ) {
                                if ( $titel ) {
                                    $titel .= ' / ';
                                }
                                $titel .= $subfield;
                            }
                        }

                        # get verlag and erscheinungsjahr
                        # use field 264 (multiple) if possible, and field 260 as last resort only
                        # field 264 indicator 1 is to be ignored; priority of indicator 2: publication (1) / distribution (2) / production (0)
                        @fields = $marcrecord->field('264');
                        my %fields_by_ind2 = ();
                        foreach $field ( @fields ) {
                            my $ind2 = $field->indicator(2);
                            $fields_by_ind2{$ind2} = $field;
                        }
                        foreach my $ind2Sort ( 1,2,0 ) {    # priority: publication (1) / distribution (2) / production (0)
                            if ( ($field = $fields_by_ind2{$ind2Sort}) ) {
                                if ( ! $verlag ) {
                                    my $subfield = $field->subfield('b');
                                    if ( $subfield ) {
                                        $verlag = $subfield;
                                    }
                                }
                                if ( ! $erscheinungsJahr ) {
                                    my $subfield = $field->subfield('c');
                                    if ( $subfield =~ /^(.)*?(\d\d\d\d)/ ) {
                                        $erscheinungsJahr = $2;
                                    }
                                }
                                if ( $verlag && $erscheinungsJahr ) {
                                    last;
                                }
                            }
                        }
                        if ( ! $verlag ) {
                            # last opportunity to get verlag
                            # field 260 is multiple, we take the first entry
                            $field = $marcrecord->field('260');
                            if ( $field ) {
                                my $subfield = $field->subfield('b');
                                if ( $subfield ) {
                                    $verlag = $subfield;
                                }
                            }
                        }
                        if ( ! $erscheinungsJahr ) {
                            # last opportunity to get erscheinungsJahr
                            # field 260 is multiple, we take the first entry
                            $field = $marcrecord->field('260');
                            if ( $field ) {
                                my $subfield = $field->subfield('c');
                                if ( $subfield ) {
                                    if ( $subfield =~ /^(.)*?(\d\d\d\d)/ ) {
                                        $erscheinungsJahr = $2;
                                    }
                                }
                            }
                        }
                    }

                    # titel info
                    # at least one of the two fields ekzArtikelNr or isbn13 has to be transmitted
                    $param->{titel}->[$iTitel]->{titelangabe}->{ekzArtikelNr} = $ekzArtikelNr if $ekzArtikelNr;
                    $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{isbn13} = $isbnEan if $isbnEan;
                    # titelinfo fields author, titel, verlag, erscheinungsJahr are optional
                    $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{author} = $author if $author;
                    $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{titel} = $titel if $titel;
                    $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{verlag} = $verlag if $verlag;
                    $param->{titel}->[$iTitel]->{titelangabe}->{titelInfo}->{erscheinungsJahr} = $erscheinungsJahr if $erscheinungsJahr;

                    # exemplar info  (optional)
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{lmsExemplarID} = $aqorders_hit->{'ordernumber'} . '';    # force type to string

                    # exemplar konfiguration info
                    my $minQuantity = scalar @{$aqbasketgroupRes->{aqorders}->{$aqorders_hit->{'ordernumber'}}->{orderitemnumbers}};
                    if ( $aqorders_hit->{'quantity'} < $minQuantity ) {
                        $minQuantity = $aqorders_hit->{'quantity'};
                    }
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{anzahl} = $minQuantity;    # required

                    #$param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{besteller} = '';    # not required (string maxlength 30)

                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{warenEmpfaenger}->{ekzKundenNr} = $aqbooksellers_hit->{'accountnumber'};    # warenEmpfaenger is optional
                    # $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{warenEmpfaenger}->{adresseElement}->{...}     # (ekz believes that adresseElement will be ignored)

                    # budget info (budget split not used here)
                    my $kostenstelle;
                    my $haushaltsstelle;

                    my $query_aqbudgets = "SELECT * FROM aqbudgets WHERE budget_id = ? ";

                    $sth = $dbh->prepare($query_aqbudgets);
                    $sth->execute($aqorders_hit->{'budget_id'});
                    if ( my $aqbudgets_hit = $sth->fetchrow_hashref ) {
                        $kostenstelle = $aqbudgets_hit->{'budget_code'};

                        my $query_aqbudgetperiods = "SELECT * FROM aqbudgetperiods WHERE budget_period_id = ? ";

                        my $sth = $dbh->prepare($query_aqbudgetperiods);
                        $sth->execute($aqbudgets_hit->{'budget_period_id'});
                        if ( my $aqbudgetperiods_hit = $sth->fetchrow_hashref ) {
                            $haushaltsstelle = $aqbudgetperiods_hit->{'budget_period_description'};
                        }
                        $sth->finish();    # finish $query_aqbudgetperiods
                    }
                    $sth->finish();    # finish $query_aqbudgets
                    if ( $haushaltsstelle || $kostenstelle ) {
                        $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{budget}->[0]->{anteil} = 100;    # Verplanung auf / Bezahlung über eine einzige Kostenstelle (Koha-Etat), keine Aufteilung auf mehrere Etats
                        $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{budget}->[0]->{haushaltsstelle} = $haushaltsstelle if $haushaltsstelle;
                        $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{budget}->[0]->{kostenstelle} = $kostenstelle if $kostenstelle;
                    }

                    # price info (budget split not used here)
                    #$param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{rabatt} = $aqbooksellers_hit->{'discount'};  or preferably:
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{rabatt} = $aqorders_hit->{'discount'};
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{fracht} = 0.0;    # also required, may be 0.00 of course
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{einband} = 0.0;    # also required, may be 0.00 of course
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{bearbeitung} = 0.0;    # also required, may be 0.00 of course
                    #$param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{ustSatz} = $aqbooksellers_hit->{'tax_rate'} * 100.0;    # 7 represents 7% GST  or preferably:
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{ustSatz} = $aqorders_hit->{'tax_rate_on_ordering'} * 100.0;    # ustSatz==7 represents 7% GST 
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{ust} = $aqorders_hit->{'tax_value_on_ordering'};
                    my $listprice = $aqorders_hit->{'listprice'};    # in the supplier's currency, price for single item
                    my $listpriceMinusDiscount = $listprice - ($listprice * ($aqorders_hit->{'discount'}/100.0));    # in the supplier's currency, price for single item, discout applied
                    $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{gesamtpreis} = $listpriceMinusDiscount;
                    $logger->trace("BestelleBeiEkz() listprice:" . $listprice . ": discount:" . $aqorders_hit->{'discount'} . ": listpriceMinusDiscount:" . $listpriceMinusDiscount . ":");

                    # we could transmit ExemplarFelder XXXWH

                    # calculate the sum of item prices
                    $gesamtpreisSum += $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{preis}->{gesamtpreis} * $param->{titel}->[$iTitel]->{exemplar}->[0]->{konfiguration}->{anzahl};
                    $logger->trace("BestelleBeiEkz() incremented gesamtpreisSum:" . $gesamtpreisSum . ":");


                    $iTitel += 1;
                }    # end foreach my $aqorders_hit ( @{$aqorders_hits} )

                $sth->finish();    # finish $query_aqorders

                # If this aqbasket does not refer to at least one valid aqorders record, then no BestellInfo request for this aqbasket/aqbasketgroup will be sent.
                if ( $iTitel < 1 ) {
                    my $mess = sprintf("aqbasket with basketno:%s: does not refer to any aqorder with regular orderstatus (new, ordered, etc.) and at least one item.",$aqbasket_hit->{basketno});
                    $logger->warn("BestelleBeiEkz() error: $mess");
                    $aqbasketgroupRes->{errorText} = $mess;
                    $aqbasketgroupRes->{resultStatus} = 0;
                    push @{$result}, $aqbasketgroupRes;
                    $sth->finish();    # finish $query_aqbasket
                    last;    # ignore further aqbasket hits in this aqbasketgroup - they must not exist, according to the specification
                }

                # finally set total price parameter and auftragsnummer for callWsBestellung
                $param->{gesamtpreis} = $gesamtpreisSum;

                if ( $basketgroup->{supplyOption} ) {
                    $param->{auftragsnummer} = $basketgroup->{supplyOption};
                } else {
                    $param->{auftragsnummer} = 'Original';
                }

                # create the corresponding acquisition_import and acquisition_import_objects records
                # BEFORE sending Bestellung request, because ekz sends corresponding BestellInfo request before the Bestellung response.
                # But this sequence is executed only if configured so in ekz.


                # In case of a repeated call of BestelleBeiEkz() for the same aqbasketgroup we have to replace the corresponding old records in database tables acquisition_import and acquisition_import_objects.
                my $selParam = {
                    vendor_id => "ekz",
                    object_type => "order",
                    object_number => 'basketno:' . $aqbasketgroupRes->{basketno},
                    #object_number => 'test_basketno:' . $aqbasketgroupRes->{basketno}, # XXXWH    for tests only
                    # we have to delete the records of any rectype.   rec_type => "message",
                    processingstate => "requested"
                };
                my $acquisitionImportOldOrder = Koha::AcquisitionImport::AcquisitionImports->new();
                $logger->debug("BestelleBeiEkz() is searching for acquisition_import_objects record with selParam:" . Dumper($selParam) . ":");
                my $oldOrderHits_rs = $acquisitionImportOldOrder->_resultset()->search( $selParam );
                
                $logger->debug("BestelleBeiEkz() count of old acquisition_import records for same aqbasketgroupno:" . $oldOrderHits_rs->count() . ":");
                while ( (my $hit = $oldOrderHits_rs->next()) ) {
                    # delete assigned record in acquisition_import_objects
                    my $selParam = {
                        acquisition_import_id => $hit->{_column_data}->{'id'}
                    };
                    $logger->debug("BestelleBeiEkz() is searching for acquisition_import_objects record with selParam:" . Dumper($selParam) . ":");
                    my $acquisitionImportObjectsOldOrder = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                    my $oldOrderObjectsHits_rs = $acquisitionImportObjectsOldOrder->_resultset()->search( $selParam );
                    $logger->debug("BestelleBeiEkz() count of old acquisition_import_objects records for this acquisition_import.id:" . $oldOrderObjectsHits_rs->count() . ": All of them will be deleted now.");
                    $oldOrderObjectsHits_rs->delete();
                    
                    # delete hit record in acquisition_import
                    $logger->debug("BestelleBeiEkz() acquisition_import record with id:" . $hit->{_column_data}->{'id'} . ": will be deleted now.");
                    $hit->delete();
                }

                # create the acquisition_import record corresponding to the request that will be sent in next step (rec_type "message")
                my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
                ($wsResult, $wsRequest, $wsResponse) = $ekzwebservice->callWsBestellung($aqbooksellers_hit->{'accountnumber'}, $param,1,undef);    # not calling the webService, just generating the request string
                my $requestBodyText = $wsRequest;
                if ( $wsRequest =~ /^.*?( *\<soap:Body\>.*\<\/soap:Body\>).*?$/s ) {
                    $requestBodyText = $1;
                }

                my $dateTimeNowOfBasketOrder = DateTime->now(time_zone => 'local');
                my $insParam = {
                    #id => 0, # AUTO
                    vendor_id => 'ekz',
                    object_type => 'order',
                    object_number => 'basketno:' . $aqbasketgroupRes->{basketno},    # the basketno will be sent in BestellInfo request in XML-Element lmsBestellCode
                    object_date => DateTime::Format::MySQL->format_datetime($dateTimeNowOfBasketOrder),    # in local time_zone
                    rec_type => 'message',
                    #object_item_number => '', # NULL
                    processingstate => 'requested',
                    processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNowOfBasketOrder),    # in local time_zone
                    payload => $requestBodyText,
                    #object_reference => undef # NULL
                };
                my $acquisitionImportIdBestellung;
                my $acquisitionImportBestellung = Koha::AcquisitionImport::AcquisitionImports->new();
                $acquisitionImportIdBestellung = $acquisitionImportBestellung->_resultset()->create($insParam)->get_column('id');

                foreach my $ordernumber ( sort { $a cmp $b } keys %{$aqbasketgroupRes->{aqorders}} ) {
                    # create the acquisition_import record corresponding to the ordered title (rec_type "title")
                    my $insParam = {
                        #id => 0, # AUTO
                        vendor_id => 'ekz',
                        object_type => 'order',
                        object_number => 'basketno:' . $aqbasketgroupRes->{basketno},    # the basketno will be sent in BestellInfo request in XML-Element lmsBestellCode
                        object_date => DateTime::Format::MySQL->format_datetime($dateTimeNowOfBasketOrder),    # in local time_zone
                        rec_type => 'title',
                        object_item_number => 'ordernumber:' . $ordernumber,    # the ordernumber will be sent in BestellInfo request in XML-Element lmsExemplarID
                        processingstate => 'requested',
                        processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNowOfBasketOrder),    # in local time_zone
                        #payload => NULL, # NULL
                        object_reference => $acquisitionImportIdBestellung
                    };
                    my $acquisitionImportTitle = Koha::AcquisitionImport::AcquisitionImports->new();
                    my $acquisitionImportTitleRS = $acquisitionImportTitle->_resultset()->create($insParam);
                    my $acquisitionImportIdTitle = $acquisitionImportTitleRS->get_column('id');

                    # create the acquisition_import_objects record corresponding to the ordered title (koha_object "title")
                    $insParam = {
                        #id => 0, # AUTO
                        acquisition_import_id => $acquisitionImportIdTitle,
                        koha_object => 'title',
                        koha_object_id => $aqbasketgroupRes->{aqorders}->{$ordernumber}->{biblionumber} . ''
                    };
                    my $titleImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                    my $titleImportObjectRS = $titleImportObject->_resultset()->create($insParam);


                    foreach my $itemnumber ( @{$aqbasketgroupRes->{aqorders}->{$ordernumber}->{orderitemnumbers}} ) {
                        # create the acquisition_import record corresponding to the ordered item (rec_type "item")
                        my $insParam = {
                            #id => 0, # AUTO
                            vendor_id => 'ekz',
                            object_type => 'order',
                            object_number => 'basketno:' . $aqbasketgroupRes->{basketno},    # the basketno will be sent in BestellInfo request in XML-Element lmsBestellCode
                            object_date => DateTime::Format::MySQL->format_datetime($dateTimeNowOfBasketOrder),    # in local time_zone
                            rec_type => 'item',
                            object_item_number => 'ordernumber:' . $ordernumber,    # the ordernumber will be sent in BestellInfo request by BestellInfo in XML-Element lmsExemplarID
                            processingstate => 'requested',
                            processingtime => DateTime::Format::MySQL->format_datetime($dateTimeNowOfBasketOrder),    # in local time_zone
                            #payload => NULL, # NULL
                            object_reference => $acquisitionImportIdTitle
                        };
                        my $acquisitionImportItem = Koha::AcquisitionImport::AcquisitionImports->new();
                        my $acquisitionImportItemRS = $acquisitionImportItem->_resultset()->create($insParam);
                        my $acquisitionImportIdItem = $acquisitionImportItemRS->get_column('id');

                        # create the acquisition_import record corresponding to the ordered item (koha_object "item")
                        $insParam = {
                            #id => 0, # AUTO
                            acquisition_import_id => $acquisitionImportIdItem,
                            koha_object => 'item',
                            koha_object_id => $itemnumber . ''
                        };
                        my $itemImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                        my $itemImportObjectRS = $itemImportObject->_resultset()->create($insParam);
                    }
                }


                ###########################################################################################
                # finally the call of the webservice 'Bestellung' with the prepared wsRequest
                $logger->debug("BestelleBeiEkz() is calling C4::External::EKZ::lib::EkzWebServices->callWsBestellung() with param:" . Dumper($param) . ":");
                ($wsResult, $wsRequest, $wsResponse) = $ekzwebservice->callWsBestellung($aqbooksellers_hit->{'accountnumber'}, $param, 1, $wsRequest);    # 1st param (ekzKundenNr) not used at the moment  - but could be used for getting name for <besteller> from systempreferences
                ###########################################################################################


                $logger->debug("BestelleBeiEkz() has called C4::External::EKZ::lib::EkzWebServices->callWsBestellung(); wsResult:" . Dumper($wsResult) . ":");
                last;    # ignore further aqbasket hits in this aqbasketgroup - they must not exist, according to the specification
            }    # end foreach my $aqbasket_hit ( @{$aqbasket_hits} )

            if ( $wsResult->{statusCode} ne 'SUCCESS' || ! $wsResult->{ekzBestellNr} ) {
                my $mess = "statusCode:'" . $wsResult->{statusCode} . "' statusMessage:'" . $wsResult->{statusMessage} . "'";
                if ( $wsResult->{statusCode} eq 'SUCCESS' ) {
                    $mess .= ' (no ekzBestellNr received)';
                }
                $logger->warn("BestelleBeiEkz() error statusCode ne 'SUCCESS' or got no ekzBestellNr: $mess");
                $aqbasketgroupRes->{resultStatus} = 0;
                $aqbasketgroupRes->{errorText} = $mess;
            } else {
                my $appendText = 'ekz-Bestellnummer: ' . $wsResult->{ekzBestellNr};

                # store 'ekz-Bestellnummer: ' . $wsResult->{ekzBestellNr} in aqorders.order_vendornote
                my $query2_aqorders = "UPDATE aqorders SET order_vendornote = IF(order_vendornote IS NULL, ?, CONCAT(order_vendornote, '\n', ?))  WHERE ordernumber = ? ";
                my $sth = $dbh->prepare($query2_aqorders);
                foreach my $ordernumber ( sort { $a cmp $b } keys %{$aqbasketgroupRes->{aqorders}} ) {
                    $sth->execute($appendText, $appendText, $ordernumber);
                }
                $sth->finish();    # finish $query2_aqorders
                # XXXWH one could delete the hash entry $aqbasketgroupRes->{aqorders} now

                # store 'ekz-Bestellnummer: ' . $wsResult->{ekzBestellNr} in aqbasket.booksellernote
                my $query2_aqbasket = "UPDATE aqbasket SET booksellernote = IF(booksellernote IS NULL, ?, CONCAT(booksellernote, '\n', ?))  WHERE basketno = ? ";
                $sth = $dbh->prepare($query2_aqbasket);
                $sth->execute($appendText, $appendText, $aqbasketgroupRes->{basketno});
                $sth->finish();    # finish $query2_aqbasket
                # XXXWH one could delete the hash entry $aqbasketgroupRes->{basketno} now
            }
            push @{$result}, $aqbasketgroupRes;
        }
        $sth->finish();    # finish $query_aqbasket
    }    # end foreach my $basketgroup ( @{$basketgroupList} )

    $logger->info("BestelleBeiEkz() returns result:" . Dumper($result) . ":");
    return $result;
}


# USED FOR BASIC MANUAL TEST ONLY:
sub BestelleBeiEkz_Test {
    my $wsresult;
    
print STDERR "ekzWsBestellung::BestelleBeiEkz_Test() START\n";

    my $ekzCustomerNumber = '1109403';
    my $param = {};
    $param->{lmsBestellCode} = '47120002';
    $param->{waehrung} = 'EUR';
    $param->{gesamtpreis} = 39.80;
    $param->{hauptstelle} = '1109403';    # optional ?
    $param->{auftragsnummer} = 'Foliiert  mit Fadenheftung';
#    $param->{besteller}->{name} = 'Alex Wallenheimer';    # besteller ist Pflichtfeld, darf aber auch leer sein

#    $param->{titel}->[0]->{titelangabe}->{ekzArtikelNr} = '12345';    # mindestens ekzArtikelNr oder isbn13 muss gesendet werden
#    $param->{titel}->[0]->{titelangabe}->{titelInfo}->{ekzArtikelArt} = '';    # optional
#    $param->{titel}->[0]->{titelangabe}->{titelInfo}->{author} = 'Mundt, Felix; Frank, Günter';
#    $param->{titel}->[0]->{titelangabe}->{titelInfo}->{titel} = 'Der Philosoph Melanchthon';
    $param->{titel}->[0]->{titelangabe}->{titelInfo}->{isbn13} = '9783110552669';
#    $param->{titel}->[0]->{titelangabe}->{titelInfo}->{verlag} = 'De Gruyter';
#    $param->{titel}->[0]->{titelangabe}->{titelInfo}->{erscheinungsJahr} = '2017';

    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{anzahl} = 2;

    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{budget}->[0]->{anteil} = 100;
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{budget}->[0]->{haushaltsstelle} = '2020';
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{budget}->[0]->{kostenstelle} = 'Sachbücher';

    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{preis}->{rabatt} = 0;
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{preis}->{fracht} = 0.0;    # also required, may be 0.00 of course
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{preis}->{einband} = 0.0;    # also required, may be 0.00 of course
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{preis}->{bearbeitung} = 0.0;    # also required, may be 0.00 of course
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{preis}->{ustSatz} = 7;
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{preis}->{ust} = 1.30;
    $param->{titel}->[0]->{exemplar}->[0]->{konfiguration}->{preis}->{gesamtpreis} = 19.90;

	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    $wsresult = $ekzwebservice->callWsBestellung($ekzCustomerNumber, $param);

print STDERR "ekzWsBestellung::BestelleBeiEkz_Test() returns wsresult:" . Dumper($wsresult) . ":\n";
    return $wsresult;
}

1;
