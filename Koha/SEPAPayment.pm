package Koha::SEPAPayment;

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

use Modern::Perl;
use XML::Writer;
use XML::LibXML;
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
        &renewMembershipForSEPADebitPatrons
    );
}

sub new {
    my $class = shift;
    my $verbose = shift;
    my $lettercode = shift;
    my $nomail = shift;

    my $self  = {};
    bless $self, $class;
    $self->{verbose} = $verbose;
    $self->{nomail} = $nomail;    # for development and debugging only (do not enqueue letter but print its content to STDOUT)
    print STDERR "Koha::SEPAPayment::new() START Dumper(class):" . Dumper($class) . ":\n" if $self->{verbose} > 1;
    $self->{sepaSysPrefs} = {};
    $self->{errorMsg} = $self->checkSEPADebitConfiguration();
    $self->{lettercode} = 'MEMBERSHIP_SEPA_NOTE';    # default
    $self->{lettercode} = $self->{sepaSysPrefs}->{SepaDirectDebitBorrowerNoticeLettercode} if $self->{sepaSysPrefs}->{SepaDirectDebitBorrowerNoticeLettercode};
    $self->{lettercode} = $lettercode if $lettercode;

    $self->{cashRegisterConfig} = $self->readCashRegisterConfiguration();
    #print STDERR "Koha::SEPAPayment::new() self->{cashRegisterConfig}:" . Dumper($self->{cashRegisterConfig}) . ":\n" if $self->{verbose} > 1;
    if ( $self->{cashRegisterConfig}->{withoutCashRegisterManagement} == 0 && $self->{cashRegisterConfig}->{cashRegisterNeedsToBeOpened} ) {    # required cash register is not opened
        $self->{errorMsg} .= "Invalid cash register configuration for SEPA direct debit. ( cash register name:" .
            ($self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterName}?$self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterName}:'undef') .
            ": manager cardnumber:" .
            ($self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterManagerCardnumber}?$self->{cashRegisterConfig}->{paymentsSepaDirectDebitCashRegisterManagerCardnumber}:'undef') .
            ":)";
    }

    # create filename for XML output
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    my $printfilename = 'pain.008';
    #$printfilename .= sprintf("_%04d-%02d-%02d_%02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
    $printfilename .= sprintf(".%04d%02d%02d",$year+1900,$mon+1,$mday);
    $printfilename .= ".xml";
    my $outputdir = C4::Context->config('outputdownloaddir');
    $outputdir = File::Spec->catpath( "", $outputdir, "batchprint" );
    $self->{xmlfilename} = File::Spec->catdir( $outputdir, $printfilename );
    # check if file for XML output of this day already exists
    if ( -e $self->{xmlfilename} ) {
        $self->{errorMsg} .= "XML output file:" . $self->{xmlfilename} . " already exists. ";
    }

    $self->{membershipFeeHitsPaid} = [];
    $self->{membershipFeeHitsFailed} = [];

    print STDERR "Koha::SEPAPayment::new() self->{errorMsg}:" . $self->{errorMsg} . ":\n" if $self->{verbose} > 1;
    print STDERR "Koha::SEPAPayment::new() self->{sepaSysPrefs}:" . Dumper($self->{sepaSysPrefs}) . ":\n" if $self->{verbose} > 1;

    return $self;
}

