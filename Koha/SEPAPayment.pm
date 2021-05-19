package Koha::SEPAPayment;

# Copyright 2020-2021 (C) LMSCLoud GmbH
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

use Modern::Perl;
use XML::Writer;
use XML::LibXML;
use utf8;
use Text::Unidecode;
use Data::Dumper;

use C4::Context;
use C4::Log;
use C4::Members;
use Koha::Database;
use Koha::DateUtils;
use Koha::Patrons;
use Koha::Account;

my ( @ISA, @EXPORT, @EXPORT_OK );

BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    push @EXPORT, qw(
        &renewMembershipForSepaDirectDebitPatrons
        &paySelectedFeesForSepaDirectDebitPatrons
        &getErrorMsg
    );
}

binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

sub new {
    my $class = shift;
    my $verbose = shift;
    my $lettercode = shift;
    my $nomail = shift;

    print STDERR "Koha::SEPAPayment::new() START Dumper(class):" . Dumper($class) . ":\n" if $verbose > 1;

    my $self  = {};
    bless $self, $class;
    $self->{verbose} = $verbose;
    $self->{nomail} = $nomail;    # for development and debugging only (do not enqueue letter but print its content to STDOUT)
    $self->{sepaSysPrefs} = {};
    $self->{errorMsg} = $self->checkSepaDirectDebitConfiguration();
    $self->{lettercode} = '';    # default: generate no notification
    $self->{lettercode} = $self->{sepaSysPrefs}->{SepaDirectDebitBorrowerNoticeLettercode} if $self->{sepaSysPrefs}->{SepaDirectDebitBorrowerNoticeLettercode};
    $self->{lettercode} = $lettercode if $lettercode;    # If function parameter $lettercode is set, it will override the entry read from system preference 'SepaDirectDebitBorrowerNoticeLettercode'.

    $self->{cashRegisterConfig} = $self->readCashRegisterConfiguration();
    #print STDERR "Koha::SEPAPayment::new() self->{cashRegisterConfig}:" . Dumper($self->{cashRegisterConfig}) . ":\n" if $self->{verbose} > 1;
    if ( $self->{cashRegisterConfig}->{withoutCashRegisterManagement} == 0 && $self->{cashRegisterConfig}->{cashRegisterNeedsToBeOpened} ) {    # required cash register is not opened
        $self->{errorMsg} .= "Invalid cash register configuration for SEPA direct debit. ( cash register name:" .
            ($self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterName}?$self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterName}:'undef') .
            ": manager cardnumber:" .
            ($self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterManagerCardnumber}?$self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterManagerCardnumber}:'undef') .
            ":)";
    }

    # create filename for payment instruction XML output
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    my $century02 = sprintf("%02d", ($year+1900)/100);
    my $year02 = sprintf("%02d", ($year+1900)%100);
    my $month02 = sprintf("%02d", $mon+1);
    my $mday02 = sprintf("%02d", $mday);
    my $outputfilename = $self->{sepaSysPrefs}->{SepaDirectDebitPaymentInstructionFileName};
    $outputfilename =~ s/<<cc>>/$century02/;
    $outputfilename =~ s/<<yy>>/$year02/;
    $outputfilename =~ s/<<mm>>/$month02/;
    $outputfilename =~ s/<<dd>>/$mday02/;
    my $outputdir = C4::Context->config('outputdownloaddir');
    $outputdir = File::Spec->catpath( "", $outputdir, "batchprint" );
    $self->{paymentInstructionFileName} = File::Spec->catdir( $outputdir, $outputfilename );
    # If no payment instructions exist for this run then signal this by adding '_no_payment_instructions.xml' to the file name.
    $self->{paymentInstructionFileNameNoTransactions} = $self->{paymentInstructionFileName} . '_no_payment_instructions.xml';
    # Error file for logging invalid BIC and IBAN entries. This file is not created if paySelectedFeesForSepaDirectDebitPatrons() encountered no such invalid entries.
    $self->{paymentInstructionErrorFileName} = $self->{paymentInstructionFileName} . '_Fehler.html';
    # check if file for payment instruction output of this day already exists
    if ( -e $self->{paymentInstructionFileName} || -e $self->{paymentInstructionFileNameNoTransactions} ) {
        $self->{errorMsg} .= "Payment instruction output file:" . $self->{paymentInstructionFileName} . "* already exists. ";
    }

    $self->{inKohaPaid} = {};
    $self->{inKohaNotPaid} = {};

    print STDERR "Koha::SEPAPayment::new() self->{errorMsg}:" . $self->{errorMsg} . ":\n" if $self->{verbose} > 1;
    print STDERR "Koha::SEPAPayment::new() self->{sepaSysPrefs}:" . Dumper($self->{sepaSysPrefs}) . ":\n" if $self->{verbose} > 1;
    print STDERR "Koha::SEPAPayment::new() self->{paymentInstructionFileName}:" . $self->{paymentInstructionFileName} . ":\n" if $self->{verbose} > 1;

    return $self;
}

sub checkSepaDirectDebitConfiguration {
    my $self = shift;
    my $configError = '';
    print STDERR "Koha::SEPAPayment::checkSepaDirectDebitConfiguration() START\n" if $self->{verbose} > 1;

    my @sepaSysPrefRecords = ( 
        { variable => 'SepaDirectDebitCreditorBic', mandatory => 1 },               # e.g. 'GENODEF1NDR'
        { variable => 'SepaDirectDebitCreditorIban', mandatory => 1 },              # e.g. 'DE90200691119999999999'
        { variable => 'SepaDirectDebitCreditorId', mandatory => 1 },                # e.g. 'DE09stb00000099999'
        { variable => 'SepaDirectDebitCreditorName', mandatory => 1 },              # e.g. 'Stadtbuecherei Norderstedt' (max. length 27/35/70 chars according to different specifications)
        { variable => 'SepaDirectDebitInitiatingPartyName', mandatory => 1 },       # e.g. 'STADTBUECHEREI NORDERSTEDT'
        { variable => 'SepaDirectDebitMessageIdHeader', mandatory => 0 },           # e.g. 'Lastschrift Stadtbuecherei-' (current date will be appended in form yyyymmdd)
        { variable => 'SepaDirectDebitRemittanceInfo', mandatory => 1 },            # e.g. 'Jahresentgelt' (max. length 140 chars)
        { variable => 'SepaDirectDebitBorrowerNoticeLettercode', mandatory => 0 },  # e.g. 'SEPA_NOTE_CHARGE'. Value '' or undef indicates that the library has deactivated the notification.
        { variable => 'SepaDirectDebitAccountTypes', mandatory => 1 },              # e.g. 'A|M|F'
        { variable => 'SepaDirectDebitMinFeeSum', mandatory => 0 },                 # e.g. '5.00'. Value '' or undef results in default value 0.01.
        { variable => 'SepaDirectDebitLocalInstrumentCode', mandatory => 1 },       # e.g. 'CORE'. 'COR1'.'B2B' (CORE = SEPA Basis-Lastschrift (Verbraucher); COR1 entspricht CORE, jedoch mit auf 1 Bankarbeitstag reduzierter Bearbeitungszeit)
        { variable => 'SepaDirectDebitPaymentInstructionFileName', mandatory => 1 } # e.g. 'pain.008.<<cc>><<yy>><<mm>><<dd>>.xml'

    );

    $self->{sepaSysPrefs} = {};
    foreach my $sepaSysPrefRecord ( @sepaSysPrefRecords ) {
        $self->{sepaSysPrefs}->{$sepaSysPrefRecord->{variable}} = C4::Context->preference($sepaSysPrefRecord->{variable});
        print STDERR "Koha::SEPAPayment::checkSepaDirectDebitConfiguration() self->{sepaSysPrefs}->{" . $sepaSysPrefRecord->{variable} . "}:" . $self->{sepaSysPrefs}->{$sepaSysPrefRecord->{variable}} . ":\n" if $self->{verbose} > 1;

        if ( $sepaSysPrefRecord->{mandatory} ) {
            if ( ! $self->{sepaSysPrefs}->{$sepaSysPrefRecord->{variable}} ) {
                $configError .= "System preference:" . $sepaSysPrefRecord->{variable} . ": is not set. "
            }
        }
    }
    print STDERR "Koha::SEPAPayment::checkSepaDirectDebitConfiguration() returns configError:$configError:\n" if $self->{verbose} > 1;
    return $configError;
}

