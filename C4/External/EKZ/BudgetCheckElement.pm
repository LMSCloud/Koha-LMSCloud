package C4::External::EKZ::BudgetCheckElement;

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

use C4::External::EKZ::EkzAuthentication;



my $debugIt = 1;
my $inBudget = 1;    # will be set to 0 if at least one of the budgets is not sufficient

sub BudgetCheckElement {
    my ($request) = @_;    # $request->{'soap:Envelope'}->{'soap:Body'} contains our deserialized BudgetCheckElement of the HTTP request

print STDERR "BudgetCheckElement::BudgetCheckElement() START\n";
print STDERR Dumper($request);
print STDERR Dumper($request->{'soap:Envelope'});
print STDERR Dumper($request->{'soap:Envelope'}->{'soap:Header'});
print STDERR Dumper($request->{'soap:Envelope'}->{'soap:Body'});
print STDERR Dumper($request->{'soap:Envelope'}->{'soap:Body'}->{'ns2:BudgetCheckElement'});

print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request request->{'soap:Envelope'}->{'soap:Body'}:", $request->{'soap:Envelope'}->{'soap:Body'}, ":\n";
print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request request messageID:", $request->{'soap:Envelope'}->{'soap:Body'}->{'ns2:BudgetCheckElement'}->{'messageID'}, ":\n";

    my $soapEnvelopeHeader = $request->{'soap:Envelope'}->{'soap:Header'};
    my $soapEnvelopeBody = $request->{'soap:Envelope'}->{'soap:Body'};

foreach my $tag  (keys %{$soapEnvelopeBody->{'ns2:BudgetCheckElement'}}) {
    print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request tag:", $tag, ":\n";
}

    my $wssusername = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'} : "WSS-username not defined";
    my $wsspassword = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'} : "WSS-username not defined";
print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request header wss username/password:" . $wssusername . "/" . $wsspassword . ":\n";
    my $authenticated = C4::External::EKZ::EkzAuthentication::authenticate($wssusername, $wsspassword);
    my $ekzLocalServicesEnabled = C4::External::EKZ::EkzAuthentication::ekzLocalServicesEnabled();

    # result values
    my $respStatusCode = 'UNDEF';
    my $respStatusMessage = 'UNDEF';
    my $timeOfDay = [gettimeofday];
    my $respTransactionID = sprintf("%d.%06d", $timeOfDay->[0], $timeOfDay->[1]);     # seconds.microseconds
    my @titelInfoListe = ();
    

    $inBudget = 1;    # will be set to 0 if at least one of the budgets is not sufficient
    if($authenticated && $ekzLocalServicesEnabled)
    {
print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request titel:",$soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'},":\n";
print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request ref(titel):",ref($soapEnvelopeBody->{'ns2:BudgetCheckElement'}->{'titel'}),":\n";
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
        print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request titel array:",@$titelArrayRef," AnzElem:", scalar @$titelArrayRef,":\n";

        my $titleCount = scalar @$titelArrayRef;
        print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP titleCount:",$titleCount, ":\n";
        for ( my $i = 0; $i < $titleCount; $i++ ) {
            print STDERR "BudgetCheckElement::BudgetCheckElement() title loop $i\n";
            my $titel = $titelArrayRef->[$i];

            # extracting the search criteria
            my $reqEkzArtikelNr = $titel->{'ekzArtikelNr'};
            my $reqIsbn = $titel->{'titelInfo'}->{'isbn'};
            my $reqIsbn13 = $titel->{'titelInfo'}->{'isbn13'};
            my $reqAuthor = $titel->{'titelInfo'}->{'author'};
            my $reqTitel = $titel->{'titelInfo'}->{'titel'};
            my $reqErscheinungsJahr = $titel->{'titelInfo'}->{'erscheinungsJahr'};
            my $reqEinzelPreis = $titel->{'titelInfo'}->{'einzelPreis'};

            if ( $debugIt ) {
                # log request parameters
                my $logstr = $titel->{'ekzArtikelNr'} ? $titel->{'ekzArtikelNr'} : "<undef>";
                print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request ekzArtikelNr:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'isbn'} ? $titel->{'titelInfo'}->{'isbn'} : "<undef>";
                print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request isbn:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'isbn13'} ? $titel->{'titelInfo'}->{'isbn13'} : "<undef>";
                print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request isbn13:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'author'} ? $titel->{'titelInfo'}->{'author'} : "<undef>";
                print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request author:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'titel'} ? $titel->{'titelInfo'}->{'titel'} : "<undef>";
                print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request titel:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'erscheinungsJahr'} ? $titel->{'titelInfo'}->{'erscheinungsJahr'} : "<undef>";
                print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request erscheinungsJahr:$logstr:\n";
                $logstr = $titel->{'titelInfo'}->{'einzelPreis'} ? $titel->{'titelInfo'}->{'einzelPreis'} : "<undef>";
                print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request einzelPreis:$logstr:\n";
            }

            print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request exemplar:",$titel->{'exemplar'},":\n";
            print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request ref(exemplar):",ref($titel->{'exemplar'}),":\n";
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
            print STDERR "BudgetCheckElement::BudgetCheckElement() HTTP request exemplarArray:",@$exemplarArrayRef," AnzElem:", 0+@$exemplarArrayRef,":\n";
            my $titelInfo = &handleBudgetCheck($reqEkzArtikelNr, $reqIsbn, $reqIsbn13, $exemplarArrayRef);

            print STDERR "BudgetCheckElement::BudgetCheckElement() titelInfo:",%$titelInfo, "\n" if $debugIt;
            print STDERR "BudgetCheckElement::BudgetCheckElement() titelInfo->id:",$titelInfo->{'id'}, "\n" if $debugIt;
            print STDERR "BudgetCheckElement::BudgetCheckElement() Anz. titelInfo->exemplare:",@{$titelInfo->{'exemplare'}}+0, "\n" if $debugIt;

            push @titelInfoListe, $titelInfo;
        }
    }

    print STDERR "BudgetCheckElement::BudgetCheckElement() Anzahl titelInfoListe:",@titelInfoListe+0, "\n" if $debugIt;


    $respStatusCode = 'ERROR';
    if ( !$authenticated ) {
        $respStatusMessage = "nicht authentifiziert";
    } elsif ( !$ekzLocalServicesEnabled ) {
        $respStatusMessage = "Webservices für ekz-Anfragen sind in der Koha-Instanz " . C4::External::EKZ::EkzAuthentication::kohaInstanceName() . " nicht aktiviert.";
    } elsif ( $inBudget ) {
        $respStatusMessage = "Die Bestellung liegt im Budget.";
    } else
    {
        $respStatusCode = 'SUCCESS';
        $respStatusMessage = "Die Bestellung übersteigt das Budget.";
    }

    my $soapStatusCode = SOAP::Data->name( 'statusCode'    => $respStatusCode )->type( 'string' );
    my $soapStatusMessage = SOAP::Data->name( 'statusMessage'  => $respStatusMessage )->type( 'string' );
    my $soapTransactionID = SOAP::Data->name( 'transactionID'  => $respTransactionID )->type( 'string' );

    my @soapTitelInfoListe = ();
    foreach my $titelInfo (@titelInfoListe)
    {
        print STDERR "BudgetCheckElement::BudgetCheckElement(); id:",$titelInfo->{'id'},":\n" if $debugIt;

        my $soapId = SOAP::Data->name( 'id' => $titelInfo->{'id'} )->type( 'string' );
        my @soapExemplare = ();

        foreach my $exemplar (@{$titelInfo->{'exemplare'}})
        {
            print STDERR "BudgetCheckElement::BudgetCheckElement(); exemplar->{'temporaryId'}:",$exemplar->{'temporaryId'},":\n" if $debugIt;

            my $soapExemplar = SOAP::Data->name( 'exemplar' => \SOAP::Data->value(
                SOAP::Data->name( 'temporaryId' => $exemplar->{'temporaryId'} )->type( 'string' ),
                SOAP::Data->name( 'inBudget' => $exemplar->{'inBudget'} )->type( 'string' )
            ));

            push @soapExemplare, $soapExemplar;
        }
        my $soapTitelInfo = SOAP::Data->name( 'titel'  => \SOAP::Data->value($soapId,@soapExemplare));

        push @soapTitelInfoListe, $soapTitelInfo;
    }
