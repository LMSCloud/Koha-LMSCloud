#!/usr/bin/perl

# Copyright 2013 ByWater Solutions
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

use CGI;

use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use Koha::Patrons;

my $cgi = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "clubs/clubs-tab.tt",
        query           => $cgi,
        type            => "opac",
    }
);

my $patron = Koha::Patrons->find( $loggedinuser );

my @enrollments = $patron->get_club_enrollments->as_list;
my @clubs = $patron->get_enrollable_clubs( my $opac = 1 )->as_list;

$template->param(
    enrollments => \@enrollments,
    clubs       => \@clubs,
    patron      => $patron,
);

output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } );
