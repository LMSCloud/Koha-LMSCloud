package C4::CashRegisterManagement;

# Copyright LMCloud GmbH 2016
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

use C4::Context;
use Koha::CashRegister::CashRegister;
use Koha::CashRegister::CashRegisters;
use Koha::CashRegister::CashRegisterManager;
use Koha::CashRegister::CashRegisterManagers;
use Koha::CashRegister::CashRegisterAccount;
use Koha::CashRegister::CashRegisterAccounts;
use DateTime;
use Koha::DateUtils;
use Koha::Acquisition::Currencies;
use Locale::Currency::Format;
use DateTime::Format::MySQL;

use constant false => 0;
use constant true  => 1;

use vars qw(@ISA @EXPORT @EXPORT_OK);

BEGIN {
    @ISA       = qw(Exporter);
    @EXPORT    = qw(passCashRegisterCheck);
    @EXPORT_OK = qw(passCashRegisterCheck);
}
    
=head1 FUNCTIONS

=head2 new

  C4::CashRegisterManagement->new($branch)

Do always initialize that module with new. The new parameter requires the currently used branch.

=cut

sub new {
    my $class = shift;
    my $branch = shift;
    my $currentuser = shift;
    my $self  = bless { @_ }, $class;

    if ( $branch ) {
        $self->{'branch'} = $branch;
    } else {
        $self->{'branch'} = C4::Context->userenv->{'branch'} if C4::Context->userenv;
    }
    
    if ( $currentuser ) {
        $self->{'user'} = $currentuser;
    } else {
        $self->{'user'} = C4::Context->userenv->{'number'} if C4::Context->userenv;
    }
    $self->loadRegisterManagerData();
    
    $self->{'currency_format'} = '';
    my $active_currency = Koha::Acquisition::Currencies->get_active;
    $self->{currency_format} = $active_currency->currency if defined($active_currency);
    
    return $self;
}

=head2 passCashRegisterCheck

   C4::CashRegisterManagement->passCashRegisterCheck($branch,$loggedinuser)

The function checks whether cash register management is enabled and the logged in
staff member has a cash register opened for payment actions. If not, cash payment
actions are not allowed.

=cut

sub passCashRegisterCheck {
    my $branch = shift;
    my $loggedinuser = shift;
    
    return true if (! C4::Context->preference('ActivateCashRegisterTransactionsOnly'));
    
    my $cash_register = Koha::CashRegister::CashRegisters->search({
        manager_id => $loggedinuser,
        branchcode => $branch
    });
    
    if ( $cash_register->next() ) {
        return true;
    }
    return false;
}

=head2 loadRegisterManagerData

  $cash_management->loadRegisterManagerData()

Initializer function that reads borrower data of cash register managers.

=cut

sub loadRegisterManagerData {
    my $self= shift;
    my $dbh = C4::Context->dbh;

    my $query = q{
        SELECT distinct b.borrowernumber, b.firstname, b.surname, b.categorycode, b.flags 
        FROM borrowers b
        WHERE    b.borrowernumber IN (SELECT distinct manager_id FROM cash_register) 
              OR b.borrowernumber IN (SELECT distinct prev_manager_id FROM cash_register)
              OR b.borrowernumber IN (SELECT distinct manager_id FROM cash_register_manager)
        ORDER BY b.firstname, b.surname ASC }; 
    $query =~ s/^\s+/ /mg;
    
    my $sth = $dbh->prepare($query);
    $sth->execute();
    
    my %borrowers = ();
    
    while (my $row = $sth->fetchrow_hashref) {
        if ( $row->{firstname} ) {
            $row->{fullname} = $row->{firstname} . ' ' . $row->{surname};
        } else {
            $row->{fullname} = $row->{surname};
        }
        $borrowers{$row->{'borrowernumber'}} = $row;
    }
    $self->{managers}=\%borrowers;
}

=head2 managerHasOpenCashRegister

  $cash_management->managerHasOpenCashRegister($branch,$borrowernumber)

Returns true (1) if the manager has opened a cash register for the branch.
Returns 0 if not;

=cut

sub managerHasOpenCashRegister {
    my $self = shift;
    my $branch = shift;
    my $loggedinuser = shift;
    
    my $cash_register = Koha::CashRegister::CashRegisters->search({
        branchcode => $branch,
        manager_id => $loggedinuser
    });
    
    if ( my $cashreg = $cash_register->next() ) {
        return 1;
    }
    return 0;
}

