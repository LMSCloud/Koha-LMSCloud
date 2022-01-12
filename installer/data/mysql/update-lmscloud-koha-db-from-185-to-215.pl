#!/usr/bin/perl

use Modern::Perl;
use utf8;

use DBI;
use Getopt::Long;
# Koha modules
use C4::Context;
use Koha::SearchEngine::Elasticsearch;
use Text::Diff qw(diff);

BEGIN{ $| = 1; }

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

updateSimpleVariables();
updateMoreSearchesContent();
updateEntryPages();
updateVariablesInNewsTexts();
updateSidebarLinks();
updateOPACUserJS();
rebuildElasticSearchIndex();

sub updateSimpleVariables {
    my $dbh = C4::Context->dbh;
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='Mana' and value='2'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='UsageStats' and value='2'");
    $dbh->do("UPDATE systempreferences SET value='Elasticsearch' WHERE variable='SearchEngine'");
    $dbh->do("UPDATE systempreferences SET value='1' WHERE variable='OpacBrowseSearch'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='QueryAutoTruncate'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='QueryFuzzy'");
    $dbh->do("UPDATE systempreferences SET value='relevance' WHERE variable='defaultSortField'");
    $dbh->do("UPDATE systempreferences SET value='dsc' WHERE variable='defaultSortOrder'");
    $dbh->do("UPDATE systempreferences SET value='NOT homebranch:eBib' WHERE variable='ElasticsearchAdditionalAvailabilitySearch'");
    $dbh->do("UPDATE systempreferences SET value='title,author,subject,title-series,local-classification,publyear,subject-genre-form' WHERE variable='ElasticsearchDefaultAutoCompleteIndexFields'");
    $dbh->do(q{UPDATE systempreferences SET value='[{ "name": "ElasticsearchSuggester", "enabled": 1}, { "name": "AuthorityFile"}, { "name": "ExplodedTerms"}, { "name": "LibrisSpellcheck"}]' WHERE variable='OPACdidyoumean'});
    $dbh->do(q{INSERT IGNORE INTO authorised_value_categories(category_name) VALUES ('MARC-FIELD-336-SELECT')});
    $dbh->do(q{INSERT IGNORE INTO authorised_value_categories(category_name) VALUES ('MARC-FIELD-337-SELECT')});
    $dbh->do(q{INSERT IGNORE INTO authorised_value_categories(category_name) VALUES ('MARC-FIELD-338-SELECT')});
    $dbh->do(q{DELETE FROM authorised_values WHERE category ='MARC-FIELD-336-SELECT'});
    $dbh->do(q{DELETE FROM authorised_values WHERE category ='MARC-FIELD-337-SELECT'});
    $dbh->do(q{DELETE FROM authorised_values WHERE category ='MARC-FIELD-338-SELECT'});
    $dbh->do(q{INSERT INTO authorised_values(category,authorised_value,lib) VALUES 
              ('MARC-FIELD-336-SELECT','cod','Computerdaten'),
              ('MARC-FIELD-336-SELECT','cop','Computerprogramm'),
              ('MARC-FIELD-336-SELECT','crd','kartografischer Datensatz'),
              ('MARC-FIELD-336-SELECT','crf','kartografische dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','cri','kartografisches Bild'),
              ('MARC-FIELD-336-SELECT','crm','kartografisches bewegtes Bild'),
              ('MARC-FIELD-336-SELECT','crn','kartografische taktile dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','crt','kartografisches taktiles Bild'),
              ('MARC-FIELD-336-SELECT','ntm','Noten'),
              ('MARC-FIELD-336-SELECT','ntv','Bewegungsnotation'),
              ('MARC-FIELD-336-SELECT','prm','aufgeführte Musik'),
              ('MARC-FIELD-336-SELECT','snd','Geräusche'),
              ('MARC-FIELD-336-SELECT','spw','gesprochenes Wort'),
              ('MARC-FIELD-336-SELECT','sti','unbewegtes Bild'),
              ('MARC-FIELD-336-SELECT','tcf','taktile dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','tci','taktiles Bild'),
              ('MARC-FIELD-336-SELECT','tcm','taktile Noten'),
              ('MARC-FIELD-336-SELECT','tcn','taktile Bewegungsnotation'),
              ('MARC-FIELD-336-SELECT','tct','taktiler Text'),
              ('MARC-FIELD-336-SELECT','tdf','dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','tdi','zweidimensionales bewegtes Bild'),
              ('MARC-FIELD-336-SELECT','tdm','dreidimensionales bewegtes Bild'),
              ('MARC-FIELD-336-SELECT','txt','Text'),
              ('MARC-FIELD-336-SELECT','xxx','Sonstige'),
              ('MARC-FIELD-336-SELECT','zzz','nicht spezifiziert'),
              ('MARC-FIELD-337-SELECT','c','Computermedien'),
              ('MARC-FIELD-337-SELECT','e','stereografisch'),
              ('MARC-FIELD-337-SELECT','g','projizierbar'),
              ('MARC-FIELD-337-SELECT','h','Mikroform'),
              ('MARC-FIELD-337-SELECT','n','ohne Hilfsmittel zu benutzen'),
              ('MARC-FIELD-337-SELECT','p','mikroskopisch'),
              ('MARC-FIELD-337-SELECT','s','audio'),
              ('MARC-FIELD-337-SELECT','v','video'),
              ('MARC-FIELD-337-SELECT','x','Sonstige'),
              ('MARC-FIELD-337-SELECT','z','nicht spezifiziert'),
              ('MARC-FIELD-338-SELECT','ca','Magnetbandcartridge'),
              ('MARC-FIELD-338-SELECT','cb','Computerchip-Cartridge'),
              ('MARC-FIELD-338-SELECT','cd','Computerdisk'),
              ('MARC-FIELD-338-SELECT','ce','Computerdisk-Cartridge'),
              ('MARC-FIELD-338-SELECT','cf','Magnetbandkassette'),
              ('MARC-FIELD-338-SELECT','ch','Magnetbandspule'),
              ('MARC-FIELD-338-SELECT','ck','Speicherkarte'),
              ('MARC-FIELD-338-SELECT','cr','Online-Ressource'),
              ('MARC-FIELD-338-SELECT','cz','Sonstige Computermedien'),
              ('MARC-FIELD-338-SELECT','eh','Stereobild'),
              ('MARC-FIELD-338-SELECT','es','Stereografische Disk'),
              ('MARC-FIELD-338-SELECT','ez','Sonstige stereografische Datenträger'),
              ('MARC-FIELD-338-SELECT','gc','Filmstreifen-Cartridge'),
              ('MARC-FIELD-338-SELECT','gd','Filmstreifen für Einzelbildvorführung'),
              ('MARC-FIELD-338-SELECT','gf','Filmstreifen'),
              ('MARC-FIELD-338-SELECT','gs','Dia'),
              ('MARC-FIELD-338-SELECT','gt','Overheadfolie'),
              ('MARC-FIELD-338-SELECT','ha','Mikrofilmlochkarte'),
              ('MARC-FIELD-338-SELECT','hb','Mikrofilm-Cartridge'),
              ('MARC-FIELD-338-SELECT','hc','Mikrofilmkassette'),
              ('MARC-FIELD-338-SELECT','hd','Mikrofilmspule'),
              ('MARC-FIELD-338-SELECT','he','Mikrofiche'),
              ('MARC-FIELD-338-SELECT','hf','Mikrofichekassette'),
              ('MARC-FIELD-338-SELECT','hg','Lichtundurchlässiger Mikrofiche'),
              ('MARC-FIELD-338-SELECT','hh','Mikrofilmstreifen'),
              ('MARC-FIELD-338-SELECT','hj','Mikrofilmrolle'),
              ('MARC-FIELD-338-SELECT','hz','Sonstige Mikroformen'),
              ('MARC-FIELD-338-SELECT','mc','Filmdose'),
              ('MARC-FIELD-338-SELECT','mf','Filmkassette'),
              ('MARC-FIELD-338-SELECT','mo','Filmrolle'),
              ('MARC-FIELD-338-SELECT','mr','Filmspule'),
              ('MARC-FIELD-338-SELECT','mz','Sonstige projizierbare Bilder'),
              ('MARC-FIELD-338-SELECT','na','Rolle'),
              ('MARC-FIELD-338-SELECT','nb','Blatt'),
              ('MARC-FIELD-338-SELECT','nc','Band'),
              ('MARC-FIELD-338-SELECT','nn','Flipchart'),
              ('MARC-FIELD-338-SELECT','no','Karte'),
              ('MARC-FIELD-338-SELECT','nr','Gegenstand'),
              ('MARC-FIELD-338-SELECT','nz','Sonstige Datenträger, die ohne Hilfsmittel zu benutzen sind'),
              ('MARC-FIELD-338-SELECT','pp','Objektträger'),
              ('MARC-FIELD-338-SELECT','pz','Sonstige Mikroskop-Anwendungen'),
              ('MARC-FIELD-338-SELECT','sd','Audiodisk'),
              ('MARC-FIELD-338-SELECT','se','Phonographenzylinder'),
              ('MARC-FIELD-338-SELECT','sg','Audiocartridge'),
              ('MARC-FIELD-338-SELECT','si','Tonspurspule'),
              ('MARC-FIELD-338-SELECT','sq','Notenrolle'),
              ('MARC-FIELD-338-SELECT','ss','Audiokassette'),
              ('MARC-FIELD-338-SELECT','st','Tonbandspule'),
              ('MARC-FIELD-338-SELECT','sz','Sonstige Tonträger'),
              ('MARC-FIELD-338-SELECT','vc','Videocartridge'),
              ('MARC-FIELD-338-SELECT','vd','Videodisk'),
              ('MARC-FIELD-338-SELECT','vf','Videokassette'),
              ('MARC-FIELD-338-SELECT','vr','Videobandspule'),
              ('MARC-FIELD-338-SELECT','vz','Sonstige Videodatenträger'),
              ('MARC-FIELD-338-SELECT','zu','nicht spezifiziert')});
    $dbh->do(q{UPDATE marc_subfield_structure SET value_builder='marc21_field_rda.pl' WHERE tagfield IN ('336','337','338') AND tagsubfield='a' AND frameworkcode = ''});
    $dbh->do(q{UPDATE marc_subfield_structure SET hidden='0' WHERE tagfield IN ('336','337','338') AND tagsubfield='2' AND frameworkcode = ''});
}

