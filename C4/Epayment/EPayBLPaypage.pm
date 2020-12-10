package C4::Epayment::EPayBLPaypage;

# Copyright 2020 (C) LMSCLoud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
use Data::Dumper;

use Modern::Perl;
use CGI::Carp;
use SOAP::Lite;
use URI::Escape;

use C4::Context;
use C4::Koha;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Patrons;

use C4::Epayment::EpaymentBase;
use parent qw(C4::Epayment::EpaymentBase);

sub new {
    my $class = shift;
    my $params = shift;
    my $loggerEpaybl = Koha::Logger->get({ interface => 'epayment.epaybl' });

    my $self = {};
    bless $self, $class;
    $self = $self->SUPER::new();
    bless $self, $class;

    $self->{logger} = $loggerEpaybl;
    $self->{patron} = $params->{patron};
    $self->{amount_to_pay} = $params->{amount_to_pay};
    $self->{accountlinesIds} = $params->{accountlinesIds};    # ref to array containing the accountlines_ids of accountlines to be payed
    $self->{paytype} = $params->{paytype};    # always 19; may be interpreted as payment via ePayBL paypage
    $self->{seconds} = time();    # make payment trials for same accountlinesIds distinguishable
    
    $self->{logger}->debug("new() cardnumber:" . $self->{patron}->cardnumber() . ": amount_to_pay:" . $self->{amount_to_pay} . ": accountlinesIds:" . Dumper($self->{accountlinesIds}) . ":");
    $self->{logger}->trace("new()  Dumper(class):" . Dumper($class) . ":");

    $self->getSystempreferences();

    my $authValues = GetAuthorisedValues("PaymentAccounttypeEpaybl",0);    # payment accounttype mapping for ePayBL
    foreach my $authValue( @{$authValues} ) {
        my @authValueLib = split( /\|/, $authValue->{lib} );
        $self->{paymentAccounttypeMapping}->{$authValue->{authorised_value}}->{haushalt} = $authValueLib[0];
        $self->{paymentAccounttypeMapping}->{$authValue->{authorised_value}}->{objektnummer} = $authValueLib[1];
    };

    $self->{now} = DateTime->from_epoch( epoch => Time::HiRes::time, time_zone => C4::Context->tz() );
    $self->{timestamp} = sprintf("%04d%02d%02d%02d%02d%02d%03d", $self->{now}->year, $self->{now}->month, $self->{now}->day, $self->{now}->hour, $self->{now}->minute, $self->{now}->second, $self->{now}->nanosecond/1000000);
    my $calculatedHashVal = $self->calculateHashVal();
    $self->{epayblEShopKundenNr} = sprintf("%s_%s_%s", $self->{patron}->cardnumber(), $self->{timestamp}, $calculatedHashVal);    # EShopKundenNr only used once; different for each payment action
    $self->{angelegtesEpayblKassenzeichen} = '';    # will be set in anlegenKassenzeichen()

    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    use IO::Socket::SSL;
    #$IO::Socket::SSL::DEBUG = 3;

    $self->{soap_request} = SOAP::Lite->new( proxy => $self->{epayblWebservicesUrl});
    $self->{soap_request}->default_ns($self->{epayblWebservicesUrl_ns});
    $self->{soap_request}->serializer->readable(1);

    $self->{logger}->debug("new() returns self:" . Dumper($self) . ":");
    return $self;
}

sub getSystempreferences {
    my $self = shift;

    $self->{logger}->debug("getSystempreferences() START");

    $self->{epayblWebservicesUrl_ns} = 'http://www.bff.bund.de/ePayment';
    $self->{epayblWebservicesUrl} = C4::Context->preference('EpayblPaypageWebservicesURL');    # test env: https://infra-pre.buergerserviceportal.de/soap/servlet/rpcrouter   production env: http://epay.akdb.de/soap/servlet/rpcrouter
    $self->{epayblPaypageUrl} = C4::Context->preference('EpayblPaypagePaypageURL');    # test env: https://infra-pre.buergerserviceportal.de/paypage/login.do   production env: https://epay.akdb.de/paypage/login.do
    $self->{epayblMandatorNumber} = C4::Context->preference('EpayblMandatorNumber');    # mandatory; ePayBL Mandantennummer (e.g. '1610000000')
    $self->{epayblOperatorNumber} = C4::Context->preference('EpayblOperatorNumber');    # mandatory; ePayBL Bewirtschafternummer (e.g. '42')
    $self->{epayblAccountingEntryText} = C4::Context->preference('EpayblAccountingEntryText');    # mandatory; ePayBL Buchungstext (e.g. 'BUEC/BUEC') (SEPA char set only)
    $self->{epayblDunningProcedureLabel} = C4::Context->preference('EpayblDunningProcedureLabel');    # mandatory; ePayBL Kennzeichen Mahnverfahren (e.g. '01')
    $self->{epayblSaltHmacSha256} = C4::Context->preference('EpayblSaltHmacSha256');    # salt for generating HMAC SHA-256 digest (e.g. 'sasd687hjh63STU7kj')
    #$self->{epayblSaltHmacSha256} = 'dsTFshg5678DGHMO';    # for test only: key for wrong HMAC digest
    $self->{opac_base_url} = C4::Context->preference('OPACBaseURL');

    $self->{logger}->debug("getSystempreferences() END epayblWebservicesUrl:$self->{epayblWebservicesUrl}: epayblMandatorNumber:$self->{epayblMandatorNumber}: epayblOperatorNumber:$self->{epayblOperatorNumber}:");
}

