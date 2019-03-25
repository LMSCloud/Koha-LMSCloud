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
use C4::Biblio qw( GetFrameworkCode GetMarcFromKohaField );
use C4::Acquisition;
use C4::External::EKZ::EkzAuthentication;
use C4::External::EKZ::lib::EkzKohaRecords;
use Koha::AcquisitionImport::AcquisitionImports;
use Koha::AcquisitionImport::AcquisitionImportObjects;
use Koha::Acquisition::Order;




sub new {
    my $class = shift;

    my $self  = {
        'debugIt' => 1,
        'dateTimeNow' => undef,    # time stamp value, identical for message, titles and items
        'homebranch' => undef,    # default dummy, has to be updated in derived classes
        'titleSourceSequence' => '_LMSC|_EKZWSMD|DNB|_WS',
        'ekzWsHideOrderedTitlesInOpac' => 1,    # policy: hide title if not explictly set to 'show'
        'ekzWebServicesSetItemSubfieldsWhenOrdered' => undef,
        'ekzAqbooksellersId' => '',

        # variables for email log
        'importerror' => 0,          # flag if an insert error happened
        'importIds' => {},
        'dt' => undef
    };
    
print STDERR "BestellInfoElement::new debugIt:",$self->{'debugIt'},": ekzWsHideOrderedTitlesInOpac:",$self->{'ekzWsHideOrderedTitlesInOpac'},":\n" if $self->{debugIt};
    bless $self, $class;
    #bless $self, 'C4::External::EKZ::BestellInfoElement';
    $self->init();

    return $self;
}

sub init {
    my $self = shift;

    $self->{debugIt} = 1;
    $self->{dateTimeNow} = DateTime->now(time_zone => 'local');
    $self->{homebranch} = undef;    # will be set later, in function process()
    $self->{titleSourceSequence} = C4::Context->preference("ekzTitleDataServicesSequence");
    if ( !defined($self->{titleSourceSequence}) ) {
        $self->{titleSourceSequence} = '_LMSC|_EKZWSMD|DNB|_WS';
    }
    $self->{ekzWsHideOrderedTitlesInOpac} = 1;    # policy: hide title if not explictly set to 'show'
    my $ekzWebServicesHideOrderedTitlesInOpac = C4::Context->preference("ekzWebServicesHideOrderedTitlesInOpac");
    if( defined($ekzWebServicesHideOrderedTitlesInOpac) && 
        length($ekzWebServicesHideOrderedTitlesInOpac) > 0 &&
        $ekzWebServicesHideOrderedTitlesInOpac == 0 ) {
            $self->{ekzWsHideOrderedTitlesInOpac} = 0;
    }
    $self->{ekzWebServicesSetItemSubfieldsWhenOrdered} = C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered");
    $self->{ekzAqbooksellersId} = C4::Context->preference("ekzAqbooksellersId");
    $self->{ekzAqbooksellersId} =~ s/^\s+|\s+$//g;    # trim spaces

    $self->{importerror} = 0;          # flag if an insert error happened
    $self->{importIds} = ();
    $self->{dt} = DateTime->now;
    $self->{dt}->set_time_zone( 'Europe/Berlin' );
}

sub process {
    my ($self, $soapBodyContent, $request) = @_;    # $request->{'soap:Envelope'}->{'soap:Body'} contains our deserialized BestellinfoElement of the HTTP request
    my $dbh = C4::Context->dbh;
    $dbh->{AutoCommit} = 0;
    # variables for email log
    my @logresult = ();
    my @actionresult = ();
    my $actionresultRef;

    my $soapEnvelopeHeader = $request->{'soap:Envelope'}->{'soap:Header'};
    my $soapEnvelopeBody = $request->{'soap:Envelope'}->{'soap:Body'};

    $self->init();

print STDERR Dumper($soapEnvelopeHeader) if $self->{debugIt};
print STDERR Dumper($soapEnvelopeBody->{'ns2:BestellInfoElement'}) if $self->{debugIt};

print STDERR "BestellInfoElement::process() HTTP request request->body:", $soapEnvelopeBody, ":\n" if $self->{debugIt};
print STDERR "BestellInfoElement::process() HTTP request request messageID:", $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'messageID'}, ":\n" if $self->{debugIt};
print STDERR "BestellInfoElement::process() HTTP request request ekzBestellNr:", $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'}, ":\n" if $self->{debugIt};
print STDERR "BestellInfoElement::process() HTTP request request hauptstelle:", $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'hauptstelle'}, ":\n" if $self->{debugIt};

foreach my $tag  (keys %{$soapEnvelopeBody->{'ns2:BestellInfoElement'}}) {
    print STDERR "BestellInfoElement::process() HTTP request tag:", $tag, ":\n" if $self->{debugIt};
}

    my $wssusername = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'} : "WSS-username not defined";
    my $wsspassword = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'} : "WSS-username not defined";
    my $authenticated = C4::External::EKZ::EkzAuthentication::authenticate($wssusername, $wsspassword);
    my $ekzLocalServicesEnabled = C4::External::EKZ::EkzAuthentication::ekzLocalServicesEnabled();


    my $ekzBestellNrIsDuplicate = 0;
    my $reqEkzBestellNr = defined $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'} && length($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'})
                            ? $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'ekzBestellNr'} : 'UNDEFINED';
    my $zeitstempel = $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'zeitstempel'};
    my $reqEkzBestellDatum = DateTime->new( year => substr($zeitstempel,0,4), month => substr($zeitstempel,5,2), day => substr($zeitstempel,8,2), time_zone => 'local' );
    my $reqWaehrung = defined $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'waehrung'} && length($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'waehrung'})
                            ? $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'waehrung'} : 'EUR';
    
    $self->{homebranch} = C4::External::EKZ::lib::EkzWebServices->new()->getEkzWebServicesDefaultBranch($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'hauptstelle'});
    $self->{homebranch} =~ s/^\s+|\s+$//g;    # trim spaces
print STDERR "BestellInfoElement::process() self->{homebranch}:", $self->{homebranch}, ":\n" if $self->{debugIt};

    # result values
    my $respStatusCode = 'UNDEF';
    my $respStatusMessage = 'UNDEF';
    my $timeOfDay = [gettimeofday];
    my $respTransactionID = sprintf("%d.%06d", $timeOfDay->[0], $timeOfDay->[1]);     # seconds.microseconds
    my @idPaarListe = ();
    my $acquisitionError = 0;
    my $basketno = -1;
    my $basketgroupid = undef;
    
    
print STDERR "BestellInfoElement::process() authenticated:" . $authenticated . ": reqEkzBestellNr:" . $reqEkzBestellNr . ":\n" if $self->{debugIt};
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
            processingtime => DateTime::Format::MySQL->format_datetime($self->{dateTimeNow}),    # in local time_zone
            payload => $soapBodyContent,
            #object_reference => undef # NULL
        };
        my $acquisitionImportIdBestellInfo;
        my $acquisitionImportBestellInfo = Koha::AcquisitionImport::AcquisitionImports->new();
        my $hit = $acquisitionImportBestellInfo->_resultset()->find( $selParam );
