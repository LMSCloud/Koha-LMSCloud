package C4::External::BZSH::ItemAvailabilitySearch_BZSH;

# Copyright 2019 (C) LMSCLoud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
use CGI::Carp;
use Data::Dumper;
use Business::ISBN;


use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );    # required for MARC::File::XML->decode(...)
use C4::Auth;
use C4::Context;
use C4::Search qw(SimpleSearch);
use Koha::Items;
use Koha::DateUtils;


sub new {
    my $class = shift;
    my $sel_sigel = shift;

#    my $self  = {};
    my $self = {
        'selbranchcodecheck' => 0,
        'selbranchcodehash' => {},
        'querybranchcodes' => '',
    };
    my @selbranchcodes = ();
    my $bzshAvailabilityBranches = C4::Context->preference('BZSHAvailabilityBranches');
    if ( $bzshAvailabilityBranches ) {
        my @bzshAvailabilityLibs = split('\|',$bzshAvailabilityBranches);
        foreach my $lib ( @bzshAvailabilityLibs ) {
            my @bzshsigelbranchcodes = split(':',$lib);
            if ( $bzshsigelbranchcodes[0] && defined $sel_sigel && $bzshsigelbranchcodes[0] eq $sel_sigel ) {
                if ( $bzshsigelbranchcodes[1] ) {
                    @selbranchcodes = split(',',$bzshsigelbranchcodes[1]);
                    foreach my $branchcode (@selbranchcodes) {
                        $self->{selbranchcodecheck} = 1;
                        $self->{selbranchcodehash}->{$branchcode} = $branchcode;
                    }
                }
                last;
            }
        }
    }
    if ( $self->{selbranchcodecheck} ) {
        for (my $i = 0; $selbranchcodes[$i]; $i += 1 ) {
            if ( $i == 0 ) {
                $self->{querybranchcodes} .= " and (branch:$selbranchcodes[$i]";
            } else {
                $self->{querybranchcodes} .= " or branch:$selbranchcodes[$i]";
            }
        }
        if ( length($self->{querybranchcodes}) > 0 ) {
            $self->{querybranchcodes} .= ")";
        }
    }
    
    bless $self, $class;
    
    return $self;
}


# title search by BZID or ISBN/ISSN/EAN and item with best availability status
#
# Try the search only if param TITEL ('Kontrollnummer') is sent.
# Try the search for MARC21 category 001 ('Kontrollnummer').
# If no hit was found:
# Try the search for MARC21 category 020 (ISBN) or MARC21 category 024 (Other Standard Identifier, e.g. EAN) if possible.
sub search_title_with_best_item_status {
    my $self = shift;
    my $sel_titel = shift;
    my $sel_srisbn = shift;

    my ( $error, $marcresults, $total_hits ) = ( undef, [], 0 );
    my $query = "cn:\"-1\"";                    # control number search, initial definition for no hit
    my $best_biblionumber = 0;
    my $best_item_status = 0;                   # default: status 0 / Titel nicht vorhanden / title does not exist
    my $best_itemnumber = 0;
    my $marcrecord;

    if (defined $sel_titel) {
        # search for catalog title record by MARC21 category 001 (control number)
        $query = "zkshid:\"$sel_titel\"" . $self->{querybranchcodes};
        ( $error, $marcresults, $total_hits ) = ( '', [], 0 );
        ( $error, $marcresults, $total_hits ) = SimpleSearch($query);

        if (defined $error) {
            my $log_str = sprintf("ItemAvailabilitySearch_BZSH: search for sel_titel:%s: returned error:%d/%s:\n", $sel_titel,$error,$error);
            carp $log_str;
        }
    }
    if ($total_hits == 0) {
        if (!defined $sel_srisbn || length($sel_srisbn) == 0 ) {
            my $log_str = sprintf("ItemAvailabilitySearch_BZSH: Title not found by sel_titel:%s: and sel_srisbn is empty - no 2nd search done. Returning status 0.\n", $sel_titel);
            carp $log_str;
        } else {
            # search for catalog title record by MARC21 category 020/024 (ISBN/EAN)
            # (search in length 10 and 13, with and without hyphens)
            my @selISBN = ();
            eval {
                my $businessIsbn = Business::ISBN->new($sel_srisbn);
                if ( defined($businessIsbn) && ! $businessIsbn->error ) {
                    $selISBN[0] = $businessIsbn->as_string([]);
                    $selISBN[1] = $businessIsbn->as_string();
                    $selISBN[2] = $businessIsbn->as_isbn10->as_string([]);
                    $selISBN[3] = $businessIsbn->as_isbn10->as_string();
                }
            };
            if ( ! defined($selISBN[0]) || length($selISBN[0]) == 0 ) {
                my $log_str = sprintf("ItemAvailabilitySearch_BZSH: ISBN/EAN not valid -> not searching for ISBN/EAN %s.\n", $sel_srisbn);
                carp $log_str;
            } else {
                for ( my $i = 0; $i < 4; $i += 1 ) {
                    if ( defined($selISBN[$i]) && length($selISBN[$i]) > 0 ) {
                        # build search query for ISBN/EAN search
                        # search for catalog title record by MARC21 category 020/024 (ISBN/EAN)
                        $query = '(nb:"' . $selISBN[$i] . '" or id-other:"' . $selISBN[$i] . '")' . $self->{querybranchcodes};
                        ( $error, $marcresults, $total_hits ) = ( '', [], 0 );
                        ( $error, $marcresults, $total_hits ) = SimpleSearch($query);
            
                        if (defined $error) {
                            my $log_str = sprintf("ItemAvailabilitySearch_BZSH: search for ISBN/EAN:%s: returned error:%d/%s:\n", $selISBN[$i],$error,$error);
                            carp $log_str;
                        } else {
                            if ( $total_hits > 0 ) {
                                last;
                            }
                        }
                    }
                }
            }
        }
    }

    my $hits = 0;
    if ( (defined $marcresults) && @$marcresults ) {
        $hits = scalar @$marcresults;
    }
    # Search "the best" item state for the catalogue titles found:
    # status 1 (item available) is the best possible one
    # status 2 (item on loan) is the second best.
    for (my $i = 0; $i < $hits and defined $marcresults->[$i] and $best_item_status != 1; $i++)
    {
        
        eval {
            $marcrecord =  MARC::Record::new_from_xml( $marcresults->[$i], "utf8", 'MARC21' );
        };
        carp "ItemAvailabilitySearch_BZSH: error in MARC::Record::new_from_xml:$@:\n" if $@;

        if ( $marcrecord )
        {
            my $biblionumber = $marcrecord->subfield("999","c");                        # get biblio number of the title hit

            $self->search_item_with_best_item_status($biblionumber, \$best_item_status, \$best_itemnumber, \$best_biblionumber );
        }
    }
    return ($best_item_status, $best_itemnumber, $best_biblionumber, $marcrecord);
}

