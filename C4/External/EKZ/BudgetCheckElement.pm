package C4::External::EKZ::BudgetCheckElement;

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

use C4::External::EKZ::EkzAuthentication;
use C4::Budgets;


sub new {
    my $class = shift;

    my $self  = {
        'hauptstelle' => undef,    # will be set later, in function process() based on ekzKundenNr in XML element 'hauptstelle'
        'ekzAqbooksellersId' => '',    # will be set later, in function process() based on ekzKundenNr in XML element 'hauptstelle'
        'budgetEkz' => {},
        'budgetKoha' => {},
        'ekzWsConfig' => undef
    };
    $self->{logger} = Koha::Logger->get({ interface => 'C4::External::EKZ::BudgetCheckElement' });

    bless $self, $class;
    $self->init();

    return $self;
}

sub init {
    my $self = shift;

    $self->{hauptstelle} = undef;    # will be set later, in function process() based on ekzKundenNr in XML element 'hauptstelle'
    $self->{ekzAqbooksellersId} = '';    # will be set later, in function process() based on ekzKundenNr in XML element 'hauptstelle'
    $self->{budgetEkz} = {};
    $self->{budgetKoha} = {};
    $self->{ekzWsConfig} = C4::External::EKZ::lib::EkzWsConfig->new();
}

