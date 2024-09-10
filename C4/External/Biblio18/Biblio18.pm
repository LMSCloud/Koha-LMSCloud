package C4::External::Biblio18::Biblio18;

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

use Modern::Perl;
use utf8;
use Carp;
use URI::Escape;
use JSON;
use DateTime;
use Data::Dumper;
use Business::ISBN;

use C4::Context;
use C4::Search;
use C4::Languages;
use C4::Auth qw(&checkpw_hash);
use C4::Circulation;

use Koha qw( version );
use Koha::SearchEngine::Search;
use Koha::SearchEngine::QueryBuilder;
use Koha::ItemTypes;
use Koha::Biblios;
use Koha::Patrons;
use Koha::DateUtils qw( dt_from_string );
use Koha::AuthorisedValues;

sub new {
    my $class = shift;
    my $params = shift;

    my $self = {};
    bless $self, $class;
    
    my $userid = $params->{userid} || '';
    
    my $patron = Koha::Patrons->find({ userid => $userid } );
    
    if (! $patron ) { 
        croak "User $userid cannot be found. Unable to start the service.";
    }
    $self->{userid} = $userid;
    $self->{password} = $patron->password;
    $self->{version} = Koha::version();
    
    # read itemtypes
    $self->{itemtypes} = {};
    foreach my $it(Koha::ItemTypes->search->as_list) {
        $self->{itemtypes}->{$it->itemtype} = $it->description;
    }
    
    $self->{searchAdd} = $params->{"search_add"};
    $self->{excludedItemTypes} = $params->{"excluded_itypes"};
    $self->{queryIndexes} = $params->{"query_indexes"};
    $self->{available_since} = $params->{"available_since"};
    $self->{itemIncludeRules} = $params->{"item_include_rules"};
    $self->{itemExcludeRules} = $params->{"item_exclude_rules"};
    $self->{querySortField} = $params->{"query_sort_field"};
    
    $self->{max_search_results} = 100;
    if ( $params->{"max_search_results"} && $params->{"max_search_results"} =~ /^([0-9]+)$/ ) {
        $self->{max_search_results} = $1;
    }
    
    return $self;
}

sub getVersion {
    my $self = shift;
    return { Version => $self->{version} };
}

sub validateCredentials {
    my $self = shift;
    my $userid = shift;
    my $password = shift;
    
    return 1 if ( $userid && 
                  $userid eq $self->{userid} &&
                  $password && 
                  &checkpw_hash($password,$self->{password}) );
    return 0;
}

