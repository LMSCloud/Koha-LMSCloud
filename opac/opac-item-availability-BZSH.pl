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

that has to deliver a syntactically incorrect XML response in the following questionable form:

  <?xml version=\"1.0\"?>
  <td><pre><p><b>isbd</b></p></pre></td>
  <status>n </status>
  <ruckdat>yyyymmdd</ruckdat>

with isbd: ISBD information on the found title record
and these entries for 'n ' in status element:
    <status>0 </status>                                     # Titel nicht vorhanden / searched catalogue title not found or item does not exist
    <status>1 </status>                                     # nicht entliehen / item available, i.e. item is loanable and not loaned
    <status>2 </status>                                     # ausgeliehen / item is loaned to a borrower
    <status>3 </status>                                     # im Buchhandel bestellt / ordered at a supplier (not used here)
    <status>4 </status>                                     # nicht ausleihbar / item not for loan
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
<status>2 </status><br>
<ruckdat>20170704</ruckdat><br>

addition february 2019:
introduction of system preference BZSHAvailabilityBranches to limit the search to selected branchcodes.
Format: list of elements, separated by '|', of the form BZSHID_x:branchcode_1,...,branchcode_n
example: 802:HST,ZW1|803:ZW2|809:ZW2,ZW4,HST
The selection for branchcodes will only be activated if
 - the system preference BZSHAvailabilityBranches is set
 - BZSHAvailabilityBranches contains an entry for this BZSHID (i.e. sigel)
 - the entry for this BZSHID (i.e. sigel) in BZSHAvailabilityBranches contains at least 1 branchcode


=cut

use strict;
use warnings;
use CGI::Carp;
use utf8;

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );    # required for MARC::File::XML->decode(...)
use C4::Auth;
use C4::Context;
use CGI qw ( -utf8 );
use C4::Search qw(SimpleSearch);
use Koha::Items;

my $cgi = new CGI;

my $sel_sigel = $cgi->param("sigel");       # this seems not to be the official ISIL but a so called BZSHID (library identifier within Schleswig-Holstein)
my $sel_titel = $cgi->param("TITEL");
my $sel_srisbn = $cgi->param("SRISBN");
my $sel_srtit = $cgi->param("SRTIT");       # not used here
my $sel_sraut = $cgi->param("SRAUT");       # not used here
my $sel_srkorp = $cgi->param("SRKORP");     # not used here
my $sel_lang = $cgi->param("LANG");         # optional, not used here

my $query = "cn:\"-1\"";                    # control number search, definition for no hit
my @itemnumbers = ();
my $best_item_status = 0;                   # default: status 0 / Titel nicht vorhanden / title does not exist
my $best_biblionumber = 0;
my $best_itemnumber = 0;
my $best_item_date_due = '';
my $best_item_date_due_year = '';
my $best_item_date_due_month = '';
my $best_item_date_due_day = '';
my ( $error, $marcresults, $total_hits, $hits ) = ( undef, (), 0, 0 );
my $marc_titledata = '';

my $selbranchcodecheck = 0;
my $bzshAvailabilityBranches = C4::Context->preference('BZSHAvailabilityBranches');
my @selbranchcodes = ();
my %selbranchcodehash = ();
if ( $bzshAvailabilityBranches ) {
    my @bzshAvailabilityLibs = split('\|',$bzshAvailabilityBranches);
    foreach my $lib ( @bzshAvailabilityLibs ) {
        my @bzshid = split(':',$lib);
        if ( $bzshid[0] && $bzshid[0] eq $sel_sigel) {
            if ( $bzshid[1] ) {
                @selbranchcodes = split(',',$bzshid[1]);
                foreach my $branchcode (@selbranchcodes) {
                    $selbranchcodecheck = 1;
                    $selbranchcodehash{$branchcode} = $branchcode;
                }
            }
            last;
        }
    }
}

# Try the search only if param TITEL ('Kontrollnummer') is sent.
# Try the search for MARC21 category 001 ('Kontrollnummer').
# If no hit was found:
# Try the search for MARC21 category 020 (ISBN) or MARC21 category 024 (Other Standard Identifier, e.g. EAN) if possible.