sub search_item_with_best_item_status {
my ( $self, $biblionumber, $ref_best_item_status, $ref_best_itemnumber, $ref_best_biblionumber ) = @_;

    # item status code in BZSH:
    # 0    # Titel nicht vorhanden / item does not exist
    # 1    # nicht entliehen / item is loanable and not loaned
    # 2    # ausgeliehen / item is loaned to a borrower
    # 3    # im Buchhandel bestellt / ordered at a supplier (not used here)
    # 4    # nicht ausleihbar / item not for loan

    for my $item ( Koha::Items->search({ biblionumber => $biblionumber }) )    # read items of this biblio number
    {
        my $itemrecord = $item->unblessed;
        if ( $self->{selbranchcodecheck} && !defined($self->{selbranchcodehash}->{$itemrecord->{'homebranch'}}) ) {
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
            if ($$ref_best_itemnumber == 0) 
            {
                $$ref_best_item_status = 4;  # item exists but is not for loan
                $$ref_best_itemnumber = $itemnumber;
                $$ref_best_biblionumber = $biblionumber;
            }
            next;
        }
        my $item_onloan = $itemrecord->{'onloan'};
        if ($item_onloan && length($item_onloan) > 0 && $$ref_best_item_status != 1)
        {
            $$ref_best_item_status = 2;     # this is the second best status of all: item on loan
            $$ref_best_itemnumber = $itemnumber;
            $$ref_best_biblionumber = $biblionumber;
            next;                           # continue; maybe an item with better status exists
        }
        $$ref_best_item_status = 1;         # this is the best status of all: item available
        $$ref_best_itemnumber = $itemnumber;
        $$ref_best_biblionumber = $biblionumber;
        last;                               # break; no better status possible
    }
}

# Generate a simple ISBD output for a biblio record by a few of its MARC fields.
# Inspired by: https://www.ifla.org/files/assets/cataloguing/isbd/isbd-examples_2013.pdf
sub genISBD {
    my $self = shift;
    my $koharecord = shift;
    
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
    
        if ( $dimensions && length($dimensions) > 0 ) {
            $pagescnt .= ' ' . $dimensions;
        }
        push @physicaldescription, $pagescnt if $pagescnt;
    }
    
    # get series statement info (ISBD Area 6)
    my @seriesstatement = ();
    foreach $field ($koharecord->field('490')) {
        my $seriesstmnt = $field->subfield('a');
        my $volumedesig = $field->subfield('v');
    
        if ( $volumedesig && length($volumedesig) > 0 ) {
            $seriesstmnt =~ s/\s*;\s*$//;
            $seriesstmnt =~ s/\s*$//;
            $seriesstmnt .= ' ; ' . $volumedesig;
        }
        push @seriesstatement, $seriesstmnt if $seriesstmnt;
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
        if ( $isbnprice && length($isbnprice) > 0 ) {
            $isbn .= " : " . $isbnprice;
        }
        push @isbns, $isbn if $isbn;
    }
    my @eans = ();
    foreach $field ($koharecord->field('024')) {
        my $ean = $field->subfield('a');
        my $eanprice = $field->subfield('c');
        if ( $eanprice && length($eanprice) > 0 ) {
            $ean .= " : " . $eanprice;
        }
        push @eans, $ean if $ean;
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

# Read the item of the biblio record to get its due date.
sub get_date_due_of_item
{
    my $self = shift;
    my $biblionumber = shift;
    my $itemnumber = shift;

    my $date_due = '';

    my $item = Koha::Items->find( { itemnumber => $itemnumber } );
    if ( $item->biblionumber == $biblionumber ) {    # should always be true
        $date_due = $item->onloan();
    }
    
    return $date_due;
}

1;