sub authenticatePatron {
    my $self = shift;
    my $params = shift;
    
    my $barcodeOrAlias = $params->{barcodeOrAlias};
    my $password = $params->{pwd};
    my $returnName = $params->{getname};
    
    if (! ($barcodeOrAlias && $password) ) {
        return  ({ 
                   status  => -2,
                   errormessage => "Es wurden unvollständige Anmeldedaten angegeben."
                 }, undef);
    }
    my $patron = Koha::Patrons->find({ cardnumber => $barcodeOrAlias } );
    if (! $patron ) { 
        $patron = Koha::Patrons->find({ userid => $barcodeOrAlias } );
    }
    if (! $patron ) {
        return  ({ 
                   status  => -2,
                   errormessage => "Die Anmeldedaten sind nicht korrekt."
                 }, undef);
    }
    
    my $age = $patron->get_age;
    my $fsk = 18;
    if ( $age > 0 && $age < 6 ) {
        $fsk = 0;
    }
    elsif ( $age >= 6 && $age < 12 ) {
        $fsk = 6;
    }
    elsif ( $age >= 12 && $age < 16 ) {
        $fsk = 12;
    }
    elsif ( $age >= 16 && $age < 18 ) {
        $fsk = 16;
    }
    
    my $status = 3;
    my $errormessage;
    my $amountlimit = C4::Context->preference("noissuescharge");
    my $non_issue_charges = $patron->account->non_issues_charges;
    my $num_overdues     = $patron->has_overdues;
    
    if ( $num_overdues && ( C4::Context->preference("OverduesBlockCirc") eq 'block' || C4::Context->preference("OverduesBlockCirc") eq 'confirmation' ) ) {
        $status = 1; # patron blocked due to overdues
        $errormessage = "Der Benutzer ist gesperrt aufgrund überfälliger Gebühren.";
    }
    elsif ( my $debarred_date = $patron->is_debarred ) {
        # patron has accrued fine days or has a restriction. $count is a date
        $status = 1; # patron debarred, no access
        $errormessage = "Der Benutzer ist gesperrt.";
    }
    elsif ( $patron->is_expired ) {
        $status = -3; # account expired
        $errormessage = "Der Benutzeraccount ist abgelaufen.";
    }
    elsif ( $patron->gonenoaddress && $patron->gonenoaddress == 1 ) {
        $status = 1; # patron has no valid address, no access
        $errormessage = "Für den Benutzer steht eine gültige Adddressangabe aus.";
    }
    elsif ( $patron->lost && $patron->lost == 1 ) {
        $status = 1; # account expired (due to a lost card)
        $errormessage = "Der Benutzerausweis wurde als verloren gemeldet.";
    }
    elsif ( $non_issue_charges > $amountlimit ) {
        $status = 4; # user debarred due to too much fines
        $errormessage = "Der Benutzeraccount ist aufgrund angefallener überhöhter Gebühren gesperrt.";
    }
    elsif ( $patron->account_locked ) {
        $status = 1; # patron blocked because he/she/it has reached the maximum number of login attempts
        $errormessage = "Für den Benutzeraccount liegen zu viele Fehlanmeldungen vor.";
    }
    if (! &checkpw_hash($password,$patron->password) ) {
        $status = -2;
        $errormessage = "Die Anmeldedaten sind nicht korrekt.";
    }
    
    if ( $status == 3 ) {
        return  ({ 
                   status  => $status,
                   fsk     => $fsk,
                   age     => $age,
                   barcode => $patron->cardnumber, 
                   userid  => $patron->borrowernumber,
                   name    => ($patron->firstname ? $patron->firstname . ' ' . $patron->surname : $patron->surname) || "",
                   email   => $patron->email || $patron->emailpro || $patron->B_email
                 }, undef);
    } else {
        return  ({ 
                   status       => $status,
                   errormessage => $errormessage
                 }, undef);
    }
}

