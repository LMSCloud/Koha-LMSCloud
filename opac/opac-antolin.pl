#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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


=head1 opac-antolin.pl

Antolin is a German initiative for kids and teenager encouraging them to read books, build knowlege about the books.
The Antolin website provides quiz where users can proove the reading experience and answer questions. 
The Antolin search provides a specific search parameter input screen to search Antolin books which belong to the stock of the library.
In order to perform the search it's necessary to run a script which compares the local bibliographic database with data retrieved from Antolin.
The script enriches the ccatalogue records with an specifc mark in field 693.$a (with ind2=2). 
Data about Antolin ist stored with the Links to Antolin an quiz in MARC field 856 with the following data:
	ind1: 4
	ind2: 2
	n: the Antonlin name
	u: the direct url to the book
	w: the Antolin book_id
	x: the number of uses of the quiz
	y: a link text consisting of Starting text and the Quiz name
	z: fitting age of the Quiz

In order to keep the catalogue data up-to-date, its necessary to run the script frequently.

=cut

use strict;
use warnings;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Biblio;
use C4::Koha;       # use getitemtypeinfo

my $query = new CGI;

my $dbh = C4::Context->dbh;

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-antolin.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
        debug           => 1,
    }
);


$template->param(
#    LEVEL_LOOP => \@level_loop,
#    HIERARCHY_LOOP => \@hierarchy_loop,
#    have_hierarchy => $have_hierarchy,
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
