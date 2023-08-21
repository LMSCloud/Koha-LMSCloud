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

=head1 updatechild.pl

    script to update a child member to (usually) an adult member category

    - if called with op=multi, will return all available non child categories, for selection.
    - if called with op=update, script will update member record via Koha::Patron->store.

=cut

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Context;
use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers output_and_exit_if_error output_and_exit );
use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::Patrons;

my $dbh   = C4::Context->dbh;
my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "members/update-child.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => { borrowers => 'edit_borrowers' },
    }
);

my $borrowernumber = $input->param('borrowernumber');
my $catcode        = $input->param('catcode');
my $cattype        = $input->param('cattype');
my $op             = $input->param('op');

my $logged_in_user = Koha::Patrons->find( $loggedinuser );

my $patron_categories = Koha::Patron::Categories->search_with_library_limits({ category_type => 'A' }, {order_by => ['categorycode']});
if ( $op eq 'multi' ) {
    # FIXME - what are the possible upgrade paths?  C -> A , C -> S ...
    #   currently just allowing C -> A
    $template->param(
        MULTI             => 1,
        borrowernumber    => $borrowernumber,
        patron_categories => $patron_categories,
    );
    output_html_with_http_headers $input, $cookie, $template->output;
}
elsif ( $op eq 'update' ) {
    my $patron         = Koha::Patrons->find( $borrowernumber );
    output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

    my $adult_category;
    if ( $patron_categories->count == 1 ) {
        $adult_category = $patron_categories->next;
    } else {
        $adult_category = $patron_categories->search({'me.categorycode' => $catcode })->next;
    }

    # Just in case someone is trying something bad
    # But we should not hit that with a normal use of the interface
    die "You are doing something wrong updating this child" unless $adult_category;

    $_->delete() for $patron->guarantor_relationships->as_list;

    $patron->categorycode($adult_category->categorycode);
    $patron->store;

    # FIXME We should not need that
    # We could redirect with a friendly message
    if ( $patron_categories->count > 1 ) {
        $template->param(
            SUCCESS        => 1,
            borrowernumber => $borrowernumber,
        );
        output_html_with_http_headers $input, $cookie, $template->output;
    }
    else {
        print $input->redirect(
            "/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrowernumber"
        );
    }
}