sub checkSEPADebitConfiguration {
    my $self = shift;
    my $configError = '';
    print STDERR "Koha::SEPAPayment::checkSEPADebitConfiguration() START\n" if $self->{verbose} > 1;

    my @sepaSysPrefVariables = ( 
        'SepaDirectDebitCreditorBic',               # e.g. 'GENODEF1NDR'
        'SepaDirectDebitCreditorIban',              # e.g. 'DE90200691119999999999'
        'SepaDirectDebitCreditorId',                # e.g. 'DE09stb00000099999'
        'SepaDirectDebitCreditorName',              # e.g. 'Stadtbuecherei Norderstedt' (max. length 27/35/70 chars according to different specifications)
        'SepaDirectDebitInitiatingPartyName',       # e.g. 'STADTBUECHEREI NORDERSTEDT'
        'SepaDirectDebitMessageIdHeader',           # e.g. 'Lastschrift Stadtbuecherei-' (current date will be appended in form yyyymmdd)
        'SepaDirectDebitRemittanceInfo',            # e.g. 'Jahresentgelt' (max. length 140 chars)
        'SepaDirectDebitBorrowerNoticeLettercode'   # e.g. 'MEMBERSHIP_SEPA_NOTE'
    );

    $self->{sepaSysPrefs} = {};
    foreach my $sepaSysPrefVariable ( @sepaSysPrefVariables ) {
        $self->{sepaSysPrefs}->{$sepaSysPrefVariable} = C4::Context->preference($sepaSysPrefVariable);
        print STDERR "Koha::SEPAPayment::checkSEPADebitConfiguration() self->{sepaSysPrefs}->{$sepaSysPrefVariable}:$self->{sepaSysPrefs}->{$sepaSysPrefVariable}:\n" if $self->{verbose} > 1;

        if( ! $self->{sepaSysPrefs}->{$sepaSysPrefVariable} ) {
            $configError .= "System preference:$sepaSysPrefVariable: is not set. "
        }
    }
    print STDERR "Koha::SEPAPayment::checkSEPADebitConfiguration() returns configError:$configError:\n" if $self->{verbose} > 1;
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

sub renewMembershipForSEPADebitPatrons{
    my $self = shift;
    my ( $params ) = @_;

    my $expiryAfterDays = $params->{expiryAfterDays} || 0;
    my $expiryBeforeDays  = $params->{expiryBeforeDays} || 14;

    print STDERR "Koha::SEPAPayment::renewMembershipForSEPADebitPatrons() START expiryAfterDays:" . (defined($expiryAfterDays)?$expiryAfterDays:'undef') . ": expiryBeforeDays:" . (defined($expiryBeforeDays)?$expiryBeforeDays:'undef') . ":\n" if $self->{verbose} > 1;
    delete $params->{expiryAfterDays};
    delete $params->{expiryBeforeDays};

    my $dateFrom = dt_from_string->add( days => $expiryAfterDays );
    my $dateUntil = dt_from_string->add( days => $expiryBeforeDays );
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;

    print STDERR "Koha::SEPAPayment::renewMembershipForSEPADebitPatrons dateFrom:" . $dateFrom . ": dateUntil:" . $dateUntil . ":\n" if $self->{verbose} > 1;
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


    print STDERR "Koha::SEPAPayment::renewMembershipForSEPADebitPatrons() is calling patrons->search() params:" . Dumper($params) . ":\n" if $self->{verbose} > 1;
    my $patrons = Koha::Patrons->new();
    my $patronsRS = $patrons->search(
        $params,
        { join => ['borrower_attributes'],
          prefetch => 'borrower_attributes'
        }
    );
    print STDERR "Koha::SEPAPayment::renewMembershipForSEPADebitPatrons() patronsRS.count:" . $patronsRS->count . ":\n" if $self->{verbose} > 0;

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

        print STDERR "Koha::SEPAPayment::renewMembershipForSEPADebitPatrons calls renew_account for borrowernumber:" . $patronHit->borrowernumber . ": with branchcode:" . $patronHit->branchcode . ": C4::Context->userenv->{'branch'}:" . C4::Context->userenv->{'branch'} . ":\n" if $self->{verbose} > 1;
        my $olddateexpiry = $patronHit->dateexpiry;
        my $newdateexpiry = $patronHit->renew_account;
        print STDERR "Koha::SEPAPayment::renewMembershipForSEPADebitPatrons renew_account for borrowernumber:" . $patronHit->borrowernumber . ": (categorycode:" . $patronHit->categorycode . ": old dateexpiry:" . $olddateexpiry . ":) has returned new dateexpiry:" . (defined($newdateexpiry)?output_pref( { 'dt' => $newdateexpiry, dateformat => 'iso', dateonly => 1 } ):'undef') . ":\n" if $self->{verbose} > 0;
    }

    return $patronsRS;
}

