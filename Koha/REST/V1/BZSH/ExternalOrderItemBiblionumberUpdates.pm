package Koha::REST::V1::BZSH::ExternalOrderItemBiblionumberUpdates;

# Copyright 2019 LMSCloud GmbH
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

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

use Scalar::Util qw(blessed);
use Try::Tiny;

use DateTime::Format::MySQL;
use DateTime::Format::W3CDTF;

use C4::Context;

=head1 NAME

Koha::REST::V1::BZSH::ExternalOrderItemBiblionumberUpdates

=head1 API

=head2 Methods


=head3 add

Controller function to deliver information about biblionumber updates of externally ordered items.
Uses a proprietary table which is filled by a trigger on the items table.

=cut

sub getExternalOrderItemBiblionumberUpdates {
    
    my $argvalue = shift;
    my $c = $argvalue->openapi->valid_input or return;

    return try {		
        my ($responsecode, $changes, $count) = &handleExternalOrderItemBiblionumberUpdates($c);
        return $c->render( status => $responsecode, openapi => { count_changes => $count, changes => $changes } );
    }
    catch {
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
        return $c->render(
            status  => 500,
            openapi => { error => "Something went wrong, check Koha logs for details." }
        );
    };
}

sub handleExternalOrderItemBiblionumberUpdates {
    my $params = shift;
    
    my $respcode = '200';
    my $changes = [];
    my $resultcount = 0;
    
	my $changes_since = $params->param('changes_since');
	if ( $changes_since ) {
		my $changes_from;
		eval { $changes_from = DateTime::Format::W3CDTF->new()->parse_datetime($changes_since); };
		$changes_since = DateTime::Format::MySQL->format_datetime($changes_from) if ($changes_from);
	}
	
	my $dbh = C4::Context->dbh;
	
	my $select = qq{
        SELECT upd.biblionumber_old AS biblionumber_old,
               upd.biblionumber_new AS biblionumber,
               upd.external_order_id AS external_order_id,
               upd.branchcode AS library_id,
               upd.created AS change_time
        FROM   bzsh_item_biblio_update upd
               JOIN external_order ord ON (upd.external_order_id = ord.external_order_id)
        };
    if ( $changes_since ) {
		$select .= ' WHERE upd.created >= ? '
	}
	$select .= 'ORDER BY upd.created';
	
	my $pagesize   = $params->{'_per_page'};
	my $pagenumber = $params->{'_page'};
	
	if ( $pagesize ) {
		$pagenumber = 1 if (! $pagenumber);
		my $offset = $pagesize * ($pagenumber - 1);
		$select .= " LIMIT $offset, $pagesize";
	}
	
	my $sth = $dbh->prepare($select);
	if ( $changes_since ) {
		$sth->execute($changes_since);
	} else {
		$sth->execute();
	}
    
	while ( my $change = $sth->fetchrow_hashref ) {
		my $dt = DateTime::Format::MySQL->parse_datetime($change->{change_time});
		$change->{change_time} = DateTime::Format::W3CDTF->new()->format_datetime($dt);
		push @$changes, $change;
		$resultcount++;
	}
	$sth->finish();

    return ($respcode,$changes,$resultcount);
}

1;

# print Dumper(handleExternalOrderItemBiblionumberUpdates({ changes_since => '2022-11-30T17:19:53' }));
