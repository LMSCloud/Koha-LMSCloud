package C4::VolumeData;

# Copyright 2018 LMSCloud GmbH
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

use C4::Search;
use C4::Languages;
use C4::Context;

use Koha::SearchEngine::Search;
use Koha::SearchEngine::QueryBuilder;
use Koha::ItemTypes;

use Unicode::Normalize;

use vars qw(@ISA @EXPORT);

BEGIN {
    require Exporter;
        @ISA    = qw(Exporter);
        @EXPORT = qw(
            GetVolumeData
        );
}

=head1 NAME

C4::VolumeData - retrieve formatted volume data for a biblio record

=head1 DESCRIPTION

The module capsules functions to access volume data of a biblio record.
The main function GetVolumeData takes a biblionumber and searches the 
recn index to find volumes records with a link to the record number in 
MARC field 773$w.
Found volume records are been formatted using the function C4::Search::searchResults
which is used to format result records of biblio search in opac and intranet
environment.

=cut

=head2 GetVolumeData

  $result = GetVolumeData($refnumber,$biblionumber,$linkedRecords,$lang);
  
=head3 Arguments

    * $refnumber is the record number to search for typically provided in MARC field 001
    * $biblionumber is the biblionumber of the record
    * $linkedRecords may optinally contain a list of record IDs which are searched with Control-number index
    * $lang specifies optionally language to use to format the volume data

=head3 Returns

    Returns a list of three data elements
    
    * $error if an error occured
    * $volumes is a list of volume records
    * $linkedRecordData is a list of related records that link to that record

=cut

sub GetVolumeData {
    my $refnumber = shift;
    my $biblionumber = shift;
    my $linkedRecords = shift;
    my $lang = shift;
    
    $lang = C4::Languages::getlanguage() if (! $lang );

    my $marcOrgCode =  C4::Context->preference('MARCOrgCode') || '';

    my $searchstring = "rcn:$refnumber"; # not (bib-level:a or bib-level:b)";
    $searchstring .= " AND cna:$marcOrgCode" if ( $marcOrgCode );

    my ($error,$volumes) = SearchVolumeData($searchstring,$lang,'opacvolume');
    return ($error,$volumes,undef) if ($error);
    
    my $linkedRecordData = [];
    
    # print STDERR "linkedRecords = @$linkedRecords\n";
    if ( $linkedRecords && scalar(@$linkedRecords) > 0 ) {
        $searchstring = '';
        foreach my $linknumber(@$linkedRecords) {
            $searchstring .= ' or ' if ( $searchstring ne '');
            $searchstring .= "Control-number:$linknumber";
        }
        ($error,$linkedRecordData) = SearchVolumeData($searchstring,$lang,'opac',$biblionumber);
        
        # print STDERR $searchstring,"\n";
    }
    return ($error,$volumes,$linkedRecordData);
}

