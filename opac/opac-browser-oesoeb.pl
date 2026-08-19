#!/usr/bin/perl

# Copyright 2018-2026 LMSCloud GmbH
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

=head1 opac-browser-oesoeb.pl

The script is used to read classification values from the browser table
if used to store classification values of the Austrian OeSOeB
(Oesterreichische Systematik fuer Oeffentliche Bibliotheken).

Anders als bei der KAB (opac-browser-kab.pl) oder ASB (opac-browser-asb.pl)
gibt es in der OeSOeB kein Praefix-/Sammlungs-Schema, mit dem dieselbe
Notation je nach Zielgruppe oder Medienart mehrfach belegt wird - Kinder-
und Jugendmedien, Spiele und AV-Medien sind bereits eigene, eigenstaendige
Zweige der Systematik (Notationen "J", "S", "T"). Die browser-Tabelle wird
daher durch oesoeb-systematik.pl ausschliesslich mit den Basisfeldern
level, classification, description, number, endnode, parent (und ggf.
exclude) befuellt - es gibt keine prefix/classval/startrange/endrange
Spalten und somit auch keine Notwendigkeit, wie bei opac-browser-kab.pl
oder opac-browser-asb.pl mehrere parallele Listen (Kinder/Jugend/
Erwachsene/Musik/Spiele/...) getrennt aufzubauen. Es gibt genau eine
flache Liste von Einträgen je Ebene.

Wie bei opac-browser-kab.pl und opac-browser-asb.pl erfolgt die
Navigation ueber die Parameter "level" und "filter", wobei "filter"
direkt den (stabilen) Wert der Spalte "classification" referenziert -
nicht wie bei opac-browser-sys-generic.pl den (fragileren) Text der
Spalte "description". Die Elternbeziehung wird ebenfalls ueber die
Spalte "parent" (die Notation des uebergeordneten Eintrags) aufgeloest,
nicht ueber eine zusammengesetzte Pipe-Kette.

=cut

use Modern::Perl;

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use CGI        qw ( -utf8 );
use C4::Scrubber;
use C4::Koha;    # use getitemtypeinfo

my $query = new CGI;

my $dbh = C4::Context->dbh;

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-browser-oesoeb.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
        debug           => 1,
    }
);

# the level of browser to display
my $level  = $query->param('level') || 0;
my $filter = $query->param('filter');

my $scrubber = C4::Scrubber->new();
$level  = $scrubber->scrub($level)  if ($level);
$filter = $scrubber->scrub($filter) if ($filter);

my ( $countEntries, $countFolders, $levelEntries ) = ( 0, 0, 0 );

$filter = '' unless defined $filter;
$level++;    # the level passed is the level of the PREVIOUS list, not the current one. Thus the ++

# build this level loop
my $sth;

my @level_loop;
my @level_entries_loop;
my @level_folder_loop;
my $myentry;

# Es gibt keine Praefix-/Sammlungsaufteilung wie bei KAB/ASB: die Liste
# der Eintraege dieser Ebene ergibt sich entweder aus den Kindern des
# per "filter" uebergebenen Elternknotens, oder - wenn kein Filter
# gesetzt ist (oberste Ebene) - aus allen Wurzelknoten (level = 1).
if ( $filter ne '' ) {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE parent = ? ORDER BY description");
    $sth->execute($filter);
} else {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE level = 1 ORDER BY description");
    $sth->execute();
}

while ( my $line = $sth->fetchrow_hashref ) {
    $line->{'browse_classification'} = $line->{'classification'};
    $line->{'search'}                = createSearchString($line);
    push @level_entries_loop, $line if $line->{endnode};
    $countEntries++ if $line->{endnode};
    push @level_folder_loop, $line if !$line->{endnode};
    $countFolders++ if !$line->{endnode};
    push @level_loop, $line;
    $levelEntries++;
}

if ( $filter ne '' ) {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ?");
    $sth->execute($filter);
    while ( my $line = $sth->fetchrow_hashref ) {
        $line->{'browse_classification'} = $line->{'classification'};
        $line->{'search'}                = createSearchString($line);
        $myentry                         = $line;
    }
}

my $have_hierarchy = 0;

# now rebuild hierarchy loop by walking up the "parent" chain, which
# holds the classification value (notation) of the parent node - not a
# pipe-joined description path like opac-browser-sys-generic.pl uses.
my @hierarchy_loop;
if ( $filter eq '' and $level == 1 ) {

    # we're starting from the top
    $have_hierarchy = 1 if @level_loop;
} else {
    $sth = $dbh->prepare("SELECT * FROM browser WHERE classification = ?");
    my $val     = $filter;
    my $maxloop = 100;       # safety guard against unexpected parent cycles
    while ( length($val) > 0 && $maxloop > 0 ) {
        $maxloop--;
        $sth->execute($val);
        my $line = $sth->fetchrow_hashref;
        if ($line) {
            $val                             = $line->{'parent'};
            $line->{'browse_classification'} = $line->{'classification'};
            $line->{'search'}                = createSearchString($line);
            unshift @hierarchy_loop, $line;
            last if ( $line->{'level'} eq '1' );
        } else {
            $val = '';
        }
    }
    $have_hierarchy = 1 if @hierarchy_loop;
}

$template->param(
    LEVEL_LOOP         => \@level_loop,
    LEVEL_ENTRIES_LOOP => \@level_entries_loop,
    LEVEL_FOLDER_LOOP  => \@level_folder_loop,
    HIERARCHY_LOOP     => \@hierarchy_loop,
    ENTRY_COUNT        => $countEntries,
    FOLDER_COUNT       => $countFolders,
    LEVEL_COUNT        => $levelEntries,
    LOOP_COUNT         => scalar(@level_loop),
    LEVEL              => $level,
    have_hierarchy     => $have_hierarchy,
    MYENTRY            => $myentry
);

sub createSearchString {
    my $class  = shift;
    my $search = '';

    if ( $class->{classification} ) {
        my $searchval = $class->{classification};
        $searchval =~ s/ /\\ /g;
        $search .= 'sys.phrase:(' . $searchval . '*)';
    }

    return $search;
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
