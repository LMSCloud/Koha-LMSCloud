package C4::CoverFlowData;

# Copyright 2010 Catalyst IT
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
use Carp;
use URI::Escape;

use C4::Biblio qw( GetAuthorisedValueDesc TransformMarcToKoha );
use C4::Context;
use C4::Koha qw( GetNormalizedUPC GetNormalizedOCLCNumber GetNormalizedISBN GetNormalizedEAN );
use C4::Search;
use Koha::Biblios;
use Koha::Libraries;
use Koha::SearchEngine;
use Koha::SearchEngine::Search;

our (@ISA, @EXPORT_OK);
BEGIN {
    require Exporter;
    @ISA       = qw(Exporter);
    @EXPORT_OK = qw(
      GetCoverFlowDataOfNearbyItemsByItemNumber
      GetCoverFlowDataByBiblionumber
      GetCoverFlowDataByQueryString
    );
}

=head1 NAME

C4::CoverFlowData - functions that deal with the shelf browser feature found in
the OPAC.

=head1 SYNOPSIS

  use C4::CoverFlowData;

=head1 DESCRIPTION

This module provides functions to get data of items nearby to another item, 
for use in the shelf browser function.

'Nearby' is controlled by a handful of system preferences that specify what
to take into account.

=head1 FUNCTIONS

=head2 GetCoverFlowDataOfNearbyItemsByItemNumber($itemnumber, [$num_each_side])

  $nearby = GetCoverFlowDataOfNearbyItemsByItemNumber($itemnumber, [$num_each_side]);

  @items = @{ $nearby->{items} };

  foreach (@items) {
      # These won't format well like this, but here are the fields
  	  print $_->{title};
  	  print $_->{biblionumber};
  	  print $_->{itemnumber};
  	  print $_->{browser_normalized_upc};
  	  print $_->{browser_normalized_oclc};
  	  print $_->{browser_normalized_isbn};
      print $_->{browser_normalized_ean};
  }

  # This is the information required to scroll the browser to the next left
  # or right set. Can be derived from next/prev, but it's here for convenience.
  print $nearby->{prev_item}{itemnumber};
  print $nearby->{next_item}{itemnumber};
  print $nearby->{prev_item}{biblionumber};
  print $nearby->{next_item}{biblionumber};

  # These will be undef if the values are not used to calculate the 
  # nearby items.
  print $nearby->{starting_homebranch}->{code};
  print $nearby->{starting_homebranch}->{description};
  print $nearby->{starting_location}->{code};
  print $nearby->{starting_location}->{description};
  print $nearby->{starting_ccode}->{code};
  print $nearby->{starting_ccode}->{description};

This finds the items that are nearby to the supplied item, and supplies
those previous and next, along with the other useful information for displaying
the shelf browser.

It automatically applies the following user preferences to work out how to
calculate things: C<ShelfBrowserUsesLocation>, C<ShelfBrowserUsesHomeBranch>, 
C<ShelfBrowserUsesCcode>.

The option C<$num_each_side> value determines how many items will be fetched
each side of the supplied item. Note that the item itself is the first entry
in the 'next' set, and counts towards this limit (this is to keep the
behaviour consistent with the code that this is a refactor of.) Default is
3.

This will throw an exception if something went wrong.

=cut