sub process {
    my ($self, $request) = @_;    # $request->{'soap:Envelope'}->{'soap:Body'} contains our deserialized BudgetCheckElement of the HTTP request
    $self->init();

    $self->{logger}->info("process() START request:" . Dumper($request) . ":");
    $self->{logger}->debug("process() request->{'soap:Envelope'}->{'soap:Header'}:" . Dumper($request->{'soap:Envelope'}->{'soap:Header'}) . ":");
    $self->{logger}->debug("process() request->{'soap:Envelope'}->{'soap:Body'}:" . Dumper($request->{'soap:Envelope'}->{'soap:Body'}) . ":");

    $self->{logger}->debug("process() HTTP request request messageID:" . $request->{'soap:Envelope'}->{'soap:Body'}->{'ns2:BudgetCheckElement'}->{'messageID'} . ":");
    $self->{logger}->debug("process() HTTP request request hauptstelle:" . $request->{'soap:Envelope'}->{'soap:Body'}->{'ns2:BudgetCheckElement'}->{'hauptstelle'} . ":");

    my $soapEnvelopeHeader = $request->{'soap:Envelope'}->{'soap:Header'};
    my $soapEnvelopeBody = $request->{'soap:Envelope'}->{'soap:Body'};

foreach my $tag  (keys %{$soapEnvelopeBody->{'ns2:BudgetCheckElement'}}) {
    $self->{logger}->trace("process() HTTP request soapEnvelopeBody->{'ns2:BudgetCheckElement'} tag:" . $tag . ":");
}

    my $wssusername = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'} : "WSS-username not defined";
    my $wsspassword = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'} : "WSS-username not defined";
    my $authenticated = C4::External::EKZ::EkzAuthentication::authenticate($wssusername, $wsspassword);
    my $ekzLocalServicesEnabled = C4::External::EKZ::EkzAuthentication::ekzLocalServicesEnabled();
    
    $self->{hauptstelle} = $soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'hauptstelle'};
    $self->{logger}->debug("process() self->{hauptstelle}:" . $self->{hauptstelle} . ":");
    $self->{ekzAqbooksellersId} = $self->{ekzWsConfig}->getEkzAqbooksellersId($self->{hauptstelle});
    $self->{ekzAqbooksellersId} =~ s/^\s+|\s+$//g;    # trim spaces
    $self->{logger}->debug("process() self->{ekzAqbooksellersId}:" . $self->{ekzAqbooksellersId} . ":");

    # result values
    my $respStatusCode = 'UNDEF';
    my $respStatusMessage = '';
    my $timeOfDay = [gettimeofday];
    my $respTransactionID = sprintf("%d.%06d", $timeOfDay->[0], $timeOfDay->[1]);     # seconds.microseconds
    my @titelInfoListe = ();
    

    if($authenticated && $ekzLocalServicesEnabled)
    {
        $self->{logger}->trace("process() HTTP request titel:" . $soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'} . ":");
        $self->{logger}->trace("process() HTTP request ref(titel):" . ref($soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'}) . ":");
        my $titeldefined = ( exists $soapEnvelopeBody->{'ns2:BudgetCheckElement'} && defined $soapEnvelopeBody->{'ns2:BudgetCheckElement'} &&
                             exists $soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'} && defined $soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'});
        my $titelArrayRef = [];    #  using ref to empty array if there are sent no titel blocks
        # if there is sent only one titel block, it is delivered here as hash ref
        if ( $titeldefined && ref($soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'}) eq 'HASH' ) {
            $titelArrayRef = [ $soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'} ]; # ref to anonymous array containing the single hash reference
        } else {
            # if there are sent more than one titel blocks, they are delivered here as array ref
            if ( $titeldefined && ref($soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'}) eq 'ARRAY' ) {
                 $titelArrayRef = $soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'}; # ref to deserialized array containing the hash references
            }
        }
        $self->{logger}->debug("process() HTTP request titel array:" . Dumper($titelArrayRef) . ": AnzElem:" . scalar @$titelArrayRef . ":");

        my $titleCount = scalar @$titelArrayRef;
        $self->{logger}->debug("process() HTTP titleCount:" . $titleCount . ":");
        for ( my $i = 0; $i < $titleCount; $i++ ) {
            $self->{logger}->debug("process() title loop i:$i:");
            my $titel = $titelArrayRef->[$i];

            # extracting the search criteria
            my $reqEkzArtikelNr = $titel->{'ekzArtikelNr'};
            my $reqIsbn = $titel->{'titelInfo'}->{'isbn'};
            my $reqIsbn13 = $titel->{'titelInfo'}->{'isbn13'};
            my $reqAuthor = $titel->{'titelInfo'}->{'author'};
            my $reqTitel = $titel->{'titelInfo'}->{'titel'};
            my $reqErscheinungsJahr = $titel->{'titelInfo'}->{'erscheinungsJahr'};
            my $reqEinzelPreis = $titel->{'titelInfo'}->{'einzelPreis'};

            $self->{logger}->debug("process() Dumper titel:" . Dumper($titel) . ":");

            $self->{logger}->debug("process() HTTP request exemplar:" . $titel->{'exemplar'} . ":");
            $self->{logger}->debug("process() HTTP request ref(exemplar):" . ref($titel->{'exemplar'}) . ":");
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
            $self->{logger}->debug("process() HTTP request exemplarArrayRef:" . Dumper($exemplarArrayRef) . ": AnzElem:" . scalar @$exemplarArrayRef . ":");
            my $titelInfo = $self->handleBudgetCheck($reqEkzArtikelNr, $reqIsbn, $reqIsbn13, $exemplarArrayRef);

            $self->{logger}->debug("process() titelInfo:" . Dumper($titelInfo) . ":");
            $self->{logger}->debug("process() titelInfo->id:" . $titelInfo->{'id'} . ":");
            $self->{logger}->debug("process() Anz. titelInfo->exemplare:" . scalar @{$titelInfo->{'exemplare'}} . ":");

            push @titelInfoListe, $titelInfo;
        }
    }

    $self->{logger}->debug("process() Anzahl titelInfoListe:" . scalar @titelInfoListe . ":");

    # check the complications happened
    my $errorMessage = {};
    my $errorMessageType = 0;    # bit mask;   1: missing haushaltstelle
                                 #             2: wrong haushaltstelle
                                 #            16: missing kostenstelle
                                 #            32: wrong kostenstelle (within haushaltstelle, independend of branchcode)
                                 #           256: budget exceeded
                                 #           512: budget encumbrance exceeded
                                 #          1024: budget expenditure exceeded
    foreach my $haushaltsstelle (sort { $a cmp $b } keys %{$self->{budgetEkz}} ) {
        $self->{logger}->debug("process() haushaltsstelle:$haushaltsstelle: checkResult:" . $self->{budgetEkz}->{$haushaltsstelle}->{checkResult} . ":");
        if ( $self->{budgetEkz}->{$haushaltsstelle}->{checkResult} & 1 ) {
            foreach my $ekzArtikelNr (@{$self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{1}}) {
                if ( length($errorMessage->{1}) == 0 ) {
                    $errorMessage->{1} = "Etat-Angabe fehlt bei ekzArtikel $ekzArtikelNr";
                } else {
                    $errorMessage->{1} .= ", $ekzArtikelNr";
                }
            }
            $errorMessageType |= 1;
        } elsif ( $self->{budgetEkz}->{$haushaltsstelle}->{checkResult} & 2 ) {
            foreach my $ekzArtikelNr (@{$self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{2}}) {
                if ( length($errorMessage->{2}) == 0 ) {
                    $errorMessage->{2} = "Ungültige Etat-Angabe bei ekzArtikel $ekzArtikelNr";
                } else {
                    $errorMessage->{2} .= ", $ekzArtikelNr";
                }
            }
            $errorMessageType |= 2;
        } else {
            foreach my $kostenstelle (sort { $a cmp $b } keys %{$self->{budgetEkz}->{$haushaltsstelle}} ) {
                $self->{logger}->debug("process() haushaltsstelle:$haushaltsstelle: kostenstelle:$kostenstelle: checkResult:" . $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} . ":");
                if ( $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} & 16 ) {
                    foreach my $ekzArtikelNr (@{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{16}}) {
                        if ( length($errorMessage->{16}) == 0 ) {
                            $errorMessage->{16} = "Konto-Angabe fehlt bei ekzArtikel $ekzArtikelNr";
                        } else {
                            $errorMessage->{16} .= ", $ekzArtikelNr";
                        }
                    }
                    $errorMessageType |= 16;
                } else {
                    if ( $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} ) {
                        foreach my $errtype (32, 256, 512, 1024) {
                            if ( $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} & $errtype ) {
                                foreach my $ekzArtikelNr (@{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{$errtype}}) {
                                    if ( length($errorMessage->{$errtype}) == 0 ) {
                                        if ( $errtype == 32 ) {
                                            $errorMessage->{$errtype} .= "Ungültige Konto-Angabe bei ekzArtikel $ekzArtikelNr";
                                        }
                                        if ( $errtype == 256 ) {
                                            $errorMessage->{$errtype} .= "Überschreitung des Kontos $haushaltsstelle/$kostenstelle durch ekzArtikel $ekzArtikelNr";
                                        }
                                        if ( $errtype == 512 ) {
                                            my $encumb = $self->{budgetKoha}->{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{budgetId}}->{budget_encumb};
                                            $errorMessage->{$errtype} .= sprintf("Überschreitung der Warnquote von $haushaltsstelle/$kostenstelle (%.0f%%) durch ekzArtikel $ekzArtikelNr",$encumb);
                                        }
                                        if ( $errtype == 1024 ) {
                                            my $expend = $self->{budgetKoha}->{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{budgetId}}->{budget_expend};
                                            $errorMessage->{$errtype} .= sprintf("Überschreitung des Warnlimits von $haushaltsstelle/$kostenstelle (%.2f EUR) durch ekzArtikel $ekzArtikelNr",$expend);
                                        }
                                    } else {
                                        $errorMessage->{$errtype} .= ", $ekzArtikelNr";
                                    }
                                }
                                $errorMessageType |= $errtype;
                            }
                        }
                    }
                }
            }
        }
    }


     $respStatusCode = 'SUCCESS';    # i.e. budget violation successfully found
    if ( !$authenticated ) {
        $respStatusMessage = "nicht authentifiziert";
    } elsif ( !$ekzLocalServicesEnabled ) {
        $respStatusMessage = "Webservices für ekz-Anfragen sind in der Koha-Instanz " . C4::External::EKZ::EkzAuthentication::kohaInstanceName() . " nicht aktiviert.";
    } elsif ( $errorMessageType ) {
        foreach my $errtype (1, 2, 16, 32, 256, 512, 1024) {
            if ( $errorMessageType & $errtype ) {
                $respStatusMessage .= $errorMessage->{$errtype} . ". ";
            }
        }
    } else {
        $respStatusCode = 'ERROR';
        $respStatusMessage = "Die Bestellung liegt im Budget.";
    }

    my $soapStatusCode = SOAP::Data->name( 'statusCode'    => $respStatusCode )->type( 'string' );
    my $soapStatusMessage = SOAP::Data->name( 'statusMessage'  => $respStatusMessage )->type( 'string' );
    my $soapTransactionID = SOAP::Data->name( 'transactionID'  => $respTransactionID )->type( 'string' );

    my @soapTitelInfoListe = ();
    foreach my $titelInfo (@titelInfoListe)
    {
        $self->{logger}->debug("process() id:" . $titelInfo->{'id'} . ":");

        my $soapId = SOAP::Data->name( 'id' => $titelInfo->{'id'} )->type( 'string' );
        my @soapExemplare = ();

        foreach my $exemplar (@{$titelInfo->{'exemplare'}})
        {
            $self->{logger}->debug("process() exemplar->{'temporaryId'}:" . $exemplar->{'temporaryId'} . ":");

            my $soapExemplar = SOAP::Data->name( 'exemplar' => \SOAP::Data->value(
                SOAP::Data->name( 'temporaryId' => $exemplar->{'temporaryId'} )->type( 'string' ),
                SOAP::Data->name( 'inBudget' => $exemplar->{'inBudget'} )->type( 'string' )
            ));

            push @soapExemplare, $soapExemplar;
        }
        my $soapTitelInfo = SOAP::Data->name( 'titel'  => \SOAP::Data->value($soapId,@soapExemplare));

        push @soapTitelInfoListe, $soapTitelInfo;
    }
    $self->{logger}->debug("process() ENDE \@soapTitelInfoListe:" . Dumper(\@soapTitelInfoListe) . ":");

    my $soapResponseElement = SOAP::Data->name( 'ns1:BudgetCheckResultatElement' )->SOAP::Header::value(
        [$soapStatusCode,
         $soapStatusMessage,
         $soapTransactionID,
         @soapTitelInfoListe])->SOAP::Header::attr('xmlns:ns1="http://www.ekz.de/BestellsystemWSDL"');

    return $soapResponseElement;
     
}