sub search {
    my $self = shift;
    my $querystring = shift;
    my $checkAvailDays = shift;
    
    $checkAvailDays = 30 if (! $checkAvailDays || $checkAvailDays !~ /^[0-9]+$/ );
    
    my $compareAvailableDay = DateTime->now;
    $compareAvailableDay->add( days => $checkAvailDays );
    
    my $lang = C4::Languages::getlanguage();
    my $builder  = Koha::SearchEngine::QueryBuilder->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
    my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
    
    $self->{opacurl} = C4::Context->preference("OPACBaseURL");
    $self->{opacurl} =~ s/[\/\s]+$//;
    
    $querystring = $self->createQueryString($querystring);
    
    my @servers  = ("biblioserver");
    my @operands = ($querystring);
    
    my $scan             = undef;
    my $results_per_page = $self->{max_search_results};
    if ( C4::Context->preference("Biblio18QueryMaxSearchResultCount") && C4::Context->preference("Biblio18QueryMaxSearchResultCount") =~ /^([0-9]+)$/ ) {
        $results_per_page = $1;
    }
    my $offset           =  0;
    my $expanded_facet   = '';

    my $records = [];
    my $hitcount = 0;
    
    my $sortField = C4::Context->preference("Biblio18QuerySortField") || $self->{querySortField} || "relevance";
    
    if ( $querystring ) {
        # Get itemtype with Koha 18.05
        my $itemtypes = { map { $_->{itemtype} => $_ } @{ Koha::ItemTypes->search_with_localization->unblessed } };
        
        my $authorisedValueSearch = Koha::AuthorisedValues->search({ category => "BIBLIO18-MediaGroupUnion-Mapping" },{ order_by => ['authorised_value'] } );
        $self->{MediaGroupUnionMapping} = {};
        if ( $authorisedValueSearch->count ) {
            while ( my $authval = $authorisedValueSearch->next ) {
                $self->{MediaGroupUnionMappingDefined} = 1;
                my $grouptype = $authval->authorised_value || '';
                my $itemtype  = $authval->lib;
                $self->{MediaGroupUnionMapping}->{$grouptype} = $itemtype;
           }
        }
        
        # Build a query
        my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) = 
                $builder->build_query_compat(
                    [], # no operators
                    \@operands,
                    [], # no indexes
                    [], # no limits
                    [ $sortField ], # sort_by
                    undef, 
                    'en', 
                    { 'whole_record' => 1, 'weighted_fields' => 1, 'is_opac' => 1, 'suppress' => 1 }
                    );
        return (undef, "Error building a search query: $error") if ($error);
        
        # search the data
        # print Dumper($query);
        my ($results_hashref, $facets);
        ($error, $results_hashref, $facets) = 
                $searcher->search_compat(
                    $query,
                    $simple_query,
                    [ $sortField ], # no sort_by
                    \@servers,
                    $results_per_page,
                    $offset,
                    $expanded_facet,
                    undef,
                    $itemtypes,
                    $query_type,
                    $scan,
                    1);
        
        return (undef, "Error executing a the query: $error") if ($error);
        
        $hitcount = $results_hashref->{$servers[0]}->{"hits"};
        foreach my $marcdata(@{$results_hashref->{$servers[0]}->{"RECORDS"}}) {
            my $marcrecord = C4::Search::new_record_from_zebra('biblioserver', $marcdata);
            if ( my $biblionumber = $marcrecord->subfield('999','c') ) {
                my $biblio = Koha::Biblios->find( $biblionumber );
                next if (! $biblio);
                # next if ( $biblio->hidden_in_opac({ rules => C4::Context->yaml_preference('OpacHiddenItems') } ) );
                
                my $hitfound = $self->formatBiblioData($biblionumber,$marcrecord,$compareAvailableDay);
                push(@$records,$hitfound) if ( $hitfound );
            }
        }
    }
    
    return {
               SearchUrl => $self->{opacurl} . '/cgi-bin/koha/opac-search.pl?q=' . uri_escape($querystring),
               CatalogItems => $records
           };
}

