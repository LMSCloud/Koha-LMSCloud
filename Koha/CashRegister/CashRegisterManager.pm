package Koha::CashRegister::CashRegisterManager;

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
use base qw(Koha::Object);

=head1 NAME

Koha::CashRegister::CashRegisterManager - Cash register manager class

=head1 DESCRIPTION

The assign staff members to cash registers.
Staff assigned to registers can open, close, pay to and pay out of a cash register.

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub _type {
    return 'CashRegisterManager';
}

1;
