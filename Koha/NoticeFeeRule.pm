package Koha::NoticeFeeRule;

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

Koha::NoticeFeeRules - Koha notice fee rule object set class

=head1 DESCRIPTION

Notice fee rules store configurations for charging notice fees when sending 
notifications to patrons.
The rules can contain a specific defined values for branchcode, borrower category, 
message transport type, letter code or an asterix '*' which is wildcard for any the 
possible values of the listed fields.

Rules with a specific value are more relevant than a rule with a wildcard value.
The rules are applied from most specific to less specific in the following field order:
branchcode, categorycode, letter_code and message_transport_type.

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub _type {
    return 'NoticeFeeRule';
}

1;