sub readCashRegisterConfiguration {
    my $self = shift;

    my $cashRegisterConfig = {};
    print STDERR "Koha::SEPAPayment::readCashRegisterConfiguration() START\n" if $self->{verbose} > 1;

    # evaluate configuration of cash register management for SEPA direct debit payments
    $cashRegisterConfig->{withoutCashRegisterManagement} = 1;    # default: avoiding cash register management in Koha::Account->pay()
    $cashRegisterConfig->{cashRegisterNeedsToBeOpened} = 0;
    $cashRegisterConfig->{cash_register_manager_id} = '';    # borrowernumber of manager of cash register for SEPA direct debit payments

    if ( C4::Context->preference("ActivateCashRegisterTransactionsOnly") ) {
        $cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterName} = C4::Context->preference('SepaDirectDebitCashRegisterName');
        $cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterManagerCardnumber} = C4::Context->preference('SepaDirectDebitCashRegisterManagerCardnumber');
        print STDERR "Koha::SEPAPayment::readCashRegisterConfiguration() paymentsSepaDirectDebitCashRegisterName:" . 
            (defined($cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterName})?$cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterName}:'undef') . 
            ": paymentsSepaDirectDebitCashRegisterManagerCardnumber:" . 
            (defined($cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterManagerCardnumber})?$cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterManagerCardnumber}:'undef') . 
            ":\n" if $self->{verbose} > 1;

        if ( length($cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterName}) || length($cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterManagerCardnumber}) ) {
            $cashRegisterConfig->{withoutCashRegisterManagement} = 0;
            $cashRegisterConfig->{cashRegisterNeedsToBeOpened} = 1;

            # get cash register manager information
            $cashRegisterConfig->{cash_register_manager} = Koha::Patrons->search( { cardnumber => $cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterManagerCardnumber} } )->next();
            if ( $cashRegisterConfig->{cash_register_manager} ) {
                $cashRegisterConfig->{cash_register_manager_id} = $cashRegisterConfig->{cash_register_manager}->borrowernumber();
                $cashRegisterConfig->{cash_register_manager_branchcode} = $cashRegisterConfig->{cash_register_manager}->branchcode();
                print STDERR "Koha::SEPAPayment::readCashRegisterConfiguration() cash_register_manager_id:" . 
                    (defined($cashRegisterConfig->{cash_register_manager_id})?$cashRegisterConfig->{cash_register_manager_id}:'undef') . 
                    ": cash_register_manager_branchcode:" . 
                    (defined($cashRegisterConfig->{cash_register_manager_branchcode})?$cashRegisterConfig->{cash_register_manager_branchcode}:'undef') . 
                    ":\n" if $self->{verbose} > 1;

                $cashRegisterConfig->{cash_register_mngmt} = C4::CashRegisterManagement->new($cashRegisterConfig->{cash_register_manager_branchcode}, $cashRegisterConfig->{cash_register_manager_id});

                if ( $cashRegisterConfig->{cash_register_mngmt} ) {
                    my $openedCashRegister = $cashRegisterConfig->{cash_register_mngmt}->getOpenedCashRegisterByManagerID($cashRegisterConfig->{cash_register_manager_id});
                    if ( defined $openedCashRegister ) {
                        print STDERR "Koha::SEPAPayment::readCashRegisterConfiguration() opened cash_register_name:" . 
                            (defined($openedCashRegister->{'cash_register_name'})?$openedCashRegister->{'cash_register_name'}:'undef') . 
                            ":\n" if $self->{verbose} > 1;

                        if ($openedCashRegister->{'cash_register_name'} eq $cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterName}) {
                            $cashRegisterConfig->{cashRegisterNeedsToBeOpened} = 0;
                            $cashRegisterConfig->{cash_register_id} = $openedCashRegister->{'cash_register_id'}
                        } else {
                            $cashRegisterConfig->{cash_register_mngmt}->closeCashRegister($openedCashRegister->{'cash_register_id'}, $cashRegisterConfig->{cash_register_manager_id});
                        }
                    }
                    if ( $cashRegisterConfig->{cashRegisterNeedsToBeOpened} ) {
                        # try to open the specified cash register by name
                        $cashRegisterConfig->{cash_register_id} = $cashRegisterConfig->{cash_register_mngmt}->readCashRegisterIdByName($cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterName});
                        print STDERR "Koha::SEPAPayment::readCashRegisterConfiguration() cash_register_id:" . 
                            (defined($cashRegisterConfig->{cash_register_id})?$cashRegisterConfig->{cash_register_id}:'undef') . 
                            ":" if $self->{verbose} > 1;

                        if ( defined $cashRegisterConfig->{cash_register_id} && $cashRegisterConfig->{cash_register_mngmt}->canOpenCashRegister($cashRegisterConfig->{cash_register_id}, $cashRegisterConfig->{cash_register_manager_id}) ) {
                            my $opened = $cashRegisterConfig->{cash_register_mngmt}->openCashRegister($cashRegisterConfig->{cash_register_id}, $cashRegisterConfig->{cash_register_manager_id});
                            if ( $opened ) {    # 0/1
                                $cashRegisterConfig->{cashRegisterNeedsToBeOpened} = 0;
                            }
                            print STDERR "Koha::SEPAPayment::readCashRegisterConfiguration() cash_register_mngmt->openCashRegister(" . 
                                $cashRegisterConfig->{cash_register_manager_branchcode} . 
                                ", " . 
                                $cashRegisterConfig->{cash_register_manager_id} . 
                                ") returned opened:$opened:\n" if $self->{verbose} > 1;
                        } else {
                            my $mess = "Koha::SEPAPayment::readCashRegisterConfiguration(): error when trying to open cash register paymentsSepaDirectDebitCashRegisterName:$cashRegisterConfig->{paymentsSepaDirectDebitCashRegisterName}:";
                            print STDERR "Koha::SEPAPayment::readCashRegisterConfiguration() error:" . $mess . ":\n";
                            warn $mess . "\n";
                        }
                    }
                }
            }
        }
    }
    return $cashRegisterConfig;
}

sub getErrorMsg {
    my $self = shift;
    print STDERR "Koha::SEPAPayment::getErrorMsg() returns errorMsg:" . (defined($self->{errorMsg})?$self->{errorMsg}:'undef') . ":\n" if $self->{verbose} > 1;

    return $self->{errorMsg};
}

