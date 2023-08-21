package C4::External::VGWortExport;

# Copyright 2023 LMSCloud GmbH
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

use base 'XML::Simple';

use Modern::Perl;
use utf8;
use Carp;

use C4::Context;
use C4::Biblio;
use C4::Charset;

use Koha::DateUtils qw( output_pref );
use Koha::Biblios;

use Data::Dumper;
use XML::Simple;
use DateTime;

=head1 NAME

C4::External::VGWortExport - Functions to create a VGWortExport

=head1 SYNOPSIS

use C4::External::VGWortExport;

my $exporter = C4::External::VGWortExport->new($fromDate,$toDate,$mediaTypeMapping,$libraryGroup,$library);

# get a hash with statistical information about the export data
$exporter->getExportCountsPerVGWortMediaType();

# get the list of titles to export
my $titleList = $exporter->getExportTitleList();

# create the export XML header
$exporter->createXMLHeader();

# create the export XML header
$exporter->createXMLTitleEntry($titleEntry);

# create the export XML footer
$exporter->createXMLFooter();

# get output filename
$exporter->getOutputFilename();

=head1 DESCRIPTION

The module provides functionality to create a VGWortExport

=head1 FUNCTIONS

=head2 new

C4::External::VGWortExport->new();

Instantiate a new VGWort exporter with the from-to dates, the media type mapping, and the library information.

The function need to be called with a from date from and to date as parameters, hash that maps koha media types 
VG WORT media types and a library group code or a library code, which can be used to limit the data contained 
in the export file. 

=cut