sub payMembershipFeesForSEPADebitPatrons {
    my $self = shift;
    my ( $params ) = @_;

    my $sepaDirectDebitDelayDays  = $params->{sepaDirectDebitDelayDays} || 14;
    my $dateSepaDirectDebit = dt_from_string->add( days => $sepaDirectDebitDelayDays );

    print STDERR "Koha::SEPAPayment::payMembershipFeesForSEPADebitPatrons() START params->{sepaDirectDebitDelayDays}:" . $params->{sepaDirectDebitDelayDays} . ": dateSepaDirectDebit:" . $dateSepaDirectDebit . ":\n" if $self->{verbose} > 1;

    delete $params->{sepaDirectDebitDelayDays};
    my $dbh = C4::Context->dbh;
    $dbh->{AutoCommit} = 0;
    my $success = 1;
    my $branchSelect = '';

    if ( $params->{branchcode} ) {
        $branchSelect = " AND b.branchcode = '$params->{branchcode}' ";
    }
    my $sth = $dbh->prepare(
        "
            SELECT
                b.borrowernumber as 'b.borrowernumber',
                b.surname as 'b.surname',
                b.firstname as 'b.firstname',
                b.cardnumber as 'b.cardnumber',
                b.branchcode as 'b.branchcode',
                a.accountlines_id AS 'a.accountlines_id',
                a.amountoutstanding AS 'a.amountoutstanding',
                ba.code as 'ba.code',
                ba.attribute as 'ba.attribute'

            FROM borrowers b
            JOIN accountlines a ON ( a.borrowernumber = b.borrowernumber )
            JOIN borrower_attributes ba_sepa ON ( ba_sepa.borrowernumber = b.borrowernumber AND ba_sepa.code = 'SEPA' AND ba_sepa.attribute = '1' )
            LEFT JOIN borrower_attributes ba ON ( ba.borrowernumber = b.borrowernumber AND ba.code IN ('SEPA_BIC', 'SEPA_IBAN', 'SEPA_Sign') )

            WHERE a.accounttype = 'A'
              AND a.amountoutstanding >= 0.01
              $branchSelect

            ORDER BY
                b.borrowernumber,
                a.accountlines_id,
                ba.code
                
        "
    );
    $sth->execute() or die $dbh->errstr;

    my $membershipFeeHit = {};
    while ( $success && (my $openMembershipFee  = $sth->fetchrow_hashref) ) {
        print STDERR "Koha::SEPAPayment::payMembershipFeesForSEPADebitPatrons() Dumper(openMembershipFee):" . Dumper($openMembershipFee) . ":\n" if $self->{verbose} > 1;

        if ( ! defined($membershipFeeHit->{accountlines}->{accountlines_id}) || $membershipFeeHit->{accountlines}->{accountlines_id} != $openMembershipFee->{'a.accountlines_id'} ) {
            # start of entries of next open membership fee hit (maybe of same borrower)
            if ( defined($membershipFeeHit->{accountlines}->{accountlines_id}) ) {
                # handle payment of current open membership fee hit
                my $kohaPaymentId = $self->payMembershipFee($membershipFeeHit, $dateSepaDirectDebit);

                $membershipFeeHit->{kohaPaymentId} = $kohaPaymentId;    # value 0 indicates failed creation of accountlines record for payment
                if ( $membershipFeeHit->{kohaPaymentId} ) {
                    push @{$self->{membershipFeeHitsPaid}}, $membershipFeeHit;
                    # create notice for borrower informing about the upcoming SEPA direct debit
                    $success = $self->printSepaNotice($membershipFeeHit);
                } else {
                    push @{$self->{membershipFeeHitsFailed}}, $membershipFeeHit;
                }
            }
            # init borrower's membership fee hit hash
            $membershipFeeHit = {};
            $membershipFeeHit->{borrowers}->{borrowernumber} = $openMembershipFee->{'b.borrowernumber'};
            $membershipFeeHit->{borrowers}->{surname} = $openMembershipFee->{'b.surname'};
            $membershipFeeHit->{borrowers}->{firstname} = $openMembershipFee->{'b.firstname'};
            $membershipFeeHit->{borrowers}->{cardnumber} = $openMembershipFee->{'b.cardnumber'};
            $membershipFeeHit->{borrowers}->{branchcode} = $openMembershipFee->{'b.branchcode'};
            $membershipFeeHit->{accountlines}->{accountlines_id} = $openMembershipFee->{'a.accountlines_id'};
            $membershipFeeHit->{accountlines}->{amountoutstanding} = $openMembershipFee->{'a.amountoutstanding'};
            $membershipFeeHit->{attributes}->{$openMembershipFee->{'ba.code'}} = $openMembershipFee->{'ba.attribute'};
        } else {
            # ad further borrower attribute to membership fee hit hash
            $membershipFeeHit->{attributes}->{$openMembershipFee->{'ba.code'}} = $openMembershipFee->{'ba.attribute'};
        }
    }
    if ( $success && defined($membershipFeeHit->{accountlines}->{accountlines_id}) ) {

        # handle payment of last membership fee hit
        my $kohaPaymentId = $self->payMembershipFee($membershipFeeHit, $dateSepaDirectDebit);

        $membershipFeeHit->{kohaPaymentId} = $kohaPaymentId;    # value 0 indicates failed creation of accountlines record for payment
        if ( $membershipFeeHit->{kohaPaymentId} ) {
            push @{$self->{membershipFeeHitsPaid}}, $membershipFeeHit;
            # create notice for borrower informing about the upcoming SEPA direct debit
            $success = $self->printSepaNotice($membershipFeeHit);
        } else {
            push @{$self->{membershipFeeHitsFailed}}, $membershipFeeHit;
        }
    }
    # we roll back all actions if borrower notice fails fundamentally
    if ( $success ) {
        $success = $self->writeSepaDirectDebitFile($dateSepaDirectDebit);
    }

    if ( $success ) {
        $dbh->commit();
    } else {
        $dbh->rollback();
    }
    $dbh->{AutoCommit} = 1;
    print STDERR "Koha::SEPAPayment::payMembershipFeesForSEPADebitPatrons() returns success:$success:\n" if $self->{verbose} > 1;

    return $success;
}

