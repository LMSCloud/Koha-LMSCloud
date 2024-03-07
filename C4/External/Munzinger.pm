package C4::External::Munzinger;

# Copyright 2017,2023 LMSCloud GmbH
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

use C4::Context;
use C4::Scrubber;
use C4::External::DivibibPatronStatus;
use Koha::Patrons;

use LWP::UserAgent;
use XML::Simple;
use Digest::SHA qw(sha512_hex);
use URI::Escape;
use Data::Dumper;
use Carp;
use Scalar::Util qw(reftype);

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    require Exporter;
    $VERSION = 2.00;
    @ISA = qw(Exporter);
    @EXPORT = qw();
    @EXPORT_OK = qw();
}

=head1 NAME

C4::External::Munzinger - Interface to Munzinger metasearch services

=head1 SYNOPSIS

use C4::External::Munzinger;

my $munzingerService = C4::External::Munzinger->new();

$munzingerService->getCategorySummary($user,'Queen');
$munzingerService->getCategorySummary($user,'Merkel','',20);
$munzingerService->getCategorySummary($user,'Merkel','biographien',25,1);

=head1 DESCRIPTION

The module searches the Munzinger databases for relevant information. A search is done using
a HTTPS GET request. The result is an XML structure defined at https://www.munzinger.de/metasearch/schema.xsd.
The functions perform a simple search and extract the information from the resulting hit list.

=head1 FUNCTIONS

=head2 new

C4::External::Munzinger->new();

Instantiate a new Munzinger service that uses an LWP::UserAgent to perform requests.

=cut

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    
    $self->{'search'} = "https://online.munzinger.de/metasearch/xml/simple";
    $self->{'allsearch'} = "https://online.munzinger.de/search/katalog/query-simple?";

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    
    $self->{'ua'} = $ua;
    
    my %config = ();
    
    my $file = '/etc/koha/munzinger.key';
    if ( -e $file && -f $file ) {
        open(my $fh, '<:encoding(UTF-8)', $file) or carp "Could not open Munzinger configuration file '$file' $!";
        while (<$fh>) {
            next if /^#/; # skip line if it starts with a hash
            chomp; # remove \n 
            my($name,$val) = split '=', $_, 2; #split line into two values, on an = sign
            $val =~ s/^\s+//; $val =~ s/\s+$//;
            $name =~ s/^\s+//; $name =~ s/\s+$//;
            next unless ($val && $name); # make sure the value is set
            $config{$name} = $val;
        }
        close $fh;
    }
    
    carp "salt value not defined in Munzinger config '$file'" if (! exists($config{'salt'}) );
    
    $self->{'salt'} = $config{'salt'} if ( exists($config{'salt'}) );
    $self->{'portalid'} = C4::Context->preference('MunzingerPortalID');
    
    $self->{'conf_ok'} = 0;
    $self->{'conf_ok'} = 1 if ( exists($self->{'salt'}) && exists($self->{'portalid'}) );
    
    $self->{'trace'} = 0;
    $self->{'trace'} = 1 if (C4::Context->preference('MunzingerTraceEnabled'));
    
    $self->{'scrubber'} = C4::Scrubber->new('munzinger');

    return $self;
}

=head2 encryptKey

Munzinger supports communication using an encrypted key. The key is generated for each call using Crypt::CBC.
A library, that wants to use Munzinger must create a key file /etc/koha/munzinger.key containing the two lines
key=<KEY>
iv=<IV>
Ask Munzinger to provide the related data.

=cut

sub encryptKey {
    my $self = shift;
    my $userid = shift;
    
    my $user = 'dummy';
    my $munzingerKey = '';
    
    if ( $userid ) {
        my $patron = Koha::Patrons->find({ userid => $userid } );
        my $patronStatus = C4::External::DivibibPatronStatus->new();
        my $pStatus = $patronStatus->getPatronStatus( $patron );
            
        if ( $pStatus && $pStatus->{status} eq '3' ) {
            $user = $patron->cardnumber;
        }
    }
    
    my $time = time;
    my $key = $self->{'salt'} . ':' . $self->{'portalid'} . ':' . $time . ':' . $user;
    
    my $requestkey = sha512_hex($key);
    
    my $parameters = { 
                        ifmtoken  => $requestkey, 
                        portalid  => $self->{'portalid'},
                        timestamp => $time,
                        user      => $user
                     };
                     
    carp "C4::External::Munzinger->encryptKey() key (salt:portalid:time:userid): $key" if ( $self->{trace} );
    carp "C4::External::Munzinger->encryptKey() SHA512 key: $requestkey" if ( $self->{trace} );
    
    return ($parameters,$requestkey,$key);
}