sub formatBiblioData {
    my $self = shift;
    my $biblionumber = shift;
    my $record = shift;
    my $compareAvailableDay = shift;
    
    my $title = "";
    my $subtitle = "";
    
    foreach my $field ($record->field('245')) {
        $title = $field->subfield('a') if ( $field->subfield('a') ) ;
        $subtitle = $field->subfield('b') if ( $field->subfield('b') ) ;
    }
    
    my $authors = '';
    my $cnt = 0;
    foreach my $field ($record->field('100','110','111','700','710','711')) {
        if ( $field->subfield('a') ) {
            $authors .= '; ' if ($cnt++);
            $authors .= $field->subfield('a');
        }
    }
    
    my $searchisbn = [];
    my $checkisbn = {};
    my $isbns="";
    $cnt = 0;
    foreach my $field ($record->field('020')) {
        my $isbn= $field->subfield('a');
        $isbn =~ s/(^\s+|\s+$)// if ( $isbn );
        if ( $isbn && !exists($checkisbn->{$isbn}) ) {
            push(@$searchisbn,"isbn=($isbn)");
            $checkisbn->{$isbn} = 1;
        }
    }
    foreach my $isbn(reverse sort keys %$checkisbn) {
        eval {
            my $isbn13 = Business::ISBN->new($isbn);
            $isbns = $isbn13->as_isbn13->as_string([]);
        };
        last if ($isbns);
    }
    
    my $eans="";
    $cnt = 0;
    foreach my $field ($record->field('024')) {
        if ( $field->indicator(1) eq '3' ) {
            my $ean= $field->subfield('a');
            $ean =~ s/(^\s+|\s+$)// if ( $ean );
            if ( $ean && !exists($checkisbn->{$ean}) ) {
                $eans .= '; ' if ($cnt++);
                $eans .= $ean;
                push(@$searchisbn,"identifier-other=($ean)");
                $checkisbn->{$ean} = 1;
            }
        }
    }
    
    my $itemIncludeRules = C4::Context->preference("Biblio18ItemIncludeRules") || $self->{itemIncludeRules} || "";
    my $itemExcludeRules = C4::Context->preference("Biblio18ItemExcludeRules") || $self->{itemExcludeRules} || "";
    $self->{parsedItemIncludeRules} = undef;
    $self->{parsedItemExcludeRules} = undef;
    
    if ( $itemIncludeRules ) {
        my $yaml = eval { YAML::XS::Load( Encode::encode_utf8( $itemIncludeRules ) ); };
        if ($@) {
            warn "Unable to parse Biblio18ItemIncludeRules";
        } else {
            $self->{parsedItemIncludeRules} = $yaml; 
        }
    }
    
    if ( $itemExcludeRules ) {
        my $yaml = eval { YAML::XS::Load( Encode::encode_utf8( $itemExcludeRules ) ); };
        if ($@) {
            warn "Unable to parse Biblio18ItemExcludeRules";
        } else {
            $self->{parsedItemExcludeRules} = $yaml; 
        }
    }
    
    $self->{hiddenItemRules} = C4::Context->yaml_preference('OpacHiddenItems');
    
    my $mediaItemsList = [];
    my $itemtype = "";
    my $itemtypeCode = "";
    
    # read biblio items
    my $items = Koha::Items->search({ biblionumber => $biblionumber });
    
    while ( my $item = $items->next ) {
        
        # check opac hidden rules
        next if ( $self->{hiddenItemRules} && $item->hidden_in_opac( { rules => $self->{hiddenItemRules} } ) );
        
        # check specific Bilio18 item include rules if defined
        next if ( $self->{parsedItemIncludeRules} && !$item->hidden_in_opac( { rules => $self->{parsedItemIncludeRules} } ) );
        
        # check specific Bilio18 item exclude rules if defined
        next if ( $self->{parsedItemExcludeRules} && $item->hidden_in_opac( { rules => $self->{parsedItemExcludeRules} } ) );
        
        if (! $itemtype && $item->itype && exists($self->{itemtypes}->{$item->itype}) ) {
            $itemtype = $self->{itemtypes}->{$item->itype};
            $itemtypeCode = $item->itype;
        }
        
        my $accessiondate = $item->dateaccessioned();
        if ( $accessiondate && $accessiondate =~ /^[12][0-9]{3}-[01][0-9]-[0123][0-9]$/ ) {
            my $dt = dt_from_string($accessiondate,'sql');
            if ( $dt ) {
                $accessiondate = $dt->datetime();
            } else {
                $accessiondate = undef;
            }
        } else {
            $accessiondate = undef;
        }
        my $mediaItem = { 
                           StatusId           => 1, 
                           StatusName         => "Verfügbar",
                           DateAvail          => undef,
                           Barcode            => $item->barcode,
                           Location           => $item->itemcallnumber,
                           Available          => JSON::true,
                           DateOfAvailability => $accessiondate
                        };
                        
        my $issue = Koha::Checkouts->find( { itemnumber => $item->itemnumber } );
        my $holds = $item->holds->waiting;

        if ( $item->damaged ) {
            $mediaItem->{"StatusId"}   = 0; 
            $mediaItem->{"StatusName"} = "Beschädigt";
            $mediaItem->{"Available"}  = JSON::false; 
        }
        elsif ( $item->itemlost ) {
            $mediaItem->{"StatusId"}   = 0; 
            $mediaItem->{"StatusName"} = "Verloren gemeldet";
            $mediaItem->{"Available"}  = JSON::false; 
        }
        elsif ( $item->restricted ) {
            $mediaItem->{"StatusId"}   = 0; 
            $mediaItem->{"StatusName"} = "Eingeschränkt ausleihbar";
            $mediaItem->{"Available"}  = JSON::false; 
        }
        elsif ( $item->withdrawn ) {
            $mediaItem->{"StatusId"}   = 0; 
            $mediaItem->{"StatusName"} = "Ausgeschieden";
            $mediaItem->{"Available"}  = JSON::false; 
        }
        elsif ( $item->notforloan ) {
            $mediaItem->{"StatusId"}   = 0; 
            $mediaItem->{"StatusName"} = "Nicht entleihbar";
            $mediaItem->{"Available"}  = JSON::false; 
        }
        elsif ( $issue ) {
            my $returndate = dt_from_string($issue->date_due,'sql');
            $mediaItem->{"StatusId"}   = 0; 
            $mediaItem->{"DateAvail"}  = $returndate->datetime();
            $mediaItem->{"StatusName"} = "Ausgeliehen";
            $mediaItem->{"Available"}  = JSON::false;
            if ( DateTime->compare( $returndate, $compareAvailableDay ) < 0 ) {
                $mediaItem->{"StatusId"}  = 1;
            }
            if ( DateTime->compare( $returndate, DateTime->now ) < 0 ) {
                $mediaItem->{"StatusName"}  = "Rückgabe überfällig";
            }
        }
        elsif ( $holds && $holds->count() ) {
            my $hold = $holds->next();
            
            my $issuedate = dt_from_string($hold->waitingdate,'sql');
            if ( DateTime->compare($issuedate, DateTime->now) < 0 ) {
                $issuedate  = DateTime->now;
            }
            my $itype = $item->effective_itemtype;
            my $datedue = C4::Circulation::CalcDateDue( $issuedate, $itype, $hold->branchcode, $hold->borrower->unblessed );
            
            $mediaItem->{"StatusId"}   = 0; 
            if ( DateTime->compare( $datedue, $compareAvailableDay ) < 0 ) {
                $mediaItem->{"StatusId"}  = 1;
            }
            $mediaItem->{"DateAvail"}  = $datedue->datetime();
            $mediaItem->{"StatusName"} = "Vorgemerkt zur Abholung";
            $mediaItem->{"Available"}  = JSON::false; 
        }
        push @$mediaItemsList, $mediaItem;
    }
    
    return undef if ( scalar(@$mediaItemsList) == 0 );
    
    my $detailURL = $self->{opacurl} . '/cgi-bin/koha/opac-detail.pl?biblionumber=' . $biblionumber;
    my $searchURL = $self->{opacurl} . '/cgi-bin/koha/opac-search.pl?q=';
    if ( scalar(@$searchisbn) ) {
        $searchURL .= uri_escape('('. join(" OR ",@$searchisbn) . ')');
    } else {
        $searchURL = $detailURL;
    }
    
    my $year = "";
    foreach my $field ($record->field('260','264')) {
        if ( $field->subfield('c') ) {
            $year = $field->subfield('c');
            if ( $year =~ /([12][0-9][0-9][0-9])/ ) {
                $year = $1;
            }
            last;
        }
    }
    
    my $annotation = "";
    foreach my $field ($record->field('520')) {
        if ( $field->indicator(1) eq '8' && $field->subfield('a') ) {
            $annotation = $field->subfield('a');
            last;
        }
    }
    if ( !$annotation ) {
        foreach my $field ($record->field('520')) {
            if ( $field->indicator(1) eq '1' ) {
                if ( $field->subfield('b') ) {
                    $annotation = $field->subfield('b');
                    last;
                }
                elsif ( $field->subfield('a') ) {
                    $annotation = $field->subfield('a');
                    last;
                }
            }
        }
    }
    if ( !$annotation ) {
        foreach my $field ($record->field('520')) {
            if ( $field->indicator(1) ne '1' && $field->indicator(1) ne '8' ) {
                if ( $field->subfield('a') ) {
                    $annotation = $field->subfield('a');
                    last;
                }
            }
        }
    }
    
    my $result = {
                    "Autor"            => $authors,
                    "Title"            => $title,
                    "TitleAddition"    => $subtitle,
                    "ISBN"             => $isbns,
                    "EAN"              => $eans,
                    "MediaGroupName"   => $itemtype,
                    "MediaArtName"     => "",
                    "DetailUrl"        => $detailURL,
                    "SearchUrl"        => $searchURL,
                    "PublishingYear"   => $year,
                    "Annotation"       => $annotation,
                    "MediaItems"       => $mediaItemsList
              };

    if ( $self->{MediaGroupUnionMappingDefined} && $itemtypeCode ) {
        if ( exists($self->{MediaGroupUnionMapping}->{$itemtypeCode}) ) {
            $result->{MediaGroupUnion} = $self->{MediaGroupUnionMapping}->{$itemtypeCode};
        }
        elsif ( exists($self->{MediaGroupUnionMapping}->{"*"}) ) {
            $result->{MediaGroupUnion} = $self->{MediaGroupUnionMapping}->{"*"};
        }
    }
    return $result;
}