sub calculateHashVal {
    my $self = shift;

    $self->{logger}->debug("calculateHashVal() START self->{now}:$self->{now}:");

    my $todayMDY = $self->{now}->mdy;
    my $todayDMY = $self->{now}->dmy;
    my $key = $self->{epayblSaltHmacSha256};
    my $borrowernumber = $self->{patron}->borrowernumber();
    my $paytype = $self->{paytype};
    my $amount_to_pay = $self->{amount_to_pay};

    my $merchantTxIdKey = $todayMDY . $key . $todayDMY . $key . $borrowernumber . $paytype . '_' . $amount_to_pay . '_' . $paytype . $borrowernumber . $key . $todayDMY . $key . $todayMDY;
    my $merchantTxIdVal = $borrowernumber . '_' . $amount_to_pay;
    foreach my $accountlinesId ( @{$self->{accountlinesIds}} ) {
        $merchantTxIdVal .= '_' . $accountlinesId;
    }
    $merchantTxIdVal .= '_' . $self->{paytype};
    $merchantTxIdVal .= '_' . $merchantTxIdVal . '_' . $merchantTxIdVal;

    my $merchantTxId = $self->genHmacSha256( $merchantTxIdVal, $merchantTxIdKey );    # unique merchant transaction ID (this hash value is used to check integrity of Koha CGI parameters in opac-account-pay-epaybl-return.pl)

    $self->{logger}->debug("calculateHashVal() returns merchantTxId:$merchantTxId:");
    return ( $merchantTxId );
}

# check if ePayBL server responds to webservice requests
sub isAlive {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retIsAliveIstOk = 0;
    my $epayblmsg = '';

    my $isAliveRequest = SOAP::Data->name('mandantNr' => $self->{epayblMandatorNumber})->type('string');

    $self->{logger}->debug("isAlive() epayblWebservicesUrl:$self->{epayblWebservicesUrl}: isAliveRequest:" . Dumper($isAliveRequest) . ":");
    my $response = eval {
        $self->{soap_request}->isAlive( $isAliveRequest );
    };
    $self->{logger}->debug("isAlive() isAlive response:" . Dumper($response) . ":");

    if ( $@ ) {
        my $mess = "isAlive() error when calling self->{soap_request}->isAlive:$@:";
        $self->{logger}->error($mess);
        carp ($mess . "\n");
        $retErrorTemplate = 'EPAYBL_UNABLE_TO_CONNECT';
        $retError = 11;
    }

    if ( $response ) {
        if ( !$response->fault() ) {
            $self->{logger}->trace("isAlive() response>result():" . Dumper($response->result()) . ":");
            $self->{logger}->debug("isAlive() response>result()->{istOk}:" . Dumper($response->result()->{istOk}) . ":");
            if ( $response->result()
                 && defined( $response->result()->{istOk} ) )
            {
                if ( $response->result()->{'istOk'} eq '1' ) {
                    $retIsAliveIstOk = 1;
                } else {
                    $epayblmsg = $response->result()->{'kurzText'} . ' (' . $response->result()->{'langText'} . ')';
                }
            }

            if ( $retIsAliveIstOk == 0 ) {
                $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                $retError = 12;
            }
        }    # End of: !$response->fault()
        else {
            $epayblmsg = $response->fault();
            $retErrorTemplate = 'EPAYBL_UNABLE_TO_CONNECT';
            $retError = 13;
        }
        if ( $epayblmsg ) {
            my $mess = "isAlive() epayblmsg:" . $epayblmsg . ":";
            $self->{logger}->error($mess);
            carp ($mess . "\n");
        }
    }

    $self->{logger}->debug("isAlive() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retIsAliveIstOk:$retIsAliveIstOk:");
    return ( $retError, $retErrorTemplate, $retIsAliveIstOk );
}

# create ePayBL pseudo customer having number EShopKundenNr, that is used only once, only for this payment action
sub anlegenKunde {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retAnlegenKundeIstOk = 0;
    my $epayblmsg = '';

    my $anlegenKundeRequest = SOAP::Data->value(
        SOAP::Data->name('mandantNr' => $self->{epayblMandatorNumber})->type('string'),
        SOAP::Data->name('bewirtschafterNr' => $self->{epayblOperatorNumber})->type('string'),
        SOAP::Data->name('kunde' => 
            \SOAP::Data->value(
                SOAP::Data->name('nachname' => $self->{patron}->surname())->type('string'),    # will be shown on paypage
                SOAP::Data->name('vorname' => $self->{patron}->firstname())->type('string'),    # will be shown on paypage
                SOAP::Data->name('EShopKundenNr' => $self->{epayblEShopKundenNr})->type('string'),    # thankfully will not be shown on paypage
                SOAP::Data->name('sprache' => 'de')->type('string')    # thankfully will not be shown on paypage
            )->type('Kunde')
        )
    );

    $self->{logger}->debug("anlegenKunde() epayblWebservicesUrl:$self->{epayblWebservicesUrl}: anlegenKundeRequest:" . Dumper($anlegenKundeRequest) . ":");
    my $response = eval {
        $self->{soap_request}->anlegenKunde( $anlegenKundeRequest );
    };
    $self->{logger}->debug("anlegenKunde() response:" . Dumper($response) . ":");

    if ( $@ ) {
        my $mess = "anlegenKunde() error when calling soap_request->anlegenKunde:$@:";
        $self->{logger}->error($mess);
        carp ($mess . "\n");
        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
        $retError = 21;
    }

    if ($response ) {
        if ( !$response->fault() ) {
            $self->{logger}->trace("anlegenKunde() response>result():" . Dumper($response->result()) . ":");
            $self->{logger}->debug("anlegenKunde() response>result()->{ergebnis}:" . Dumper($response->result()->{ergebnis}) . ":");
            $self->{logger}->debug("anlegenKunde() response>result()->{ergebnis}->{istOk}:" . Dumper($response->result()->{ergebnis}->{istOk}) . ":");
            if ( $response->result()
                 && defined( $response->result()->{ergebnis} )
                 && defined( $response->result()->{ergebnis}->{istOk} ) )
            {
                if ( $response->result()->{ergebnis}->{'istOk'} eq '1' ) {
                    $retAnlegenKundeIstOk = 1;
                } else {
                    $epayblmsg = $response->result()->{ergebnis}->{'kurzText'} . ' (' . $response->result()->{ergebnis}->{'langText'} . ')';
                }
            }

            if ( $retAnlegenKundeIstOk == 0 ) {
                $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                $retError = 22;
            }
        }    # End of: !$response->fault()
        else {
            $epayblmsg = $response->fault();
            $retErrorTemplate = 'EPAYBL_UNABLE_TO_CONNECT';
            $retError = 23;
        }
        if ( $epayblmsg ) {
            my $mess = "anlegenKunde() epayblmsg:" . $epayblmsg . ":";
            $self->{logger}->error($mess);
            carp ($mess . "\n");
        }
    }

    $self->{logger}->debug("anlegenKunde() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retAnlegenKundeIstOk:$retAnlegenKundeIstOk:");
    return ( $retError, $retErrorTemplate, $retAnlegenKundeIstOk );
}