sub payMembershipFee {
    my $self = shift;
    my ($membershipFeeHit, $dateSepaDirectDebit) = @_;

    my $kohaPaymentId = 0;
    print STDERR "Koha::SEPAPayment::payMembershipFee() accountlines_id:" . $membershipFeeHit->{accountlines}->{accountlines_id} . ": dateSepaDirectDebit:" . $dateSepaDirectDebit . ":\n" if $self->{verbose} > 1;

    # check if required info is set / wei 10.06.2020: no checks, please!
    my $ibanOk = $self->checkIban($membershipFeeHit);
    my $bicOk = $self->checkBic($membershipFeeHit);
    my $signOk = 1;    # $self->checkSign($membershipFeeHit);    # wei 10.06.2020: no checks, please!

    if ( $ibanOk &&
         $bicOk &&
         $signOk    ) {

        # now 'pay' the accountline representing the membership fee
        my $account = Koha::Account->new( { patron_id => $membershipFeeHit->{borrowers}->{borrowernumber} } );
        my @lines = Koha::Account::Lines->search(    # array consisting of 1 row
            {
                accountlines_id => $membershipFeeHit->{accountlines}->{accountlines_id}
            }
        );
        #print STDERR "Koha::SEPAPayment::payMembershipFee Dumper(lines):" . Dumper(\@lines) . ":\n" if $self->{verbose} > 1;

        if ( $lines[0] ) {
            print STDERR "Koha::SEPAPayment::payMembershipFee() Dumper(lines[0]->{_result}->{_column_data}):" . Dumper($lines[0]->{_result}->{_column_data}) . ":\n" if $self->{verbose} > 1;
            my $descriptionText = 'Zahlung (SEPA Lastschrift)';
            my $noteText = output_pref( { 'dt' => $dateSepaDirectDebit, dateformat => 'iso', dateonly => 1 } );    # requested collection date (vorgesehenes Datum für Lastschrifteinzug)
            print STDERR "Koha::SEPAPayment::payMembershipFee() noteText:" . $noteText . ":\n" if $self->{verbose} > 1;

            $kohaPaymentId = $account->pay(
                {
                    amount => $membershipFeeHit->{accountlines}->{amountoutstanding},
                    lines => \@lines,
                    library_id => $membershipFeeHit->{borrowers}->{branchcode},    # we take the borrowers branchcode also for the payment accountlines record to be created
                    description => $descriptionText,
                    note => $noteText,
                    withoutCashRegisterManagement => $self->{cashRegisterConfig}->{withoutCashRegisterManagement},
                    onlinePaymentCashRegisterManagerId => $self->{cashRegisterConfig}->{cash_register_manager_id}
                }
            );
        }
    }
    if ( $kohaPaymentId ) {
        print STDERR "Koha::SEPAPayment::payMembershipFee() direct debit payment of membership fee for borrower:" .
            $membershipFeeHit->{borrowers}->{borrowernumber} .
            ": amount:" .
            $membershipFeeHit->{accountlines}->{amountoutstanding} .
            ": fee accountlines_id:" .
            $membershipFeeHit->{accountlines}->{accountlines_id} .
            ": pay accountlines_id:" .
            $kohaPaymentId .
            ": succeeded.\n" if $self->{verbose} > 0;
    } else {
        print STDERR "Koha::SEPAPayment::payMembershipFee() error: direct debit payment of membership fee for borrower:" .
            $membershipFeeHit->{borrowers}->{borrowernumber} .
            ": amount:" .
            $membershipFeeHit->{accountlines}->{amountoutstanding} .
            ": fee accountlines_id:" .
            $membershipFeeHit->{accountlines}->{accountlines_id} .
            ": failed.\n";
    }
    print STDERR "Koha::SEPAPayment::payMembershipFee() returns kohaPaymentId:" . ($kohaPaymentId?$kohaPaymentId:'undef') . ":\n" if $self->{verbose} > 1;
    return $kohaPaymentId;
}

