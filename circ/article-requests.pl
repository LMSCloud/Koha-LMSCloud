#!/usr/bin/perl

# Copyright 2015 ByWater Solutions
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

use C4::Auth;
use C4::Output;
use Koha::ArticleRequests;

my $query = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/article-requests.tt",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
    }
);

my $branchcode = defined( $query->param('branchcode') ) ? $query->param('branchcode') : C4::Context->userenv->{'branch'};

$template->param(
    branchcode                  => $branchcode,
    article_requests_pending    => scalar Koha::ArticleRequests->pending($branchcode),
    article_requests_processing => scalar Koha::ArticleRequests->processing($branchcode),
);

output_html_with_http_headers $query, $cookie, $template->output;
