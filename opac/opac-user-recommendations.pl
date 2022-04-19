#!/usr/bin/perl

# Copyright 2022 LMSCloud GmbH
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
use C4::Context;
use C4::Koha;

use C4::Output;
use Koha::Patrons;
use C4::External::BibtipRecommendations;

use Koha::ItemTypes;

my $query = CGI->new;

# if opacreadinghistory is disabled, leave immediately
if ( ! C4::Context->preference('opacreadinghistory') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-user-recommendations.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        debug           => 1,
    }
);

if ( $borrowernumber ) {
    my $borrower = Koha::Patrons->find( $borrowernumber );
    my $privacy = $borrower->privacy();

    $template->param( privacy => $privacy );
}

$template->param(
    recommendationview => 1
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