sub checkIban {
    my $self = shift;
    my ($membershipFeeHit) = @_;
    my $ret = 0;

    print STDERR "Koha::SEPAPayment::checkIban() START\n" if $self->{verbose} > 1;
    if( ! ( defined($membershipFeeHit->{attributes}) && defined($membershipFeeHit->{attributes}->{SEPA_IBAN}) ) ) {
        print STDERR "Koha::SEPAPayment::checkIban() IBAN not defined (borrower:" . $membershipFeeHit->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
    } elsif ( length($membershipFeeHit->{attributes}->{SEPA_IBAN}) < 22 ) {
        print STDERR "Koha::SEPAPayment::checkIban() invalid IBAN:" . $membershipFeeHit->{attributes}->{SEPA_IBAN} . ": (borrower:" . $membershipFeeHit->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
    } else {
        $ret = 1;
    }
    return $ret;
}

sub checkBic {
    my $self = shift;
    my ($membershipFeeHit) = @_;
    my $ret = 0;

    print STDERR "Koha::SEPAPayment::checkBic() START\n" if $self->{verbose} > 1;
    if( ! ( defined($membershipFeeHit->{attributes}) && defined($membershipFeeHit->{attributes}->{SEPA_BIC}) ) ) {
        print STDERR "Koha::SEPAPayment::checkBic() BIC not defined (borrower:" . $membershipFeeHit->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
    } elsif ( ! ( length($membershipFeeHit->{attributes}->{SEPA_BIC}) == 8 || length($membershipFeeHit->{attributes}->{SEPA_BIC}) == 11 ) ) {
        print STDERR "Koha::SEPAPayment::checkBic() invalid BIC:" . $membershipFeeHit->{attributes}->{SEPA_BIC} . ": (borrower:" . $membershipFeeHit->{borrowers}->{borrowernumber} . ":)\n" if $self->{verbose} > 0;
    } else {
        $ret = 1;
    }
    return $ret;
}