sub getExcludedItypes {
    my $self = shift;
    
    my @itypes;
    my $exludedItypesConfig = C4::Context->preference("Biblio18ExcludedItemtypes") || $self->{excludedItemTypes} || "";
    foreach my $itype( split(/[,|]/, $exludedItypesConfig) ) {
        $itype =~ s/(^\s+|\s+$)// if ( $itype );
        push @itypes, $itype;
    }
    return @itypes;
}

sub createQueryString {
    my $self = shift;
    my $querystring = shift;
    
    $querystring = '' if (! $querystring );
    $querystring =~ s/(^\s+|\s+$)// if ( $querystring );
    
    return '' if (! $querystring);
    
    my @querywords = split(/\s+/,$querystring);
    
    my $queryIndexes = C4::Context->preference("Biblio18QueryIndexes") || $self->{queryIndexes} || "";
    my $query = '';
    my @indexes;
    foreach my $index( split(/[,|]/, $queryIndexes) ) {
        $index =~ s/(^\s+|\s+$)// if ( $index );
        push @indexes, $index if ($index);
    }
    
    if ( scalar(@indexes) ) {
        foreach my $word(@querywords) {
            my @searchword;
            foreach my $index(@indexes) {
                push @searchword,"$index:($word)";
            }
            if ( scalar(@searchword) > 1 ) {
                $query .= ' AND ' if ( $query );
                $query .= '(' . join(' OR ', @searchword) . ')';
            }
            elsif ( scalar(@searchword) == 1 ) {
                $query .= ' AND ' if ( $query );
                $query .= $searchword[0];
            }
        }
        $query = '(' . $query . ')' if ($query);
    }
    else {
        $query = $querystring;
    }
    
    my @excludedItypes = $self->getExcludedItypes();
    my $searchAdd = C4::Context->preference("Biblio18QueryStaticSupplement") || $self->{searchAdd} || "";
    my $itypeAdd = join('") OR ("',@excludedItypes);
    $itypeAdd = 'NOT itype:(("' . $itypeAdd . '"))' if ($itypeAdd);
    my $availableSince = C4::Context->preference("Biblio18QueryAvailableSince") || $self->{available_since} || "";
    if ( $availableSince && $availableSince =~ /([0-9]+)/ ) {
        my $dt = DateTime->now;
        $dt->add( days => -$1 );
        my $accessiondate = $dt->ymd;
        $query .= " AND acqdate:(<=$accessiondate)";
    }

    $query .= " " . $itypeAdd if ( $itypeAdd );
    $query .= " " . $searchAdd if ( $searchAdd );
    
    return $query;
}

1;