=head2 registerPayment

  $cash_management->registerPayment($branch, $manager_id, $amount, $accountlines_no)

Registers a payment to the opened cash register of the manager.

=cut

sub registerPayment {
    my ($self, $branch, $manager_id, $amount, $accountlines_no) = @_;
    
    my $cash_register = Koha::CashRegister::CashRegisters->search( {
        manager_id => $manager_id,
        branchcode =>$branch
    });
    
    if ( my $cashreg = $cash_register->next() ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'PAYMENT', $manager_id, '', $amount, $accountlines_no);
    }
    
    return 0;
}

=head2 registerPayment

  $cash_management->registerPayment($branch, $manager_id, $amount, $accountlines_no)

Registers a payment to the opened cash register of the manager.

=cut

sub registerReversePayment {
    my ($self, $branch, $manager_id, $amount, $accountlines_no) = @_;
    
    my $cash_register = Koha::CashRegister::CashRegisters->search( {
        manager_id => $manager_id,
        branchcode =>$branch
    });
    
    if ( my $cashreg = $cash_register->next() ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'REVERSE_PAYMENT', $manager_id, '', ($amount * -1), $accountlines_no);
    }
    
    return 0;
}

=head2 registerAdjustment

  $cash_management->registerAdjustment($branch, $manager_id, $amount, $payment_note)

Registers a payment to the opened cash register of the manager.

=cut

sub registerAdjustment {
    my ($self, $branch, $manager_id, $amount, $comment) = @_;
    
    my $cash_register = Koha::CashRegister::CashRegisters->search( {
        manager_id => $manager_id,
        branchcode =>$branch
    });
    
    if ( my $cashreg = $cash_register->next() ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'ADJUSTMENT', $manager_id, $comment, $amount);
    }
    
    return 0;
}

=head2 registerCashPayment

  $cash_management->registerCashPayment($cash_register_id, $manager_id, $amount, $comment)

The action is used for cash payments. Typically thisis a transfer from the cash register to
the central cash register of the organisation or to a bank.

=cut

sub registerCashPayment {
    my ($self, $branch, $manager_id, $amount, $comment) = @_;
    
    my $cash_register = Koha::CashRegister::CashRegisters->search( {
        manager_id => $manager_id,
        branchcode =>$branch
    });
    
    if ( my $cashreg = $cash_register->next() ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'PAYOUT', $manager_id, $comment, ($amount * -1));
    }
    
    return 0;
}

=head2 registerCredit

  $cash_management->registerCredit($cash_register_id, $manager_id, $amount, $comment)

Koha supports to register deposits. The call is used to register that credit amount.

=cut

sub registerCredit {
    my ($self, $branch, $manager_id, $amount, $accountlines_no) = @_;
    
    my $cash_register = Koha::CashRegister::CashRegisters->search( {
        manager_id => $manager_id,
        branchcode =>$branch
    });
    
    if ( my $cashreg = $cash_register->next() ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'CREDIT', $manager_id, '', $amount, $accountlines_no);
    }
    
    return 0;
}

=head2 getOpenCashRegister

  $cash_management->getOpenCashRegister($borrowernumber)

Returns a cash register if opened by the staff member.

=cut

sub getOpenCashRegister {
    my $self = shift;
    my $loggedinuser = shift;
    my $branch = shift;
    
    my $params = { manager_id => $loggedinuser };
    if ( $branch ) {
        $params->{branchcode} = $branch;
    }
    
    my $cash_register = Koha::CashRegister::CashRegisters->search($params);
    
    if ( my $cashreg = $cash_register->next() ) {
        return $self->loadCashRegister($cashreg->id());
    }
    return undef;
}

=head2 getPermittedCashRegisters

  $cash_management->getPermittedCashRegisters($borrowernumber)

Returns a list of cash registers a staff member is authorized to use.

=cut

sub getPermittedCashRegisters {
    my $self = shift;
    my $loggedinuser = shift;
    my $cash_register = Koha::CashRegister::CashRegisterManagers->search({ 
            manager_id => $loggedinuser
    });
    
    my @cash_registers = ();
    while ( my $cashreg = $cash_register->next() ) {
        if ( my $cash = $self->loadCashRegister($cashreg->cash_register_id()) ) {
            push  @cash_registers,$cash;
        }
    }
    return @cash_registers;
}

