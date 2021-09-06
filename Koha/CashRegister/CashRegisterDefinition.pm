package Koha::CashRegister::CashRegisterDefinition;

# Copyright LMCloud GmbH 2016, 2021
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
use Carp;

use base qw(Koha::Object);

=head1 NAME

Koha::CashRegister::CashRegisterDefinition - Cash register class

=head1 DESCRIPTION

Cash registers that are used in the library. If cash registers are enabled, all 
cash payments need to be reistered in a Cash. It's possible to define one ore more 
cash registers for a (branch) library and assign users that can use a cash register.

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub _type {
    return 'CashRegisterDefinition';
}

1;
