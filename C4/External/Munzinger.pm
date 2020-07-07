package C4::External::Munzinger;

# Copyright 2017 LMSCloud GmbH
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
use Koha::Patrons;

use LWP::UserAgent;
use XML::Simple;
use POSIX qw(strftime);
use MIME::Base64;
use Crypt::Twofish;
use File::Slurp;
use Crypt::CBC;
use Encode;
use Scalar::Util qw(reftype);
use URI::Escape;

use Data::Dumper;
use Carp;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    require Exporter;
    $VERSION = 3.07.00.049;
    @ISA = qw(Exporter);
    @EXPORT = qw();
    @EXPORT_OK = qw();
}

=head1 NAME

C4::External::Munzinger - Interface to Munzinger metasearch services

=head1 SYNOPSIS

use C4::External::Munzinger;

my $munzingerService = C4::External::Munzinger->new();

$munzingerService->getCategorySummary("Queen");

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
    
    my $simplesearch   = "https://www.munzinger.de/metasearch/xml/simple/simple.jsp?";
    my $detailedsearch = "https://www.munzinger.de/metasearch/xml/simple/";
    my $allsearch = "https://www.munzinger.de/search/katalog/query-simple?";
    
    $self->{'simplesearch'} = $simplesearch;
    $self->{'detailedsearch'} = $detailedsearch;
    $self->{'allsearch'} = $allsearch;
    $self->{'publications'} = {
                                    'Film'                       => 'film.jsp',
                                    'Personen'                   => 'personen.jsp',
                                    'Länder'                     => 'länder.jsp',
                                    'Pop'                        => 'pop.jsp',
                                    'Biographien'                => 'biographien.jsp',
                                    'Sport'                      => 'sport.jsp',
                                    'Duden Basiswissen Schule'   => 'basiswissen.jsp',
                                    'Duden'                      => 'duden.jsp',
                                    'Filmkritiken'               => 'film.jsp',
                                    'Kindler'                    => 'kindler.jsp',
                                    'KLG'                        => 'klg.jsp',
                                    'KLFG'                       => 'klfg.jsp',
                                    'KDG '                       => 'kdg.jsp',
                                    'KLL'                        => 'kll.jsp',
                                    'Kindlers Literatur Lexikon' => 'klg.jsp'
                              };
    
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
    
    carp "key value not defined in Munzinger config '$file'" if (! exists($config{'key'}) );
    carp "iv value not defined in Munzinger config '$file'" if (! exists($config{'iv'}) );
    
    $self->{'key'} = $config{'key'} if ( exists($config{'key'}) );
    $self->{'iv'}  = $config{'iv'} if ( exists($config{'iv'}) );
    
    $self->{'conf_ok'} = 0;
    $self->{'conf_ok'} = 1 if ( exists($config{'key'}) && exists($config{'iv'}) );

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
    my $keydata = shift;
    
    my $cipher = Crypt::CBC->new(
                            -literal_key => 1,
                            -key    => $self->{'key'},
                            -cipher => 'Twofish',
                            -iv => $self->{'iv'},
                            -header => 'none'
                      );
    my $requestkey = encode_base64($cipher->encrypt($keydata)); 
    $requestkey =~ s/[+]/(/g;
    $requestkey =~ s/[=]/_/g;
    $requestkey =~ s/[\/]/)/g;
    return $requestkey;
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
    my $maxcount = shift;
    
    return undef if (! $self->{'conf_ok'} );
    return undef unless ( C4::Context->preference('MunzingerPortalID') );
    
    $searchtext = $self->normalizeSearchRequest($searchtext);
    
    return undef if (! $searchtext );
   
    my $requestkey = '';
    my $user = 'dummy';
    my $munzingerKey = '';
    
    if ( $userid ) {
        my $patron = Koha::Patrons->find({ userid => $userid } );
        if ( $patron ) {
            $user = $patron->cardnumber;
        }
    }
    
    if ( exists($self->{'key'}) ) {
        my $datestring = strftime "%Y%m%e%H%M%S", localtime;
        $munzingerKey = "userid=". $user . "&portalid=" . C4::Context->preference('MunzingerPortalID') . "&ts=$datestring";
        $requestkey = $self->encryptKey($munzingerKey);
    }
 
    my $url;
    if ( $publication ) {
        $url = $self->{'detailedsearch'};
        if ( exists($self->{'publications'}->{$publication}) ) {
            $url .= $self->{'publications'}->{$publication};
        }
        $url .= "?text=" . uri_escape_utf8($searchtext) . "&sort=field:title";
        $url .= "&size=$maxcount&page=1" if ( $maxcount );
    }
    else {
        $url = $self->{'simplesearch'};
        $url .= "text=" . uri_escape_utf8($searchtext);
    }
        
    $url .= "&key=" . uri_escape_utf8($requestkey) if ($requestkey ne '');
    
    my $response = $self->{'ua'}->get($url);
    
    if ( defined($response) && $response->is_success ) {
        # print Dumper($response->content);
        
        carp "C4::External::Munzinger->simpleSearch() with URL $url (key=$munzingerKey)" if (C4::Context->preference('MunzingerTraceEnabled'));
            
        my $respstruct = XMLin( $response->content, KeyAttr => { hit => 'id' }, ForceArray => ["hitlist","hit"], KeepRoot => 1 );
        
        if ( defined($respstruct->{error}) ) {
            carp "C4::External::Munzinger->simpleSearch() with URL $url (key=$munzingerKey) returned with error result. Error id " . $respstruct->{error}->{id} . ": " . $respstruct->{error}->{content} if (C4::Context->preference('MunzingerTraceEnabled')); 
        }
        
        $respstruct->{'searchmunzinger'}  = $self->{'allsearch'} . "stichwort=$searchtext&portalid=" . C4::Context->preference('MunzingerPortalID');
        $respstruct->{'searchmunzinger'} .= "&key=$requestkey" if ($requestkey ne '');

        # 
        carp Dumper($respstruct) if (C4::Context->preference('MunzingerTraceEnabled'));
        
        return $respstruct;
    }
    else {
        carp "C4::External::Munzinger->simpleSearch() with URL $url returned with HTTP error code " . $response->error_as_HTML if (C4::Context->preference('MunzingerTraceEnabled'));   
    }
    return undef;
}