# budget check for all the ordered items of a title
sub handleBudgetCheck {
    my ($self, $reqEkzArtikelNr, $reqIsbn, $reqIsbn13, $exemplarArrayRef) = @_;
    my $ekzKohaRecord = C4::External::EKZ::lib::EkzKohaRecords->new();
    
    # variables for result structure
    my %titel = ();
    my @exemplare = ();

    $self->{logger}->info("handleBudgetCheck() START reqEkzArtikelNr:$reqEkzArtikelNr:");

    $titel{'id'} = $reqEkzArtikelNr;

    my $itemCount = scalar @{$exemplarArrayRef};
    for ( my $i = 0; $i < $itemCount; $i++ ) {
        $self->{logger}->debug("handleBudgetCheck() reqEkzArtikelNr:$reqEkzArtikelNr: itemCount:$itemCount: exemplar loop i:$i:");

        my $temporaryId = (defined $exemplarArrayRef->[$i]->{'temporaryId'} && length($exemplarArrayRef->[$i]->{'temporaryId'}) > 0) ? $exemplarArrayRef->[$i]->{'temporaryId'} : "temporaryId not set";
        my $exemplarquantity = $exemplarArrayRef->[$i]->{'konfiguration'}->{'anzahl'};
        $self->{logger}->debug("handleBudgetCheck() itemCount $itemCount: exemplar loop i:$i: exemplarquantity:$exemplarquantity:");
        my $inBudget = 1;    # If the real budget check in Koha is not activated, we return that the budget is not exceeded.

        # attaching ekz order to Koha acquisition: check means in aqbudgets.
        if ( defined($self->{ekzAqbooksellersId}) && length($self->{ekzAqbooksellersId}) ) {
            my $haushaltsstelle = $exemplarArrayRef->[$i]->{'konfiguration'}->{'budget'}->{'haushaltsstelle'} ? $exemplarArrayRef->[$i]->{'konfiguration'}->{'budget'}->{'haushaltsstelle'} : '---';
            my $kostenstelle = $exemplarArrayRef->[$i]->{'konfiguration'}->{'budget'}->{'kostenstelle'} ? $exemplarArrayRef->[$i]->{'konfiguration'}->{'budget'}->{'kostenstelle'} : '---';
            my $gesamtpreis = defined($exemplarArrayRef->[$i]->{'konfiguration'}->{'preis'}->{'gesamtpreis'}) ? $exemplarArrayRef->[$i]->{'konfiguration'}->{'preis'}->{'gesamtpreis'} : '0.0.';
            $self->{logger}->debug("handleBudgetCheck() exemplar loop i:$i: haushaltsstelle:$haushaltsstelle: kostenstelle:$kostenstelle: gesamtpreis:$gesamtpreis: exemplarquantity:$exemplarquantity:");

            if ( $haushaltsstelle eq '---' || $kostenstelle eq '---' ) {
                $inBudget = 0;
                if ( $haushaltsstelle eq '---' ) {
                    $self->{budgetEkz}->{$haushaltsstelle}->{checkResult} |= 1;
                    if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{1}) ) {
                        $self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{1} = [];
                    }
                    push @{$self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{1}}, $reqEkzArtikelNr;
                } else {
                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} |= 16;
                    if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{16}) ) {
                        $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{16} = [];
                    }
                    push @{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{16}}, $reqEkzArtikelNr;
                }
            } else {
                my ($budgetperiodId, $budgetperiodDescription, $budgetId, $budgetCode) = $ekzKohaRecord->checkAqbudget($self->{hauptstelle}, $haushaltsstelle, $kostenstelle, 0);
                $self->{logger}->debug("handleBudgetCheck() nach checkAqbudget budgetId:$budgetId:");

                # LMSCloud requires that the combination of haushaltsstelle and kostenstelle (budgetperiodDescription and budgetCode) be unique,
                # so we need not store in $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{$zweigstellencode} because $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle} is sufficient
                if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}) ) {
                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{budgetperiodId} = $budgetperiodId;
                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{budgetperiodDescription} = $budgetperiodDescription;
                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{budgetId} = $budgetId;
                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{budgetCode} = $budgetCode;
                    $self->{logger}->debug("handleBudgetCheck() created self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle} with budgetperiodId:$budgetperiodId: budgetperiodDescription:$budgetperiodDescription: budgetId:$budgetId: budgetCode:$budgetCode:");
                }
                if ( !(defined($budgetperiodId) && $budgetperiodId > 0) ) {
                    $inBudget = 0;
                    $self->{budgetEkz}->{$haushaltsstelle}->{checkResult} |= 2;
                    if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{2}) ) {
                        $self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{2} = [];
                    }
                    push @{$self->{budgetEkz}->{$haushaltsstelle}->{ekzArtikelNr}->{2}}, $reqEkzArtikelNr;
                }
                if ( !(defined($budgetId) && $budgetId > 0) ) {
                    $inBudget = 0;
                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} |= 32;
                    if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{32}) ) {
                        $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{32} = [];
                    }
                    push @{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{32}}, $reqEkzArtikelNr;
                } else {
                    my $unittotal = $exemplarquantity * $gesamtpreis;    # discounted, tax incl.  (if aqbooksellers.invoiceincgst)
                    if ( !defined($self->{budgetKoha}->{$budgetId} ) ) {
                        # read means of this aqbudget for checking the limits encumbrance, expenditure etc.

                        my $budget = C4::Budgets::GetBudget($budgetId);
                        $self->{budgetKoha}->{$budgetId}->{budget_amount} = $budget->{budget_amount};
                        $self->{budgetKoha}->{$budgetId}->{budget_encumb} = $budget->{budget_encumb};    # quote, e.g. 90.0 represents 90% (of budget_amount)
                        $self->{budgetKoha}->{$budgetId}->{budg_encumbrance} = $budget->{budget_amount} * $budget->{budget_encumb} / 100.0;
                        $self->{budgetKoha}->{$budgetId}->{budget_expend} = $budget->{budget_expend};    # means, e.g. 9000.0 represents 9000.00 EUR
                        $self->{budgetKoha}->{$budgetId}->{budg_ordered} = GetBudgetOrdered($budgetId);
                        $self->{budgetKoha}->{$budgetId}->{budg_spent} = GetBudgetSpent($budgetId);
                        $self->{logger}->debug("handleBudgetCheck() created self->{budgetKoha}->{$budgetId} with budget_amount:" . scalar $self->{budgetKoha}->{$budgetId}->{budget_amount} . ": budg_spent:" . scalar $self->{budgetKoha}->{$budgetId}->{budg_spent} . ": budg_ordered:" . scalar $self->{budgetKoha}->{$budgetId}->{budg_ordered} . ":");
                    }
                    if ( defined($self->{budgetKoha}->{$budgetId}->{budget_amount} ) ) {
                        my $budget_used = $self->{budgetKoha}->{$budgetId}->{budg_spent} + $self->{budgetKoha}->{$budgetId}->{budg_ordered};
                        my $budget_remaining = $self->{budgetKoha}->{$budgetId}->{budget_amount} - $budget_used;

                        $self->{logger}->debug("handleBudgetCheck() self->{budgetKoha}->{$budgetId}->{budget_amount}:" . scalar $self->{budgetKoha}->{$budgetId}->{budget_amount} . ":");
                        $self->{logger}->debug("handleBudgetCheck() self->{budgetKoha}->{$budgetId}->{budget_encumb}:" . scalar $self->{budgetKoha}->{$budgetId}->{budget_encumb} . ":");
                        $self->{logger}->debug("handleBudgetCheck() self->{budgetKoha}->{$budgetId}->{budg_encumbrance}:" . scalar $self->{budgetKoha}->{$budgetId}->{budg_encumbrance} . ":");
                        $self->{logger}->debug("handleBudgetCheck() self->{budgetKoha}->{$budgetId}->{budget_expend}:" . scalar $self->{budgetKoha}->{$budgetId}->{budget_expend} . ":");
                        $self->{logger}->debug("handleBudgetCheck() self->{budgetKoha}->{$budgetId}->{budg_ordered}:" . scalar $self->{budgetKoha}->{$budgetId}->{budg_ordered} . ":");
                        $self->{logger}->debug("handleBudgetCheck() self->{budgetKoha}->{$budgetId}->{budg_spent}:" . scalar $self->{budgetKoha}->{$budgetId}->{budg_spent} . ":");
                        $self->{logger}->debug("handleBudgetCheck() budget_used:$budget_used: budget_remaining:$budget_remaining: unittotal:$unittotal:");

                        if ( $unittotal > $budget_remaining ) {
                            $inBudget = 0;
                            $self->{budgetKoha}->{$budgetId}->{warn_remaining} = 'Warning! Order total amount exceeds allowed budget';
                            $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} |= 256;
                            if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{256}) ) {
                                $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{256} = [];
                            }
                            push @{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{256}}, $reqEkzArtikelNr;
                        } else {
                            if ( ($self->{budgetKoha}->{$budgetId}->{budg_encumbrance}+0) && ($budget_used + $unittotal) > $self->{budgetKoha}->{$budgetId}->{budg_encumbrance} ) {
                                $self->{budgetKoha}->{$budgetId}->{warn_encumbrance} = sprintf("Warning! You will exceed %s %% of your fund.",$self->{budgetKoha}->{$budgetId}->{budget_encumb});
                                $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} |= 512;
                                if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{512}) ) {
                                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{512} = [];
                                }
                                push @{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{512}}, $reqEkzArtikelNr;
                            }
                            if ( ($self->{budgetKoha}->{$budgetId}->{budget_expend}+0) && ($budget_used + $unittotal) > $self->{budgetKoha}->{$budgetId}->{budget_expend} ) {
                                $self->{budgetKoha}->{$budgetId}->{warn_expenditure} = sprintf("Warning! You will exceed maximum limit %s %s for your fund.",$self->{budgetKoha}->{$budgetId}->{budget_expend},'EUR');
                                $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{checkResult} |= 1024;
                                if ( !defined($self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{1024}) ) {
                                    $self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{1024} = [];
                                }
                                push @{$self->{budgetEkz}->{$haushaltsstelle}->{$kostenstelle}->{ekzArtikelNr}->{1024}}, $reqEkzArtikelNr;
                            }
                        }
                        $self->{budgetKoha}->{$budgetId}->{budg_ordered} += $unittotal;
                    }
                }
            }
        }
        $self->{logger}->debug("handleBudgetCheck() inBudget:$inBudget:");

        my %exemplar = ();
        $exemplar{'temporaryId'} = $temporaryId;
        if ( $inBudget ) {    # refers to the current exemplar block
            $exemplar{'inBudget'} = 'true';
        } else {
            $exemplar{'inBudget'} = 'false';
        }
        push @exemplare, \%exemplar;
    }
    $titel{'exemplare'} = \@exemplare;

    $self->{logger}->debug("handleBudgetCheck() titel-ID:" . $titel{'id'} . ":");
    $self->{logger}->debug("handleBudgetCheck() Exemplare:" . Dumper(@exemplare) . ":");
    $self->{logger}->debug("handleBudgetCheck() Anz. Exemplare:" . scalar @exemplare . ":");
    $self->{logger}->debug("handleBudgetCheck() titel-Exemplare:" . Dumper($titel{'exemplare'}) . ":");
    $self->{logger}->debug("handleBudgetCheck() Anz. titel-Exemplare:" . scalar @{$titel{'exemplare'}} . ":");

    return \%titel;
}



