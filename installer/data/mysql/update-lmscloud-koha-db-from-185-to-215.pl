#!/usr/bin/perl

use Modern::Perl;
use utf8;

use DBI;
use Getopt::Long;
# Koha modules
use C4::Context;

binmode(STDOUT, ":utf8");

updateSimpleVariables();
updateMoreSearchesContent();
updateEntryPages();
updateSidebarLinks();

sub updateSimpleVariables {
    my $dbh = C4::Context->dbh;
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='Mana' and value='2'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='UsageStats' and value='2'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='OpacBrowseSearch' and value='1'");
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
        
        $value =~ s/(<div[^>]*class\s*=\s*")(([^"]*)(span([1-9][0-2]?))([^"]*))("[^>]*>)/"$1".updateClass($2,$4,"col-lg-$5 entry-page-col")."$7"/eg;
        $value =~ s/(<div[^>]*class\s*=\s*")(([^"]*)(row-fluid)([^"]*))("[^>]*>)/"$1".updateClass($2,$4,"row entry-page-row")."$6"/eg;

        # replace comments
        $value =~ s/span([1-9][0-2]?)/col-lg-$1/g;
    
        # replace breadcrumb
        if ( $value !~ /<nav aria-label="breadcrumb">/ ) {
            $value =~ s/\n\s*(<ul\s+class\s*=\s*"\s*breadcrumb\s*">.*<\/ul>)/"\n" . replaceBreadcrumb($1)/es;
        }

        # replace rss feed image
        $value =~ s!<img src="[^"]*feed-icon-16x16.png">!<i class="fa fa-rss" aria-hidden="true"></i>!sg;
        
        $value =~ s!(<a\s+href\s*=\s*\'opac-search\.pl\?q=)([^\']+)(\')!"$1".updateQuery($2)."$3"!seg;
        $value =~ s!(<a\s+href\s*=\s*\"opac-search\.pl\?q=)([^\"]+)(\")!"$1".updateQuery($2)."$3"!seg;

    
        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
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