print STDERR "BestellInfoElement::process() ref(hit):", ref($hit), ":\n" if $self->{debugIt};
        if ( defined($hit) ) {
            $ekzBestellNrIsDuplicate = 1;
            my $mess = sprintf("The ekzBestellNr '%s' has already been used at %s. Processing denied.\n",$reqEkzBestellNr, $hit->get_column('processingtime'));
            carp $mess;
print STDERR "BestellInfoElement::process() hit->{_column_data}:", Dumper($hit->{_column_data}), ":\n" if $self->{debugIt};
        } else {
            $acquisitionImportIdBestellInfo = $acquisitionImportBestellInfo->_resultset()->create($insParam)->get_column('id');
print STDERR "BestellInfoElement::process() acquisitionImportIdBestellInfo:", $acquisitionImportIdBestellInfo, ":\n" if $self->{debugIt};
        }

        print STDERR "BestellInfoElement::process() HTTP request titel:",$soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'},":\n" if $self->{debugIt};
        print STDERR "BestellInfoElement::process() HTTP request ref(titel):",ref($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'titel'}),":\n" if $self->{debugIt};
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
        print STDERR "BestellInfoElement::process() HTTP request titel array:",@$titelArrayRef," AnzElem:", scalar @$titelArrayRef,":\n" if $self->{debugIt};

        my $titleCount = scalar @$titelArrayRef;
        print STDERR "BestellInfoElement::process() HTTP titleCount:",$titleCount, ":\n" if $self->{debugIt};

        # attaching ekz order to Koha acquisition: Create new basket.
        # if system preference ekzAqbooksellersId is not empty: create a Koha order basket for collecting the Koha orders created for each title contained in the request in the following steps.
        if ( $titleCount > 0 && $reqEkzBestellNr ne 'UNDEFINED' && !$ekzBestellNrIsDuplicate ) {
            # policy: if ekzAqbooksellersId is not empty but does not identify an aqbooksellers record: create such an record and update ekzAqbooksellersId
            $self->{ekzAqbooksellersId} = C4::External::EKZ::lib::EkzKohaRecords->checkEkzAqbooksellersId($self->{ekzAqbooksellersId},1);
            if ( length($self->{ekzAqbooksellersId}) ) {
                # Search or create a Koha acquisition order basket,
                # i.e. search / insert a record in table aqbasket so that the following new aqorders records can link to it via aqorders.basketno = aqbasket.basketno .
                my $basketname = 'B-' . $reqEkzBestellNr;
                my $selbaskets = C4::Acquisition::GetBaskets( { 'basketname' => "\'$basketname\'" } );
                if ( @{$selbaskets} > 0 ) {
                    $basketno = $selbaskets->[0]->{'basketno'};
                    print STDERR "BestellInfoElement::process() found aqbasket with basketno:$basketno:\n" if $self->{debugIt};
                } else {
                    my $authorisedby = undef;
                    my $sth = $dbh->prepare("select borrowernumber from borrowers where surname = 'LCService'");
                    $sth->execute();
                    if ( my $hit = $sth->fetchrow_hashref ) {
                        $authorisedby = $hit->{borrowernumber};
                    }
                    my $branchcode = C4::External::EKZ::lib::EkzKohaRecords->branchcodeFallback('', $self->{homebranch});
                    $basketno = C4::Acquisition::NewBasket($self->{ekzAqbooksellersId}, $authorisedby, $basketname, 'created by ekz BestellInfo', '', undef, $branchcode, $branchcode, 0, 'ordering');    # XXXWH
                    print STDERR "BestellInfoElement::process() created new basket having basketno:", Dumper($basketno), ":\n" if $self->{debugIt};
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
        print STDERR "BestellInfoElement::process() ekzAqbooksellersId:$self->{ekzAqbooksellersId}: acquisitionError:$acquisitionError: basketno:$basketno:\n" if $self->{debugIt};


        # for each titel
        for ( my $i = 0; $i < $titleCount && $reqEkzBestellNr ne 'UNDEFINED' && !$ekzBestellNrIsDuplicate && !$acquisitionError; $i++ ) {
            print STDERR "BestellInfoElement::process() title loop $i\n" if $self->{debugIt};
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
            
            if ( $self->{debugIt} ) {
            # log request parameters
                my $logstr = $titel->{'ekzArtikelNr'} ? $titel->{'ekzArtikelNr'} : "<undef>";
                print STDERR "BestellInfoElement::process() HTTP request ekzArtikelNr:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'isbn'} ? $titel->{'titelInfo'}->{'isbn'} : "<undef>";
                print STDERR "BestellInfoElement::process() HTTP request isbn:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'isbn13'} ? $titel->{'titelInfo'}->{'isbn13'} : "<undef>";
                print STDERR "BestellInfoElement::process() HTTP request isbn13:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'author'} ? $titel->{'titelInfo'}->{'author'} : "<undef>";
                print STDERR "BestellInfoElement::process() HTTP request author:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'titel'} ? $titel->{'titelInfo'}->{'titel'} : "<undef>";
                print STDERR "BestellInfoElement::process() HTTP request titel:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'erscheinungsJahr'} ? $titel->{'titelInfo'}->{'erscheinungsJahr'} : "<undef>";
                print STDERR "BestellInfoElement::process() HTTP request erscheinungsJahr:$logstr:\n";
            }

            print STDERR "BestellInfoElement::process() HTTP request exemplar:",$titel->{'exemplar'},":\n" if $self->{debugIt};
            print STDERR "BestellInfoElement::process() HTTP request ref(exemplar):",ref($titel->{'exemplar'}),":\n" if $self->{debugIt};
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
            print STDERR "BestellInfoElement::process() HTTP request exemplarArray:",@$exemplarArrayRef," AnzElem:", 0+@$exemplarArrayRef,":\n" if $self->{debugIt};
            my @idPaarListeTmp = $self->handleTitelBestellInfo($acquisitionImportIdBestellInfo, $reqEkzBestellNr, $reqEkzBestellDatum, $reqParamTitelInfo, $exemplarArrayRef, $reqWaehrung, $basketno, \$actionresultRef); ## add title data to table biblio, biblioitems, and exemplar data to table items

            print STDERR "BestellInfoElement::process() Anzahl idPaarListe:",@idPaarListeTmp+0, "\n" if $self->{debugIt};
            print STDERR "BestellInfoElement::process() idPaarListe:",@idPaarListeTmp, "\n" if $self->{debugIt};
            push @actionresult, @$actionresultRef;

            push @idPaarListe, @idPaarListeTmp;
        }

        # attaching ekz order to Koha acquisition: Close basket, create and close corresponding basketgroup.
        if ( length($self->{ekzAqbooksellersId}) && defined($basketno) && $basketno > 0 ) {
            # create a basketgroup for this basket and close both basket and basketgroup
            my $aqbasket = &C4::Acquisition::GetBasket($basketno);
print STDERR "BestellInfoElement::process() Dumper aqbasket:", Dumper($aqbasket), ":\n" if $self->{debugIt};
            if ( $aqbasket ) {
                # close the basket
print STDERR "BestellInfoElement::process() is calling CloseBasket basketno:", $aqbasket->{basketno}, ":\n" if $self->{debugIt};
                &C4::Acquisition::CloseBasket($aqbasket->{basketno});

                # search/create basket group with aqbasketgroups.name = ekz order number and aqbasketgroups.booksellerid = and update aqbasket accordingly
                my $params = {
                    name => "\'$aqbasket->{basketname}\'",
                    booksellerid => $aqbasket->{booksellerid}
                };
                $basketgroupid  = undef;
                my $aqbasketgroups = &C4::Acquisition::GetBasketgroupsGeneric($params, { orderby => "id DESC" } );
print STDERR "BestellInfoElement::process() Dumper aqbasketgroups:", Dumper($aqbasketgroups), ":\n" if $self->{debugIt};

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
print STDERR "BestellInfoElement::process() created basketgroup with name:", $aqbasket->{basketname}, ": having basketgroupid:$basketgroupid:\n" if $self->{debugIt};
                } else {
                    $basketgroupid = $aqbasketgroups->[0]->{id};
print STDERR "BestellInfoElement::process() found basketgroup with name:", $aqbasket->{basketname}, ": having basketgroupid:$basketgroupid:\n" if $self->{debugIt};
                }

                if ( $basketgroupid ) {
                    # update basket, i.e. set basketgroupid
                    my $basketinfo = {
                        'basketno' => $aqbasket->{basketno},
                        'basketgroupid' => $basketgroupid
                    };
                    &C4::Acquisition::ModBasket($basketinfo);

                    # close the basketgroup
print STDERR "BestellInfoElement::process() is calling CloseBasketgroup basketgroupid:$basketgroupid:\n" if $self->{debugIt};
                    &C4::Acquisition::CloseBasketgroup($basketgroupid);
                }
            }
        }

    }

    print STDERR "BestellInfoElement::process() Anzahl idPaarListe:",@idPaarListe+0, "\n" if $self->{debugIt};
    print STDERR "BestellInfoElement::process() idPaarListe:",@idPaarListe, "\n" if $self->{debugIt};

    #$dbh->rollback;    # roll it back for TEST XXXWH
    #@idPaarListe = (); # roll it back for TEST XXXWH


    $respStatusCode = 'ERROR';
    if ( !$authenticated ) {
        $respStatusMessage = "nicht authentifiziert";
    } elsif ( !$ekzLocalServicesEnabled ) {
        $respStatusMessage = "Webservices für ekz-Anfragen sind in der Koha-Instanz " . C4::External::EKZ::EkzAuthentication::kohaInstanceName() . " nicht aktiviert.";
    } elsif ( $reqEkzBestellNr eq 'UNDEFINED' )
    {
        $respStatusMessage = "keine ekzBestellNr empfangen";
    } elsif ( $acquisitionError )
    {
        $respStatusMessage = "Die Koha-Erwerbung kann nicht angesprochen werden.";
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
        print STDERR "BestellInfoElement::process(); ekzExemplarID:",$idPaar->{'ekzExemplarID'},":\n" if $self->{debugIt};

        my $soapIdPaar = SOAP::Data->name( 'idPaar' => \SOAP::Data->value(
                SOAP::Data->name( 'ekzExemplarID' => $idPaar->{'ekzExemplarID'} )->type( 'string' ),
                SOAP::Data->name( 'lmsExemplarID' => $idPaar->{'lmsExemplarID'} )->type( 'string' )
        ));

        push @soapIdPaarListe, $soapIdPaar;
    }

    # create @logresult message for log email, representing all titles of the BestellInfo with all their processed items
    push @logresult, ['BestellInfo', $soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'messageID'}, \@actionresult, $acquisitionError, $self->{ekzAqbooksellersId}, $basketno ];
