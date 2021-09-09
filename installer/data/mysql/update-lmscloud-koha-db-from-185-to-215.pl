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
        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}
