package Koha::CashRegister::CashRegisterAccounts;

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


use Modern::Perl;
use Koha::Database;
use base qw(Koha::Objects);

=head1 NAME

Koha::CashRegister::CashRegistersAccounts - Cash register accounts class

=head1 DESCRIPTION

The cash register account is used to manage cash register transactions. 
Actions are open and close the cash register, pay in, pay out, and adjust the
the cash register balance.
Payment actions (except pay outs) and refunds link typically to the accountline
bookings.

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub _type {
    return 'CashRegisterAccount';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::CashRegister::CashRegisterAccount';
}

1;