print STDERR "Dumper(\\\@logresult): ####################################################################################################################\n" if $self->{debugIt};
print STDERR Dumper(\@logresult) if $self->{debugIt};



    # commit the complete BestellInfo (only as a single transaction)
    $dbh->commit();
    $dbh->{AutoCommit} = 1;
    
    if ( scalar(@logresult) > 0 ) {
        my @importIds = keys %{$self->{importIds}};
        my ($message, $subject, $haserror) = C4::External::EKZ::lib::EkzKohaRecords->createProcessingMessageText(\@logresult, "headerTEXT", $self->{dt}, \@importIds, $reqEkzBestellNr);  # we use ekzBestellNr as part of importID in MARc field 025.a: (EKZImport)$importIDs[0]
        C4::External::EKZ::lib::EkzKohaRecords->sendMessage($soapEnvelopeBody->{'ns2:BestellInfoElement'}->{'hauptstelle'}, $message, $subject);
    }

    my $soapResponseElement = SOAP::Data->name( 'ns2:BestellInfoResultatElement' )->SOAP::Header::value(
        [$soapStatusCode,
         $soapStatusMessage,
         $soapTransactionID,
         @soapIdPaarListe])->SOAP::Header::attr('xmlns:ns2="http://www.ekz.de/BestellsystemWSDL"');

    return $soapResponseElement;
     
}

