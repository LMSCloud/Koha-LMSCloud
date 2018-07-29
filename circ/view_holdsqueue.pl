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


=head1 view_holdsqueue

This script displays items in the tmp_holdsqueue table

=cut

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::HoldsQueue qw(GetHoldsQueueItems);
use Koha::BiblioFrameworks;

use Koha::ItemTypes;

my $query = new CGI;
my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "circ/view_holdsqueue.tt",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
        debug           => 1,
    }
);

my $params = $query->Vars;
my $run_report     = $params->{'run_report'};
my $branchlimit    = $params->{'branchlimit'};
my $itemtypeslimit = $params->{'itemtypeslimit'};

if ( $run_report ) {
    # XXX GetHoldsQueueItems() does not support $itemtypeslimit!
    my $items = GetHoldsQueueItems($branchlimit, $itemtypeslimit);
    for my $item ( @$items ) {
        $item->{patron} = Koha::Patrons->find( $item->{borrowernumber} );
    }
    $template->param(
        branchlimit     => $branchlimit,
        total      => scalar @$items,
        itemsloop  => $items,
        run_report => $run_report,
    );
}

# Checking if there is a Fast Cataloging Framework
$template->param( fast_cataloging => 1 ) if Koha::BiblioFrameworks->find( 'FA' );

# writing the template
output_html_with_http_headers $query, $cookie, $template->output;