=head2 simpleSearch

Execute a simple search and return the result as Hash structure parsed with XML::Simple.
In case of an HTTP error it returns undef.

=cut


sub simpleSearch {
    my $self = shift;
    my $userid = shift;
    my $searchtext = shift;
    my $publication = shift;
    my $maxcount = shift || 20;
    my $offset = shift || 0;
    
    return undef if (! $self->{'conf_ok'} );
    
    $searchtext = $self->normalizeSearchRequest($searchtext);
    
    return undef if (! $searchtext );
    
    my ($parameters,$requestkey,$munzingerKey) = $self->encryptKey($userid);

    my $authenticationParametersAdd = '';
    if ( $parameters->{user} ne 'dummy' ) {
        foreach my $parameter (sort keys %$parameters) {
            if ( $parameter ne 'portalid' ) {
                $authenticationParametersAdd .= '&' . uri_escape_utf8($parameter) . '=' . uri_escape_utf8($parameters->{$parameter});
            }
        }
    }
    
    $parameters->{text} = $searchtext;
    
    my $url = $self->{'search'};
    if ( $publication ) {
        if ( $maxcount && $maxcount > 1000 ) {
            $maxcount = 1000;
        }
        if ( $offset ) {
            $parameters->{start} = $offset+1;
        }
        $parameters->{scope} = $publication;
        $parameters->{hits} = 'all';
        $parameters->{size} = $maxcount;
    }
    
    my $linkadd = '';
    
    carp "C4::External::Munzinger->simpleSearch() sending request to url: $url\nwith parameters:" . Dumper($parameters) if ( $self->{trace} );
    my $response = $self->{'ua'}->post($url,$parameters);
    
    carp "C4::External::Munzinger->simpleSearch() returns status: " . $response->status_line if ( $self->{trace} );
    carp "C4::External::Munzinger->simpleSearch() returns content: " . $response->content if ( $self->{trace} );
    
    if ( defined($response) && $response->is_success ) {  
        my $respstruct = XMLin( $response->content, KeyAttr => { hit => 'count' }, ForceArray=> qr/^(hitlist|hit)$/, KeepRoot => 1 );
        
        $respstruct->{'authenticationParameters'} = $authenticationParametersAdd;
        $respstruct->{'searchmunzinger'}  = $self->{'allsearch'} . "stichwort=" . uri_escape_utf8($searchtext) . "&portalid=" . $self->{'portalid'} . $authenticationParametersAdd;
        
        return $respstruct;
    }
    else {
        carp "C4::External::Munzinger->simpleSearch() with URL $url returned with HTTP error code " . $response->error_as_HTML if ($self->{trace});   
    }
    return undef;
}