sub handleTitelBestellInfo {
    my ( $self, $acquisitionImportIdBestellInfo, $reqEkzBestellNr, $reqEkzBestellDatum, $reqParamTitelInfo, $exemplare, $reqWaehrung, $basketno, $retactionresult ) = @_;

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
print STDERR "BestellInfoElement::handleTitelBestellInfo() Start reqEkzBestellNr:$reqEkzBestellNr: reqEkzBestellDatum:$reqEkzBestellDatum: reqWaehrung:$reqWaehrung: basketno:$basketno:\n" if $self->{debugIt};

    # Search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
    $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLocalDB($reqParamTitelInfo, 1);
print STDERR "BestellInfoElement::handleTitelBestellInfo() from local DB titleHits->{'count'}:",$titleHits->{'count'},": \n" if $self->{debugIt};
    if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
        $biblionumber = $titleHits->{'records'}->[0]->subfield("999","c");
    }

    my @titleSourceSequence = split('\|',$self->{titleSourceSequence});
    foreach my $titleSource (@titleSourceSequence) {
print STDERR "BestellInfoElement::handleTitelBestellInfo() titleSource:$titleSource:\n" if $self->{debugIt};
        if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
            last;    # title data have been found in lastly tested title source
        }

        if ( $titleSource eq '_LMSC' ) {
            # search title in LMSPool
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleInLMSPool($reqParamTitelInfo);
print STDERR "BestellInfoElement::handleTitelBestellInfo() from LMS Pool titleHits->{'count'}:",$titleHits->{'count'},": \n" if $self->{debugIt};
        } elsif ( $titleSource eq '_EKZWSMD' ) {
            # send query to the ekz title information web service
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromEkzWsMedienDaten($reqParamTitelInfo->{'ekzArtikelNr'});
print STDERR "BestellInfoElement::handleTitelBestellInfo() from ekz Webservice titleHits->{'count'}:",$titleHits->{'count'},": \n" if $self->{debugIt};
        } elsif ( $titleSource eq '_WS' ) {
            # use sparse title data from the BestellinfoElement
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->createTitleFromFields($reqParamTitelInfo);    # creates marc data, not a biblio DB record
print STDERR "BestellInfoElement::handleTitelBestellInfo() from sent titelinfo fields titleHits->{'count'}:",$titleHits->{'count'},": \n" if $self->{debugIt};
        } else {
            # search title in in the Z39.50 target with z3950servers.servername=$titleSource
            $titleHits = C4::External::EKZ::lib::EkzKohaRecords->readTitleFromZ3950Target($titleSource,$reqParamTitelInfo);
print STDERR "BestellInfoElement::handleTitelBestellInfo() from z39.50 search on target:" . $titleSource . ": titleHits->{'count'}:" . $titleHits->{'count'} . ": \n" if $self->{debugIt};
        }
    }


    if ( $titleHits->{'count'} > 0 && defined $titleHits->{'records'}->[0] ) {
        if ( $biblionumber == 0 ) {    # title data have been found in one of the sources
            # Create a biblio record in Koha and enrich it with values of the hits found in one of the title sources.
            # It is sufficient to evaluate the first hit.

            $titleHits->{'records'}->[0]->insert_fields_ordered(MARC::Field->new('035',' ',' ','a' => "(EKZImport)$reqEkzBestellNr"));    # system controll number
            if( $self->{ekzWsHideOrderedTitlesInOpac} ) {
                $titleHits->{'records'}->[0]->insert_fields_ordered(MARC::Field->new('942',' ',' ','n' => 1));           # hide this title in opac
            }
            ($biblionumber,$biblioitemnumber) = C4::Biblio::AddBiblio($titleHits->{'records'}->[0],'');
print STDERR "BestellInfoElement::handleTitelBestellInfo() new biblionumber:",$biblionumber,": biblioitemnumber:",$biblioitemnumber,": \n" if $self->{debugIt};
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
                $self->{importerror} = 1;
            }
        } else {    # title record has been found in local database
            $biblioExisting = 1;
            # positive message for log
            $importresult = 2;
            $importedTitlesCount += 0;
        }
        # add result of adding biblio to log email
        ($titeldata, $isbnean) = C4::External::EKZ::lib::EkzKohaRecords->getShortISBD($titleHits->{'records'}->[0]);
        push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $self->{importerror}, 1, undef, undef];
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
            processingtime => DateTime::Format::MySQL->format_datetime($self->{dateTimeNow}),    # in local time_zone
            #payload => NULL, # NULL
            object_reference => $acquisitionImportIdBestellInfo
        };
        my $acquisitionImportTitle = Koha::AcquisitionImport::AcquisitionImports->new();
        my $acquisitionImportTitleRS = $acquisitionImportTitle->_resultset()->create($insParam);
        $acquisitionImportIdTitle = $acquisitionImportTitleRS->get_column('id');
print STDERR "BestellInfoElement::handleTitelBestellInfo() acquisitionImportTitleRS->{_column_data}:", Dumper($acquisitionImportTitleRS->{_column_data}), ":\n" if $self->{debugIt};
print STDERR "BestellInfoElement::handleTitelBestellInfo() acquisitionImportIdTitle:", $acquisitionImportIdTitle, ":\n" if $self->{debugIt};

        # Insert a record into table acquisition_import_object representing the Koha title data.
        $insParam = {
            #id => 0, # AUTO
            acquisition_import_id => $acquisitionImportIdTitle,
            koha_object => "title",
            koha_object_id => $biblionumber . ''
        };
        my $titleImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
        my $titleImportObjectRS = $titleImportObject->_resultset()->create($insParam);

