package C4::External::HeLiMa;

# Copyright 2025 LMSCloud GmbH
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
use Time::HiRes qw(time);

use C4::Context;
use C4::Scrubber;
use Koha::Patrons;
use C4::External::DivibibPatronStatus;

# use LWP::ConsoleLogger::Easy qw( debug_ua );
use LWP::UserAgent;
use JSON;
use Scalar::Util qw(reftype);
use URI::Escape;
use URI;

use Data::Dumper;
use Carp;
use POSIX;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    require Exporter;
    $VERSION = 22.11.32.000;
    @ISA = qw(Exporter);
    @EXPORT = qw();
    @EXPORT_OK = qw();
}

=head1 NAME

C4::External::HeLiMa - Interface ti the Hessian License Manager user for OPAC search integration

=head1 SYNOPSIS

use C4::External::HeLiMa;

my $helimaService = C4::External::HeLiMa->new();

$helimaService->simpleSearch(1,"Hase",3,10,0);

=head1 DESCRIPTION

The module searches the Hessian License Managerfor relevant information. 
See documentation at https://login.bibconnect.de.
A search is done using the REST interface.

=head1 FUNCTIONS

=head2 new

C4::External::HeLiMa->new();

Instantiate a new HeLiMa service that uses an LWP::UserAgent to perform requests.

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    if (! C4::Context->preference('HelimaSearchActive') ) {
        return undef;
    }
    
    my %config = ();
    
    $self->{'helimaLicensor'}  = C4::Context->preference('HelimaLicensor') || 'hessian';
    my $file = '/etc/koha/' . $self->{'helimaLicensor'} . 'LicenseManagerConfig.key';
    
    if ( -e $file && -f $file ) {
        open(my $fh, '<:encoding(UTF-8)', $file) or carp "Could not open Helima configuration file '$file' $!";
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
    
    $self->{'traceEnabled'}     = 0;
    $self->{'traceEnabled'}     = 1 if (C4::Context->preference('HelimaTraceEnabled'));
    $self->{'customerID'}       = C4::Context->preference('HelimaCustomerID') || '';
    $self->{'helimaAPIBaseURL'} = $config{url} || 'https://login.ebibliotheken-hessen.de/api';
    $self->{'scrubber'}         = C4::Scrubber->new();
    
    $self->{'searchAllCollections'} = 1;

    if ( C4::Context->preference('HeLiMaSearchCollections') ) {
        $self->{'searchAllCollections'} = 0;
        $self->{'searchCollections'} = {};
        foreach my $collection( split(/\|/,C4::Context->preference('HeLiMaSearchCollections')) ) {
            $collection =~ s/^\s+//;
            $collection =~ s/\s+$//;
            $self->{'searchCollections'}->{$collection} = 1;
        }
    }
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout(3);
    $ua->env_proxy;
    
    # my $ua_logger = debug_ua( $ua );
    
    $self->{'ua'} = $ua;
    
    my @header = ( 'Accept' => 'application/json', 'Authorization' => 'Bearer ' .$config{bearer});
    $self->{'requestHeader'} = \@header;

    return $self;
}


=head2 simpleSearch

Execute a simple search and return the result as Hash structure parsed with JSON.
In case of an HTTP error it returns undef.

=cut


sub simpleSearch {
    my $self        = shift;
    my $userid      = shift;
    my $searchtext  = shift;
    my $searchtype  = shift;
    my $maxcount    = shift;
    my $offset      = shift;

    return undef unless ( C4::Context->preference('HelimaSearchActive') );

    $searchtext = $self->normalizeSearchRequest($searchtext);
    
    return undef if (! $searchtext );

    my $withAuth = 0;
    my $patronFsk;
    if ( $userid ) {
        my $patron = Koha::Patrons->find({ userid => $userid } );
        if ( $patron ) {
            my $patronStatus = C4::External::DivibibPatronStatus->new();
            my $pStatus = $patronStatus->getPatronStatus( $patron );
            
            if ( $pStatus && $pStatus->{status} eq '3' ) {
                $withAuth = 1;
                
                $patronFsk = $pStatus->{fsk};
            }
        }
    }
    
    $offset = 0 if (!$offset);
    $maxcount = 0 if (!$maxcount || ($maxcount + 0) <= 0);
    
    my $url = $self->{'helimaAPIBaseURL'};
        
    if ( $searchtype ) {
        if ( !$self->{'searchAllCollections'} &&
             (!exists($self->{'searchCollections'}->{$searchtype}) || 
              $self->{'searchCollections'}->{$searchtype} == 0
             ) ) 
        {
            return;
        }
        $url .= '/search/?q=' . uri_escape_utf8($searchtext);
        $url .= '&offer_id=' . uri_escape_utf8($searchtype);
        $url .= '&limit=' . uri_escape_utf8($maxcount);
        $url .= '&offset=' . uri_escape_utf8($offset);
    } else {
        $url .= '/search/dbs/' . $self->{'customerID'} .'?q=' . uri_escape_utf8($searchtext);
    }

    my @header = @{$self->{'requestHeader'}};
        
    carp "C4::External::HeLiMa->simpleSearch() with URL $url" if ( $self->{'traceEnabled'} );
        
    my $response = $self->{'ua'}->get($url,@header);

    if ( $self->{'traceEnabled'} ) {
        $Data::Dumper::Indent = 2;
        carp "C4::External::HeLiMa->simpleSearch(): helima response: " . Dumper($response);
    }
    
    my $result;
        
    if ( defined($response) && $response->is_success ) {
        
        my $json = JSON->new->utf8->allow_nonref;
        
        my $data = $self->scrubData($json->decode( $response->content ));
        # print Dumper($data);
        if ( $searchtype ) {
            $data = $self->sanitizeResultStructureResultList($data,$withAuth,$offset,$patronFsk);
            $data->{searchType}         = 'singleOffer';
            $data->{searchOffer}        = $searchtype;
        } else {
            $data = $self->sanitizeResultStructureOffers($data);
            $data->{searchType}         = 'offerList';
        }
        
        $data->{search}             = $searchtext;
        $data->{searchUrl}          = $url;
        
        $result = $data;
    }
    
    if ( $self->{'traceEnabled'} ) {
        $Data::Dumper::Indent = 2;
        carp "C4::External::HeLiMa->simpleSearch(): result: " . Dumper($result);
    }

    return $result;
}

sub scrubData {
    my $self       = shift;
    my $data       = shift;
    
    if ( reftype($data) ) {
        if ( reftype($data) eq 'ARRAY' ) {
            foreach my $ref( @$data ) {
                $self->scrubData($ref);
            }
        }
        elsif ( reftype($data) eq 'HASH' ) {
            foreach my $key( keys %$data ) {
                if ( reftype($data->{$key}) ) {
                    if ( reftype($data->{$key}) eq 'ARRAY' || reftype($data->{$key}) eq 'HASH' ) {
                        $self->scrubData($data->{$key});
                    }
                } else {
                    $data->{$key} = $self->{'scrubber'}->scrub($data->{$key});
                }
            }
        }
    }
    return $data;
}

sub sanitizeResultStructureOffers {
    my $self       = shift;
    my $data       = shift;
    my $withAuth   = shift;
    
    my $result = { resultCollections => 0, collections => [] };

    if ( $data && $data->{success}) {
        if (    exists($data->{total_offers}) 
             && $data->{total_offers} > 0 
             && exists($data->{offers})
             && reftype($data->{offers}) 
             && reftype($data->{offers}) eq 'ARRAY'
             && scalar(@{$data->{offers}}) > 0
        ) {
            foreach my $offer( @{ $data->{offers} } ) {
                if ( reftype($offer) eq 'HASH' ) {
                    if ( $offer && exists($offer->{matches}) && $offer->{matches} > 0 &&
                         exists($offer->{name}) && $offer->{name} &&
                         exists($offer->{id}) && $offer->{id} &&
                         ( $self->{'searchAllCollections'} || 
                            ( exists($self->{'searchCollections'}->{$offer->{name}}) && $self->{'searchCollections'}->{$offer->{name}} == 1) 
                         )
                       ) 
                    {
                        my $collection = {};
                        $result->{resultCollections}++;
                        my $image = $offer->{image_url};
                        $image = URI->new_abs($image,$self->{'helimaAPIBaseURL'})->as_string if ( $image =~ m#^\s*/# );
                        push @{$result->{collections}}, { name => $offer->{name}, id => $offer->{id}, hits => $offer->{matches}+0, description => $offer->{description}, image => $image };
                    }
                }
            }
        }
    }
    
    return $result;
}

sub sanitizeResultStructureResultList {
    my $self       = shift;
    my $data       = shift;
    my $withAuth   = shift;
    
    my $result = { hitCount => 0, hits => [] };

    if ( $data && $data->{success}) {
        if (    exists($data->{results}) 
             && $data->{results} > 0 
             && exists($data->{results})
             && reftype($data->{results}) 
             && reftype($data->{results}) eq 'ARRAY'
             && scalar(@{$data->{results}}) > 0 
        ) {
            
            $result->{hitCount} = $data->{total} + 0;
            $result->{offset} = $data->{offset} + 0;
            $result->{size} = $data->{limit} + 0;
            
            my $results = $data->{results}->[0];
            
            $result->{name} = $results->{offer_name};
            $result->{id} = $results->{offer_id};
            $result->{description} = $results->{description};
            my $image = $results->{offer_image_url};
            $image = URI->new_abs($image,$self->{'helimaAPIBaseURL'})->as_string if ( $image =~ m#^\s*/# );
            $result->{image} = $image;
            
            foreach my $lesson( @{ $results->{lessons} } ) {
                my $hit = {};
                if ( reftype($lesson) eq 'HASH' ) {
                    for my $key('active','area','dauer','fach','id','image_url','klassenstufen','medium','title','topic','url','valid_from','valid_until') {
                        if ( exists($lesson->{$key}) && !ref($lesson->{$key}) ) {
                            if ( $key =~ /^image_url|url$/ && $lesson->{$key} && $lesson->{$key} =~ m#^\s*/# ) {
                                $hit->{$key} = URI->new_abs($lesson->{$key},$self->{'helimaAPIBaseURL'})->as_string;
                            } else {
                                $hit->{$key} = $lesson->{$key};
                            }
                        }
                    }
                }
                push( @{$result->{hits}}, $hit);
            }
        }
    }
    
    return $result;
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

1;

#my $helimaService = C4::External::HeLiMa->new();
#my $start = time();
#my $result = $helimaService->simpleSearch(1,"Biene",undef,1);
#my $end = time();
#my $elapsed_ms = ($end - $start) * 1000;
#
#printf("Vergangene Zeit: %.3f ms\n", $elapsed_ms);
#
#my $result = $helimaService->simpleSearch(1,"Winter",9,10);
#print Dumper($result);