# create a new kassenzeichen, required for paypageUrl()
sub anlegenKassenzeichen {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retAnlegenKassenzeichenIstOk = 0;
    my $epayblmsg = '';

    $self->{logger}->debug("anlegenKassenzeichen() START self->{patron}->cardnumber():" . $self->{patron}->cardnumber() . ":");

    # read the marked accountlines
    my $account = Koha::Account->new( { patron_id => $self->{patron}->cardnumber() } );
    my @lines = Koha::Account::Lines->search(
        {
            accountlines_id => { -in => $self->{accountlinesIds} }
        }
    );

    my $sumAmountoutstanding = 0.0;
    my $sumAmountoutstandingForType = {};
    my $sumAmountoutstandingForHaushalt = {};
    my @buchungenArray;

    foreach my $accountline ( @lines ) {
        $self->{logger}->debug("anlegenKassenzeichen() accountline->id:" . $accountline->accountlines_id() . ": ->amountoutstanding:" . $accountline->amountoutstanding() . ": accounttype:" . $accountline->accounttype() . ":");
        my $accounttype = $accountline->accounttype();
        my $amountoutstanding = $accountline->amountoutstanding();
        if ( ! defined( $sumAmountoutstandingForType->{$accounttype} ) ) {
            $sumAmountoutstandingForType->{$accounttype} = 0.0;
        }
        $sumAmountoutstandingForType->{$accounttype} += $amountoutstanding;
        $sumAmountoutstanding += $amountoutstanding;
    }
    $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding was also done in the complimentary opac-account-pay-pl

    if ( $sumAmountoutstanding !=  $self->{amount_to_pay} ) {
        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
        $retError = 34;
        $epayblmsg = "sumAmountoutstanding (" . $sumAmountoutstanding . ") != self->{amount_to_pay} (" . $self->{amount_to_pay} . ")";
    } else {

        foreach my $accounttype ( keys %{$sumAmountoutstandingForType} ) {
            my $haushalt = '';
            my $objektnummer = '';
            if ( $self->{paymentAccounttypeMapping}->{$accounttype} ) {
                $haushalt = $self->{paymentAccounttypeMapping}->{$accounttype}->{haushalt};
                $objektnummer = $self->{paymentAccounttypeMapping}->{$accounttype}->{objektnummer};
            } elsif ( $self->{paymentAccounttypeMapping}->{''} ) {
                # we have to use the default fall back values for accounttypes without specific mapping
                $haushalt = $self->{paymentAccounttypeMapping}->{''}->{haushalt};
                $objektnummer = $self->{paymentAccounttypeMapping}->{''}->{objektnummer};
            }
            $self->{logger}->debug("anlegenKassenzeichen() sumAmountoutstandingForType->{accounttype:$accounttype}:" . $sumAmountoutstandingForType->{$accounttype} . ": haushalt:$haushalt: objektnummer:$objektnummer:");
            if ( ! defined ( $sumAmountoutstandingForHaushalt->{$haushalt} ) ) {
                $sumAmountoutstandingForHaushalt->{$haushalt}->{sum} = $sumAmountoutstandingForType->{$accounttype};
                $sumAmountoutstandingForHaushalt->{$haushalt}->{haushaltsstelle} = $haushalt;
                $sumAmountoutstandingForHaushalt->{$haushalt}->{objektnummer} = $objektnummer;
            } else {
                $sumAmountoutstandingForHaushalt->{$haushalt}->{sum} += $sumAmountoutstandingForType->{$accounttype};
            }
        }

        # ePayBL creates text for 'Verwendungszweck' by kassenzeichen . '/' . buchungstext.
        # As 'Verwendungszweck' is limited to 27 chars (of the SEPA compliant char set, by the way),
        # and kassenzeichen (e.g. '4200000000061') seems to have always a length of 13 chars, 
        # the length of the text for buchungstext has to be limited to 13 chars.
        foreach my $haushalt ( keys %{$sumAmountoutstandingForHaushalt} ) {
            my $buchungen = SOAP::Data->name('buchungen' => \SOAP::Data->value(
                #SOAP::Data->name('belegNr' => $belegNr)->type('string'),    # optional
                SOAP::Data->name('betrag' => $sumAmountoutstandingForHaushalt->{$haushalt}->{sum})->type('decimal'),
                SOAP::Data->name('buchungstext' => substr($self->{epayblAccountingEntryText},0,13))->type('string'),    # length( kassenzeichen . '/' . buchungstext ) has to be <= 27
                SOAP::Data->name('haushaltsstelle' => $sumAmountoutstandingForHaushalt->{$haushalt}->{haushaltsstelle})->type('string'),
                #SOAP::Data->name('href' => $href)->type('string'),    # optional
                SOAP::Data->name('objektnummer' => $sumAmountoutstandingForHaushalt->{$haushalt}->{objektnummer})->type('string')
            )->type('Buchung'));
            push @buchungenArray, $buchungen;
        }

        my $buchungen = SOAP::Data->value(
            @buchungenArray
        )->type('soapenc:Array');
        
        my $buchungsListe = SOAP::Data->value(
            #SOAP::Data->name('EShopTransaktionsNr' => \$buchungen)->type('string'),    # optional
            #SOAP::Data->name('EShopTransaktionsNr' => 'EShopTransaktionsNr127')->type('string'),    # optional (use not transparent)
            SOAP::Data->name('betrag' => $sumAmountoutstanding)->type('decimal'),    # will be shown on paypage
            SOAP::Data->name('bewirtschafterNr' => $self->{epayblOperatorNumber})->type('string'),
            SOAP::Data->name('buchungen' => \$buchungen)->type('soapenc:Array'),
            SOAP::Data->name('faelligkeitsdatum' => $self->{now})->type('dateTime'),
            #SOAP::Data->name('kassenzeichen' => $kassenzeichen)->type('string')    # optional
            SOAP::Data->name('kennzeichenMahnverfahren' => $self->{epayblDunningProcedureLabel})->type('string'),
            SOAP::Data->name('waehrungskennzeichen' => 'EUR')->type('string')
        )->type('BuchungsListe');
        
        #my $lieferAdresse = SOAP::Data->value(    # contrary to documentation lieferAdresse seems not to be required
        #    SOAP::Data->name('nachname' => 'Mustermann')->type('string'),
        #    SOAP::Data->name('vorname' => 'Max')->type('string')
        #)->type('LieferAdresse');

        my $anlegenKassenzeichenRequest = SOAP::Data->value(
            SOAP::Data->name('mandantNr' => $self->{epayblMandatorNumber})->type('string'),
            SOAP::Data->name('eShopKundenNr' => $self->{epayblEShopKundenNr})->type('string'),    # name starts with lower case 'e'
            SOAP::Data->name('buchungsListe' => \$buchungsListe)->type('BuchungsListe'),
            #SOAP::Data->name('lieferAdresse' => \$lieferAdresse)->type('LieferAdresse'),    # contrary to documentation this seems not to be required
            ###SOAP::Data->name('buchungstext' => $self->{epayblAccountingEntryText})->type('string')    # contrary to documentation this seems not to be required but is not accepted
            #SOAP::Data->name('zahlverfahren' => $zahlverfahren)->type('string')    # optional
        );

        $self->{logger}->debug("anlegenKassenzeichen() epayblWebservicesUrl:$self->{epayblWebservicesUrl}: anlegenKassenzeichenRequest:" . Dumper($anlegenKassenzeichenRequest) . ":");
        my $response = eval {
            $self->{soap_request}->anlegenKassenzeichen( $anlegenKassenzeichenRequest );
        };
        $self->{logger}->debug("anlegenKassenzeichen() response:" . Dumper($response) . ":");

        if ( $@ ) {
            my $mess = "anlegenKassenzeichen() error when calling soap_request->anlegenKassenzeichen:$@:";
            $self->{logger}->error($mess);
            carp ($mess . "\n");
            $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
            $retError = 31;
        }

        if ($response ) {
            if ( !$response->fault() ) {
                $self->{logger}->trace("anlegenKassenzeichen() response>result():" . Dumper($response->result()) . ":");
                $self->{logger}->debug("anlegenKassenzeichen() response>result()->{ergebnis}:" . Dumper($response->result()->{ergebnis}) . ":");
                $self->{logger}->debug("anlegenKassenzeichen() response>result()->{ergebnis}->{istOk}:" . Dumper($response->result()->{ergebnis}->{istOk}) . ":");
                $self->{logger}->debug("anlegenKassenzeichen() response>result()->{buchungsListe}:" . Dumper($response->result()->{buchungsListe}) . ":");
                $self->{logger}->debug("anlegenKassenzeichen() response>result()->{buchungsListe}->{kassenzeichen}:" . Dumper($response->result()->{buchungsListe}->{kassenzeichen}) . ":");
                if ( $response->result()
                     && defined( $response->result()->{ergebnis} )
                     && defined( $response->result()->{ergebnis}->{istOk} )
                     && defined( $response->result()->{buchungsListe} )
                     && defined( $response->result()->{buchungsListe}->{kassenzeichen} ) )
                {
                    if ( $response->result()->{ergebnis}->{'istOk'} eq '1' && length($response->result()->{buchungsListe}->{'kassenzeichen'}) ) {
                        $retAnlegenKassenzeichenIstOk = 1;
                        $self->{angelegtesEpayblKassenzeichen} = $response->result()->{buchungsListe}->{'kassenzeichen'};
                    } else {
                        $epayblmsg = $response->result()->{ergebnis}->{'kurzText'} . ' (' . $response->result()->{ergebnis}->{'langText'} . ')';
                    }
                }

                if ( $retAnlegenKassenzeichenIstOk == 0 ) {
                    $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                    $retError = 32;
                }
            }    # End of: !$response->fault()
            else {
                $epayblmsg = $response->fault();
                $retErrorTemplate = 'EPAYBL_UNABLE_TO_CONNECT';
                $retError = 33;
            }
        }
    }

    if ( $epayblmsg ) {
        my $mess = "anlegenKassenzeichen() epayblmsg:" . $epayblmsg . ":";
        $self->{logger}->error($mess);
        carp ($mess . "\n");
    }
    $self->{logger}->debug("anlegenKassenzeichen() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retAnlegenKassenzeichenIstOk:$retAnlegenKassenzeichenIstOk:");
    return ( $retError, $retErrorTemplate, $retAnlegenKassenzeichenIstOk );
}

