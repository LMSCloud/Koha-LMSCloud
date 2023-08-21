package C4::ClassSplitRoutine;

# Copyright 2022 Koha Development Team
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

use Class::Factory::Util;

our (@ISA, @EXPORT_OK);
BEGIN {
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT_OK = qw(
       GetSplitRoutineNames
    );
}

=head1 NAME

C4::ClassSplitRoutine - base object for creation of classification splitting routines

=head1 SYNOPSIS

use C4::ClassSplitRoutine;

=head1 FUNCTIONS

=cut

=head2 GetSplitRoutineNames

  my @routines = GetSplitRoutineNames();

Get names of all modules under C4::ClassSplitRoutine::*.

=cut

sub GetSplitRoutineNames {
    return C4::ClassSplitRoutine->subclasses();
}

1;

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut
