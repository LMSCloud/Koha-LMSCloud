package C4::CashRegisterManagement;

# Copyright 2016-2019 (C) LMSCLoud GmbH
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
use Carp;

use C4::Context;
use C4::Koha;

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
use Storable qw(dclone);
use Koha::ItemTypes;
use Koha::Libraries;

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
    
    $self->{'currency_format'} = 'USD';
    my $active_currency = Koha::Acquisition::Currencies->get_active;
    $self->{currency_format} = $active_currency->currency if defined($active_currency);
    
    return $self;
}

=head2 getCurrencyFormatterData

   C4::CashRegisterManagement->getCurrencyFormatterData()

Delivers an array ref with currency formatter data such as currency, currency symbol, 
decimal_precision, thousands_separator, and decimal_separator

=cut

sub getCurrencyFormatterData {
    my $self = shift();
    
    my $currency = $self->{currency_format};
    return [$currency,currency_symbol($currency),decimal_precision($currency),decimal_separator($currency),thousands_separator($currency)];
}

=head2 getEffectiveBranchcode

  C4::CashRegisterManagement::getEffectiveBranchcode($branch)

Returns the branchcode of the assigned book mobile if $branch is the branchcode of a book mobile station; 
returns $branch otherwise.

=cut

sub getEffectiveBranchcode {
    my $branch = shift;
    
    # If logged in as a book mobile station, the cash register of the assigned book mobile has to be used;
    # cash registers for book mobile station make no sense and therefore can not be created.
    my %assignedBookMobileBranchcode = ();
    my $branches = { map { $_->branchcode => $_->unblessed } Koha::Libraries->search };
    for my $branchi (sort { $branches->{$a}->{branchcode} cmp $branches->{$b}->{branchcode} } keys %$branches) {
        if ( $branches->{$branchi}->{'mobilebranch'} ) {
            $assignedBookMobileBranchcode{$branchi} = $branches->{$branchi}->{'mobilebranch'};
        }
    }
    
    if ( defined($branch) && exists($assignedBookMobileBranchcode{$branch}) ) {
        $branch = $assignedBookMobileBranchcode{$branch};
    }
    return $branch
}

=head2 passCashRegisterCheck

   C4::CashRegisterManagement->passCashRegisterCheck($branch,$loggedinuser)

If Cash register management is disabled, this function returns true.
The function checks whether cash register management is enabled and the logged in
staff member has a cash register opened for payment actions. If not, cash payment
actions are not allowed.

=cut

sub passCashRegisterCheck {
    my $branch = shift;
    my $loggedinuser = shift;
    
    return true if (! C4::Context->preference('ActivateCashRegisterTransactionsOnly'));
    if ( getOpenedCashRegister($branch,$loggedinuser) ) {
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
        SELECT distinct manager_id as borrowernumber FROM cash_register
        UNION ALL
        SELECT distinct prev_manager_id as borrowernumber FROM cash_register
        UNION ALL
        SELECT distinct manager_id as borrowernumber FROM cash_register_manager };
    $query =~ s/^\s+/ /mg;
    
    my $sth = $dbh->prepare($query);
    $sth->execute();
    
    my %borrowers = ();
    
    while ( my $row = $sth->fetchrow_hashref ) {
        if ( $row->{'borrowernumber'} ) {
            $borrowers{$row->{'borrowernumber'}} = $row;
        }
    }
    $sth->finish();

    my $query_bor = q{
        SELECT b.borrowernumber, b.firstname, b.surname, b.categorycode, b.flags
        FROM borrowers b
        WHERE b.borrowernumber = ? };
    my $sth_bor = $dbh->prepare($query_bor);
    
    my $query_delbor = q{
        SELECT b.borrowernumber, b.firstname, b.surname, b.categorycode, b.flags
        FROM deletedborrowers b
        WHERE b.borrowernumber = ? };
    my $sth_delbor = $dbh->prepare($query_delbor);

    foreach my $borrowernumber ( keys %borrowers ) {
        if ( $borrowernumber ) {
            $sth_bor->execute($borrowernumber);
            my $row_bor = $sth_bor->fetchrow_hashref;
            if ( ! $row_bor  ) {
                $sth_delbor->execute($borrowernumber);
                $row_bor = $sth_delbor->fetchrow_hashref;
            }
            if ( $row_bor ) {
                $borrowers{$borrowernumber}->{firstname} = $row_bor->{firstname};
                $borrowers{$borrowernumber}->{surname} = $row_bor->{surname};
                $borrowers{$borrowernumber}->{categorycode} = $row_bor->{categorycode};
                $borrowers{$borrowernumber}->{flags} = $row_bor->{flags};
            }
            if ( $borrowers{$borrowernumber}->{firstname} ) {
                $borrowers{$borrowernumber}->{fullname} = $borrowers{$borrowernumber}->{firstname} . ' ' . $borrowers{$borrowernumber}->{surname};
            } else {
                $borrowers{$borrowernumber}->{fullname} = $borrowers{$borrowernumber}->{surname};
            }
        }
    }
    $sth_delbor->finish();
    $sth_bor->finish();

    $self->{managers} = \%borrowers;
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
    
    if ( getOpenedCashRegister($branch,$loggedinuser) ) {
        return true;
    }
    return false;
}

=head2 getOpenedCashRegister

  C4::CashRegisterManagement->getOpenedCashRegister($branch,$borrowernumber)

Return a opened cash register or undef if cash register managment is inactive or
if the user has no open cash register.
If a cash register is open, the function returns Koha::CashRegister::CashRegister object.

=cut

sub getOpenedCashRegister {
    my $branch = shift;
    my $loggedinuser = shift;
    
    if (! C4::Context->preference('ActivateCashRegisterTransactionsOnly')) {
        return undef;
    }
    $branch = getEffectiveBranchcode($branch);
        
    if (! C4::Context->preference('PermitConcurrentCashRegisterUsers')) {
        my $cash_register = Koha::CashRegister::CashRegisters->search({
            -and => [
                -or => [
                        branchcode => $branch,
                        no_branch_restriction => 1
                    ],
                manager_id => $loggedinuser
                ]
        });
        
        if ( my $cashreg = $cash_register->next() ) {
            return $cashreg;
        }
    }
    else {
        # check whether the cash register is marked es opened by the manager
        my $dbh = C4::Context->dbh;
        my $query = q{
                SELECT DISTINCT c.id as id
                FROM cash_register c, cash_register_manager m
                WHERE     (c.branchcode = ? or c.no_branch_restriction = 1)
                      AND c.id = m.cash_register_id
                      AND m.manager_id = ?
                      AND m.opened = 1 }; 
        $query =~ s/^\s+/ /mg;
        
        my $sth = $dbh->prepare($query);
        $sth->execute($branch, $loggedinuser);
        if (my $row = $sth->fetchrow_hashref) {
            my $cashreg = Koha::CashRegister::CashRegisters->find({ 
                id => $row->{id}
            });
            $sth->finish();
            return $cashreg;
        }
        $sth->finish();
    }
    return undef;
}

=head2 getOpenedCashRegisterByManagerID

  C4::CashRegisterManagement->getOpenedCashRegisterByManagerID($borrowernumber)

Return an opened cash register or undef if cash register managment is inactive or
if the user has no open cash register.
If a cash register is open, the function returns Koha::CashRegister::CashRegister object.

=cut

sub getOpenedCashRegisterByManagerID {
    my $self = shift;
    my $loggedinuser = shift;
    
    if (! C4::Context->preference('ActivateCashRegisterTransactionsOnly')) {
        return undef;
    }
        
    if (! C4::Context->preference('PermitConcurrentCashRegisterUsers')) {
        my $cash_register = Koha::CashRegister::CashRegisters->search({
            manager_id => $loggedinuser
        });
        
        if ( my $cashreg = $cash_register->next() ) {
            return $self->loadCashRegister($cashreg->id);
        }
    }
    else {
        # check whether the cash register is marked es opened by the manager
        my $dbh = C4::Context->dbh;
        my $query = q{
                SELECT DISTINCT c.id as id
                FROM cash_register c, cash_register_manager m
                WHERE     c.id = m.cash_register_id
                      AND m.manager_id = ?
                      AND m.opened = 1 }; 
        $query =~ s/^\s+/ /mg;
        
        my $sth = $dbh->prepare($query);
        $sth->execute($loggedinuser);
        if (my $row = $sth->fetchrow_hashref) {
            $sth->finish();
            return $self->loadCashRegister($row->{id});
        }
        $sth->finish();
    }
    return undef;
}

=head2 registerPayment

  $cash_management->registerPayment($branch, $manager_id, $amount, $accountlines_no)

Registers a payment to the opened cash register of the manager.

=cut

sub registerPayment {
    my ($self, $branch, $manager_id, $amount, $accountlines_no) = @_;
    
    my $cashreg = getOpenedCashRegister($branch, $manager_id);
    if ( $cashreg ) {
        return $self->addCashRegisterTransaction($cashreg->id(), 'PAYMENT', $manager_id, '', $amount, '', $accountlines_no);
    }
    
    return 0;
}

=head2 registerPayment

  $cash_management->registerPayment($branch, $manager_id, $amount, $accountlines_no)

Registers a payment to the opened cash register of the manager.

=cut

sub registerReversePayment {
    my ($self, $branch, $manager_id, $amount, $accountlines_no) = @_;
    
    my $cashreg = getOpenedCashRegister($branch, $manager_id);
    if ( $cashreg ) {
        return $self->addCashRegisterTransaction($cashreg->id(), 'REVERSE_PAYMENT', $manager_id, '', ($amount * -1), '', $accountlines_no);
    }
    
    return 0;
}

=head2 registerAdjustment

  $cash_management->registerAdjustment($branch, $manager_id, $amount, $payment_note, $reason)

Registers a payment to the opened cash register of the manager.

=cut

sub registerAdjustment {
    my ($self, $branch, $manager_id, $amount, $comment, $reason) = @_;
    
    my $cashreg = getOpenedCashRegister($branch, $manager_id);
    if ($cashreg ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'ADJUSTMENT', $manager_id, $comment, $amount, $reason);
    }
    
    return 0;
}

=head2 registerCashPayment

  $cash_management->registerCashPayment($cash_register_id, $manager_id, $amount, $comment, $reason)

The action is used for cash payments. Typically thisis a transfer from the cash register to
the central cash register of the organisation or to a bank.

=cut

sub registerCashPayment {
    my ($self, $branch, $manager_id, $amount, $comment, $reason) = @_;
    
    my $cashreg = getOpenedCashRegister($branch, $manager_id);
    if ($cashreg ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'PAYOUT', $manager_id, $comment, ($amount * -1), $reason);
    }
    
    return 0;
}

=head2 registerCashDeposit

  $cash_management->registerCashDeposit($cash_register_id, $manager_id, $amount, $comment, $reason)

The action is used for cash deposits.

=cut

sub registerCashDeposit {
    my ($self, $branch, $manager_id, $amount, $comment, $reason) = @_;
    
    my $cashreg = getOpenedCashRegister($branch, $manager_id);
    if ($cashreg ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'DEPOSIT', $manager_id, $comment, $amount , $reason);
    }
    
    return 0;
}

=head2 registerCredit

  $cash_management->registerCredit($cash_register_id, $manager_id, $amount, $comment)

Koha supports to register deposits. The call is used to register that credit amount.

=cut

sub registerCredit {
    my ($self, $branch, $manager_id, $amount, $accountlines_no) = @_;
    
    my $cashreg = getOpenedCashRegister($branch, $manager_id);
    if ( $cashreg ) {
        $self->addCashRegisterTransaction($cashreg->id(), 'CREDIT', $manager_id, '', $amount, '', $accountlines_no);
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
    
    my $cashreg = getOpenedCashRegister($branch, $loggedinuser);
    
    if ( $cashreg ) {
        return $self->loadCashRegister($cashreg->id());
    }
    return undef;
}

=head2 canOpenCashRegister

  my $isAllowed = $cash_management->canOpenCashRegister($cash_register_id,$manager_id)

Checks whether a cash register can be opend by a manager.

=cut

sub canOpenCashRegister {
    my $self = shift;
    my $cash_register_id = shift;
    my $borrowerid = shift;
    
    my $concurrentBookingsEnabled = (C4::Context->preference('PermitConcurrentCashRegisterUsers') || 0);

    # check whether the cash register is marked es opened by the manager
    my $dbh = C4::Context->dbh;
    my $query = q{
            SELECT distinct c.id 
            FROM cash_register c, cash_register_manager m
            WHERE     c.id = ? 
                  AND c.id = m.cash_register_id
                  AND (
                    ( 1 = ? AND m.manager_id = ? AND m.opened = 0 )
                    OR
                    ( 0 = ? AND (c.manager_id IS NULL or c.manager_id = '') )
                  ) }; 
    $query =~ s/^\s+/ /mg;
        
    my $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id, $concurrentBookingsEnabled, $borrowerid, $concurrentBookingsEnabled);
    my $result = false;
    if ( my $row = $sth->fetchrow_hashref ) {
        $result = true;
    }
    $sth->finish();
    return $result;
}