# delete ePayBL pseudo customer having number EShopKundenNr
sub loeschenKunde {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retLoeschenKundeIstOk = 0;
    my $epayblmsg = '';

    my $loeschenKundeRequest = SOAP::Data->value(
        SOAP::Data->name('mandantNr' => $self->{epayblMandatorNumber})->type('string'),
        SOAP::Data->name('bewirtschafterNr' => $self->{epayblOperatorNumber})->type('string'),
        SOAP::Data->name('EShopKundenNr' => $self->{epayblEShopKundenNr})->type('string')    # name starts with upper case 'E'
    );

    $self->{logger}->debug("loeschenKunde() epayblWebservicesUrl:$self->{epayblWebservicesUrl}: loeschenKundeRequest:" . Dumper($loeschenKundeRequest) . ":");
    my $response = eval {
        $self->{soap_request}->loeschenKunde( $loeschenKundeRequest );
    };
    $self->{logger}->debug("loeschenKunde() response:" . Dumper($response) . ":");

    if ( $@ ) {
        my $mess = "loeschenKunde() error when calling soap_request->loeschenKunde:$@:";
        $self->{logger}->error($mess);
        carp ($mess . "\n");
        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
        $retError = 41;
    }

    if ($response ) {
        if ( !$response->fault() ) {
            $self->{logger}->trace("loeschenKunde() response>result():" . Dumper($response->result()) . ":");
            $self->{logger}->debug("loeschenKunde() response>result()->{ergebnis}:" . Dumper($response->result()->{ergebnis}) . ":");
            $self->{logger}->debug("loeschenKunde() response>result()->{ergebnis}->{istOk}:" . Dumper($response->result()->{ergebnis}->{istOk}) . ":");
            if ( $response->result()
                 && defined( $response->result()->{ergebnis} )
                 && defined( $response->result()->{ergebnis}->{istOk} ) )
            {
                if ( $response->result()->{ergebnis}->{'istOk'} eq '1' ) {
                    $retLoeschenKundeIstOk = 1;
                } else {
                    $epayblmsg = $response->result()->{ergebnis}->{'kurzText'} . ' (' . $response->result()->{ergebnis}->{'langText'} . ')';
                }
            }

            if ( $retLoeschenKundeIstOk == 0 ) {
                $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                $retError = 42;
            }
        }    # End of: !$response->fault()
        else {
            $epayblmsg = $response->fault();
            $retErrorTemplate = 'EPAYBL_UNABLE_TO_CONNECT';
            $retError = 43;
        }
        if ( $epayblmsg ) {
            my $mess = "loeschenKunde() epayblmsg:" . $epayblmsg . ":";
            $self->{logger}->error($mess);
            carp ($mess . "\n");
        }
    }

    $self->{logger}->debug("loeschenKunde() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retLoeschenKundeIstOk:$retLoeschenKundeIstOk:");
    return ( $retError, $retErrorTemplate, $retLoeschenKundeIstOk );
}

# create URL for redirect to ePayBL paypage (requires the new kassenzeichen created by anlegenKassenzeichen)
sub createPaypageUrl {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $epayblRedirectToPaypageUrl = '';

    # these contents will be shown on paypage (example: SB Ingolstadt):
    # name: sent in anlegenKunde as vorname and nachname of $self->{patron}
    # authority: constant text defined by ePayBL (e.g. 'Buecherei')
    # invoice number: unique kassenzeichen created by anlegenKassenzeichen and then stored in $self->{angelegtesEpayblKassenzeichen} (e.g. '4200000000061')
    # amount (including currency): sent in anlegenKassenzeichen ($self->{amount_to_pay} and 'EUR')
    # due date: date-part of timestamp of payment initiation 

    $self->{logger}->debug("createPaypageUrl() START self->{angelegtesEpayblKassenzeichen}:$self->{angelegtesEpayblKassenzeichen}: self->{epayblEShopKundenNr}:$self->{epayblEShopKundenNr}:");

    if ( $self->{angelegtesEpayblKassenzeichen} ) {

        # notifyUrl is used to update accountlines ('pay' them) corresponding to the payment
        my $notifyUrl = URI->new( $self->{opac_base_url} . "/cgi-bin/koha/opac-account-pay-epaybl-return.pl" );
        $notifyUrl->query_form(
            {
                amountKoha => $self->{amount_to_pay},
                accountlinesKoha => $self->{accountlinesIds},
                borrowernumberKoha => $self->{patron}->borrowernumber(),
                paytypeKoha => $self->{paytype},
                result => 'paid',
                kassenzeichen => $self->{angelegtesEpayblKassenzeichen}
            }
        );

        # cancelUrl is used to send info to epaybl that user has aborted the payment action or that an error has happened
        my $cancelUrl = URI->new( $self->{opac_base_url} . "/cgi-bin/koha/opac-account-pay-epaybl-return.pl" );
        $cancelUrl->query_form(
            {
                amountKoha => $self->{amount_to_pay},
                accountlinesKoha => $self->{accountlinesIds},
                borrowernumberKoha => $self->{patron}->borrowernumber(),
                paytypeKoha => $self->{paytype},
                result => 'cancelled'
            }
        );

        $epayblRedirectToPaypageUrl = $self->{epayblPaypageUrl};
        $epayblRedirectToPaypageUrl .= '?mandant=' . $self->{epayblMandatorNumber};
        $epayblRedirectToPaypageUrl .= '&EShopKundenNr=' . $self->{epayblEShopKundenNr};
        $epayblRedirectToPaypageUrl .= '&kassenzeichen=' . $self->{angelegtesEpayblKassenzeichen};
        $epayblRedirectToPaypageUrl .= '&backlinkSuccess=' . uri_escape_utf8($notifyUrl->as_string());
        $epayblRedirectToPaypageUrl .= '&backlinkAbort=' . uri_escape_utf8($cancelUrl->as_string());
    } else {
        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
        $retError = 51;
    }

    $self->{logger}->debug("createPaypageUrl() returns retError:$retError: retErrorTemplate:$retErrorTemplate: epayblRedirectToPaypageUrl:$epayblRedirectToPaypageUrl:");
    return ( $retError, $retErrorTemplate, $epayblRedirectToPaypageUrl );
}