sub updateResultHash {
    my $self = shift;
    my $resultHashName = shift;
    my $currentFeeHit = shift;

    my $currentHitBorrowernumber = $currentFeeHit->{borrowers}->{borrowernumber};

    if ( ! defined($self->{$resultHashName}->{$currentHitBorrowernumber}) ) {
        $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesSumAmountoutstanding} = 0.0;
        $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesCount} = 0;
        $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesMinId} = 0;
    }

    # borrowersKey: 'borrowernumber', 'surname', 'firstname', 'cardnumber', 'branchcode'
    foreach my $borrowersKey ( sort keys %{$currentFeeHit->{borrowers}} ) {
        $self->{$resultHashName}->{$currentHitBorrowernumber}->{borrowers}->{$borrowersKey} = $currentFeeHit->{borrowers}->{$borrowersKey};
    }

    # accountlines keys: all selected accountlines.accountlines_id with corresponding amountoutstanding and accounttype
    my $currentHitAccountlinesId = $currentFeeHit->{accountlines}->{accountlines_id};
    $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlines}->{$currentHitAccountlinesId}->{accountlines_id} = $currentFeeHit->{accountlines}->{accountlines_id};
    $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlines}->{$currentHitAccountlinesId}->{accounttype} = $currentFeeHit->{accountlines}->{accounttype};
    $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlines}->{$currentHitAccountlinesId}->{amountoutstanding} = $currentFeeHit->{accountlines}->{amountoutstanding};
    # accountlines helper keys: 'accountlinesSumAmountoutstanding', 'accountlinesCount', 'accountlinesMinId', and later 'accountlinesKohaPaymentId'
    $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesSumAmountoutstanding} += $currentFeeHit->{accountlines}->{amountoutstanding};
    $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesCount} += 1;
    if ( $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesMinId} == 0 ||
         $currentFeeHit->{accountlines}->{accountlines_id} < $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesMinId} ) {
         $self->{$resultHashName}->{$currentHitBorrowernumber}->{accountlinesMinId} = $currentFeeHit->{accountlines}->{accountlines_id};
    }

    # borrowerAttributesKey: 'SEPA_BIC', 'SEPA_IBAN', 'SEPA_Sign', 'Konto_von'
    foreach my $borrowerAttributesKey ( sort keys %{$currentFeeHit->{borrower_attributes}} ) {
        $self->{$resultHashName}->{$currentHitBorrowernumber}->{borrower_attributes}->{$borrowerAttributesKey} = $currentFeeHit->{borrower_attributes}->{$borrowerAttributesKey};
    }

}

sub renewMembershipForSepaDirectDebitPatrons {
    my $self = shift;
    my ( $params ) = @_;

    my $expiryAfterDays = $params->{expiryAfterDays} || 0;
    my $expiryBeforeDays  = $params->{expiryBeforeDays} || 14;

    print STDERR "Koha::SEPAPayment::renewMembershipForSepaDirectDebitPatrons() START expiryAfterDays:" . (defined($expiryAfterDays)?$expiryAfterDays:'undef') . ": expiryBeforeDays:" . (defined($expiryBeforeDays)?$expiryBeforeDays:'undef') . ":\n" if $self->{verbose} > 1;
    delete $params->{expiryAfterDays};
    delete $params->{expiryBeforeDays};

    my $dateFrom = dt_from_string->add( days => $expiryAfterDays );
    my $dateUntil = dt_from_string->add( days => $expiryBeforeDays );
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $renewMembershipCount = 0;
    my $renewedMembershipCount = 0;

    print STDERR "Koha::SEPAPayment::renewMembershipForSepaDirectDebitPatrons dateFrom:" . $dateFrom . ": dateUntil:" . $dateUntil . ":\n" if $self->{verbose} > 1;
    $params->{'dateexpiry'} = {
        ">=" => $dtf->format_date( $dateFrom ),
        "<=" => $dtf->format_date( $dateUntil ),
    };

    $params->{'borrower_attributes.code'} = {
        "=" => 'SEPA'
    };
    $params->{'borrower_attributes.attribute'} = {
        "=" => '1'
    };


    print STDERR "Koha::SEPAPayment::renewMembershipForSepaDirectDebitPatrons() is calling patrons->search() params:" . Dumper($params) . ":\n" if $self->{verbose} > 1;
    my $patrons = Koha::Patrons->new();
    my $patronsRS = $patrons->search(
        $params,
        { join => ['borrower_attributes'],
          prefetch => 'borrower_attributes'
        }
    );
    print STDERR "Koha::SEPAPayment::renewMembershipForSepaDirectDebitPatrons() patronsRS.count:" . $patronsRS->count . ":\n" if $self->{verbose} > 0;

    $patronsRS->reset();

    while (my $patronHit = $patronsRS->next() ) {

        C4::Context->_new_userenv('');

        C4::Context->set_userenv(
            $patronHit->borrowernumber,
            $patronHit->userid,
            $patronHit->cardnumber,
            $patronHit->firstname,
            $patronHit->surname,
            $patronHit->branchcode,
            '',    # branchname
            $patronHit->flags,
            $patronHit->email,
            undef,    # branchprinter
            undef,    # shibboleth
            ''    # branchcategory,
        );

        print STDERR "Koha::SEPAPayment::renewMembershipForSepaDirectDebitPatrons calls renew_account for borrowernumber:" . $patronHit->borrowernumber . ": with branchcode:" . $patronHit->branchcode . ": C4::Context->userenv->{'branch'}:" . C4::Context->userenv->{'branch'} . ":\n" if $self->{verbose} > 1;
        my $olddateexpiry = $patronHit->dateexpiry;
        my $newdateexpiry = $patronHit->renew_account;
        print STDERR "Koha::SEPAPayment::renewMembershipForSepaDirectDebitPatrons renew_account for borrowernumber:" . $patronHit->borrowernumber . ": (categorycode:" . $patronHit->categorycode . ": old dateexpiry:" . $olddateexpiry . ":) has returned new dateexpiry:" . (defined($newdateexpiry)?output_pref( { 'dt' => $newdateexpiry, dateformat => 'iso', dateonly => 1 } ):'undef') . ":\n" if $self->{verbose} > 0;
        $renewMembershipCount += 1;
        if ( defined($newdateexpiry) && ( output_pref( { 'dt' => $newdateexpiry, dateformat => 'iso', dateonly => 1 } ) ne $olddateexpiry ) ) {
            $renewedMembershipCount += 1;
        }
    }

    print STDERR "Koha::SEPAPayment::renewMembershipForSepaDirectDebitPatrons returns renewMembershipCount:$renewMembershipCount: renewedMembershipCount:$renewedMembershipCount:\n" if $self->{verbose} > 0;
    return ( $renewMembershipCount, $renewedMembershipCount);
}

