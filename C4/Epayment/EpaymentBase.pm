package C4::Epayment::EpaymentBase;

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
use Digest;
use Digest::SHA qw(hmac_sha256_hex);
use Encode; 

use C4::Context;

sub new {
    my $class = shift;
    my $loggerEpayment = Koha::Logger->get({ interface => 'epayment' });

    my $self  = {
        logger => $loggerEpayment
    };

    #bless $self, $class;    # does not work: Attempt to bless into a reference
    bless $self, 'C4::Epayment::EpaymentBase';

    $self->getSystempreferences();

    $self->{logger}->debug("new() returns self:" . Dumper($self) . ":");
    return $self;
}

# get system preferences from the generic online payments section
sub getSystempreferences {
    my $self = shift;

    $self->{logger}->debug("getSystempreferences() START");

    $self->{paymentsMinimumPatronAge} = C4::Context->preference('PaymentsMinimumPatronAge');
    $self->{activateCashRegisterTransactionsOnly} = C4::Context->preference('ActivateCashRegisterTransactionsOnly');
    $self->{paymentsOnlineCashRegisterName} = C4::Context->preference('PaymentsOnlineCashRegisterName');
    $self->{paymentsOnlineCashRegisterManagerCardnumber} = C4::Context->preference('PaymentsOnlineCashRegisterManagerCardnumber');

    $self->{logger}->debug("getSystempreferences() paymentsMinimumPatronAge:$self->{paymentsMinimumPatronAge}: paymentsRemittanceInfo:$self->{paymentsRemittanceInfo}:");
    $self->{logger}->debug("getSystempreferences() activateCashRegisterTransactionsOnly:$self->{activateCashRegisterTransactionsOnly}: paymentsOnlineCashRegisterName:$self->{paymentsOnlineCashRegisterName}: paymentsOnlineCashRegisterManagerCardnumber:$self->{paymentsOnlineCashRegisterManagerCardnumber}:");

}

# evaluate system preferences configuration of cash register management for online payments
sub getEpaymentCashRegisterManagement {
    my $self = shift;
            
    my $retWithoutCashRegisterManagement = 1;    # default: avoiding cash register management in Koha::Account->pay()
    my $retCashRegisterManagerId = 0;    # borrowernumber of manager of cash register for online payments

    $self->{logger}->debug("getEpaymentCashRegisterManagement() START");

    if ( $self->{activateCashRegisterTransactionsOnly} ) {
        if ( length($self->{paymentsOnlineCashRegisterName}) && length($self->{paymentsOnlineCashRegisterManagerCardnumber}) ) {
            $retWithoutCashRegisterManagement = 0;

            # get cash register manager information
            my $cashRegisterManager = Koha::Patrons->search( { cardnumber => $self->{paymentsOnlineCashRegisterManagerCardnumber} } )->next();
            if ( $cashRegisterManager ) {
                $retCashRegisterManagerId = $cashRegisterManager->borrowernumber();
                my $cashRegisterManagerBranchcode = $cashRegisterManager->branchcode();
                $self->{logger}->debug("getEpaymentCashRegisterManagement() retCashRegisterManagerId:$retCashRegisterManagerId: cashRegisterManagerBranchcode:$cashRegisterManagerBranchcode:");
                my $cashRegisterMngmt = C4::CashRegisterManagement->new($cashRegisterManagerBranchcode, $retCashRegisterManagerId);
                $self->{logger}->trace("getEpaymentCashRegisterManagement() cashRegisterMngmt:" . Dumper($cashRegisterMngmt) . ":");

                if ( $cashRegisterMngmt ) {
                    my $cashRegisterNeedsToBeOpened = 1;
                    my $openedCashRegister = $cashRegisterMngmt->getOpenedCashRegisterByManagerID($retCashRegisterManagerId);
                    if ( defined $openedCashRegister ) {
                        if ($openedCashRegister->{'cash_register_name'} eq $self->{paymentsOnlineCashRegisterName}) {
                            $cashRegisterNeedsToBeOpened = 0;
                        } else {
                            $cashRegisterMngmt->closeCashRegister($openedCashRegister->{'cash_register_id'}, $retCashRegisterManagerId);
                        }
                    }
                    $self->{logger}->debug("getEpaymentCashRegisterManagement() cashRegisterNeedsToBeOpened:$cashRegisterNeedsToBeOpened:");
                    if ( $cashRegisterNeedsToBeOpened ) {
                        # try to open the specified cash register by name
                        my $cash_register_id = $cashRegisterMngmt->readCashRegisterIdByName($self->{paymentsOnlineCashRegisterName});
                        if ( defined $cash_register_id && $cashRegisterMngmt->canOpenCashRegister($cash_register_id, $retCashRegisterManagerId) ) {
                            my $opened = $cashRegisterMngmt->openCashRegister($cash_register_id, $retCashRegisterManagerId);
                            $self->{logger}->debug("getEpaymentCashRegisterManagement() opened:" . Dumper($opened) . ":");
                        }
                    }
                }
            }
        }
    }

    $self->{logger}->debug("getEpaymentCashRegisterManagement() returns retWithoutCashRegisterManagement:$retWithoutCashRegisterManagement: retCashRegisterManagerId:$retCashRegisterManagerId:");
    return ( $retWithoutCashRegisterManagement, $retCashRegisterManagerId );
}

# round float $flt to precision of $decimaldigits behind the decimal separator. E. g. roundGS(-1.234567, 2) == -1.23
sub roundGS ()
{
    my $self = shift;
    my ($flt, $decimaldigits) = @_;
    my $decimalshift = 10 ** $decimaldigits;

    return (int(($flt * $decimalshift) + (($flt < 0) ? -0.5 : 0.5)) / $decimalshift);
}

# create remittance information text for payment (will be displayed on paypage with most payment service providers)
# defined placeholder: <<borrowers.cardnumber>>
sub createRemittanceInfoText {
    my $self = shift;
    my $remittanceInfoTextPattern = shift;
    my $cardnumber = shift;

    $self->{logger}->debug("createRemittanceInfoText() START remittanceInfoTextPattern:" . ($remittanceInfoTextPattern?$remittanceInfoTextPattern:'undef') . ": cardnumber:$cardnumber:");

    my $retRemittanceInfoText = 'Bibliothek:' . $cardnumber;    # basic fall back default

    if ( $remittanceInfoTextPattern ) {
        $retRemittanceInfoText = $remittanceInfoTextPattern;
        $retRemittanceInfoText =~ s/<<borrowers.cardnumber>>/$cardnumber/g;
    }
    $retRemittanceInfoText = substr($retRemittanceInfoText, 0, 27);    # limit remittance information text to ancient SEPA specified length

    $self->{logger}->debug("createRemittanceInfoText() returns retRemittanceInfoText:$retRemittanceInfoText:");
    return $retRemittanceInfoText;
}

# calculate HMAC SHA-256 digest
sub genHmacSha256 {
    my $self = shift;
    my ($str, $key) = @_;

    #my $hashval = hmac_sha256_hex($str, $key);    # wrong hash calculation if $str (or $key) contain ISO-8859-* 8-bit chars
    my $hashval = hmac_sha256_hex(Encode::encode_utf8($str), Encode::encode_utf8($key));    # force UTF-8 encoding, even for 8-bit chars

    return $hashval;
}

1;
