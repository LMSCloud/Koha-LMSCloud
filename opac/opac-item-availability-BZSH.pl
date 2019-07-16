#!/usr/bin/perl

# Copyright 2017-2019 (C) LMSCloud GmbH
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


=head1 opac-item-availability-BZSH.pl

The BZSH (Büchereizentrale Schleswig-Holstein) calls this item availability service
with the CGI request parameters 
  sigel : eindeutige Nummer zur Identifikation der Bibliothek
  TITEL : Titelnummer des Zentralkataloges
  SRISBN : ISBN Nummer im Zentralkatalog
  SRTIT : Stichworte der Titelaufnahme
  SRAUT : Autorwort(e)
  SRKORP : Körperschaft(en)
  LANG : optionaler Parameter für Sprachkennung

In earlier times it had to deliver a syntactically incorrect XML response in the following questionable form:

  <?xml version=\"1.0\"?>
  <td><pre><p><b>isbd</b></p></pre></td>
  <status>n</status>
  <ruckdat>yyyymmdd</ruckdat>

with isbd: ISBD information on the found title record
and these entries for 'n' in status element:
    <status>0</status>                                      # Titel nicht vorhanden / searched catalogue title not found or item does not exist
    <status>1</status>                                      # nicht entliehen / item available, i.e. item is loanable and not loaned
    <status>2</status>                                      # ausgeliehen / item is loaned to a borrower
    <status>3</status>                                      # im Buchhandel bestellt / ordered at a supplier (not used here)
    <status>4</status>                                      # nicht ausleihbar / item not for loan
and ruckdat element in the form
  if status==2 and due date is defined:
    <ruckdat>yyyymmdd</ruckdat>                             # Datum voraussichtliche Rückgabe / due date (only if status==2 and due date is defined)
  otherwise:
    <ruckdat></ruckdat> 


The CGI script of BZSH embeds this fragment in a HTML response.
In order to make it more readable and usefull for the user,
we added a cleartext output of the status and due date information
as well as a permalink to the local title and item information.                                                   

example request:
http://wallenheim.lmscloud.net/opac-item-availability-BZSH.pl?sigel=634&TITEL=4072861&SRISBN=9783763026838&SRTIT=Mona%20Lisa%20forever&SRAUT=Thomas&SRKORP=&LANG=de

example response:
<?xml version="1.0"?>
<td><pre><p><b>Die Sixtinische Kapelle / Ulrich Pfisterer. - Orig.-Ausg. - München: Beck, 2013.
127 S. 18 cm. - (Beck'sche Reihe ; 2562) 
ISBN 978-3-406-63819-0 : kt. : EUR 8.95

Status: ausgeliehen
Datum voraussichtliche Rückgabe: 04.07.2017
<p><a href="https://wallenheim.lmscloud.net/bib/6391">Weitere Informationen zu diesem Titel</a></p>
</b></p></pre></td>
<status>2</status><br>
<ruckdat>20170704</ruckdat><br>

addition february 2019:
introduction of system preference BZSHAvailabilityBranches to limit the search to selected branchcodes.
Format: list of elements, separated by '|', of the form BZSH-Sigel_x:branchcode_1,...,branchcode_n
example: 802:HST,ZW1|803:ZW2|809:ZW2,ZW4,HST
The selection for branchcodes will only be activated if
 - the system preference BZSHAvailabilityBranches is set
 - BZSHAvailabilityBranches contains an entry for this BZSH-Sigel
 - the entry for this BZSH-Sigel in BZSHAvailabilityBranches contains at least 1 branchcode

addition july 2019:
The response has been streamlined to the following form:
<?xml version="1.0" encoding="UTF-8"?>
<response>
  <info>
    <pre>
      <p>
        <b>Mittsommersehnsucht: Roman / Elfie Ligensa. - Orig.-Ausg. - Berlin: Ullstein, 2012.
411 S. 19 cm. - (Ullstein ; 28436) 
ISBN 978-3-548-28436-1 : kt. : EUR 8.99
          Status: ausgeliehen
          Datum voraussichtliche R\xfcckgabe: 20.02.2019
          <p><a href="http://192.168.122.101/bib/1817">Weitere Informationen zu diesem Titel</a></p>
        </b>
      </p>
    </pre>
  </info>
  <status>2</status>
  <ruckdat>20190220</ruckdat>
</response>



=cut

use strict;
use warnings;
use CGI qw ( -utf8 );
use CGI::Carp;
use utf8;

use C4::External::BZSH::ItemAvailabilitySearch_BZSH;


my $cgi = new CGI;

my $sel_sigel = $cgi->param("sigel");       # this seems not to be the official ISIL but a so called BZSH-Sigel (library identifier within Schleswig-Holstein)
my $sel_titel = $cgi->param("TITEL");
my $sel_srisbn = $cgi->param("SRISBN");
my $sel_srtit = $cgi->param("SRTIT");       # not used here
my $sel_sraut = $cgi->param("SRAUT");       # not used here
my $sel_srkorp = $cgi->param("SRKORP");     # not used here
my $sel_lang = $cgi->param("LANG");         # optional, not used here

my $best_item_status = 0;                   # default: status 0 / Titel nicht vorhanden / title does not exist
my $best_biblionumber = 0;
my $best_itemnumber = 0;
my $marcrecord;

# Generate the CGI response (text/xml in this case) without using template toolkit.
sub output_BZSH_xml {
    my ( $query, $data ) = @_;

    my $options = {
        type              => 'text/xml',
        status            => '200 OK',
        charset           => 'UTF-8',
        Pragma            => 'no-cache',
        'Cache-Control'   => 'no-cache, no-store, max-age=0',
        'X-Frame-Options' => 'SAMEORIGIN',
    };
    $options->{expires} = 'now';

    $data =~ s/\&amp\;amp\; /\&amp\; /g;
    binmode(STDOUT, ":utf8");
    print $query->header($options), $data;
}

# Generate an URL for the biblio record in Koha for display in the item availability response.
sub genPermalink {
    my ($biblionumber) = @_;
	
    my $permalink = '';
	my $baseurl = C4::Context->preference('OPACBaseURL');
    
    if ( length($baseurl) > 0 && length($biblionumber) > 0 ) {
        $permalink = $baseurl . "/bib/" . $biblionumber;
    }
    return $permalink;
}

# Try the search for MARC21 category 001 ('Kontrollnummer').
# If no hit was found:
# Try the search for MARC21 category 020 (ISBN) or MARC21 category 024 (Other Standard Identifier, e.g. EAN) if possible.
my $itemAvailabilitySearch_BZSH = C4::External::BZSH::ItemAvailabilitySearch_BZSH->new($sel_sigel);
($best_item_status, $best_itemnumber, $best_biblionumber, $marcrecord ) = $itemAvailabilitySearch_BZSH->search_title_with_best_item_status($sel_titel, $sel_srisbn);


# build the components of the response
my $BZSH_output_bibldata = '';
my $BZSH_output_statustext = "Status: Titel nicht vorhanden";
my $BZSH_output_ruckdattext = "";
my $BZSH_output_permalink = "";
my $BZSH_output_statuscode = "0";
my $BZSH_output_ruckdatcode = "";

if ( $best_biblionumber > 0 ) {
    if ( $marcrecord ) {
        my $marc_titledata = '';
        $marc_titledata = $itemAvailabilitySearch_BZSH->genISBD($marcrecord);    # generate the ISBN output for this title
        if (length($marc_titledata) > 0) {
            $BZSH_output_bibldata = "$marc_titledata";
        }
    }
    $BZSH_output_permalink = sprintf("%s", &genPermalink($best_biblionumber));
}

if ( $best_item_status == 1) {
    $BZSH_output_statustext = "Status: nicht entliehen";
    $BZSH_output_statuscode = "1";
} elsif ( $best_item_status == 2) {
    $BZSH_output_statustext = "Status: ausgeliehen";
    $BZSH_output_statuscode = "2";
    my $best_item_date_due_year = '';
    my $best_item_date_due_month = '';
    my $best_item_date_due_day = '';
    my $best_item_date_due = $itemAvailabilitySearch_BZSH->get_date_due_of_item($best_biblionumber, $best_itemnumber);
    if ( length($best_item_date_due) >= 10 ) {
        $best_item_date_due_year = substr($best_item_date_due,0,4);
        $best_item_date_due_month = substr($best_item_date_due,5,2);
        $best_item_date_due_day = substr($best_item_date_due,8,2);
        if ( length($best_item_date_due_year) == 4 &&  length($best_item_date_due_month) == 2 && length($best_item_date_due_day) == 2 ) {
            $BZSH_output_ruckdattext = sprintf("Datum voraussichtliche Rückgabe: %02d.%02d.%04d", $best_item_date_due_day, $best_item_date_due_month, $best_item_date_due_year);
            $BZSH_output_ruckdatcode = sprintf("%04d%02d%02d", $best_item_date_due_year, $best_item_date_due_month, $best_item_date_due_day);
        }
    }
} elsif ( $best_item_status == 4) {
    $BZSH_output_statustext = "Status: nicht ausleihbar";
    $BZSH_output_statuscode = "4";
}
    
# finally build the response from its components
my $BZSH_output = sprintf(
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<response>
  <info>
    <pre>
      <p>
        <b>%s          %s%s
          <p><a href=\"%s\">Weitere Informationen zu diesem Titel</a></p>
        </b>
      </p>
    </pre>
  </info>
  <status>%s</status>
  <ruckdat>%s</ruckdat>
</response>
",
    $BZSH_output_bibldata, $BZSH_output_statustext, $BZSH_output_ruckdattext?"\n          " . $BZSH_output_ruckdattext:'',
    $BZSH_output_permalink,
    $BZSH_output_statuscode,
    $BZSH_output_ruckdatcode
);

# send the response
&output_BZSH_xml( $cgi, $BZSH_output );

1;
