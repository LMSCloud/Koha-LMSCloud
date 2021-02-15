package C4::Epayment::EpaymentBase;

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
use strict;
use warnings;
use Data::Dumper;

use Digest;
use Digest::MD5 qw(md5 md5_hex md5_base64);
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

    $self->{kohaInstanceName} = substr(C4::Context->config('database'),5);  # Regrettably the Koha instance name is not configured, so we take database name (e.g. 'koha_wallenheim') and cut away the leading part 'koha_'.
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

    $self->{logger}->debug("getSystempreferences() paymentsMinimumPatronAge:$self->{paymentsMinimumPatronAge}:");
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
sub roundGS {
    my $self = shift;
    my ($flt, $decimaldigits) = @_;
    my $decimalshift = 10 ** $decimaldigits;

    return (int(($flt * $decimalshift) + (($flt < 0) ? -0.5 : 0.5)) / $decimalshift);
}

# create remittance information text for payment (will be displayed on paypage with GiroSolution and pmPayment payment service providers)
# defined placeholder: <<borrowers.cardnumber>>
# ancient SEPA rules restrict the character set to: a-z A-Z 0-9 ':?,-(+.)/
# (So the text pattern has to be supplied correctly by Koha user.)
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

# calculate HMAC MD5 digest
sub genHmacMd5 {
    my $self = shift;
    my ($key, $str) = @_;

    #my $hmac_md5 = Digest->HMAC_MD5($key);    # wrong hash calculation if $key contain ISO-8859-* 8-bit chars
    #$hmac_md5->add($str);    # wrong hash calculation if $str contain ISO-8859-* 8-bit chars
    my $hmac_md5 = Digest->HMAC_MD5( Encode::encode_utf8($key) );    # force UTF-8 encoding, even for 8-bit chars
    $hmac_md5->add( Encode::encode_utf8($str) );    # force UTF-8 encoding, even for 8-bit chars
    my $hashval = $hmac_md5->hexdigest();

    return $hashval;
}

# calculate HMAC SHA-256 digest
sub genHmacSha256 {
    my $self = shift;
    my ($str, $key) = @_;

    #my $hashval = hmac_sha256_hex($str, $key);    # wrong hash calculation if $str (or $key) contain ISO-8859-* 8-bit chars
    my $hashval = hmac_sha256_hex(Encode::encode_utf8($str), Encode::encode_utf8($key));    # force UTF-8 encoding, even for 8-bit chars

    return $hashval;
}

# pick chars from a string based on a simple pattern, mainly used for compressing hash values
sub pickChars {
    my $self = shift;
    my ($str, $offset1, $offset2, $cnt) = @_;    # $offset1: offset of 1st char to pick  $offset2: offset from char to char  $cnt: count of chars to pick
    my $len = length($str) ? length($str) : 1;
    my $offs = $offset1 % $len;
    my $res = '';

    for ( my $i = 0; $i < $cnt; $i += 1 ) {
        if ( my $c = substr($str, $offs, 1) ) {
            $res .= $c;
        } else {
            $res .= '0';
        }
        $offs = ($offs + $offset2) % $len;
    }

    $self->{logger}->trace("pickChars(str:$str: offset1:$offset1: offset2:$offset2: cnt:$cnt) returns res:$res:");
    return($res);
}

1;
