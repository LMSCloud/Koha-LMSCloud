package Koha::AggregatedStatistics::AggregatedStatisticsParameters;

# Copyright 2017 (C) LMSCLoud GmbH
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

use Carp;

use Koha::Database;

use Koha::AggregatedStatistics::AggregatedStatisticsParameter;

use base qw(Koha::Objects);

=head1 NAME

Koha::AggregatedStatistics::AggregatedStatisticsParameters - Koha additional statistics parameters Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub _type {
    return 'AggregatedStatisticsParameter';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::AggregatedStatistics::AggregatedStatisticsParameter';
}

=head3 upd_or_ins

=cut
                                           
sub upd_or_ins {
    my ($self, $selparam, $updparam, $insparam) = @_;

    my $rs = $self->_resultset();

    my $hit = $rs->find( $selparam );
    if ( defined $hit ) {
        $hit->update( $updparam );
    } else
    {
        $hit = $self->_resultset()->create($insparam);
    }
    #$self->{statistics_id} = $hit->{_column_data}->{statistics_id};
    $self = Koha::AggregatedStatistics::AggregatedStatisticsParameters->_new_from_dbic( $hit );

    return $self;
}

1;