sub paySelectedFeesForSepaDirectDebitPatrons {
    my $self = shift;
    my ( $params ) = @_;

    my $sepaDirectDebitDelayDays  = $params->{sepaDirectDebitDelayDays} || 14;
    my $requestedCollectionDate = dt_from_string->add( days => $sepaDirectDebitDelayDays );    # date the direct debit will be booked by the bank in the borrowers bank account

    print STDERR "Koha::SEPAPayment::paySelectedFeesForSepaDirectDebitPatrons() START params->{sepaDirectDebitDelayDays}:" . $params->{sepaDirectDebitDelayDays} . ": requestedCollectionDate:" . $requestedCollectionDate . ":\n" if $self->{verbose} > 1;

    delete $params->{sepaDirectDebitDelayDays};
    my $dbh = C4::Context->dbh;
    $dbh->{AutoCommit} = 0;
    my $success = 1;

    # providing selection for branchcode
    my $branchSelect = '';
    if ( $params->{branchcode} ) {
        $branchSelect = " AND b.branchcode = '$params->{branchcode}' ";
    }

    # providing selection for accounttype
    my $accountTypesSel = 'A';    # In the first version of SEPA direct debit payment only membership fees (accounttype = 'A') had to be handled.
    my $sepaDirectDebitAccountTypes = $self->{sepaSysPrefs}->{SepaDirectDebitAccountTypes};
    print STDERR "Koha::SEPAPayment::paySelectedFeesForSepaDirectDebitPatrons() sepaDirectDebitAccountTypes:" . $sepaDirectDebitAccountTypes . ":\n" if $self->{verbose} > 1;
    if ( $sepaDirectDebitAccountTypes ) {
        $accountTypesSel = '';    # In the second version of SEPA direct debit payment all accounttypes of interest have to be configured. (e.g. 'A|M|F')
        my @accountTypes = split(/\|/, $sepaDirectDebitAccountTypes);
        foreach my $accountType (@accountTypes) {
            if ( $accountTypesSel ) {
                $accountTypesSel .= ",";
            }
            $accountTypesSel .= "'" . $accountType . "'";
        }
    }

    # providing selection for sum(amountoutstanding) threshold per borrower
    my $minSumAmountoutstanding = 0.01;
    my $sepaDirectDebitMinFeeSum = $self->{sepaSysPrefs}->{SepaDirectDebitMinFeeSum};
    if ( defined($sepaDirectDebitMinFeeSum) && $sepaDirectDebitMinFeeSum + 0.00 >= 0.01 ) {
        $minSumAmountoutstanding = $sepaDirectDebitMinFeeSum + 0.00;
    }

    my $selectStatement = "
        SELECT
            b.borrowernumber as 'b.borrowernumber',
            b.surname as 'b.surname',
            b.firstname as 'b.firstname',
            b.cardnumber as 'b.cardnumber',
            b.branchcode as 'b.branchcode',
            a.accountlines_id AS 'a.accountlines_id',
            a.amountoutstanding AS 'a.amountoutstanding',
            a.accounttype AS 'a.accounttype',
            ba.code as 'ba.code',
            ba.attribute as 'ba.attribute'

        FROM borrowers b
        JOIN accountlines a ON ( a.borrowernumber = b.borrowernumber )
        JOIN borrower_attributes ba_sepa ON ( ba_sepa.borrowernumber = b.borrowernumber AND ba_sepa.code = 'SEPA' AND ba_sepa.attribute = '1' )
        LEFT JOIN borrower_attributes ba ON ( ba.borrowernumber = b.borrowernumber AND ba.code IN ('SEPA_BIC', 'SEPA_IBAN', 'SEPA_Sign', 'Konto_von') )

        WHERE a.accounttype IN ($accountTypesSel)
          AND a.amountoutstanding >= 0.01
          $branchSelect
          AND EXISTS (
                SELECT al2.borrowernumber, sum(al2.amountoutstanding)
                FROM accountlines al2
                WHERE al2.borrowernumber = a.borrowernumber
                  AND al2.amountoutstanding >= 0.01
                GROUP BY al2.borrowernumber
                HAVING SUM( al2.amountoutstanding ) >= $minSumAmountoutstanding
              )

        ORDER BY
            b.borrowernumber,
            a.accountlines_id,
            ba.code

    ";

    print STDERR "Koha::SEPAPayment::paySelectedFeesForSepaDirectDebitPatrons() selectStatement:$selectStatement:\n" if $self->{verbose} > 1;

    my $sth = $dbh->prepare( $selectStatement );
    $sth->execute() or die $dbh->errstr;

    my $currentFeeHit = {};
    while ( my $openFee = $sth->fetchrow_hashref ) {
        print STDERR "Koha::SEPAPayment::paySelectedFeesForSepaDirectDebitPatrons() Dumper(openFee):" . Dumper($openFee) . ":\n" if $self->{verbose} > 1;

        if ( ! defined($currentFeeHit->{accountlines}->{accountlines_id}) ||
             $currentFeeHit->{accountlines}->{accountlines_id} != $openFee->{'a.accountlines_id'} ) {
            # start of entries of NEXT open fee hit (i.e. different accountlines_id, but maybe of same borrower)
            if ( defined($currentFeeHit->{accountlines}->{accountlines_id}) ) {
                # accumulate CURRENT open fee hit (for the same accountlines_id there exist different hits representing the different borrower_attributes)
                $self->updateResultHash('inKohaSelected',$currentFeeHit);
            }

            # init borrower's CURRENT fee hit hash with values of NEXT open fee (so it becomes the CURRENT one)
            $currentFeeHit = {};
            $currentFeeHit->{borrowers}->{borrowernumber} = $openFee->{'b.borrowernumber'};
            $currentFeeHit->{borrowers}->{surname} = $openFee->{'b.surname'};
            $currentFeeHit->{borrowers}->{firstname} = $openFee->{'b.firstname'};
            $currentFeeHit->{borrowers}->{cardnumber} = $openFee->{'b.cardnumber'};
            $currentFeeHit->{borrowers}->{branchcode} = $openFee->{'b.branchcode'};
            $currentFeeHit->{accountlines}->{accountlines_id} = $openFee->{'a.accountlines_id'};
            $currentFeeHit->{accountlines}->{amountoutstanding} = $openFee->{'a.amountoutstanding'};
            $currentFeeHit->{accountlines}->{accounttype} = $openFee->{'a.accounttype'};
            $currentFeeHit->{borrower_attributes}->{$openFee->{'ba.code'}} = $openFee->{'ba.attribute'};
        } else {
            # ad further borrower attribute to CURRENT fee hit hash
            $currentFeeHit->{borrower_attributes}->{$openFee->{'ba.code'}} = $openFee->{'ba.attribute'};
        }
    }
    if ( defined($currentFeeHit->{accountlines}->{accountlines_id}) ) {

        # handle last fee hit
        $self->updateResultHash('inKohaSelected',$currentFeeHit);
    }

    # try to pay in Koha the selected accumulated fees per borrower
    # if payment suceeded: write SEPA notice message for this borrower into DB table message_queue if required
    foreach my $borrowernumber ( sort keys %{$self->{inKohaSelected}} ) {
        my $kohaPaymentId = $self->paySelectedFeesOfPatron($self->{inKohaSelected}->{$borrowernumber}, $requestedCollectionDate);

        $self->{inKohaSelected}->{$borrowernumber}->{accountlinesKohaPaymentId} = $kohaPaymentId;    # value 0 indicates failed creation of accountlines record for payment
        if ( $self->{inKohaSelected}->{$borrowernumber}->{accountlinesKohaPaymentId} ) {
            $self->{inKohaPaid}->{$borrowernumber} = $self->{inKohaSelected}->{$borrowernumber};

            if ( $self->{lettercode} ) {
                # create notice for borrower informing about the upcoming SEPA direct debit
                $success = $self->printSepaNotice($self->{inKohaPaid}->{$borrowernumber});
            }
        } else {
            $self->{inKohaNotPaid}->{$borrowernumber} = $self->{inKohaSelected}->{$borrowernumber};
        }
        if ( !$success ) {
            last;
        }
    }

    # If there are invalid IBANs etc. then log this in the error file. If no errors exist, the error file will not be created.
    $self->writeSepaDirectDebitErrorFile();

    # if sucess: create the SEPA payment instruction file
    if ( $success ) {
        $success = $self->writeSepaDirectDebitFile($requestedCollectionDate);
    }

    # we roll back all actions if borrower notice fails fundamentally
    if ( $success ) {
        $dbh->commit();
    } else {
        $dbh->rollback();
    }
    $dbh->{AutoCommit} = 1;
    print STDERR "Koha::SEPAPayment::paySelectedFeesForSepaDirectDebitPatrons() returns success:$success:\n" if $self->{verbose} > 1;

    return $success;
}