=head2 canCloseCashRegister

  my $isAllowed = $cash_management->canCloseCashRegister($cash_register_id,$manager_id)

Checks whether a cash register can be closed by a manager.

=cut

sub canCloseCashRegister {
    my $self = shift;
    my $cash_register_id = shift;
    my $borrowerid = shift;
    
    my $concurrentBookingsEnabled = 0;
    if (C4::Context->preference('PermitConcurrentCashRegisterUsers')) {
        $concurrentBookingsEnabled = 1;
    }
    # check whether the cash register is marked es opened by the manager
    my $dbh = C4::Context->dbh;
    my $query = q{
            SELECT distinct c.id 
            FROM cash_register c, cash_register_manager m
            WHERE     c.id = ? 
                  AND c.id = m.cash_register_id
                  AND (
                    ( 1 = ? AND m.manager_id = ? AND m.opened = 1 )
                    OR
                    ( 0 = ? AND c.manager_id = ? )
                  )}; 
    $query =~ s/^\s+/ /mg;
        
    my $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id, $concurrentBookingsEnabled, $borrowerid, $concurrentBookingsEnabled, $borrowerid);
    my $result = false;
    if (my $row = $sth->fetchrow_hashref) {
        $result = true;
    }
    $sth->finish();
    return $result;
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
            'cash_register_balance_formatted' => $self->formatAmountWithCurrency($balance),
            'cash_register_no_branch_restriction' => $cash_register->no_branch_restriction()
        };
    }
    return undef;
}

=head2 readCashRegisterIdByName

  $cash_register_id = $cash_management->readCashRegisterIdByName($cash_register_name)

Read cash_register_id of a cash register, selected by cash_register.name (is unique). Returns the id or undef.

=cut

sub readCashRegisterIdByName {
    my $self = shift;
    my $cash_register_name = shift;

    my $cash_register_id = undef;
    
    my $cash_register = Koha::CashRegister::CashRegisters->search({ name => $cash_register_name })->next();
    if ( $cash_register ) {
        $cash_register_id = $cash_register->id();
    }
    return $cash_register_id;
}

=head2 formatAmountWithCurrency

  my $formattedAmount = $cash_management->formatAmountWithCurrency($amount)

Helper finction to format a booking amounz with currency..

=cut

sub formatAmountWithCurrency {
    my $self = shift;
    my $amount = shift;
        
    my $amount_formatted = currency_format($self->{'currency_format'}, $amount || 0.0, FMT_SYMBOL);
    # if active currency isn't correct ISO code fallback to sprintf
    $amount_formatted = sprintf('%.2f', $amount || 0.0) unless $amount_formatted;
    
    return $amount_formatted;
}

=head2 getAllCashRegisters

 my @cashRegisterList = $cash_management->getAllCashRegisters()

List all defined cash registerss.

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
            'no_branch_restriction' => $cashreg->no_branch_restriction(),
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

  $cash_management->getCurrentBalance($cash_register_id)

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
        WHERE b.flags%2=1 OR b.flags&1024 > 0 OR ( u.module_bit = 10 AND code = 'cash_management')};
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
        if (!$cashreg->manager_id() || C4::Context->preference('PermitConcurrentCashRegisterUsers')) {
            my @managerIDs = $self->getEnabledStaff($cash_register_id);
            foreach my $enabled_manager (@managerIDs) {
                if ( $enabled_manager->{borrowernumber} == $borrowerid ) {
                    # set the cash register manger if not already opened
                    if ( !$cashreg->manager_id() ) {
                        $cashreg->set( { manager_id => $borrowerid, prev_manager_id => $cashreg->prev_manager_id() } );
                        $cashreg->store();
                        $self->addCashRegisterTransaction($cash_register_id, 'OPEN', $borrowerid);
                    }
                    my $cashmans = Koha::CashRegister::CashRegisterManagers->search({
                        cash_register_id => $cash_register_id,
                        manager_id => $borrowerid
                    });
                    if ( my $manager = $cashmans->next() ) {
                        $manager->set( { opened => 1 });
                        $manager->store();
                    }
                    return true;
                }
            }
        }
    }
    
    return false;
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
        if ( ($cashreg->manager_id() && $borrowerid == $cashreg->manager_id()) || C4::Context->preference('PermitConcurrentCashRegisterUsers') ) {
        
            my $cashmans = Koha::CashRegister::CashRegisterManagers->search({
                cash_register_id => $cash_register_id
            });
            
            # find out, how many staff members opened the cash register
            my $cashmans_opened_register = 0;
            while ( my $manager = $cashmans->next() ) {
                if ( $manager->opened ) {
                    if ( $manager->manager_id == $borrowerid ) {
                        $manager->set( { opened => 0 });
                        $manager->store();
                    } else {
                        $cashmans_opened_register++;
                    }
                }
            }
            if ( $cashmans_opened_register == 0 ) {
                $cashreg->set( { manager_id => undef, prev_manager_id => $cashreg->manager_id() } );
                $cashreg->store();
                return $self->addCashRegisterTransaction($cash_register_id, 'CLOSE', $borrowerid);
            }
            return true;
        }
    }
    
    return false;
}


=head2 smartCloseCashRegister

  $cash_management->smartCloseCashRegister($cash_register_id, $manager_id)

A smart close action can be used if concurrent booking actions are allowed 
for cash registers. Since multiple users can have opened a cash register, all but
the last user one can close the cash register without confirming the cash balance.

=cut

sub smartCloseCashRegister {
    my $self = shift;
    my $cash_register_id = shift;
    my $borrowerid = shift;
    
    my $cashreg = Koha::CashRegister::CashRegisters->find({ id => $cash_register_id });
    
    if ( $cashreg ) {
        if ( C4::Context->preference('PermitConcurrentCashRegisterUsers') ) {
        
            my $cashmans = Koha::CashRegister::CashRegisterManagers->search({
                cash_register_id => $cash_register_id
            });
            
            # find out, how many staff members opened the cash register
            my $cashmans_opened_register = 0;
            while ( my $manager = $cashmans->next() ) {
                if ( $manager->opened && $manager->manager_id != $borrowerid ) {
                    $cashmans_opened_register++;
                }
            }
            if ( $cashmans_opened_register > 0 ) {
                $cashmans->reset();
                while ( my $manager = $cashmans->next() ) {
                    if ( $manager->opened && $manager->manager_id == $borrowerid ) {
                         $manager->set( { opened => 0 });
                         $manager->store();
                         return true;
                    }
                }
            }
        }
    }
    
    return false;
}

=head2 getLastBooking

  $cash_management->getLastBooking($cash_register_id)

Returnes the last booking of a cash register.

=cut

sub getLastBooking {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $cash_register_id = shift;
    my $row = undef;
        
    my $query = q{
        SELECT  a.id, a.cash_register_account_id, a.cash_register_id, a.manager_id, a.booking_time, 
                a.accountlines_id, a.current_balance, a.action, a.booking_amount, a.description
        FROM cash_register_account a
        WHERE a.id = (SELECT MAX(b.id) FROM cash_register_account b WHERE b.cash_register_id = ?) 
              AND a.cash_register_id = ?
       }; $query =~ s/^\s+/ /mg;
    my $sth = $dbh->prepare($query);

    my $query_bor = q{
        SELECT b.borrowernumber, b.firstname, b.surname
        FROM borrowers b
        WHERE b.borrowernumber = ? };
    my $sth_bor = $dbh->prepare($query_bor);
    
    my $query_delbor = q{
        SELECT b.borrowernumber, b.firstname, b.surname
        FROM deletedborrowers b
        WHERE b.borrowernumber = ? };
    my $sth_delbor = $dbh->prepare($query_delbor);


    $sth->execute($cash_register_id, $cash_register_id);

    if ($row = $sth->fetchrow_hashref) {
        $row->{manager_name} = '';

        my $amount = $row->{booking_amount};
        $row->{booking_amount} = sprintf('%.2f', $amount);
        $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
        my $balance = $row->{current_balance};
        $row->{current_balance} = sprintf('%.2f', $balance);
        $row->{current_balance_formatted} = $self->formatAmountWithCurrency($balance);
        $row->{booking_time} = output_pref ( { dt => dt_from_string($row->{booking_time}) } );
        
        # read required record from borrowers or deletedborrowers for getting manager_name
        if ( $row->{manager_id} ) {
            my $borrower_is_deleted = 0;
            $sth_bor->execute($row->{manager_id});
            my $row_bor = $sth_bor->fetchrow_hashref;
            if ( ! $row_bor  ) {
                $borrower_is_deleted = 1;
                $sth_delbor->execute($row->{manager_id});
                $row_bor = $sth_delbor->fetchrow_hashref;
            }
            if ( $row_bor ) {
                $row->{manager_name} = length($row_bor->{firstname}) ? $row_bor->{firstname} . ' ' . $row_bor->{surname} : $row_bor->{surname};
            }
            $row->{manager_is_deleted} = $borrower_is_deleted;
        }
    }
    $sth_delbor->finish();
    $sth_bor->finish();
    $sth->finish();

    return $row;
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
    my $asdate = shift;
    
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
            if ( DateTime->compare( $date_from, $date_to ) == 0 && $date_to->hour == 0 && $date_to->minute == 0  ) {
                $date_to = DateTime->new(
                    year      => $date_to->year,
                    month     => $date_to->month,
                    day       => $date_to->day,
                    hour      => 23,
                    minute    => 59,
                    second    => 59,
                    time_zone => C4::Context->tz
                );
            } else {
                $date_to = DateTime->new(
                    year      => $date_to->year,
                    month     => $date_to->month,
                    day       => $date_to->day,
                    hour      => $date_to->hour,
                    minute    => $date_to->minute,
                    second    => 59,
                    time_zone => C4::Context->tz
                );
            }
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
                a.accountlines_id, a.current_balance, a.action, a.booking_amount, a.description, a.reason,
                l.accounttype, l.note as accountlines_note, 
                l.description as accountlines_description,
                l.borrowernumber,
                m.title as title
        FROM  cash_register_account a
        LEFT JOIN accountlines l ON a.accountlines_id = l.accountlines_id
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
    
    my %borrowers = ();

    my $query_bor = q{
        SELECT b.borrowernumber, b.firstname, b.surname
        FROM borrowers b
        WHERE b.borrowernumber = ? };
    my $sth_bor = $dbh->prepare($query_bor);
    
    my $query_delbor = q{
        SELECT b.borrowernumber, b.firstname, b.surname
        FROM deletedborrowers b
        WHERE b.borrowernumber = ? };
    my $sth_delbor = $dbh->prepare($query_delbor);

    $sth->execute( $cash_register_id, 'OPEN');
    
    my @result;
    
    while (my $row = $sth->fetchrow_hashref) {
        my $amount = $row->{booking_amount};
        $row->{booking_amount} = sprintf('%.2f', $amount);
        $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
        my $balance = $row->{current_balance};
        $row->{current_balance} = sprintf('%.2f', $balance);
        $row->{current_balance_formatted} = $self->formatAmountWithCurrency($balance);
        
        # read required record from borrowers or deletedborrowers for getting manager_name and patron_name
        foreach my $borr ( { id => 'manager_id', desig_name => 'manager_name', desig_isdel => 'manager_is_deleted' }, { id => 'borrowernumber', desig_name => 'patron_name', desig_isdel => 'patron_is_deleted' } ) {
            if ( $row->{$borr->{id}} ) {
                if ( ! exists $borrowers{$row->{$borr->{id}}} ) {
                    my $borrower_is_deleted = 0;
                    $sth_bor->execute($row->{$borr->{id}});
                    my $row_bor = $sth_bor->fetchrow_hashref;
                    if ( ! $row_bor  ) {
                        $borrower_is_deleted = 1;
                        $sth_delbor->execute($row->{$borr->{id}});
                        $row_bor = $sth_delbor->fetchrow_hashref;
                    }
                    if ( $row_bor ) {
                        $borrowers{$row->{$borr->{id}}}->{fullname} = length($row_bor->{firstname}) ? $row_bor->{firstname} . ' ' . $row_bor->{surname} : $row_bor->{surname};
                    } else {
                        $borrowers{$row->{$borr->{id}}}->{fullname} = '';
                    }
                    $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted} = $borrower_is_deleted;
                }
                $row->{$borr->{desig_name}} = $borrowers{$row->{$borr->{id}}}->{fullname};
                $row->{$borr->{desig_isdel}} = $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted};
            } else {
                $row->{$borr->{desig_name}} = '';
                $row->{$borr->{desig_isdel}} = 1;
            }
        }

        push @result, $row;
    }
    $sth_delbor->finish();
    $sth_bor->finish();
    $sth->finish();

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
        SELECT  a.id, a.cash_register_account_id, a.cash_register_id, a.manager_id, l.borrowernumber, a.booking_time, 
                a.accountlines_id, a.current_balance, a.action, a.booking_amount, a.description, a.reason, 
                l.accounttype, l.note as accountlines_note, 
                l.description as accountlines_description,
                m.title as title, l.borrowernumber
        FROM  cash_register_account a
        LEFT JOIN accountlines l ON a.accountlines_id = l.accountlines_id
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
    
    my %borrowers = ();

    my $query_bor = q{
        SELECT b.borrowernumber, b.firstname, b.surname
        FROM borrowers b
        WHERE b.borrowernumber = ? };
    my $sth_bor = $dbh->prepare($query_bor);
    
    my $query_delbor = q{
        SELECT b.borrowernumber, b.firstname, b.surname
        FROM deletedborrowers b
        WHERE b.borrowernumber = ? };
    my $sth_delbor = $dbh->prepare($query_delbor);

    my @result;
    
    while (my $row = $sth->fetchrow_hashref) {
        my $amount = $row->{booking_amount};
        $row->{booking_amount} = sprintf('%.2f', $amount);
        $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
        my $balance = $row->{current_balance};
        $row->{current_balance} = sprintf('%.2f', $balance);
        $row->{current_balance_formatted} = $self->formatAmountWithCurrency($balance);
        
        # read required record from borrowers or deletedborrowers for getting manager_name and patron_name
        foreach my $borr ( { id => 'manager_id', desig_name => 'manager_name', desig_isdel => 'manager_is_deleted' }, { id => 'borrowernumber', desig_name => 'patron_name', desig_isdel => 'patron_is_deleted' } ) {
            if ( $row->{$borr->{id}} ) {
                if ( ! exists $borrowers{$row->{$borr->{id}}} ) {
                    my $borrower_is_deleted = 0;
                    $sth_bor->execute($row->{$borr->{id}});
                    my $row_bor = $sth_bor->fetchrow_hashref;
                    if ( ! $row_bor  ) {
                        $borrower_is_deleted = 1;
                        $sth_delbor->execute($row->{$borr->{id}});
                        $row_bor = $sth_delbor->fetchrow_hashref;
                    }
                    if ( $row_bor ) {
                        $borrowers{$row->{$borr->{id}}}->{fullname} = length($row_bor->{firstname}) ? $row_bor->{firstname} . ' ' . $row_bor->{surname} : $row_bor->{surname};
                    } else {
                        $borrowers{$row->{$borr->{id}}}->{fullname} = '';
                    }
                    $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted} = $borrower_is_deleted;
                }
                $row->{$borr->{desig_name}} = $borrowers{$row->{$borr->{id}}}->{fullname};
                $row->{$borr->{desig_isdel}} = $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted};
            } else {
                $row->{$borr->{desig_name}} = '';
                $row->{$borr->{desig_isdel}} = 1;
            }
        }

        push @result, $row;
    }
    $sth_delbor->finish();
    $sth_bor->finish();
    $sth->finish();

    return (\@result,output_pref({dt => dt_from_string($date_from), dateonly => 0}),output_pref({dt => dt_from_string($date_to), dateonly => 0}));
}