sub GetCoverFlowDataOfNearbyItemsByItemNumber {
    my ( $itemnumber, $num_each_side, $gap) = @_;
    $num_each_side ||= 3;
    $gap ||= (2 * $num_each_side)+1; # Should be > $num_each_side
    croak 'BAD CALL in C4::ShelfBrowser::GetNearbyItems, gap should be > num_each_side'
        if $gap <= $num_each_side;

    my $dbh         = C4::Context->dbh;

    my $sth_get_item_details = $dbh->prepare('SELECT cn_sort,homebranch,location,ccode FROM items WHERE itemnumber=?');
    $sth_get_item_details->execute($itemnumber);
    my $item_details_result = $sth_get_item_details->fetchrow_hashref();
    croak "Unable to find item '$itemnumber' for shelf browser" if (!$sth_get_item_details);
    my $start_cn_sort = $item_details_result->{'cn_sort'};

    my ($start_homebranch, $start_location, $start_ccode);
    if (C4::Context->preference('ShelfBrowserUsesHomeBranch') && 
    	defined($item_details_result->{'homebranch'})) {
        $start_homebranch->{code} = $item_details_result->{'homebranch'};
        $start_homebranch->{description} = Koha::Libraries->find($item_details_result->{'homebranch'})->branchname;
    }
    if (C4::Context->preference('ShelfBrowserUsesLocation') && 
    	defined($item_details_result->{'location'})) {
        $start_location->{code} = $item_details_result->{'location'};
        $start_location->{description} = GetAuthorisedValueDesc(q{}, q{}, $item_details_result->{'location'}, q{}, q{}, 'LOC', 'opac');
    }
    if (C4::Context->preference('ShelfBrowserUsesCcode') && 
    	defined($item_details_result->{'ccode'})) {
        $start_ccode->{code} = $item_details_result->{'ccode'};
        $start_ccode->{description} = GetAuthorisedValueDesc(q{}, q{}, $item_details_result->{'ccode'}, q{}, q{}, 'CCODE', 'opac');
    }

    # Build the query for previous and next items
    my $prev_query = q{
        SELECT itemnumber, biblionumber, cn_sort, itemcallnumber
        FROM items
        WHERE
            ((cn_sort = ? AND itemnumber < ?) OR cn_sort < ?)
    };
    my $next_query = q{
        SELECT itemnumber, biblionumber, cn_sort, itemcallnumber
        FROM items
        WHERE
            ((cn_sort = ? AND itemnumber >= ?) OR cn_sort > ?)
    };
    my @params;
    my $query_cond;
    push @params, ($start_cn_sort, $itemnumber, $start_cn_sort);
    if ($start_homebranch) {
    	$query_cond .= 'AND homebranch = ? ';
    	push @params, $start_homebranch->{code};
    }
    if ($start_location) {
    	$query_cond .= 'AND location = ? ';
    	push @params, $start_location->{code};
    }
    if ($start_ccode) {
    	$query_cond .= 'AND ccode = ? ';
    	push @params, $start_ccode->{code};
    }

    my @prev_items = @{
        $dbh->selectall_arrayref(
            $prev_query . $query_cond . ' ORDER BY cn_sort DESC, itemnumber DESC LIMIT ?',
            { Slice => {} },
            ( @params, $gap )
        )
    };
    my @next_items = @{
        $dbh->selectall_arrayref(
            $next_query . $query_cond . ' ORDER BY cn_sort, itemnumber LIMIT ?',
            { Slice => {} },
            ( @params, $gap + 1 )
        )
    };

    my $prev_item = $prev_items[-1];
    my $next_item = $next_items[-1];
    @next_items = splice @next_items, 0, $num_each_side + 1;
    @prev_items = reverse splice @prev_items, 0, $num_each_side;
    my @items = ( @prev_items, @next_items );

    $next_item = undef
        if not $next_item
            or ( $next_item->{itemnumber} == $items[-1]->{itemnumber}
                and ( @prev_items or @next_items <= 1 )
            );
    $prev_item = undef
        if not $prev_item
            or ( $prev_item->{itemnumber} == $items[0]->{itemnumber}
                and ( @next_items or @prev_items <= 1 )
            );

    # populate the items
    @items = GetCatalogueData( @items );

    return {
        items               => \@items,
        count               => scalar(@items),
        next_item           => $next_item,
        prev_item           => $prev_item,
        starting_homebranch => $start_homebranch,
        starting_location   => $start_location,
        starting_ccode      => $start_ccode,
    };
}

sub GetCoverFlowDataByBiblionumber {
    my @biblios = @_;
    my @biblist;

    foreach my $biblionumber (@biblios) {
        push @biblist, { biblionumber => $biblionumber }
    }

    # populate catalogue record data
    @biblist = GetCatalogueData( @biblist );
    
    return {
        items  => \@biblist,
        count  => scalar(@biblist),
    };
}

sub GetCoverFlowDataByQueryString {
    my ($query,$offset,$maxcount) = @_;
    $offset = 0 if (! $offset);
    $maxcount = 20 if (! $maxcount);

    my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
    my ( $error, $searchresults, $totalcount ) = $searcher->simple_search_compat($query,$offset,$maxcount);
    my @results;
    my @biblist;
    if (!defined $error) {
        foreach my $resultrecord (@{$searchresults}) {
            my $bibdata = TransformMarcToKoha( { record => C4::Search::new_record_from_zebra('biblioserver',$resultrecord) } );

            if ($bibdata) {
                push @results, { biblionumber => $bibdata->{'biblionumber'} };
            }
        }
        # populate catalogue record data
        @biblist = GetCatalogueData( @results );
    
        return {
            items  => \@biblist,
            count  => scalar(@biblist),
            totalcount => $totalcount,
            offset => $offset,
            query => $query
        };
    }
    return {
        items  => \@biblist,
        count  => 0,
        totalcount => 0,
        offset => $offset,
        query => $query
    };
}