sub paySelectedFeesOfPatron {
    my $self = shift;
    my ($borrowersSelectedFees, $requestedCollectionDate) = @_;

    my $kohaPaymentId = 0;
    print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() accountlines count:" . $borrowersSelectedFees->{accountlinesCount} . ": sumAmountoutstanding:" . $borrowersSelectedFees->{accountlinesSumAmountoutstanding} . ": requestedCollectionDate:" . $requestedCollectionDate . ":\n" if $self->{verbose} > 1;

    my $selectedAccountlinesIds = '';
    my @selectedAccountlinesIdsArray = ();
    foreach my $selectedAccountlinesId ( sort keys %{$borrowersSelectedFees->{accountlines}} ) {
        if ( length( $selectedAccountlinesIds ) > 0 ) {
            $selectedAccountlinesIds .= ',';
        }
        $selectedAccountlinesIds .= $selectedAccountlinesId;
        push @selectedAccountlinesIdsArray, $selectedAccountlinesId;
    }

    # check if required info is set
    my $ibanOk = $self->checkIban($borrowersSelectedFees);
    my $bicOk = $self->checkBic($borrowersSelectedFees);
    my $signOk = 1;    # $self->checkSign($borrowersSelectedFees);    # wei 10.06.2020: no checks of SEPA signature, please!

    if ( $ibanOk &&
         $bicOk &&
         $signOk &&
         length( $selectedAccountlinesIds ) > 0 &&
         scalar @selectedAccountlinesIdsArray > 0 &&
         $borrowersSelectedFees->{accountlinesCount} > 0 ) {

        # now 'pay' the accountlines representing the selected fees
        my $selParam = { accountlines_id => { '-IN' => \@selectedAccountlinesIdsArray } };
        print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() Dumper(selParam):" . Dumper($selParam) . ":\n" if $self->{verbose} > 1;

        my @lines = Koha::Account::Lines->search( $selParam );
        #print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() Dumper(lines):" . Dumper(\@lines) . ":\n" if $self->{verbose} > 1;

        if ( $lines[0] ) {
            for ( my $i = 0; $i < scalar @lines; $i += 1 ) {
                print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() Dumper(lines[$i]->{_result}->{_column_data}):" . Dumper($lines[$i]->{_result}->{_column_data}) . ":\n" if $self->{verbose} > 1;
            }
            my $descriptionText = 'Zahlung (SEPA Lastschrift)';
            my $noteText = output_pref( { 'dt' => $requestedCollectionDate, dateformat => 'iso', dateonly => 1 } );    # requested collection date (vorgesehenes Datum für Lastschrifteinzug)
            print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() noteText:" . $noteText . ":\n" if $self->{verbose} > 1;

            my $account = Koha::Account->new( { patron_id => $borrowersSelectedFees->{borrowers}->{borrowernumber} } );
            $kohaPaymentId = $account->pay(
                {
                    amount => $borrowersSelectedFees->{accountlinesSumAmountoutstanding},
                    lines => \@lines,
                    library_id => $borrowersSelectedFees->{borrowers}->{branchcode},    # we take the borrowers branchcode also for the payment accountlines record to be created
                    description => $descriptionText,
                    note => $noteText,
                    withoutCashRegisterManagement => $self->{cashRegisterConfig}->{withoutCashRegisterManagement},
                    onlinePaymentCashRegisterManagerId => $self->{cashRegisterConfig}->{cash_register_manager_id}
                }
            );
        }
    }
    if ( $kohaPaymentId ) {
        print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() direct debit payment of selected fees for borrower:" .
            $borrowersSelectedFees->{borrowers}->{borrowernumber} .
            ": amount:" .
            $borrowersSelectedFees->{accountlinesSumAmountoutstanding} .
            ": count:" .
            $borrowersSelectedFees->{accountlinesCount} .
            ": fees accountlines_ids:" .
            $selectedAccountlinesIds .
            ": pay accountlines_id:" .
            $kohaPaymentId .
            ": succeeded.\n" if $self->{verbose} > 0;
    } else {
        print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() error: direct debit payment of selected fees for borrower:" .
            $borrowersSelectedFees->{borrowers}->{borrowernumber} .
            ": amount:" .
            $borrowersSelectedFees->{accountlinesSumAmountoutstanding} .
            ": count:" .
            $borrowersSelectedFees->{accountlinesCount} .
            ": fees accountlines_ids:" .
            $selectedAccountlinesIds .
            ": failed.\n";

        my $errormsg = sprintf('Betrag:%.2f: der Gebühr(en):%s: konnte in Koha nicht bezahlt werden', $borrowersSelectedFees->{accountlinesSumAmountoutstanding}, $selectedAccountlinesIds);
        push @{$borrowersSelectedFees->{errormsg}}, $errormsg;
    }
    print STDERR "Koha::SEPAPayment::paySelectedFeesOfPatron() returns kohaPaymentId:" . ($kohaPaymentId?$kohaPaymentId:'undef') . ":\n" if $self->{verbose} > 1;
    return $kohaPaymentId;
}

sub checkIban {
    my $self = shift;
    my ($borrowersSelectedFees) = @_;
    my $ret = 0;

    print STDERR "Koha::SEPAPayment::checkIban() START\n" if $self->{verbose} > 1;
    if( ! ( defined($borrowersSelectedFees->{borrower_attributes}) && defined($borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN}) ) ) {
        print STDERR "Koha::SEPAPayment::checkIban() IBAN not defined (borrower:" . $borrowersSelectedFees->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
        my $errormsg = 'IBAN ist nicht definiert';
        push @{$borrowersSelectedFees->{errormsg}}, $errormsg;
    } else {
        $borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN} =~ s/[\s,\r,\n]//g;
        my $countryCode = '';
        my $checkSum = '';
        my $basicBankAccountNumber = '';
        if ( $borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN} =~ /^([A-Z]{2}).*$/ ) {
            $countryCode = $1;
        }
        if ( $borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN} =~ /^..(\d\d).*$/ ) {
            $checkSum = $1;
        }
        if ( $borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN} =~ /^....(.*)$/ ) {
            $basicBankAccountNumber = $1;    # remainder: so called 'BBAN'
        }
        print STDERR "Koha::SEPAPayment::checkIban() SEPA_IBAN:" . (defined($borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN})?$borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN}:'undef') .
                                                ": countryCode:" . (defined($countryCode)?$countryCode:'undef') .
                                                   ": checkSum:" . (defined($checkSum)?$checkSum:'undef') .
                                                       ": BBAN:" . (defined($basicBankAccountNumber)?$basicBankAccountNumber:'undef') .
                                                           ":\n" if $self->{verbose} > 1;
        if ( length($countryCode) != 2 ||
             length($checkSum) != 2 ||
             ( $countryCode eq 'DE' && length($basicBankAccountNumber) != 18 ) ||
             ( $countryCode eq 'AT' && length($basicBankAccountNumber) != 16 ) ||
             ( $countryCode eq 'BE' && length($basicBankAccountNumber) != 12 ) ||
             ( $countryCode eq 'LU' && length($basicBankAccountNumber) != 16 ) ||
             ( $countryCode eq 'FR' && length($basicBankAccountNumber) != 23 ) ||
             (                         length($basicBankAccountNumber) < 11 )
           ) {
            print STDERR "Koha::SEPAPayment::checkIban() invalid IBAN:" . $borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN} . ": (borrower:" . $borrowersSelectedFees->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
            my $errormsg = sprintf('IBAN:%s: ist fehlerhaft', $borrowersSelectedFees->{borrower_attributes}->{SEPA_IBAN});
            push @{$borrowersSelectedFees->{errormsg}}, $errormsg;
        } else {
            $ret = 1;
        }
    }
    return $ret;
}