=head2 loadCashRegister

  $cash_management->loadCashRegister($cash_register_id)

Read data of a cash register. Returns a hash ref or undef.

=cut

sub loadCashRegister {
    my $self= shift;
    my $cash_register_id = shift;

    my $cash_register_manager = undef;
    my $cash_register_prev_manager = undef;
    
    my $cash_register = Koha::CashRegister::CashRegisters->find({ 
            id => $cash_register_id
        });
    if ( $cash_register ) {
        if ( $cash_register->manager_id() ) {
            if ( exists( $self->{managers}->{$cash_register->manager_id()} ) ) {
                $cash_register_manager = $self->{managers}->{$cash_register->manager_id()}->{fullname};
            }
        }

        if ( $cash_register->prev_manager_id() ) {
            if ( exists( $self->{managers}->{$cash_register->prev_manager_id()} )  ) {
                $cash_register_prev_manager = $self->{managers}->{$cash_register->prev_manager_id()}->{fullname};
            }
        }
        
        my $balance = $self->getCurrentBalance( $cash_register->id());

        return {
            'cash_register_id' => $cash_register->id(),
            'cash_register_name' => $cash_register->name(),
            'cash_register_branchcode' => $cash_register->branchcode(),
            'cash_register_manager_id' => $cash_register->manager_id(),
            'cash_register_manager' => $cash_register_manager,
            'cash_register_prev_manager_id' => $cash_register->prev_manager_id(),
            'cash_register_prev_manager' => $cash_register_prev_manager,
            'cash_register_balance' => sprintf('%.2f', $balance ),
            'cash_register_balance_formatted' => $self->formatAmountWithCurrency($balance)
        };
    }
    return undef;
}

sub formatAmountWithCurrency {
    my $self = shift;
    my $amount = shift;
        
    my $amount_formatted = currency_format($self->{'currency_format'}, $amount, FMT_SYMBOL);
    # if active currency isn't correct ISO code fallback to sprintf
    $amount_formatted = sprintf('%.2f', $amount) unless $amount_formatted;
    
    return $amount_formatted;
}

=head2 getAllCashRegisters

  $cash_management->getAllCashRegisters()

List all adefined cash registerss.

=cut

sub getAllCashRegisters {
    my $self = shift;
    my @cash_registers = ();
    my @cash_register_managers = Koha::CashRegister::CashRegisterManagers->search({});

    foreach my $cashreg (Koha::CashRegister::CashRegisters->search({})) {
    
        my $balance = $self->getCurrentBalance($cashreg->id());
        
        my $cash_register_manager = undef;
        my $cash_register_prev_manager = undef;
    
        if ( $cashreg->manager_id() ) {
            if ( exists( $self->{managers}->{$cashreg->manager_id()} ) ) {
                $cash_register_manager = 
                        $self->{managers}->{$cashreg->manager_id()}->{fullname};
            }
        }
        
        if ( $cashreg->prev_manager_id() ) {
            if ( exists( $self->{managers}->{$cashreg->prev_manager_id()} )  ) {
                $cash_register_prev_manager = 
                        $self->{managers}->{$cashreg->prev_manager_id()}->{fullname};
            }
        }
        
        my $cr = {
            'id' => $cashreg->id(),
            'name'=> $cashreg->name(),
            'branchcode' => $cashreg->branchcode(),
            'manager_id' =>  $cashreg->manager_id(),
            'manager_name' =>  $cash_register_manager,
            'prev_manager_id' => $cashreg->prev_manager_id(),
            'prev_manager_name' =>  $cash_register_prev_manager,
            'balance' => sprintf('%.2f', $balance),
            'balance_formatted' => $self->formatAmountWithCurrency($balance),
            'managers' => []
        };
        foreach my $manager (@cash_register_managers) {
            if ( $cashreg->id() == $manager->cash_register_id() && exists($self->{managers}->{$manager->manager_id()}) ) {
                push @{$cr->{managers}}, $self->{managers}->{$manager->manager_id()};
            }
        }
        push @cash_registers, $cr;
    }
    return @cash_registers;
}

