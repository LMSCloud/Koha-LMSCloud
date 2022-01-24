#!/usr/bin/perl

use Modern::Perl;
use utf8;

use DBI;
use Getopt::Long;
# Koha modules
use C4::Context;
use Koha::SearchEngine::Elasticsearch;
use Text::Diff qw(diff);

# additional for epayment migration
use Archive::Extract;
use Mojo::UserAgent;
use File::Copy;
use File::Temp;
use Capture::Tiny;
use Koha::Plugins;


BEGIN{ $| = 1; }

binmode(STDIN, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

updateSimpleVariables();
updateMoreSearchesContent();
updateEntryPages();
updateVariablesInNewsTexts();
updateSidebarLinks();
updateOPACUserJS();
rebuildElasticSearchIndex();

&migrate_epayment_to_2105('LMSC');
&migrate_epayment_to_2105('KohaPayPal');



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




# Called individually for each Koha instance of the current host:
# - Check if epayment methods of LMSCloud origin are activated.
#   If this is the case then
#   - fetch the Koha plugin E-Payments-DE from orgaknecht.lmscloud.net
#   - install the Koha plugin E-Payments-DE for the current Koha instance
#   - migrate configuration values of all LMSCloud epayment methods from old systempreferences to new entries in koha_plugin_com_lmscloud_epaymentsde_preferences and to plugin_data.enable_opac_payments
#   - delete the old epayment systempreferences, with exception of 'PaymentsMinimumPatronAge'
#   - do not delete the systempreference 'ActivateCashRegisterTransactionsOnly', because it is not only relevant for epayment.
#   - do not delete the systempreferences 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber' if the standard Koha PayPal e-payment is activated.
#
# - Check if epayment methods of the standard Koha Paypal e-payment is activated.
#   If this is the case then
#   - fetch the adapted Koha plugin pay_via_paypal_lmsc from orgaknecht.lmscloud.net
#   - install the Koha plugin pay_via_paypal_lmsc for the current Koha instance
#   - migrate configuration values of the standard Koha PayPal e-payment method from old systempreferences to new entries in koha_plugin_com_theke_payviapaypal_pay_via_paypal and to plugin_data.enable_opac_payments, plugin_data.PayPalSandboxMode, plugin_data.useBaseURL,
#   - one could delete the old standard Koha PayPal e-payment systempreferences, with exception of 'PaymentsMinimumPatronAge', 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber'
#     (but because this will be done by the standard Koha updateDatabase.pl we skip it here)
#   - do not delete the systempreference 'ActivateCashRegisterTransactionsOnly', because it is not only relevant for epayment.

sub migrate_epayment_to_2105 {
    my ( $migType ) = @_;    # 'LMSC': migrate the LMSC e-payment solutions (GiroSolution, Epay21, PmPayment, EPayBL)   'KohaPayPal': migrate the standard Koha e-payment solution for PayPal

    sub trace {
        my ( $logline ) = @_;
        my $debug = $ENV{'DEBUG_MIGRATE_EPAYMENT'};

        print $logline if $debug;
    }

    sub read_systempreferences {
        my ( $dbh, $selVariable ) = @_;
        my $retValue = '';
	    &trace("migrate_epayment_to_2105::read_systempreferences() START selVariable:$selVariable:\n");

        my $sqlStatement = q{
            SELECT value
            FROM systempreferences
            WHERE  variable = ?;
        };
        &trace("migrate_epayment_to_2105::read_systempreferences() sqlStatement:$sqlStatement:\n");
        my $sth = $dbh->prepare($sqlStatement);
        $sth->execute($selVariable);

        if ( my ($value ) = $sth->fetchrow ) {
            $retValue = $value;
        }

        &trace("migrate_epayment_to_2105::read_systempreferences() END; selVariable:$selVariable: retValue:$retValue:\n");

        return $retValue;
    }


    sub delete_systempreferences {
        my ( $dbh, $selVariable ) = @_;
        my $retValue = '';
	    &trace("migrate_epayment_to_2105::delete_systempreferences() START selVariable:$selVariable:\n");

        my $sqlStatement = q{
            DELETE
            FROM systempreferences
            WHERE  variable = ?;
        };
        &trace("migrate_epayment_to_2105::delete_systempreferences() sqlStatement:$sqlStatement:\n");
        my $sth = $dbh->prepare($sqlStatement);
        $retValue = $sth->execute($selVariable);

        &trace("migrate_epayment_to_2105::delete_systempreferences() END; selVariable:$selVariable: retValue:$retValue:\n");

        return $retValue;
    }


    sub update_epaymentsde_preferences {
        my ( $dbh, $payment_type, $library_id, $name, $value ) = @_;
	    &trace("migrate_epayment_to_2105::update_epaymentsde_preferences() START payment_type:$payment_type: library_id:$library_id: name:$name: value:$value:\n");

        my $sqlStatement = q{
            UPDATE koha_plugin_com_lmscloud_epaymentsde_preferences
               SET value = ?
             WHERE payment_type = ?
               AND library_id = ?
               AND name = ?;
        };
        &trace("migrate_epayment_to_2105::update_epaymentsde_preferences() sqlStatement:$sqlStatement:\n");
        my $sth = $dbh->prepare($sqlStatement);
        my $res = $sth->execute( $value, $payment_type, $library_id, $name );

        &trace("migrate_epayment_to_2105::update_epaymentsde_preferences() END; res:$res:\n");

        return $res;
    }


    sub update_payviapaypal_pay_via_paypal {
        my ( $dbh, $library_id, $active, $user, $pwd, $signature, $charge_description, $threshold ) = @_;
	    &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() START library_id:" . (defined($library_id)?$library_id:'undef') . ": active:$active: user:$user: pwd:$pwd: signature:$signature: signature:$signature: charge_description:$charge_description: threshold:" . (defined($threshold)?$threshold:'undef') . ":\n");

        my $sqlStatement = '';
        my $sth;
        my $res = 'undefined';
        if ( defined($library_id) ) {
            $sqlStatement = q{
                DELETE FROM koha_plugin_com_theke_payviapaypal_pay_via_paypal WHERE library_id = ?;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute( $library_id );
        } else {
            $sqlStatement = q{
                DELETE FROM koha_plugin_com_theke_payviapaypal_pay_via_paypal WHERE library_id IS NULL;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute(  );
        }
        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() 1. sqlStatement:$sqlStatement: res:$res:\n");

        $sqlStatement = q{
            INSERT IGNORE INTO koha_plugin_com_theke_payviapaypal_pay_via_paypal (library_id, active, user, pwd, signature, charge_description, threshold)  VALUES ( ?, ?, ?, ?, ?, ?, ?);
        };
        $sth = $dbh->prepare($sqlStatement);
        $res = $sth->execute( $library_id, $active, $user, $pwd, $signature, $charge_description, $threshold );
        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() 2. sqlStatement:$sqlStatement: res:$res:\n");

        if ( defined($library_id) ) {
            $sqlStatement = q{
                UPDATE koha_plugin_com_theke_payviapaypal_pay_via_paypal
                   SET active = ?,
                       user = ?,
                       pwd = ?,
                       signature = ?,
                       charge_description = ?,
                       threshold = ?
                 WHERE library_id = ?;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute( $active, $user, $pwd, $signature, $charge_description, $threshold, $library_id );
        } else {
            $sqlStatement = q{
                UPDATE koha_plugin_com_theke_payviapaypal_pay_via_paypal
                   SET active = ?,
                       user = ?,
                       pwd = ?,
                       signature = ?,
                       charge_description = ?,
                       threshold = ?
                 WHERE library_id IS NULL;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute( $active, $user, $pwd, $signature, $charge_description, $threshold );
        }
        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() 3. sqlStatement:$sqlStatement: res:$res:\n");

        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() END; res:$res:\n");

        return $res;
    }


    sub update_plugin_data {
        my ( $dbh, $plugin_class, $plugin_key, $plugin_value ) = @_;
	    &trace("migrate_epayment_to_2105::update_plugin_data() START plugin_class:$plugin_class: plugin_key:$plugin_key: plugin_value:$plugin_value:\n");

        my $sqlStatement = q{
            INSERT IGNORE INTO plugin_data (plugin_class, plugin_key, plugin_value)  VALUES ( ?, ?, ? );
        };
        my $sth = $dbh->prepare($sqlStatement);
        my $res = $sth->execute( $plugin_class, $plugin_key, $plugin_value );
        &trace("migrate_epayment_to_2105::update_plugin_data() 1. sqlStatement:$sqlStatement: res:$res:\n");

        $sqlStatement = q{
            UPDATE plugin_data
               SET plugin_value = ?
             WHERE plugin_class = ?
               AND plugin_key = ?;
        };
        &trace("migrate_epayment_to_2105::update_plugin_data() 2. sqlStatement:$sqlStatement:\n");
        $sth = $dbh->prepare($sqlStatement);
        $res = $sth->execute( $plugin_value, $plugin_class, $plugin_key );

        &trace("migrate_epayment_to_2105::update_plugin_data() END; res:$res:\n");

        return $res;
    }


    sub install_koha_plugin {
        my ( $uploadfilename ) = @_;    # name of the KPZ file
        my $uploaddirname = 'https://configuration.lmscloud.net/pluginstore';
        #my $uploadlocation = '';
        my $uploadlocation = $uploaddirname . '/' . $uploadfilename;
        my $plugins_enabled = C4::Context->config("enable_plugins");
        my $plugins_dir = C4::Context->config("pluginsdir");
        $plugins_dir = ref($plugins_dir) eq 'ARRAY' ? $plugins_dir->[0] : $plugins_dir;
        my ( $tempfile, $tfh );
        my %errors;
        my $res = 'undefinedResult';

        &trace("migrate_epayment_to_2105::install_koha_plugin() START; uploadfilename:$uploadfilename: uploadlocation:$uploadlocation: plugins_enabled:$plugins_enabled:\n");

        if ( ! $plugins_enabled ) {
            # set <enable_plugins>1</enable_plugins> in /etc/koha/sites/<instancename>/koha-conf.xml
            my $kohaConfFileName = $ENV{'KOHA_CONF'};
            `sed -i.bak -e 's|<enable_plugins>.*</enable_plugins>|<enable_plugins>1</enable_plugins>|g' $kohaConfFileName`;
            &trace("migrate_epayment_to_2105::install_koha_plugin() updated '$kohaConfFileName'\n");
        }

        my $dirname = File::Temp::tempdir( CLEANUP => 1 );
        &trace("migrate_epayment_to_2105::install_koha_plugin() dirname:$dirname:\n");

        my $filesuffix;
        $filesuffix = $1 if $uploadfilename =~ m/(\..+)$/i;
        ( $tfh, $tempfile ) = File::Temp::tempfile( SUFFIX => $filesuffix, UNLINK => 1 );

        &trace("migrate_epayment_to_2105::install_koha_plugin() tempfile:$tempfile:\n");

        $errors{'NOTKPZ'} = 1 if ( $uploadfilename !~ /\.kpz$/i );
        $errors{'NOWRITETEMP'}    = 1 unless ( -w $dirname );
        $errors{'NOWRITEPLUGINS'} = 1 unless ( -w $plugins_dir );

        if ( $uploadlocation ) {
            my $ua = Mojo::UserAgent->new(max_redirects => 5);
            my $tx = $ua->get($uploadlocation);
            $tx->result->content->asset->move_to($tempfile);
        } else {
            $errors{'EMPTYUPLOAD'} = 1;
        }

        if ( ! %errors ) {
            my $ae = Archive::Extract->new( archive => $tempfile, type => 'zip' );
            if ( $ae->extract( to => $plugins_dir ) ) {
                &setUserAndGroup( $plugins_dir );

                &trace("migrate_epayment_to_2105::install_koha_plugin() now calling Koha::Plugins->new()->InstallPlugins()\n");
                $res = Koha::Plugins->new()->InstallPlugins();    # returns total count of plugins currently installed on this hosts
            } else {
                $errors{'UZIPFAIL'} = $uploadfilename;
            }
        }

        if ( %errors ) {
            foreach my $key ( keys %errors ) {
                &trace("migrate_epayment_to_2105::install_koha_plugin() errors{$key}:" . $errors{$key} . ":\n");
            }
        }

        &trace("migrate_epayment_to_2105::install_koha_plugin() returns res:$res:\n");
    }

    # recursively set user and group to <koha-Instanz-Name>-koha
    sub setUserAndGroup {
        my ( $dirName ) = @_;
        my $kohaUserName = substr(C4::Context->config('database'),5) . '-koha';    # e.g. koha_wallenheim -> wallenheim-koha

        &trace("migrate_epayment_to_2105::setUserAndGroup() START; dirName:$dirName: kohaUserName:$kohaUserName:\n");

        #`chown -R $kohaUserName:$kohaUserName $dirName`;
        my ($stdoutRes, $stderrRes) = Capture::Tiny::capture {
            system ( "chown -R $kohaUserName:$kohaUserName $dirName" );
        };

        &trace("migrate_epayment_to_2105::setUserAndGroup() tried to chown -R $kohaUserName:$kohaUserName $dirName; stdoutRes:$stdoutRes: stderrRes:$stderrRes:\n");
        if ( $stderrRes ) {
            print "migrate_epayment_to_2105::setUserAndGroup() tried to chown -R $kohaUserName:$kohaUserName $dirName; stdoutRes:$stdoutRes: stderrRes:$stderrRes:\n";
        }
    }

# end of migrate_epayment_to_2105 subs
#################################################################################

    my $dbh = C4::Context->dbh;
    $|=1; # flushes output
    local $dbh->{RaiseError} = 1;

    if ( $migType eq 'LMSC' ) {
        my $lmscPrefCount = 0;
        my $lmscPrefRead = 0;
        my $lmscPrefUpdated = 0;
        my $lmscPrefToDelete = 0;
        my $lmscPrefDeleted = 0;
        my $res = 'noop';

        # systempreferences for the LMSC e-payments (GiroSolution, Epay21, PmPayment, EPayBL)
        my $prefLmsc = {};
        $prefLmsc->{migrate} = 0;    # assumption: no epayment type activated, nothing to migrate

        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{switchName} = 'Epay21PaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{variable}->{Epay21PaypageOpacPaymentsEnabled}->{newName} = 'Epay21PaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{variable}->{Epay21MandantDesc}->{newName} = 'Epay21PaypageMandantDesc';
        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{variable}->{Epay21OrderDesc}->{newName} = 'Epay21PaypageOrderDesc';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21AccountingSystemInfo}->{newName} = 'Epay21AccountingSystemInfo';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21App}->{newName} = 'Epay21App';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21BasicAuthPw}->{newName} = 'Epay21BasicAuthPw';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21BasicAuthUser}->{newName} = 'Epay21BasicAuthUser';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21Mandant}->{newName} = 'Epay21Mandant';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21PaypageWebservicesURL}->{newName} = 'Epay21WebservicesURL';

        $prefLmsc->{pmt}->{epaybl}->{pmv}->{Paypage}->{switchName} = 'EpayblPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epaybl}->{pmv}->{Paypage}->{variable}->{EpayblPaypageOpacPaymentsEnabled}->{newName} = 'EPayBLPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epaybl}->{pmv}->{Paypage}->{variable}->{EpayblPaypagePaypageURL}->{newName} = 'EPayBLPaypageURL';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblAccountingEntryText}->{newName} = 'EPayBLAccountingEntryText';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblDunningProcedureLabel}->{newName} = 'EPayBLDunningProcedureLabel';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblMandatorNumber}->{newName} = 'EPayBLMandatorNumber';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblOperatorNumber}->{newName} = 'EPayBLOperatorNumber';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblPaypageWebservicesURL}->{newName} = 'EPayBLWebservicesURL';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblSaltHmacSha256}->{newName} = 'EPayBLSaltHmacSha256';

        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{switchName} = 'GirosolutionCreditcardOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{variable}->{GirosolutionCreditcardOpacPaymentsEnabled}->{newName} = 'GiroSolutionCreditcardOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{variable}->{GirosolutionCreditcardProjectId}->{newName} = 'GiroSolutionCreditcardProjectId';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{variable}->{GirosolutionCreditcardProjectPwd}->{newName} = 'GiroSolutionCreditcardProjectPwd';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{switchName} = 'GirosolutionGiropayOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{variable}->{GirosolutionGiropayOpacPaymentsEnabled}->{newName} = 'GiroSolutionGiropayOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{variable}->{GirosolutionGiropayProjectId}->{newName} = 'GiroSolutionGiropayProjectId';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{variable}->{GirosolutionGiropayProjectPwd}->{newName} = 'GiroSolutionGiropayProjectPwd';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{switchName} = 'GirosolutionPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageOpacPaymentsEnabled}->{newName} = 'GiroSolutionPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageOrderDesc}->{newName} = 'GiroSolutionPaypageOrderDesc';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageOrganizationName}->{newName} = 'GiroSolutionPaypageOrganizationName';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypagePaytypesTestmode}->{newName} = 'GiroSolutionPaypagePaytypesTestmode';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageProjectId}->{newName} = 'GiroSolutionPaypageProjectId';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageProjectPwd}->{newName} = 'GiroSolutionPaypageProjectPwd';
        $prefLmsc->{pmt}->{girosolution}->{variable}->{GirosolutionMerchantId}->{newName} = 'GiroSolutionMerchantId';
        $prefLmsc->{pmt}->{girosolution}->{variable}->{GirosolutionRemittanceInfo}->{newName} = 'GiroSolutionRemittanceInfo';

        $prefLmsc->{pmt}->{pmpayment}->{pmv}->{Paypage}->{switchName} = 'PmpaymentPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{pmpayment}->{pmv}->{Paypage}->{variable}->{PmpaymentPaypageOpacPaymentsEnabled}->{newName} = 'PmPaymentPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentAccountingRecord}->{newName} = 'PmPaymentAccountingRecord';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentAgs}->{newName} = 'PmPaymentAgs';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentPaypageWebservicesURL}->{newName} = 'PmPaymentWebservicesURL';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentProcedure}->{newName} = 'PmPaymentProcedure';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentRemittanceInfo}->{newName} = 'PmPaymentRemittanceInfo';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentSaltHmacSha256}->{newName} = 'PmPaymentSaltHmacSha256';


        $prefLmsc->{epaymentbase}->{variable}->{ActivateCashRegisterTransactionsOnly}->{newName} = 'EpaymentBaseActivateCashRegisterTransactionsOnly';
        $prefLmsc->{epaymentbase}->{variable}->{PaymentsOnlineCashRegisterManagerCardnumber}->{newName} = 'EpaymentBaseOnlineCashRegisterManagerCardnumber';
        $prefLmsc->{epaymentbase}->{variable}->{PaymentsOnlineCashRegisterName}->{newName} = 'EpaymentBaseOnlineCashRegisterName';

        $prefLmsc->{paypal}->{switchName} = 'EnablePayPalOpacPayments';


        # check if at least 1 LMSC epayment of 18.05 is enabled
        foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
            foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                my $value = &read_systempreferences($dbh, $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{switchName});
                $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{switchValue} = $value;
                if ( $value ) {
                    $prefLmsc->{migrate} = 1;
                    # last;
                }
            }
        }

        # check if the standard Koha PayPal epayment of 18.05 is enabled.
        # In this case do not delete systempreferences 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber'.
        {
            my $value = &read_systempreferences($dbh, $prefLmsc->{paypal}->{switchName});
            $prefLmsc->{paypal}->{switchValue} = $value;
        }

        # read complete LMSC epayment configuration of 18.05
        foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
            &trace("migrate_epayment_to_2105 loop A1 pmnttype:$pmnttype:\n");
            foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                &trace("migrate_epayment_to_2105 loop A2 pmnttype:$pmnttype: pmntvariant:$pmntvariant:\n");
                foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}} ) {
                    &trace("migrate_epayment_to_2105 loop A3 pmnttype:$pmnttype: pmntvariant:$pmntvariant: variable:$variable:\n");
                    $lmscPrefCount += 1;
                    my $value = &read_systempreferences($dbh, $variable);
                    if ( ! $value && $variable =~ /OpacPaymentsEnabled$/ ) {
                        $value = '0';
                    }
                    $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value} = $value;
                    &trace("migrate_epayment_to_2105 loop A3 prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value}:$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value}:\n");
                    if ( defined($value) ) {
                        $lmscPrefRead += 1;
                    }
                }
            }
            foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{variable}} ) {
                &trace("migrate_epayment_to_2105 loop B2 pmnttype:$pmnttype: variable:$variable:\n");
                $lmscPrefCount += 1;
                my $value = &read_systempreferences($dbh, $variable);
                $prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value} = $value;
                &trace("migrate_epayment_to_2105 loop B2 prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value}:$prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value}:\n");
                if ( defined($value) ) {
                    $lmscPrefRead += 1;
                }
            }
        }
        foreach my $variable (sort keys %{$prefLmsc->{epaymentbase}->{variable}} ) {
            &trace("migrate_epayment_to_2105 loop C1 variable:$variable:\n");
            $lmscPrefCount += 1;
            my $value = &read_systempreferences($dbh, $variable);
            $prefLmsc->{epaymentbase}->{variable}->{$variable}->{value} = $value;
            &trace("migrate_epayment_to_2105 loop C1 prefLmsc->{epaymentbase}->{variable}->{$variable}->{value}:$prefLmsc->{epaymentbase}->{variable}->{$variable}->{value}:\n");
            if ( defined($value) ) {
                $lmscPrefRead += 1;
            }
        }
        #&trace("migrate_epayment_to_2105 prefLmsc:" . Dumper($prefLmsc) . ":\n");



        # only if at least 1 LMSC epayment of 18.05 is enabled, we migrate the (complete) LMSC epayment configuration
        if ( $prefLmsc->{migrate} ) {
            # install the plugin E-Payments-DE
            &install_koha_plugin( 'koha-plugin-e-payments-de-v1.0.0.kpz' );

            # store LMSC epayment configuration in 21.05
            foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
                &trace("migrate_epayment_to_2105 loop G1 pmnttype:$pmnttype:\n");
                foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                    &trace("migrate_epayment_to_2105 loop G2 pmnttype:$pmnttype: pmntvariant:$pmntvariant:\n");
                    foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}} ) {
                        my $name = $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{newName};
                        my $value = $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value};
                        &trace("migrate_epayment_to_2105 loop G3 pmnttype:$pmnttype: pmntvariant:$pmntvariant: variable:$variable: name:$name: value:$value:\n");
                        my $res = &update_epaymentsde_preferences( $dbh, $pmnttype, 'default', $name, $value );
                        if ( $res eq '1' ) {
                            $lmscPrefUpdated += 1;
                        }
                    }
                }
                foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{variable}} ) {
                    my $name = $prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{newName};
                    my $value = $prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value};
                    &trace("migrate_epayment_to_2105 loop G2 pmnttype:$pmnttype: variable:$variable: name:$name: value:$value:\n");
                    my $res = &update_epaymentsde_preferences( $dbh, $pmnttype, 'default', $name, $value );
                    if ( $res eq '1' ) {
                        $lmscPrefUpdated += 1;
                    }
                }
            }
            foreach my $variable (sort keys %{$prefLmsc->{epaymentbase}->{variable}} ) {
                &trace("migrate_epayment_to_2105 loop H1 variable:$variable:\n");
                my $name = $prefLmsc->{epaymentbase}->{variable}->{$variable}->{newName};
                my $value = $prefLmsc->{epaymentbase}->{variable}->{$variable}->{value};
                &trace("migrate_epayment_to_2105 loop H1 prefLmsc->{epaymentbase}->{variable}->{$variable}:$variable: name:$name: value:$value:\n");
                my $res = &update_epaymentsde_preferences( $dbh, 'epaymentbase', 'default', $name, $value );
                if ( $res eq '1' ) {
                    $lmscPrefUpdated += 1;
                }
            }
            $res = update_plugin_data( $dbh, 'Koha::Plugin::Com::LMSCloud::EPaymentsDE', 'enable_opac_payments', '1' );
        }

        # In any case we delete the 18.05 system preferences for e-payment, obsolete in 21.05 (exception: ActivateCashRegisterTransactionsOnly, PaymentsMinimumPatronAge)
        foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
            &trace("migrate_epayment_to_2105 loop J1 pmnttype:$pmnttype:\n");
            foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                &trace("migrate_epayment_to_2105 loop J2 pmnttype:$pmnttype: pmntvariant:$pmntvariant:\n");
                foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}} ) {
                    &trace("migrate_epayment_to_2105 loop J3 pmnttype:$pmnttype: pmntvariant:$pmntvariant: variable:$variable:\n");
                    $lmscPrefToDelete += 1;
                    my $delRes = &delete_systempreferences($dbh, $variable);
                    &trace("migrate_epayment_to_2105 loop J3 prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable} deleted:$delRes:\n");
                    if ( defined($delRes) && $delRes == 1 ) {
                        $lmscPrefDeleted += 1;
                    }
                }
            }
            foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{variable}} ) {
                &trace("migrate_epayment_to_2105 loop B2 pmnttype:$pmnttype: variable:$variable:\n");
                $lmscPrefToDelete += 1;
                my $delRes = &delete_systempreferences($dbh, $variable);
                &trace("migrate_epayment_to_2105 loop B2 prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable} deleted:$delRes:\n");
                if ( defined($delRes) && $delRes == 1 ) {
                        $lmscPrefDeleted += 1;
                    }
            }
        }
        foreach my $variable (sort keys %{$prefLmsc->{epaymentbase}->{variable}} ) {
            &trace("migrate_epayment_to_2105 loop C1 variable:$variable:\n");
            if ( $variable eq 'ActivateCashRegisterTransactionsOnly' ) {
                next;
            }
            if ( $variable eq 'PaymentsMinimumPatronAge' ) {
                next;
            }
            if ( $prefLmsc->{paypal}->{switchValue} ) {
                # PayPal requires also in 21.05 the systempreferences 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber'
                if ( $variable eq 'PaymentsOnlineCashRegisterName' ) {
                    next;
                }
                if ( $variable eq 'PaymentsOnlineCashRegisterManagerCardnumber' ) {
                    next;
                }
            }
            $lmscPrefToDelete += 1;
            my $delRes = &delete_systempreferences($dbh, $variable);
            &trace("migrate_epayment_to_2105 loop C1 prefLmsc->{epaymentbase}->{variable}->{$variable} deleted:$delRes:\n");
            if ( defined($delRes) && $delRes == 1 ) {
                $lmscPrefDeleted += 1;
            }
        }


        &trace("migrate_epayment_to_2105 End lmscPrefCount:$lmscPrefCount: lmscPrefRead:$lmscPrefRead: lmscPrefUpdated:$lmscPrefUpdated: lmscPrefToDelete:$lmscPrefToDelete: lmscPrefDeleted:$lmscPrefDeleted: res:$res:\n");

    }


    if ( $migType eq 'KohaPayPal' ) {
        my $paypalPrefCount = 0;
        my $paypalPrefRead = 0;
        my $paypalPrefUpdated = 0;
        my $paypalPrefToDelete = 0;
        my $paypalPrefDeleted = 0;
        my $res = 'noop';

        # systempreferences for the LMSC e-payments (GiroSolution, Epay21, PmPayment, EPayBL)
        my $prefPaypal = {};
        $prefPaypal->{migrate} = 0;    # assumption: no PayPal activated, nothing to migrate

        $prefPaypal->{paypal}->{switchName} = 'EnablePayPalOpacPayments';
        $prefPaypal->{paypal}->{variable}->{EnablePayPalOpacPayments}->{newName} = 'NoDirectEquivalentButIAmHereForDeletionOfMeIn1805Systempreferences';
        $prefPaypal->{paypal}->{variable}->{PayPalChargeDescription}->{newName} = 'charge_description';
        $prefPaypal->{paypal}->{variable}->{PayPalPwd}->{newName} = 'pwd';
        $prefPaypal->{paypal}->{variable}->{PayPalSandboxMode}->{newName} = 'plugin_data.plugin_key';    # to be stored in plugin_data.plugin_key where plugin_class = 'Koha::Plugin::Com::Theke::PayViaPayPal'
        $prefPaypal->{paypal}->{variable}->{PayPalSignature}->{newName} = 'signature';
        $prefPaypal->{paypal}->{variable}->{PayPalUser}->{newName} = 'user';

        # check if the standard Koha PayPal epayment of 18.05 is enabled.
        {
            my $value = &read_systempreferences($dbh, $prefPaypal->{paypal}->{switchName});
            $prefPaypal->{paypal}->{switchValue} = $value;
            if ( $value ) {
                $prefPaypal->{migrate} = 1;
            }
        }


        # read complete PayPal epayment configuration of 18.05
        foreach my $variable (sort keys %{$prefPaypal->{paypal}->{variable}} ) {
            &trace("migrate_epayment_to_2105 loop PPA1 variable:$variable:\n");
            $paypalPrefCount += 1;
            my $value = &read_systempreferences($dbh, $variable);
            $prefPaypal->{paypal}->{variable}->{$variable}->{value} = $value;
            &trace("migrate_epayment_to_2105 loop PPA1 prefPaypal->{paypal}->{variable}->{$variable}->{value}:$prefPaypal->{paypal}->{variable}->{$variable}->{value}:\n");
            if ( defined($value) ) {
                $paypalPrefRead += 1;
            }
        }
        #&trace("migrate_epayment_to_2105 prefPaypal:" . Dumper($prefPaypal) . ":\n");

        # only if PayPal epayment of 18.05 is enabled, we migrate the PayPal specific epayment configuration for the pay_via_paypal plugin.
        # But we continue to use systempreferences 'ActivateCashRegisterTransactionsOnly', 'PaymentsMinimumPatronAge', 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber' also in the pay_via_paypal plugin.
        if ( $prefPaypal->{migrate} ) {
            # install the plugin Pay-Via-PayPal, supplied by Theke Solutions and sligthly modified by LMSCloud
            &install_koha_plugin( 'koha-plugin-pay-via-paypal-v2.3.7_lmsc.kpz' );

            # store PayPal epayment configuration in 21.05 plugin DB table koha_plugin_com_theke_payviapaypal_pay_via_paypal
            {
                my $library_id = undef;
                my $active = 1;
                my $user = $prefPaypal->{paypal}->{variable}->{PayPalUser}->{value};
                my $pwd = $prefPaypal->{paypal}->{variable}->{PayPalPwd}->{value};
                my $signature = $prefPaypal->{paypal}->{variable}->{PayPalSignature}->{value};
                my $charge_description = $prefPaypal->{paypal}->{variable}->{PayPalChargeDescription}->{value};
                my $threshold = undef;

                my $res = &update_payviapaypal_pay_via_paypal( $dbh, $library_id, $active, $user, $pwd, $signature, $charge_description, $threshold );

                if ( $res eq '1' ) {
                    $paypalPrefUpdated += 1;
                }
            }
            $res = update_plugin_data( $dbh, 'Koha::Plugin::Com::Theke::PayViaPayPal', 'useBaseURL', '1' );
            $res += update_plugin_data( $dbh, 'Koha::Plugin::Com::Theke::PayViaPayPal', 'PayPalSandboxMode', $prefPaypal->{paypal}->{variable}->{PayPalSandboxMode}->{value} );
        }

        # In any case we delete the 18.05 system preferences for PayPal epayment, obsolete in 21.05.
        # No, this will be done by the standard Koha updateDatabase.pl, so we skip it here.
#        foreach my $variable (sort keys %{$prefPaypal->{paypal}->{variable}} ) {
#            &trace("migrate_epayment_to_2105 loop PPB1 variable:$variable:\n");
#            $paypalPrefToDelete += 1;
#            my $delRes = &delete_systempreferences($dbh, $variable);
#            &trace("migrate_epayment_to_2105 loop PPB1 prefPaypal->{paypal}->{variable}->{$variable} deleted:$delRes:\n");
#            if ( defined($delRes) && $delRes == 1 ) {
#                    $paypalPrefDeleted += 1;
#                }
#        }

        &trace("migrate_epayment_to_2105 End paypalPrefCount:$paypalPrefCount: paypalPrefRead:$paypalPrefRead: paypalPrefUpdated:$paypalPrefUpdated: paypalPrefToDelete:$paypalPrefToDelete: paypalPrefDeleted:$paypalPrefDeleted: res:$res:\n");
        print "migrate_epayment_to_2105 End paypalPrefCount:$paypalPrefCount: paypalPrefRead:$paypalPrefRead: paypalPrefUpdated:$paypalPrefUpdated: paypalPrefToDelete:$paypalPrefToDelete: paypalPrefDeleted:$paypalPrefDeleted: res:$res:\n";

    }

}