# Read the items of the biblio record for comparision with $itemnumber to find out its due date.
sub get_date_due_for_item
{
    my ( $biblionumber, $itemnumber ) = @_;
    my $date_due = '';

    for my $item ( Koha::Items->search({ biblionumber => $biblionumber }) ) {
        if ( $item->itemnumber == $itemnumber ) {
            $date_due = $item->{date_due};
            last;
        }
    }
    
    return $date_due;
}

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

# Generate a simple ISBD output for a biblio record by a few of its MARC fields.
# Inspired by: https://www.ifla.org/files/assets/cataloguing/isbd/isbd-examples_2013.pdf
sub genISBD {
    my ($koharecord) = @_;
		
	# get title / author info (ISBD Area 1)
    my $field = $koharecord->field('245');
	my $titleblock;
	if ( $field ) {
		my $title = $field->subfield('a');
		my $subtitle = $field->subfield('b');
		my $author = $field->subfield('c');
	
		$titleblock = $title;
		if ( $subtitle ) {
			$titleblock .= ': ' . $subtitle;
		}
		if ( $author ) {
			$titleblock .= ' / ' . $author;
		}
		if ( $titleblock && $titleblock !~ /\.$/ ) {
			$titleblock .= '.';
		}
	}
	# get edition statement info (ISBD Area 2)
	$field = $koharecord->field('250');
	if ( $field ) {
		my $edition = $field->subfield('a');
	
		if ( $edition ) {
			$titleblock .= ' - ' . $edition;
			if ( $titleblock !~ /\.$/ ) {
				$titleblock .= '.';
			} 
		}
	}
	# get publication info (ISBD Area 4)
	$field = $koharecord->field('260');
    if (! defined($field) ) {
        $field = $koharecord->field('264');
    }
	if ( $field ) {
		my $location = $field->subfield('a');
		my $publisher = $field->subfield('b');
		my $year = $field->subfield('c');
	
		my $publisherblock = $location;
		if ( $publisherblock && ( defined($publisher) || defined($year) )) {
			$publisherblock .= ': ';
		}
		if ( $publisher ) {
			$publisherblock .=  $publisher;
		}
		if ( $year ) {
			if ( $publisherblock ) {
				$publisherblock .= ', ';
			}
			$publisherblock .=  $year;
		}
		if ( $publisherblock ) {
			$titleblock .= ' - ' . $publisherblock;
			if ( $titleblock !~ /\.$/ ) {
				$titleblock .= '.';
			}
		}
	}
    
    # get physical description info (ISBD Area 5)
    my @physicaldescription = ();
	foreach $field ($koharecord->field('300')) {
		my $pagescnt = $field->subfield('a');
		my $dimensions = $field->subfield('c');
	
		if ( length($dimensions) > 0 ) {
			$pagescnt .= ' ' . $dimensions;
		}
		push @physicaldescription, $pagescnt;
	}
    
    # get series statement info (ISBD Area 6)
    my @seriesstatement = ();
	foreach $field ($koharecord->field('490')) {
		my $seriesstmnt = $field->subfield('a');
		my $volumedesig = $field->subfield('v');
	
		if ( length($volumedesig) > 0 ) {
            $seriesstmnt =~ s/\s*;\s*$//;
            $seriesstmnt =~ s/\s*$//;
			$seriesstmnt .= ' ; ' . $volumedesig;
		}
		push @seriesstatement, $seriesstmnt;
	}
	
	# get ISBN / EAN info (ISBD Area 8)
    my @isbns = ();
	foreach $field ($koharecord->field('020')) {
		my $isbn = $field->subfield('a');
		eval {
			my $val = Business::ISBN->new($isbn);
			$isbn = $val->as_isbn13()->as_string("-");
		};
		my $isbnprice = $field->subfield('c');
        if ( length($isbnprice) > 0 ) {
            $isbn .= " : " . $isbnprice;
        }
		push @isbns, $isbn;
	}
    my @eans = ();
	foreach $field ($koharecord->field('024')) {
		my $ean = $field->subfield('a');
		my $eanprice = $field->subfield('c');
        if ( length($eanprice) > 0 ) {
            $ean .= " : " . $eanprice;
        }
		push @eans, $ean;
	}
    
    
    
    # ISBD Area 1, 2, 4: title / author / edition / publication info
    my $isbd = $titleblock;

    if ( @physicaldescription > 0 || @seriesstatement > 0) {
        $isbd .= "\n";
    }

    # ISBD Area 5: physical description
    for ( my $i = 0; $i < @physicaldescription; $i++) {
        $isbd .= " ; " if ( $i > 0 );
        $isbd .= $physicaldescription[$i];
    } 
    
    # ISBD Area 6: series statement
    if ( @seriesstatement > 0 ) {
         $isbd .= ". - " if ( @physicaldescription > 0);    # separator between series statement and physical description
    }
    for ( my $i = 0; $i < @seriesstatement; $i++) {
        $isbd .= "(" . $seriesstatement[$i] . ") ";
    }

    # ISBD Area 7: not used here, but it forces a new line nevertheless
    $isbd .= "\n";
    
    # ISBD Area 8: ISBN / EAN
    for ( my $i=0; $i < @isbns; $i++) {
        $isbd .= ". - " if ( $i > 0 );
        $isbd .= "ISBN " . $isbns[$i];
    }
    for ( my $i=0; $i < @eans; $i++) {
        $isbd .= ". - " if ( $i > 0 || @isbns > 0 );        # separator EAN/EAN and ISBN/EAN, if any
        $isbd .= "EAN " . $eans[$i];
    }

    $isbd .= "\n";
    $isbd =~ s/[\x{0098}\x{009c}]//g;                       # removing non-sort characters
    
    return $isbd;
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


my $querybranchcodes = '';
if ( $selbranchcodecheck ) {
    for (my $i = 0; $selbranchcodes[$i]; $i += 1 ) {
        if ( $i == 0 ) {
            $querybranchcodes .= " and (branch:$selbranchcodes[$i]";
        } else {
            $querybranchcodes .= " or branch:$selbranchcodes[$i]";
        }
    }
    if ( length($querybranchcodes) > 0 ) {
        $querybranchcodes .= ")";
    }
}

# start the title search
if (defined $sel_titel)
{
    # search for catalog title record by MARC21 category 001 (control number)
    $query = "zkshid:\"$sel_titel\"" . $querybranchcodes;
    ( $error, $marcresults, $total_hits ) = ( '', (), 0 );
    ( $error, $marcresults, $total_hits ) = SimpleSearch($query);

    if (defined $error) {
        my $log_str = sprintf("main: search for sel_titel:%s: returned error:%d/%s:\n", $sel_titel,$error,$error);
        carp $log_str;
    }
}
if ($total_hits == 0)
{
    if (!defined $sel_srisbn)
    {
      my $log_str = sprintf("opac-item-availability-BZSH: Title not found by sel_titel:%s: and sel_srisbn is empty - no 2nd search done. Returning status 0.\n", $sel_titel);
      carp $log_str;
    } else
    {
        # search for catalog title record by MARC21 category 020/024 (ISBN/EAN)
        $query = "(nb:\"$sel_srisbn\" or id-other:\"$sel_srisbn\")" . $querybranchcodes;
        ( $error, $marcresults, $total_hits ) = ( '', (), 0 );
        ( $error, $marcresults, $total_hits ) = SimpleSearch($query);
        
        if (defined $error) {
            my $log_str = sprintf("main: search for sel_srisbn:%s: returned error:%d/%s:\n", $sel_srisbn,$error,$error);
            carp $log_str;
        }
    }
}
$hits = scalar @$marcresults;

# Search "the best" item state for the catalogue titles found. Status 1 (item available) is the best possible one, status 2 (item on loan) the second best.
for (my $i = 0; $i < $hits and defined $marcresults->[$i] and $best_item_status != 1; $i++)
{
    # item status code in BZSH:
    # 0    # Titel nicht vorhanden / item does not exist
    # 1    # nicht entliehen / item is loanable and not loaned
    # 2    # ausgeliehen / item is loaned to a borrower
    # 3    # im Buchhandel bestellt / ordered at a supplier (not used here)
    # 4    # nicht ausleihbar / item not for loan
    
    my $marcrecord;
    eval {
        $marcrecord =  MARC::Record::new_from_xml( $marcresults->[$i], "utf8", 'MARC21' );
    };
    carp "main: error in MARC::Record::new_from_xml:$@:\n" if $@;

    if ( $marcrecord )
    {
        my $biblionumber = $marcrecord->subfield("999","c");                        # get biblio number of the title hit
        $marc_titledata = &genISBD($marcrecord);                                    # generate the ISBN output for this title

        for my $item ( Koha::Items->search({ biblionumber => $biblionumber }) )    # read items of this biblio number
        {
            my $itemrecord = $item->unblessed;
            if ( $selbranchcodecheck && !defined($selbranchcodehash{$itemrecord->{'homebranch'}}) ) {
                next;    # not in the set of relevant items
            }

            # check if this item has a "better" status
            my $itemnumber = $itemrecord->{'itemnumber'};
            
            if ($itemrecord->{'notforloan'} ||
                $itemrecord->{'damaged'} ||
                $itemrecord->{'itemlost'} ||
                $itemrecord->{'withdrawn'} ||
                $itemrecord->{'restricted'})
            {
                if ($best_itemnumber == 0) 
                {
                    $best_item_status = 4;  # item exists but is not for loan
                    $best_itemnumber = $itemnumber;
                    $best_biblionumber = $biblionumber;
                }
                next;
            }
            my $item_onloan = $itemrecord->{'onloan'};
            if ($item_onloan && length($item_onloan) > 0 && $best_item_status != 1)
            {
                $best_item_status = 2;      # this is the second best status of all: item on loan
                $best_itemnumber = $itemnumber;
                $best_biblionumber = $biblionumber;
                next;                       # continue; maybe an item with better status exists
            }
            $best_item_status = 1;          # this is the best status of all: item available
            $best_itemnumber = $itemnumber;
            $best_biblionumber = $biblionumber;
            last;                           # break; no better status possible
        }
    }
}

if ($best_item_status == 2)    # For performance reasons, we search for date due only if we really have to. 
{
    $best_item_date_due = &get_date_due_for_item( $best_biblionumber, $best_itemnumber );
    if ( length($best_item_date_due) >= 10 ) {
        $best_item_date_due_year = substr($best_item_date_due,0,4);
        $best_item_date_due_month = substr($best_item_date_due,5,2);
        $best_item_date_due_day = substr($best_item_date_due,8,2);
    }
}


# build the components of the response
my $BZSH_output_header = "<?xml version=\"1.0\"?>\n";
my $BZSH_output_bibldata = '';
my $BZSH_output_statustext = "Status: Titel nicht vorhanden\n";
my $BZSH_output_ruckdattext = "";
my $BZSH_output_permalink = "";
my $BZSH_output_statuscode = "\n<status>0 </status><br>\n";
my $BZSH_output_ruckdatcode = "<ruckdat></ruckdat><br>\n";

if (length($marc_titledata) > 0) {
    $BZSH_output_bibldata = "$marc_titledata\n";
}
if ( $best_item_status == 1) {
    $BZSH_output_statustext = "Status: nicht entliehen\n";
    $BZSH_output_statuscode = "\n<status>1 </status><br>\n";
} elsif ( $best_item_status == 2) {
    $BZSH_output_statustext = "Status: ausgeliehen\n";
    $BZSH_output_statuscode = "\n<status>2 </status><br>\n";
    if ( length($best_item_date_due_year) == 4 &&  length($best_item_date_due_month) == 2 && length($best_item_date_due_day) == 2 ) {
        $BZSH_output_ruckdattext = sprintf("Datum voraussichtliche Rückgabe: %02d.%02d.%04d\n", $best_item_date_due_day, $best_item_date_due_month, $best_item_date_due_year);
        $BZSH_output_ruckdatcode = sprintf("<ruckdat>%04d%02d%02d</ruckdat><br>\n", $best_item_date_due_year, $best_item_date_due_month, $best_item_date_due_day);
    }
} elsif ( $best_item_status == 4) {
    $BZSH_output_statustext = "Status: nicht ausleihbar\n";
    $BZSH_output_statuscode = "\n<status>4 </status><br>\n";
}
if ( $best_biblionumber > 0 ) {
    $BZSH_output_permalink = sprintf("<p><a href=\"%s\">Weitere Informationen zu diesem Titel</a></p>\n", &genPermalink($best_biblionumber));
}
    
# finally build the response from its components
my $BZSH_output = sprintf("%s<td><pre><p><b>%s%s%s%s</b></p></pre></td>%s%s", $BZSH_output_header, $BZSH_output_bibldata, $BZSH_output_statustext, $BZSH_output_ruckdattext, $BZSH_output_permalink, $BZSH_output_statuscode, $BZSH_output_ruckdatcode);

# send the response
&output_BZSH_xml( $cgi, $BZSH_output );

1;