=head2 getCashRegisterPaymentAndDepositOverview

  $cash_management->getLastBooking($cash_register_id, $from, $to)

Return an aggregated overview of payments and deposits of a cash register for a selected period.

=cut

sub getCashRegisterPaymentAndDepositOverview {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $cash_register_id = shift;
    my $from = shift;
    my $to = shift;
    my ($date_from,$date_to) = $self->getValidFromToPeriod($from, $to);

    my $authValuesAll = {};
    my $authValues = GetAuthorisedValues("CASHREG_PAYOUT",0);
    foreach my $val( @$authValues ) { $authValuesAll->{'PAYOUT'}->{$val->{authorised_value}} = $val->{lib} };
    $authValues = GetAuthorisedValues("CASHREG_DEPOSIT",0);
    foreach my $val( @$authValues ) { $authValuesAll->{'DEPOSIT'}->{$val->{authorised_value}} = $val->{lib} };
    $authValues = GetAuthorisedValues("CASHREG_ADJUST",0);
    foreach my $val( @$authValues ) { $authValuesAll->{'ADJUSTMENT'}->{$val->{authorised_value}} = $val->{lib} };
    
    my $query = q{
        SELECT c.action, sum(c.booking_amount) as booking_amount, c.reason, l.accounttype
        FROM   cash_register_account c
        LEFT JOIN accountlines l ON c.accountlines_id = l.accountlines_id
        WHERE     booking_time >= ? and booking_time <= ?
              AND c.booking_amount <> 0
              AND cash_register_id = ?
        GROUP BY c.action, c.reason, l.accounttype
       }; $query =~ s/^\s+/ /mg;
    my $sth = $dbh->prepare($query);
    $sth->execute( 
            DateTime::Format::MySQL->format_datetime($date_from),
            DateTime::Format::MySQL->format_datetime($date_to),
            $cash_register_id
        );
    
    my $result = { 'INPAYMENT' => [], 'OUTPAYMENT' => [] }; 
    my $suminpayment = 0.0;
    my $sumoutpayment = 0.0;
    while (my $row = $sth->fetchrow_hashref) {

        my $amount = $row->{booking_amount};
        my $ptype = 'INPAYMENT';
        $ptype = 'OUTPAYMENT' if ($amount < 0.0);
        
        $suminpayment += $amount if ( $ptype eq 'INPAYMENT' );
        $sumoutpayment += $amount if ( $ptype eq 'OUTPAYMENT' );
        
        $row->{booking_amount} = sprintf('%.2f', $amount);
        $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
        
        # check whether we can deliver the description of a reason from authorised 
        # values if defined
        if ( defined($row->{reason}) && exists( $authValuesAll->{$row->{action}}->{$row->{reason}} ) ) {
             $row->{reason} = $authValuesAll->{$row->{action}}->{$row->{reason}};
        }

        push @{$result->{$ptype}}, $row;
    }
    
    $result->{SUM_INPAYMENT} = { 
        'booking_amount'           => sprintf('%.2f', $suminpayment),
        'booking_amount_formatted' => $self->formatAmountWithCurrency($suminpayment)
    };
    $result->{SUM_OUTPAYMENT} = { 
        'booking_amount'           => sprintf('%.2f', $sumoutpayment),
        'booking_amount_formatted' => $self->formatAmountWithCurrency($sumoutpayment)
    };
    
    $result->{type} = 'inoutpaymentoverview';
    
    return ($result,output_pref({dt => dt_from_string($date_from), dateonly => 0}),output_pref({dt => dt_from_string($date_to), dateonly => 0}));
}

=head2 getFinesOverviewByBranch

  $cash_management->getFinesOverviewByBranch($branchcode,$from,$to)

This function returns an overview of fines by type.

=cut

