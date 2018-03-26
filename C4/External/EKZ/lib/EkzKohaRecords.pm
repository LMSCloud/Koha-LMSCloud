package C4::External::EKZ::lib::EkzKohaRecords;

# Copyright 2017 (C) LMSCLoud GmbH
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

use strict;
use warnings;

use utf8;
use Carp;
use Data::Dumper;
use HTML::Entities;
use Mail::Sendmail;

use Koha::Email;
use MARC::Field;
use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );
use C4::Breeding qw(Z3950SearchGeneral);
use C4::External::EKZ::EkzAuthentication;
use C4::External::EKZ::lib::LMSPoolSRU;
use C4::External::EKZ::lib::EkzWebServices;



binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

our $VERSION = '0.01';
my %branchnames = ();    # for caching the branch names
my $callCounter = 0;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);


my $debugIt = 1;

BEGIN {
    require Exporter;
    $VERSION = 1.00.00.000;
    @ISA = qw(Exporter);
    @EXPORT = qw();
}

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(60);
	$ua->env_proxy;
    $ua->ssl_opts( "verify_hostname" => 0 );
    push @{ $ua->requests_redirectable }, 'POST';

	$self->{'ua'} = $ua;

	return $self;
}


##############################################################################
#
# search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
#
##############################################################################
sub readTitleInLocalDB {
	my $class = shift;
    my $reqParamTitelInfo = shift;
    my $maxhits = shift;

	my $selParam->{'ekzArtikelNr'} = $reqParamTitelInfo->{'ekzArtikelNr'};
	$selParam->{'isbn'} = $reqParamTitelInfo->{'isbn'};
	$selParam->{'isbn13'} = $reqParamTitelInfo->{'isbn13'};
	$selParam->{'issn'} = $reqParamTitelInfo->{'issn'};
	$selParam->{'ismn'} = $reqParamTitelInfo->{'ismn'};
	$selParam->{'ean'} = $reqParamTitelInfo->{'ean'};

	my $result = {'count' => 0, 'records' => []};
    my $hits = 0;
print STDERR "EkzKohaRecords::readTitleInLocalDB() selEkzArtikelNr:", defined($selParam->{'ekzArtikelNr'}) ? $selParam->{'ekzArtikelNr'} : 'undef',
                                                ": selIsbn:", defined($selParam->{'isbn'}) ? $selParam->{'isbn'} : 'undef', 
                                                ": selIsbn13:", defined($selParam->{'isbn13'}) ? $selParam->{'isbn13'} : 'undef',
                                                ": selIssn:", defined($selParam->{'issn'}) ? $selParam->{'issn'} : 'undef', 
                                                ": selIsmn:", defined($selParam->{'ismn'}) ? $selParam->{'ismn'} : 'undef', 
                                                ": selEan:", defined($selParam->{'ean'}) ? $selParam->{'ean'} : 'undef', 
                                                ": maxhits:", defined($maxhits) ? $maxhits : 'undef', ":\n" if $debugIt;

    my $marcresults = $class->readTitleDubletten($selParam,1);
    $hits = scalar @$marcresults if $marcresults;

    HITS: for (my $i = 0; $i < $hits && $maxhits > 0 and defined $marcresults->[$i]; $i++)
    {
        my $marcrecord;
        eval {
            $marcrecord =  MARC::Record::new_from_xml( $marcresults->[$i], "utf8", 'MARC21' );
        };
        carp "EkzKohaRecords::readTitleInLocalDB: error in MARC::Record::new_from_xml:$@:\n" if $@;

        if ( $marcrecord ) {
            # Onleihe e-media have to be filtered out
            my $biblionumber = $marcrecord->subfield("999","c");
            my $items = &C4::Items::GetItemsByBiblioitemnumber( $biblionumber );
            foreach my $item (@$items) {
                if ( isOnleiheItem($item) ) {
                    next HITS;
                }
            }

            push @{$result->{'records'}}, $marcrecord;
            $result->{'count'} += 1;
            if ( defined($maxhits) && $maxhits >= 0 && $result->{'count'} >= $maxhits ) {
                last;
            }
        }
    }
print STDERR "EkzKohaRecords::readTitleInLocalDB() result->{'count'}:$result->{'count'}:\n" if $debugIt;
print STDERR "EkzKohaRecords::readTitleInLocalDB() result->{'records'}:$result->{'records'}:\n" if $debugIt;

	return $result;
}


##############################################################################
#
# test if the item's itype qualifies the title as Onleihe medium
#
##############################################################################
sub isOnleiheItem {
    my ($item) = @_;
    my $ret = 0;

    print STDERR "EkzKohaRecords::isOnleiheItem() item->{itype}:", $item->{itype}, ":\n" if $debugIt;

    if ( $item->{itype} eq 'eaudio' ||
         $item->{itype} eq 'ebook' ||
         $item->{itype} eq 'emusic' ||
         $item->{itype} eq 'epaper' ||
         $item->{itype} eq 'evideo' ) {
        $ret = 1;
    }
    return $ret;
}


##############################################################################
#
# insert elements from the second marcresults array in the first marcresults array if the title is not contained yet.
#
##############################################################################
sub mergeMarcresults {
    my ($marcresults1, $biblionumberhash, $marcresults2, $hitscntref) = @_;

    foreach my $marcresult2 ( @{$marcresults2} ) {
    }
    my $hits2 = 0;
    $hits2 = scalar @{$marcresults2} if $marcresults2;


    for (my $i = 0; $i < $hits2 and defined $marcresults2->[$i]; $i++)
    {
        my $marcrecord2;
        eval {
            $marcrecord2 =  MARC::Record::new_from_xml( $marcresults2->[$i], "utf8", 'MARC21' );
        };
        carp "EkzKohaRecords::mergeMarcresults: error in MARC::Record::new_from_xml:$@:\n" if $@;

        if ( $marcrecord2 ) {
            my $biblionumber = $marcrecord2->subfield("999","c");
            if ( !exists($biblionumberhash->{$biblionumber}) ) {
                push @{$marcresults1}, $marcresults2->[$i];
                $biblionumberhash->{$biblionumber} = $biblionumber;
                $$hitscntref += 1;
            }
        }
    }
}


