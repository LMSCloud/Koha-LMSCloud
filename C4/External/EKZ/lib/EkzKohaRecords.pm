package C4::External::EKZ::lib::EkzKohaRecords;

# Copyright 2017-2020 (C) LMSCLoud GmbH
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

use Encode qw(encode decode);
use utf8;
use Carp;
use Data::Dumper;
use HTML::Entities;
use Mail::Sendmail;
use Capture::Tiny 'capture_stdout';

use Koha::Email;
use MARC::Field;
use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );
use C4::Breeding qw(Z3950SearchGeneral);
use C4::External::EKZ::EkzAuthentication;
use C4::External::EKZ::lib::LMSPoolSRU;
use C4::External::EKZ::lib::EkzWsConfig;
use C4::External::EKZ::lib::EkzWebServices;
use C4::Context;
use C4::Biblio;
use Koha::Libraries;

use Koha::Schema::Result::Aqbudgetperiod;



binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

our $VERSION = '0.01';

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);


BEGIN {
    require Exporter;
    $VERSION = 1.00.00.000;
    @ISA = qw(Exporter);
    @EXPORT = qw();
}

sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    $self->{logger} = Koha::Logger->get({ interface => 'C4::External::EKZ::lib::EkzKohaRecords' });
    # get the systempreferences concerning ekz media services configuration for variing ekzKundenNr
    $self->{'ekzWsConfig'} = C4::External::EKZ::lib::EkzWsConfig->new();
    $self->{'branchnames'} = {};    # for caching the branch names

    $self->{localCatalogSourceDelegateClass} = undef;
    if ( C4::Context->preference("ekzTitleLocalCatalogSourceDelegateClass") ) {
        my $srcClass = C4::Context->preference("ekzTitleLocalCatalogSourceDelegateClass");
        my $src;
        # capture_stdout is used to avoid output to STDOUT, which would spoil the webservice response
        my $stdoutCaptured = capture_stdout {
            $src = eval("require $srcClass; 
                         import $srcClass; 
                         $srcClass->new()");
        };
        if ( $stdoutCaptured ) {
            $self->{'logger'}->error("new() message of srcClass->new() stdoutCaptured:$stdoutCaptured:");
        }
        if ( $src ) {
             $self->{localCatalogSourceDelegateClass} = $src;
        } 
    }

    return $self;
}

##############################################################################
#
# create new biblio record
#
##############################################################################
sub addNewRecord {
    my $self = shift;
    my $record = shift;

    my $biblionumber;
    my $biblioitemnumber;
        
    if ( $self->{localCatalogSourceDelegateClass} ) {
        my $localCat = $self->{localCatalogSourceDelegateClass};
        ($biblionumber,$record) = $localCat->addSingleRecord($record);
        $biblioitemnumber = $biblionumber;
    } else {
        ($biblionumber,$biblioitemnumber) = C4::Biblio::AddBiblio($record,'');
        if ( $biblionumber ) {
            $record = C4::Biblio::GetMarcBiblio( { biblionumber => $biblionumber } );
        }
    }

    return ($biblionumber,$biblioitemnumber,$record);
}