sub getFinesOverview {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    
    # read parameters
    my $params           = shift;
    my $branchcode       = defined($params->{branchcode}) ? $params->{branchcode} : undef;
    my $from             = $params->{from};
    my $to               = $params->{to};
    my $type             = $params->{type};
    my $cash_register_id = $params->{cash_register_id};
    $branchcode = getEffectiveBranchcode($branchcode);

  
    # initialization of processing
    $type = 'accounttype' if ( ! $type );
    my ($date_from,$date_to) = $self->getValidFromToPeriod($from, $to);
    my $result = {};
    $result->{type} = $type;
    my $ACCOUNT_TYPE_LENGTH = 5;
    
    # read manual invoice types
    my %manual_invtypes;
    foreach my $inv_type(@{$dbh->selectcol_arrayref(qq{SELECT authorised_value FROM authorised_values WHERE category = 'MANUAL_INV'})}) {
        my $val = substr($inv_type, 0, $ACCOUNT_TYPE_LENGTH);
        $manual_invtypes{$val} = $inv_type;
    }
    
    # read itemtypes
    my %itemtypes;
    foreach my $it(Koha::ItemTypes->search) {
        $itemtypes{$it->itemtype} = $it->description;
    }
    
    my $branchselect = '';
    my $cashregisterselect = '';
    if ( $branchcode ) {
        $branchselect = "AND ( br.branchcode = " . $dbh->quote($branchcode) . " OR br.mobilebranch = " . $dbh->quote($branchcode) . " )";
        $cashregisterselect = "AND (r.no_branch_restriction = 1 OR br.branchcode = " . $dbh->quote($branchcode) . " OR br.mobilebranch = " . $dbh->quote($branchcode) . " )";
    }

    my $tmpdate = dclone($date_to);
    
    # set dateselect
    my $fmtfrom = DateTime::Format::MySQL->format_datetime($date_from);
    my $fmtto = DateTime::Format::MySQL->format_datetime($tmpdate);
    my $dateselect = "ao.created_on BETWEEN '$fmtfrom' AND '$fmtto'";
    my $cashdateselect = "c.booking_time BETWEEN '$fmtfrom' AND '$fmtto'";
    
    my $authValuesAll;
    my $authValues = GetAuthorisedValues("CASHREG_PAYOUT",0);
    foreach my $val( @$authValues ) { $authValuesAll->{'PAYOUT'}->{$val->{authorised_value}} = $val->{lib} };
    $authValues = GetAuthorisedValues("CASHREG_DEPOSIT",0);
    foreach my $val( @$authValues ) { $authValuesAll->{'DEPOSIT'}->{$val->{authorised_value}} = $val->{lib} };
    $authValues = GetAuthorisedValues("CASHREG_ADJUST",0);
    foreach my $val( @$authValues ) { $authValuesAll->{'ADJUSTMENT'}->{$val->{authorised_value}} = $val->{lib} };
    $authValues = GetAuthorisedValues("ACCOUNT_TYPE_MAPPING",0);
    foreach my $val( @$authValues ) { $authValuesAll->{'ACCOUNT_TYPE'}->{$val->{authorised_value}} = $val->{lib} };
    
    # check fines overview type
    if ($type eq 'finesoverview' ) {

        # query of paid fines
        # the 1st to the 3rd SELECT are use to search fines that are paid with a normal payment
        # the 4th to the 6th SELECT is used to search new payments of reversed payments
        #                    This one is tricky because new payments may be partial payments
        # the 7th to the 9th SELECT is used to search reversed payments so that they are payments agains
        # the 10th select is used to select paid back payments which have been paid again a new payment
        my $query = qq{
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(ao.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets ao, accountlines c, accountlines a
            JOIN   items AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = a.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> 0.00
            GROUP BY 
                   a.accounttype, i.itype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(ao.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets ao, accountlines c, accountlines a
            JOIN   deleteditems AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = a.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> 0.00
            GROUP BY 
                   a.accounttype, i.itype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(ao.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   "" AS itemtype
            FROM   branches br, account_offsets ao, accountlines c, accountlines a
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = a.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> 0.00
            GROUP BY 
                   a.accounttype, itemtype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines u, accountlines a
            JOIN   items AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND ao.debit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
                   AND ao.amount = u.amount
            GROUP BY 
                   a.accounttype, i.itype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines u, accountlines a
            JOIN   deleteditems AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND ao.debit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
                   AND ao.amount = u.amount
            GROUP BY 
                   a.accounttype, i.itype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   "" AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines u, accountlines a
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND ao.debit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND o.amount <> 0.00
                   AND ao.amount = u.amount
            GROUP BY 
                   a.accounttype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
            JOIN   items AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.credit_id = c.accountlines_id
                   AND ao.amount > 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
                   AND -ao.amount = c.amount
            GROUP BY 
                    a.accounttype, i.itype
            
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
            JOIN   deleteditems AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.credit_id = c.accountlines_id
                   AND ao.amount > 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
                   AND -ao.amount = c.amount
            GROUP BY 
                   a.accounttype, i.itype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   "" AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.credit_id = c.accountlines_id
                   AND ao.amount > 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND o.amount <> 0.00
                   AND -ao.amount = c.amount
            GROUP BY 
                   a.accounttype
            UNION ALL
            SELECT 
                   'PaymentOfPaidBackPayment' AS accounttype,
                   SUM(ao.amount) * -1 AS amount,
                   COUNT(*) AS count,
                   '' AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines u, accountlines a
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND ao.debit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> 0.00
            GROUP BY 
                   a.accounttype
            UNION ALL
            SELECT 
                   'PartialPaymentOfPaidBackPayment' AS accounttype,
                   ao.amount * -1 AS amount,
                   1 AS count,
                   '' AS itemtype
            FROM   branches br, account_offsets ao, accountlines c, accountlines u
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND EXISTS (
                       SELECT 1
                       FROM account_offsets o, accountlines a
                       WHERE
                               ao.debit_id = o.credit_id
                           AND o.type = 'Payment'
                           AND o.debit_id = a.accountlines_id
                           AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   )
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> u.amount
            UNION ALL
            SELECT 
                   'PartialPaymentReverseOfPaidBackPayment' AS accounttype,
                   ao.amount AS amount,
                   1 AS count,
                   "" AS itemtype
            FROM   branches br, account_offsets ao,  accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.credit_id = c.accountlines_id
                   AND ao.amount > 0.0
                   AND $dateselect $branchselect
                   AND ao.amount <> -c.amount
           }; $query =~ s/^\s+/ /mg;
           
        # warn "Query: $query\n";
           
        my $sth = $dbh->prepare($query);
        $sth->execute();
        $result->{sum}->{paid} = {
                amount => 0.0,
                count => 0
            };
        $result->{sum}->{mapped} = {
                amount => 0.0,
                count => 0
            };
        $result->{sum}->{unmapped} = {
                amount => 0.0,
                count => 0
            };
            
        while (my $row = $sth->fetchrow_hashref) {
            my $amount = $row->{amount};
            my $accounttype = $row->{accounttype};
            $accounttype = $manual_invtypes{$accounttype} if ( exists($manual_invtypes{$accounttype}) );
            
            # Add values to summary calculation grouped by account type and item type
            if (! exists($result->{data}->{paid}->{$accounttype}->{$row->{itemtype}}) ) {
                $result->{data}->{paid}->{$accounttype}->{$row->{itemtype}} = {
                    amount => $amount,
                    count => $row->{count},
                    itemtype => $row->{itemtype},
                    itemtypedescription => $itemtypes{$row->{itemtype}},
                    fines_amount => sprintf('%.2f', $amount),
                    fines_amount_formatted => $self->formatAmountWithCurrency($amount)
                };
            }
            else {
                $result->{data}->{paid}->{$accounttype}->{$row->{itemtype}}->{amount} += $amount;
                $result->{data}->{paid}->{$accounttype}->{$row->{itemtype}}->{count}  += $row->{count};
                $result->{data}->{paid}->{$accounttype}->{$row->{itemtype}}->{fines_amount} += sprintf('%.2f', $result->{data}->{paid}->{$accounttype}->{$row->{itemtype}}->{amount});
                $result->{data}->{paid}->{$accounttype}->{$row->{itemtype}}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{paid}->{$accounttype}->{$row->{itemtype}}->{amount});
            }
            # Add values to summary calculation grouped by account type
            if (! exists($result->{data}->{paidtype}->{$accounttype}) ) {
                $result->{data}->{paidtype}->{$accounttype} = {
                    amount => $amount,
                    count => $row->{count},
                    itemtype => $row->{itemtype},
                    itemtypedescription => $itemtypes{$row->{itemtype}},
                    fines_amount => sprintf('%.2f', $amount),
                    fines_amount_formatted => $self->formatAmountWithCurrency($amount)
                };
            }
            else {
                $result->{data}->{paidtype}->{$accounttype}->{amount} += $amount;
                $result->{data}->{paidtype}->{$accounttype}->{count}  += $row->{count};
                $result->{data}->{paidtype}->{$accounttype}->{fines_amount} += sprintf('%.2f', $result->{data}->{paidtype}->{$accounttype}->{amount});
                $result->{data}->{paidtype}->{$accounttype}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{paidtype}->{$accounttype}->{amount});
            }
            # Add values to summary calculation grouped by account if there exists an accounttype to account mapping
            # defined with normalized value type ACCOUNT_TYPE_MAPPING
            my $mapped = 'unmapped';
            my $account = $row->{accounttype};
            if ( exists($authValuesAll->{'ACCOUNT_TYPE'}->{$accounttype}) ) {
                $mapped = 'mapped';
                $account = $authValuesAll->{'ACCOUNT_TYPE'}->{$accounttype};
            }
            if (! exists($result->{data}->{account}->{$mapped}->{$account}) ) {
                $result->{data}->{account}->{$mapped}->{$account} = {
                    amount => $amount,
                    count => $row->{count},
                    fines_amount => sprintf('%.2f', $amount),
                    fines_amount_formatted => $self->formatAmountWithCurrency($amount)
                };
            } else {
                $result->{data}->{account}->{$mapped}->{$account}->{amount} += $amount;
                $result->{data}->{account}->{$mapped}->{$account}->{count}  += $row->{count};
                $result->{data}->{account}->{$mapped}->{$account}->{fines_amount} = sprintf('%.2f', $result->{data}->{account}->{$mapped}->{$account}->{amount});
                $result->{data}->{account}->{$mapped}->{$account}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{account}->{$mapped}->{$account}->{amount});
            }
            
            if (! exists($result->{data}->{mapaccount}->{paid}->{$mapped}->{$account}) ) {
                $result->{data}->{mapaccount}->{paid}->{$mapped}->{$account} = { amount => 0.0, count => 0, '0.00', '0.00' };
            }
            $result->{data}->{mapaccount}->{paid}->{$mapped}->{$account}->{amount} += $amount;
            $result->{data}->{mapaccount}->{paid}->{$mapped}->{$account}->{count}  += $row->{count};
            $result->{data}->{mapaccount}->{paid}->{$mapped}->{$account}->{fines_amount} = sprintf('%.2f', $result->{data}->{mapaccount}->{paid}->{$mapped}->{$account}->{amount});
            $result->{data}->{mapaccount}->{paid}->{$mapped}->{$account}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{mapaccount}->{paid}->{$mapped}->{$account}->{amount});

            $result->{sum}->{paid}->{amount} += $amount;
            $result->{sum}->{paid}->{count}  += $row->{count};
            
            $result->{sum}->{$mapped}->{amount} += $amount;
            $result->{sum}->{$mapped}->{count}  += $row->{count};
        }
        
        $result->{sum}->{paid}->{fines_amount}           = sprintf('%.2f', $result->{sum}->{paid}->{amount});
        $result->{sum}->{paid}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{paid}->{amount});
                
        $sth->finish;
        
        $query = qq{
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
            JOIN   items AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.amount < 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND ao.credit_id = c.accountlines_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
            GROUP BY 
                   a.accounttype, i.itype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) AS amount,
                   COUNT(*) AS count,
                   i.itype AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
            JOIN   deleteditems AS i USING (itemnumber)
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.amount < 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND ao.credit_id = c.accountlines_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
            GROUP BY 
                   a.accounttype, i.itype
            UNION ALL
            SELECT 
                   a.accounttype AS accounttype,
                   SUM(o.amount) AS amount,
                   COUNT(*) AS count,
                   "" AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.amount < 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND ao.credit_id = c.accountlines_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND o.amount <> 0.00
            GROUP BY 
                   a.accounttype
            UNION ALL
            SELECT 
                   'ReversedPaymentOfPaidBackPayment' AS accounttype,
                   SUM(o.amount) AS amount,
                   COUNT(*) AS count,
                   '' AS itemtype
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.amount < 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND ao.credit_id = c.accountlines_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
            GROUP BY 
                   a.accounttype
           }; $query =~ s/^\s+/ /mg;
           
        $sth = $dbh->prepare($query);
        $sth->execute();
        $result->{sum}->{reversed} = {
                amount => 0.0,
                count => 0
            };
            
        while (my $row = $sth->fetchrow_hashref) {
            my $amount = $row->{amount};
            my $accounttype = $row->{accounttype};
            $accounttype = $manual_invtypes{$accounttype} if ( exists($manual_invtypes{$accounttype}) );
            
            # Add values to summary calculation grouped by account type and item type
            if (! exists($result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}}) ) {
                $result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}} = {
                    amount => $amount,
                    count => $row->{count},
                    itemtype => $row->{itemtype},
                    itemtypedescription => $itemtypes{$row->{itemtype}},
                    fines_amount => sprintf('%.2f', $amount),
                    fines_amount_formatted => $self->formatAmountWithCurrency($amount)
                };
            }
            else {
                $result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}}->{amount} += $amount;
                $result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}}->{count}  += $row->{count};
                $result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}}->{fines_amount} += sprintf('%.2f', $result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}}->{amount});
                $result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{reversed}->{$accounttype}->{$row->{itemtype}}->{amount});
            }
            
            # Add values to summary calculation grouped by account type
            if (! exists($result->{data}->{reversedtype}->{$accounttype}) ) {
                $result->{data}->{reversedtype}->{$accounttype} = {
                    amount => $amount,
                    count => $row->{count},
                    itemtype => $row->{itemtype},
                    itemtypedescription => $itemtypes{$row->{itemtype}},
                    fines_amount => sprintf('%.2f', $amount),
                    fines_amount_formatted => $self->formatAmountWithCurrency($amount)
                };
            }
            else {
                $result->{data}->{reversedtype}->{$accounttype}->{amount} += $amount;
                $result->{data}->{reversedtype}->{$accounttype}->{count}  += $row->{count};
                $result->{data}->{reversedtype}->{$accounttype}->{fines_amount} += sprintf('%.2f', $result->{data}->{reversedtype}->{$accounttype}->{amount});
                $result->{data}->{reversedtype}->{$accounttype}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{reversedtype}->{$accounttype}->{amount});
            }

            # Add values to summary calculation grouped by account if there exists an accounttype to account mapping
            # defined with normalized value type ACCOUNT_TYPE_MAPPING
            my $mapped = 'unmapped';
            my $account = $row->{accounttype};
            if ( exists($authValuesAll->{'ACCOUNT_TYPE'}->{$accounttype}) ) {
                $mapped = 'mapped';
                $account = $authValuesAll->{'ACCOUNT_TYPE'}->{$accounttype};
            }
            if (! exists($result->{data}->{account}->{$mapped}->{$account}) ) {
                $result->{data}->{account}->{$mapped}->{$account} = {
                    amount => $amount,
                    count => $row->{count},
                    fines_amount => sprintf('%.2f', $amount),
                    fines_amount_formatted => $self->formatAmountWithCurrency($amount)
                };
            } else {
                $result->{data}->{account}->{$mapped}->{$account}->{amount} += $amount;
                $result->{data}->{account}->{$mapped}->{$account}->{count}  += $row->{count};
                $result->{data}->{account}->{$mapped}->{$account}->{fines_amount} = sprintf('%.2f', $result->{data}->{account}->{$mapped}->{$account}->{amount});
                $result->{data}->{account}->{$mapped}->{$account}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{account}->{$mapped}->{$account}->{amount});
            }
            
            if (! exists($result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account}) ) {
                $result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account} = { amount => 0.0, count => 0, '0.00', '0.00' };
            }
            $result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account}->{amount} += $amount;
            $result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account}->{count}  += $row->{count};
            $result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account}->{fines_amount} = sprintf('%.2f', $result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account}->{amount});
            $result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{mapaccount}->{reversed}->{$mapped}->{$account}->{amount});

            
            $result->{sum}->{$mapped}->{amount} += $amount;
            $result->{sum}->{$mapped}->{count}  += $row->{count};
            
            $result->{sum}->{reversed}->{amount} += $amount;
            $result->{sum}->{reversed}->{count} += $row->{count};
        }
        
        $sth->finish;
        
        $result->{sum}->{reversed}->{fines_amount}           = sprintf('%.2f', $result->{sum}->{reversed}->{amount});
        $result->{sum}->{reversed}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{reversed}->{amount});
        
        $result->{sum}->{overall}->{amount} = $result->{sum}->{reversed}->{amount} + $result->{sum}->{paid}->{amount};
        $result->{sum}->{overall}->{count}  = $result->{sum}->{reversed}->{count}  + $result->{sum}->{paid}->{count};
        $result->{sum}->{overall}->{fines_amount}           = sprintf('%.2f', $result->{sum}->{overall}->{amount});
        $result->{sum}->{overall}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{overall}->{amount});
        
        $result->{sum}->{mapped}->{fines_amount}           = sprintf('%.2f', exists( $result->{sum}->{mapped}->{amount}) ? $result->{sum}->{mapped}->{amount} : 0.0);
        $result->{sum}->{mapped}->{fines_amount_formatted} = $self->formatAmountWithCurrency( exists( $result->{sum}->{mapped}->{amount}) ? $result->{sum}->{mapped}->{amount} : 0.0 );

        $result->{sum}->{unmapped}->{fines_amount}           = sprintf('%.2f', exists( $result->{sum}->{unmapped}->{amount}) ? $result->{sum}->{unmapped}->{amount} : 0.0);
        $result->{sum}->{unmapped}->{fines_amount_formatted} = $self->formatAmountWithCurrency( exists( $result->{sum}->{unmapped}->{amount}) ? $result->{sum}->{unmapped}->{amount} : 0.0 );

        
        # calculate overall sum of fines
        $result->{sum}->{fines} = {
                amount => 0.0,
                count => 0
            };
            
        $result->{sum}->{fines}->{amount} = $result->{sum}->{reversed}->{amount} + $result->{sum}->{paid}->{amount};
        $result->{sum}->{fines}->{fines_amount}           = sprintf('%.2f', $result->{sum}->{fines}->{amount});
        $result->{sum}->{fines}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{fines}->{amount});
        
        $query = qq{
            SELECT c.action AS action,
                   c.reason AS reason,
                   l.accounttype AS accounttype,
                   SUM(c.booking_amount) AS amount,
                   COUNT(*) AS count,
                   r.name AS cash_register
            FROM   branches br, cash_register r, cash_register_account c
            LEFT JOIN accountlines l ON c.accountlines_id = l.accountlines_id
            WHERE  r.branchcode = br.branchcode
               AND $cashdateselect $cashregisterselect
               AND c.cash_register_id  = r.id
               AND c.action NOT IN ('OPEN','CLOSE','REVERSE_PAYMENT')
            GROUP BY
                   r.name, c.action, c.reason, l.accounttype
            UNION ALL
            SELECT 'PAYMENT' AS action,
                   c.reason AS reason,
                   l.accounttype AS accounttype,
                   SUM(c.booking_amount) AS amount,
                   COUNT(*) AS count,
                   r.name AS cash_register
            FROM   branches br, cash_register r, cash_register_account c
            LEFT JOIN accountlines l ON c.accountlines_id = l.accountlines_id
            WHERE  r.branchcode = br.branchcode
               AND $cashdateselect $cashregisterselect
               AND c.cash_register_id  = r.id
               AND c.action = 'REVERSE_PAYMENT'
               AND c.booking_amount > 0.00
            GROUP BY
                   r.name, c.action, c.reason, l.accounttype
            UNION ALL
            SELECT c.action AS action,
                   c.reason AS reason,
                   l.accounttype AS accounttype,
                   SUM(c.booking_amount) AS amount,
                   COUNT(*) AS count,
                   r.name AS cash_register
            FROM   branches br, cash_register r, cash_register_account c
            LEFT JOIN accountlines l ON c.accountlines_id = l.accountlines_id
            WHERE  r.branchcode = br.branchcode
               AND $cashdateselect $cashregisterselect
               AND c.cash_register_id  = r.id
               AND c.action = 'REVERSE_PAYMENT'
               AND c.booking_amount < 0.00
            GROUP BY
                   r.name, c.action, c.reason, l.accounttype
        }; $query =~ s/^\s+/ /mg;
           
        $sth = $dbh->prepare($query);
        $sth->execute();
        
        $result->{sum}->{cashreg}->{PAYOUT}       = { amount => 0.0, count => 0 };
        $result->{sum}->{cashreg}->{ADJUSTMENT}   = { amount => 0.0, count => 0 };
        $result->{sum}->{cashreg}->{DEPOSIT}      = { amount => 0.0, count => 0 };
        
        while (my $row = $sth->fetchrow_hashref) {
            my $amount      = $row->{amount};
            my $reason      = $row->{reason} || '';
            my $action      = $row->{action};
            my $cashreg     = $row->{cash_register};
            my $accounttype = $row->{accounttype} || '';
            $reason = $authValuesAll->{$action}->{$reason} if ( exists($authValuesAll->{$action}->{$reason}) );
            if (! exists($result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype}) ) {
                $result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype} = {
                    amount => $amount,
                    count => $row->{count},
                    cash_register => $cashreg,
                    reason => $reason,
                    accounttype => $accounttype,
                    fines_amount => sprintf('%.2f', $amount),
                    fines_amount_formatted => $self->formatAmountWithCurrency($amount)
                };
            }
            else {
                $result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype}->{amount} += $amount;
                $result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype}->{count}  += $row->{count};
                $result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype}->{fines_amount} += sprintf('%.2f', $result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype}->{amount});
                $result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{cashregister}->{$cashreg}->{$action}->{$reason}->{$accounttype}->{amount});
            }
            $result->{sum}->{cashreg}->{$action}->{amount} += $amount;
            $result->{sum}->{cashreg}->{$action}->{count}  += $row->{count};
        }
        $sth->finish;
        
        # get summary of payments by payment type: 'Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03'
        # in order to calculate cash and card payments
        $query = qq{
            SELECT 
                   a.accounttype,
                   SUM(ao.amount) AS amount,
                   COUNT(*) AS count
            FROM   branches br, account_offsets ao, accountlines a
            WHERE      a.branchcode = br.branchcode
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND ao.credit_id = a.accountlines_id
                   AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> 0.00
            GROUP BY 
                   a.accounttype
            UNION ALL
            SELECT 
                   a.accounttype,
                   SUM(ao.amount) * -1 AS amount,
                   COUNT(*) AS count
            FROM   branches br, account_offsets ao, accountlines a
            WHERE      a.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND $dateselect $branchselect
                   AND ao.credit_id = a.accountlines_id
                   AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount > 0.00
            GROUP BY 
                   a.accounttype
            }; $query =~ s/^\s+/ /mg;

        $sth = $dbh->prepare($query);
        $sth->execute();
        
        my @ptypes = ('cash','card','unassigned');

        foreach my $type(@ptypes) {
            $result->{sum}->{cashtype}->{$type}->{payment} = {
                amount => 0.0,
                count_transactions => 0
            };
            $result->{sum}->{cashtype}->{$type}->{payout} = {
                amount => 0.0,
                count_transactions => 0
            };
            $result->{sum}->{cashtype}->{$type}->{bookings_found} = 0;
        }
        
        while (my $row = $sth->fetchrow_hashref) {
            my $amount = $row->{'amount'} * -1;
            my $acctype = $row->{'accounttype'};
            my $type = 'unassigned';
            if ( $acctype eq 'Pay' ) {
                $type = 'cash';
            }
            elsif ( $acctype eq 'Pay00' || $acctype eq 'Pay01' || $acctype eq 'Pay02' || $acctype eq 'Pay03' ) {
                $type = 'card';
            }
            my $what = 'payout';
            if ( $amount >= 0.00 ) {
                # it's a payment
                $what = 'payment';
            }
            $result->{sum}->{cashtype}->{$type}->{$what}->{amount} += $amount;
            $result->{sum}->{cashtype}->{$type}->{$what}->{count}  += $row->{count};
            $result->{sum}->{cashtype}->{$type}->{bookings_found} = 1;
        }
        $sth->finish;
        
        push(@ptypes, 'sum');
        foreach my $type(@ptypes) {
            $result->{sum}->{cashtype}->{$type}->{payment}->{payment_amount} = sprintf('%.2f', $result->{sum}->{cashtype}->{$type}->{payment}->{amount} || 0.0);
            $result->{sum}->{cashtype}->{$type}->{payment}->{payment_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{cashtype}->{$type}->{payment}->{amount});
            $result->{sum}->{cashtype}->{$type}->{payout}->{payout_amount} = sprintf('%.2f', $result->{sum}->{cashtype}->{$type}->{payout}->{amount} || 0.0);
            $result->{sum}->{cashtype}->{$type}->{payout}->{payout_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{cashtype}->{$type}->{payout}->{amount});
        }
        
        # calculate account management fees grouped by borrowers town and borrower type
        my %accoutfeegroups = ( 
                    'borrower_type' => { 'select' => 'cat.description', 'group_by' => 'cat.description' },
                    'borrower_town' => { 'select' => 'b.city', 'group_by' => 'b.city' }
            );
        foreach my $accoutfeegroup (keys %accoutfeegroups) {
            my $selectfield = $accoutfeegroups{$accoutfeegroup}->{select};
            my $groupfield = $accoutfeegroups{$accoutfeegroup}->{group_by};
            $query = qq{
                SELECT 
                       $selectfield as description,
                       SUM(ao.amount) * -1 AS amount,
                       COUNT(*) AS count,
                       ao.type AS paytype
                FROM   branches br, account_offsets ao, accountlines c, accountlines a
                JOIN   borrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.debit_id = a.accountlines_id
                       AND ao.credit_id = c.accountlines_id
                       AND ao.type = 'Payment'
                       AND $dateselect $branchselect
                       AND a.accounttype = 'A'
                       AND ao.amount <> 0.00
                GROUP BY 
                       paytype, $groupfield
                UNION ALL
                SELECT 
                       $selectfield as description,
                       SUM(ao.amount) * -1 AS amount,
                       COUNT(*) AS count,
                       ao.type AS paytype
                FROM   branches br, account_offsets ao, accountlines c, accountlines a
                JOIN   deletedborrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.debit_id = a.accountlines_id
                       AND ao.credit_id = c.accountlines_id
                       AND ao.type = 'Payment'
                       AND $dateselect $branchselect
                       AND a.accounttype = 'A'
                       AND ao.amount <> 0.00
                GROUP BY 
                       paytype, $groupfield

                UNION ALL
                SELECT 
                       $selectfield as description,
                       SUM(o.amount) * -1 ,
                       COUNT(*) AS count,
                       ao.type AS paytype
                FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines u, accountlines a
                JOIN   borrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.debit_id = u.accountlines_id
                       AND ao.credit_id = c.accountlines_id
                       AND ao.type = 'Payment'
                       AND $dateselect $branchselect
                       AND ao.debit_id = o.credit_id
                       AND o.type = 'Payment'
                       AND o.debit_id = a.accountlines_id
                       AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                       AND a.accounttype = 'A'
                       AND ao.amount = u.amount
                       AND o.amount <> 0.00
                GROUP BY 
                       paytype, $groupfield
                UNION ALL
                SELECT 
                       $selectfield as description,
                       SUM(o.amount) * -1 ,
                       COUNT(*) AS count,
                       ao.type AS paytype
                FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines u, accountlines a
                JOIN   deletedborrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.debit_id = u.accountlines_id
                       AND ao.credit_id = c.accountlines_id
                       AND ao.type = 'Payment'
                       AND $dateselect $branchselect
                       AND ao.debit_id = o.credit_id
                       AND o.type = 'Payment'
                       AND o.debit_id = a.accountlines_id
                       AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                       AND a.accounttype = 'A'
                       AND ao.amount = u.amount
                       AND o.amount <> 0.00
                GROUP BY 
                       paytype, $groupfield

                UNION ALL
                SELECT 
                       $selectfield  as description,
                       SUM(o.amount) * -1 AS amount,
                       COUNT(*) AS count,
                       'Payment' AS paytype
                FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
                JOIN   borrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.type = 'Reverse Payment'
                       AND ao.credit_id = c.accountlines_id
                       AND ao.amount > 0.0
                       AND $dateselect $branchselect
                       AND ao.credit_id = o.credit_id
                       AND o.type = 'Payment'
                       AND o.debit_id = a.accountlines_id
                       AND a.accounttype = 'A'
                       AND o.amount <> 0.00
                       AND -ao.amount = c.amount
                GROUP BY 
                       paytype, $groupfield
                UNION ALL
                SELECT 
                       $selectfield  as description,
                       SUM(o.amount) * -1 AS amount,
                       COUNT(*) AS count,
                       'Payment' AS paytype
                FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
                JOIN   deletedborrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.type = 'Reverse Payment'
                       AND ao.credit_id = c.accountlines_id
                       AND ao.amount > 0.0
                       AND $dateselect $branchselect
                       AND ao.credit_id = o.credit_id
                       AND o.type = 'Payment'
                       AND o.debit_id = a.accountlines_id
                       AND a.accounttype = 'A'
                       AND o.amount <> 0.00
                       AND -ao.amount = c.amount
                GROUP BY 
                       paytype, $groupfield

                UNION ALL
                SELECT 
                       $selectfield as description,
                       SUM(o.amount) AS amount,
                       COUNT(*) AS count,
                       ao.type AS paytype
                FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
                JOIN   borrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.type = 'Reverse Payment'
                       AND ao.credit_id = c.accountlines_id
                       AND ao.amount < 0.0
                       AND $dateselect $branchselect
                       AND ao.credit_id = o.credit_id
                       AND o.type = 'Payment'
                       AND o.debit_id = a.accountlines_id
                       AND a.accounttype = 'A'
                       AND o.amount <> 0.00
                       AND ao.amount = c.amount
                GROUP BY 
                       paytype, $groupfield
                UNION ALL
                SELECT 
                       $selectfield as description,
                       SUM(o.amount) AS amount,
                       COUNT(*) AS count,
                       ao.type AS paytype
                FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a
                JOIN   deletedborrowers AS b USING (borrowernumber)
                JOIN   categories AS cat USING (categorycode)
                WHERE      c.branchcode = br.branchcode
                       AND ao.type = 'Reverse Payment'
                       AND ao.credit_id = c.accountlines_id
                       AND ao.amount < 0.0
                       AND $dateselect $branchselect
                       AND ao.credit_id = o.credit_id
                       AND o.type = 'Payment'
                       AND o.debit_id = a.accountlines_id
                       AND a.accounttype = 'A'
                       AND o.amount <> 0.00
                       AND ao.amount = c.amount
                GROUP BY 
                       paytype, $groupfield
                }; $query =~ s/^\s+/ /mg;

            $sth = $dbh->prepare($query);
            $sth->execute();
            
            $result->{sum}->{accountfee}->{$accoutfeegroup}->{amount} = 0.0;
        
            while (my $row = $sth->fetchrow_hashref) {
                my $amount       = $row->{'amount'};
                my $paytype      = $row->{'paytype'};
                my $count        = $row->{'count'};
                my $description  = $row->{'description'} || '';
                
                $result->{data}->{accountfee}->{$accoutfeegroup}->{$paytype}->{$description}->{amount} += $amount;
                $result->{data}->{accountfee}->{$accoutfeegroup}->{$paytype}->{$description}->{count}  += $count;
                $result->{data}->{accountfee}->{$accoutfeegroup}->{$paytype}->{$description}->{fines_amount} = sprintf('%.2f', $result->{data}->{accountfee}->{$accoutfeegroup}->{$paytype}->{$description}->{amount});
                $result->{data}->{accountfee}->{$accoutfeegroup}->{$paytype}->{$description}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{data}->{accountfee}->{$accoutfeegroup}->{$paytype}->{$description}->{amount});
                
                $result->{sum}->{accountfee}->{$accoutfeegroup}->{amount} += $amount;
                $result->{sum}->{accountfee}->{$accoutfeegroup}->{count} += $count;
            }
            $sth->finish;
            
            $result->{sum}->{accountfee}->{$accoutfeegroup}->{fines_amount} = sprintf('%.2f', $result->{sum}->{accountfee}->{$accoutfeegroup}->{amount});
            $result->{sum}->{accountfee}->{$accoutfeegroup}->{fines_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{accountfee}->{$accoutfeegroup}->{amount});
        }
    }
    elsif ( $type eq 'paidfinesbyday' || $type eq 'paidfinesbymanager' || $type eq 'paidfinesbytype' ) {
        
        my $query = qq{
            SELECT 
                   1 as entrytype,
                   DATE(ao.created_on) as date,
                   a.accounttype as accounttype, 
                   ao.amount * -1 as amount,
                   c.borrowernumber as borrowernumber,
                   c.manager_id as manager_id,
                   a.description as description,
                   '' as reason
            FROM   branches br, account_offsets ao, accountlines a, accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = a.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> 0.00
            UNION ALL
            SELECT 
                   1 as entrytype,
                   DATE(ao.created_on) as date,
                   a.accounttype as accounttype, 
                   o.amount * -1 as amount,
                   c.borrowernumber as borrowernumber,
                   c.manager_id as manager_id,
                   a.description as description,
                   '' as reason
            FROM   branches br, account_offsets o, account_offsets ao, accountlines u, accountlines a, accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND ao.debit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
                   AND ao.amount = u.amount
            UNION ALL
            SELECT 
                   1 as entrytype,
                   DATE(ao.created_on) as date,
                   a.accounttype as accounttype, 
                   o.amount as amount,
                   c.borrowernumber as borrowernumber,
                   c.manager_id as manager_id,
                   a.description as description,
                   '' as reason
            FROM   branches br, account_offsets o, account_offsets ao, accountlines a, accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.credit_id = c.accountlines_id
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
                   AND ABS(ao.amount) = ABS(c.amount)
            UNION ALL
            SELECT 
                   1 as entrytype,
                   DATE(ao.created_on) as date,
                   'PaymentOfPaidBackPayment' AS accounttype,
                   ao.amount * -1 AS amount,
                   c.borrowernumber as borrowernumber,
                   c.manager_id as manager_id,
                   a.description as description,
                   '' as reason
            FROM   branches br, account_offsets o, account_offsets ao, accountlines u, accountlines a, accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND ao.debit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> 0.00
            UNION ALL
            SELECT 
                   1 as entrytype,
                   DATE(ao.created_on) as date,
                   'PartialPaymentOfPaidBackPayment' AS accounttype,
                   ao.amount * -1 AS amount,
                   c.borrowernumber as borrowernumber,
                   c.manager_id as manager_id,
                   u.description as description,
                   '' as reason
            FROM   branches br, account_offsets ao, accountlines u, accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND $dateselect $branchselect
                   AND EXISTS (
                       SELECT 1
                       FROM account_offsets o, accountlines a
                       WHERE
                               ao.debit_id = o.credit_id
                           AND o.type = 'Payment'
                           AND o.debit_id = a.accountlines_id
                           AND a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   )
                   AND u.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND ao.amount <> u.amount
            UNION ALL
            SELECT 
                   1 as entrytype,
                   DATE(ao.created_on) as date,
                   'PartialPaymentReverseOfPaidBackPayment' AS accounttype,
                   ao.amount AS amount,
                   c.borrowernumber as borrowernumber,
                   c.manager_id as manager_id,
                   c.description as description,
                   '' as reason
            FROM   branches br, account_offsets ao,  accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.credit_id = c.accountlines_id
                   AND ao.amount > 0.0
                   AND $dateselect $branchselect
                   AND ao.amount <> -c.amount
            UNION ALL
            SELECT 
                   1 as entrytype,
                   DATE(ao.created_on) as date,
                   'ReversedPaymentOfPaidBackPayment' AS accounttype,
                   o.amount AS amount,
                   c.borrowernumber as borrowernumber,
                   c.manager_id as manager_id,
                   c.description as description,
                   '' as reason
            FROM   branches br, account_offsets o, account_offsets ao, accountlines a, accountlines c
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.amount < 0.0
                   AND $dateselect $branchselect
                   AND ao.credit_id = o.credit_id
                   AND ao.credit_id = c.accountlines_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND o.amount <> 0.00
            ORDER BY date, borrowernumber
           }; $query =~ s/^\s+/ /mg;
           
        # warn "Query: $query\n";
           
        my $sth = $dbh->prepare($query);
        
        my %borrowers = ();

        my $query_bor = q{
            SELECT b.borrowernumber, b.firstname, b.surname, b.cardnumber
            FROM borrowers b
            WHERE b.borrowernumber = ? };
        my $sth_bor = $dbh->prepare($query_bor);
        
        my $query_delbor = q{
            SELECT b.borrowernumber, b.firstname, b.surname, b.cardnumber
            FROM deletedborrowers b
            WHERE b.borrowernumber = ? };
        my $sth_delbor = $dbh->prepare($query_delbor);

        $sth->execute();

        my $rownum = 0;
        while (my $row = $sth->fetchrow_hashref) {
            my $amount = $row->{amount};
            my $accounttype = $row->{accounttype};
            $accounttype = $manual_invtypes{$accounttype} if ( exists($manual_invtypes{$accounttype}) );
            
            # read required record from borrowers or deletedborrowers for getting manager_name and patron_name
            foreach my $borr ( { id => 'manager_id', desig_name => 'manager_name', desig_cardno => 'manager_cardnumber', desig_isdel => 'manager_is_deleted' }, { id => 'borrowernumber', desig_name => 'patron_name', desig_cardno => 'cardnumber', desig_isdel => 'patron_is_deleted' } ) {
                if ( $row->{$borr->{id}} ) {
                    if ( ! exists $borrowers{$row->{$borr->{id}}} ) {
                        my $borrower_is_deleted = 0;
                        $sth_bor->execute($row->{$borr->{id}});
                        my $row_bor = $sth_bor->fetchrow_hashref;
                        if ( ! $row_bor  ) {
                            $borrower_is_deleted = 1;
                            $sth_delbor->execute($row->{$borr->{id}});
                            $row_bor = $sth_delbor->fetchrow_hashref;
                        }
                        if ( $row_bor ) {
                            $borrowers{$row->{$borr->{id}}}->{fullname} = length($row_bor->{firstname}) ? $row_bor->{firstname} . ' ' . $row_bor->{surname} : $row_bor->{surname};
                            $borrowers{$row->{$borr->{id}}}->{cardnumber} = $row_bor->{cardnumber};
                        } else {
                            $borrowers{$row->{$borr->{id}}}->{fullname} = '';
                            $borrowers{$row->{$borr->{id}}}->{cardnumber} = '';
                        }
                        $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted} = $borrower_is_deleted;
                    }
                    $row->{$borr->{desig_name}} = $borrowers{$row->{$borr->{id}}}->{fullname};
                    $row->{$borr->{desig_cardno}} = $borrowers{$row->{$borr->{id}}}->{cardnumber};
                    $row->{$borr->{desig_isdel}} = $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted};
                } else {
                    $row->{$borr->{desig_name}} = '';
                    $row->{$borr->{desig_cardno}} = '';
                    $row->{$borr->{desig_isdel}} = 1;
                }
            }
            
            $result->{data}->[$rownum++] = {
                entrytype => $row->{entrytype},
                reason => $row->{reason},
                date => $row->{date},
                accounttype => $accounttype,
                amount => $amount,
                fines_amount => sprintf('%.2f', $amount),
                fines_amount_formatted => $self->formatAmountWithCurrency($amount),
                description => $row->{description},
                borrowernumber => $row->{borrowernumber},
                patron_name => $row->{patron_name},             # constructed from %borrowers
                cardnumber => $row->{cardnumber},               # constructed from %borrowers
                patron_is_deleted => $row->{patron_is_deleted}, # constructed from %borrowers
                manager_id => $row->{manager_id},
                manager_name => $row->{manager_name}            # constructed from %borrowers
            };
        }
        $sth_delbor->finish();
        $sth_bor->finish();
        $sth->finish();
    }
    elsif ( $type eq 'paymentsbyday' || $type eq 'paymentsbymanager' || $type eq 'paymentsbytype' || $type eq 'payoutbytype' ) {
        # get the accountlines statistics by type
        
        my $selectpaytype = qq{ c.action IN ('PAYOUT','ADJUSTMENT','DEPOSIT') };
        
        if ( $type eq 'payoutbytype' ) {
            $selectpaytype = qq{ (c.action = 'PAYOUT' or (c.action = 'ADJUSTMENT' and c.booking_amount < 0.0 ) ) };
            if ( $cash_register_id && $cash_register_id =~ /^[0-9]+$/ ) {
                $selectpaytype .= " and c.cash_register_id = $cash_register_id ";
            }
        }
        
        my $query  = qq{
            SELECT 2 as entrytype,
                    DATE(c.booking_time) as date,
                    c.action as accounttype,
                    c.booking_amount as amount,
                    NULL as borrowernumber,
                    c.description as description,
                    c.manager_id as manager_id,
                    c.reason as reason,
                    r.name as cash_register_name,
                    c.cash_register_account_id as journalno
             FROM   branches br, cash_register r, cash_register_account c
             WHERE      $selectpaytype
                    AND $cashdateselect $cashregisterselect
                    AND r.branchcode = br.branchcode
                    AND c.cash_register_id  = r.id
             ORDER BY date, borrowernumber
            };
        
        if ( $type ne 'payoutbytype' ) {
            $query = qq{
                SELECT 
                        1 as entrytype,
                        DATE(ao.created_on) as date,
                        a.accounttype as accounttype,
                        IF(ao.type = 'Payment', SUM(ao.amount)* -1, SUM(ao.amount)) as amount,
                        a.borrowernumber as borrowernumber,
                        a.description as description,
                        a.manager_id as manager_id,
                        '' as reason,
                        '' as cash_register_name,
                        0 as journalno
                 FROM 
                        branches br, account_offsets ao 
                        JOIN accountlines a ON (a.accountlines_id = ao.credit_id)
                 WHERE      a.branchcode = br.branchcode
                        AND ao.type IN ('Payment','Reverse Payment')
                        AND $dateselect $branchselect
                 GROUP BY
                        ao.type, ao.credit_id, ao.created_on, a.accounttype, a.borrowernumber,
                        a.description, a.manager_id
                 UNION ALL } . $query;
         };
         
        $query =~ s/^\s+/ /mg;
        
        my $sth = $dbh->prepare($query);
        
        my %borrowers = ();

        my $query_bor = q{
            SELECT b.borrowernumber, b.firstname, b.surname, b.cardnumber
            FROM borrowers b
            WHERE b.borrowernumber = ? };
        my $sth_bor = $dbh->prepare($query_bor);
        
        my $query_delbor = q{
            SELECT b.borrowernumber, b.firstname, b.surname, b.cardnumber
            FROM deletedborrowers b
            WHERE b.borrowernumber = ? };
        my $sth_delbor = $dbh->prepare($query_delbor);

        $sth->execute();

        my $rownum = 0;
        while (my $row = $sth->fetchrow_hashref) {
            my $amount = $row->{amount};
            my $accounttype = $row->{accounttype};
            $accounttype = $manual_invtypes{$accounttype} if ( exists($manual_invtypes{$accounttype}) );
            
            if ( $row->{entrytype} == 2 ) {
                # check whether we can deliver the description of a reason from authorised 
                # values if defined
                if ( defined($row->{reason}) && exists( $authValuesAll->{$row->{accounttype}}->{$row->{reason}} ) ) {
                    $row->{reason} = $authValuesAll->{$row->{accounttype}}->{$row->{reason}};
                }
            }
            
            # read required record from borrowers or deletedborrowers for getting manager_name and patron_name
            foreach my $borr ( { id => 'manager_id', desig_name => 'manager_name', desig_cardno => 'manager_cardnumber', desig_isdel => 'manager_is_deleted' }, { id => 'borrowernumber', desig_name => 'patron_name', desig_cardno => 'cardnumber', desig_isdel => 'patron_is_deleted' } ) {
                if ( $row->{$borr->{id}} ) {
                    if ( ! exists $borrowers{$row->{$borr->{id}}} ) {
                        my $borrower_is_deleted = 0;
                        $sth_bor->execute($row->{$borr->{id}});
                        my $row_bor = $sth_bor->fetchrow_hashref;
                        if ( ! $row_bor  ) {
                            $borrower_is_deleted = 1;
                            $sth_delbor->execute($row->{$borr->{id}});
                            $row_bor = $sth_delbor->fetchrow_hashref;
                        }
                        if ( $row_bor ) {
                            $borrowers{$row->{$borr->{id}}}->{fullname} = length($row_bor->{firstname}) ? $row_bor->{firstname} . ' ' . $row_bor->{surname} : $row_bor->{surname};
                            $borrowers{$row->{$borr->{id}}}->{cardnumber} = $row_bor->{cardnumber};
                        } else {
                            $borrowers{$row->{$borr->{id}}}->{fullname} = '';
                            $borrowers{$row->{$borr->{id}}}->{cardnumber} = '';
                        }
                        $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted} = $borrower_is_deleted;
                    }
                    $row->{$borr->{desig_name}} = $borrowers{$row->{$borr->{id}}}->{fullname};
                    $row->{$borr->{desig_cardno}} = $borrowers{$row->{$borr->{id}}}->{cardnumber};
                    $row->{$borr->{desig_isdel}} = $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted};
                } else {
                    $row->{$borr->{desig_name}} = '';
                    $row->{$borr->{desig_cardno}} = '';
                    $row->{$borr->{desig_isdel}} = 1;
                }
            }
            
            $result->{data}->[$rownum++] = {
                entrytype => $row->{entrytype},
                reason => $row->{reason},
                date => $row->{date},
                accounttype => $accounttype,
                amount => $amount,
                fines_amount => sprintf('%.2f', $amount),
                fines_amount_formatted => $self->formatAmountWithCurrency($amount),
                borrowernumber => $row->{borrowernumber},
                description => $row->{description},
                patron_name => $row->{patron_name},             # constructed from %borrowers
                cardnumber => $row->{cardnumber},               # constructed from %borrowers
                patron_is_deleted => $row->{patron_is_deleted}, # constructed from %borrowers
                manager_id => $row->{manager_id},
                manager_name => $row->{manager_name},           # constructed from %borrowers
                cash_register_name => $row->{cash_register_name},
                cash_register_journalno => $row->{journalno}
            };
        }
    }
    elsif ( $type eq 'finesbyday' || $type eq 'finesbymanager' || $type eq 'finesbytype' ) {
    
        my ($fmtfrom,$fmtto);
        # get the accountlines statistics by type
        $fmtfrom = DateTime::Format::MySQL->format_date($date_from);
        $fmtto = DateTime::Format::MySQL->format_date($date_to);

        # get the accountlines statistics by type
        my $query = qq{
            SELECT  1 as entrytype,
                    a.date as date, 
                    a.accounttype as accounttype, 
                    a.amount as amount,
                    a.borrowernumber as borrowernumber,
                    a.description as description,
                    a.manager_id as manager_id,
                    '' as reason
            FROM    branches br, accountlines a
            WHERE   a.accounttype NOT IN ('Pay', 'Pay00', 'Pay01', 'Pay02')
                AND a.date >= ? and a.date <= ?
                AND a.branchcode = br.branchcode $branchselect
            ORDER BY date, borrowernumber
           }; 
        
        my @params = ($fmtfrom, $fmtto);

        $query =~ s/^\s+/ /mg;
        
        my $sth = $dbh->prepare($query);
        
        my %borrowers = ();

        my $query_bor = q{
            SELECT b.borrowernumber, b.firstname, b.surname, b.cardnumber
            FROM borrowers b
            WHERE b.borrowernumber = ? };
        my $sth_bor = $dbh->prepare($query_bor);
        
        my $query_delbor = q{
            SELECT b.borrowernumber, b.firstname, b.surname, b.cardnumber
            FROM deletedborrowers b
            WHERE b.borrowernumber = ? };
        my $sth_delbor = $dbh->prepare($query_delbor);

        $sth->execute(@params);

        my $rownum = 0;
        while (my $row = $sth->fetchrow_hashref) {
            my $amount = $row->{amount};
            my $accounttype = $row->{accounttype};
            $accounttype = $manual_invtypes{$accounttype} if ( exists($manual_invtypes{$accounttype}) );
            
            # read required record from borrowers or deletedborrowers for getting manager_name and patron_name
            foreach my $borr ( { id => 'manager_id', desig_name => 'manager_name', desig_cardno => 'manager_cardnumber', desig_isdel => 'manager_is_deleted' }, { id => 'borrowernumber', desig_name => 'patron_name', desig_cardno => 'cardnumber', desig_isdel => 'patron_is_deleted' } ) {
                if ( $row->{$borr->{id}} ) {
                    if ( ! exists $borrowers{$row->{$borr->{id}}} ) {
                        my $borrower_is_deleted = 0;
                        $sth_bor->execute($row->{$borr->{id}});
                        my $row_bor = $sth_bor->fetchrow_hashref;
                        if ( ! $row_bor  ) {
                            $borrower_is_deleted = 1;
                            $sth_delbor->execute($row->{$borr->{id}});
                            $row_bor = $sth_delbor->fetchrow_hashref;
                        }
                        if ( $row_bor ) {
                            $borrowers{$row->{$borr->{id}}}->{fullname} = length($row_bor->{firstname}) ? $row_bor->{firstname} . ' ' . $row_bor->{surname} : $row_bor->{surname};
                            $borrowers{$row->{$borr->{id}}}->{cardnumber} = $row_bor->{cardnumber};
                        } else {
                            $borrowers{$row->{$borr->{id}}}->{fullname} = '';
                            $borrowers{$row->{$borr->{id}}}->{cardnumber} = '';
                        }
                        $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted} = $borrower_is_deleted;
                    }
                    $row->{$borr->{desig_name}} = $borrowers{$row->{$borr->{id}}}->{fullname};
                    $row->{$borr->{desig_cardno}} = $borrowers{$row->{$borr->{id}}}->{cardnumber};
                    $row->{$borr->{desig_isdel}} = $borrowers{$row->{$borr->{id}}}->{borrower_is_deleted};
                } else {
                    $row->{$borr->{desig_name}} = '';
                    $row->{$borr->{desig_cardno}} = '';
                    $row->{$borr->{desig_isdel}} = 1;
                }
            }
            
            $result->{data}->[$rownum++] = {
                entrytype => $row->{entrytype},
                reason => $row->{reason},
                date => $row->{date},
                accounttype => $accounttype,
                amount => $amount,
                fines_amount => sprintf('%.2f', $amount),
                fines_amount_formatted => $self->formatAmountWithCurrency($amount),
                description => $row->{description},
                borrowernumber => $row->{borrowernumber},
                patron_name => $row->{patron_name},             # constructed from %borrowers
                cardnumber => $row->{cardnumber},               # constructed from %borrowers
                patron_is_deleted => $row->{patron_is_deleted}, # constructed from %borrowers
                manager_id => $row->{manager_id},
                manager_name => $row->{manager_name}            # constructed from %borrowers
            };
        }
    }
    
    return ($result,output_pref({dt => dt_from_string($date_from), dateonly => 0}),output_pref({dt => dt_from_string($date_to), dateonly => 0}));
}

