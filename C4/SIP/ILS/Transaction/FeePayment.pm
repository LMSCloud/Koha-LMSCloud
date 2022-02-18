package C4::SIP::ILS::Transaction::FeePayment;

# Copyright 2011 PTFS-Europe Ltd.
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

use warnings;
use strict;

use C4::Context;

use Koha::Account;
use Koha::Account::Lines;

use C4::CashRegisterManagement;
use C4::SIP::Sip qw(siplog);

use parent qw(C4::SIP::ILS::Transaction);

our $debug = 0;

my %fields = ();

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    foreach ( keys %fields ) {
        $self->{_permitted}->{$_} = $fields{$_};    # overlaying _permitted
    }

    @{$self}{ keys %fields } = values %fields;    # copying defaults into object
    return bless $self, $class;
}

sub pay {
    my $self                 = shift;
    my $borrowernumber       = shift;
    my $amt                  = shift;
    my $sip_type             = shift;
    my $fee_id               = shift;
    my $is_writeoff          = shift;
    my $disallow_overpayment = shift;
    my $register_id          = shift;

    my $type = $is_writeoff ? 'WRITEOFF' : 'PAYMENT';

    my $account = Koha::Account->new( { patron_id => $borrowernumber } );

    if ($disallow_overpayment) {
        return { ok => 0 } if $account->balance < $amt;
    }
 
    my $withoutCashRegisterManagement = checkOpenedCashRegisterIfConfigured();
    
    siplog("LOG_DEBUG", "pay fee: borrowernumber %d, sip_type %s, amount %f, withoutCashRegisterManagement = %d",$borrowernumber, $amt, $sip_type, $withoutCashRegisterManagement);

    my $pay_options = {
        amount        => $amt,
        type          => $type,
        payment_type  => 'SIP' . $sip_type,
        interface     => C4::Context->interface,
        cash_register => $register_id,
        withoutCashRegisterManagement => $withoutCashRegisterManagement,
    };
    
    if ($fee_id) {
        my $fee = Koha::Account::Lines->find($fee_id);
        if ( $fee ) {
            $pay_options->{lines} = [$fee];
        }
        else {
            return {
                ok => 0
            };
        }
    }

    my $pay_response;
    eval {
            $pay_response = $account->pay($pay_options);
    };
    
    if ( $@ ) {
        siplog("LOG_DEBUG", "pay fee error: %s", $@);
        return {
            ok           => 0,
        };
    }
    
    return {
        ok           => 1,
        pay_response => $pay_response
    };
}

sub checkOpenedCashRegisterIfConfigured {
    my $withoutCashRegisterManagement = 1;
    
    my $cashregname = C4::Context->preference('SIPCashRegisterName');
    my $branch      = C4::Context->userenv->{branch};
    my $manager_id  = C4::Context->userenv->{number};
    my $retWithoutCashRegisterManagement = 1;
    
    if ( $cashregname ) {
        
        my $cashRegisterMngmt = C4::CashRegisterManagement->new($branch, $manager_id);
        my $openedCashRegister = $cashRegisterMngmt->getOpenedCashRegisterByManagerID($manager_id);
        
        siplog("LOG_DEBUG", "sip pay fee: use cash register %s (current status open: %d)",$cashregname,($openedCashRegister ? 1 : 0));
        
        if ( $openedCashRegister ) {
            if ( $openedCashRegister->{'cash_register_name'} ne $cashregname ) {
                $cashRegisterMngmt->closeCashRegister($openedCashRegister->{'cash_register_id'}, $manager_id);
                $openedCashRegister = undef;
            }
            else {
                $withoutCashRegisterManagement = 0;
            }
        }
        if (! $openedCashRegister ) {
            my $cashRegisterId = $cashRegisterMngmt->readCashRegisterIdByName($cashregname);
            if ( defined $cashRegisterId && $cashRegisterMngmt->canOpenCashRegister($cashRegisterId, $manager_id) ) {
                $openedCashRegister = $cashRegisterMngmt->openCashRegister($cashRegisterId, $manager_id);
                $withoutCashRegisterManagement = 0 if ($openedCashRegister);
            }
        }
        if (! $openedCashRegister ) {
            siplog("LOG_ERROR", "Cannot open cash register '%s' for manager id '%s' of branch '%s' for SIP payment.", $cashregname, $manager_id, $branch);
        }
    }
    return $withoutCashRegisterManagement;
}

# sub DESTROY {
# }

1;
__END__

