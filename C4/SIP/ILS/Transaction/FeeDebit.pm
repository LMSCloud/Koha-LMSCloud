package C4::SIP::ILS::Transaction::FeeDebit;

use warnings;
use strict;

# Copyright 2021 LMSCloud GmbH
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

use C4::Context;
use Koha::AuthorisedValues;
use Koha::Account::DebitTypes;
use Koha::Patrons;

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
    
    $self->{patron_password_checked} = 0;
    $self->{patron_password_ok} = 0;
    
    return bless $self, $class;
}

sub charge {
    my $self                 = shift;
    my $borrowernumber       = shift;
    my $amount               = shift;
    my $fee_type             = shift;
    my $product_identifier   = shift;
    my $fee_id               = shift;
    my $prod_code            = shift;
    my $fee_comment          = shift;
    
    my $charge_ok = 1;
    my $debit_type;
    my $description;
    
    my $feeTypes = {};
    foreach my $debit_type ( Koha::Account::DebitTypes->search() ) {
        $feeTypes->{$debit_type->code} = $debit_type->description;
    }
    my $authorisedValueSearch = Koha::AuthorisedValues->search({ category => "DEBIT_TYPE_SIP2_MAPPED" },{ order_by => ['authorised_value'] } );
    my $feeTypesSIPMapped = {};
    if ( $authorisedValueSearch->count ) {
        while ( my $authval = $authorisedValueSearch->next ) {
            my $value   = $authval->authorised_value || '';
            my $valname = $authval->lib;
            $feeTypesSIPMapped->{$value} = [$valname,$authval->lib_opac];
        }
    }
    
    if ( exists($feeTypes->{$prod_code}) ) {
        $debit_type = $prod_code;
        $description = $feeTypes->{$prod_code};
    }
    elsif ( exists($feeTypesSIPMapped->{$prod_code}) && exists($feeTypes->{$feeTypesSIPMapped->{$prod_code}->[0]}) ) {
        $debit_type = $feeTypesSIPMapped->{$prod_code}->[0];
        $description = $feeTypesSIPMapped->{$prod_code}->[1];
    }
    elsif ( exists($feeTypes->{$fee_type}) ) {
        $debit_type = $fee_type;
        $description = $feeTypes->{$fee_type};
    }
    else {
        if ( exists($feeTypesSIPMapped->{$fee_type}) && exists($feeTypes->{$feeTypesSIPMapped->{$fee_type}->[0]})) {
            $debit_type = $feeTypesSIPMapped->{$fee_type}->[0];
            $description = $feeTypesSIPMapped->{$fee_type}->[1];
        }
        elsif ( exists($feeTypesSIPMapped->{$fee_type.$product_identifier}) && exists($feeTypes->{$feeTypesSIPMapped->{$fee_type.$product_identifier}->[0]})) {
            $debit_type = $feeTypesSIPMapped->{$fee_type.$product_identifier}->[0];
            $description = $feeTypesSIPMapped->{$fee_type.$product_identifier}->[1];
        }
        else {
            $self->screen_msg("Debit type invalid.");
            $self->ok(0);
            $charge_ok = 0;
        }
    }
    
    if ( !$amount || $amount !~ /^[0-9]+(\.[0-9]{1,2})?$/ || $amount < 0.0 ) {
        $self->screen_msg("Fee amount invalid.");
        $self->ok(0);
        $charge_ok = 0;
    }
    else {
        $amount += 0.0;
    }

    if ( $charge_ok) {
        my $patron = Koha::Patrons->find($borrowernumber);
        
        if ( $patron ) {
            my $line = $patron->account->add_debit(
                {
                    amount      => $amount,
                    description => $description,
                    note        => $fee_comment,
                    user_id     => C4::Context->userenv->{number},
                    interface   => C4::Context->interface,
                    library_id  => C4::Context->userenv->{branch},
                    type        => $debit_type
                }
            );

            if ( C4::Context->preference('AccountAutoReconcile') ) {
                $patron->account->reconcile_balance;
            }
            $self->ok(1);
        } else {
            $self->screen_msg("Invalid patron id.");
            $self->ok(0);
        }
    }
}

sub setPatronPasswordChecked {
    my $self = shift;
    my $checked = shift;
    $self->{patron_password_checked} = $checked;
}

sub getPatronPasswordChecked {
    my $self = shift;
    return $self->{patron_password_checked};
}

sub setPatronPasswordOk {
    my $self = shift;
    my $checked = shift;
    $self->{patron_password_ok} = $checked;
}

sub getPatronPasswordOk {
    my $self = shift;
    return $self->{patron_password_ok};
}

1;
__END__

