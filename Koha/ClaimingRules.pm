package Koha::ClaimingRules;

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

Koha::ClaimingRules - Koha ClaimingRules object set class

=head1 DESCRIPTION

Claiming fee rules store configurations for charging claiming fees for overdue items.
A rule consists of 5 values:
- id 
- branchcode
- item type
- borrower category
- claiming fee for the 1st reminder
- claiming fee for the 2nd reminder
- claiming fee for the 3rd reminder
- claiming fee for the 4th reminder
- claiming fee for the 5th reminder
Claiming rules can contain a specific defined value for branchcode, item type, or
borrower category or an asterix '*' which is wildcard for any possible value.
Rules with a specific value are more relevant than a rule with a wildcard value.

The rules are applied from most specific to less specific, using the first found in this order:
- same library, same patron type, same item type
- same library, same patron type, all item types
- same library, all patron types, same item type
- same library, all patron types, all item types
- default (all libraries), same patron type, same item type
- default (all libraries), same patron type, all item types
- default (all libraries), all patron types, same item type
-default (all libraries), all patron types, all item types

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub _type {
    return 'ClaimingRule';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ClaimingRule';
}

1;