sub new {
    my ($class,$fromDate,$toDate,$mediaTypeMapping,$libraryGroup,$library) = @_;

    my $self = {};
    bless $self, $class;
    
    $self->{fromDate} = $fromDate;
    $self->{toDate} = $toDate;
    $self->{mediaTypeMapping} = $mediaTypeMapping;
    my $useItypes = [];
    my $qmarks = [];
    
    foreach my $itype (keys %$mediaTypeMapping) {
        if ( $mediaTypeMapping->{$itype} ) {
            push @$useItypes, $itype;
            push @$qmarks, '?';
        }
    }
    
    $self->{itypes} = $useItypes;
    my $selectItypeAdd = join(',',@$qmarks);
    
    $self->{useLibraryGroup} = '0';
    $self->{libraryGroup} = '';
    $self->{useSingleLibrary} = '0';
    $self->{singleLibrary} = '';
    
    if ( $library ) {
        $self->{useSingleLibrary} = '1';
        $self->{singleLibrary} = $library;
    }
    elsif ( $libraryGroup ) {
        $self->{useLibraryGroup} = '1';
        $self->{libraryGroup} = $libraryGroup;
    }
    
    my $xmlheader = '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>' . "\n" .
                    '<!DOCTYPE DATEI PUBLIC' . "\n" .
                    '       "-//Berlinger SE//DTD crv-meldung-nutzung-ausleihen 1.0//DE"' . "\n" .
                    '       "http://download.vgwort.de/xsd/1_0/crv-meldung-nutzung-ausleihen_1_0.dtd">';
    $self->{xmlheader} = $xmlheader;
    
    my $dt = DateTime->today();
    $self->{today} = output_pref({ dt => $dt, dateonly => 1 });
    $self->{filename} = "VGWort-Export-" . output_pref({ dt => $dt, dateformat => 'iso', dateonly => 1  }) . '.xml';
    
    $self->{selectAggregatedStart} = q{
         SELECT year, itype, COUNT(biblionumber) AS count, SUM(isscount) AS isscount, SUM(issued) AS issued, SUM(renewed) AS renewed
         FROM (
    };
    
    $self->{selectAggregatedEnd} = q{
         ) AS summarized
         GROUP BY year,itype;
    };
    
    $self->{selectTitles} = q{
        SELECT sums.year,
               sums.biblionumber,
               sums.itype,
               IFNULL(SUM(sums.isscount),0) AS isscount,
               IFNULL(SUM(sums.issued),0) AS issued,
               IFNULL(SUM(sums.renewed),0) AS renewed,
               SUM(sums.deleteditems) AS deleteditems
        FROM
            (
                SELECT i.biblionumber,
                       i.itype,
                       s.branch,
                       i.homebranch,
                       count(*) AS isscount,
                       SUM( IF(s.type = 'issue',1,0) ) AS issued,
                       SUM( IF(s.type = 'renew',1,0) ) AS renewed,
                       YEAR(s.datetime) AS year,
                       0 AS deleteditems
                FROM   statistics s
                       JOIN items i ON ( i.itemnumber = s.itemnumber )
                WHERE  ( date(s.datetime) >= ( @startdatum := ? ) ) 
                   AND ( date(s.datetime) <= ( @enddatum := ? ) )
                   AND s.type in ('issue', 'renew')
                   AND i.itype IN (} . $selectItypeAdd . q{)
                GROUP BY i.biblionumber, i.itype, s.branch, i.homebranch, YEAR(s.datetime) 
                UNION ALL
                SELECT i.biblionumber,
                       i.itype,
                       s.branch,
                       i.homebranch,
                       count(*) AS isscount,
                       SUM( IF(s.type = 'issue',1,0) ) AS issued,
                       SUM( IF(s.type = 'renew',1,0) ) AS renewed,
                       YEAR(s.datetime) AS year,
                       1 AS deleteditems
                FROM   statistics s
                       JOIN deleteditems i ON ( i.itemnumber = s.itemnumber )
                WHERE  ( date(s.datetime) >= ( @startdatum ) ) 
                   AND ( date(s.datetime) <= ( @enddatum ) )
                   AND s.type in ('issue', 'renew')
                   AND i.itype IN (} . $selectItypeAdd . q{)
                GROUP BY i.biblionumber, i.itype, s.branch, i.homebranch, YEAR(s.datetime)
            )   AS sums,
            (   SELECT s.branchcode 
                FROM   branches s
                WHERE 
                    ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                    OR
                    ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                    OR
                    (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
            ) AS br
        WHERE sums.branch = br.branchcode 
           OR ( 
                (sums.branch IS NULL or sums.branch = 'OPACRenew' ) 
                AND sums.homebranch = br.branchcode
              )
        GROUP BY sums.year,sums.biblionumber,sums.itype
    };
    return $self;
};

=head2 getExportCountsPerVGWortMediaType

Create statistic information about data that will be contained in an VG Wort export.

The output is structured as below:
[
	  {
		'year' => '2022',
		'stats' => [
					 {
					   'mediaType' => 'AV-MEDIUM',    # VG WORT media type
					   'count' => 4,                  # count of titles of that media type
					   'isscount' => 6,               # sum of loans and renewals of the titles
					   'year' => 2022,                # statistical year
					   'itypes' => [                  # list of Koha itypes that are mapped to the VG Wort media type
									 'MO0',
									 'MO12',
									 'MO18'
								   ],
					   'itypeCount' => {              # titles belongig to the the ralated itypes
										 'MO12' => 2,
										 'MO0' => 1,
										 'MO18' => 1
									   },
					   'renewed' => 3,                # count of renewals
					   'issued' => 3                  # coutn of loans
					 },
					 {
					   'mediaType' => 'BUCH',
					   'count' => 5,
					   'isscount' => '6',
					   'year' => 2022,
					   'itypes' => [
									 'BU0'
								   ],
					   'itypeCount' => {
										 'BU0' => 5
									   },
					   'renewed' => '5',
					   'issued' => '1'
					 }
				   ]
	  }
]

=cut

sub getExportCountsPerVGWortMediaType {
    my $self = shift;
    
    my $dbh = C4::Context->dbh;
    
    my $sth = $dbh->prepare($self->{selectAggregatedStart} . $self->{selectTitles} . $self->{selectAggregatedEnd});
    
    $sth->execute($self->{fromDate},$self->{toDate},@{$self->{itypes}},@{$self->{itypes}},$self->{useLibraryGroup},$self->{libraryGroup},$self->{useSingleLibrary},$self->{singleLibrary});
    
    my $result = [];
    my $resultMapping = {};
    while ( my $mediaTypeCount = $sth->fetchrow_hashref ) {
        my $mediatype = 'BUCH';
        
        if ( exists( $self->{mediaTypeMapping}->{ $mediaTypeCount->{itype} } ) ) {
            $mediatype = $self->{mediaTypeMapping}->{ $mediaTypeCount->{itype} };
        }
        
        if ( exists( $resultMapping->{ $mediaTypeCount->{year} }->{ $mediatype } ) ) {
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{issued}   += $mediaTypeCount->{issued};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{renewed}  += $mediaTypeCount->{renewed};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{count}    += $mediaTypeCount->{count};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{isscount} += $mediaTypeCount->{isscount};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{itypeCount}->{$mediaTypeCount->{itype}} = $mediaTypeCount->{count};
            push @{$resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{itypes}}, $mediaTypeCount->{itype};
        } else {
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{issued}    = $mediaTypeCount->{issued};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{renewed}   = $mediaTypeCount->{renewed};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{count}     = $mediaTypeCount->{count};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{isscount}  = $mediaTypeCount->{isscount};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{itypes}    = [$mediaTypeCount->{itype}];
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{year}      = $mediaTypeCount->{year};
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{mediaType} = $mediatype;
            $resultMapping->{$mediaTypeCount->{year}}->{$mediatype}->{itypeCount}->{$mediaTypeCount->{itype}} = $mediaTypeCount->{count};
        }
    }
    foreach my $year(sort keys %$resultMapping) {
        my $yearstat = [];
        foreach my $mtype(sort keys %{ $resultMapping->{$year} }) {
            push @$yearstat, $resultMapping->{$year}->{$mtype};
        }
        push @$result, { year => $year, stats => $yearstat };
    }
    
    return $result;
}

=head2 getExportTitleList

To enable streaming of the export xml file, all titles for an export can be retrieved 
and exported as xml fragment using the function createXMLTitleEntry.

=cut

sub getExportTitleList {
    my $self = shift;
    
    my $dbh = C4::Context->dbh;
    
    my $sth = $dbh->prepare($self->{selectTitles});
    
    # print STDERR "VGWort export:", $self->{fromDate},$self->{toDate},$self->{useLibraryGroup},$self->{libraryGroup},$self->{useSingleLibrary},$self->{singleLibrary},"\n";
    
    $sth->execute($self->{fromDate},$self->{toDate},@{$self->{itypes}},@{$self->{itypes}},$self->{useLibraryGroup},$self->{libraryGroup},$self->{useSingleLibrary},$self->{singleLibrary});
    
    my $result = [];
    while ( my $titleInfo = $sth->fetchrow_hashref ) {
        push @$result,$titleInfo;
    }
    
    return $result;
}

sub openExportTitleList {
    my $self = shift;
    
    my $dbh = C4::Context->dbh;
    
    my $sth = $dbh->prepare($self->{selectTitles});
    
    # print STDERR "VGWort export:", $self->{fromDate},$self->{toDate},$self->{useLibraryGroup},$self->{libraryGroup},$self->{useSingleLibrary},$self->{singleLibrary},"\n";
    
    $sth->execute($self->{fromDate},$self->{toDate},@{$self->{itypes}},@{$self->{itypes}},$self->{useLibraryGroup},$self->{libraryGroup},$self->{useSingleLibrary},$self->{singleLibrary});
    
    $self->{exportTitlesSTH} = $sth;
    
    return 1;
}

sub fetchExportListTitle {
    my $self = shift;
    
    my $sth = $self->{exportTitlesSTH};
    
    if ( my $titleInfo = $sth->fetchrow_hashref ) {
        return (1,$titleInfo);
    }
    return (0,undef);
}

=head2 createXMLTitleEntry

Create an xml fragment containing the data of one title entry in an VG WORT xml export.
The xml fragment has the following format:

<MELDUNG AUSLEIHEN="1" JAHR="2021" NUTZUNGSART="BOAusleihen">
  <WERK ERSCHEINUNGSJAHR="2012" WERKTYP="BUCH">
    <TITEL>Lambacher-Schweizer - Mathematik für Gymnasien : Analytische Geometrie und lineare Algebra</TITEL>
    <ISBN>9783127357165</ISBN>
    <ISSN></ISSN>
    <MEDIENARTEN>
      <MEDIUM TYPE="DRUCK" />
    </MEDIENARTEN>
    <BETEILIGTE>
      <VERLAG FUNKTION="VERLEGER" NAME="Klett" />
      <URHEBER FUNKTION="BETEILIGTE PERSON" NAME="Freudigmann, Hans" />
      <URHEBER FUNKTION="Begr." NAME="Lambacher, Theophil" />
    </BETEILIGTE>
  </WERK>
</MELDUNG>

=cut

sub createXMLTitleEntry {
    my $self = shift;
    my $titleEntry = shift;
    
    my $biblionumber = $titleEntry->{biblionumber};
    my $biblio = Koha::Biblios->find( $biblionumber );
    my $record = $biblio ? $biblio->metadata->record : undef;
    
    $record = GetDeletedMarcBiblio({ biblionumber => $biblionumber }) if (! $record );
    
    if ( $record ) {
        my $mediatype = 'BUCH';
        
        if ( exists( $self->{mediaTypeMapping}->{ $titleEntry->{itype} } ) ) {
            $mediatype = $self->{mediaTypeMapping}->{ $titleEntry->{itype} };
        }
        
        my $media;
        if ( $mediatype eq 'AV-MEDIUM' ) {
            my $contentSpec = $record->subfield('300','a');
            
            if ( $contentSpec =~ /DVD/i || $contentSpec =~ /BD/i ) {
                $media = 'DVD';
            }
            elsif ( $contentSpec =~ /Kassette/i ) {
                $media = 'KASSETTE';
            }
            elsif ( $contentSpec =~ /Diskette/i ) {
                $media = 'DISKETTE';
            }
            elsif ( $contentSpec =~ /CD/i ) {
                $media = 'COMPACT DISC';
            }
            elsif ( $contentSpec =~ /platte/i ) {
                $media = 'PLATTE';
            }
            elsif ( $contentSpec =~ /VHS/i || $contentSpec =~ /Video/i ) {
                $media = 'VHS';
            }
            $media = 'MEDIENKOMBINATION' if (! $media);
        } else {
            $media = 'DRUCK';
        }
        
        my $title = '';
        if ( my $field = $record->field('245') ) {
            if ( $field->subfield('a') ) {
                $title = $field->subfield('a');
                if ( $field->subfield('c') ) {
                    $title .= ' / ' if ( $title );
                    $title .= $field->subfield('c');
                }
                if ( $field->subfield('p') ) {
                    $title .= ' : '  if ( $title );
                    $title .= $field->subfield('p');
                }
                if ( $field->subfield('n') ) {
                    $title .= ' : '  if ( $title );
                    $title .= $field->subfield('n');
                }
            }
        }
        my $year = $record->subfield('264','c');
        $year = $record->subfield('260','c') if (! $year);
        
        my $isbn = $record->subfield('020','a');
        $isbn = $record->subfield('020','z') if (! $isbn);
        $isbn = $record->subfield('024','a') if (! $isbn);
        
        my $issn = $record->subfield('022','a');
        $issn = $record->subfield('022','l') if (! $isbn);
        $issn = $record->subfield('022','y') if (! $isbn);
        $issn = $record->subfield('022','m') if (! $isbn);
        $issn = $record->subfield('022','z') if (! $isbn);
        
        my $beteiligte = [ {} ];
        foreach my $field( $record->field('100','110','111','700','710','711') ) {
            my $name = $field->subfield('a');
            if ( $name ) {
                my $function = $field->subfield('e');
                $function = $field->subfield('4') if (! $function);
                if (! $function ) {
                    if ( $field->tag() eq '100' ) {
                        $function = 'AUTOR';
                    }
                    elsif ( $field->tag() eq '110' ) {
                        $function = 'KÖRPERSCHAFT';
                    }
                    elsif ( $field->tag() eq '111' ) {
                        $function = 'MEETING';
                    }
                    elsif ( $field->tag() eq '700' ) {
                        $function = 'BETEILIGTE PERSON';
                    }
                    elsif ( $field->tag() eq '710' ) {
                        $function = 'BETEILIGTE KÖRPERSCHAFT';
                    }
                    elsif ( $field->tag() eq '711' ) {
                        $function = 'BETEILIGTES MEETING';
                    }
                }
                if ( !exists($beteiligte->[0]->{URHEBER}) ) {
                    $beteiligte->[0]->{URHEBER} = [];
                }
                push @{$beteiligte->[0]->{URHEBER}}, { 'FUNKTION' => $function, 'NAME' => $name };
            }
        }
        foreach my $field($record->field('260','264') ) {
            my $name = $field->subfield('b');
            if ( $name ) {
                my $function;
                if ( $field->tag() eq '264' && $field->indicator(1) eq '0' ) {
                    $function = 'PRODUKTION';
                }
                elsif ( $field->tag() eq '264' && $field->indicator(1) eq '1' ) {
                    $function = 'VERLEGER';
                }
                elsif ( $field->tag() eq '264' && $field->indicator(1) eq '2' ) {
                    $function = 'DISTRIBUTOR';
                }
                elsif ( $field->tag() eq '264' && $field->indicator(1) eq '3' ) {
                    $function = 'HERSTELLER';
                }
                elsif ( $field->tag() eq '264' && $field->indicator(1) eq '4' ) {
                    next;
                }
                
                if ( !$function ) {
                    $function = 'VERLEGER';
                }
                if ( !exists($beteiligte->[0]->{VERLAG}) ) {
                    $beteiligte->[0]->{VERLAG} = [];
                }
                push @{$beteiligte->[0]->{VERLAG}}, { 'FUNKTION' => $function, 'NAME' => $name };
            }
        }
        
        my $titleData = { 'MELDUNG' =>
                           {
                               'NUTZUNGSART' => 'BOAusleihen',
                               'JAHR' => $titleEntry->{year},
                               'AUSLEIHEN' => $titleEntry->{isscount},
                               'WERK' => {
                                   'ERSCHEINUNGSJAHR' => $year,
                                   'WERKTYP' => $mediatype,
                                   'TITEL' => [ $title ],
                                   'ISBN'  => [ $isbn ],
                                   'ISSN'  => [ $issn ],
                                   'BETEILIGTE' =>  $beteiligte,
                                   'MEDIENARTEN' =>  [ { 'MEDIUM' => [ { TYPE => $media } ] } ]
                               }
                           }
                        };
        return $self->XMLout($titleData, KeepRoot => 1 );
    }
}

sub GetDeletedMarcBiblio {
    my ($params) = @_;

    if (not defined $params) {
        carp 'GetDeletedMarcBiblio called without parameters';
        return;
    }

    my $biblionumber = $params->{biblionumber};

    if (not defined $biblionumber) {
        carp 'GetDeletedMarcBiblio called with undefined biblionumber';
        return;
    }

    my $dbh          = C4::Context->dbh;
    my $sth          = $dbh->prepare("SELECT biblioitemnumber FROM deletedbiblioitems WHERE biblionumber=? ");
    $sth->execute($biblionumber);
    my $row     = $sth->fetchrow_hashref;
    my $biblioitemnumber = $row->{'biblioitemnumber'};
    my $marcxml = GetDeletedXmlBiblio( $biblionumber );
    $marcxml = C4::Charset::StripNonXmlChars( $marcxml );
    my $frameworkcode = GetDeletedFrameworkCode($biblionumber);
    MARC::File::XML->default_record_format( C4::Context->preference('marcflavour') );
    my $record = MARC::Record->new();
    if ($marcxml) {
        $record = eval {
            MARC::Record::new_from_xml( $marcxml, "UTF-8",
                C4::Context->preference('marcflavour') );
        };
        if ($@) { warn " problem with :$biblionumber : $@ \n$marcxml"; }
        return unless $record;

        C4::Biblio::_koha_marc_update_bib_ids( $record, $frameworkcode, $biblionumber,
            $biblioitemnumber );

        return $record;
    }
    else {
        return;
    }
}

sub GetDeletedXmlBiblio {
    my ($biblionumber) = @_;
    my $dbh = C4::Context->dbh;
    return unless $biblionumber;
    my ($marcxml) = $dbh->selectrow_array(
        q|
        SELECT metadata
        FROM deletedbiblio_metadata
        WHERE biblionumber=?
            AND format='marcxml'
            AND `schema`=?
    |, undef, $biblionumber, C4::Context->preference('marcflavour')
    );
    return $marcxml;
}

sub GetDeletedFrameworkCode {
    my ($biblionumber) = @_;
    my $dbh            = C4::Context->dbh;
    my $sth            = $dbh->prepare("SELECT frameworkcode FROM deletedbiblio WHERE biblionumber=?");
    $sth->execute($biblionumber);
    my ($frameworkcode) = $sth->fetchrow;
    return $frameworkcode;
}

=head2 createXMLHeader

Create an xml header for an VG WORT xml export.
The xml header has the following format:

<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<!DOCTYPE DATEI PUBLIC
       "-//Berlinger SE//DTD crv-meldung-nutzung-ausleihen 1.0//DE"
       "http://download.vgwort.de/xsd/1_0/crv-meldung-nutzung-ausleihen_1_0.dtd">
<DATEI VERSION="1.0" BIBLIOTHEK="Bibliothek Wallenheim" ERSTELLT="14.02.2023" FILE_CRV="VGWort-Export-2023-02-14.xml" TRANSACTION="MELDUNG">

=cut

sub createXMLHeader {
    my $self = shift;
    
    my $library = encodeXML( C4::Context->preference('LibraryName') );
    
    return $self->{xmlheader} . 
           "\n" .
           '<DATEI VERSION="1.0" ' .
           'BIBLIOTHEK="' . $library . '" ' .
           'ERSTELLT="' . $self->{today} . '" ' . 
           'FILE_CRV="' . encodeXML($self->{filename}) . '" ' .
           'TRANSACTION="MELDUNG">' . "\n";
}

sub encodeXML {
	my $value = shift;
	$value =~ s/&/&amp;/g;
	$value =~ s/</&lt;/g;
	$value =~ s/>/&gt;/g;
	$value =~ s/"/&quot;/g;
	return $value;
}

=head2 createXMLFooter

Create an xml footer for an VG WORT xml export.
The xml footer has the following format:

</DATEI>

=cut

sub createXMLFooter {
    my $self = shift;
    return '</DATEI>' . "\n";
}

=head2 getOutputFilename

Deliver the xml output file name formatted as VGWort-Export-YYYY-MM-DD.xml.

=cut

sub getOutputFilename {
    my $self = shift;
    return $self->{filename};
}

=head2 sorted_keys

Helper function to sort XML elements. Overwrites an XML::Simple function.

=cut

sub sorted_keys
{
   my ($self, $name, $hashref) = @_;
   if ($name eq 'MELDUNG')   # only this tag I care about the order;
   {
      my @ordered = qw(
          STATUS
          AUSLEIHEN
          JAHR
          NUTZUNGSART
          WERK
      );
      my %ordered_hash = map {$_ => 1} @ordered;

      #set ordered tags in front of others
      return grep {exists $hashref->{$_}} @ordered, grep {not $ordered_hash{$_}} $self->SUPER::sorted_keys($name, $hashref);
   }
   if ($name eq 'WERK')   # only this tag I care about the order;
   {
      my @ordered = qw(
          TITEL
          ISBN
          ISSN
          MAP551
          MEDIENARTEN
          BEMERKUNG
          BETEILIGTE
      );
      my %ordered_hash = map {$_ => 1} @ordered;

      #set ordered tags in front of others
      return grep {exists $hashref->{$_}} @ordered, grep {not $ordered_hash{$_}} $self->SUPER::sorted_keys($name, $hashref);
   }
   if ($name eq 'BETEILIGTE')   # only this tag I care about the order;
   {
      my @ordered = qw(
          VERLAG
          URHEBER
      );
      my %ordered_hash = map {$_ => 1} @ordered;

      #set ordered tags in front of others
      return grep {exists $hashref->{$_}} @ordered, grep {not $ordered_hash{$_}} $self->SUPER::sorted_keys($name, $hashref);
   }
   return $self->SUPER::sorted_keys($name, $hashref); # for the rest, I don't care!
}

1;
