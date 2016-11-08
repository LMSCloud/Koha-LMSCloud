#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2013 BibLibre
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
use Carp;

use C4::Auth qw(:DEFAULT get_session);
use CGI qw( -utf8 );
use C4::Context;
use C4::Output;
use C4::Log;
use C4::Debug;
use C4::Branch;
use C4::Members;
use Koha::Patron::Discharge;
use Koha::DateUtils;

my $input = new CGI;

unless ( C4::Context->preference('useDischarge') ) {
    print $input->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $op = $input->param("op");

# Getting the template and auth
my ( $template, $loggedinuser, $cookie ) = get_template_and_user({
    template_name => "opac-discharge.tt",
    query         => $input,
    type          => "opac",
    debug         => 1,
});

if ( $op eq 'request' ) {
    my $success = Koha::Patron::Discharge::request({
        borrowernumber => $loggedinuser,
    });

    if ($success) {
        $template->param( success => 1 );
    }
    else {
        $template->param( has_issues => 1 );
    }
}
elsif ( $op eq 'get' ) {
    eval {

        # Getting member data
        my $data = GetMember( borrowernumber => $loggedinuser );
        my $pdf_path = Koha::Patron::Discharge::generate_as_pdf({
            borrowernumber => $loggedinuser,
            branchcode => $data->{'branchcode'},
        });

        binmode(STDOUT);
        print $input->header(
            -type       => 'application/pdf',
            -charset    => 'utf-8',
            -attachment => "discharge_$loggedinuser.pdf",
        );
        open my $fh, '<', $pdf_path;
        my @lines = <$fh>;
        close $fh;
        print @lines;
        exit;
    };
    if ( $@ ) {
        carp $@;
        $template->param( messages => [ {type => 'error', code => 'unable_to_generate_pdf'} ] );
    }
}
else {
    my $pending = Koha::Patron::Discharge::count({
        borrowernumber => $loggedinuser,
        pending        => 1,
    });
    # FIXME looks like $available is not needed
    # If a patron is discharged he has a validated discharge available
    my $available = Koha::Patron::Discharge::count({
        borrowernumber => $loggedinuser,
        validated      => 1,
    });
    $template->param(
        available => $available && Koha::Patron::Discharge::is_discharged({borrowernumber => $loggedinuser}),
        pending   => $pending,
    );
}

$template->param( dischargeview => 1 );

output_html_with_http_headers $input, $cookie, $template->output, undef, { force_no_caching => 1 };