# verify payment by calling the webservice 'lesenKassenzeichenInfo', check hash values, and then 'pay' the accountlines in Koha
sub lesenKassenzeichenInfo {
    my $self = shift;
    my $cgi = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retLesenKassenzeichenInfoIstOk = 0;
    my $epayblmsg = '';
    my $epayblKassenzeichen = $cgi->param('kassenzeichen');
    my $paytypeKoha = $cgi->param('paytypeKoha');

    $self->{logger}->debug("lesenKassenzeichenInfo() START epayblKassenzeichen:$epayblKassenzeichen: paytypeKoha:$paytypeKoha: cgi:" . Dumper($cgi) . ":");

    # verify success of ePayBL paypage payment action
    my $lesenKassenzeichenInfoRequest = SOAP::Data->value(
        SOAP::Data->name('mandantNr' => $self->{epayblMandatorNumber})->type('string'),
        SOAP::Data->name('kassenzeichen' => $epayblKassenzeichen)->type('string')
    );

    my $kohaPaymentId;
    # read payment status until response.result.paypageStatus.code is equal 'INAKTIV' - but maximal for 7 seconds
    my $paymentStatusCode = 'undef';
    my $paymentBetrag = '';
    my $paymentEShopKundennummer = '';
    my $paymentKassenzeichen = '';
    my $paymentZahlverfahren = '';
    my $starttime = time();

    while ( time() < $starttime + 7 ) {
        $epayblmsg = '';
        $self->{logger}->debug("lesenKassenzeichenInfo() epayblWebservicesUrl:$self->{epayblWebservicesUrl}: lesenKassenzeichenInfoRequest:" . Dumper($lesenKassenzeichenInfoRequest) . ":");
        my $response = eval {
            $self->{soap_request}->lesenKassenzeichenInfo( $lesenKassenzeichenInfoRequest );
        };

        if ( $@ ) {
            my $mess = "lesenKassenzeichenInfo() error when calling soap_request->lesenKassenzeichenInfo:$@:";
            $self->{logger}->error($mess);
            carp ($mess . "\n");
            $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
            $retError = 610;
        }

        if ($response ) {
            $self->{logger}->trace("lesenKassenzeichenInfo() response>result():" . Dumper($response->result()) . ":");
            if ( !$response->fault() ) {
                $self->{logger}->debug("lesenKassenzeichenInfo() response>result()->{ergebnis}:" . Dumper($response->result()->{ergebnis}) . ":");
                $self->{logger}->debug("lesenKassenzeichenInfo() response>result()->{ergebnis}->{istOk}:" . Dumper($response->result()->{ergebnis}->{istOk}) . ":");
                if ( $response->result()
                     && defined( $response->result()->{ergebnis} )
                     && defined( $response->result()->{ergebnis}->{istOk} ) )
                {
                    if ( $response->result()->{ergebnis}->{'istOk'} eq '1' ) {
                        $retLesenKassenzeichenInfoIstOk = 1;    # the call of lesenKassenzeichen was ok, but not necessarily the payment itself
                        if ( $response->result()->{paypageStatus} ) {
                            $paymentStatusCode = $response->result()->{paypageStatus}->{code};
                            $paymentBetrag = $response->result()->{betragHauptforderungen};
                            $paymentEShopKundennummer = $response->result()->{EShopKundennummer};
                            $paymentKassenzeichen = $response->result()->{kassenzeichen};
                            $paymentZahlverfahren = $response->result()->{zahlverfahren};
                            if ( $paymentStatusCode eq 'INAKTIV' ) {
                                if ( $paymentKassenzeichen ne $epayblKassenzeichen ) {
                                    $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                                    $retError = 621;
                                    $epayblmsg = "paymentKassenzeichen:$paymentKassenzeichen: ne epayblKassenzeichen:$epayblKassenzeichen:";
                                    last;    # payment very suspicious, so we do NOT 'pay' the accountlines
                                }
                                $retErrorTemplate = '';
                                $retError = 0;
                                $epayblmsg = '';
                                last;    # looks good, we have to 'pay' the accountlines
                            }

                            $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                            $retError = 622;
                            $epayblmsg = "paymentStatusCode:$paymentStatusCode: ne 'INAKTIV'";
                        } else {
                            $paymentStatusCode = '';
                            $paymentBetrag = '';
                            $paymentEShopKundennummer = '';
                            $paymentKassenzeichen = '';
                            $paymentZahlverfahren = '';

                            $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                            $retError = 623;
                            $epayblmsg = 'paypageStatus ist nicht angegeben';
                        }
                    } else {
                        $retLesenKassenzeichenInfoIstOk = 0;
                        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                        $retError = 624;
                        $epayblmsg = $response->result()->{ergebnis}->{'kurzText'} . ' (' . $response->result()->{ergebnis}->{'langText'} . ')';
                    }
                }

                if ( $retLesenKassenzeichenInfoIstOk == 0 ) {
                    $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
                    $retError = 625;
                }
            }    # End of: !$response->fault()
            else {
                $epayblmsg = $response->fault();
                $retErrorTemplate = 'EPAYBL_UNABLE_TO_CONNECT';
                $retError = 626;
            }
            if ( $epayblmsg ) {
                my $mess = "lesenKassenzeichenInfoIstOk() epayblmsg:" . $epayblmsg . ":";
                $self->{logger}->error($mess);
                carp ($mess . "\n");
            }
            sleep(1);
        }
    }

    # check if hash values for the payment are identical to impede abuse of a correct kassenzeichen for another payment
    $self->{logger}->debug("lesenKassenzeichenInfo() paymentEShopKundennummer:" . Dumper($paymentEShopKundennummer) . ":");
    my ($paymentCardnumber, $paymentTimestamp, $paymentHashVal ) = split( /_/, $paymentEShopKundennummer );
    my $calculatedHashVal = $self->calculateHashVal();
    my $paymentIsDiffering = 0;
    $self->{logger}->debug("lesenKassenzeichenInfo() paymentCardnumber:$paymentCardnumber: self->{patron}->cardnumber():" . $self->{patron}->cardnumber() . ":");
    $self->{logger}->debug("lesenKassenzeichenInfo() paymentTimestamp:$paymentTimestamp: self->{timestamp}:$self->{timestamp}:");
    $self->{logger}->debug("lesenKassenzeichenInfo() paymentHashVal:$paymentHashVal: calculatedHashVal:$calculatedHashVal:");

    if ( ! defined( $paymentCardnumber ) || $paymentCardnumber ne $self->{patron}->cardnumber() ) {
        $paymentIsDiffering = 1;
        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
        $retError = 631;
        $epayblmsg .= ' Sent patron cardnumber (' . $self->{patron}->cardnumber() . ') is differing from patron cardnumber stored in ePayBL (' . ($paymentCardnumber?$paymentCardnumber:'undef') . ').';
    } elsif ( ! defined( $paymentTimestamp ) || $self->{timestamp} - $paymentTimestamp > 1000000000 ) {    # payment timestamp stored in ePayBL is older than current timestamp by more than 1 day
        $paymentIsDiffering = 2;
        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
        $retError = 632;
        $epayblmsg .= ' Current time (' . scalar $self->{timestamp} . ') is differing too much from timestamp stored in ePayBL (' . ($paymentTimestamp?$paymentTimestamp:'undef') . ').';
    } elsif ( ! defined( $paymentHashVal ) || $paymentHashVal ne $calculatedHashVal ) {
        $paymentIsDiffering = 3;
        $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
        $retError = 633;
        $epayblmsg .= ' Calculated transaction hash value (' . $calculatedHashVal . ') is differing from hash value stored in ePayBL (' . ($paymentHashVal?$paymentHashVal:'undef') . ').';
    }

    if (  $paymentStatusCode eq 'INAKTIV' &&
          $paymentKassenzeichen eq $epayblKassenzeichen &&
          ! $paymentIsDiffering ) {

        # Online payment action has succeeded and it seems that the URL is not manipulated,
        # so 'pay' the accountlines in Koha now.
        my $account = Koha::Account->new( { patron_id => $self->{patron}->borrowernumber() } );
        my @lines = Koha::Account::Lines->search(
            {
                accountlines_id => { -in => $self->{accountlinesIds} }
            }
        );

        my $sumAmountoutstanding = 0.0;
        foreach my $accountline ( @lines ) {
            $sumAmountoutstanding += $accountline->amountoutstanding();
        }
        $sumAmountoutstanding = sprintf( "%.2f", $sumAmountoutstanding );    # this rounding was also done in the complimentary opac-account-pay-pl

        if ( $sumAmountoutstanding == $self->{amount_to_pay} ) {

            my $descriptionText = 'Zahlung (ePayBL)';    # should always be overwritten
            my $noteText = "Online-Zahlung $paymentKassenzeichen";    # should always be overwritten
            if ( $paytypeKoha == 19 ) {    # all of paypage: giropay, paydirect, credit card, direct debit, ...
                if ( $paymentZahlverfahren ) {
                    $descriptionText = $paymentZahlverfahren . " (ePayBL)";
                    $noteText = "Online ($paymentZahlverfahren) $paymentKassenzeichen";
                } else {
                    $descriptionText = "Online-Zahlung (ePayBL)";
                    $noteText = "Online-Zahlung $paymentKassenzeichen";
                }
            }
            if ( $self->{epayblAccountingEntryText} ) {
                $noteText .= '/' . $self->{epayblAccountingEntryText};
            }
            $self->{logger}->debug("lesenKassenzeichenInfo() descriptionText:$descriptionText: noteText:$noteText:");

            # we take the borrowers branchcode also for the payment accountlines record to be created
            my $library_id = $self->{patron}->branchcode();
            $self->{logger}->debug("lesenKassenzeichenInfo() library_id:$library_id:");

            # evaluate configuration of cash register management for online payments
            # default: withoutCashRegisterManagement = 1; (i.e. avoiding cash register management in Koha::Account->pay())
            # default: onlinePaymentCashRegisterManagerId = 0;: borrowernumber of manager of cash register for online payments
            my ( $withoutCashRegisterManagement, $onlinePaymentCashRegisterManagerId ) = $self->getEpaymentCashRegisterManagement();
            
            $kohaPaymentId = $account->pay(
                {
                    amount => $self->{amount_to_pay},
                    lines => \@lines,
                    library_id => $library_id,
                    description => $descriptionText,
                    note => $noteText,
                    withoutCashRegisterManagement => $withoutCashRegisterManagement,
                    onlinePaymentCashRegisterManagerId => $onlinePaymentCashRegisterManagerId
                }
            );
        } else {
            $epayblmsg = "NOT calling account->pay! sumAmountoutstanding (=$sumAmountoutstanding) != amount_to_pay (=$self->{amount_to_pay})";
        }
    }

    if ( $kohaPaymentId ) {
        $retErrorTemplate = '';
        $retError = 0;
        $epayblmsg = '';
    } else {
        if (  $paymentStatusCode eq 'INAKTIV' && $paymentKassenzeichen eq $epayblKassenzeichen ) {
            $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
            $retError = 641;
            $epayblmsg .= ' Error in account->pay()';
        } else {
            $retErrorTemplate = 'EPAYBL_ERROR_PROCESSING';
            $retError = 642;
            $epayblmsg .= ' Online payment has not been confirmed by ePayBL within 7 seconds.';
        }
    }

    if ( $epayblmsg ) {
        my $mess = "lesenKassenzeichenInfo() epayblmsg:" . $epayblmsg . ":";
        $self->{logger}->error($mess);
        carp ("EPayBLPaypage::" . $mess . "\n");
    }

    $self->{logger}->debug("lesenKassenzeichenInfo() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retLesenKassenzeichenInfoIstOk:$retLesenKassenzeichenInfoIstOk:");
    return ( $retError, $retErrorTemplate, $retLesenKassenzeichenInfoIstOk );
}