sub normalizeSearchRequest {
    my $self = shift;
    my $search = shift;
    
    if ( defined($search) ) {
        
        $search =~ s/&quot;//g;
        $search =~ s/(\x{0098}|\x{009c}|\x{00ac})//g;
        $search =~ s/(,\s*)?(homebranch|itype|mc-itype|ccode|mc-ccode|mc-loc|location|datelastborrowed|acqdate|callnum|age|anta|antc|ff7-00|yr|barcode|bib-level|rcn|aud)(,(wrdl|phr|ext|rtrn|ltrn|st-date-normalized|ge|le|st-numeric))*\s*[:=]\s*(["']+[\w&\.\- ]+["']+|[\w&\.\-]+)(\s+(and|or))?//ig;
        
        if ( $search =~ /(sys|lcn)[A-Za-z0-9,-]*[:=]/i ) {
            return '';
        }
        
        $search =~ s/(,\s*)?branch\s*[:=]\s*[\w+\.\-]+(\s+[\w+\.\-]+(?![:]))*//ig;
        $search =~ s/[A-Za-z0-9,-]+\s*[:=]\s*//ig;
        
        $search =~ s/^\s*[0-9-\/]+\s*$//;
        $search =~ s/, / /g;
        $search =~ s/\(\s*\)//g;
        $search =~ s/^\s*(and|or)\s*//;
        $search =~ s/\W(and|or)\s*$//i;
        $search =~ s/\s(and|or)\s/ /i;
        $search =~ s/\s*\(\s*["']([^"']+)["']\s*\)\s*/$1/i;
        $search =~ s/(\s)\s+/$1/g;
        $search =~ s/^\s+//g;
        $search =~ s/\s+$//g;
        $search =~ s/^["']([^"']+)["']$/$1/g;
    }
    
    return $search;
}

=head2 getCategorySummary

Execute a simple search and return the as new data structure grouping the results by facet categories. The return result may look like the following:

{
  'categorycount' => 2,
  'hitcount' => 1013,
  'categories' => [
                    {
                      'id' => 'biographien',
                      'hits' => [
                                  {
                                    'title' => 'Merkel, Angela',
                                    'words' => " Angela <span class=\"highlighter\">Merkel</span> deutsche Physikerin und Politikerin ... www.cdu.de Herkunft Angela Dorothea <span class=\"highlighter\">Merkel</span>, geb. Kasner, wurde am 17.  ...  und SPD 1. Kabinett <span class=\"highlighter\">Merkel</span> 2005-2009 \x{2013} Koalition aus Union ...  und FDP 2. Kabinett <span class=\"highlighter\">Merkel</span> 2009-2013 \x{2013} Koalition aus Union ...  und SPD 4. Kabinett <span class=\"highlighter\">Merkel</span> ab 2018 \x{2013} Koalition aus Union",
                                    'text' => "*\x{a0}17. Juli 1954 Hamburg, deutsche Physikerin und Politikerin; Bundeskanzlerin 2005-2021; Bundesvorsitzende der CDU 2000-2018; Bundesministerin f\x{fc}r Frauen und Jugend (1991-1994) sowie f\x{fc}r Umwelt, Naturschutz und Reaktorsicherheit (1994-1998); CDU/CSU-Fraktionschefin im Bundestag 2002-2005; CDU-Generalsekret\x{e4}rin 1998-2000; MdB ab 1990",
                                    'top' => 'true',
                                    'link' => 'https://online.munzinger.de/document/00000019778?portalid=59013&ifmtoken=a174bdd0f719a38ffcb3f927bdf86f9f5b901c2978dde2e08b8e974d4d6b0a5e5b095ebce9127039300a8592d1b0e3ea0263ca65f2bc77abfca82990b5cc539b&timestamp=1679997969&user=1',
                                    'date' => '06/2023'
                                  },
                                  {
                                    'title' => 'Merkel, Max',
                                    'words' => " Max <span class=\"highlighter\">Merkel</span> \x{f6}sterreichischer Fu\x{df}balltrainer ... bei M\x{fc}nchen (Deutschland) Max <span class=\"highlighter\">Merkel</span> z\x{e4}hlte vor allem in den 60er ... Ruf als Erfolgstrainer. Max <span class=\"highlighter\">Merkel</span> war einer der schillernden, ... Bei Rapid bildete <span class=\"highlighter\">Merkel</span> zusammen mit dem gro\x{df}en Ernst ... <span class=\"highlighter\">Merkel</span> war ein Spieler, der seine ",
                                    'text' => "*\x{a0}7. Dezember 1918 Wien, \x{2020}\x{a0}28. November 2006 Putzbrunn bei M\x{fc}nchen (Deutschland), \x{f6}sterreichischer Fu\x{df}balltrainer; bestritt als Spieler je ein L\x{e4}nderspiel f\x{fc}r \x{d6}sterreich und Deutschland; arbeitete als holl\x{e4}ndischer Nationaltrainer und bei diversen Klubs in \x{d6}sterrreich (Rapid Wien), Deutschland (u. a. Bor. Dortmund, 1860 M\x{fc}nchen, 1. FC N\x{fc}rnberg) und Spanien (FC Sevilla, Atletico Madrid), [...]",
                                    'top' => 'true',
                                    'link' => 'https://online.munzinger.de/document/01000000187?portalid=59013&ifmtoken=a174bdd0f719a38ffcb3f927bdf86f9f5b901c2978dde2e08b8e974d4d6b0a5e5b095ebce9127039300a8592d1b0e3ea0263ca65f2bc77abfca82990b5cc539b&timestamp=1679997969&user=1',
                                    'date' => '48/2006'
                                  },
                                  {
                                    'date' => '09/2009',
                                    'link' => 'https://online.munzinger.de/document/00000018863?portalid=59013&ifmtoken=a174bdd0f719a38ffcb3f927bdf86f9f5b901c2978dde2e08b8e974d4d6b0a5e5b095ebce9127039300a8592d1b0e3ea0263ca65f2bc77abfca82990b5cc539b&timestamp=1679997969&user=1',
                                    'top' => 'true',
                                    'text' => "*\x{a0}1. Oktober 1922 Wien, \x{2020}\x{a0}15. Januar 2006 San Miguel de Allend (Mexiko), \x{f6}sterreichische  Altphilologin und Schriftstellerin; Werke u.\x{a0}a.: \"Das andere Gesicht\", \"Die letzte Posaune\", \"Eine ganz gew\x{f6}hnliche Ehe\", \"Aus den Geleisen\", \"Sie kam zu K\x{f6}nig Salomo\"",
                                    'title' => 'Merkel, Inge',
                                    'words' => " Inge <span class=\"highlighter\">Merkel</span> \x{f6}sterreichische Altphilologin ... +43\x{a0}1\x{a0}4065189 Herkunft Inge <span class=\"highlighter\">Merkel</span>, r\x{f6}m.-kath., wurde 1922 als ... verstorbenen Arzt K. Lucius <span class=\"highlighter\">Merkel</span>, einem Sohn des Malers Georg Joshua <span class=\"highlighter\">Merkel</span>, entstammten die Kinder Eva ... 04; Erz\x{e4}hlungen). 2008:\x{a0}Inge <span class=\"highlighter\">Merkel</span>: \"Das gro\x{df}e Spektakel. Eine"
                                  },
                                  {
                                    'date' => '05/2019',
                                    'link' => 'https://online.munzinger.de/document/00000028067?portalid=59013&ifmtoken=a174bdd0f719a38ffcb3f927bdf86f9f5b901c2978dde2e08b8e974d4d6b0a5e5b095ebce9127039300a8592d1b0e3ea0263ca65f2bc77abfca82990b5cc539b&timestamp=1679997969&user=1',
                                    'text' => "*\x{a0}26. Mai 1964 K\x{f6}ln, deutscher Schriftsteller; Ver\x{f6}ffentl. u.\x{a0}a.: \"Das Jahr der Wunder\",  \"Lichtjahre entfernt\", \"Das Ungl\x{fc}ck der anderen. Kosovo, Liberia, Afghanistan\", \"Bo\", \"Stadt ohne Gott\"",
                                    'title' => 'Merkel, Rainer',
                                    'words' => " Rainer <span class=\"highlighter\">Merkel</span> deutscher Schriftsteller; Ver\x{f6}ffentl ... www.fischerverlage.de Herkunft Rainer <span class=\"highlighter\">Merkel</span> wurde am 26. Mai 1964 in K\x{f6}ln",
                                    'top' => 'true'
                                  }
                                ],
                      'count' => '962',
                      'name' => 'Biographien'
                    },
                    {
                      'name' => 'Filmdienst',
                      'count' => '51',
                      'hits' => [
                                  {
                                    'text' => "Dokumentarisches Portr\x{e4}t \x{fc}ber Angela Merkel, das ihre Biografie und ihre politische Karriere in ein spannungsvolles Verh\x{e4}ltnis setzt, wenngleich die Inhalte ihrer Politik und die Zeitl\x{e4}ufte nur am Rande gestreift werden. In Kombination aus Archivmaterialien und Kurzinterviews treibt die aufw\x{e4}ndig gestaltete [...]",
                                    'title' => 'Merkel - Macht der Freiheit',
                                    'words' => " <span class=\"highlighter\">Merkel</span> - Macht der Freiheit Dokumentarisches Portr\x{e4}t \x{fc}ber Angela <span class=\"highlighter\">Merkel</span>, das ihre Biografie und ihre ... <span class=\"highlighter\">Merkel</span> danach. Manchmal scheinen sich ...  Physikerin, und Angela <span class=\"highlighter\">Merkel</span>, die Politikerin, unterscheiden ... Wesentlichen l\x{e4}sst der Film <span class=\"highlighter\">Merkel</span> selbst sprechen, die an \x{201e}<span class=\"highlighter\">Merkel</span>",
                                    'top' => 'true',
                                    'date' => '48/2022',
                                    'link' => 'https://online.munzinger.de/document/10000049010?portalid=59013&ifmtoken=a174bdd0f719a38ffcb3f927bdf86f9f5b901c2978dde2e08b8e974d4d6b0a5e5b095ebce9127039300a8592d1b0e3ea0263ca65f2bc77abfca82990b5cc539b&timestamp=1679997969&user=1'
                                  }
                                ],
                      'id' => 'film'
                    }
                  ]
}

=cut

sub getCategorySummary {
    my $self = shift;
    my $userid = shift;
    my $searchtext = shift;
    my $publication = shift;
    my $maxcount = shift;
    my $offset = shift || 0;
    
    my $categories = { categorycount => 0, hitcount => 0, categories => [] };
    
    my $result;
    my $authlinkAdd = '';
    
    $result = $self->simpleSearch($userid,$searchtext,$publication,$maxcount,$offset) if ( defined($searchtext) );
    
    if ( defined($result) && exists($result->{'hitlists'} ) ) {
        $categories->{'searchmunzinger'} = $result->{'searchmunzinger'};
        $authlinkAdd = $result->{'authenticationParameters'};
        
        $result = $result->{'hitlists'};
    }
    
    if ( defined($result) && exists($result->{'hitlist'}) ) {
        my @categhits = @{$result->{'hitlist'}};
        
        foreach my $categhit (@categhits) {
            if ( defined($categhit->{publikation}) && defined($categhit->{id}) && defined($categhit->{totalCount}) ) {
                
                my $categentry = { id => $self->{'scrubber'}->scrub($categhit->{id}), name => $self->{'scrubber'}->scrub($categhit->{publikation}), count => $categhit->{totalCount}+0, offset => $offset+0, hits => [] };

                my $hitcount = 0;
                if ( defined($categhit->{hit}) && reftype($categhit->{hit}) eq 'HASH' ) {
                    my @keys = sort { $a <=> $b } keys %{$categhit->{hit}};
                    foreach my $hit( @keys ) {
                        my $link    = $self->{'scrubber'}->scrub($categhit->{hit}->{$hit}->{url}) . $authlinkAdd;
                        my $title   = $self->{'scrubber'}->scrub($categhit->{hit}->{$hit}->{title}) || '';
                        my $date    = $self->{'scrubber'}->scrub($categhit->{hit}->{$hit}->{date}) || '';
                        my $text    = $self->{'scrubber'}->scrub($categhit->{hit}->{$hit}->{teaser}) || '';
                        my $top     = $self->{'scrubber'}->scrub($categhit->{hit}->{$hit}->{top}) || "false";
                        my $words   = $self->{'scrubber'}->scrub($categhit->{hit}->{$hit}->{words}) || '';
                        push @{$categentry->{hits}}, {
                                                         link  => $link,
                                                         title => $title,
                                                         date  => $date,
                                                         text  => $text,
                                                         top   => $top,
                                                         words => $words
                                                     };
                        $hitcount++;
                    }
                }
                push(@{$categories->{categories}}, $categentry);
                $categories->{categorycount} += 1;
                $categories->{hitcount} += $categhit->{totalCount};
            }
        }
    }
    
    return $categories;
    
}

1;

