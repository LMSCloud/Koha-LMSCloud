#!/usr/bin/perl

# Copyright 2018 LMSCloud GmbH
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
use Data::Dumper;

use CGI qw ( -utf8 );
use C4::Auth;
use C4::Output;
use C4::Members;

use Koha::Patron::Categories;

my $input = new CGI;
print STDERR "ill::illLibrary_search input:", Dumper($input), ":\n";
my @illPatronCategories = split(/,/,$input->param('illcategories'));
    my $kohaIllPatronCategories = [];
    foreach my $catcode (@illPatronCategories) {
        my $rs = Koha::Patron::Categories->search({categorycode => $catcode});
        if ( my $categoryres = $rs->next ) {
            push @$kohaIllPatronCategories, { categorycode => $categoryres->categorycode, description => $categoryres->description };
        }
    }

my ( $template, $loggedinuser, $cookie, $staff_flags ) = get_template_and_user(
    {   template_name   => "common/illLibrary_search.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 'edit_borrowers' },
    }
);

$template->param(
    view => ( $input->request_method() eq "GET" ) ? "show_form" : "show_results",
    columns => ['cardnumber', 'name', 'borr_attr_attribute_SIGEL', 'city', 'action' ],
    json_template => 'members/tables/illLibrary_results.tt',
    selection_type => 'select',
    return_borrower_attributes => 'SIGEL',
    alphabet        => ( C4::Context->preference('alphabet') || join ' ', 'A' .. 'Z' ),
    categories      => $kohaIllPatronCategories,
    aaSorting       => 1,
);
output_html_with_http_headers( $input, $cookie, $template->output );
