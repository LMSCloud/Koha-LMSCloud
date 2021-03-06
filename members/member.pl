#!/usr/bin/perl


#script to do a borrower enquiry/bring up borrower details etc
#written 20/12/99 by chris@katipo.co.nz


# Copyright 2000-2002 Katipo Communications
# Copyright 2013 BibLibre
# parts Copyright 2018 (C) LMSCLoud GmbH
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
use C4::Auth;
use C4::Output;
use CGI qw( -utf8 );
use Koha::DateUtils;
use Koha::List::Patron;
use Koha::Patrons;

my $input = new CGI;

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/member.tt",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {borrowers => 'edit_borrowers'},
                 });

my $theme = $input->param('theme') || "default";

my $searchmember = $input->param('searchmember');
my $quicksearch = $input->param('quicksearch') // 0;

if ( $quicksearch and $searchmember ) {
    my $branchcode;
    if ( C4::Context::only_my_library ) {
        my $userenv = C4::Context->userenv;
        $branchcode = $userenv->{'branch'};
    }
    my $patron = Koha::Patrons->find( { cardnumber => $searchmember } );
    if (
        $patron
        and (  ( $branchcode and $patron->branchcode eq $branchcode )
            or ( not $branchcode ) )
      )
    {
        print $input->redirect( "/cgi-bin/koha/members/moremember.pl?borrowernumber=" . $patron->borrowernumber );
        exit;
    }
}

my $searchfieldstype = $input->param('searchfieldstype') || 'standard';

$template->param( 'alphabet' => C4::Context->preference('alphabet') || join ' ', 'A' .. 'Z' );

my $view = $input->request_method() eq "GET" ? "show_form" : "show_results";

$template->param(
    patron_lists => [ GetPatronLists() ],
    searchmember        => $searchmember,
    branchcode_filter   => scalar $input->param('branchcode_filter'),
    categorycode_filter => scalar $input->param('categorycode_filter'),
    searchtype          => scalar $input->param('searchtype') || 'contain',
    searchfieldstype    => $searchfieldstype,
    chargesfrom         => scalar $input->param('chargesfrom'),
    chargesto           => scalar $input->param('chargesto'),
    chargessince        => scalar $input->param('chargessince'),
    accountexpiresto    => scalar $input->param('accountexpiresto'),
    accountexpiresfrom  => scalar $input->param('accountexpiresfrom'),
    debarreduntilto     => scalar $input->param('debarreduntilto'),
    debarreduntilfrom   => scalar $input->param('debarreduntilfrom'),
    agerangestart       => scalar $input->param('agerangestart'),
    agerangeend         => scalar $input->param('agerangeend'),
    lastlettercode      => scalar $input->param('lastlettercode'),
    overduelevel        => scalar $input->param('overduelevel'),
    inactivesince       => scalar $input->param('inactivesince'),
    issuecountstart     => scalar $input->param('issuecountstart'),
    issuecountend       => scalar $input->param('issuecountend'),
    validemailavailable => scalar $input->param('validemailavailable'),
    patronlistid        => scalar $input->param('patronlistid'),
    PatronsPerPage      => C4::Context->preference("PatronsPerPage") || 20,
    view                => $view,
);

output_html_with_http_headers $input, $cookie, $template->output;