sub updateSidebarLinks {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable like 'OpacDetailBookShopLinkContent%' or variable = 'OpacDetailBookShopLinkContent'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        $value =~ s/<li>\s*<a role="menuitem"/<a class="dropdown-item"/gs;
        $value =~ s/<\/li>//gs;
        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}

sub whitener {
    my $searchstring = shift;
    $searchstring =~ s/(\s)/\\$1/g;
    return $searchstring;
}

sub replaceWhitespaceInPhraseSearchKeepingTTSyntax {
    my $searchstring = shift;
    $searchstring =~ s/([^\[%]+)(?!%\])(?=(\[%|$))/whitener($1)/eg;
    $searchstring =~ s/(?<=\[%)([^%|]*[^\s])(?=\s*[%|])/$1.replace(' ','\\ ')/g;
    return $searchstring;
}

sub replaceModifierList {
    my $index = shift;
    my $modifierlist = shift;
    my $searchstring = shift;
    my $quotionMark = '';
    
    if ( $searchstring =~ s/^\s*"(.*)"$/$1/ ) {
        $quotionMark = '"';
    }
    elsif ( $searchstring =~ s/^\s*&quot;(.*)&quot;$/$1/ ) {
        $quotionMark = '&quot;';
    }
    elsif ( $searchstring =~ s/^\s*'(.*)'$/$1/ ) {
        $quotionMark = "'";
    }
    
    my %modifier;
    
    # print "Index ($index), modifier ($modifierlist), search ($searchstring) $quotionMark\n";
    foreach my $mod( grep { $_ =~ s/(^\s+|\s+$)//; $_ ne '' } split(/,/,$modifierlist) ) {
        $modifier{$mod}=1;
    }
    
    $index = 'ocn' if ( $index eq 'lcn' && $searchstring =~ /^\s*(sfb|kab|ssd|asb)/ );
    
    if ( ((defined $modifier{ltrn} && defined $modifier{rtrn}) || defined $modifier{lrtrn} ) && (defined $modifier{phr} || defined $modifier{'first-in-subfield'})  && defined $modifier{ext} ) {
        $searchstring = replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring = '*' . $searchstring . '*';
        $index .= '.phrase';
    }
    elsif ( defined $modifier{rtrn} && (defined $modifier{phr} || defined $modifier{'first-in-subfield'}) ) {
        $searchstring = replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring .= '*';
        $index .= '.phrase';
    }
    elsif ( defined $modifier{ltrn} && (defined $modifier{phr} || defined $modifier{'first-in-subfield'}) ) {
        $searchstring =~ replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring = '*' . $searchstring;
        $index .= '.phrase';
    }
    elsif ( (defined $modifier{phr} || defined $modifier{'first-in-subfield'}) && defined $modifier{ext} ) {
        $searchstring = "$quotionMark$searchstring$quotionMark";
        $index .= '.phrase';
    }
    elsif ( defined $modifier{'first-in-subfield'} ) {
        $searchstring = replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring = '*' . $searchstring . '*';
        $index .= '.phrase';
    }
    elsif ( defined $modifier{phr} ) {
        $searchstring = "($searchstring)";
    }
    elsif ( (defined $modifier{'st-numeric'} || defined $modifier{'st-date-normalized'} || defined $modifier{'st-date'}) || defined $modifier{ge} || defined $modifier{gt} || defined $modifier{le} || defined $modifier{le} ) {
        if ( defined $modifier{ge} ) {
            $searchstring = "(>=$searchstring)";
        }
        elsif ( defined $modifier{gt} ) {
            $searchstring = "(>$searchstring)";
        }
        elsif ( defined $modifier{le} ) {
            $searchstring = "(<=$searchstring)";
        }
        elsif ( defined $modifier{lt} ) {
            $searchstring = "(<$searchstring)";
        }
        else {
            $searchstring = "($searchstring)";
        }
    }
    elsif( $quotionMark && $searchstring =~ /\s/ ) {
        $searchstring = "($searchstring)";
    }
    
    return "$index:$searchstring";
}

sub updateQuery {
    my $query = shift;
    
    $query =~ s/(\s+(and|or|not)\s+)/uc($1)/seg;
    $query =~ s/=/:/sg;
    $query =~ s/(^|\W)([a-zA-Z][a-z0-9A-Z-]*)(((\,|%2[Cc])(ext|phr|rtrn|ltrn|st-numeric|gt|ge|lt|le|eq|st-date-normalized|st-date|startswithnt|first-in-subfield))*)([:=]|%3[Aa])\s*(["][^"]+["]|&quot;[^"]+&quot;|['][^']+[']|[^\s]+)/$1.replaceModifierList($2,$3,$8)/eg;
    
    # rtrn : right truncation
    # ltrn : left truncation
    # lrtrn : left and right truncation
    # st-date : type date
    # st-numeric : type number (integer)
    # ext : exact search on whole subfield (does not work with icu)
    # phr : search on phrase anywhere in the subfield
    # startswithnt : subfield starts with

    return $query;
}

sub updateEntryPages {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable like 'OpacEntryPage%'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        my $imageAltAdded = 0;
        ($value,$imageAltAdded) = replaceEntryPageContent($value);
    
        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable.", ($imageAltAdded ? " $imageAltAdded image alt attributes added." : ""), "\n";
        }
    }
}

sub updateVariablesInNewsTexts {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT branchcode, lang, content FROM opac_news WHERE title like 'OpacNavRight%' OR title like 'OpacMainPageLeftPanel%' OR title like 'OpacMainUserBlock%'");
    $sth->execute;
    while ( my ($branchcode,$lang,$content) = $sth->fetchrow ) {
        my $origvalue = $content;
        my $imageAltAdded = 0;
        ($content,$imageAltAdded) = replaceEntryPageContent($content);
    
        if ( $origvalue ne $content ) {
            $dbh->do("UPDATE opac_news SET content=? WHERE lang=? and branchcode=?", undef, $content, $lang, $branchcode);
            print "Updated opac_news $lang.", ($imageAltAdded ? " $imageAltAdded image alt attributes added." : ""), "\n";
        }
    }
}

sub replaceEntryPageContent {
    my $value = shift;
    
    $value =~ s/(<div[^>]*class\s*=\s*")(([^"]*)(span([1-9][0-2]?))([^"]*))("[^>]*>)/"$1".updateClass($2,$4,"col-lg-$5 entry-page-col")."$7"/eg;
    $value =~ s/(<div[^>]*class\s*=\s*")(([^"]*)(row-fluid)([^"]*))("[^>]*>)/"$1".updateClass($2,$4,"row entry-page-row")."$6"/eg;

    # replace spans
    $value =~ s/span([1-9][0-2]?)/col-lg-$1/g;

    # replace breadcrumb
    if ( $value !~ /<nav aria-label="breadcrumb">/ ) {
        $value =~ s/\n\s*(<ul\s+class\s*=\s*"\s*breadcrumb\s*">.*<\/ul>)/"\n" . replaceBreadcrumb($1)/es;
    }

    # replace rss feed image
    $value =~ s!<img src="[^"]*feed-icon-16x16.png">!<i class="fa fa-rss" aria-hidden="true"></i>!sg;
    
    $value =~ s!(<a\s+href\s*=\s*\'opac-search\.pl\?q=)([^\']+)(\')!"$1".updateQuery($2)."$3"!seg;
    $value =~ s!(<a\s+href\s*=\s*\"opac-search\.pl\?q=)([^\"]+)(\")!"$1".updateQuery($2)."$3"!seg;

    my $documentTree = getDocumentTree($value);
    my $changes = getElementsByName($documentTree, "img", \&addImageAltAttributeFromLegend);
    $value = getDocumentFromTree($documentTree);
    
    return ($value,$changes);
}

sub replaceBreadcrumb {
    my ($oldbreadcrumb) = @_;
    
    my $newbreadcrumb = '    <nav aria-label="breadcrumb">' . "\n".
                        '        <ul class="breadcrumb">' . "\n";
    while ( $oldbreadcrumb =~ m{(<li>(.*?)</li>)}g ) {
        $newbreadcrumb .= '                <li class="breadcrumb-item">' . "\n";
        $newbreadcrumb .= '                    ' . removeDivider($2) . "\n";
        $newbreadcrumb .= '                </li>' . "\n";
    }
    $newbreadcrumb .= '        </ul>' . "\n";
    $newbreadcrumb .= '    </nav>' . "\n";
    
    # print "$oldbreadcrumb\n$newbreadcrumb\n";
    return $newbreadcrumb;
}

sub removeDivider {
    my ($dividervalue) = @_;
    
    $dividervalue =~ s!\s*<span class="divider">&rsaquo;</span>\s*!!mg;
    
    return $dividervalue;
}

sub updateClass {
    my ($classlist, $oldclass, $newclass) = @_;
    
    my @classes = split(/\s+/,$classlist);
    my @newclasses;
    foreach my $class(@classes) {
        if ( $class eq $oldclass ) {
            $class = $newclass;
        }
        push @newclasses, $class;
    }
    return join(" ",@newclasses);
}

sub removeLineTrimmed {
    my $text = shift;
    my $replacements = shift;
    
    foreach my $repl(@$replacements) {
        $text =~ s/[\n][ \t]*\Q$repl\E[ \t]*//g;
    }
    return $text;
}

sub updateMoreSearchesContent {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable like 'OpacMoreSearchesContent_%'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        $value =~ s/<ul>/<ul class="nav" id="moresearches">/;
        $value =~ s/<li>/<li class="nav-item">/g;

        if ( $value !~ m!<a href="/cgi-bin/koha/opac-browse\.pl">! ) {
            my $replace = q{ [% IF Koha.Preference('SearchEngine') == 'Elasticsearch' && Koha.Preference( 'OpacBrowseSearch' ) == 1 %]<li class="nav-item"><a href="/cgi-bin/koha/opac-browse.pl"><i class="fa fa-search-plus" style="color:#4caf50"></i> Indexsuche</a></li>[% END %]};
            if ( $variable =~ /_en$/ ) {
                $replace = q{ [% IF Koha.Preference('SearchEngine') == 'Elasticsearch' && Koha.Preference( 'OpacBrowseSearch' ) == 1 %]<li class="nav-item"><a href="/cgi-bin/koha/opac-browse.pl"><i class="fa fa-search-plus" style="color:#4caf50"></i> Index search</a></li>[% END %]};
            }
            if ( $value =~ m!<li[^>]*><a href="/cgi-bin/koha/opac-search\.pl">(.|\n)*?</li>! ) {
                $value =~ s!(<li[^>]*><a href="/cgi-bin/koha/opac-search\.pl">(.|\n)*?</li>)!"$1\n$replace"!e;
            }
        }

        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}

sub updateOPACUserJS {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable = 'OPACUserJS'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        my @replace;
        $replace[0] = '$("#availability_facet").hide();';
        $replace[1] = '$("h5#facet-locations").text("Standorte");';
        $value = removeLineTrimmed($value,\@replace);

        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}

sub rebuildElasticSearchIndex {
    # Loading Elasticsearch index configuration
    system "/usr/share/koha/bin/search_tools/rebuild_elasticsearch.pl --reset --biblios --verbose --commit 5000 --processes 4";
}


sub getElementAttributeValues {
    my $value = shift;
    
    my $origvalue = $value;
    my $singlequotes = 0;
    if ( $value =~ s/^"([^"]*)"$/$1/ ) {
        $singlequotes = 0;
    }
    elsif ( $value =~ s/^'([^']*)'$/$1/ ) {
        $singlequotes = 1;
    }
    
    my $ret = { origvalue => $origvalue, value => $value, singlequotes => $singlequotes };
    foreach my $val(split(/\s+/,$value)) {
        $ret->{values}->{$val} = 1 if ($val);
    }
    
    return $ret;
}