=head2 saveCashRegister

  $cash_management->saveCashRegister($params,$managerIDList,$cash_register_id)

Create or update a cash register. Parameter $params must be a hash ref of cash register
properies such as name and branchcode. 
$managerIDList is a list of borrowernumbers separated by comma. For updates it is
necessary top provide the $cash_register_id.

=cut

sub saveCashRegister {
    my $self = shift;
    my $params = shift;
    my $cash_register_manager_list = shift;
    my $cash_register_id = shift;

    my @cash_register_manager = ();
    if ( $cash_register_manager_list ) {
        @cash_register_manager = split(",",$cash_register_manager_list);
    }
    my $cash_register = undef;
    if ( $cash_register_id ) {
        $cash_register = Koha::CashRegister::CashRegisters->find({ 
            id => $cash_register_id
        });
        if ($cash_register) {
            $cash_register->set($params)->store();
        } 
    } else {
        $cash_register = Koha::CashRegister::CashRegister->new();
        $cash_register->set($params);
        $cash_register->store();
    }
    
    if ( $cash_register ) {
        my $id = $cash_register->id();
        
        $cash_register = Koha::CashRegister::CashRegisters->find({ 
            id => $id
        });
        
        if ( $id ) {
            my $cash_register_managers = Koha::CashRegister::CashRegisterManagers->search({ 
                cash_register_id => $id
            });
            
            my @new_cash_mans = @cash_register_manager;
            my @saved_manager;
            while ( my $manager = $cash_register_managers->next() ) {
                my $sman = $manager->manager_id();
                if (! grep( /^$sman$/, @cash_register_manager ) ) {
                    $manager->delete();
                }
                else {
                    @new_cash_mans = grep { $_ != $sman } @new_cash_mans;
                }
            }
            
            foreach my $newman(@new_cash_mans) {
                my $newmanager = Koha::CashRegister::CashRegisterManager->new();
                my $manparams = {};
                $manparams->{cash_register_id} = $id;
                $manparams->{manager_id}       = $newman;
                $manparams->{authorized_by}    = $self->{'user'};
                $newmanager->set($manparams);
                $newmanager->store();
            }
        }
    }
    return $cash_register;
}


=head2 getCurrentBalance

  $cash_management->readPermittedStaff($cash_register_id)

Returnes the current balance of the of the cash register.

=cut

sub getCurrentBalance {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $cash_register_id = shift;
    
    my $query = q{
        SELECT a.current_balance 
        FROM cash_register_account a
        WHERE a.cash_register_id = ? AND
              id = (SELECT MAX(b.id) FROM cash_register_account b WHERE a.cash_register_id = b.cash_register_id ) 
       }; $query =~ s/^\s+/ /mg;
    my $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id);
    while (my $row = $sth->fetchrow_hashref) {
       return $row->{current_balance};
    }
    return 0.0;
}

=head2 readPermittedStaff

  $cash_management->readPermittedStaff([$cash_register_id])

Return a list of users who are in general permitted to manage cash registers.
The list can be used to select additional users who can manage a cash register.
Optionally, a cash register id can be provided to exclude the users who are already
authorized

=cut

sub readPermittedStaff {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $cashregID = shift;
    
    my $staff_enabled = shift;
    my @permitted_staff = ();
    my %staff_enabled = ();
    
    my @enabled_staff = ();
    
    if ( $cashregID ) {  
        my @enabled_staff = $self->getEnabledStaff($cashregID);
        foreach my $id (@enabled_staff) {
            $staff_enabled{$id->{borrowernumber}} = 1;
        }
    }
    
    # search for users with permission cash_management or for superlibrarians
    my $staffquery = q{
        SELECT distinct b.borrowernumber, b.firstname, b.surname, b.categorycode, b.flags 
        FROM borrowers b
        LEFT JOIN user_permissions u ON b.borrowernumber=u.borrowernumber
        WHERE b.flags%2=1 OR ( u.module_bit = 10 AND code = 'cash_management')};
    # we might exclude those who are already registered as authorized users
    if ( $cashregID ) {
        $staffquery .= q{
        AND NOT EXISTS (SELECT 1 FROM cash_register_manager m WHERE m.manager_id = b.borrowernumber AND m.cash_register_id = ?)};
    }
    # add a nice order by
    $staffquery .= q{
        ORDER BY b.firstname, b.surname ASC }; 
    $staffquery =~ s/^\s+/ /mg;

    my $sth_staff = $dbh->prepare($staffquery);
    if ( $cashregID ) {
        $sth_staff->execute($cashregID);
    } else {
        $sth_staff->execute();
    }
    
    
    while (my $row = $sth_staff->fetchrow_hashref) {
        if (! exists($staff_enabled{$row->{borrowernumber}}) ) {
        push @permitted_staff,$row;
        }
    }
    return @permitted_staff;
}

=head2 readPermittedStaff

  $cash_management->readEnabledStaff([$cash_register_id])

Returns a list of users who authorized to manage a cash register;

=cut

sub getEnabledStaff {
    my $self = shift;
    my $cash_register_id = shift;
    
    my @enabled_staff = ();
    my $dbh = C4::Context->dbh;
    my $query = q{
        SELECT distinct(manager_id) as manager_id
        FROM cash_register_manager
        WHERE cash_register_id = ?
       }; $query =~ s/^\s+/ /mg;
       
    my $sth = $dbh->prepare($query);
    $sth->execute( $cash_register_id);
    while (my $row = $sth->fetchrow_hashref) {
        push @enabled_staff, $self->{managers}->{$row->{manager_id}};
    }
    
    return @enabled_staff;
}

=head2 openCashRegister

  $cash_management->openCashRegister($cash_register_id, $manager_id)

Opens a cash register. As a result of the open action, the manager_id will be set as 
current manager. Additionally, the open action will be added to the cash register account 
transaction table.

=cut

sub openCashRegister {
    my $self = shift;
    my $cash_register_id = shift;
    my $borrowerid = shift;
    
    my $cashreg = Koha::CashRegister::CashRegisters->find({ id => $cash_register_id });
    
    if ( $cashreg ) {
        if (! $cashreg->manager_id() ) {
        my @managerIDs = $self->getEnabledStaff($cash_register_id);
            foreach my $enabled_manager (@managerIDs) {
                if ( $enabled_manager->{borrowernumber} == $borrowerid ) {
                    $cashreg->set( { manager_id => $borrowerid, prev_manager_id =>  $cashreg->prev_manager_id() } );
                    $cashreg->store();
                    return $self->addCashRegisterTransaction($cash_register_id, 'OPEN', $borrowerid);
                }
            }
        }
    }
    
    return 0;
}

=head2 closeCashRegister

  $cash_management->closeCashRegister($cash_register_id, $manager_id)

Close a cash register. The cash will become available for other users. It will
not be possible to perform payment transactions to the cash register until it's 
opened again.

=cut

sub closeCashRegister {
    my $self = shift;
    my $cash_register_id = shift;
    my $borrowerid = shift;
    
    my $cashreg = Koha::CashRegister::CashRegisters->find({ id => $cash_register_id });
    
    if ( $cashreg ) {
        if ( $cashreg->manager_id() && $borrowerid == $cashreg->manager_id() ) {
            $cashreg->set( { manager_id => undef, prev_manager_id =>  $cashreg->manager_id() } );
            $cashreg->store();
            return $self->addCashRegisterTransaction($cash_register_id, 'CLOSE', $borrowerid);
        }
    }
    
    return 0;
}

=head2 getLastBooking

  $cash_management->getLastBooking($cash_register_id)

Returnes the last booking of a cash register.

=cut

sub getLastBooking {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $cash_register_id = shift;
        
    my $query = q{
        SELECT  a.id, a.cash_register_account_id, a.cash_register_id, a.manager_id, a.booking_time, 
                a.accountlines_id, a.current_balance, a.action, a.booking_amount, a.description,
                CONCAT(IFNULL(b.firstname,''), ' ', b.surname) as manager_name
        FROM cash_register_account a, borrowers b
        WHERE id = (SELECT MAX(b.id) FROM cash_register_account b WHERE a.cash_register_id = b.cash_register_id) 
              AND a.manager_id = b.borrowernumber
              AND a.cash_register_id = ?
       }; $query =~ s/^\s+/ /mg;
    my $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id);
    while (my $row = $sth->fetchrow_hashref) {
        my $amount = $row->{booking_amount};
        $row->{booking_amount} = sprintf('%.2f', $amount);
        $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
        my $balance = $row->{current_balance};
        $row->{current_balance} = sprintf('%.2f', $balance);
        $row->{current_balance_formatted} = $self->formatAmountWithCurrency($balance);
        $row->{booking_time} = output_pref ( { dt => dt_from_string($row->{booking_time}) } );
        return $row;
    }
    return undef;
}


=head2 getValidFromToPeriod

  $cash_management->getValidFromToPeriod($from, $to)

Helper function to set a valiad fro/to perod for input parameters. Sets from
to today if not set.

=cut

sub getValidFromToPeriod {
    my $self = shift;
    my $from = shift;
    my $to = shift;
    
    my $date_from;
    my $date_to;
    
    if ( $from ) {
        $date_from = dt_from_string($from);
        if (! $to ) {
            $date_to = DateTime->new(
                year      => $date_from->year,
                month     => $date_from->month,
                day       => $date_from->day,
                hour      => 23,
                minute    => 59,
                second    => 59,
                time_zone => C4::Context->tz
            );
        }
        else {
            $date_to = dt_from_string($to);
            $date_to = DateTime->new(
                year      => $date_to->year,
                month     => $date_to->month,
                day       => $date_to->day,
                hour      => 23,
                minute    => 59,
                second    => 59,
                time_zone => C4::Context->tz
            );
        }
    }
    else {
        $date_from = dt_from_string($from);
        my $now = DateTime->now();
        $date_from = DateTime->new(
            year      => $now->year,
            month     => $now->month,
            day       => $now->day,
            hour      => 0,
            minute    => 0,
            second    => 0,
            time_zone => C4::Context->tz
        );
        $date_to = DateTime->new(
            year      => $now->year,
            month     => $now->month,
            day       => $now->day,
            hour      => 23,
            minute    => 59,
            second    => 59,
            time_zone => C4::Context->tz
        );
    }
    
    return ($date_from, $date_to);
}

=head2 getBookingsSinceLastOpening

  $cash_management->getBookingsSinceLastOpening($cash_register_id)

Returnes the bookings since the previeous opening action.

=cut

sub getBookingsSinceLastOpening {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $cash_register_id = shift;
        
    my $query = q{
        SELECT  a.id, a.cash_register_account_id, a.cash_register_id, a.manager_id, a.booking_time, 
                a.accountlines_id, a.current_balance, a.action, a.booking_amount, a.description,
                CONCAT(IFNULL(b.firstname, ''), IF(b.firstname IS NULL, '', ' '), b.surname) as manager_name,
                CONCAT(IFNULL(o.firstname, ''), IF(o.firstname IS NULL, '', ' '), o.surname) as patron_name,
                l.accounttype, l.note as accountlines_note, 
                l.description as accountlines_description,
                m.title as title
        FROM  cash_register_account a
        LEFT JOIN borrowers b ON a.manager_id = b.borrowernumber
        LEFT JOIN accountlines l ON a.accountlines_id = l.accountlines_id
        LEFT JOIN borrowers o ON o.borrowernumber = l.borrowernumber
        LEFT JOIN items i ON i.itemnumber = l.itemnumber
        LEFT JOIN biblio m ON i.biblionumber = m.biblionumber
        WHERE     a.cash_register_id = ?
              AND a.id >= (SELECT MAX(x.id) 
                           FROM cash_register_account x 
                           WHERE a.cash_register_id = x.cash_register_id 
                             AND x.action = ?)
        ORDER BY id DESC
       }; $query =~ s/^\s+/ /mg;
    my $sth = $dbh->prepare($query);
    $sth->execute( $cash_register_id, 'OPEN');
    
    my @result;
    
    while (my $row = $sth->fetchrow_hashref) {
       my $amount = $row->{booking_amount};
       $row->{booking_amount} = sprintf('%.2f', $amount);
       $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
       my $balance = $row->{current_balance};
       $row->{current_balance} = sprintf('%.2f', $balance);
       $row->{current_balance_formatted} = $self->formatAmountWithCurrency($balance);
       $row->{booking_time} = output_pref ( { dt => dt_from_string($row->{booking_time}) } );
       push @result, $row;
    }

    return \@result;
}

=head2 getBookingsFromTo

  $cash_management->getLastBooking($cash_register_id, $from, $to)