# Populate an item list with titel data and upc, oclc and isbn normalized.
sub GetCatalogueData {
    my @items = @_;
    my $marcflavour = C4::Context->preference('marcflavour');
    my @valid_items;
    for my $item ( @items ) {
        my $biblio = Koha::Biblios->find( $item->{biblionumber} );
        next unless defined $biblio;
        next if ( $biblio->hidden_in_opac({ rules => C4::Context->yaml_preference('OpacHiddenItems') }) );
        
        $item->{local_image_count} = 0;
        my $cover_images = $biblio->cover_images;
        if ( $cover_images->count ) {
            $item->{local_image_count} = $cover_images->count;
        }

        $item->{biblio_object} = $biblio;
        $item->{biblionumber}  = $biblio->biblionumber;
        $item->{title}         = $biblio->title;
        $item->{title} =~ s/[\x{0098}\x{009c}]//g if ($item->{title});
        $item->{subtitle}      = $biblio->subtitle;
        $item->{subtitle} =~ s/[\x{0098}\x{009c}]//g if ($item->{subtitle});
        $item->{medium}        = $biblio->medium;
        $item->{part_number}   = $biblio->part_number;
        $item->{part_name}     = $biblio->part_name;
        my $record = $biblio ? $biblio->metadata->record : undef;

		if ( $record ) {
			$item->{'browser_normalized_upc'}  = GetNormalizedUPC($record,$marcflavour);
			$item->{'browser_normalized_oclc'} = GetNormalizedOCLCNumber($record,$marcflavour);
			$item->{'browser_normalized_isbn'} = GetNormalizedISBN(undef,$record,$marcflavour);
			$item->{'browser_normalized_ean'}  = GetNormalizedEAN($record,$marcflavour);

			if (C4::Context->preference('OpacSuppression')) {
				my $opacsuppressionfield = '942';
				my $opacsuppressionfieldvalue = $record->field($opacsuppressionfield);
				if ( $opacsuppressionfieldvalue &&
					$opacsuppressionfieldvalue->subfield("n") &&
					$opacsuppressionfieldvalue->subfield("n") == 1) 
				{
					next;
				}
			}
			my $field = $record->field('245');
			my $titleblock = q{};
			my $title = q{};
			my $author = q{};
		
			if ( $field ) {
				$title = $field->subfield('a');
				my $subtitle = $field->subfield('b');
				$author = $field->subfield('c');
		
				$titleblock = $title;
				
				if ( $subtitle ) {
					$titleblock .= ': ' . $subtitle;
				}
				$author =~ s/^\s*\/\s*// if ($author);
				if ( $author ) {
					$titleblock .= ' / ' . $author;
				}
				if ( $titleblock !~ /\.$/ ) {
					$titleblock .= '.';
				}
			}
			
			$field = $record->field('250');
			my $edition;
			if ( $field ) {
				$edition = $field->subfield('a');
		
				if ( $edition ) {
					$titleblock .= ' - ' . $edition;
					if ( $titleblock !~ /\.$/ ) {
						$titleblock .= '.';
					} 
				}
			}
			
			$field = $record->field('260');
			$field = $record->field('264') if (! $field);
			my $year;
			my $location;
			my $publisher;
			if ( $field ) {
				$location = $field->subfield('a');
				$publisher = $field->subfield('b');
				$year = $field->subfield('c');
		
				my $publisherblock = $location;
				if ( $publisherblock && ( defined $publisher || defined $year )) {
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
			$title =~ s/[\x{0098}\x{009c}]//g if ($title);
			$author =~ s/[\x{0098}\x{009c}]//g if ($author);
			$titleblock =~ s/[\x{0098}\x{009c}]//g if ($titleblock);
			
			
			my $identifier = q{};
			$field = $record->field('020');
			if ( $field ) {
				my $isbn = $field->subfield('a');
				$identifier = $isbn if ( $isbn );
			}
			$field = $record->field('024');
			if ( $field && $identifier eq q{} ) {
				my $ean = $field->subfield('a');
				$identifier = $ean if ( $ean );
			}
			
			my $coverurl = q{};
			foreach my $field ( $record->field('856') ) {
				if ( $field->subfield('q') && $field->subfield('q') =~ /^cover/ && $field->subfield('u') ) {
					next if ($field->subfield('n') && $field->subfield('n') =~ /^(Wikipedia|Antolin)$/i );
					my $val = $field->subfield('u');
					next if (! $val);
					next if ( $val =~ /\.ekz\.de/ && !C4::Context->preference('EKZCover') );
					next if ( $val =~ /\.onleihe\.de/ && !C4::Context->preference('DivibibEnabled') );
					$coverurl = $val;
					$coverurl =~ s#http:\/\/cover\.ekz\.de#https://cover.ekz.de#;
					$coverurl =~ s#http:\/\/www\.onleihe\.de#https://www.onleihe.de#;
					last;
				}
			}
				
			my $generic_coverurl = '/api/v1/public/generated_cover?title=' . uri_escape_utf8($title) .'&author=' . uri_escape_utf8($author) ;

			$item->{'titleblock'} = $titleblock;
			$item->{'coverurl'}   = $coverurl;
			$item->{'gencover'}   = $generic_coverurl;
			$item->{'identifier'} = $identifier;
			$item->{'author'}     = $author;
			$item->{'year'}       = $year;
			$item->{'edition'}    = $edition;
			$item->{'place'}      = $location;
			$item->{'publisher'}  = $publisher;

			push @valid_items, $item;
		}
    }
    return @valid_items;
}

1;