sub printSepaNotice {
    my $self = shift;
    my ($membershipFeeHit) = @_;

    my $ret = 0;
    my $borrowernumber = $membershipFeeHit->{borrowers}->{borrowernumber};
    my $patron = Koha::Patrons->find( $borrowernumber );
    my $branchcode = $patron->branchcode;
    my $library = Koha::Libraries->find( $branchcode )->unblessed;
    my $adminEmailAddress = $library->{branchemail} || C4::Context->preference('KohaAdminEmailAddress');
    my $noticeFees = C4::NoticeFees->new();

    print STDERR "Koha::SEPAPayment::printSepaNotice() START branchcode:$branchcode: borrowernumber:$borrowernumber: letter_code:$self->{lettercode}:\n" if $self->{verbose} > 1;
    # Try to get the borrower's email address
    my $to_address = $patron->notice_email_address;

    # Try to read the new membership fee
    my $accountlines = Koha::Account::Lines->new();
    my $accountlineFee = $accountlines->find( { accountlines_id => $membershipFeeHit->{accountlines}->{accountlines_id} } );
    #print STDERR "Koha::SEPAPayment::printSepaNotice() accountlineFee->unblessed:" . Dumper($accountlineFee->unblessed) . ":\n" if $self->{verbose} > 1;
    my $accountlinePayment = $accountlines->find( { accountlines_id => $membershipFeeHit->{kohaPaymentId} } );
    #print STDERR "Koha::SEPAPayment::printSepaNotice() accountlinePayment->unblessed:" . Dumper($accountlinePayment->unblessed) . ":\n" if $self->{verbose} > 1;

    my %letter_params = (
        module => 'members',
        branchcode => $branchcode,
        lang => $patron->lang,
        tables => {
            'branches'        => $library,
            'borrowers'       => $patron->unblessed,
            'accountlinesFee' => $accountlineFee->unblessed,
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
                    my $fee = $noticeFeeRule->notice_fee();
                    
                    if ( $fee && $fee > 0.0 ) {
                        # Bad for the patron, staff has assigned a notice fee for sending the notification
                         $noticeFees->AddNoticeFee( 
                            {
                                borrowernumber => $borrowernumber,
                                amount         => $fee,
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

sub writeSepaDirectDebitFile {
    my $self = shift;
    my ($dateSepaDirectDebit) = @_;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    my $msgId = sprintf("%s%04d%02d%02d", $self->{sepaSysPrefs}->{SepaDirectDebitMessageIdHeader}, $year+1900, $mon+1, $mday);
    my $creDtTm = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    my $grpHdrNbOfTxs = scalar @{$self->{membershipFeeHitsPaid}};
    my $pmtInfNbOfTxs = scalar @{$self->{membershipFeeHitsPaid}};    # we send only 1 <PmtInf> block, so $pmtInfNbOfTxs == $grpHdrNbOfTxs
    my $reqdColltnDt = output_pref( { 'dt' => $dateSepaDirectDebit, dateformat => 'iso', dateonly => 1 } );    # requested collection date (vorgesehenes Datum für Lastschrifteinzug)
    my $remittanceInfo = sprintf("%-.140s", $self->{sepaSysPrefs}->{SepaDirectDebitRemittanceInfo});
    my $success = 0;
    my $ctrlSum = 0.0;

    foreach my $membershipFeeHit (@{$self->{membershipFeeHitsPaid}}) {
        $ctrlSum += (sprintf("%.2f",$membershipFeeHit->{accountlines}->{amountoutstanding}) + 0.0);
    }
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile(dateSepaDirectDebit:$dateSepaDirectDebit) START scalar self->{membershipFeeHitsPaid}:" . scalar @{$self->{membershipFeeHitsPaid}} . ": ctrlSum:" . $ctrlSum . ":\n" if $self->{verbose} > 1;

    my $xmlwriter = XML::Writer->new(OUTPUT => 'self', NEWLINES => 0, DATA_MODE => 1, DATA_INDENT => 2, ENCODING => 'utf-8' );

    $xmlwriter->xmlDecl("UTF-8");
    $xmlwriter->startTag(   'Document',                                                             # root element 'Document'
                                'xmlns' => 'urn:iso:std:iso:20022:tech:xsd:pain.008.003.02',
                                'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                'xsi:schemaLocation' => 'urn:iso:std:iso:20022:tech:xsd:pain.008.003.02 pain.008.003.02.xsd');
    $xmlwriter->startTag(     'CstmrDrctDbtInitn');                                                 # CustomerDirectDebitInitialization ?

    $xmlwriter->startTag(       'GrpHdr');                                                          # GroupHeader
    $xmlwriter->dataElement(      'MsgId' => $msgId);                                               # MessageId
    $xmlwriter->dataElement(      'CreDtTm' => $creDtTm);                                           # CreationDateTime
    $xmlwriter->dataElement(      'NbOfTxs' => $grpHdrNbOfTxs);                                     # NumberOfTransactions
    $xmlwriter->startTag(         'InitgPty');                                                      # InitiatingParty
    $xmlwriter->dataElement(        'Nm' => $self->{sepaSysPrefs}->{SepaDirectDebitInitiatingPartyName});   # InitiatingParty.Name
    $xmlwriter->endTag(           'InitgPty');
    $xmlwriter->endTag(         'GrpHdr');

    $xmlwriter->startTag(       'PmtInf');                                                          # PaymentInformation
    $xmlwriter->dataElement(      'PmtInfId' => $self->{sepaSysPrefs}->{SepaDirectDebitCreditorIban});  # PaymentInformationID (wie can use the IBAN for this field)
    $xmlwriter->dataElement(      'PmtMtd' => 'DD');                                                # PaymentMethod ('DD' = direct debit)
    $xmlwriter->dataElement(      'NbOfTxs' => $pmtInfNbOfTxs);                                     # NumberOfTransactions
    $xmlwriter->dataElement(      'CtrlSum' => sprintf("%.2f",$ctrlSum));                           # ControlSum

    $xmlwriter->startTag(         'PmtTpInf');                                                      # PaymentTypeInformation
    $xmlwriter->startTag(           'SvcLvl');                                                      # ServiceLevel
    $xmlwriter->dataElement(          'Cd' => 'SEPA');                                              # ServiceLevel.Code
    $xmlwriter->endTag(             'SvcLvl');
    $xmlwriter->startTag(           'LclInstrm');                                                   # LocalInstrument
    $xmlwriter->dataElement(          'Cd' => 'COR1');                                              # LocalInstrument.Code (COR1, B2B, ...) (COR1 = SEPA Basis-Lastschrift (Verbraucher))
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
    foreach my $membershipFeeHit (@{$self->{membershipFeeHitsPaid}}) {
        my $debtorName = $self->debtorName($membershipFeeHit->{borrowers}->{surname}, $membershipFeeHit->{borrowers}->{firstname});
        my $dateOfSignature = $membershipFeeHit->{attributes}->{SEPA_Sign};
        if ( ! $dateOfSignature ) {
            $dateOfSignature = sprintf("%04d-%02d-%02d",$year+1900, $mon+1, $mday);
        } else {
            if ( $dateOfSignature =~ /^(\d\d)\.(\d\d)\.(\d\d\d\d)/ ) {    # e.g. 31.12.2009
                $dateOfSignature = $3 . '-' . $2 . '-' . $1;    # e.g. 2009-12-31
            }
            if ( $dateOfSignature =~ /^(\d\d)\.(\d\d)\.(\d\d)/ ) {    # e.g. 31.12.09 or 31.12.99
                if ( 2000 + $3 <= $year+1900 ) {
                    $dateOfSignature = '20' . $3 . '-' . $2 . '-' . $1;    # e.g. 2009-12-31
                } else {
                    $dateOfSignature = '19' . $3 . '-' . $2 . '-' . $1;    # e.g. 1999-12-31
                }
            }
        }

        $xmlwriter->startTag(     'DrctDbtTxInf');                                                  # DirectDebitTransactionInformation
        $xmlwriter->startTag(       'PmtId');                                                       # PaymentID
        $xmlwriter->dataElement(      'EndToEndId' => 'NOTPROVIDED');                               # PaymentID.EndToEndId (from the viewpoint of the initiator)
        $xmlwriter->endTag(         'PmtId');

        $xmlwriter->dataElement(    'InstdAmt', sprintf("%.2f",$membershipFeeHit->{accountlines}->{amountoutstanding}), 'Ccy' => 'EUR'); # InstructedAmount (in currency 'EUR')

        $xmlwriter->startTag(       'DrctDbtTx');                                                   # DirectDebitTransaction
        $xmlwriter->startTag(         'MndtRltdInf');                                               # MandateRelatedInformation
        $xmlwriter->dataElement(        'MndtId' => $membershipFeeHit->{borrowers}->{cardnumber});  # MandateID
        $xmlwriter->dataElement(        'DtOfSgntr' => $dateOfSignature);                           # DateOfSignature in format yyyy-mm-dd
        $xmlwriter->dataElement(        'AmdmntInd' => 'false');                                    # AmendmentIndicator
        $xmlwriter->endTag(           'MndtRltdInf');
        $xmlwriter->endTag(         'DrctDbtTx');

        $xmlwriter->startTag(       'DbtrAgt');                                                     # DebtorAgent
        $xmlwriter->startTag(         'FinInstnId');                                                # FinancialInstitutionIdentification
        $xmlwriter->dataElement(        'BIC' => $membershipFeeHit->{attributes}->{SEPA_BIC});      # FinancialInstitutionIdentification.BIC
        $xmlwriter->endTag(           'FinInstnId');
        $xmlwriter->endTag(         'DbtrAgt');

        $xmlwriter->startTag(       'Dbtr');                                                        # Debtor
        $xmlwriter->dataElement(        'Nm' => sprintf("%-.70s",$debtorName));                     # Debtor.Name (max. 70 chars)
        $xmlwriter->endTag(         'Dbtr');

        $xmlwriter->startTag(       'DbtrAcct');                                                    # DebtorAccount
        $xmlwriter->startTag(         'Id');                                                        # DebtorAccount.ID
        $xmlwriter->dataElement(        'IBAN' => $membershipFeeHit->{attributes}->{SEPA_IBAN});    # DebtorAccount.ID.IBAN
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


    # create a batch output file, even if it contains 0 transactions
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() will now open output file:" . $self->{xmlfilename} . ": for writing\n" if $self->{verbose} > 1;
    my $fh;
    my $res = open $fh, ">:encoding(UTF-8)", $self->{xmlfilename};
    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() tried to open output file:" . $self->{xmlfilename} . ": fh:$fh: res:" . (defined($res)?$res:'undef') . ":\n" if $self->{verbose} > 1;
    if ( $res ) {
        $res = print $fh $xmlContent;
        close $fh;
        print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() tried to write to output file:" . $self->{xmlfilename} . ": res:" . (defined($res)?$res:'undef') . ":\n" if $self->{verbose} > 1;
        if ( $res ) {
            print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() output file:" . $self->{xmlfilename} . ": has been written\n" if $self->{verbose} > 1;
            $success = 1;
        }
    }
    if ( ! $success ) {
        print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() output file:" . $self->{xmlfilename} . ": has NOT been written. ( \$!:$!: )\n";
    }

    print STDERR "Koha::SEPAPayment::writeSepaDirectDebitFile() output file:" . $self->{xmlfilename} . ": returns success:$success:\n" if $self->{verbose} > 1;
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