sub NotImplementedElement {
    my $requiredHttpSoapAction = shift;
    my ($request) = @_;    # $request->{'soap:Envelope'}->{'soap:Body'} contains our deserialized not implemented SOAP element of the HTTP request
    my $soapElementName = "";
    my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ::BudgetCheckElement' });

    $logger->info("NotImplementedElement() START request:" . Dumper($request) . ":");
    $logger->debug("NotImplementedElement() HTTP request request->{'soap:Envelope'}->{'soap:Body'}:" . Dumper($request->{'soap:Envelope'}->{'soap:Body'}) . ":");

    my $soapEnvelopeHeader = $request->{'soap:Envelope'}->{'soap:Header'};
    my $soapEnvelopeBody = $request->{'soap:Envelope'}->{'soap:Body'};

foreach my $tag  (keys %{$soapEnvelopeBody}) {
    $logger->trace("NotImplementedElement() HTTP request soapEnvelopeBody tag:" . $tag . ":");
    $soapElementName = $tag;
    last;
}
foreach my $tag  (keys %{$soapEnvelopeBody->{$soapElementName}}) {
    $logger->trace("NotImplementedElement() HTTP request soapEnvelopeBody->{$soapElementName} tag:" . $tag . ":");
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
    my @titelInfoListe = ();


    $respStatusCode = 'ERROR';
    if ( !$authenticated ) {
        $respStatusMessage = "nicht authentifiziert";
    } elsif ( !$ekzLocalServicesEnabled ) {
        $respStatusMessage = "Webservices für ekz-Anfragen sind in der Koha-Instanz " . C4::External::EKZ::EkzAuthentication::kohaInstanceName() . " nicht aktiviert.";
    } else {
        $respStatusMessage = "Service:$requiredHttpSoapAction: ist nicht implementiert.";
    }

    my $soapStatusCode = SOAP::Data->name( 'statusCode'    => $respStatusCode )->type( 'string' );
    my $soapStatusMessage = SOAP::Data->name( 'statusMessage'  => $respStatusMessage )->type( 'string' );
    my $soapTransactionID = SOAP::Data->name( 'transactionID'  => $respTransactionID )->type( 'string' );

    my @soapTitelInfoListe = ();

    my $soapResponseElement = SOAP::Data->name($soapElementName . 'Response')->SOAP::Header::value(
        [$soapStatusCode,
         $soapStatusMessage,
         $soapTransactionID,
         @soapTitelInfoListe])->SOAP::Header::attr('xmlns:ns1="http://www.ekz.de/BestellsystemWSDL"');

    $logger->info("NotImplementedElement() ENDE soapResponseElement:" . Dumper($soapResponseElement) . ":");

    return $soapResponseElement;
     
}

1;