print STDERR "BestellInfoElement::handleTitelBestellInfo() titleImportObjectRS->{_column_data}:", Dumper($titleImportObjectRS->{_column_data}), ":\n" if $self->{debugIt};;

        # now add the items data for the new or found biblionumber
        my $itemCount = scalar @{$exemplare};
        for ( my $i = 0; $i < $itemCount; $i++ ) {
            my $ekzExemplarID = (defined $exemplare->[$i]->{'ekzExemplarID'} && length($exemplare->[$i]->{'ekzExemplarID'}) > 0) ? $exemplare->[$i]->{'ekzExemplarID'} : "ekzExemplarID not set";
            my $exemplar_anzahl = $exemplare->[$i]->{'konfiguration'}->{'anzahl'};
            print STDERR "BestellInfoElement::handleTitelBestellInfo() exemplar itemCount:$itemCount loop:$i exemplar_anzahl:$exemplar_anzahl\n" if $self->{debugIt};

print STDERR "BestellInfoElement::handleTitelBestellInfo() exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}:", $exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}, ":\n" if $self->{debugIt};
print STDERR "BestellInfoElement::handleTitelBestellInfo() ref exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}:", ref($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}), ":\n" if $self->{debugIt};
            # look for XML <ExemplarFeldElement> blocks within current <exemplar> block
            my $exemplarfelderArrayRef = [];    # using ref to empty array if there are sent no ExemplarFeldElement blocks
            # if there is sent only one ExemplarFeldElement block, it is delivered here as hash ref
            if ( defined($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}) && ref($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}) && 
                 defined($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'}) && ref($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}) ) {
                if ( ref($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'}) eq 'HASH' ) {
                    $exemplarfelderArrayRef = [ $exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'} ]; # ref to anonymous array containing the single hash reference
                } else {
                    # if there are sent more than one ExemplarFeldElement blocks, they are delivered here as array ref
                    if ( ref($exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'}) eq 'ARRAY' ) {
                        $exemplarfelderArrayRef = $exemplare->[$i]->{'konfiguration'}->{'ExemplarFelderElement'}->{'ExemplarFeldElement'}; # ref to deserialized array containing the hash references
                    }
                }
            }
print STDERR "BestellInfoElement::handleTitelBestellInfo() HTTP request ExemplarFeldElement array:",@$exemplarfelderArrayRef," AnzElem:", scalar @$exemplarfelderArrayRef,":\n" if $self->{debugIt};

            my $exemplarfeldercount = scalar @$exemplarfelderArrayRef;
            my $zweigstellencode = '';
print STDERR "BestellInfoElement::handleTitelBestellInfo() HTTP exemplarfeldercount:",$exemplarfeldercount, ":\n" if $self->{debugIt};
            for ( my $j = 0; $j < $exemplarfeldercount; $j++ ) {
                print STDERR "BestellInfoElement::handleTitelBestellInfo() HTTP request ExemplarFeldElement name:", $exemplarfelderArrayRef->[$j]->{'name'}, ": inhalt:", $exemplarfelderArrayRef->[$j]->{'inhalt'},":\n" if $self->{debugIt};
                if ( $exemplarfelderArrayRef->[$j]->{'name'} eq 'zweigstelle' ) {
                    $zweigstellencode = $exemplarfelderArrayRef->[$j]->{'inhalt'};
                    $zweigstellencode =~ s/^\s+|\s+$//g; # trim spaces
                }
            }
            if ( length($zweigstellencode) == 0 && defined $self->{homebranch} && length($self->{homebranch}) > 0 ) {
                $zweigstellencode = $self->{homebranch};
            }
print STDERR "BestellInfoElement::handleTitelBestellInfo() vor checkbranchcode zweigstellencode:", $zweigstellencode, ":\n" if $self->{debugIt};
            if ( !&C4::External::EKZ::lib::EkzKohaRecords::checkbranchcode($zweigstellencode) ) {
                $zweigstellencode = '';
            }
print STDERR "BestellInfoElement::handleTitelBestellInfo() nach checkbranchcode zweigstellencode:", $zweigstellencode, ":\n" if $self->{debugIt};


                # attaching ekz order to Koha acquisition: Create a new Koha::Acquisition::Order.
                my $rabatt = defined($exemplare->[$i]->{'konfiguration'}->{'preis'}->{'rabatt'}) ? $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'rabatt'} : "0.0";
                my $fracht = defined($exemplare->[$i]->{'konfiguration'}->{'preis'}->{'fracht'}) ? $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'fracht'} : "0.00";
                my $einband = defined($exemplare->[$i]->{'konfiguration'}->{'preis'}->{'einband'}) ? $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'einband'} : "0.00";
                my $bearbeitung = defined($exemplare->[$i]->{'konfiguration'}->{'preis'}->{'bearbeitung'}) ? $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'bearbeitung'} : "0.00";
                my $ustSatz = defined($exemplare->[$i]->{'konfiguration'}->{'preis'}->{'ustSatz'}) ? $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'ustSatz'} / 100.0 : "0.07";
                my $ust = defined($exemplare->[$i]->{'konfiguration'}->{'preis'}->{'ust'}) ? $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'ust'} : "0.00";
                my $gesamtpreis = defined($exemplare->[$i]->{'konfiguration'}->{'preis'}->{'gesamtpreis'}) ? $exemplare->[$i]->{'konfiguration'}->{'preis'}->{'gesamtpreis'} : "0.00";    # total for a single item, discounted, incl. additional costs

                if ( $ust == 0.0 && $ustSatz != 0.0 ) {    # Bruttopreise
                    $ust = $gesamtpreis * $ustSatz / (1 + $ustSatz);
                    $ust = &C4::External::EKZ::lib::EkzKohaRecords::round($ust, 2);
                }
                if ( $ustSatz == 0.0 && $ust != 0.0 && $gesamtpreis != 0.0) {    # Nettopreise
                    $ustSatz = $ust / $gesamtpreis;
                    $ustSatz = &C4::External::EKZ::lib::EkzKohaRecords::round($ustSatz, 2);
                }

                # the following calculation is correct only where aqbooksellers.gstreg=1 and  aqbooksellers.listincgst=1 and  aqbooksellers.invoiceincgst=1 and aqbooksellers.listprice = aqbooksellers.invoiceprice = the library's currency
                my $listpriceDiscounted_tax_included = $gesamtpreis - $fracht - $einband - $bearbeitung; # not sent in LieferscheinDetailResponseElement, so we calculate it
                my $listprice_tax_included = $listpriceDiscounted_tax_included;
                if ( $rabatt != 0.0 ) {
                    my $divisor = 1.0 - ($rabatt / 100.0);
                    $listprice_tax_included = $divisor == 0.0 ? $listprice_tax_included : $listprice_tax_included / $divisor;    # list price of single item in vendor's currency, not discounted
                    $listprice_tax_included = &C4::External::EKZ::lib::EkzKohaRecords::round($listprice_tax_included, 2);
                }
                my $divisor = 1.0 + $ustSatz;
                my $listprice_tax_excluded = $divisor == 0.0 ? 0.0 : $listprice_tax_included / $divisor;
                $listprice_tax_excluded = &C4::External::EKZ::lib::EkzKohaRecords::round($listprice_tax_excluded, 2);
                my $replacementcost_tax_included = $listprice_tax_included;    # list price of single item in library's currency, not discounted (at the moment no exchange rate calculation implemented)
                my $replacementcost_tax_excluded = $listprice_tax_excluded;    # list price of single item in library's currency, not discounted, tax excluded (at the moment no exchange rate calculation implemented)


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

                    my $haushaltsstelle = defined($exemplare->[$i]->{'konfiguration'}->{'budget'}->{'haushaltsstelle'}) ? $exemplare->[$i]->{'konfiguration'}->{'budget'}->{'haushaltsstelle'} : "";
                    my $kostenstelle = defined($exemplare->[$i]->{'konfiguration'}->{'budget'}->{'kostenstelle'}) ? $exemplare->[$i]->{'konfiguration'}->{'budget'}->{'kostenstelle'} : "";

                    my ($dummy1, $dummy2, $budgetid, $dummy3) = C4::External::EKZ::lib::EkzKohaRecords->checkAqbudget($haushaltsstelle, $kostenstelle, 1);

                    my $quantity = $exemplar_anzahl;
                    my $budgetedcost_tax_included = $gesamtpreis;    # discounted
                    my $divisor = 1.0 + $ustSatz;
                    my $budgetedcost_tax_excluded = $divisor == 0.0 ? 0.0 : $budgetedcost_tax_included / $divisor;
                    $budgetedcost_tax_excluded = &C4::External::EKZ::lib::EkzKohaRecords::round($budgetedcost_tax_excluded, 2);
                    my $rabattbetrag = $listprice_tax_included - $listpriceDiscounted_tax_included;

                    my $orderinfo = ();

                    # ordernumber is set by DBS
                    $orderinfo->{biblionumber} = $biblionumber;
                    # entrydate is set to today by Koha::Acquisition::Order->store()
                    $orderinfo->{quantity} = $quantity;
                    $orderinfo->{currency} = $reqWaehrung;    # currency of bookseller's list price
                    # XXXWH currency-Umrechnung fehlt in die eine oder andere Richtung
                    $orderinfo->{'listprice'} = $listprice_tax_included;    # input field 'Vendor price' in UI (in foreign currency, not discounted, per item)
                    $orderinfo->{unitprice} = 0.0;    #  corresponds to input field 'Actual cost' in UI (discounted) and will be initialized with budgetedcost in the GUI in 'receiving' step
                    $orderinfo->{unitprice_tax_excluded} = 0.0;
                    $orderinfo->{unitprice_tax_included} = 0.0;
                    # quantityreceived is set to 0 by DBS
                    $orderinfo->{order_internalnote} = '';
                    $orderinfo->{order_vendornote} = 'Gesamtpreis: ' . "$gesamtpreis $reqWaehrung\n";
                    if ( $rabattbetrag != 0.0 ) {
                        $orderinfo->{order_vendornote} .= 'Rabatt: ' . "$rabattbetrag $reqWaehrung\n";
                    }
                    if ( $fracht != 0.0 ) {
                        $orderinfo->{order_vendornote} .= 'Fracht: ' . "$fracht $reqWaehrung\n";
                    }
                    if ( $einband != 0.0 ) {
                        $orderinfo->{order_vendornote} .= 'Einband: ' . "$einband $reqWaehrung\n";
                    }
                    if ( $bearbeitung != 0.0 ) {
                        $orderinfo->{order_vendornote} .= 'Bearbeitung: ' . "$bearbeitung $reqWaehrung\n";
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

            if ( length($zweigstellencode) == 0 && defined $self->{homebranch} && length($self->{homebranch}) > 0 ) {
                $zweigstellencode = $self->{homebranch};
                if ( !&C4::External::EKZ::lib::EkzKohaRecords::checkbranchcode($zweigstellencode) ) {
                    $zweigstellencode = '';
                }
            }

            for ( my $j = 0; $j < $exemplar_anzahl; $j++ ) {
                my $problems = '';              # string for accumulating error messages for this order
                my $item_hash;

                $processedItemsCount += 1;

                $item_hash->{homebranch} = $zweigstellencode;
                $item_hash->{booksellerid} = 'ekz';
                $item_hash->{price} = $gesamtpreis;
                $item_hash->{replacementprice} = $replacementcost_tax_included;
                
                # finally add the next items record
                my ( $biblionumberItem, $biblioitemnumberItem, $itemnumber ) = C4::Items::AddItem($item_hash, $biblionumber);

                # collect title controlnumbers for HTML URL to Koha records of handled titles
                my $tmp_cn = defined($titleHits->{'records'}->[0]->field("001")) ? $titleHits->{'records'}->[0]->field("001")->data() : $biblionumber;
                my $tmp_cna = defined($titleHits->{'records'}->[0]->field("003")) ? $titleHits->{'records'}->[0]->field("003")->data() : "undef";
                my $importId = '(ControlNumber)' . $tmp_cn . '(ControlNrId)' . $tmp_cna;    # if cna = 'DE-Rt5' then this cn is the ekz article number
                $self->{importIds}->{$importId} = $itemnumber;
print STDERR "BestellInfoElement::genKohaRecords() importedItemsCount:$importedItemsCount; set next importIds:", $importId, ":\n" if $self->{debugIt};

                if ( defined $itemnumber && $itemnumber > 0 ) {

                    # configurable items record field initialization via C4::Context->preference("ekzWebServicesSetItemSubfieldsWhenOrdered")
                    # e.g. setting the 'item ordered' state in items.notforloan
                    if ( defined($self->{ekzWebServicesSetItemSubfieldsWhenOrdered}) && length($self->{ekzWebServicesSetItemSubfieldsWhenOrdered}) > 0 ) {
                        my @affects = split q{\|}, $self->{ekzWebServicesSetItemSubfieldsWhenOrdered};
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
                    if ( defined($order) ) {
                        $order->add_item($itemnumber);
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
                        processingtime => DateTime::Format::MySQL->format_datetime($self->{dateTimeNow}),    # in local time_zone
                        #payload => NULL, # NULL
                        object_reference => $acquisitionImportIdTitle
                    };
                    my $acquisitionImportItem = Koha::AcquisitionImport::AcquisitionImports->new();
                    my $acquisitionImportItemRS = $acquisitionImportItem->_resultset()->create($insParam);
                    my $acquisitionImportIdItem = $acquisitionImportItemRS->get_column('id');
print STDERR "BestellInfoElement::handleTitelBestellInfo() acquisitionImportItemRS->{_column_data}:", Dumper($acquisitionImportItemRS->{_column_data}), ":\n" if $self->{debugIt};

                    # Insert a record into table acquisition_import_object representing the Koha item data.
                    $insParam = {
                        #id => 0, # AUTO
                        acquisition_import_id => $acquisitionImportIdItem,
                        koha_object => "item",
                        koha_object_id => $itemnumber . ''
                    };
                    my $itemImportObject = Koha::AcquisitionImport::AcquisitionImportObjects->new();
                    my $itemImportObjectRS = $itemImportObject->_resultset()->create($insParam);
print STDERR "BestellInfoElement::process() itemImportObjectRS->{_column_data}:", Dumper($itemImportObjectRS->{_column_data}), ":\n" if $self->{debugIt};

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
                    $self->{importerror} = 1;
                }
                # add result of adding item to log email
                my ($titeldata, $isbnean) = ($itemnumber, '');
print STDERR "BestellInfoElement::handleTitelBestellInfo() item titeldata:", $titeldata, ":\n" if $self->{debugIt};
                push @records, [$reqParamTitelInfo->{'ekzArtikelNr'}, defined $biblionumber ? $biblionumber : "no biblionumber", $importresult, $titeldata, $isbnean, $problems, $self->{importerror}, 2, $ordernumber, $basketno];
            }    # End handling of one <exemplar> - block
        }    # End add items
    }    # End $biblioExisting || $biblioInserted

    # create @actionresult message for log email, representing 1 title with all its processed items
    my @actionresult = ();
    push @actionresult, [ 'insertRecords', 0, "X", "Y", $processedTitlesCount, $importedTitlesCount, $updatedTitlesCount, $processedItemsCount, $importedItemsCount, 0, \@records];
    $$retactionresult = \@actionresult;
print STDERR "BestellInfoElement::handleTitelBestellInfo() actionresult:", @actionresult, ":\n" if $self->{debugIt};
print STDERR "BestellInfoElement::handleTitelBestellInfo() actionresult[0]:", @{$actionresult[0]}, ":\n" if $self->{debugIt};
#####print STDERR "BestellInfoElement::handleTitelBestellInfo() actionresult[0]->[10]->[0]:", @{$actionresult[0]->[10]->[0]}, ":\n" if $self->{debugIt};
print STDERR "BestellInfoElement::handleTitelBestellInfo() retactionresult:", $retactionresult, ":\n" if $self->{debugIt};

    return (@idPaarListe);
}

1;