sub SearchVolumeData {
    my $searchstring = shift;
    my $lang         = shift;
    my $view         = shift;
    my $refbiblionumber = shift; 
    
    my $searchengine = C4::Context->preference("SearchEngine");
    my ($builder, $searcher);

    $builder  = Koha::SearchEngine::QueryBuilder->new({index => 'biblios'});
    $searcher = Koha::SearchEngine::Search->new({index => 'biblios'});

    my @servers  = ("biblioserver");
    my @operands = ($searchstring);
    
    my $scan             = undef;
    my $results_per_page = 1000;
    my $offset           =  0;
    my $expanded_facet   = '';

    # Get itemtype with Koha 18.05
    my $itemtypes = { map { $_->{itemtype} => $_ } @{ Koha::ItemTypes->search_with_localization->unblessed } };

    # Build a query
    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) = 
            $builder->build_query_compat(
                [], # no operators
                \@operands,
                [], # no indexes
                [], # no limits,
                [], # no sort_by, 
                0, 
                $lang, 
                {});
    return ($error, undef) if ($error);

    # search the data
    my ($results_hashref, $facets);
    ($error, $results_hashref, $facets) = 
            $searcher->search_compat(
                $query,
                $simple_query,
                [], # no sort_by,
                \@servers,
                $results_per_page,
                $offset,
                $expanded_facet,
                undef,
                $itemtypes,
                $query_type,
                $scan,
                1);
    
    return ($error, undef) if ($error);
    
    my $records = {};
    
    my $userecords = [];
    foreach my $marcdata(@{$results_hashref->{$servers[0]}->{"RECORDS"}}) {
        my $marcrecord = C4::Search::new_record_from_zebra('biblioserver', $marcdata);
        if ( my $biblionumber = $marcrecord->subfield('999','c') ) {
            if ( $refbiblionumber != $biblionumber ) {
                push @$userecords, $marcdata;
                $records->{$biblionumber} = [[$marcrecord->subfield('245','a') || undef,$marcrecord->subfield('245','p') || undef,$marcrecord->subfield('245','n') || undef]];
                for (my $i=0; $i<=2; $i++) {
                    $records->{$biblionumber}->[1]->[$i] = undef;
                    if ( $records->{$biblionumber}->[0]->[$i] ) {
                        $records->{$biblionumber}->[1]->[$i] = normalizeSortData($records->{$biblionumber}->[0]->[$i]);
                    }
                }
            }
        }
    }
    $results_hashref->{$servers[0]}->{"RECORDS"} = $userecords;
    
    my $sortnum = 0;
    foreach my $biblionumber(  sort {  sortVolumeWords($records->{$a}->[1]->[0],$records->{$b}->[1]->[0]) || 
                                       sortVolumeWords($records->{$a}->[1]->[2],$records->{$b}->[1]->[2]) || 
                                       sortVolumeWords($records->{$a}->[1]->[1],$records->{$b}->[1]->[1]) } keys %$records ) 
    {
        $records->{$biblionumber}->[2] = ++$sortnum;
    }

    # get the data
    my @results = ();
    for (my $i=0;$i<@servers;$i++) {
        my $server = $servers[$i];
        my $hits = $results_hashref->{$server}->{"hits"};
        push @results, sort { $records->{$a->{biblionumber}}->[2] <=>  $records->{$b->{biblionumber}}->[2] } 
            searchResults($view, $query_desc, $hits, $results_per_page, $offset, $scan, $results_hashref->{$server}->{"RECORDS"});
    }
    
    $sortnum = 0;
    foreach my $res( @results ) {
        $res->{result_number} = ++$sortnum;
        $res->{sortvolume}    = $records->{ $res->{biblionumber} }->[0]->[2];
        $res->{sortpart}      = $records->{ $res->{biblionumber} }->[0]->[1];
        $res->{sorttitle}     = $records->{ $res->{biblionumber} }->[0]->[0];
    }
    
    return ($error, \@results) 
}

sub normalizeSortData {
    my $s = shift;
    $s = NFD($s); 
    $s =~ s/\r\n\t/ /g;
    $s =~ s/\pM//g;
    $s =~ s/\([^\(\)]+\)/ /g;
    $s =~ s/\s+/ /g;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    return uc($s);
}


sub sortVolumeWords {
    my $a = shift;
    my $b = shift;
    
    return 0  if ( !defined($a) && !defined($b) );
    return -1 if ( !defined($a) );
    return 1  if ( !defined($b) );
    
    my @awords = $a =~ /(\w+(?:'\w+)*)/g;
    my @bwords = $b =~ /(\w+(?:'\w+)*)/g;
    
    my $res = 0;
    my $k = $#awords;
    $k = $#bwords if ($#bwords > $k);
    
    for (my $i = 0; $i <= $k && $res==0; $i++) {
        if ($i > $#awords) {
            $res = -1;
        }
        elsif ($i > $#bwords) {
            $res =  1;
        }
        elsif ( $awords[$i] =~ /^[0-9]+$/ && $bwords[$i] =~ /^[0-9]+$/ ) {
            $res = $awords[$i] <=> $bwords[$i];
        }
        else {
            $res = $awords[$i] cmp $bwords[$i];
        }
    }
    return $res;
}

1;

__END__

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut