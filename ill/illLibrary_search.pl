#!/usr/bin/perl

# Copyright 2018-2024 (C) LMSCloud GmbH
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

use CGI qw ( -utf8 );
use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::Members;

use Koha::Patron::Categories;

my $input = new CGI;

my $patrontype = ($input->param('patrontype') || 'owni');
my @illPatronCategories = split(/,/,$input->param('illcategories'));
my $kohaIllPatronCategories = [];
foreach my $catcode (@illPatronCategories) {
    my $rs = Koha::Patron::Categories->search({categorycode => $catcode});
    if ( my $categoryres = $rs->next ) {
        push @$kohaIllPatronCategories, { categorycode => $categoryres->categorycode, description => $categoryres->description };
    }
}
my $searchmember = $input->param('searchmember');
my @attribute_type_codes = ( 'Sigel' );
if ( C4::Context->preference('ExtendedPatronAttributes') ) {
    push @attribute_type_codes, @{[ Koha::Patron::Attribute::Types->search( { staff_searchable => 1 } )->get_column('code') ]};
}

my ( $template, $loggedinuser, $cookie, $staff_flags ) = get_template_and_user(
    {   template_name   => "ill/illLibrary_search.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 'edit_borrowers' },
    }
);

$template->param(
    columns => ['cardnumber', 'name', 'city', 'extended_attribute_SIGEL', 'category', 'action' ],
    default_sort_column => 'name',
    selection_type => 'select',
    ill_patronclass_lmsc => 'ILL_library',
    ill_patrontype_lmsc => $patrontype,
    categories => $kohaIllPatronCategories,
    searchmember => $searchmember,
    attribute_type_codes => \@attribute_type_codes,
);

output_html_with_http_headers( $input, $cookie, $template->output );