##############################################################################
#
# search title in local database by ekzArtikelNr or ISBN or ISSN/ISMN/EAN
#
##############################################################################
sub readTitleInLocalDB {
    my $self = shift;
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
    $self->{'logger'}->info("readTitleInLocalDB() selEkzArtikelNr:" . defined($selParam->{'ekzArtikelNr'}) ? $selParam->{'ekzArtikelNr'} : 'undef' .
                                               ": selIsbn:" . defined($selParam->{'isbn'}) ? $selParam->{'isbn'} : 'undef' .
                                               ": selIsbn13:" . defined($selParam->{'isbn13'}) ? $selParam->{'isbn13'} : 'undef' .
                                               ": selIssn:" . defined($selParam->{'issn'}) ? $selParam->{'issn'} : 'undef' .
                                               ": selIsmn:" . defined($selParam->{'ismn'}) ? $selParam->{'ismn'} : 'undef' .
                                               ": selEan:" . defined($selParam->{'ean'}) ? $selParam->{'ean'} : 'undef' .
                                               ": maxhits:" . defined($maxhits) ? $maxhits : 'undef' .
                                               ":");

    my $marcresults = $self->readTitleDubletten($selParam,1);
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
                if ( $self->isOnleiheItem($item) ) {
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
    $self->{'logger'}->debug("readTitleInLocalDB() result->{'count'}:$result->{'count'}: result->{'records'}:" . Dumper($result->{'records'}) . ":");

    return $result;
}


##############################################################################
#
# search title in local database by biblionumber
#
##############################################################################
sub readTitleInLocalDBByBiblionumber {
    my $self = shift;
    my $selBiblionumber = shift;
    my $maxhits = shift;

    my $result = {'count' => 0, 'records' => []};
    $self->{'logger'}->info("readTitleInLocalDBByBiblionumber() selBiblionumber:" . (defined($selBiblionumber)?$selBiblionumber:'undef') . ":");

    my $marcrecord = C4::Biblio::GetMarcBiblio( { biblionumber => $selBiblionumber, embed_items => 0 } );

    if ( $marcrecord && $maxhits > 0 ) {
        push @{$result->{'records'}}, $marcrecord;
        $result->{'count'} += 1;
    }
    $self->{'logger'}->debug("readTitleInLocalDBByBiblionumber() result->{'count'}:$result->{'count'}: result->{'records'}:" . Dumper($result->{'records'}) . ":");

    return $result;
}


##############################################################################
#
# test if the item's itype qualifies the title as Onleihe medium
#
##############################################################################
sub isOnleiheItem {
    my $self = shift;
    my ($item) = @_;
    my $ret = 0;

    $self->{'logger'}->debug("isOnleiheItem() item->{itype}:" . $item->{itype} . ":");

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
    my $self = shift;
    my ($marcresults1, $biblionumberhash, $marcresults2, $hitscntref) = @_;

    my $hits2 = 0;
    $hits2 = scalar @{$marcresults2} if $marcresults2;


    for (my $i = 0; $i < $hits2 and defined $marcresults2->[$i]; $i++)
    {
        my $marcrecord2;
        eval {
            $marcrecord2 =  MARC::Record::new_from_xml( $marcresults2->[$i], "utf8", 'MARC21' );
        };
        if ( $@ ) {
            my $mess = sprintf("mergeMarcresults: error in MARC::Record::new_from_xml:%s:", $@);
            $self->{'logger'}->warn($mess);
            carp "EkzKohaRecords::" . $mess . "\n";
        }

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
    my $self = shift;
    my $selParam = shift;
    my $strictMatch = shift;
    $self->{'logger'}->debug("readTitleDubletten() strictMatch:$strictMatch: selParam:" . Dumper($selParam) . ":");

    my $allmarcresults = [];
    if ( $self->{localCatalogSourceDelegateClass} ) {
        my $searchClass = $self->{localCatalogSourceDelegateClass};
        $allmarcresults = $searchClass->searchLocalRecords($selParam);
    } else {
        my $query = "cn:\"-1\"";                    # control number search, initial definition for no hit
        my $allinall_hits = 0;
        my %biblionumbersfound = ();
        # search priority:
        # 1. ekzArtikelNr
        # 2. isbn or isbn13
        # 3. issn or ismn or ean
        # 4. titel and author and erscheinungsJahr

        # check for ekzArtikelNr search
        if ( !defined $selParam->{'ekzArtikelNr'} || length($selParam->{'ekzArtikelNr'}) == 0 ) {
            my $mess = sprintf("readTitleDubletten(): ekzArtikelNr is empty -> not searching for ekzArtikelNr.");
            $self->{'logger'}->warn($mess);
            #carp "EkzKohaRecords::" . $mess . "\n";
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
            $self->{'logger'}->debug("readTitleDubletten() query:$query:");

            my ( $error, $marcresults, $total_hits ) = ( '', [], 0 );
            ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
            
            if (defined $error) {
                my $mess = sprintf("readTitleDubletten(): search for ekzArtikelNr:%s: returned error:%d/%s:", $selParam->{'ekzArtikelNr'}, $error, $error);
                $self->{'logger'}->warn($mess);
                carp "EkzKohaRecords::" . $mess . "\n";
            } else
            {
                $self->mergeMarcresults($allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
            }
            $self->{'logger'}->debug("readTitleDubletten() search total_hits:$total_hits: allinall_hits:$allinall_hits:");
        }

        # check for isbn/isbn13 search
        if ( (!defined $selParam->{'isbn'} || length($selParam->{'isbn'}) == 0) && 
             (!defined $selParam->{'isbn13'} || length($selParam->{'isbn13'}) == 0) ) {
            my $mess = sprintf("readTitleDubletten(): isbn and isbn13 are empty -> not searching for isbn or isbn13.");
            $self->{'logger'}->warn($mess);
            #carp "EkzKohaRecords::" . $mess . "\n";
        } else
        {
            my ( $error, $marcresults, $total_hits ) = ( '', [], 0 );
            my @isbnSelFields = ('isbn', 'isbn13');
            ISBNSEARCH: for ( my $k = 0; $k < 2; $k += 1 ) {
                if ( defined $selParam->{$isbnSelFields[$k]} && length($selParam->{$isbnSelFields[$k]}) > 0 ) {
                    my @selISBN = ();
                    eval {
                        my $businessIsbn = Business::ISBN->new($selParam->{$isbnSelFields[$k]});
                        if ( defined($businessIsbn) && ! $businessIsbn->error ) {
                            $selISBN[0] = $businessIsbn->as_string([]);
                            $selISBN[1] = $businessIsbn->as_string();
                            $selISBN[2] = $businessIsbn->as_isbn10->as_string([]);
                            $selISBN[3] = $businessIsbn->as_isbn10->as_string();
                        }
                    };
                    if ( ! defined($selISBN[0]) ) {
                        my $mess = sprintf("readTitleDubletten(): %s not valid -> not searching for %s %s.", $isbnSelFields[$k], $isbnSelFields[$k], $selParam->{$isbnSelFields[$k]});
                        $self->{'logger'}->warn($mess);
                        carp "EkzKohaRecords::" . $mess . "\n";
                    } else {
                        for ( my $i = 0; $i < 4; $i += 1 ) {
                            if ( defined($selISBN[$i]) && length($selISBN[$i]) > 0 ) {
                                # build search query for isbn/isbn13 search
                                # search for catalog title record by MARC21 category 020/024 (ISBN/EAN)
                                my $query = "nb:\"$selISBN[$i]\" or id-other:\"$selISBN[$i]\"";
                                $self->{'logger'}->debug("readTitleDubletten() query:$query:");
                
                                ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
            
                                if (defined $error) {
                                    my $mess = sprintf("readTitleDubletten(): search for %s:%s: returned error:%d/%s:", $isbnSelFields[$k], $selISBN[$i], $error,$error);
                                    $self->{'logger'}->warn($mess);
                                    carp "EkzKohaRecords::" . $mess . "\n";
                                } else {
                                    if ( $total_hits > 0 ) {
                                        $self->mergeMarcresults($allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
                                        last ISBNSEARCH;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            $self->{'logger'}->debug("readTitleDubletten() isbn/isbn13 search total_hits:$total_hits: allinall_hits:$allinall_hits:");
        }

        # check for issn/ismn/ean search
        if ( (!defined $selParam->{'issn'} || length($selParam->{'issn'}) == 0) && 
             (!defined $selParam->{'ismn'} || length($selParam->{'ismn'}) == 0) && 
             (!defined $selParam->{'ean'} || length($selParam->{'ean'}) == 0) ) {
            my $mess = sprintf("readTitleDubletten(): issn and ismn and ean are empty -> not searching for issn or ismn or ean.");
            $self->{'logger'}->warn($mess);
            #carp "EkzKohaRecords::" . $mess . "\n";
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
            $self->{'logger'}->debug("readTitleDubletten() query:$query:");
            
            my ( $error, $marcresults, $total_hits ) = ( '', [], 0 );
            ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
        
            if (defined $error) {
                my $mess = sprintf("readTitleDubletten(): search for issn:%s: or ismn:%s: or ean:%s: returned error:%d/%s:", $selParam->{'issn'}, $selParam->{'ismn'}, $selParam->{'ean'}, $error,$error);
                $self->{'logger'}->warn($mess);
                carp "EkzKohaRecords::" . $mess . "\n";
            }
            $self->{'logger'}->debug("readTitleDubletten() issn/ismn/ean search1 total_hits:$total_hits:");
                
            # ekz sends EAN without leading 0
            if ($total_hits == 0 && defined $selParam->{'ean'} && length($selParam->{'ean'}) > 0 && length($selParam->{'ean'}) < 13) {
                if ( length($query1) > 0 ) {
                    $query3 .= ' or ';
                }
                $query3 .= sprintf("ident:\"%013d\"",$selParam->{'ean'});
                $query = $query1 . $query3;
                $self->{'logger'}->debug("readTitleDubletten() query:$query:");
                
                ( $error, $marcresults, $total_hits ) = ( '', [], 0 );
                ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
            
                if (defined $error) {
                    my $mess = sprintf("readTitleDubletten(): search for issn:%s: or ismn:%s: or ean:%s: returned error:%d/%s:", $selParam->{'issn'}, $selParam->{'ismn'}, $selParam->{'ean'}, $error,$error);
                    $self->{'logger'}->warn($mess);
                    carp "EkzKohaRecords::" . $mess . "\n";
                } else
                {
                    $self->mergeMarcresults($allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
                }
                $self->{'logger'}->debug("readTitleDubletten() issn/ismn/ean search2 total_hits:$total_hits: allinall_hits:$allinall_hits:");
            }
        }

        # check for author and title and publication year search
        if ( (!defined $selParam->{'author'} || length($selParam->{'author'}) == 0) || (!defined $selParam->{'titel'} || length($selParam->{'titel'}) == 0) || (!defined $selParam->{'erscheinungsJahr'} || length($selParam->{'erscheinungsJahr'}) == 0) ) {
            my $mess = sprintf("readTitleDubletten(): author and titel and erscheinungsJahr is empty -> not searching for it.");
            $self->{'logger'}->warn($mess);
            #carp "EkzKohaRecords::" . $mess . "\n";
        } else
        {
            # build search query for author and title and publication year search
            $query = "au,phr:\"$selParam->{'author'}\" and ti,phr,ext:\"$selParam->{'titel'}\" and yr,st-year:\"$selParam->{'erscheinungsJahr'}\"";
            $self->{'logger'}->debug("readTitleDubletten() query:$query:");
            
            my ( $error, $marcresults, $total_hits ) = ( '', [], 0 );
            ( $error, $marcresults, $total_hits ) = C4::Search::SimpleSearch($query);
        
            if (defined $error) {
                my $mess = sprintf("readTitleDubletten(): search for author:%s: or title:%s: publication year:%s: returned error:%d/%s:", $selParam->{'author'}, $selParam->{'titel'}, $selParam->{'erscheinungsJahr'}, $error, $error);
                $self->{'logger'}->warn($mess);
                carp "EkzKohaRecords::" . $mess . "\n";

            } else
            {
                $self->mergeMarcresults($allmarcresults,\%biblionumbersfound,$marcresults,\$allinall_hits);
            }
            $self->{'logger'}->debug("readTitleDubletten() author/title/publicationyear search total_hits:$total_hits: allinall_hits:$allinall_hits:");
        }
    }
    
    return $allmarcresults;
}


##############################################################################
#
# read title data from the LMSCloud ekz title data pool, using ekzArtikelNr, ISBN, ISBN13, ISSN, ISMN, EAN
#
##############################################################################
sub readTitleInLMSPool {
    my $self = shift;
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
        $self->{'logger'}->debug("readTitleInLMSPool() is calling getbyId.");
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
            $self->{'logger'}->debug("readTitleInLMSPool() is calling getbyISBN.");
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
            $self->{'logger'}->debug("readTitleInLMSPool() is calling getbyIdentifierStandard.");
            $result = $pool->getbyIdentifierStandard(\@standardIdentifierList);

            if ( $result->{'count'} > 0 ) {
                $foundInPool = 3;
            }
        }
    }

    $self->{'logger'}->debug("readTitleDubletten() selEkzArtikelNr:" . $selEkzArtikelNr . ": selIsbn:" . $selIsbn . ": selIsbn13:" . $selIsbn13 . ": foundInPool:" . $foundInPool . ":");
    $self->{'logger'}->debug("readTitleDubletten() result->{'count'}:$result->{'count'}:");
    return $result;
}


##############################################################################
#
# read title data using ekz web service MedienDaten, selected by ekzArtikelNr
#
##############################################################################
sub readTitleFromEkzWsMedienDaten {
    my $self = shift;
    my $ekzArtikelNr = shift;
    
    my $ekzwebservice = C4::External::EKZ::lib::EkzWebServices->new();
    my $result = $ekzwebservice->callWsMedienDaten($ekzArtikelNr);
    $self->{'logger'}->debug("readTitleFromEkzWsMedienDaten() result->{'count'}:$result->{'count'}: result->{'records'}:" . Dumper($result->{'records'}) . ": ");

    return $result;
}


##############################################################################
#
# read title data from a Z39.50 target using Z39.50 search selected by ISBN, ISSN or EAN
#
##############################################################################
sub readTitleFromZ3950Target {
    my $self = shift;
    my ($z3950kohaservername, $reqParamTitelInfo) = @_;

    my $selIsbn13 = $reqParamTitelInfo->{'isbn13'};
    my $selIssn = $reqParamTitelInfo->{'issn'};
    my $selEan = $reqParamTitelInfo->{'ean'};
    my @id = ();   # for z3950servers.id of the configured z39.50 connection to DNB
    my $params;
    my $result = { 'count' => 0, 'records' => [] };
    my $errors = [];
    my $dbh = C4::Context->dbh;

    $self->{'logger'}->debug("readTitleFromZ3950Target() z3950kohaservername:$z3950kohaservername: selIsbn13:$selIsbn13: selIssn:$selIssn: selEan:$selEan:");
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
            my @selISBN = ();
            eval {
                my $businessIsbn = Business::ISBN->new($selIsbn13);
                if ( defined($businessIsbn) && ! $businessIsbn->error ) {
                    $selISBN[0] = $businessIsbn->as_string([]);
                    $selISBN[1] = $businessIsbn->as_string();
                    $selISBN[2] = $businessIsbn->as_isbn10->as_string([]);
                    $selISBN[3] = $businessIsbn->as_isbn10->as_string();
                }
            };
            for ( my $i = 0; $i < 4; $i += 1 ) {
                if ( $result->{'count'} == 0 && defined($selISBN[$i]) && length($selISBN[$i]) > 0 ) {
                    $params->{'isbn'} = $selISBN[$i];
                    $self->{'logger'}->debug("readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: isbn:$selISBN[$i]:");
                    C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
                    $params->{'isbn'} = '';
                }
            }
        }
        if ( $result->{'count'} == 0 && defined($selIssn) && length($selIssn) > 0 ) {
            $params->{'issn'} = $selIssn;
            $self->{'logger'}->debug("readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: issn:$params->{'issn'}:");
            C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
            $params->{'issn'} = '';
        }
        if ( $result->{'count'} == 0 && defined($selEan) && length($selEan) > 0 ) {
            $params->{'ean'} = $selEan;    # effective for zed search only, not for sru search
            $self->{'logger'}->debug("readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: ean:$params->{'ean'}:");
            C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
            $params->{'ean'} = '';
            if ( $result->{'count'} == 0 ) {
                $params->{'isbn'} = $selEan;    # last resort for sru targets: search ean value as isbn
            $self->{'logger'}->debug("readTitleFromZ3950Target() is calling C4::Breeding::Z3950SearchGeneral id[0]:$id[0]: ean value as isbn:$params->{'isbn'}:");
                C4::Breeding::Z3950SearchGeneral($params, \$result, \$errors);
                $params->{'isbn'} = '';
            }
        }
    }
    $self->{'logger'}->debug("readTitleFromZ3950Target() result->{'count'}:$result->{'count'}: result->{'records'}:" . Dumper($result->{'records'}) . ": ");
    foreach my $error (@{$errors}) {
        $self->{'logger'}->debug("readTitleFromZ3950Target() error:" . Dumper($error) . ":");
    }

    return $result;
}


##############################################################################
#
# take title data from the few fields of request titelinfo
#
##############################################################################
sub createTitleFromFields {
    my $self = shift;
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

    $self->{'logger'}->debug("createTitleFromFields() marcrecord:" . Dumper( $marcrecord ) . ":");
    if ( $marcrecord ) {
        push @{$result->{'records'}}, $marcrecord;
        $result->{'count'} += 1;
    }

    return $result;
}


sub checkbranchcode {
    my $self = shift;
    my $branchcode = shift;

    if ( keys %{$self->{'branchnames'}} == 0 ) {
        my $branches = { map { $_->branchcode => $_->unblessed } Koha::Libraries->search };
        foreach my $brcode ( sort keys %{$branches} ) {
            my $brcodeN = $brcode;
            $brcodeN =~ s/^\s+|\s+$//g; # trim spaces
            $self->{'branchnames'}->{$brcodeN} = $branches->{$brcode}->{'branchname'};
            $self->{'logger'}->debug("checkbranchcode() self->{'branchnames'}->{" . $brcodeN . "} = " . $self->{'branchnames'}->{$brcodeN} . ":");
        }
    }
    $branchcode =~ s/^\s+|\s+$//g; # trim spaces
    my $ret = defined $self->{'branchnames'}->{$branchcode};

    $self->{'logger'}->debug("checkbranchcode() branchcode:" . $branchcode . ": returns ret:" . $ret . ":");
    return $ret;
}


##############################################################################
#
# create a short ISBD description of the title for the e-mail
#
##############################################################################
sub getShortISBD {
    my $self = shift;
    my $koharecord = shift;

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
    if ( $titleblock ) {
        $titleblock =~ s/[\x{0098}\x{009c}]//g;
    }
    
    my $identifier = '';
    $field = $koharecord->field('020');
    if ( $field ) {
        my $isbn = $field->subfield('a');
        eval {
            my $val = Business::ISBN->new($isbn);
            $isbn = $val->as_isbn13()->as_string([]);
        };
        $identifier = $isbn;
    }
    $field = $koharecord->field('024');
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
    my $self = shift;
    my $logresult = shift;
    my $header = shift;
    my $dt = shift;
    my $importIDs  = shift;
    my $ekzBestell_Ls_Re_Nr = shift;

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
    $self->{'logger'}->info("createProcessingMessageText() envKohaInstanceUrl:$envKohaInstanceUrl: kohaInstanceUrl:$kohaInstanceUrl:");
    my $printdate =  $dt->dmy('.') . ' um ' . sprintf("%02d:%02d Uhr", $dt->hour, $dt->minute);
    $self->{'logger'}->info("createProcessingMessageText() printdate:$printdate: Anz. logresult:" . scalar @{$logresult} . ": importIDs->[0]:$importIDs->[0]: ekzBestell_Ls_Re_Nr:$ekzBestell_Ls_Re_Nr:");
    $self->{'logger'}->debug("createProcessingMessageText() Dumper(logresult):" . Dumper($logresult) . ":");
    $self->{'logger'}->debug("createProcessingMessageText() Dumper(importIDs):" . Dumper($importIDs) . ":");
    
    my $subject = "Import ekz Bestellung $ekzBestell_Ls_Re_Nr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    if ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
        $subject = "Import ekz Rechnung $ekzBestell_Ls_Re_Nr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    } elsif ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
        $subject = "Import ekz Lieferschein $ekzBestell_Ls_Re_Nr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
        $subject = "Import ekz standing-order-Titel $ekzBestell_Ls_Re_Nr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    } else {    # eq 'BestellInfo'
        $subject = "Import ekz Bestellung $ekzBestell_Ls_Re_Nr ($libraryName) " . $dt->dmy('.') . sprintf(" %02d:%02d Uhr", $dt->hour, $dt->minute);
    }
    
    $message .= '<!DOCTYPE html>'."\n";
    $message .= '<html xmlns="http://www.w3.org/1999/xhtml">'."\n";
    $message .= '<head>'."\n";
    $message .= '<title>'."\n";
    if ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
        $message .= '    '. h("Ergebnisse Import ekz Rechnung $ekzBestell_Ls_Re_Nr ($libraryName)") . "\n";
    } elsif ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
        $message .= '    '. h("Ergebnisse Import ekz Lieferschein $ekzBestell_Ls_Re_Nr ($libraryName)") . "\n";
    } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
        $message .= '    '. h("Ergebnisse Import ekz standing-order-Titel $ekzBestell_Ls_Re_Nr ($libraryName)") . "\n";
    } else {    # eq 'BestellInfo'
        $message .= '    '. h("Ergebnisse Import ekz Bestellung $ekzBestell_Ls_Re_Nr ($libraryName)") . "\n";
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
    
    my $acquisitionError = undef;
    my $aqbooksellersid = undef;
    my $aqbasketno = undef;
    my $invoiceid = undef;
    my $processedTitlesCount = 0;
    my $importedTitlesCount = 0;
    my $foundTitlesCount = 0;
    my $processedItemsCount = 0;
    my $importedItemsCount = 0;
    my $updatedItemsCount = 0;
    foreach my $result (@$logresult) {
        $self->{'logger'}->info("createProcessingMessageText() printdate:$printdate: result->[0]:$result->[0]: Anz. result->[2]:" . scalar @{$result->[2]} . ": importIDs->[0]:$importIDs->[0]: ekzBestell_Ls_Re_Nr:$ekzBestell_Ls_Re_Nr:");
        $self->{'logger'}->debug("createProcessingMessageText() Dumper(result):" . Dumper($result) . ":");
        my @actionsteps = @{$result->[2]};
        $acquisitionError = $result->[3];
        $aqbooksellersid = $result->[4];
        $aqbasketno = $result->[5];
        $invoiceid =  (sort(keys %{$result->[6]}))[0] if scalar keys %{$result->[6]};

        my @records = ();
        foreach my $action (@actionsteps) {
            $self->{'logger'}->trace("createProcessingMessageText() action->[actTxt ($actTxt)]:" . $action->[$actTxt] . ":");
            $self->{'logger'}->trace("createProcessingMessageText() action->[actRes ($actRes)]:" . $action->[$actRes] . ":");
            $self->{'logger'}->trace("createProcessingMessageText() action->[impTC ($impTC)]:" . $action->[$impTC] . ":");
            $self->{'logger'}->trace("createProcessingMessageText() action:" . Dumper($action) . ":");

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
    if ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
        $message .= '<h1>' . h("Ergebnisse Import ekz Rechnung $ekzBestell_Ls_Re_Nr ($libraryName)") .' </h1>'."\n";
        $message .= '<p>' . h('Datum: ' .  $printdate. ', RechnungDetail-Response messageID: ' . $logresult->[0]->[1]);
    } elsif ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
        $message .= '<h1>' . h("Ergebnisse Import ekz Lieferschein $ekzBestell_Ls_Re_Nr ($libraryName)") .' </h1>'."\n";
        $message .= '<p>' . h('Datum: ' .  $printdate. ', LieferscheinDetail-Response messageID: ' . $logresult->[0]->[1]);
    } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
        $message .= '<h1>' . h("Ergebnisse Import ekz standing-order-Titel $ekzBestell_Ls_Re_Nr ($libraryName)") .' </h1>'."\n";
        $message .= '<p>' . h('Datum: ' .  $printdate. ', StoList-Response messageID: ' . $logresult->[0]->[1]);
    } else {    # eq 'BestellInfo'
        $message .= '<h1>' . h("Ergebnisse Import ekz Bestellung $ekzBestell_Ls_Re_Nr ($libraryName)") .' </h1>'."\n";
        $message .= '<p>' . h('Datum: ' .  $printdate. ', BestellInfo-Request messageID: ' . $logresult->[0]->[1]);
    }
    if ( $importedTitlesCount + $foundTitlesCount > 0 and scalar @{$importIDs} > 0 ) {
        my $controlNumberQuery = '';
        my $controlNumberCnt = 0;
        my $orderQuery = '';
        my $orderCnt = 0;
        my $allQuery = '';
        foreach my $importID (@{$importIDs}) {
            $self->{'logger'}->info("createProcessingMessageText() importID:" . $importID . ":");
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
        $self->{'logger'}->debug("createProcessingMessageText() controlNumberCnt:" . $controlNumberCnt . ": controlNumberQuery:" . $controlNumberQuery . ": orderCnt:" . $orderCnt . ": orderQuery:" . $orderQuery . ":");
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
            if ( $logresult->[0]->[0] eq 'StoList' || $logresult->[0]->[0] eq 'LieferscheinDetail' || $logresult->[0]->[0] eq 'RechnungDetail' ) {
                $messText = "Link auf alle bearbeiteten Titel";
            }            
            $message .= '<br />' . '<a href="' . $kohaInstanceUrl . '/cgi-bin/koha/catalogue/search.pl?q=' . $controlNumberQuery . '">' . h($messText) . '</a>';
            if ( $logresult->[0]->[0] eq 'BestellInfo' || $logresult->[0]->[0] eq 'StoList' ) {
                if ( defined($aqbasketno) && $aqbasketno > 0 ) { 
                    my $messText = "Link auf die Koha-Bestellung";    # default for BestellInfo and StoList
                    # e. g.  http://192.168.122.100:8080/cgi-bin/koha/acqui/basket.pl?basketno=42
                    $message .= '<br />' . '<a href="' . $kohaInstanceUrl . '/cgi-bin/koha/acqui/basket.pl?basketno=' . $aqbasketno . '">' . h($messText) . '</a>';
                }
            } elsif ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
                if ( defined($invoiceid) && $invoiceid > 0 ) { 
                    my $messText = "Link auf die Koha-Rechnung";    # default for RechnungDetail
                    # e. g.  http://192.168.122.101:8080/cgi-bin/koha/acqui/invoice.pl?invoiceid=22
                    $message .= '<br />' . '<a href="' . $kohaInstanceUrl . '/cgi-bin/koha/acqui/invoice.pl?invoiceid=' . $invoiceid . '">' . h($messText) . '</a>';
                }
            }
        }
    }
    $message .= '</p>'."\n";
    $message .= '<p>';
    if ( $processedTitlesCount == 0 ) {
        if ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
            $message .= h("Beim Import der ekz Rechnung " . $ekzBestell_Ls_Re_Nr . " trat ein Problem auf. Es wurden keine Titeldaten erkannt.");
        } elsif ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
            $message .= h("Beim Import des ekz Lieferscheins " . $ekzBestell_Ls_Re_Nr . " trat ein Problem auf. Es wurden keine Titeldaten erkannt.");
        } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
            $message .= h("Beim Import von Titeln der ekz standing-order " . $ekzBestell_Ls_Re_Nr . " trat ein Problem auf. Es wurden keine Titeldaten erkannt.");
        } else {    # eq 'BestellInfo'
            $message .= h("Beim Import der ekz Bestellung " . $ekzBestell_Ls_Re_Nr . " trat ein Problem auf. Es wurden keine Titeldaten erkannt.");
        }
    } else {
        if ( $haserror ) {
            if ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
                $message .= h("Beim Import der ekz Rechnung " . $ekzBestell_Ls_Re_Nr . " traten Probleme auf. Details sind der folgenden Liste zu entnehmen.");
            } elsif ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
                $message .= h("Beim Import des ekz Lieferscheins " . $ekzBestell_Ls_Re_Nr . " traten Probleme auf. Details sind der folgenden Liste zu entnehmen.");
            } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
                $message .= h("Beim Import von Titeln der ekz standing-order " . $ekzBestell_Ls_Re_Nr . " traten Probleme auf. Details sind der folgenden Liste zu entnehmen.");
            } else {    # eq 'BestellInfo'
                $message .= h("Beim Import der ekz Bestellung " . $ekzBestell_Ls_Re_Nr . " traten Probleme auf. Details sind der folgenden Liste zu entnehmen.");
            }
        } else {
            if ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
                $message .= h("Die Titel- und Exemplardaten der ekz Rechnung " . $ekzBestell_Ls_Re_Nr . " wurden komplett übernommen. Details sind der folgenden Liste zu entnehmen.");
            } elsif ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
                $message .= h("Die Titel- und Exemplardaten des ekz Lieferscheins " . $ekzBestell_Ls_Re_Nr . " wurden komplett übernommen. Details sind der folgenden Liste zu entnehmen.");
            } elsif ( $logresult->[0]->[0] eq 'StoList' ) {
                $message .= h("Die aktualisierten Titel- und Exemplardaten der ekz standing-order " . $ekzBestell_Ls_Re_Nr . " wurden komplett übernommen. Details sind der folgenden Liste zu entnehmen.");
            } else {    # eq 'BestellInfo'
                $message .= h("Die Titel- und Exemplardaten zur ekz Bestellung " . $ekzBestell_Ls_Re_Nr . " wurden komplett übernommen. Details sind der folgenden Liste zu entnehmen.");
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
        if ( $logresult->[0]->[0] eq 'BestellInfo' || $logresult->[0]->[0] eq 'LieferscheinDetail' || $logresult->[0]->[0] eq 'RechnungDetail' ) {
            $message .= '           <span class="import-result-field">Ergebnis:</span> <span class="import-result">' . 'Von ' . $processedTitlesCount . ' Titeln wurden ' . $importedTitlesCount . ' importiert und ' . $foundTitlesCount . ' aktualisiert; von ' . $processedItemsCount . ' Exemplaren wurden ' . $importedItemsCount . ' importiert und ' . $updatedItemsCount . ' aktualisiert. </span><br />'."\n";
        } else {    # eq 'StoList'
            $message .= '           <span class="import-result-field">Ergebnis:</span> <span class="import-result">' . 'Von ' . $processedTitlesCount . ' Titeln wurden ' . $importedTitlesCount . ' importiert und ' . $foundTitlesCount . ' aktualisiert; von ' . $processedItemsCount . ' Exemplaren wurden ' . $importedItemsCount . ' importiert. </span><br />'."\n";
        }
        $message .= '        </th>'."\n";
        $message .= '    </tr>'."\n";

        if ( scalar(@actionsteps) > 0 ) {
        
            $message .= '    <tr class="recordheader">'."\n";
            $message .= '        <th width="5%">'."\n";
            $message .= '            Lfd. Nr.'."\n";
            $message .= '        </th>'."\n";

            $message .= '        <th width="50%">'."\n";
            $message .= '            Titel'."\n";
            $message .= '        </th>'."\n";

            $message .= '        <th width="10%">'."\n";
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
                my %aqordernumbers = ();
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
                            if ( $action->[$updIC] > 0 || $logresult->[0]->[0] eq 'LieferscheinDetail' || $logresult->[0]->[0] eq 'RechnungDetail' ) {
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
                        if ( defined($aqbooksellersid) && length($aqbooksellersid) > 0 ) {
                            my $aqordernumber = $record->[8];
                            my $item_basketno = $record->[9];
                            $self->{'logger'}->debug("createProcessingMessageText() itemnumber:" . h($record->[3]) . ": aqordernumber:" . (defined($aqordernumber)?Dumper($aqordernumber):'undef') . ": item_basketno:" . (defined($item_basketno)?$item_basketno:'undef') . ":");
                            if ( defined($aqordernumber) && $aqordernumber > 0 ) {
                                if ( defined($item_basketno) && $item_basketno > 0 ) {
                                    # e. g. for basket: http://192.168.122.100:8080/cgi-bin/koha/acqui/basket.pl?basketno=42
                                    # e.g. for order line: http://192.168.122.100:8080/cgi-bin/koha/acqui/neworderempty.pl?ordernumber=45&booksellerid=13&basketno=42
                                    $message .= '( <a href="' . $kohaInstanceUrl . '/cgi-bin/koha/acqui/basket.pl?basketno=' . $item_basketno . '">' . h('Best. ' . $item_basketno) . '</a>' . 
                                                ', <a href="' . $kohaInstanceUrl . '/cgi-bin/koha/acqui/neworderempty.pl?ordernumber=' . $aqordernumber . '&booksellerid=' . $aqbooksellersid . '&basketno=' . $item_basketno . '">' . h('Posten ' . $aqordernumber) . "</a>)\n";
                                } else {
                                    # e.g.: http://192.168.122.100:8080/cgi-bin/koha/acqui/neworderempty.pl?ordernumber=45&booksellerid=13
                                    $message .= ' <a href="' . $kohaInstanceUrl . '/cgi-bin/koha/acqui/neworderempty.pl?ordernumber=' . $aqordernumber . '&booksellerid=' . $aqbooksellersid . '">(' . h(' Bestellposten ' . $aqordernumber) . ")</a>\n";
                                }
                            }
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
                if ( $logresult->[0]->[0] eq 'RechnungDetail' ) {
                    $message .= h('Fehler beim Import der ekz Rechnungsdaten für einen Titel: ') . h($loaderr);
                } elsif ( $logresult->[0]->[0] eq 'LieferscheinDetail' ) {
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
    my $self = shift;
    my ( $ekzCustomerNumber, $message, $subject ) = @_;

    my $ekzAdminEmailAddress = $self->{'ekzWsConfig'}->getEkzProcessingNoticesEmailAddress($ekzCustomerNumber);
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
            subject     => encode("MIME-Q", $subject),
            message     => $message,
            contenttype => 'text/html; charset="UTF-8"'
        }
    );
    $self->{'logger'}->debug("sendMessage() ekzCustomerNumber:$ekzCustomerNumber: sendmailParams:" . Dumper(%sendmailParams) . ":");
    sendmail( %sendmailParams );
}

sub h {
    return (encode_entities(shift));
}


sub checkEkzAqbooksellersId {
    my $self = shift;
    my ($ekzAqbooksellersId, $createIfNotExists) = @_;
    my $ekzAqbooksellersIdNew = $ekzAqbooksellersId;

    $self->{'logger'}->debug("checkEkzAqbooksellersId() START ekzAqbooksellersId:$ekzAqbooksellersId: createIfNotExists:$createIfNotExists:");

    if ( defined($ekzAqbooksellersId) && length($ekzAqbooksellersId) ) {
        my $schema = Koha::Database->new->schema;
        my $rs = $schema->resultset('Aqbookseller');
        my $rec = $rs->find({ 'id' => $ekzAqbooksellersId });
        if ( !defined($rec) ) {
            $rec = $rs->search({ 'name' => "ekz" }, { order_by => {-asc => 'id'} })->first();
            if ( defined($rec) ) {
                $ekzAqbooksellersIdNew = $rec->id;
            }
        }

        if ( !defined($rec) && $createIfNotExists ) {
            $rec = $rs->create({
                                    name => "ekz",
                                    address1 => "ekz.bibliotheksservice GmbH\n",
                                    address2 => "Bismarckstr. 3\n",
                                    address3 => "D-72764 Reutlingen\n",
                                    phone => "07121 144-0",
                                    fax => "07121 144-280",
                                    url => "http://www.ekz.de",
                                    postal => "ekz.bibliotheksservice GmbH\nBismarckstr. 3\nD-72764 Reutlingen\n",
                                    active => 1,
                                    listprice => "EUR",
                                    invoiceprice => "EUR",
                                    gstreg => 1,
                                    listincgst => 1,
                                    invoiceincgst => 1,
                                    tax_rate => 0.07,
                                    discount => 0.0,
                                    deliverytime => 9
                            });
            $ekzAqbooksellersIdNew = $rec->id;
        }

        if (  $ekzAqbooksellersIdNew != $ekzAqbooksellersId ) {
            my $rs = $schema->resultset('Systempreference');
            my $rec = $rs->find({ 'variable' => "ekzAqbooksellersId" });
            if ( defined($rec) ) {
                $rec->update({ 'value' => $ekzAqbooksellersIdNew });
            }
        }
    }
    $self->{'logger'}->debug("checkEkzAqbooksellersId() returns ekzAqbooksellersIdNew:$ekzAqbooksellersIdNew:");
    return $ekzAqbooksellersIdNew;
}

sub checkAqbudget {
    my $self = shift;
    my ($ekzCustomerNumber, $ekzHaushaltsstelle, $ekzKostenstelle, $createIfNotExists) = @_;
    my $ret_budget_period_id = undef;
    my $ret_budget_period_description = undef;
    my $ret_budget_id = undef;
    my $ret_budget_code = undef;
    my $budget_code_default;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $today = $year+1900 . '-' . sprintf("%02d",$mon+1) . '-' . sprintf("%02d",$mday);

    $self->{'logger'}->debug("checkAqbudget() START ekzCustomerNumber:$ekzCustomerNumber: ekzHaushaltsstelle:$ekzHaushaltsstelle: ekzKostenstelle:$ekzKostenstelle: createIfNotExists:$createIfNotExists:");

    # $ekzHaushaltsstelle is sent in SOAP request and refers to aqbudgetperiods.budget_period_description
    # $ekzKostenstelle is sent in SOAP request refers to aqbudgets.budget_code where budget_parent_id IS NULL and budget_period_id = aqbudgetperiods.budget_period_id
    # As we require the combination of aqbudgetperiods.budget_period_description and aqbudgets.budget_code to be unique, we do not select by budget_branchcode (this is necessary because StoList and LieferscheinDetail and RechnungDetail send no branchcode field)
    
    # If ekzHaushaltsstelle is not empty:
    #     If an active, non locked aqbudgetperiods record with aqbudgetperiods.budget_period_description = ekzHaushaltsstelle exists, then take this record,
    #     otherwise, if $createIfNotExists is set, create such an aqbudgetperiods record (budget_period_startdate = CURRYEAR-01-01 etc.).
    #
    # If ekzHaushaltsstelle is empty and the entry in systempreference "ekzAqbudgetperiodsDescription" corresponding to $ekzCustomerNumber is not empty:
    #     If an active, non locked aqbudgetperiods record with aqbudgetperiods.budget_period_description = <this entry> exists, then take this record,
    #     otherwise create such an aqbudgetperiods record (budget_period_startdate = CURRYEAR-01-01 etc.).
    # 
    # If ekzHaushaltsstelle is empty and the entry in systempreference "ekzAqbudgetperiodsDescription") corresponding to $ekzCustomerNumber is empty:
    #     If an active, non locked aqbudgetperiods record with with aqbudgetperiods.budget_period_startdate < today <  aqbudgetperiods.budget_period_enddate exists, then take this record,
    #     otherwise create a default aqbudgetperiods record (aqbudgetperiods.budget_period_description = CURRYEAR, budget_period_startdate = CURRYEAR-01-01 etc.).

    # find or create a budget period to use
    my $ekzAqbudgetperiodsDescription = $self->{'ekzWsConfig'}->getEkzAqbudgetperiodsDescription($ekzCustomerNumber);
    if ( defined($ekzHaushaltsstelle) && length($ekzHaushaltsstelle) > 0 ) {
        $ret_budget_period_description = $ekzHaushaltsstelle;
    } else {
        if ( defined($ekzAqbudgetperiodsDescription) && length($ekzAqbudgetperiodsDescription) > 0 ) {
            $ret_budget_period_description = $ekzAqbudgetperiodsDescription;
        }
    }
    $self->{'logger'}->debug("checkAqbudget() ekzHaushaltsstelle:$ekzHaushaltsstelle: selection from syspref ekzAqbudgetperiodsDescription:$ekzAqbudgetperiodsDescription: ret_budget_period_description:$ret_budget_period_description:");

    my $query_period = "SELECT * FROM aqbudgetperiods p ";
    $query_period .= " WHERE p.budget_period_active = 1 ";
    $query_period .= " AND p.budget_period_locked = 0 ";
    if ( $ret_budget_period_description ) {
        $query_period .= " AND p.budget_period_description = '$ret_budget_period_description' ";
    } else {
        $query_period .= " AND p.budget_period_startdate <= CURDATE() ";
        $query_period .= " AND CURDATE() <= p.budget_period_enddate ";
    }
    $query_period .= " order by p.budget_period_startdate, p.budget_period_enddate ";

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query_period);
    $sth->execute();
    my $budgetperiod_hits = $sth->fetchall_arrayref({});
    my $best_budgetperiod_hit = undef;

    $self->{'logger'}->debug("checkAqbudget() scalar budgetperiod_hits:" . scalar @{$budgetperiod_hits} . ":");
    foreach my $budgetperiod_hit ( @{$budgetperiod_hits} ) {
        $self->{'logger'}->debug("checkAqbudget() budgetperiod_hit:" . Dumper($budgetperiod_hit) . ":");
        if ( !defined($best_budgetperiod_hit) ) {
            $best_budgetperiod_hit = $budgetperiod_hit;
            $ret_budget_period_id = $best_budgetperiod_hit->{'budget_period_id'};
            $ret_budget_period_description = $best_budgetperiod_hit->{'budget_period_description'};
        } else {
            $self->{'logger'}->debug("checkAqbudget() today:$today: budgetperiod_hit->startdate:" . $budgetperiod_hit->{'budget_period_startdate'} . ": ->enddate:" . $budgetperiod_hit->{'budget_period_enddate'} . ": best_budgetperiod_hit->startdate::" . $best_budgetperiod_hit->{'budget_period_startdate'} . ": ->enddate::" . $best_budgetperiod_hit->{'budget_period_enddate'} . ":");
            if ( !($best_budgetperiod_hit->{'budget_period_startdate'} le $today && $today le $best_budgetperiod_hit->{'budget_period_enddate'}) ) {
                if ( $budgetperiod_hit->{'budget_period_startdate'} le $today && $today le $budgetperiod_hit->{'budget_period_enddate'} ) {
                    $best_budgetperiod_hit = $budgetperiod_hit;
                    $ret_budget_period_id = $best_budgetperiod_hit->{'budget_period_id'};
                    $ret_budget_period_description = $best_budgetperiod_hit->{'budget_period_description'};
                }
            }
            $self->{'logger'}->debug("checkAqbudget() today:$today: budgetperiod_hit->startdate:" . $budgetperiod_hit->{'budget_period_startdate'} . ": ->enddate:" . $budgetperiod_hit->{'budget_period_enddate'} . ": best_budgetperiod_hit->startdate::" . $best_budgetperiod_hit->{'budget_period_startdate'} . ": ->enddate::" . $best_budgetperiod_hit->{'budget_period_enddate'} . ":");
        }
    }

    if ( !defined($best_budgetperiod_hit) ) {
        if ( !$ret_budget_period_description ) {
            $ret_budget_period_description = $year+1900;
        }
        if (  $createIfNotExists ) {
            # It is required to create an aqbudgetperiods record.
            my $startdate = $year+1900 . '-01-01';
            my $enddate = $year+1900 . '-12-31';
            my $schema = Koha::Database->new->schema;
            my $rs = $schema->resultset('Aqbudgetperiod');
            my $aqbudgetperiod = $rs->create( { 
                                                'budget_period_startdate' => $startdate,
                                                'budget_period_enddate' => $enddate,
                                                'budget_period_active' => 1,
                                                'budget_period_description' => $ret_budget_period_description,
                                                'budget_period_total' => 0.0,
                                                'budget_period_locked' => 0
                                              } );

            $ret_budget_period_id = $aqbudgetperiod->budget_period_id;
            $self->{'logger'}->debug("checkAqbudget() created aqbudgetperiods; ret_budget_period_description:$ret_budget_period_description: ret_budget_period_id:$ret_budget_period_id:");
        }
    }

    if ( $ret_budget_period_id ) {
        # find or create a budget in the budget period to use
        my $ekzAqbudgetsCode = $self->{'ekzWsConfig'}->getEkzAqbudgetsCode($ekzCustomerNumber);
        if ( defined($ekzAqbudgetsCode) && length($ekzAqbudgetsCode) > 0 ) {
            $budget_code_default = $ekzAqbudgetsCode;
        } else {
            $budget_code_default = "ekz";
        }
        if ( defined($ekzKostenstelle) && length($ekzKostenstelle) > 0 ) {
            $ret_budget_code = $ekzKostenstelle;
        } else {
            $ret_budget_code = $budget_code_default;
        }
        $self->{'logger'}->debug("checkAqbudget() budget_code_default:$budget_code_default: ret_budget_code:$ret_budget_code:");
        
        my $query_budget = "SELECT b.* FROM aqbudgets b ";
        $query_budget .= " WHERE b.budget_parent_id IS NULL ";
        $query_budget .= " AND b.budget_code = '$ret_budget_code' ";
        $query_budget .= " AND b.budget_period_id = $ret_budget_period_id";
        $query_budget .= " ORDER BY b.budget_branchcode ASC, b.budget_id DESC";

        $self->{'logger'}->debug("checkAqbudget() query_budget:$query_budget:");

        $sth = $dbh->prepare($query_budget);
        $sth->execute();
        my $budget_hits = $sth->fetchall_arrayref({});

        $self->{'logger'}->debug("checkAqbudget() scalar budget_hits:" . scalar @{$budget_hits} . ":");

        if ( defined($budget_hits->[0]) ) {
            $ret_budget_id = $budget_hits->[0]->{'budget_id'};
            $ret_budget_code = $budget_hits->[0]->{'budget_code'};
        } else {
            if ( $createIfNotExists ) {
                # It is required to create an aqbudgets record.
                # To this end an appropriate aqbudgetperiods record must exist.
                my $schema = Koha::Database->new->schema;
                my $rs = $schema->resultset('Aqbudget');
                my $aqbudget = $rs->create( { 
                                                'budget_parent_id' => undef,
                                                'budget_code' => $ret_budget_code,
                                                'budget_name' => $ret_budget_period_description . '-' . $ret_budget_code,
                                                'budget_branchcode' => '',
                                                'budget_amount' => 0.01,
                                                'budget_notes' => "",
                                                'budget_period_id' => $ret_budget_period_id,
                                                'sort1_authcat' => "",
                                                'sort2_authcat' => ""
                                            } );

                $ret_budget_id = $aqbudget->budget_id;
                $ret_budget_code = $aqbudget->budget_code;
                $self->{'logger'}->debug("checkAqbudget() created aqbudget record having ret_budget_id:$ret_budget_id: and ret_budget_code:$ret_budget_code:");
            }
        }
    }
    
    $self->{'logger'}->debug("checkAqbudget() returns ret_budget_period_id:$ret_budget_period_id: ret_budget_period_description:$ret_budget_period_description: ret_budget_id:$ret_budget_id: ret_budget_code:$ret_budget_code:");
    return ($ret_budget_period_id, $ret_budget_period_description, $ret_budget_id, $ret_budget_code);
}

sub branchcodeFallback {
    my $self = shift;
    my ($branchcode, $branchcodeFallback) = @_;
    my $ret_branchcode = $branchcode;

    $ret_branchcode =~ s/^\s+|\s+$//g;    # trim spaces
    if ( ! $self->checkbranchcode($ret_branchcode) ) {
        $ret_branchcode = $branchcodeFallback;
        $ret_branchcode =~ s/^\s+|\s+$//g;    # trim spaces
        if ( ! $self->checkbranchcode($ret_branchcode) ) {
            # take the branchcode of the branch having most items (but not 'eBib' and no book mobile station) 
            # select homebranch, count(*) from items where exists (select branchcode from branches where branches.branchcode != 'eBib' and branches.mobilebranch IS NULL and branches.branchcode = items.homebranch)  group by homebranch order by count(*);
            my $dbh = C4::Context->dbh;
            my $sth = $dbh->prepare("select homebranch, count(*) as count from items where exists (select branchcode from branches where branches.branchcode != 'eBib' and branches.mobilebranch IS NULL and branches.branchcode = items.homebranch)  group by homebranch order by count desc");
            $sth->execute();
            while ( my $hit = $sth->fetchrow_hashref ) {
                $ret_branchcode = $hit->{homebranch};
                $ret_branchcode =~ s/^\s+|\s+$//g;    # trim spaces
                if ( $self->checkbranchcode($ret_branchcode) ) {
                    last;
                }
                $ret_branchcode = '';
            }
        }
    }
    $self->{'logger'}->debug("branchcodeFallback() branchcode:$branchcode: branchcodeFallback:$branchcodeFallback: returns ret_branchcode:$ret_branchcode:");
    return $ret_branchcode
}

# round float $flt to precision of $decimaldigits behind the decimal separator. E. g. round(-1.234567, 2) == -1.23
sub round ()
{
    my ($flt, $decimaldigits) = @_;
    my $decimalshift = 10 ** $decimaldigits;

    return (int(($flt * $decimalshift) + (($flt < 0) ? -0.5 : 0.5)) / $decimalshift);
}

sub defaultUstSatz {
    my ($ustSatzType) = @_;    # 'E': Ermaessigt   'V': Voll
    my @defaultUstSatzE = (0.07, 0.05);    # MwSt.-Satz Ermaessigt in default period 0: 7%, in period 1: 5%
    my @defaultUstSatzV = (0.19, 0.16);    # MwSt.-Satz Voll in default period 0: 19%, in period 1: 16%
    my $period = 0;
    my $defaultUstSatzRet = 0;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $year += 1900;
    $mon += 1;

    # period 1: from 2020-07-01 to 2020-12-31, when value added tax rate (VAT) was reduced from 7% to 5% and from 19% to 16% in Germany
    if ( $year = 2020 && $mon >= 7 && $mon <= 12 )   {
        $period = 1;
    }

    if ( $ustSatzType eq 'V' ) {
        $defaultUstSatzRet = $defaultUstSatzV[$period];
    } else {
        $defaultUstSatzRet = $defaultUstSatzE[$period];
    }

    return $defaultUstSatzRet;
}

1;