Returnes the bookings from date $from to date $to.

=cut

sub getLastBookingsFromTo {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $cash_register_id = shift;
    my $from = shift;
    my $to = shift;
    my ($date_from,$date_to) = $self->getValidFromToPeriod($from, $to);
        
    my $query = q{
        SELECT  a.id, a.cash_register_account_id, a.cash_register_id, a.manager_id, a.booking_time, 
                a.accountlines_id, a.current_balance, a.action, a.booking_amount, a.description,
                CONCAT(IFNULL(b.firstname,''), IF(b.firstname IS NULL, '', ' '), b.surname) as manager_name,
                CONCAT(IFNULL(o.firstname,''), IF(o.firstname IS NULL, '', ' '), o.surname) as patron_name,
                l.accounttype, l.note as accountlines_note, 
                l.description as accountlines_description,
                m.title as title
        FROM  cash_register_account a
        LEFT JOIN borrowers b ON a.manager_id = b.borrowernumber
        LEFT JOIN accountlines l ON a.accountlines_id = l.accountlines_id
        LEFT JOIN borrowers o ON o.borrowernumber = l.borrowernumber
        LEFT JOIN items i ON i.itemnumber = l.itemnumber
        LEFT JOIN biblio m ON i.biblionumber = m.biblionumber
        WHERE     booking_time >= ? and booking_time <= ?
              AND a.cash_register_id = ?
        ORDER BY id DESC
       }; $query =~ s/^\s+/ /mg;
    my $sth = $dbh->prepare($query);
    $sth->execute( 
            DateTime::Format::MySQL->format_datetime($date_from),
            DateTime::Format::MySQL->format_datetime($date_to),
            $cash_register_id
        );
    
    my @result;
    
    while (my $row = $sth->fetchrow_hashref) {
       my $amount = $row->{booking_amount};
       $row->{booking_amount} = sprintf('%.2f', $amount);
       $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
       my $balance = $row->{current_balance};
       $row->{current_balance} = sprintf('%.2f', $balance);
       $row->{current_balance_formatted} = $self->formatAmountWithCurrency($balance);
       $row->{booking_time} = output_pref ( { dt => dt_from_string($row->{booking_time}) } );
       push @result, $row;
    }

    return (\@result,output_pref({dt => dt_from_string($date_from), dateonly => 1}),output_pref({dt => dt_from_string($date_to), dateonly => 1}));
}

=head2 getLastBooking

  $cash_management->addCashRegisterTransaction($cash_register_id, $action, $manager_id, $comment, $amount, $accountlines_id)

Store a cash register management action.

=cut

sub addCashRegisterTransaction {
    my $self = shift;
    my $cash_register_id = shift;
    my $action = shift;
    my $manager_id = shift;
    my $comment = shift;
    my $amount = shift;
    my $accountlines_id = shift;
    
    if (! $amount ) {
    $amount = 0.00;
    }
    # retrieve last transaction data
    my $lastTransaction = $self->getLastBooking($cash_register_id);
    if (! $lastTransaction ) {
        $lastTransaction = {
            manager_id => undef,
            current_balance => 0.00,
            booking_amount => 0.00
        };
    }
    
    if ( $action eq 'OPEN' ) {
        $accountlines_id = undef;
        $amount = 0.00;
    }
    elsif ( $action eq 'CLOSE' ) {
        $accountlines_id = undef;
        $amount = 0.00;
    }
    elsif ( $action eq 'PAYMENT' ) {
    }
    elsif ( $action eq 'REVERSE_PAYMENT' ) {
    }
    elsif ( $action eq 'PAYOUT' ) {
    }
    elsif ( $action eq 'ADJUSTMENT' ) {
    }
    elsif ( $action eq 'CREDIT' ) {
    }
    else {
        return 0;
    }
    
    my $cash_register_account_id = 0;
    my $dbh = C4::Context->dbh;
    my $query = q{
        SELECT max(cash_register_account_id) as cash_register_account_id
        FROM cash_register_account
        WHERE cash_register_id = ?
       }; $query =~ s/^\s+/ /mg;
       
    my $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id);
    while (my $row = $sth->fetchrow_hashref) {
        if ( $row && $row->{cash_register_account_id} ) {
            $cash_register_account_id = $row->{cash_register_account_id};
        }
    }
    $cash_register_account_id++;
    
    
    # set parameter to store
    my $params = {
        cash_register_id => $cash_register_id,
        cash_register_account_id => $cash_register_account_id,
        manager_id => $manager_id,
        current_balance => $lastTransaction->{current_balance} + $amount,
        booking_amount => $amount,
        accountlines_id => $accountlines_id,
        action => $action,
        description => $comment
    };
    
    my $entry = Koha::CashRegister::CashRegisterAccount->new();
    $entry->set($params);
    $entry->store();
    
    return 1;
}