=head2 getCategorySummary

Execute a simple search and return the as new data structure grouping the results by facet categories. The return result may look like the following:

{
  'categorycount' => 3,
  'hitcount' => 6,
  'categories' => [
            {
              'name' => 'Personen',
              'count' => '3',
              'hits' => [
                  {
                    'link' => 'https://www.munzinger.de/document/00000002405',
                    'title' => "Elizabeth; Mutter von K\x{f6}nigin Elizabeth II. von Gro\x{df}britannien",
                    'text' => "* 4. August 1900 London, \x{2020} 30. M\x{e4}rz 2002 Windsor, Mutter von K\x{f6}nigin Elizabeth II. von Gro\x{df}britannien"
                  },
                  {
                    'text' => "* 21. April 1926 London, geb. Prinzessin Elizabeth Alexandra Mary Windsor; ab 6.2.1952 K\x{f6}nigin des Vereinigten K\x{f6}nigreichs nach dem Tod des Vaters George VI.(Kr\x{f6}nung am 2. 6.1953 in der Westminster-Abtei), seit 1947 verheiratet mit Philip Mountbatten  (nach der Heirat: Herzog von Edinburgh), 2012/2013 60-j\x{e4}hriges Thron- und Kr\x{f6}nungsjubil\x{e4}um",
                    'title' => "Elizabeth II.; K\x{f6}nigin von Gro\x{df}britannien und Nordirland",
                    'link' => 'https://www.munzinger.de/document/00000000073'
                  },
                  {
                    'title' => "Mary; K\x{f6}nigin von England",
                    'text' => "* 26. Mai 1867 im Kensington Palast/London, \x{2020} 24. M\x{e4}rz 1953 London,  K\x{f6}nigin von England; verheiratet mit Georg V. ab 1893; Mutter von George VI.",
                    'link' => 'https://www.munzinger.de/document/00000000801'
                  }
                ]
            },
            {
              'name' => 'Pop',
              'count' => '1',
              'hits' => [
                  {
                    'link' => 'https://www.munzinger.de/document/02000000117',
                    'title' => 'Queen; britische Art-Rock-Band',
                    'text' => 'Britische Art-Rock-Band'
                  }
                ]
            },
            {
              'name' => 'Duden Basiswissen Schule',
              'count' => '2',
              'hits' => [
                  {
                    'text' => "Sprechen<br />N\x{fc}tzliches Basisvokabular 2.5.1 Describing ourselves and others<br />Taking part in politics",
                    'title' => "Duden Basiswissen Schule \x{2013} Englisch",
                    'link' => 'http://www.munzinger.de/search/duden/basiswissen.jsp?id=BWSEN0087&query=Queen'
                  },
                  {
                    'title' => "Duden Basiswissen Schule \x{2013} Englisch",
                    'text' => "Lern- und Arbeitsstrategien f\x{fc}r den Englischunterricht<br />Produktion eigener Texte<br />Der Bericht und der Brief",
                    'link' => 'http://www.munzinger.de/search/duden/basiswissen.jsp?id=BWSEA0056&query=Queen'
                  }
                ]
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
    
    my $categories = { categorycount => 0, hitcount => 0, categories => [] };
    
    my $result;
    
    $result = $self->simpleSearch($userid,$searchtext,$publication,$maxcount) if ( defined($searchtext) );
        
    if ( defined($result) && exists($result->{'hitlists'} ) ) {
        $categories->{'searchmunzinger'} = $result->{'searchmunzinger'};
        $result = $result->{'hitlists'};
    }
    
    if ( defined($result) && exists($result->{'hitlist'}) ) {
        my @categhits = @{$result->{'hitlist'}};
        
        foreach my $categhit (@categhits) {
            if ( defined($categhit->{publikation}) && defined($categhit->{totalCount}) ) {
                
                my $categentry = { name => $categhit->{publikation}, count => $categhit->{totalCount}, hits => [] };

                my $hitcount = 0;
                if ( defined($categhit->{hit}) && reftype($categhit->{hit}) eq 'HASH' ) {
                    foreach my $hit( keys %{$categhit->{'hit'}} ) {
                        push @{$categentry->{hits}}, $self->formatCategoryHit($categhit->{hit}->{$hit});
                        $hitcount++;
                    }
                }
                if ($hitcount) {
                    push(@{$categories->{categories}}, $categentry);
                    $categories->{categorycount} += 1;
                    $categories->{hitcount} += $categhit->{totalCount};
                }
            }
        }
    }

    # print Dumper($categories);
    
    return $categories;
    
}

=head2 formatCategoryHit

Return a hash ref that puts Munzinger hit data into a unified data structure consisting of title, text and link.

=cut

sub formatCategoryHit {
    my $self = shift;
    my $hit = shift;
    my $entry = { title => '', text => '', link => '' };
    
    if ( $hit->{'xsi:type'} eq 'person' ) {
        $entry->{title} = $hit->{title} if (defined($hit->{title}));
        $entry->{text}  = $hit->{text} if (defined($hit->{text}));
        $entry->{link}  = $hit->{url} if (defined($hit->{url}));
    }
    elsif ( $hit->{'xsi:type'} eq 'bws' ) {
        $entry->{title} = $hit->{book} if (defined($hit->{book}));
        my $text = '';
        $text .= ( $text ne '' ? '<br />' : '' ) . $hit->{chapter} if (defined($hit->{chapter}));
        $text .= ( $text ne '' ? '<br />' : '' ) . $hit->{section} if (defined($hit->{section}));
        $text .= ( $text ne '' ? '<br />' : '' ) . $hit->{subsection} if (defined($hit->{subsection}));
        $entry->{text}  = $text;
        $entry->{link}  = $hit->{url} if (defined($hit->{url}));
    }
    else {
        $entry->{title} = $hit->{title} if (defined($hit->{title}));
        if ( defined($hit->{text}) ) {
            my $text = $hit->{text};
            if ( reftype($text) eq 'HASH' && defined($text->{content}) && reftype($text->{content}) eq 'ARRAY' && defined($text->{i}) ) {
                my $settext = '';
                my @inserttext = ();
                if ( reftype($text->{i}) && reftype($text->{i}) eq 'ARRAY' ) {
                    @inserttext = @{$text->{i}};
                }
                else {
                    $inserttext[0] = $text->{i};
                }
                my @textlist = @{$text->{content}};
                
                for (my $i=0; $i < scalar(@textlist); $i++ ) {
                    $settext .= $textlist[$i];
                    $settext .= $inserttext[$i] if ( $i < scalar(@inserttext) );
                }
                $text = $settext;
            }
            $entry->{text}  = $text;
        }
        $entry->{link}  = $hit->{url} if (defined($hit->{url}));
    }
    return $entry;
}

sub normalizeSearchRequest {
    my $self = shift;
    my $search = shift;
    
    if ( defined($search) ) {
        
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

1;