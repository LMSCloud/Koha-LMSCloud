#!/usr/bin/perl

# Copyright 2026 LMSCloud GmbH
# License: GPL-3.0-or-later

=head1 NAME

acquisition-import-viewer.pl - Staff-Interface-Seite für Acquisition-Import-Tabellen

=head1 DESCRIPTION

Rendert die Viewer-Seite für die Tabellen C<acquisition_import> und
C<acquisitions_import_objects>. Die eigentlichen Daten werden im Browser
per JavaScript direkt über die Koha REST API abgefragt
(C</api/v1/acquisitionimports/...>).

Erforderliche Berechtigung: C<tools → acquisition_import_viewer>

=cut

use Modern::Perl;
use CGI qw(:standard);
use C4::Auth   qw(get_template_and_user);
use C4::Output qw(output_html_with_http_headers);

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'tools/acquisition-import-viewer.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { tools => 'acquisition_import_viewer' },
    }
);

output_html_with_http_headers $input, $cookie, $template->output;