print STDERR "BudgetCheckElement::BudgetCheckElement() ENDE \@soapTitelInfoListe\n";
print STDERR Dumper(\@soapTitelInfoListe);

    my $soapResponseElement = SOAP::Data->name( 'ns1:BudgetCheckResultatElement' )->SOAP::Header::value(
        [$soapStatusCode,
         $soapStatusMessage,
         $soapTransactionID,
         @soapTitelInfoListe])->SOAP::Header::attr('xmlns:ns1="http://www.ekz.de/BestellsystemWSDL"');

    return $soapResponseElement;
     
}

# budget check for all the ordered items of a title
# At the moment this is a functional dummy.
sub handleBudgetCheck {
    my ($reqEkzArtikelNr, $reqIsbn, $reqIsbn13, $exemplarArrayRef) = @_;
    my $testIt = 0;
    
    # variables for result structure
    my %titel = ();
    my @exemplare = ();

    if ( $testIt ) {
        $titel{'id'} = '3297876';

        my %exemplar = ();
        $exemplar{'temporaryId'} = '32978760-12345';
        $exemplar{'inBudget'} = 'true';
        push @exemplare, \%exemplar;
        push @exemplare, \%exemplar;
        push @exemplare, \%exemplar;
        $titel{'exemplare'} = \@exemplare;

        print STDERR "BudgetCheckElement::handleBudgetCheck() titel-ID:",$titel{'id'},":\n" if $debugIt;
        print STDERR "BudgetCheckElement::handleBudgetCheck() Exemplare:",@exemplare,":\n" if $debugIt;
        print STDERR "BudgetCheckElement::handleBudgetCheck() Anz. Exemplare:",@exemplare+0,":\n";
        print STDERR "BudgetCheckElement::handleBudgetCheck() titel-Exemplare:",$titel{'exemplare'},":\n" if $debugIt;
        print STDERR "BudgetCheckElement::handleBudgetCheck() Anz. titel-Exemplare:",@#{$titel{'exemplare'}}-1,":\n" if $debugIt;
    } else
    {
        # In reality we schould check if the budgets are sufficient for the prices of all items sent.
        # But at the moment BudgetCheck is a dummy that returns true for any item price.

        $titel{'id'} = $reqEkzArtikelNr;

        my $itemCount = scalar @{$exemplarArrayRef};
        for ( my $i = 0; $i < $itemCount; $i++ ) {
            print STDERR "BudgetCheckElement::handleBudgetCheck() reqEkzArtikelNr:$reqEkzArtikelNr: exemplar loop $i\n";

            my $temporaryId = (defined $exemplarArrayRef->[$i]->{'temporaryId'} && length($exemplarArrayRef->[$i]->{'temporaryId'}) > 0) ? $exemplarArrayRef->[$i]->{'temporaryId'} : "temporaryId not set";
            my $exemplarcount = $exemplarArrayRef->[$i]->{'konfiguration'}->{'anzahl'};
            print STDERR "BudgetCheckElement::handleBudgetCheck() exemplar itemCount $itemCount loop $i exemplarcount $exemplarcount\n";

            for ( my $j = 0; $j < $exemplarcount; $j++ ) {
                my %exemplar = ();
                $exemplar{'temporaryId'} = $temporaryId . "-" . ($j+1);    # Kombination aus ekz Temporary ID und einer LMS Temporary ID
                if ( 1 ) {    # for test only, in place of real budget check
                    $exemplar{'inBudget'} = 'true';
                } else {
                    $exemplar{'inBudget'} = 'false';
                    $inBudget = 0;
                }
                push @exemplare, \%exemplar;
            }
        }
        $titel{'exemplare'} = \@exemplare;

        print STDERR "BudgetCheckElement::handleBudgetCheck() titel-ID:", $titel{'id'}, ":\n" if $debugIt;
        print STDERR "BudgetCheckElement::handleBudgetCheck() inBudget:", $inBudget, ":\n" if $debugIt;
        print STDERR "BudgetCheckElement::handleBudgetCheck() Exemplare:", @exemplare, ":\n" if $debugIt;
        print STDERR "BudgetCheckElement::handleBudgetCheck() Anz. Exemplare:", @exemplare+0, ":\n";
        print STDERR "BudgetCheckElement::handleBudgetCheck() titel-Exemplare:", $titel{'exemplare'}, ":\n" if $debugIt;
        print STDERR "BudgetCheckElement::handleBudgetCheck() Anz. titel-Exemplare:", @{$titel{'exemplare'}}, ":\n" if $debugIt;
    }

    return \%titel;
}



sub NotImplementedElement {
    my $requiredHttpSoapAction = shift;
    my ($request) = @_;    # $request->{'soap:Envelope'}->{'soap:Body'} contains our deserialized not implemented SOAP element of the HTTP request
    my $soapElementName = "";

print STDERR "BudgetCheckElement::NotImplementedElement() START\n";
print STDERR Dumper($request);
print STDERR Dumper($request->{'soap:Envelope'});
print STDERR Dumper($request->{'soap:Envelope'}->{'soap:Header'});
print STDERR Dumper($request->{'soap:Envelope'}->{'soap:Body'});

print STDERR "BudgetCheckElement::NotImplementedElement() HTTP request request->{'soap:Envelope'}->{'soap:Body'}:", $request->{'soap:Envelope'}->{'soap:Body'}, ":\n";
    my $soapEnvelopeHeader = $request->{'soap:Envelope'}->{'soap:Header'};
    my $soapEnvelopeBody = $request->{'soap:Envelope'}->{'soap:Body'};

foreach my $tag  (keys %{$soapEnvelopeBody}) {
    print STDERR "BudgetCheckElement::NotImplementedElement() HTTP request tag1:", $tag, ":\n";
    $soapElementName = $tag;
    last;
}
foreach my $tag  (keys %{$soapEnvelopeBody->{$soapElementName}}) {
    print STDERR "BudgetCheckElement::NotImplementedElement() HTTP request tag2:", $tag, ":\n";
}

    my $wssusername = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Username'} : "WSS-username not defined";
    my $wsspassword = defined($soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'}) ? $soapEnvelopeHeader->{'wsse:Security'}->{'wsse:UsernameToken'}->{'wsse:Password'} : "WSS-username not defined";
print STDERR "BudgetCheckElement::NotImplementedElement() HTTP request header wss username/password:" . $wssusername . "/" . $wsspassword . ":\n";
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

print STDERR "BudgetCheckElement::NotImplementedElement() ENDE \$soapResponseElement:\n";
print STDERR Dumper($soapResponseElement);

    return $soapResponseElement;
     
}

1;
