package Koha::Exceptions::CurbsidePickup;

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

use Koha::Exception;

use Exception::Class (

    'Koha::Exceptions::CurbsidePickup' => {
        isa => 'Koha::Exception',
    },
    'Koha::Exceptions::CurbsidePickup::NotEnabled' => {
        isa         => 'Koha::Exceptions::CurbsidePickup',
        description => 'Curbside pickups are not enable for this library',
    },
    'Koha::Exceptions::CurbsidePickup::LibraryIsClosed' => {
        isa         => 'Koha::Exceptions::CurbsidePickup',
        description => 'Cannot create a pickup on a closed day',
    },
    'Koha::Exceptions::CurbsidePickup::TooManyPickups' => {
        isa         => 'Koha::Exceptions::CurbsidePickup',
        description => 'Patron already has a scheduled pickup for this library',
        fields      => [ 'branchcode', 'borrowernumber' ],
    },
    'Koha::Exceptions::CurbsidePickup::NoMatchingSlots' => {
        isa         => 'Koha::Exceptions::CurbsidePickup',
        description => 'Cannot create a pickup with this pickup datetime',
    },
    'Koha::Exceptions::CurbsidePickup::NoMorePickupsAvailable' => {
        isa         => 'Koha::Exceptions::CurbsidePickup',
        description => 'No more pickups available for this slot',
    },
    'Koha::Exceptions::CurbsidePickup::NoWaitingHolds' => {
        isa         => 'Koha::Exceptions::CurbsidePickup',
        description => 'Cannot create a pickup, patron does not have waiting holds',
    },
);

1;