sub addElementToDocumentTree {
    my ($elementTree,$isEnd,$tagname,$attrtext,$follows,$fullcontent) = @_;
    
    my $attributes = {};
    my $retElem = $elementTree;
    
    my $attrnum = 0;
    while ( $attrtext =~ s/^\s*([\w\-_]+)\s*=\s*("[^"]*"|'[^']*')\s*// ) {
        $attributes->{$1} = getElementAttributeValues($2); 
        $attributes->{$1}->{attrnumber} = ++$attrnum;
    }
    if ( $follows =~ /^(\s*)\/>/ ) {
        my $newElement = { name => $tagname, type => 'elem', tree => [], parent => $elementTree, attributes => $attributes, attrcount => $attrnum, ended => 1, attradd => $attrtext, endfound => 0, spaceend => $1 };
        push @{$elementTree->{tree}}, $newElement;
        $follows =~ s/^\s*[\/>]+//;
        if ( $follows ) {
            push @{$elementTree->{tree}}, { type => 'text', content => $follows };
        }
    }
    elsif (! $isEnd ) {
        my $newElement = { name => $tagname, type => 'elem', tree => [], parent => $elementTree, attributes => $attributes, attrcount => $attrnum, ended => 0, attradd => $attrtext, endfound => 0, spaceend => '' };
        push @{$elementTree->{tree}}, $newElement;
        $follows =~ s/^[>]//;
        if ( $follows ) {
            push @{$newElement->{tree}}, { type => 'text', content => $follows };
        }
        $retElem = $newElement;
    }
    else {
        my $checkElem = $elementTree;
        while ( $checkElem && $checkElem->{name} ) {
            if ( $checkElem->{name} eq $tagname ) {
                $checkElem->{endfound} = 1;
                $retElem = $checkElem;
                if ( $retElem->{parent}) {
                    $retElem = $retElem->{parent};
                }
                last;
            } else {
                $checkElem = $checkElem->{parent};
            }
        }
        $follows =~ s/^[>]//;
        if ( defined($follows) ) {
            push @{$retElem->{tree}}, { type => 'text', content => $follows };
        }
    }
    return $retElem;
}

sub getDocumentTree {
    my ($text) = @_;
    
    my $elementTree = { parent => undef, type => 'root', tree => [] };
    my $root = $elementTree;
    while ( $text =~ s/(<(\/?)(\w+)((\s*[\w\-_]+\s*=\s*("[^"]*"|'[^']*'))*)([^<]+))// ) {
        push @{$elementTree->{tree}}, { type => 'text', content => $` } if ( $` );
        $text = $';
        $elementTree = addElementToDocumentTree($elementTree,$2,$3,$4,$7,$1);
    }
    push @{$elementTree->{tree}}, { type => 'text', content => $text } if ( $text );
    return $root;
}

sub getElementsByName {
    my ($subtree,$name,$function,$returnFirst) = @_;
    
    my $ret = 0;
    
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(root|elem)$/ ) {
        if ( exists($subtree->{name}) && $subtree->{name} =~ /$name/i ) {
            if ( $returnFirst ) {
                return $subtree;
            }
            elsif ( $function ) {
                $ret += $function->($subtree);
            }
        }
        elsif ( exists($subtree->{tree}) && scalar(@{$subtree->{tree}}) > 0 ) {
            foreach my $subentry (@{$subtree->{tree}}) {
                my $elem = getElementsByName($subentry,$name,$function,$returnFirst);
                if ( $elem && $returnFirst ) {
                    return $elem;
                }
                else {
                    $ret += $elem;
                }
            }
        }
    }
    
    return $ret;
}

sub getElementByName {
    my ($subtree,$name) = @_;
    return getElementsByName($subtree,$name,undef,1);
}

sub addImageAltAttributeFromLegend {
    my ($imageElement) = @_;

    if ( exists($imageElement->{name}) && $imageElement->{name} =~ /img/i ) {
        if (! exists($imageElement->{attributes}->{alt}) ) {
            # print "img has no alt attribute\n";
            
            my $parent = $imageElement->{parent};
            my $legend = '';
            while ( $parent ) {
                if (    exists($parent->{type}) && $parent->{type} =~ /^(elem)$/ 
                     && exists($parent->{name}) && $parent->{name} =~ /^(div)$/i
                     && exists($parent->{attributes}) && exists($parent->{attributes}->{class}->{values}->{'ui-tabs-panel'})
                   ) 
                {
                    my $legend = getElementByName($parent,'legend');
                    if ($legend) {
                        if ( exists($legend->{tree}) && scalar(@{$legend->{tree}}) > 0 ) {
                            my $txt = $legend->{tree}->[0]->{content};
                            $txt =~ s/(^\s+|\s+$)//g if ($txt);
                            $txt =~ s/["']//g if ($txt);
                            if ( $txt ) {
                                $imageElement->{attributes}->{alt}->{values} = $txt;
                                $imageElement->{attributes}->{alt}->{value} = $txt;
                                $imageElement->{attrcount} += 1;
                                $imageElement->{attributes}->{alt}->{attrnumber} = $imageElement->{attrcount};
                                return 1;
                            }
                        }
                    }
                }
                $parent = $parent->{parent};
            }
        }
    }
    return 0;
}

sub getDocumentFromTree {
    my ($subtree,$level,$txtarr) = @_;
    
    my $ret = 0;
    if (! $level ) {
        $level = 1;
        $txtarr = [];
    }
    
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(root|elem)$/ && exists($subtree->{name})) {
        my $txt = '<' . $subtree->{name};
        if ( $subtree->{attrcount} ) {
            foreach my $attr( sort { $subtree->{attributes}->{$a}->{attrnumber} <=> $subtree->{attributes}->{$b}->{attrnumber} } keys %{$subtree->{attributes}} ) {
                my $attrquote = '"';
                $attrquote = "'" if ( $subtree->{attributes}->{$attr}->{value} =~ /"/ || $subtree->{attributes}->{$attr}->{singlequotes} );
                $txt .= " $attr=$attrquote" . $subtree->{attributes}->{$attr}->{value} . "$attrquote";
            }
        }
        if ( $subtree->{attradd} ) {
            $txt .= $subtree->{attradd};
        }
        $txt .= $subtree->{spaceend} . "/" if ( $subtree->{ended} );
        $txt .= ">";
        push @$txtarr, $txt;
    }
    if ( exists($subtree->{tree}) && scalar(@{$subtree->{tree}}) > 0 ) {
        for (my $i=0;$i<scalar(@{$subtree->{tree}});$i++) {
            getDocumentFromTree($subtree->{tree}->[$i],$level+1,$txtarr);
        }
    }
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(root|elem)$/ && exists($subtree->{name}) && $subtree->{endfound} && !$subtree->{ended} ) {
        push @$txtarr, '</' . $subtree->{name} . '>';
    }
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(text)$/ ) {
        push @$txtarr, $subtree->{content};
    }
    
    if ( $level == 1 ) {
        return join('',@$txtarr);
    }
}
