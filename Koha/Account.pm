package Koha::Account;

# Copyright 2016 ByWater Solutions
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

use Modern::Perl;

use Carp;
use Data::Dumper;

use C4::Log qw( logaction );
use C4::Stats qw( UpdateStats );
use C4::CashRegisterManagement;
use C4::Context;

use Koha::Account::Lines;
use Koha::Account::Offsets;
use Koha::DateUtils qw( dt_from_string );

=head1 NAME
Koha::Accounts - Module for managing payments and fees for patrons
=cut

sub new {
    my ( $class, $params ) = @_;

    Carp::croak("No patron id passed in!") unless $params->{patron_id};

    return bless( $params, $class );
}

=head2 pay
This method allows payments to be made against fees/fines
Koha::Account->new( { patron_id => $borrowernumber } )->pay(
    {
        amount      => $amount,
        sip         => $sipmode,
        note        => $note,
        description => $description,
        library_id  => $branchcode,
        lines        => $lines, # Arrayref of Koha::Account::Line objects to pay
        account_type => $type,  # accounttype code
        offset_type => $offset_type,    # offset type code
    }
);
=cut

sub pay {
    my ( $self, $params ) = @_;

    my $amount       = $params->{amount};
    my $sip          = $params->{sip};
    my $description  = $params->{description};
    my $note         = $params->{note} || q{};
    my $library_id   = $params->{library_id};
    my $lines        = $params->{lines};
    my $type         = $params->{type} || 'payment';
    my $account_type = $params->{account_type};
    my $offset_type  = $params->{offset_type} || $type eq 'writeoff' ? 'Writeoff' : $type eq 'cancelfee' ? 'Cancel Fee' : 'Payment';

    my $userenv = C4::Context->userenv;

    # We should remove accountno, it is no longer needed
    my $last = Koha::Account::Lines->search(
        {
            borrowernumber => $self->{patron_id}
        },
        {
            order_by => 'accountno'
        }
    )->next();
    my $accountno = $last ? $last->accountno + 1 : 1;

    my $manager_id = $userenv ? $userenv->{number} : 0;
    $library_id ||= $userenv ? $userenv->{'branch'} : undef;
    
    my $cash_register_mngmt = undef;
    # Check whether cash registers are activated and mandatory for payment actions.
    # If thats the case than we need to check whether the manager has opened a cash
    # register to use for payments.
    if ( !$sip && C4::Context->preference("ActivateCashRegisterTransactionsOnly") ) {
        $cash_register_mngmt = C4::CashRegisterManagement->new($library_id, $manager_id);
        
        # if there is no open cash register of the manager we return without a doing the payment
        return undef if (! $cash_register_mngmt->managerHasOpenCashRegister($library_id, $manager_id) );
    }

    my @fines_paid; # List of account lines paid on with this payment

    my $balance_remaining = $amount; # Set it now so we can adjust the amount if necessary
    $balance_remaining ||= 0;

    my @account_offsets;

    # We were passed a specific line to pay
    foreach my $fine ( @$lines ) {
        my $amount_to_pay =
            $fine->amountoutstanding > $balance_remaining
          ? $balance_remaining
          : $fine->amountoutstanding;

        my $old_amountoutstanding = $fine->amountoutstanding;
        my $new_amountoutstanding = $old_amountoutstanding - $amount_to_pay;
        $fine->amountoutstanding($new_amountoutstanding)->store();
        $balance_remaining = $balance_remaining - $amount_to_pay;

        if ( $fine->itemnumber && $fine->accounttype && ( $fine->accounttype eq 'Rep' || $fine->accounttype eq 'L' ) )
        {
            C4::Circulation::ReturnLostItem( $self->{patron_id}, $fine->itemnumber );
        }

        my $account_offset = Koha::Account::Offset->new(
            {
                debit_id => $fine->id,
                type     => $offset_type,
                amount   => $amount_to_pay * -1,
            }
        );
        push( @account_offsets, $account_offset );

        if ( C4::Context->preference("FinesLog") ) {
            logaction(
                "FINES", 'MODIFY',
                $self->{patron_id},
                Dumper(
                    {
                        action                => 'fee_payment',
                        borrowernumber        => $fine->borrowernumber,
                        old_amountoutstanding => $old_amountoutstanding,
                        new_amountoutstanding => 0,
                        amount_paid           => $old_amountoutstanding,
                        accountlines_id       => $fine->id,
                        accountno             => $fine->accountno,
                        manager_id            => $manager_id,
                        note                  => $note,
                    }
                )
            );
            push( @fines_paid, $fine->id );
        }
    }

    # Were not passed a specific line to pay, or the payment was for more
    # than the what was owed on the given line. In that case pay down other
    # lines with remaining balance.
    my @outstanding_fines;
    @outstanding_fines = Koha::Account::Lines->search(
        {
            borrowernumber    => $self->{patron_id},
            amountoutstanding => { '>' => 0 },
        }
    ) if $balance_remaining > 0;

    foreach my $fine (@outstanding_fines) {
        my $amount_to_pay =
            $fine->amountoutstanding > $balance_remaining
          ? $balance_remaining
          : $fine->amountoutstanding;

        my $old_amountoutstanding = $fine->amountoutstanding;
        $fine->amountoutstanding( $old_amountoutstanding - $amount_to_pay );
        $fine->store();

        my $account_offset = Koha::Account::Offset->new(
            {
                debit_id => $fine->id,
                type     => $offset_type,
                amount   => $amount_to_pay * -1,
            }
        );
        push( @account_offsets, $account_offset );

        if ( C4::Context->preference("FinesLog") ) {
            logaction(
                "FINES", 'MODIFY',
                $self->{patron_id},
                Dumper(
                    {
                        action                => "fee_$type",
                        borrowernumber        => $fine->borrowernumber,
                        old_amountoutstanding => $old_amountoutstanding,
                        new_amountoutstanding => $fine->amountoutstanding,
                        amount_paid           => $amount_to_pay,
                        accountlines_id       => $fine->id,
                        accountno             => $fine->accountno,
                        manager_id            => $manager_id,
                        note                  => $note,
                    }
                )
            );
            push( @fines_paid, $fine->id );
        }

        $balance_remaining = $balance_remaining - $amount_to_pay;
        last unless $balance_remaining > 0;
    }

    $account_type ||=
        $type eq 'writeoff' ? 'W'
      : $type eq 'cancelfee' ? 'CAN'
      : defined($sip)       ? "Pay$sip"
      :                       'Pay';

    my $desc ||= $type eq 'writeoff' ? 'Writeoff' : $type eq 'cancelfee' ? 'Fine cancelled' : q{};
    if ( $description ) {
        $desc .= ": $description";
    }

    my $payment = Koha::Account::Line->new(
        {
            borrowernumber    => $self->{patron_id},
            accountno         => $accountno,
            date              => dt_from_string(),
            amount            => 0 - $amount,
            description       => $desc,
            accounttype       => $account_type,
            amountoutstanding => 0 - $balance_remaining,
            manager_id        => $manager_id,
            note              => $note,
            branchcode        => $library_id,
        }
    )->store();

    foreach my $o ( @account_offsets ) {
        $o->credit_id( $payment->id() );
        $o->store();
    }

    # If it is not SIP it is a cash payment and if cash registers are activated as too,
    # the cash payment need to registered for the opened cash register as cash receipt
    if ( !$sip && C4::Context->preference("ActivateCashRegisterTransactionsOnly") ) {
        $cash_register_mngmt->registerPayment($library_id, $manager_id, $amount, $payment->id());
    }

    UpdateStats(
        {
            branch         => $library_id,
            type           => $type,
            amount         => $amount,
            borrowernumber => $self->{patron_id},
            accountno      => $accountno,
        }
    );

    if ( C4::Context->preference("FinesLog") ) {
        logaction(
            "FINES", 'CREATE',
            $self->{patron_id},
            Dumper(
                {
                    action            => "create_$type",
                    borrowernumber    => $self->{patron_id},
                    accountno         => $accountno,
                    amount            => 0 - $amount,
                    amountoutstanding => 0 - $balance_remaining,
                    accounttype       => $account_type,
                    accountlines_paid => \@fines_paid,
                    manager_id        => $manager_id,
                }
            )
        );
    }

    return $payment->id;
}

=head3 balance
my $balance = $self->balance
Return the balance (sum of amountoutstanding columns)
=cut

sub balance {
    my ($self) = @_;
    my $fines = Koha::Account::Lines->search(
        {
            borrowernumber => $self->{patron_id},
        },
        {
            select => [ { sum => 'amountoutstanding' } ],
            as => ['total_amountoutstanding'],
        }
    );
    return $fines->count
      ? $fines->next->get_column('total_amountoutstanding')
      : 0;
}

1;

=head1 AUTHOR
Kyle M Hall <kyle.m.hall@gmail.com>
=cut