sub getCashRegisterHandoverInformationByLastOpeningAction {
    my $self = shift;
    my $cash_register_id = shift;
    my $dbh = C4::Context->dbh;
    
    # First we want fo find the last opening action of the cash
    # register
    my $lastOpeningId = 0;
    my $query = q{
        SELECT max(a.id) as id
        FROM   cash_register_account a
        WHERE  a.cash_register_id = ? AND a.action = ?
       }; $query =~ s/^\s+/ /mg;
    my $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id,'OPEN');
    # return { 'id' => $cash_register_id };
    if (my $row = $sth->fetchrow_hashref) {
        if ( $row && $row->{'id'} ) {
            $lastOpeningId =  $row->{'id'};
        }
    }
    $sth->finish;
    
    # lets now retrieve the data of the last oping action
    my $lastOpeningAction = Koha::CashRegister::CashRegisterAccounts->find({ id => $lastOpeningId });
    return undef if (! $lastOpeningAction );
    
    my $result = {
        'opening_balance' => sprintf('%.2f', $lastOpeningAction->current_balance()),
        'opening_balance_formatted' => $self->formatAmountWithCurrency($lastOpeningAction->current_balance()),
        'opening_manager_id' => $lastOpeningAction->manager_id(),
        'opening_booking_time' => output_pref ( { dt => dt_from_string($lastOpeningAction->booking_time()) } ),
        'inpayments_amount' => sprintf('%.2f', 0.00 ),
        'inpayments_amount_formatted' => $self->formatAmountWithCurrency(0.00),
        'inpayments_count' => 0,
        'payouts_amount' => sprintf('%.2f', 0.00 ),
        'payouts_amount_formatted' => $self->formatAmountWithCurrency(0.00),
        'payouts_count' => 0
    };

    
    # read the amount of payments that filled the cash register
    $query = q{
        SELECT sum(a.booking_amount) as amount, count(*) actions
        FROM   cash_register_account a
        WHERE  a.cash_register_id = ? AND a.id > ? AND a.booking_amount > 0.00
       }; $query =~ s/^\s+/ /mg;
    $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id,$lastOpeningId);
    if (my $row = $sth->fetchrow_hashref) {
        if ( $row && $row->{amount} ) {
            $result->{'inpayments_amount'} =  sprintf('%.2f',$row->{amount});
            $result->{'inpayments_amount_formatted'} =  $self->formatAmountWithCurrency($row->{amount});
            $result->{'inpayments_count'} = $row->{actions};
        }
    }
    $sth->finish;
    
    # read the amount of payouts 
    my $payouts_amount = 0.00;
    $query = q{
        SELECT sum(a.booking_amount) as amount, count(*) actions
        FROM   cash_register_account a
        WHERE  a.cash_register_id = ? AND a.id > ? AND a.booking_amount < 0.00
       }; $query =~ s/^\s+/ /mg;
    $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id,$lastOpeningId);
    if (my $row = $sth->fetchrow_hashref) {
        if ( $row && $row->{amount} ) {
            $result->{'payouts_amount'} =  sprintf('%.2f',$row->{amount});
            $result->{'payouts_amount_formatted'} =  $self->formatAmountWithCurrency($row->{amount});
            $result->{'payouts_count'} = $row->{actions};
        }
    }
    $sth->finish;
    
    my $lastbooking = $self->getLastBooking($cash_register_id);
    if ( $lastbooking ) {
        $result->{current_balance} = $lastbooking->{current_balance};
        $result->{current_balance_formatted} = $lastbooking->{current_balance_formatted};
        $result->{last_booking_time} = $lastbooking->{booking_time};
    }
    
    return $result;
}

1;