# call the webservices 'isAlive', 'anlegenKunde', 'anlegenKassenzeichen', 'loeschenKunde' and then, if succeeded, redirect to ePayBL paypage URL
sub paymentAction {
    my $self = shift;
    my $retError = 0;
    my $retErrorTemplate = '';
    my $retEpayblRedirectToPaypageUrl = '';
    my $isAliveIstOk = 0;
    my $anlegenKundeIstOk = 0;
    my $anlegenKassenzeichenIstOk = 0;
    my $loeschenKundeIstOk = 0;

    $self->{logger}->debug("paymentAction() START");

    if ( $retError == 0 ) {
        # 1. step: call the webservice 'isAlive' (check if ePayBL server responds to webservice requests)
        ( $retError, $retErrorTemplate, $isAliveIstOk ) = $self->isAlive();
    }

    if ( $retError == 0 && $isAliveIstOk ) {
        # 2. step: call the webservice 'anlegenKunde' (create ePayBL pseudo customer having number EShopKundenNr, that is used only once, only for this payment action)
        ( $retError, $retErrorTemplate, $anlegenKundeIstOk ) = $self->anlegenKunde();
    }

    if ( $retError == 0 && $anlegenKundeIstOk ) {
        # 3. step: call the webservices 'anlegenKassenzeichen' (if successful this will create a new kassenzeichen, required for createPaypageUrl() ) 
        ( $retError, $retErrorTemplate, $anlegenKassenzeichenIstOk ) = $self->anlegenKassenzeichen();
    }

    if ( $isAliveIstOk && $anlegenKundeIstOk ) {
        # 4. step: call the webservices 'loeschenKunde' (delete pseudo ePayBL customer having number EShopKundenNr)
        my $errorLoeschenKunde = 0;    # failure of loeschenKunde will deliberately be ignored
        my $errorTemplateLoeschenKunde = '';    # failure of loeschenKunde will deliberately be ignored
        ( $errorLoeschenKunde, $errorTemplateLoeschenKunde, $loeschenKundeIstOk ) = $self->loeschenKunde();
    }

    if ( $retError == 0 && $anlegenKassenzeichenIstOk ) {
        # 5. step: create ePayBL paypage URL used later for redirect (requires the new kassenzeichen created by anlegenKassenzeichen)
        ( $retError, $retErrorTemplate, $retEpayblRedirectToPaypageUrl ) = $self->createPaypageUrl();
    }

    $self->{logger}->debug("paymentAction() returns retError:$retError: retErrorTemplate:$retErrorTemplate: retEpayblRedirectToPaypageUrl:$retEpayblRedirectToPaypageUrl:");
    return ( $retError, $retErrorTemplate, $retEpayblRedirectToPaypageUrl );
}

1;