sub checkBic {
    my $self = shift;
    my ($borrowersSelectedFees) = @_;
    my $ret = 0;

    print STDERR "Koha::SEPAPayment::checkBic() START\n" if $self->{verbose} > 1;
    if( ! ( defined($borrowersSelectedFees->{borrower_attributes}) && defined($borrowersSelectedFees->{borrower_attributes}->{SEPA_BIC}) ) ) {
        print STDERR "Koha::SEPAPayment::checkBic() BIC not defined (borrower:" . $borrowersSelectedFees->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
        my $errormsg = 'BIC ist nicht definiert';
        push @{$borrowersSelectedFees->{errormsg}}, $errormsg;
    } else {
        $borrowersSelectedFees->{borrower_attributes}->{SEPA_BIC} =~ s/[\s,\r,\n]//g;
        if ( ! ( length($borrowersSelectedFees->{borrower_attributes}->{SEPA_BIC}) == 8 || length($borrowersSelectedFees->{borrower_attributes}->{SEPA_BIC}) == 11 ) ) {
            print STDERR "Koha::SEPAPayment::checkBic() invalid BIC:" . $borrowersSelectedFees->{borrower_attributes}->{SEPA_BIC} . ": (borrower:" . $borrowersSelectedFees->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
            my $errormsg = sprintf('BIC:%s: ist fehlerhaft', $borrowersSelectedFees->{borrower_attributes}->{SEPA_BIC});
            push @{$borrowersSelectedFees->{errormsg}}, $errormsg;
        } else {
            $ret = 1;
        }
    }
    return $ret;
}

sub printSepaNotice {
    my $self = shift;
    my ($borrowersPaidFees) = @_;

    my $ret = 0;
    my $borrowernumber = $borrowersPaidFees->{borrowers}->{borrowernumber};
    my $patron = Koha::Patrons->find( $borrowernumber );
    my $branchcode = $patron->branchcode;
    my $library = Koha::Libraries->find( $branchcode )->unblessed;
    my $adminEmailAddress = $library->{branchemail} || C4::Context->preference('KohaAdminEmailAddress');
    my $noticeFees = C4::NoticeFees->new();

    print STDERR "Koha::SEPAPayment::printSepaNotice() START branchcode:$branchcode: borrowernumber:$borrowernumber: letter_code:$self->{lettercode}:\n" if $self->{verbose} > 1;
    # Try to get the borrower's email address
    my $to_address = $patron->notice_email_address;

    # Try to read the first selected fee record
    my $accountlines = Koha::Account::Lines->new();
    my $accountlineFee0 = $accountlines->find( { accountlines_id => $borrowersPaidFees->{accountlinesMinId} } );
    #print STDERR "Koha::SEPAPayment::printSepaNotice() accountlineFee->unblessed:" . Dumper($accountlineFee0->unblessed) . ":\n" if $self->{verbose} > 1;
    # Try to read the new payment record
    my $accountlinePayment = $accountlines->find( { accountlines_id => $borrowersPaidFees->{accountlinesKohaPaymentId} } );
    #print STDERR "Koha::SEPAPayment::printSepaNotice() accountlinePayment->unblessed:" . Dumper($accountlinePayment->unblessed) . ":\n" if $self->{verbose} > 1;

    my %letter_params = (
        module => 'members',
        branchcode => $branchcode,
        lang => $patron->lang,
        tables => {
            'branches'        => $library,
            'borrowers'       => $patron->unblessed,
            'accountlinesFee' => $accountlineFee0->unblessed,
            'accountlinesPayment' => $accountlinePayment->unblessed,
        },
    );


    my $send_notification = sub {
        my ( $mtt, $borrowernumber, $letter_code ) = @_;
        if ( ! defined($letter_code) ) {
            warn "Koha::SEPAPayment::printSepaNotice(): Error: letter code is not set";
            return 0;
        }

        $letter_params{letter_code} = $letter_code;
        $letter_params{message_transport_type} = $mtt;
        my $letter =  C4::Letters::GetPreparedLetter ( %letter_params );
        unless ($letter) {
            warn "Koha::SEPAPayment::printSepaNotice(): Could not find a letter called '$letter_params{'letter_code'}' for $mtt in the '$letter_params{'module'}' module";
            return 0;
        }
        #print STDERR "Koha::SEPAPayment::printSepaNotice() Dumper letter:" . Dumper($letter) . ":\n"  if $self->{verbose} > 1;

        if ( $self->{nomail} ) {    # for development and debugging only
            print $letter->{'content'} . "\n";
        } else {
            C4::Letters::EnqueueLetter( {
                letter => $letter,
                borrowernumber => $borrowernumber,
                from_address => $adminEmailAddress,
                message_transport_type => $mtt,
                branchcode => $branchcode
            } );

            # check whether there are notice fee rules defined
            if ( $noticeFees->checkForNoticeFeeRules() == 1 ) {
                #check whether there is a matching notice fee rule
                my $noticeFeeRule = $noticeFees->getNoticeFeeRule($letter_params{branchcode}, $patron->categorycode, $mtt, $letter_code);

                if ( $noticeFeeRule ) {
                    my $noticeFee = $noticeFeeRule->notice_fee();
                    
                    if ( $noticeFee && $noticeFee > 0.0 ) {
                        # Bad for the patron, staff has assigned a notice fee for sending the notification
                         $noticeFees->AddNoticeFee( 
                            {
                                borrowernumber => $borrowernumber,
                                amount         => $noticeFee,
                                letter_code    => $letter_code,
                                letter_date    => output_pref( { dt => dt_from_string, dateonly => 1 } ),
                                
                                # these are parameters that we need for fancy message printing
                                branchcode     => $letter_params{branchcode},
                                substitute     => { bib     => $library->{branchname}, 
                                                    'count' => 1,
                                                  },
                                tables        =>  $letter_params{tables}
                                
                             }
                         );
                    }
                }
            }
        }
        return 1;
    };

    if ( $to_address ) {
        $ret = &$send_notification('email', $borrowernumber, $self->{lettercode});
    } else {
        $ret = &$send_notification('print', $borrowernumber, $self->{lettercode});
    }
    print STDERR "Koha::SEPAPayment::printSepaNotice() returns ret:$ret:\n" if $self->{verbose} > 1;
    return $ret;
}

sub writeSepaDirectDebitErrorFile {
    my $self = shift;
    my $errormessages = '';

    foreach my $borrowernumber ( sort keys %{$self->{inKohaSelected}} ) {
        if ( exists($self->{inKohaSelected}->{$borrowernumber}->{errormsg}) && defined($self->{inKohaSelected}->{$borrowernumber}->{errormsg}) ) {
            my $errormsgcount = scalar @{$self->{inKohaSelected}->{$borrowernumber}->{errormsg}};
            if ( $errormsgcount > 0 ) {
                my $errormessageborrower = '';
                for ( my $i = 0; $i < $errormsgcount; $i += 1 ) {
                    my $mess = sprintf("Ausweis:%s: %s  <br>\n", $self->{inKohaSelected}->{$borrowernumber}->{borrowers}->{cardnumber}, $self->{inKohaSelected}->{$borrowernumber}->{errormsg}->[$i]);
                    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitErrorFile() mess:$mess:\n" if $self->{verbose} > 1;
                    $errormessageborrower .= $mess;
                }
                if ( length($errormessageborrower) > 0 ) {
                    $errormessages .= "<p>\n" . $errormessageborrower . "</p>\n";
                }
            }
        }
    }
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitErrorFile() errormessages:" . $errormessages . ":\n" if $self->{verbose} > 1;

    if ( length($errormessages) > 0 ) {
        # Create a error output file to indicate problems.
        my $fileWriteSccess = 0;
        my $paymentInstructionErrorFileName = $self->{paymentInstructionErrorFileName};

        print STDERR "Koha::SEPAPayment::writeSepaDirectDebitErrorFile() will now open error output file:" . $paymentInstructionErrorFileName . ": for writing\n" if $self->{verbose} > 1;
        my $fh;
        my $res = open $fh, ">:encoding(UTF-8)", $paymentInstructionErrorFileName;
        print STDERR "Koha::SEPAPayment::writeSepaDirectDebitErrorFile() tried to open error output file:" . $paymentInstructionErrorFileName . ": fh:$fh: res:" . (defined($res)?$res:'undef') . ":\n" if $self->{verbose} > 1;
        if ( $res ) {
            my $errorheaderline = sprintf("<h3>Fehlerprotokoll SEPA-Lauf vom %s Uhr </h3>\n", DateTime->now( time_zone => C4::Context->tz() )->strftime('%d.%m.%Y %H:%M:%S') );
            $res = print $fh $errorheaderline . $errormessages;
            close $fh;
            print STDERR "Koha::SEPAPayment::writeSepaDirectDebitErrorFile() tried to write to error output file:" . $paymentInstructionErrorFileName . ": res:" . (defined($res)?$res:'undef') . ":\n" if $self->{verbose} > 1;
            if ( $res ) {
                print STDERR "Koha::SEPAPayment::writeSepaDirectDebitErrorFile() error output file:" . $paymentInstructionErrorFileName . ": has been written\n" if $self->{verbose} > 1;
                $fileWriteSccess = 1;
            }
        }
        if ( ! $fileWriteSccess ) {
            print STDERR "Koha::SEPAPayment::writeSepaDirectDebitErrorFile() error output file:" . $paymentInstructionErrorFileName . ": has NOT been written. ( \$!:$!: )\n";
        }
    }
}

