#!/usr/bin/perl

# Copyright 2009 BibLibre
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
use Encode qw(encode);

use C4::Auth;
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::Record;
use C4::Ris;

use Koha::CsvProfiles;
use Koha::Virtualshelves;

use utf8;
my $query = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user (
    {
        template_name   => "virtualshelves/downloadshelf.tt",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
    }
);

my $shelfid = $query->param('shelfid');
my $format  = $query->param('format');
my $dbh     = C4::Context->dbh;
my @messages;

if ($shelfid && $format) {

    my $marcflavour         = C4::Context->preference('marcflavour');
    my $output='';

    my $shelf = Koha::Virtualshelves->find($shelfid);
    if ( $shelf ) {
        if ( $shelf->can_be_viewed( $loggedinuser ) ) {

            my $contents = $shelf->get_contents;
            # CSV
            if ($format =~ /^\d+$/) {
                my @biblios;
                while ( my $content = $contents->next ) {
                    push @biblios, $content->biblionumber->biblionumber;
                }
                $output = marc2csv(\@biblios, $format);
            }
            else { #Other formats
                while ( my $content = $contents->next ) {
                    my $biblionumber = $content->biblionumber->biblionumber;
                    my $record = GetMarcBiblio($biblionumber, 1);
                    if ($format eq 'iso2709') {
                        $output .= $record->as_usmarc();
                    }
                    elsif ($format eq 'ris') {
                        $output .= marc2ris($record);
                    }
                    elsif ($format eq 'bibtex') {
                        $output .= marc2bibtex($record, $biblionumber);
                    }
                }
            }

            # If it was a CSV export we change the format after the export so the file extension is fine
            $format = "csv" if ($format =~ m/^\d+$/);

            print $query->header(
            -type => 'application/octet-stream',
            -'Content-Transfer-Encoding' => 'binary',
            -attachment=>"shelf.$format");
            print $output;
            exit;
        } else {
            push @messages, { type => 'error', code => 'unauthorized' };
        }
    } else {
        push @messages, { type => 'error', code => 'does_not_exist' };
    }
}
else {
    $template->param(csv_profiles => [ Koha::CsvProfiles->search({ type => 'marc' }) ]);
    $template->param(shelfid => $shelfid); 
}
$template->param( messages => \@messages );
output_html_with_http_headers $query, $cookie, $template->output;
