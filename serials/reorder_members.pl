#!/usr/bin/perl
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

# Routing.pl script used to create a routing list for a serial subscription
# In this instance it is in fact a setting up of a list of reserves for the item
# where the hierarchical order can be changed on the fly and a routing list can be
# printed out
use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Auth qw( checkauth );
use C4::Serials qw( reorder_members );

my $query          = CGI->new;
my $subscriptionid = $query->param('subscriptionid');
my $routingid      = $query->param('routingid');
my $rank           = $query->param('rank');

checkauth( $query, 0, { serials => 'routing' }, 'intranet' );

reorder_members( $subscriptionid, $routingid, $rank );

print $query->redirect(
    "/cgi-bin/koha/serials/routing.pl?subscriptionid=$subscriptionid");