sub writeSepaDirectDebitFile {
    my $self = shift;
    my ($requestedCollectionDate) = @_;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    my $msgId = sprintf("%s%04d%02d%02d", $self->{sepaSysPrefs}->{SepaDirectDebitMessageIdHeader}, $year+1900, $mon+1, $mday);
    my $creDtTm = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    my $reqdColltnDt = output_pref( { 'dt' => $requestedCollectionDate, dateformat => 'iso', dateonly => 1 } );    # requested collection date (vorgesehenes Datum für Lastschrifteinzug)
    my $remittanceInfo = sprintf("%-.140s", $self->{sepaSysPrefs}->{SepaDirectDebitRemittanceInfo});
    my $success = 0;
    my $ctrlSum = 0.0;
    my $directDebitsCount = 0;    # we send only 1 <PmtInf> block, so <CstmrDrctDbtInitn><PmtInf><NbOfTxs> == <CstmrDrctDbtInitn><GrpHdr><NbOfTxs> == $directDebitsCount

    foreach my $borrowernumber ( sort keys %{$self->{inKohaPaid}} ) {
        $ctrlSum += (sprintf("%.2f",$self->{inKohaPaid}->{$borrowernumber}->{accountlinesSumAmountoutstanding}) + 0.0);
        $directDebitsCount += 1;
    }
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile(requestedCollectionDate:$requestedCollectionDate) START directDebitsCount:" . $directDebitsCount . ": ctrlSum:" . $ctrlSum . ":\n" if $self->{verbose} > 1;

    my $xmlwriter = XML::Writer->new(OUTPUT => 'self', NEWLINES => 0, DATA_MODE => 1, DATA_INDENT => 2, ENCODING => 'utf-8' );

    $xmlwriter->xmlDecl("UTF-8");
    $xmlwriter->startTag(   'Document',                                                             # root element 'Document'
                                'xmlns' => 'urn:iso:std:iso:20022:tech:xsd:pain.008.003.02',
                                'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                'xsi:schemaLocation' => 'urn:iso:std:iso:20022:tech:xsd:pain.008.003.02 pain.008.003.02.xsd');
    $xmlwriter->startTag(     'CstmrDrctDbtInitn');                                                 # CustomerDirectDebitInitialization

    $xmlwriter->startTag(       'GrpHdr');                                                          # GroupHeader
    $xmlwriter->dataElement(      'MsgId' => $msgId);                                               # MessageId
    $xmlwriter->dataElement(      'CreDtTm' => $creDtTm);                                           # CreationDateTime
    $xmlwriter->dataElement(      'NbOfTxs' => $directDebitsCount);                                     # NumberOfTransactions
    $xmlwriter->startTag(         'InitgPty');                                                      # InitiatingParty
    $xmlwriter->dataElement(        'Nm' => $self->{sepaSysPrefs}->{SepaDirectDebitInitiatingPartyName});   # InitiatingParty.Name
    $xmlwriter->endTag(           'InitgPty');
    $xmlwriter->endTag(         'GrpHdr');

    $xmlwriter->startTag(       'PmtInf');                                                          # PaymentInformation
    $xmlwriter->dataElement(      'PmtInfId' => $self->{sepaSysPrefs}->{SepaDirectDebitCreditorIban});  # PaymentInformationID (wie can use the IBAN for this field)
    $xmlwriter->dataElement(      'PmtMtd' => 'DD');                                                # PaymentMethod ('DD' = direct debit)
    $xmlwriter->dataElement(      'NbOfTxs' => $directDebitsCount);                                  # NumberOfTransactions
    $xmlwriter->dataElement(      'CtrlSum' => sprintf("%.2f",$ctrlSum));                           # ControlSum

    $xmlwriter->startTag(         'PmtTpInf');                                                      # PaymentTypeInformation
    $xmlwriter->startTag(           'SvcLvl');                                                      # ServiceLevel
    $xmlwriter->dataElement(          'Cd' => 'SEPA');                                              # ServiceLevel.Code
    $xmlwriter->endTag(             'SvcLvl');
    $xmlwriter->startTag(           'LclInstrm');                                                   # LocalInstrument
    $xmlwriter->dataElement(          'Cd' => $self->{sepaSysPrefs}->{SepaDirectDebitLocalInstrumentCode}); # LocalInstrument.Code (CORE, COR1, B2B) (CORE und COR1: SEPA Basis-Lastschrift (Verbraucher))
    $xmlwriter->endTag(             'LclInstrm');
    $xmlwriter->dataElement(        'SeqTp' => 'FRST');                                             # SequenceType (FRST, RCUR, OOFF, FNAL)
    $xmlwriter->endTag(           'PmtTpInf');

    $xmlwriter->dataElement(      'ReqdColltnDt' => $reqdColltnDt);                                 # RequestedCollectionDate

    $xmlwriter->startTag(         'Cdtr');                                                          # Creditor
    $xmlwriter->dataElement(        'Nm' => $self->{sepaSysPrefs}->{SepaDirectDebitCreditorName});  # Creditor.Name
    $xmlwriter->endTag(           'Cdtr');

    $xmlwriter->startTag(         'CdtrAcct');                                                      # CreditorAccount
    $xmlwriter->startTag(           'Id');                                                          # CreditorAccount.Id
    $xmlwriter->dataElement(          'IBAN' => $self->{sepaSysPrefs}->{SepaDirectDebitCreditorIban});  # CreditorAccount.Id.IBAN
    $xmlwriter->endTag(             'Id');
    $xmlwriter->endTag(           'CdtrAcct');

    $xmlwriter->startTag(         'CdtrAgt');                                                       # CreditorAgent
    $xmlwriter->startTag(           'FinInstnId');                                                  # FinancialInstitutionIdentification
    $xmlwriter->dataElement(          'BIC' => $self->{sepaSysPrefs}->{SepaDirectDebitCreditorBic});# FinancialInstitutionIdentification.BIC
    $xmlwriter->endTag(             'FinInstnId');
    $xmlwriter->endTag(           'CdtrAgt');

    $xmlwriter->dataElement(      'ChrgBr' => 'SLEV');                                              # ChargeBearer (SLEV = 'Preisverrechnung shared' (Kostenteilung))

    $xmlwriter->startTag(         'CdtrSchmeId');                                                   # CreditorIdentification (Gläubiger-Identifikationsnummer)
    $xmlwriter->startTag(           'Id');                                                          # CreditorIdentification.ID
    $xmlwriter->startTag(             'PrvtId');                                                    # CreditorIdentification.ID.PrivateID
    $xmlwriter->startTag(               'Othr');                                                    # CreditorIdentification.ID.PrivateID.Other
    $xmlwriter->dataElement(              'Id' => $self->{sepaSysPrefs}->{SepaDirectDebitCreditorId});  # CreditorIdentification.ID.PrivateID.Other.ID (Gläubiger-Identifikationsnummer)
    $xmlwriter->startTag(                 'SchmeNm');                                               # CreditorIdentification.ID.PrivateID.Other.SchemeName
    $xmlwriter->dataElement(                'Prtry' => 'SEPA');                                     # CreditorIdentification.ID.PrivateID.Other.SchemeName.Proprietary
    $xmlwriter->endTag(                   'SchmeNm');
    $xmlwriter->endTag(                 'Othr');
    $xmlwriter->endTag(               'PrvtId');
    $xmlwriter->endTag(             'Id');
    $xmlwriter->endTag(           'CdtrSchmeId');

    # now add the valid transactions
    foreach my $borrowernumber ( sort keys %{$self->{inKohaPaid}} ) {
        my $borrFeesPaid = $self->{inKohaPaid}->{$borrowernumber};
        my $debtorName = $self->debtorName( $borrFeesPaid->{borrowers}->{surname}, $borrFeesPaid->{borrowers}->{firstname} );    # default initialization, resulting in surname, firstname
        if ( defined( $borrFeesPaid->{borrower_attributes}->{Konto_von} ) && length( $borrFeesPaid->{borrower_attributes}->{Konto_von} ) > 0 ) {
            $debtorName = $self->debtorName( $borrFeesPaid->{borrower_attributes}->{Konto_von}, undef );    # if set, use borrower attribute having code 'Konto_von' as debtor name
        }
        my $dateOfSignature = $borrFeesPaid->{borrower_attributes}->{SEPA_Sign};
        $dateOfSignature = sprintf("%04d-%02d-%02d",$year+1900, $mon+1, $mday);    # there may be invalid entries in $borrFeesPaid->{borrower_attributes}->{SEPA_Sign}, so we ignore it and use today date

        $xmlwriter->startTag(     'DrctDbtTxInf');                                                  # DirectDebitTransactionInformation
        $xmlwriter->startTag(       'PmtId');                                                       # PaymentID
        $xmlwriter->dataElement(      'EndToEndId' => 'NOTPROVIDED');                               # PaymentID.EndToEndId (from the viewpoint of the initiator)
        $xmlwriter->endTag(         'PmtId');

        $xmlwriter->dataElement(    'InstdAmt', sprintf("%.2f",$borrFeesPaid->{accountlinesSumAmountoutstanding}), 'Ccy' => 'EUR'); # InstructedAmount (in currency 'EUR')

        $xmlwriter->startTag(       'DrctDbtTx');                                                   # DirectDebitTransaction
        $xmlwriter->startTag(         'MndtRltdInf');                                               # MandateRelatedInformation
        $xmlwriter->dataElement(        'MndtId' => $borrFeesPaid->{borrowers}->{cardnumber});      # MandateID
        $xmlwriter->dataElement(        'DtOfSgntr' => $dateOfSignature);                           # DateOfSignature in format yyyy-mm-dd
        $xmlwriter->dataElement(        'AmdmntInd' => 'false');                                    # AmendmentIndicator
        $xmlwriter->endTag(           'MndtRltdInf');
        $xmlwriter->endTag(         'DrctDbtTx');

        $xmlwriter->startTag(       'DbtrAgt');                                                     # DebtorAgent
        $xmlwriter->startTag(         'FinInstnId');                                                # FinancialInstitutionIdentification
        $xmlwriter->dataElement(        'BIC' => $borrFeesPaid->{borrower_attributes}->{SEPA_BIC}); # FinancialInstitutionIdentification.BIC
        $xmlwriter->endTag(           'FinInstnId');
        $xmlwriter->endTag(         'DbtrAgt');

        $xmlwriter->startTag(       'Dbtr');                                                        # Debtor
        $xmlwriter->dataElement(        'Nm' => sprintf("%-.70s",$debtorName));                     # Debtor.Name (max. 70 chars)
        $xmlwriter->endTag(         'Dbtr');

        $xmlwriter->startTag(       'DbtrAcct');                                                    # DebtorAccount
        $xmlwriter->startTag(         'Id');                                                        # DebtorAccount.ID
        $xmlwriter->dataElement(        'IBAN' => $borrFeesPaid->{borrower_attributes}->{SEPA_IBAN}); # DebtorAccount.ID.IBAN
        $xmlwriter->endTag(           'Id');
        $xmlwriter->endTag(         'DbtrAcct');

        $xmlwriter->startTag(       'RmtInf');                                                      # RemittanceInfo (Verwendungszweck)
        $xmlwriter->dataElement(      'Ustrd' => $remittanceInfo);                                  # RemittanceInfo.Unstructured (max. 140 chars)
        $xmlwriter->endTag(         'RmtInf');
        $xmlwriter->endTag(       'DrctDbtTxInf');
    }

    $xmlwriter->endTag(         'PmtInf');
    $xmlwriter->endTag(       'CstmrDrctDbtInitn');
    $xmlwriter->endTag(     'Document');

    my $xmlContent = "";
    $xmlContent .= $xmlwriter->end();
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() xmlContent:" . $xmlContent . ":\n" if $self->{verbose} > 1;

    # one could check here the syntax of $xmlContent using the open source tool perfidia    # wei 10.06.2020: no checks, please!


    # Create a batch output file to indicate the success of the task.
    # If it contains 0 transactions then signal this by using a modified file name.
    my $paymentInstructionFileName = $self->{paymentInstructionFileName};
    if ( $directDebitsCount == 0 ) {
        $paymentInstructionFileName = $self->{paymentInstructionFileNameNoTransactions};
    }
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() will now open payment instruction output file:" . $paymentInstructionFileName . ": for writing\n" if $self->{verbose} > 1;
    my $fh;
    my $res = open $fh, ">:encoding(UTF-8)", $paymentInstructionFileName;
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() tried to open payment instruction output file:" . $paymentInstructionFileName . ": fh:$fh: res:" . (defined($res)?$res:'undef') . ":\n" if $self->{verbose} > 1;
    if ( $res ) {
        $res = print $fh $xmlContent;
        close $fh;
        print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() tried to write to payment instruction output file:" . $paymentInstructionFileName . ": res:" . (defined($res)?$res:'undef') . ":\n" if $self->{verbose} > 1;
        if ( $res ) {
            print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() payment instruction output file:" . $paymentInstructionFileName . ": has been written\n" if $self->{verbose} > 1;
            $success = 1;
        }
    }
    if ( ! $success ) {
        print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() payment instruction output file:" . $paymentInstructionFileName . ": has NOT been written. ( \$!:$!: )\n";
    }

    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() payment instruction output file:" . $paymentInstructionFileName . ": returns success:$success:\n" if $self->{verbose} > 1;
    return $success;
}

sub debtorName {
    my $self = shift;
    my ($surname, $firstname) = @_;
    my $debtorName = '';
    print STDERR "Koha::SEPAPayment::debtorName() START\n" if $self->{verbose} > 1;
    
    if ( $surname ) {
        $debtorName = uc(unidecode($surname));
        if ( $debtorName =~ /^\s*(.*?)\s*$/ ) {
            $debtorName = $1;
        }
    }
    if ( $firstname ) {
        my $debtorFirstName = uc(unidecode($firstname));
        if ( $debtorFirstName =~ /^\s*(.*?)\s*$/ ) {
            $debtorFirstName = $1;
        }
        if ( length($debtorName) > 0 ) {
            $debtorName .= ', ' . $debtorFirstName;
        } else {
            $debtorName = $debtorFirstName;
        }
    }

    print STDERR "Koha::SEPAPayment::debtorName() returns debtorName:$debtorName:\n" if $self->{verbose} > 1;
    return $debtorName;
}

1;