##############################################################################
#
# search title records with same ekzArtikelNr or ISBN or ISSN/ISMN/EAN or title and author and publication year
#
##############################################################################
sub readTitleDubletten {
	my $class = shift;
    my $selParam = shift;
    my $strictMatch = shift;
print STDERR "EkzKohaRecords::readTitleDubletten() strictMatch:$strictMatch: selParam:", Dumper($selParam), ":\n" if $debugIt;

    my $query = "cn:\"-1\"";                    # control number search, initial definition for no hit
    my @allmarcresults = ();
    my $allinall_hits = 0;
    my %biblionumbersfound = ();

    # search priority:
    # 1. ekzArtikelNr
    # 2. isbn or isbn13
    # 3. issn or ismn or ean
    # 4. titel and author and erscheinungsJahr

    # check for ekzArtikelNr search
    if ( !defined $selParam->{'ekzArtikelNr'} || length($selParam->{'ekzArtikelNr'}) == 0 ) {
        carp "EkzKohaRecords::readTitleDubletten() ekzArtikelNr is empty -> not searching for ekzArtikelNr.\n";
    } else
    {
        # build search query for ekzArtikelNr search
        # If used for spotting the title the new item is assigned to (e.g. webservice BestellInfo), $strictMatch has to be set.
        # If also related titles have to be found (e.g. webservice DublettencheckElement), a wider hit set is recommended, so $strictMatch has to be 0.
        if ( $strictMatch ) {    # used for web service BestellInfo etc.
            $query = "(cn:\"$selParam->{'ekzArtikelNr'}\" and cna:\"DE-Rt5\")";
        } else {    # used for web service DublettenCheckElement
            $query = "(cn:\"$selParam->{'ekzArtikelNr'}\" and cna:\"DE-Rt5\") or (kw,phr:\"(DE-Rt5)$selParam->{'ekzArtikelNr'}\")";
        }
        print STDERR "EkzKohaRecords::readTitleDubletten() query:$query:\n" if $debugIt;

        my ( $error, $marcresults, $total_hits ) = ( '', \(), 0 );
        ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
        
        if (defined $error) {
            my $log_str = sprintf("EkzKohaRecords::readTitleDubletten(): search for ekzArtikelNr:%s: returned error:%d/%s:\n", $selParam->{'ekzArtikelNr'}, $error,$error);
            carp $log_str;
        } else
        {
            mergeMarcresults(\@allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
        }
        print STDERR "EkzKohaRecords::readTitleDubletten() ekzArtikelNr search total_hits:$total_hits: allinall_hits:$allinall_hits:\n" if $debugIt;
    }

    # check for isbn/isbn13 search
    if ( (!defined $selParam->{'isbn'} || length($selParam->{'isbn'}) == 0) && 
         (!defined $selParam->{'isbn13'} || length($selParam->{'isbn13'}) == 0) ) {
        carp("EkzKohaRecords::readTitleDubletten() isbn and isbn13 are empty -> not searching for isbn or isbn13.\n");
    } else
    {
        # build search query for isbn/isbn13 search
        # search for catalog title record by MARC21 category 020/024 (ISBN/EAN)
        $query = '';
        if ( defined $selParam->{'isbn'} && length($selParam->{'isbn'}) > 0 ) {
            $query .= "nb:\"$selParam->{'isbn'}\" or id-other:\"$selParam->{'isbn'}\"";
        }
        if ( defined $selParam->{'isbn13'} && length($selParam->{'isbn13'}) > 0 ) {
            if ( length($query) > 0 ) {
                $query .= ' or ';
            }
            $query .= "nb:\"$selParam->{'isbn13'}\" or id-other:\"$selParam->{'isbn13'}\"";
        }
        print STDERR "EkzKohaRecords::readTitleDubletten() query:$query:\n" if $debugIt;
        
        my ( $error, $marcresults, $total_hits ) = ( '', \(), 0 );
        ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
    
        if (defined $error) {
            my $log_str = sprintf("EkzKohaRecords::readTitleDubletten(): search for isbn:%s: or isbn13:%s: returned error:%d/%s:\n", $selParam->{'isbn'}, $selParam->{'isbn13'}, $error,$error);
            carp $log_str;
        } else
        {
            mergeMarcresults(\@allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
        }
        print STDERR "EkzKohaRecords::readTitleDubletten() isbn/isbn13 search total_hits:$total_hits: allinall_hits:$allinall_hits:\n" if $debugIt;
    }

    # check for issn/ismn/ean search
    if ( (!defined $selParam->{'issn'} || length($selParam->{'issn'}) == 0) && 
         (!defined $selParam->{'ismn'} || length($selParam->{'ismn'}) == 0) && 
         (!defined $selParam->{'ean'} || length($selParam->{'ean'}) == 0) ) {
        carp("EkzKohaRecords::readTitleDubletten() issn and ismn and ean are empty -> not searching for issn or ismn or ean.\n");
    } else
    {
        # build search query for issn/ismn/ean search for searching index ident
        # search for catalog title record by MARC21 category 020/022/024 (ISBN/ISSN/ISMN/EAN)
        my $query1 = '';
        my $query2 = '';
        my $query3 = '';
        if ( defined $selParam->{'issn'} && length($selParam->{'issn'}) > 0 ) {
            $query1 .= "ident:\"$selParam->{'issn'}\"";
        }
        if ( defined $selParam->{'ismn'} && length($selParam->{'ismn'}) > 0 ) {
            if ( length($query1) > 0 ) {
                $query1 .= ' or ';
            }
            $query1 .= "ident:\"$selParam->{'ismn'}\"";
        }
        if ( defined $selParam->{'ean'} && length($selParam->{'ean'}) > 0 ) {
            if ( length($query1) > 0 ) {
                $query2 .= ' or ';
            }
            $query2 .= "ident:\"$selParam->{'ean'}\"";
        }
        $query = $query1 . $query2;
        print STDERR "EkzKohaRecords::readTitleDubletten() query:$query:\n" if $debugIt;
        
        my ( $error, $marcresults, $total_hits ) = ( '', \(), 0 );
        ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
    
        if (defined $error) {
            my $log_str = sprintf("EkzKohaRecords::readTitleDubletten(): search for issn:%s: or ismn:%s: or ean:%s: returned error:%d/%s:\n", $selParam->{'issn'}, $selParam->{'ismn'}, $selParam->{'ean'}, $error,$error);
            carp $log_str;
        }
        print STDERR "EkzKohaRecords::readTitleDubletten() issn/ismn/ean search1 total_hits:$total_hits:\n" if $debugIt;
            
        # ekz sends EAN without leading 0
        if ($total_hits == 0 && defined $selParam->{'ean'} && length($selParam->{'ean'}) > 0 && length($selParam->{'ean'}) < 13) {
            if ( length($query1) > 0 ) {
                $query3 .= ' or ';
            }
            $query3 .= sprintf("ident:\"%013d\"",$selParam->{'ean'});
            $query = $query1 . $query3;
            print STDERR "EkzKohaRecords::readTitleDubletten() query:$query:\n" if $debugIt;
            
            ( $error, $marcresults, $total_hits ) = ( '', \(), 0 );
            ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
        
            if (defined $error) {
                my $log_str = sprintf("EkzKohaRecords::readTitleDubletten(): search for issn:%s: or ismn:%s: or ean:%s: returned error:%d/%s:\n", $selParam->{'issn'}, $selParam->{'ismn'}, $selParam->{'ean'}, $error,$error);
                carp $log_str;
            } else
            {
                mergeMarcresults(\@allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
            }
            print STDERR "EkzKohaRecords::readTitleDubletten() issn/ismn/ean search2 total_hits:$total_hits: allinall_hits:$allinall_hits:\n" if $debugIt;
        }
    }

    # check for author and title and publication year search
    if ( (!defined $selParam->{'author'} || length($selParam->{'author'}) == 0) || (!defined $selParam->{'titel'} || length($selParam->{'titel'}) == 0) || (!defined $selParam->{'erscheinungsJahr'} || length($selParam->{'erscheinungsJahr'}) == 0) ) {
        carp("EkzKohaRecords::readTitleDubletten() author and titel and erscheinungsJahr is empty -> not searching for it.\n");
    } else
    {
        # build search query for author and title and publication year search
        $query = "au,phr:\"$selParam->{'author'}\" and ti,phr,ext:\"$selParam->{'titel'}\" and yr,st-year:\"$selParam->{'erscheinungsJahr'}\"";
        print STDERR "EkzKohaRecords::readTitleDubletten() query:$query:\n" if $debugIt;
        
        my ( $error, $marcresults, $total_hits ) = ( '', \(), 0 );
        ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
    
        if (defined $error) {
            my $log_str = sprintf("EkzKohaRecords::readTitleDubletten(): search for author:%s: or title:%s: publication year:%s: returned error:%d/%s:\n", $selParam->{'author'}, $selParam->{'titel'}, $selParam->{'erscheinungsJahr'}, $error, $error);
            carp $log_str;
        } else
        {
            mergeMarcresults(\@allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
        }
        print STDERR "EkzKohaRecords::readTitleDubletten() author/title/publicationyear search total_hits:$total_hits: allinall_hits:$allinall_hits:\n" if $debugIt;
    }
    
    return \@allmarcresults;
}


##############################################################################
#
# read title data from the LMSCloud ekz title data pool, using ekzArtikelNr, ISBN, ISBN13, ISSN, ISMN, EAN
#
##############################################################################
sub readTitleInLMSPool {
	my $class = shift;
    my ($reqParamTitelInfo) = @_;

    my $selEkzArtikelNr = $reqParamTitelInfo->{'ekzArtikelNr'};
    my $selIsbn = $reqParamTitelInfo->{'isbn'};
    my $selIsbn13 = $reqParamTitelInfo->{'isbn13'};
    my $selIssn = $reqParamTitelInfo->{'issn'};
    my $selIsmn = $reqParamTitelInfo->{'ismn'};
    my $selEan = $reqParamTitelInfo->{'ean'};

    my $foundInPool = 0;
    my $pool = new LMSPoolSRU;
    my $result = {'count' => 0, 'records' => []};

    if(defined $selEkzArtikelNr && length($selEkzArtikelNr) > 0) {
        # search by EKZ id
        my @EKZIDList = ($selEkzArtikelNr);
print STDERR "EkzKohaRecords::readTitleInLMSPool() is calling getbyId\n" if $debugIt;
        $result = $pool->getbyId(\@EKZIDList);

        if ( $result->{'count'} > 0 ) {
            $foundInPool = 1;
        }
    }
    
    if($foundInPool == 0) {
        my $searchIsbn = (defined $selIsbn && length($selIsbn) > 0);
        my $searchIsbn13 = (defined $selIsbn13 && length($selIsbn13) > 0);
        
        if($searchIsbn || $searchIsbn13) {
			# search by ISBN
			my @ISBNList = ();
            if($searchIsbn) {
                push @ISBNList, $selIsbn;
            }
            if($searchIsbn13) {
                push @ISBNList, $selIsbn13;
            }
print STDERR "EkzKohaRecords::readTitleInLMSPool() is calling getbyISBN\n" if $debugIt;
            $result = $pool->getbyISBN(\@ISBNList);

            if ( $result->{'count'} > 0 ) {
                $foundInPool = 2;
            }
        }
    }
    
    if($foundInPool == 0) {
        # search in MARC fields 22/24 for ISSN / ISMN / EAN
        my @standardIdentifierList = ();
        if(defined $selIssn && length($selIssn) > 0) {
               push @standardIdentifierList, $selIssn;
        }
        if(defined $selIsmn && length($selIsmn) > 0) {
               push @standardIdentifierList, $selIsmn;
        }
        if(defined $selEan && length($selEan) > 0) {
               push @standardIdentifierList, $selEan;
        }
        if ( @standardIdentifierList > 0 ) {
print STDERR "EkzKohaRecords::readTitleInLMSPool() is calling getbyIdentifierStandard\n" if $debugIt;
            $result = $pool->getbyIdentifierStandard(\@standardIdentifierList);

            if ( $result->{'count'} > 0 ) {
                $foundInPool = 3;
            }
        }
    }

print STDERR "EkzKohaRecords::readTitleInLMSPool() selEkzArtikelNr:", $selEkzArtikelNr, ": selIsbn:",$selIsbn,": selIsbn13:",$selIsbn13,": foundInPool:",$foundInPool,":\n" if $debugIt;
print STDERR "EkzKohaRecords::readTitleInLMSPool() result->{'count'}:$result->{'count'}:\n" if $debugIt;
    return $result;
}


##############################################################################
#
# read title data using ekz web service MedienDaten, selected by ekzArtikelNr
#
##############################################################################
sub readTitleFromEkzWsMedienDaten {
	my $class = shift;
    my $ekzArtikelNr = shift;
    
	my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    my $result = $ekzwebservice->callWsMedienDaten($ekzArtikelNr);
print STDERR "EkzKohaRecords::readTitleFromEkzWsMedienDaten() result->{'count'}:$result->{'count'}:\n" if $debugIt;
print STDERR "EkzKohaRecords::readTitleFromEkzWsMedienDaten() result->{'records'}:$result->{'records'}:\n" if $debugIt;

    return $result;
}


##############################################################################
#
# read title data from a Z39.50 target using Z39.50 search selected by ISBN, ISSN or EAN
#
##############################################################################
sub readTitleFromZ3950Target {
	my $class = shift;
    my ($z3950kohaservername, $reqParamTitelInfo) = @_;

    my $selIsbn13 = $reqParamTitelInfo->{'isbn13'};
    my $selIssn = $reqParamTitelInfo->{'issn'};
    my $selEan = $reqParamTitelInfo->{'ean'};
    my @id = ();   # for z3950servers.id of the configured z39.50 connection to DNB
    my $params;
    my $result = { 'count' => 0, 'records' => [] };
    my $errors = [];
    my $dbh = C4::Context->dbh;

print STDERR "EkzKohaRecords::readTitleFromZ3950Target() z3950kohaservername:$z3950kohaservername: selIsbn13:$selIsbn13: selIssn:$selIssn: selEan:$selEan:\n" if $debugIt;
    if ( defined($selIsbn13) && length($selIsbn13) > 0 ||
         defined($selIssn) && length($selIssn) > 0 ||
         defined($selEan) && length($selEan) > 0 ) {
        my $sth = $dbh->prepare("select * from z3950servers where servername=?");
        $sth->execute($z3950kohaservername);
        while ( my $server = $sth->fetchrow_hashref ) {
            push @id, $server->{id};
        }

        # It seems that the (non empty only) conditions are 'ored', not 'anded'.
        $params = {
            biblionumber => '',
            id => \@id,          # Z39.50 target ID
            isbn => '',
            issn => '',
            title => '',
            author => ''
        };
        if ( defined($selIsbn13) && length($selIsbn13) > 0 ) {
            $params->{'isbn'} = $selIsbn13;
print STDERR "EkzKohaRecords::readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: isbn:$params->{'isbn'}:\n" if $debugIt;
            C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
            $params->{'isbn'} = '';
        }
        if ( $result->{'count'} == 0 && defined($selIssn) && length($selIssn) > 0 ) {
            $params->{'issn'} = $selIssn;
print STDERR "EkzKohaRecords::readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: issn:$params->{'issn'}:\n" if $debugIt;
            C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
            $params->{'issn'} = '';
        }
        if ( $result->{'count'} == 0 && defined($selEan) && length($selEan) > 0 ) {
            $params->{'ean'} = $selEan;    # effective for zed search only, not for sru search
print STDERR "EkzKohaRecords::readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: ean:$params->{'ean'}:\n" if $debugIt;
            C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
            $params->{'ean'} = '';
            if ( $result->{'count'} == 0 ) {
                $params->{'isbn'} = $selEan;    # last resort for sru targets: search ean value as isbn
print STDERR "EkzKohaRecords::readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: ean value as isbn:$params->{'isbn'}:\n" if $debugIt;
                C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
                $params->{'isbn'} = '';
            }
        }
    }
print STDERR "EkzKohaRecords::readTitleFromZ3950Target() result->{'count'}:$result->{'count'}:\n" if $debugIt;
print STDERR "EkzKohaRecords::readTitleFromZ3950Target() result->{'records'}:$result->{'records'}:\n" if $debugIt;
if ( $debugIt ) {
    foreach my $error (@{$errors}) {
print STDERR "EkzKohaRecords::readTitleFromZ3950Target() error:", Dumper($error), ":\n";
    }
}

    return $result;
}


##############################################################################
#
# take title data from the few fields of request titelinfo
#
##############################################################################
sub createTitleFromFields {
	my $class = shift;
    my ($reqParamTitelInfo) = @_;
    # potential keys of $reqParamTitelInfo:
    # 'ekzArtikelNr'
    # 'ekzArtikelArt'
    # 'ekzVerkaufsEinheitsNr'
    # 'ekzSystematik'
    # 'nonBookBestellCode'
    # 'ekzInteressenKreis'
    # 'StOkennung'
    # 'StOklartext'
    # 'fortsetzung'
    # 'urn'
    # 'isbn'
    # 'isbn13'
    # 'issn'
    # 'ismn'
    # 'ean'      # with web service StoList and LieferscheinDetail
    # 'author'
    # 'titel'
    # 'verlag'
    # 'erscheinungsJahr'
    # 'auflage'

	my $result = { 'count' => 0, 'records' => [] };
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $lasttransaction = sprintf("%04d%02d%02d%02d%02d%02d.0",1900+$year,1+$mon,$mday,$hour,$min,$sec);
    my $preisStored = 0;
    my $marcrecord =  MARC::Record->new();

    $marcrecord->MARC::Record::encoding( 'UTF-8' );
    $marcrecord->insert_fields_ordered(MARC::Field->new('001', $reqParamTitelInfo->{'ekzArtikelNr'}));
    $marcrecord->insert_fields_ordered(MARC::Field->new('003', "DE-Rt5"));
    $marcrecord->insert_fields_ordered(MARC::Field->new('005', $lasttransaction));

    # get values for fields 000, 006, 007, 008 depending on ekzArtikelArt:
    my $f06lead           = 'a';
    my $f06rest           = '|||||||||||||||||';
    my $field007content   = 'tu';
    my $f08CF26           = '|';
    my $f08VM33           = '|';
    my $field008val06     = 'n';
    my $field008val07to10 = 'uuuu';
    my $field008val11to14 = 'uuuu';
    my $fieldval11to14    = 'uuuu';
    my $lead19            = ' ';
    my $ltype             = 'a';
    my $lbib              = 'm';
    my $marcLanguageCode  = 'ger';

    if ( $reqParamTitelInfo->{'ekzArtikelArt'} eq 'A' ) {         # ekz: DVD (we take this as movie DVD)
        $f06lead = 'g';
        $f06rest = '|||||||||||s|||m|';
        $field007content = 'vz||v||||';
        $ltype = 'g';
        $lbib = "m";

    } elsif ( $reqParamTitelInfo->{'ekzArtikelArt'} eq 'B' ) {    # ekz: Bücher (we take this as books)
        $f06lead = 'a';
        $f06rest = '|||||||||||||||||';
        $field007content = 'tu';
        $ltype = 'a';
        $lbib = "m";
        $lead19 = ' ';

    } elsif ( $reqParamTitelInfo->{'ekzArtikelArt'} eq 'C' ) {    # ekz: CD (we take this as music audio CD or as audio book)
        # CD-DA (music)    # not used
        #$f06lead = 'j';
        #$f06rest = '|||||||||||||||||';
        #$field007content = 'sz||||||||||||';
        #$ltype = 'j';
        #$lbib = "m";

        # CD Novel (sound)
        $f06lead = 'i';
        $f06rest = '|||||||||||||||||';
        $field007content = 'sz||||||||||||';
        $ltype = 'i';
        $lbib = "m";

        # CD-ROM Novel (computer file)    # not used
        #$f06lead = 'm';
        #$f06rest = '||||||||h||||||||';
        #$field007content = 'cd ||||||||';
        #$ltype = 'm';
        #$lbib = "m";

    } elsif ( $reqParamTitelInfo->{'ekzArtikelArt'} eq 'M' ) {    # ekz: interaktive Medien (we take this as PC files)
        $ltype = 'm';
        $f06lead = 'm';
        $field007content = 'cc';
        $f08CF26 = 'u';

    } elsif ( $reqParamTitelInfo->{'ekzArtikelArt'} eq 'S' ) {    # ekz: Spiele (we take this as standard games)
        # Spiel (Mixed materials)
        $f06lead = 'p';
        $f06rest = '|||||||||||||||||';
        $field007content = 'zu';
        $ltype = 'p';
        $lbib = "m";

        # Spiele (Visual material; Type of visual material: legal article) # deactivated, worse than Mixed materials alternative
        #$f06lead = 'r';
        #$f06rest = '|||||||||||||||g|';
        #$ltype = 'r';
        #$f08VM33 = 'g';

    } elsif ( $reqParamTitelInfo->{'ekzArtikelArt'} eq 'V' ) {    # ekz: Videos (we take this as movie video cassettes)
        $f06lead = 'g';
        $f06rest = '|||||||||||||||m|';
        $field007content = 'vf';
        $ltype = 'g';
        $lbib = "m";
    }

    my $leader =    "     ".    #00-04 lenh
                    "c".        #05
                    $ltype.     #06
                    $lbib.      #07
                    " ".        #08 specify not type of control
                    "a".        #09 Unicode encoding
                    "2".        #10
                    "2".        #11
                    "     ".    #12-16 base address of data
                    " ".        #17 full encoding level
                    "u".        #18 unknown descriptive cataloging form
                    $lead19.    #19 not specified multipart resource record level
                    "4".        #20 length of the length-of-field portion
                    "5".        #21 length of the starting-character-position portion
                    "0".        #22 length of the implementation-defined portion
                    "0";        #23 always set to 0

    $marcrecord->leader($leader);

    my $f08y = sprintf("%02d",$year % 100);
    my $f08d = sprintf("%02d",$mday);
    my $f08m = sprintf("%02d",1+$mon);
    if ( $f08VM33 ne '|' && length($f06rest)>= 16 && substr($f06rest,15,1) eq '|'  ) {
        substr($f06rest,15,1) = $f08VM33;
    }
    if ( $f08CF26 ne '|' && length($f06rest)>= 16 && substr($f06rest,8,1) eq '|'  ) {
        substr($f06rest,8,1) = $f08CF26;
    }

    my $f08full = $f08y.$f08m.$f08d.$field008val06.$field008val07to10.$field008val11to14.'gw '. $f06rest . $marcLanguageCode . "||";

    $marcrecord->insert_fields_ordered( MARC::Field->new("006",$f06lead.$f06rest));
    $marcrecord->insert_fields_ordered( MARC::Field->new("007",$field007content));
    $marcrecord->insert_fields_ordered( MARC::Field->new("008",$f08full));


    my $isnLastStored = '';
    foreach my $isn ('isbn13', 'isbn', 'ean', 'ismn') {
        if ( defined($reqParamTitelInfo->{$isn}) && length($reqParamTitelInfo->{$isn}) > 0 ) {
            my $fieldno = '020';    # fits isbn, isbn13
            if ( $isn eq 'ean' || $isn eq 'ismn' ) {
                $fieldno = '024';
            }
            my $ind1 = ' ';    # fits isbn, isbn13
            if ( $isn eq 'ean' ) {
                $ind1 = '3';
            } elsif ( $isn eq 'ismn' ) {
                $ind1 = '2';
            }
            my $marcfield02x = MARC::Field->new($fieldno,$ind1,' ','a' => $reqParamTitelInfo->{$isn});    # field 020 or 024
            if ( !$preisStored && defined($reqParamTitelInfo->{'preis'}) && length($reqParamTitelInfo->{'preis'}) > 0 ) {
                $marcfield02x->add_subfields( 'c' => 'EUR ' . $reqParamTitelInfo->{'preis'} );
                $preisStored = 1;
            }
            if ( ($isn eq 'isbn' && $isnLastStored eq 'isbn13') || ($isn eq 'ismn' && $isnLastStored eq 'ean') ) {
                $marcrecord->insert_fields_after($marcrecord->field($fieldno),$marcfield02x);
            } else {
                $marcrecord->insert_fields_ordered($marcfield02x);
            }
            $isnLastStored = $isn;
        }
    }
    $marcrecord->insert_fields_ordered(MARC::Field->new('022',' ',' ','a' => $reqParamTitelInfo->{'issn'})) if ( defined($reqParamTitelInfo->{'issn'}) && length($reqParamTitelInfo->{'issn'}) > 0 );
    $marcrecord->insert_fields_ordered(MARC::Field->new('040',' ',' ','c' => "DE-Rt5"));
    $marcrecord->insert_fields_ordered(MARC::Field->new('100','1',' ','a' => $reqParamTitelInfo->{'author'})) if ( defined($reqParamTitelInfo->{'author'}) && length($reqParamTitelInfo->{'author'}) > 0 );
    my $marcfield245;
    if ( defined($reqParamTitelInfo->{'titel'}) && length($reqParamTitelInfo->{'titel'}) > 0 ) {
        $marcfield245 = MARC::Field->new('245','0','0','a' => $reqParamTitelInfo->{'titel'});
    }
    if ( defined($reqParamTitelInfo->{'author'}) && length($reqParamTitelInfo->{'author'}) > 0 ) {
        if ( !defined($marcfield245) ) {
            $marcfield245 = MARC::Field->new('245','0','0','c' => $reqParamTitelInfo->{'author'});
        } else {
            $marcfield245->add_subfields( 'c' => $reqParamTitelInfo->{'author'} );
        }
    }
    if ( defined($marcfield245) ) {
        $marcrecord->insert_fields_ordered($marcfield245);
    }
    $marcrecord->insert_fields_ordered(MARC::Field->new('250',' ',' ','a' => $reqParamTitelInfo->{'auflage'})) if ( defined($reqParamTitelInfo->{'auflage'}) && length($reqParamTitelInfo->{'auflage'}) > 0 );
    my $marcfield260;
    if ( defined($reqParamTitelInfo->{'verlag'}) && length($reqParamTitelInfo->{'verlag'}) > 0 ) {
        $marcfield260 = MARC::Field->new('260',' ',' ','b' => $reqParamTitelInfo->{'verlag'});    # DNB uses 264 3 1 b
    }
    if ( defined($reqParamTitelInfo->{'erscheinungsJahr'}) && length($reqParamTitelInfo->{'erscheinungsJahr'}) > 0 ) {
        if ( !defined($marcfield260) ) {
            $marcfield260 = MARC::Field->new('260',' ',' ','c' => $reqParamTitelInfo->{'erscheinungsJahr'});
        } else {
            $marcfield260->add_subfields( 'c' => $reqParamTitelInfo->{'erscheinungsJahr'} );    # DNB uses 264 3 1 c
        }
    }
    if ( defined($marcfield260) ) {
        $marcrecord->insert_fields_ordered($marcfield260);
    }
    #$marcrecord->insert_fields_ordered(MARC::Field->new('490','0',' ','a' => $reqParamTitelInfo->{'titel'} . " / " . $reqParamTitelInfo->{'author'})) if ( defined($reqParamTitelInfo->{'titel'}) && length($reqParamTitelInfo->{'titel'}) > 0 && defined($reqParamTitelInfo->{'author'}) && length($reqParamTitelInfo->{'author'}) );

print STDERR "EkzKohaRecords::createTitleFromFields() marcrecord:", $marcrecord, ":\n" if $debugIt;
print STDERR "EkzKohaRecords::createTitleFromFields() marcrecord:", Dumper( $marcrecord ) if $debugIt;
    if ( $marcrecord ) {
        push @{$result->{'records'}}, $marcrecord;
        $result->{'count'} += 1;
    }

	return $result;
}


sub checkbranchcode {
    my ( $branchcode ) = @_;

    # we reread the branches only after 16 calls
    $callCounter += 1;
    if ( $callCounter > 16 ) {
        %branchnames = ();
        $callCounter = 0;
    }

    if ( keys %branchnames == 0 ) {
        my $branches = C4::Branch::GetBranches();
        foreach my $brcode (sort keys %$branches) {
            my $brcodeN = $brcode;
            $brcodeN =~ s/^\s+|\s+$//g; # trim spaces
            $branchnames{$brcodeN} = $branches->{$brcode}->{'branchname'};
print STDERR "EkzKohaRecords::checkbranchname branchnames{", $brcodeN, "} = ", $branchnames{$brcodeN}, ":\n" if $debugIt;
        }
    }
    $branchcode =~ s/^\s+|\s+$//g; # trim spaces
    my $ret = defined $branchnames{$branchcode};

print STDERR "EkzKohaRecords::checkbranchcode branchcode:", $branchcode, ": returns:", $ret, ":\n" if $debugIt;
    return $ret;
}


##############################################################################
#
# create a short ISBD description of the title for the e-mail
#
##############################################################################
sub getShortISBD {
	my $class = shift;
    my $Koharecord = shift;

    my $field = $Koharecord->field('245');
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
    
    $field = $Koharecord->field('250');
    if ( $field ) {
        my $edition = $field->subfield('a');
    
        if ( $edition ) {
            $titleblock .= ' - ' . $edition;
            if ( $titleblock !~ /\.$/ ) {
                $titleblock .= '.';
            } 
        }
    }
    
    $field = $Koharecord->field('260');
    if (! defined($field) ) {
        $field = $Koharecord->field('264');
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
    if ( $titleblock ) {
        $titleblock =~ s/[\x{0098}\x{009c}]//g;
    }
    
    my $identifier = '';
    $field = $Koharecord->field('020');
    if ( $field ) {
        my $isbn = $field->subfield('a');
        eval {
            my $val = Business::ISBN->new($isbn);
            $isbn = $val->as_isbn13()->as_string([]);
        };
        $identifier = $isbn;
    }
    $field = $Koharecord->field('024');
    if ( $field && ((! defined($identifier)) || $identifier eq '') ) {
        my $ean = $field->subfield('a');
        $identifier = $ean;
    }
    return ($titleblock,$identifier);
}

##############################################################################
#
# Create and format a processing message
#
##############################################################################
sub createProcessingMessageText {
	my $class = shift;
    my $logresult = shift;
    my $header = shift;
    my $dt = shift;
    my $importIDs  = shift;
    my $ekzBestellOrLsNr = shift;

    my $message = '';
    my $haserror = 0;

    # offset in actionstep
    my $actTxt = 0;     # action text
    my $actRes = 1;     # action result 
    my $loadMsg = 2;    # message of loading
    my $loadErr = 3;    # error of loading
    my $prcTC = 4;      # processedTitlesCount
    my $impTC = 5;      # importedTitlesCount
    my $fndTC = 6;      # foundTitlesCount
    my $prcIC = 7;      # processedItemsCount
    my $impIC = 8;      # importedItemsCount
    my $updIC = 9;      # updatedItemsCount
    my $iRecords = 10;  # @records

    my $libraryName = C4::Context->preference("LibraryName");
    my $kohaInstanceName = C4::External::EKZ::EkzAuthentication::kohaInstanceName();
    my $kohaInstanceUrl = 'https://' . $kohaInstanceName . '-lms.lmscloud.net';
    my $envKohaInstanceUrl =  $ENV{'KOHAINSTANCEURL'};    # for test in development environment
    if ( defined($envKohaInstanceUrl) && length($envKohaInstanceUrl) ) {
        $kohaInstanceUrl = $envKohaInstanceUrl;
    }
    my $printdate =  $dt->dmy('.') . ' um ' . sprintf("%02d:%02d Uhr", $dt->hour, $dt->minute);
print STDERR "EkzKohaRecords::createProcessingMessageText() printdate:$printdate: Anz. logresult:", @{$logresult}+0, ": importIDs->[0]:$importIDs->[0]: ekzBestellOrLsNr:$ekzBestellOrLsNr:\n" if $debugIt;
    
    my $subject = "Import ekz Bestellung $ekzBestellOrLsNr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
        $subject = "Import ekz Lieferschein $ekzBestellOrLsNr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
        $subject = "Import ekz standing-order-Titel $ekzBestellOrLsNr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    } else {    # eq 'BestellInfo'
        $subject = "Import ekz Bestellung $ekzBestellOrLsNr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    }
    
    $message .= '<!DOCTYPE html>'."\n";
    $message .= '<html xmlns="http://www.w3.org/1999/xhtml">'."\n";
    $message .= '<head>'."\n";
    $message .= '<title>'."\n";
    if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
        $message .= '    '. h("Ergebnisse Import ekz Lieferschein $ekzBestellOrLsNr ($libraryName)") . "\n";
    } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
        $message .= '    '. h("Ergebnisse Import ekz standing-order-Titel $ekzBestellOrLsNr ($libraryName)") . "\n";
    } else {    # eq 'BestellInfo'
        $message .= '    '. h("Ergebnisse Import ekz Bestellung $ekzBestellOrLsNr ($libraryName)") . "\n";
    }
    $message .= '</title>'."\n";
    $message .= '<style>'."\n";
    $message .= '
                    body {
                        font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
                        font-size: 12px;
                        line-height: 20px;
                        font-weight: 400;
                        color: #000;
                        margin: 15px;
                        -webkit-font-smoothing: antialiased;
                        font-smoothing: antialiased;
                        background: #fff;
                    }
                    
                    p,h1 { 
                        padding: 1px 8px; 
                        font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
                    }
                    
                    h1 {
                        line-height: 30px;
                    }

                    table
                    {
                        font-size: 12px;
                        background: #fff;
                        border-collapse: collapse;
                        text-align: left;
                    }
                    th
                    {
                        font-weight: normal;
                        color: #000; 
                        padding: 10px 8px;
                        border-bottom: 2px solid #6678b1;
                        vertical-align: top;
                        text-align: left;
                    }
                    td
                    {
                        border-bottom: 1px solid #ccc;
                        color: #000;
                        padding: 6px 8px;
                        vertical-align: top;
                        text-align: left;
                    }
                    td a {
                        color: #000;
                    }
                    tbody tr:hover td
                    {
                        color: #009;
                    }

                    tr:nth-child(even) td { background: #F6F6F6; }
                    
                    img {
                        max-width: 150px;
                        padding: 0px 8px; 
                    }
                    '."\n";
    $message .= '</style>'."\n";
    $message .= '</head>'."\n";
    
    my $processedTitlesCount = 0;
    my $importedTitlesCount = 0;
    my $foundTitlesCount = 0;
    my $processedItemsCount = 0;
    my $importedItemsCount = 0;
    my $updatedItemsCount = 0;
print STDERR "EkzKohaRecords::createProcessingMessageText() logresult:", $logresult,":\n" if $debugIt;
print STDERR Dumper( $logresult ) if $debugIt;
    foreach my $result (@$logresult) {
print STDERR "EkzKohaRecords::createProcessingMessageText() printdate:$printdate: result->[0]:$result->[0]: Anz. result->[2]:", @{$result->[2]}+0, ": importIDs->[0]:$importIDs->[0]: ekzBestellOrLsNr:$ekzBestellOrLsNr:\n" if $debugIt;
print STDERR "EkzKohaRecords::createProcessingMessageText() result:", $result,":\n" if $debugIt;
print STDERR Dumper( $result ) if $debugIt;
        my @actionsteps = @{$result->[2]};
        my @records = ();
        foreach my $action (@actionsteps) {
print STDERR "EkzKohaRecords::createProcessingMessageText() action->[$actTxt]:", $action->[$actTxt],":\n" if $debugIt;
print STDERR "EkzKohaRecords::createProcessingMessageText() action->[$actRes]:", $action->[$actRes],":\n" if $debugIt;
print STDERR "EkzKohaRecords::createProcessingMessageText() action->[$impTC]:", $action->[$impTC],":\n" if $debugIt;
print STDERR "EkzKohaRecords::createProcessingMessageText() action:", $action,":\n" if $debugIt;
print STDERR Dumper( $action ) if $debugIt;
            if ( $action->[$actTxt] eq 'insertRecords' ) {
                $processedTitlesCount += $action->[$prcTC];
                $importedTitlesCount  += $action->[$impTC];
                $foundTitlesCount  += $action->[$fndTC];
                $processedItemsCount += $action->[$prcIC];
                $importedItemsCount  += $action->[$impIC];
                $updatedItemsCount  += $action->[$updIC];
                @records = @{$action->[$iRecords]};
            }
            if ( $action->[$actRes] != 0 ) {
                $haserror = 1;
            }
            if ( scalar(@records) > 0 ) {
                foreach my $record (@records) {
                    if ( !($record->[2] == 1 || $record->[2] == 2) || $record->[6] == 1 ) {
                        $haserror = 1;
                    }
                }
            }
        }
    }
    
    $message .= '<body>'."\n";
    $message .= '<img src="https://orgaknecht.lmscloud.net/lmscloud_logo_horizontal_486_klein.png" alt="LMSCloud Logo" />'."\n";
    if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
        $message .= '<h1>' . h("Ergebnisse Import ekz Lieferschein $ekzBestellOrLsNr ($libraryName)") .' </h1>'."\n";
        $message .= '<p>' . h('Datum: ' .  $printdate. ', LieferscheinDetail-Response messageID: ' . $logresult->[0]->[1]);
    } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
        $message .= '<h1>' . h("Ergebnisse Import ekz standing-order-Titel $ekzBestellOrLsNr ($libraryName)") .' </h1>'."\n";
        $message .= '<p>' . h('Datum: ' .  $printdate. ', StoList-Response messageID: ' . $logresult->[0]->[1]);
    } else {    # eq 'BestellInfo'
        $message .= '<h1>' . h("Ergebnisse Import ekz Bestellung $ekzBestellOrLsNr ($libraryName)") .' </h1>'."\n";
        $message .= '<p>' . h('Datum: ' .  $printdate. ', BestellInfo-Request messageID: ' . $logresult->[0]->[1]);
    }
    if ( $importedTitlesCount + $foundTitlesCount > 0 and scalar @{$importIDs} > 0 ) {
        my $controlNumberQuery = '';
        my $controlNumberCnt = 0;
        my $orderQuery = '';
        my $orderCnt = 0;
        my $allQuery = '';
        foreach my $importID (@{$importIDs}) {
print STDERR "EkzKohaRecords::createProcessingMessageText() importID:", $importID, ":\n" if $debugIt;
            if ( $importID =~ /^\(ControlNumber\)(\d+)\(ControlNrId\)(.*)$/s ) {
                if ( length($controlNumberQuery) > 0 ) {
                    $controlNumberQuery .= " or ";
                }
                $controlNumberQuery .= '(cn%3A%22' . $1 . '%22 and cna%3A%22' . $2 . '%22)';    # i.e. '(cn:"' . $1 . '" and cna:"' . $2 . '")'
                $controlNumberCnt += 1;
            } elsif ( $importID =~ /^\(ControlNumber\)(\d+)$/s ) {
                if ( length($controlNumberQuery) > 0 ) {
                    $controlNumberQuery .= " or ";
                }
                $controlNumberQuery .= '(cn%3A%22' . $1 . '%22)';    # i.e. '(cn:"' . $1 . '")'
                $controlNumberCnt += 1;
            } else {
                if ( length($orderQuery) > 0 ) {
                    $orderQuery .= ' or ';
                }
                $orderQuery .= '(Other-control-number%3A%22' . $importID . '%22)';    # i.e. '(Other-control-number:"' . $importID . '")'
                $orderCnt += 1;
            }
        }
        if ( length($orderQuery) > 0 ) {
            if ( length($controlNumberQuery) > 0 ) {
                $allQuery = $orderQuery . ' or ' . $controlNumberQuery;
            } else {
                $allQuery = $orderQuery;
            }
        } elsif ( length($controlNumberQuery) > 0 ) {
            $allQuery = $controlNumberQuery;
        }
print STDERR "EkzKohaRecords::createProcessingMessageText() controlNumberCnt:", $controlNumberCnt, ": controlNumberQuery:", $controlNumberQuery, ": orderCnt:", $orderCnt, ": orderQuery:", $orderQuery, ":\n" if $debugIt;
        ## link to all handled titles
        #if ( $orderCnt > 1 || ($orderCnt > 0 && $controlNumberCnt > 0) ) {
        #    $message .=  '<br />' . '<a href="' . $kohaInstanceUrl . '/cgi-bin/koha/catalogue/search.pl?q=' . $allQuery . '">' . h("Link auf alle bearbeiteten Titel") . '</a>';
        #}
        ## links to handled titles grouped by order number 
        #foreach my $importID (@{$importIDs}) {
        #    my $orderNr = '';
        #    if ( $importID =~ /^\(EKZImport\)([\w\d]+)$/s ) {
        #        $orderNr = $1;
        #    } else {
        #        next;
        #    }
        #    $message .= '<br />' . '<a href="' . $kohaInstanceUrl . '/cgi-bin/koha/catalogue/search.pl?q=Other-control-number%3A%28EKZImport%29' . $orderNr . '">' . h("Link auf alle bearbeiteten Titel der Bestellung $orderNr") . '</a>';
        #}
        ## link to all handled titles without order number (or from stoList or LieferscheinDetail)
        if ( $controlNumberCnt > 0 ) {
            #my $messText = "Link auf alle bearbeiteten Titel ohne Bestellzuordnung";    # default for BestellInfo
            my $messText = "Link auf alle bearbeiteten Titel";    # default for BestellInfo
            if ( $logresult->[0]->[0] eq 'StoList' || $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
                $messText = "Link auf alle bearbeiteten Titel";
            }            
            $message .= '<br />' . '<a href="' . $kohaInstanceUrl . '/cgi-bin/koha/catalogue/search.pl?q=' . $controlNumberQuery . '">' . h($messText) . '</a>';
        }
    }
    $message .= '</p>'."\n";
    $message .= '<p>';
    if ( $processedTitlesCount == 0 ) {
        if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
            $message .= h("Beim Import des ekz Lieferscheins " . $ekzBestellOrLsNr . " trat ein Probleme auf. Es wurden keine Titeldaten erkannt.");
        } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
            $message .= h("Beim Import der ekz standing-order-Titel " . $ekzBestellOrLsNr . " trat ein Probleme auf. Es wurden keine Titeldaten erkannt.");
        } else {    # eq 'BestellInfo'
            $message .= h("Beim Import der ekz Bestellung " . $ekzBestellOrLsNr . " trat ein Probleme auf. Es wurden keine Titeldaten erkannt.");
        }
    } else {
        if ( $haserror ) {
            if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
                $message .= h("Beim Import des ekz Lieferscheins " . $ekzBestellOrLsNr . " traten Probleme auf. Details sind der folgenden Liste zu entnehmen.");
            } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
                $message .= h("Beim Import der ekz standing-order-Titel " . $ekzBestellOrLsNr . " traten Probleme auf. Details sind der folgenden Liste zu entnehmen.");
            } else {    # eq 'BestellInfo'
                $message .= h("Beim Import der ekz Bestellung " . $ekzBestellOrLsNr . " traten Probleme auf. Details sind der folgenden Liste zu entnehmen.");
            }
        } else {
            if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
                $message .= h("Die Titel- und Exemplardaten des ekz Lieferscheins " . $ekzBestellOrLsNr . " wurden komplett übernommen. Details sind der folgenden Liste zu entnehmen.");
            } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
                $message .= h("Die aktualisierten Titel- und Exemplardaten der ekz standing-order " . $ekzBestellOrLsNr . " wurden komplett übernommen. Details sind der folgenden Liste zu entnehmen.");
            } else {    # eq 'BestellInfo'
                $message .= h("Die Titel- und Exemplardaten zur ekz Bestellung " . $ekzBestellOrLsNr . " wurden komplett übernommen. Details sind der folgenden Liste zu entnehmen.");
            }
        }
    }
    $message .= '<p>'."\n";

    $message .= '<table>'."\n";
    foreach my $result (@$logresult) {
        my $file = $result->[0];
        my $messageID = $result->[1];
        my @actionsteps = @{$result->[2]};
        my @records = ();
        my ($loaderr,$loadmsg);
        
        $message .= '    <tr class="messageheader">'."\n";
        $message .= '        <th colspan="6">'."\n";
        if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
            $message .= '           <span class="import-result-field">Ergebnis:</span> <span class="import-result">' . 'Von ' . $processedTitlesCount . ' Titeln wurden ' . $importedTitlesCount . ' importiert und ' . $foundTitlesCount . ' aktualisiert; von ' . $processedItemsCount . ' Exemplaren wurden ' . $importedItemsCount . ' importiert und ' . $updatedItemsCount . ' aktualisiert. </span><br />'."\n";
        } else {    # eq 'BestellInfo' || eq 'StoList'
            $message .= '           <span class="import-result-field">Ergebnis:</span> <span class="import-result">' . 'Von ' . $processedTitlesCount . ' Titeln wurden ' . $importedTitlesCount . ' importiert und ' . $foundTitlesCount . ' aktualisiert; von ' . $processedItemsCount . ' Exemplaren wurden ' . $importedItemsCount . ' importiert. </span><br />'."\n";
        }
        $message .= '        </th>'."\n";
        $message .= '    </tr>'."\n";

        if ( scalar(@actionsteps) > 0 ) {
        
            $message .= '    <tr class="recordheader">'."\n";
            $message .= '        <th>'."\n";
            $message .= '            Lfd. Nr.'."\n";
            $message .= '        </th>'."\n";

            $message .= '        <th>'."\n";
            $message .= '            EKZ-Artikelnr.'."\n";
            $message .= '        </th>'."\n";

            $message .= '        <th>'."\n";
            $message .= '            Titel'."\n";
            $message .= '        </th>'."\n";

            $message .= '        <th>'."\n";
            $message .= '            Status'."\n";
            $message .= '        </th>'."\n";

            $message .= '        <th>'."\n";
            $message .= '            Information'."\n";
            $message .= '        </th>'."\n";
            $message .= '    </tr>'."\n";
        }
        
        my $i = 1;    # $i enumerates titles
        foreach my $action (@actionsteps) {
            if ( $action->[$actTxt] eq 'insertRecords' ) {
                @records = @{$action->[$iRecords]};
                $loadmsg = $action->[$loadMsg];
                $loaderr = $action->[$loadErr];
            }

            if ( scalar(@records) > 0 ) {
                
                for ( my $j = 0; $j < scalar(@records); $j++ ) {
                    my $record = $records[$j];
                    
                    # fields if title: [$recordId,$biblionumber,$importresult,$titeldata,$isbnean,$problems]
                    # fields if item:  [$recordId,$ekzItemNumber,$importresult,$titeldata,$isbnean,$problems]
                    
                    if ( $record->[7] == 1 ) {    # title data
                        $message .= '    <tr class="recordresult">'."\n";

                        # Lfd. Nr.
                        $message .= '        <td>'."\n";
                        $message .= '            '. $i . "\n";
                        $message .= '        </td>'."\n";

                        # EKZ-Artikelnr.
                        $message .= '        <td>'."\n";
                        $message .= '            '. h($record->[0]) . "\n";
                        $message .= '        </td>'."\n";

                        # Titel
                        $message .= '        <td>'."\n";
                        if ( $record->[2] != -1 ) {
                            $message .= '            <a href="' . $kohaInstanceUrl . '/cgi-bin/koha/catalogue/detail.pl?biblionumber='.$record->[1].'">'. h($record->[3]) . "</a>\n";
                        } else {
                            $message .= '            ' . h($record->[3]) . "\n";
                        }
                        $message .= '        </td>'."\n";

                        # Status
                        my $statusText = "nicht angelegt";
                        if ( $record->[2] == 2 ) {
                            $statusText = "vorhanden";
                        } elsif ( $record->[2] == 1 ) {
                            $statusText = "angelegt";
                        } elsif ( $record->[2] == -1 ) {
                            $statusText = "Fehler";
                        }
                        $message .= '        <td>'."\n";
                        $message .= '            '. h($statusText) . "\n";
                        $message .= '        </td>'."\n";

                        # Information
                        $message .= '        <td>'."\n";
                        if ( $record->[2] == 1 || $record->[2] == 2 ) {
                            if ( $logresult->[0]->[0] eq 'LieferscheinDetail' || $action->[$updIC] > 0 ) {
                                $message .= '            Von ' . $action->[$prcIC] . ' Exemplaren wurden ' . $action->[$impIC] . ' importiert und ' . $action->[$updIC] . ' aktualisiert.' . "\n";
                            } else {
                                $message .= '            Von ' . $action->[$prcIC] . ' Exemplaren wurden ' . $action->[$impIC] . ' importiert.' . "\n";
                            }
                        }
                        if ( length($record->[5]) > 0) {
                            if ( $record->[2] == 1 || $record->[2] == 2 ) {
                                $message .= '            <br />';
                            } else {
                                $message .= '            ';
                            }
                            $message .= h($record->[5]) . "\n";
                        }
                    } else {    # item data, to be added as new lines in the last column, not in additional table rows
                        if ( $j == 1 && $action->[$impIC] + $action->[$updIC] > 0 ) {    # loop is at the first item and item data for this title have been imported or updated
                            $message .= '            <br />' . 'Links zum Bearbeiten der Exemplardaten:'."\n";
                        }
                        if ( !($record->[2] == 1 || $record->[2] == 2) ) {    # item import/update error happened
                            $message .= '            <br />' . h($record->[5]) . "\n";
                        } else {
                            # e.g.: http://192.168.122.100:8080/cgi-bin/koha/cataloguing/additem.pl?op=edititem&biblionumber=68231&itemnumber=123915#edititem
                            $message .= '            <br /><a href="' . $kohaInstanceUrl . '/cgi-bin/koha/cataloguing/additem.pl?op=edititem&biblionumber=' . $record->[1] . '&itemnumber=' . $record->[3] . '#edititem' . '">' . h($record->[3]) . "</a>\n";
                        }
                    }
                    if ( $j == scalar(@records)-1 ) {    # last item of this title -> mark end of table column and table row
                        $message .= '        </td>'."\n";
                        $message .= '    </tr>'."\n";
                    }
                }
                $i++;
            }
            else {
                $message .= '    <tr class="errormessage">'."\n";
                $message .= '        <td colspan="6">'."\n";
                $message .= h('Fehler beim Import der EKZ-Bestellungsdaten für einen Titel: ') . h($loaderr);
                if ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
                    $message .= h('Fehler beim Import der ekz Lieferscheindaten für einen Titel: ') . h($loaderr);
                } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
                    $message .= h('Fehler beim Import der ekz standing-order-Daten für einen Titel: ') . h($loaderr);
                } else {    # eq 'BestellInfo'
                    $message .= h('Fehler beim Import der ekz Bestelldaten für einen Titel: ') . h($loaderr);
                }
                $message .= '        </td>'."\n";
                $message .= '    </tr>'."\n";
            }
        }
    }
    $message .= '</table>'."\n";
    $message .= '</body>'."\n";
    $message .= '</html>'."\n";
    
    return ($message, $subject, $haserror);
}

##############################################################################
#
# send the log message
#
##############################################################################
sub sendMessage {
	my $class = shift;
    my ($message, $subject) = @_;

    my $ekzAdminEmailAddress = C4::Context->preference("ekzProcessingNoticesEmailAddress");
    my $adminEmailAddress = C4::Context->preference("KohaAdminEmailAddress");
    if( !( defined $ekzAdminEmailAddress && length($ekzAdminEmailAddress) > 0 ) ) {
        $ekzAdminEmailAddress = $adminEmailAddress;
    }
    my $replyTo = C4::Context->preference("ReplytoDefault");
    
    my $email = Koha::Email->new();

    my %sendmailParams = $email->create_message_headers(
        {
            to          => $ekzAdminEmailAddress,
            from        => $adminEmailAddress,
            replyto     => $replyTo,
            sender      => $adminEmailAddress,
            subject     => $subject,
            message     => $message,
            contenttype => 'text/html; charset="UTF-8"'
        }
    );
print STDERR "EkzKohaRecords::sendMessage() sendmailParams:", %sendmailParams, ":\n" if $debugIt;
print STDERR Dumper( %sendmailParams ) if $debugIt;
    sendmail( %sendmailParams );
}

sub h {
    return (encode_entities(shift));
}

1;