=head2 getCashTransactionOverviewByBranch

  $cash_management->getCashTransactionOverviewByBranch($branchcode,$from,$to)

This function returns an overview of all cash transactions during a selected period for a branch library.
The payments and payout transactions are summarized by account and count for each defined cash register
but also for SIP payments specifically cash and credit card.


=cut

sub getCashTransactionOverviewByBranch {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $branchcode = shift;
    my $from = shift;
    my $to = shift;
    my ($date_from,$date_to) = $self->getValidFromToPeriod($from, $to);
    my $result = {};
    $branchcode = getEffectiveBranchcode($branchcode);
    
    my $cash_register = Koha::CashRegister::CashRegisters->search({
            branchcode => $branchcode
    });
    
    $result->{'sum'} = {
        starting_balance => { amount => 0.0 },
        final_balance => { amount => 0.0 },
    };
    
    # initialize data
    while ( my $cashreg = $cash_register->next() ) {
        my $id = $cashreg->id;
        $result->{$id}->{payment} = {
            booking_amount => sprintf('%.2f', 0.0),
            booking_amount_formatted => $self->formatAmountWithCurrency(0.0),
            count_transactions => 0
        };
        $result->{$id}->{payout} = {
            booking_amount => sprintf('%.2f', 0.0),
            booking_amount_formatted => $self->formatAmountWithCurrency(0.0),
            count_transactions => 0
        };
        $result->{$id}->{starting_balance} = {
            booking_amount => sprintf('%.2f', 0.0),
            booking_amount_formatted => $self->formatAmountWithCurrency(0.0)
        };
        $result->{$id}->{final_balance} = {
            booking_amount => sprintf('%.2f', 0.0),
            booking_amount_formatted => $self->formatAmountWithCurrency(0.0)
        };
        
        # get the starting balance for the first transaction of the selected period
        my $query = q{
            SELECT  a.current_balance as balance
            FROM cash_register_account a
            WHERE     a.id = (SELECT MAX(b.id) FROM cash_register_account b WHERE b.booking_time < ? and b.cash_register_id = ? ) 
                  AND a.cash_register_id = ?
           }; $query =~ s/^\s+/ /mg;
        my $sth = $dbh->prepare($query);
        $sth->execute(DateTime::Format::MySQL->format_datetime($date_from), $id, $id);
        if (my $row = $sth->fetchrow_hashref) {
            $result->{$id}->{starting_balance} = {
                booking_amount => sprintf('%.2f', $row->{balance}),
                booking_amount_formatted => $self->formatAmountWithCurrency($row->{balance})
            };
            $result->{'sum'}->{starting_balance}->{amount} += $row->{balance};
        }
        
        # get the final balance at the end selected period
        $query = q{
            SELECT  a.current_balance as balance
            FROM cash_register_account a
            WHERE     a.id = (SELECT MAX(b.id) FROM cash_register_account b WHERE b.booking_time <= ? and b.cash_register_id = ? ) 
                  AND a.cash_register_id = ?
           }; $query =~ s/^\s+/ /mg;
        $sth = $dbh->prepare($query);
        $sth->execute(DateTime::Format::MySQL->format_datetime($date_to), $id, $id);
        if (my $row = $sth->fetchrow_hashref) {
            $result->{$id}->{final_balance} = {
                booking_amount => sprintf('%.2f', $row->{balance}),
                booking_amount_formatted => $self->formatAmountWithCurrency($row->{balance})
            };
            $result->{'sum'}->{final_balance}->{amount} += $row->{balance};
        }
        else {
             $result->{$id}->{final_balance} = $result->{$id}->{starting_balance};
        }
        
        $result->{$id}->{info} = $self->loadCashRegister($id);
    }

    # get payments of cash registers
    my $query = q{
            SELECT a.cash_register_id as id, sum(a.booking_amount) as amount, count(*) count_transactions
            FROM   cash_register_account a, cash_register c, branches br
            WHERE  a.cash_register_id = c.id 
               AND a.booking_amount > 0.00
               AND a.booking_time >= ? and a.booking_time <= ?
               AND c.branchcode = br.branchcode
               AND ( br.branchcode = ? OR br.mobilebranch = ? )
            GROUP BY a.cash_register_id
        }; $query =~ s/^\s+/ /mg;

    my $sth = $dbh->prepare($query);
    $sth->execute( 
        DateTime::Format::MySQL->format_datetime($date_from),
        DateTime::Format::MySQL->format_datetime($date_to),
        $branchcode,
        $branchcode
    );
    while (my $row = $sth->fetchrow_hashref) {
       my $amount = $row->{amount};
       $result->{'sum'}->{payment}->{amount} += $amount;
       $row->{booking_amount} = sprintf('%.2f', $amount);
       $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
       $result->{$row->{id}}->{payment} = $row;
       $result->{$row->{id}}->{bookings_found} = 1;
    }
    $sth->finish;
    
    # get payouts of cash registers
    $query = q{
            SELECT a.cash_register_id as id, sum(a.booking_amount) as amount, count(*) count_transactions
            FROM   cash_register_account a, cash_register c, branches br
            WHERE  a.cash_register_id = c.id 
               AND a.booking_amount < 0.00
               AND a.booking_time >= ? and a.booking_time <= ?
               AND c.branchcode = br.branchcode
               AND ( br.branchcode = ? OR br.mobilebranch = ? )
            GROUP BY a.cash_register_id
        }; $query =~ s/^\s+/ /mg;

    $sth = $dbh->prepare($query);
    $sth->execute( 
        DateTime::Format::MySQL->format_datetime($date_from),
        DateTime::Format::MySQL->format_datetime($date_to),
        $branchcode,
        $branchcode
    );
    while (my $row = $sth->fetchrow_hashref) {
       my $amount = $row->{amount};
       $result->{'sum'}->{payout}->{amount} += $amount;
       $row->{booking_amount} = sprintf('%.2f', $amount);
       $row->{booking_amount_formatted} = $self->formatAmountWithCurrency($amount);
       $result->{$row->{id}}->{payout} = $row;
       $result->{$row->{id}}->{bookings_found} = 1;
    }
    $sth->finish;
    
    # get all transactions which are not related to cash registers
    # get payments of cash registers
    $query = q{
            SELECT a.accounttype accounttype, sum(a.amount-a.amountoutstanding) as amount, count(*) count_transactions
            FROM   accountlines a, borrowers b, branches br
            WHERE  a.amount-a.amountoutstanding <> 0.00
               AND a.date >= ? and a.date <= ?
               AND a.manager_id = b.borrowernumber
               AND a.branchcode = br.branchcode
               AND ( br.branchcode = ? OR br.mobilebranch = ? )
               AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'C', 'REF')
               AND NOT EXISTS (SELECT 1 FROM cash_register_account c WHERE c.accountlines_id = a.accountlines_id)
            GROUP BY b.branchcode, a.accounttype

            UNION ALL
            SELECT a.accounttype accounttype, sum(a.amount-a.amountoutstanding) as amount, count(*) count_transactions
            FROM   accountlines a, deletedborrowers b, branches br
            WHERE  a.amount-a.amountoutstanding <> 0.00
               AND a.date >= ? and a.date <= ?
               AND a.manager_id = b.borrowernumber
               AND a.branchcode = br.branchcode
               AND ( br.branchcode = ? OR br.mobilebranch = ? )
               AND a.accounttype IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'C', 'REF')
               AND NOT EXISTS (SELECT 1 FROM cash_register_account c WHERE c.accountlines_id = a.accountlines_id)
            GROUP BY b.branchcode, a.accounttype
        }; $query =~ s/^\s+/ /mg;

    $sth = $dbh->prepare($query);
    $sth->execute( 
        DateTime::Format::MySQL->format_date($date_from),
        DateTime::Format::MySQL->format_date($date_to),
        $branchcode,
        $branchcode,
        DateTime::Format::MySQL->format_date($date_from),
        DateTime::Format::MySQL->format_date($date_to),
        $branchcode,
        $branchcode
    );
    
    my @ptypes = ('cash','card','unassigned');

    foreach my $type(@ptypes) {
        $result->{$type}->{payment} = {
            amount => 0.0,
            count_transactions => 0
        };
        $result->{$type}->{payout} = {
            amount => 0.0,
            count_transactions => 0
        };
        $result->{$type}->{bookings_found} = 0;
    }
    
    while (my $row = $sth->fetchrow_hashref) {
        my $amount = $row->{'amount'} * -1;
        my $acctype = $row->{'accounttype'};
        my $type = 'unassigned';
        if ( $acctype eq 'Pay00' ) {
            $type = 'cash';
        }
        elsif ( $acctype eq 'Pay01' || $acctype eq 'Pay02' ) {
            $type = 'card';
        }
        my $what = 'payout';
        if ( $amount >= 0.00 ) {
            # it's a payment
            $what = 'payment';
        }
        $result->{'sum'}->{$what}->{amount} += $amount;
        $result->{$type}->{$what}->{amount} += $amount;
        $result->{$type}->{$what}->{count_transactions} += $row->{count_transactions};
        $result->{$type}->{bookings_found} = 1;
    }
    $sth->finish;
    
    push(@ptypes, 'sum');
    foreach my $type(@ptypes) {
        $result->{$type}->{payment}->{booking_amount} = sprintf('%.2f', $result->{$type}->{payment}->{amount} || 0.0);
        $result->{$type}->{payment}->{booking_amount_formatted} = $self->formatAmountWithCurrency($result->{$type}->{payment}->{amount});
        $result->{$type}->{payout}->{booking_amount} = sprintf('%.2f', $result->{$type}->{payout}->{amount} || 0.0);
        $result->{$type}->{payout}->{booking_amount_formatted} = $self->formatAmountWithCurrency($result->{$type}->{payout}->{amount});
    }
    $result->{sum}->{starting_balance}->{booking_amount} = sprintf('%.2f', $result->{sum}->{starting_balance}->{amount});
    $result->{sum}->{starting_balance}->{booking_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{starting_balance}->{amount});
    $result->{sum}->{final_balance}->{booking_amount} = sprintf('%.2f', $result->{sum}->{final_balance}->{amount});
    $result->{sum}->{final_balance}->{booking_amount_formatted} = $self->formatAmountWithCurrency($result->{sum}->{final_balance}->{amount});
    
    
    return ($result,output_pref({dt => dt_from_string($date_from), dateonly => 0}),output_pref({dt => dt_from_string($date_to), dateonly => 0}));
}


=head2 addCashRegisterTransaction

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
    my $reason = shift;
    my $accountlines_id = shift;
    
    if (! $amount ) {
        $amount = 0.00;
    }
    
    my $trials = 0;
    # Avoiding use of stale booking_amount with concurrent inserts, 
    # because storing with same cash_register_id and cash_register_account_id will fail with message:
    # paycollect.pl: DBIx::Class::Storage::DBI::_dbh_execute(): Duplicate entry '...' for key 'cash_reg_account_idx_account_id'
    while ( $trials < 11 ) {
        $trials += 1;
        # retrieve last transaction data of this cash register
        my $lastTransaction = $self->getLastBooking($cash_register_id);
        if (! $lastTransaction ) {
            $lastTransaction = {
                cash_register_account_id => 0,
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
        elsif ( $action eq 'DEPOSIT' ) {
        }
        elsif ( $action eq 'ADJUSTMENT' ) {
        }
        elsif ( $action eq 'CREDIT' ) {
        }
        else {
            return 0;
        }
        
        # set parameter to store
        my $params = {
            cash_register_id => $cash_register_id,
            cash_register_account_id => $lastTransaction->{cash_register_account_id} + 1,    # This may clash with a concurrent insert, but there are further attempts.
            manager_id => $manager_id,
            current_balance => $lastTransaction->{current_balance} + $amount,
            booking_amount => $amount,
            accountlines_id => $accountlines_id,
            action => $action,
            description => $comment,
            reason => $reason
        };
        
        my $entry = Koha::CashRegister::CashRegisterAccount->new();
        $entry->set($params);
        my $res = eval { $entry->store() };

        if ( defined($res) ) {
            return 1;    # $entry->store() did succeed
        }
        if ( $trials >= 10 ) {
            $entry->store();    # if failing: die and show error message in dialog 
            return 1;
        }
    }
    return 0;
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
    
    if (! $lastOpeningId ) {
        $query = q{
            SELECT min(a.id) as id
            FROM   cash_register_account a
            WHERE  a.cash_register_id = ?
           }; $query =~ s/^\s+/ /mg;
        $sth = $dbh->prepare($query);
        $sth->execute($cash_register_id);
        if (my $row = $sth->fetchrow_hashref) {
            if ( $row && $row->{'id'} ) {
                $lastOpeningId =  $row->{'id'};
            }
        }
        $sth->finish;
    }
    
    # lets now retrieve the data of the last oping action
    my $lastOpeningAction = Koha::CashRegister::CashRegisterAccounts->find({ id => $lastOpeningId });
    return undef if (! $lastOpeningAction );
    
    my $result = {
        'opening_balance' => sprintf('%.2f', $lastOpeningAction->current_balance()),
        'opening_balance_formatted' => $self->formatAmountWithCurrency($lastOpeningAction->current_balance()),
        'opening_manager_id' => $lastOpeningAction->manager_id(),
        'opening_manager' => $self->{managers}->{$lastOpeningAction->manager_id()}->{fullname},
        'opening_booking_time' => output_pref ( { dt => dt_from_string($lastOpeningAction->booking_time()) } ),
        'inpayments_amount' => sprintf('%.2f', 0.00 ),
        'inpayments_amount_formatted' => $self->formatAmountWithCurrency(0.00),
        'inpayments_count' => 0,
        'payouts_amount' => sprintf('%.2f', 0.00 ),
        'payouts_amount_formatted' => $self->formatAmountWithCurrency(0.00),
        'payouts_count' => 0,
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
    
    # read the amount of payments that filled the cash register
    $query = q{
        SELECT DISTINCT manager_id
        FROM   cash_register_manager
        WHERE  cash_register_id = ? AND opened = 1 AND manager_id <> ?
       }; $query =~ s/^\s+/ /mg;
    $sth = $dbh->prepare($query);
    $sth->execute($cash_register_id,$lastOpeningAction->manager_id());
    my $additionalOpener = 0;
    $result->{'also_used_by_manager_id'} = [];
    while (my $row = $sth->fetchrow_hashref) {
        if ( $row && $row->{manager_id} ) {
            $result->{'also_used_by_manager'}->[$additionalOpener++] = 
                { id => $row->{manager_id}, name => $self->{managers}->{$row->{manager_id}}->{fullname} };
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

sub getPaidChargesByAccountType {
    my $params = shift;
    
    if ( defined($params) && defined($params->{branchcode}) ) {
    
    }
}

1;
