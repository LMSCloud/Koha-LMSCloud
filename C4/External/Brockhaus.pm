package C4::External::Brockhaus;

# Copyright 2020 LMSCloud GmbH
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
use Koha::Patrons;

use LWP::UserAgent;
use JSON;
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

C4::External::Brockhaus - Interface to Brockhaus metasearch services

=head1 SYNOPSIS

use C4::External::Brockhaus;

my $brockhausService = C4::External::Brockhaus->new();

$brockhausService->simpleSearch(1,"Bernstein","ecs",10,0);

=head1 DESCRIPTION

The module searches the Brockhaus encyklopedia for relevant information. A search is done using
a HTTPS GET request. The interface can be testet at http://api2.brockhaus.de/search.
The functions perform a simple search and extracts the information from the resulting hit list.

=head1 FUNCTIONS

=head2 new

C4::External::Brockhaus->new();

Instantiate a new Brockhaus service that uses an LWP::UserAgent to perform requests.

=cut

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    
    $self->{'brockhausDomain'} = C4::Context->preference('BrockhausDomain');
    $self->{'brockhausDomain'} = 'brockhaus.de' if ( ! $self->{'brockhausDomain'} );
    
    $self->{'customerID'}   = C4::Context->preference('BrockhausCustomerID');
    $self->{'librarySelectID'} = C4::Context->preference('BrockhausLibrarySelectID');
    
    $self->{'brockhausSearchURL'} = 'https://api2.' .  $self->{'brockhausDomain'} . '/search?';
    
    $self->{'brockhausAccessURL'} = 'https://' . $self->{'brockhausDomain'} . '/ecs';
    
    $self->{'searchAtBrockhausURL'} = 'https://brockhaus.de/search/?';
    if ( $self->{'librarySelectID'} ) {
        $self->{'searchAtBrockhausURL'} .= 'select=' . $self->{'librarySelectID'};
    }
    
    if ( $self->{'customerID'} ) {
        $self->{'brockhausAccessURLAuth'} = 'https://' . $self->{'brockhausDomain'} . '/portal/user/' . $self->{'customerID'} . '?url=/ecs';
    } else {
        $self->{'brockhausAccessURLAuth'} = $self->{'brockhausAccessURL'}
    }
    
    my @header = ( 'Accept' => 'application/json' );
    
    $self->{'requestHeader'} = \@header;
    
    $self->{'scrubber'} = C4::Scrubber->new();
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    
    $self->{'ua'} = $ua;

    return $self;
}


=head2 simpleSearch

Execute a simple search and return the result as Hash structure parsed with JSON.
In case of an HTTP error it returns undef.

=cut


sub simpleSearch {
    my $self = shift;
    my $userid = shift;
    my $searchtext = shift;
    my $searchtypes = shift;
    my $maxcount = shift;
    my $offset = shift;

    return undef unless ( C4::Context->preference('BrockhausSearchActive') );
    
    $searchtext = $self->normalizeSearchRequest($searchtext);
    
    return undef if (! $searchtext );
    
    my $user;
    if ( $userid ) {
        my $patron = Koha::Patrons->find({ userid => $userid } );
        if ( $patron ) {
            $user = $patron->cardnumber;
        }
    }
    
    $offset = 0 if (!$offset);
    $maxcount = 10 if (!$maxcount);
    $searchtypes = [ "ecs" ]  if (!$searchtypes);
    $searchtypes = [ $searchtypes ] if ( reftype($searchtypes) ne 'ARRAY' );
 
    my $results = [];
 
    foreach my $searchtype ( @$searchtypes ) {
    
        my $url = $self->{'brockhausSearchURL'};
        $url .= 'q='. uri_escape_utf8($searchtext) . '&src=' . uri_escape($searchtype) . '&grouped=1';
        
        if ( $maxcount ) {
            $url .= '&size=' . $maxcount;
        }
        
        if ( $offset ) {
            $url .= '&offset=' . $offset;
        }
        
        my @header = @{$self->{'requestHeader'}};
        
        # print "Brockhaus URL => $url\n";
        
        my $response = $self->{'ua'}->get($url,@header);
        
        if ( defined($response) && $response->is_success ) {
            
            my $json = JSON->new->utf8->allow_nonref;
            my $data = $self->sanitizeResultStructure($json->decode( $response->content ), $user);
            $data->{searchType} = $searchtype;
            my $collection = 'enzy';
            if ( $searchtype =~ /julex/ ) {
                $collection = 'julex';
            }
            elsif ( $searchtype =~ /kilex/ ) {
                $collection = 'kilex';
            }
            $data->{searchAtBrockhaus} = $self->{'searchAtBrockhausURL'} . 't=' . $collection . '&q=' .uri_escape_utf8($searchtext);
            
            carp "C4::External::Brockhaus->simpleSearch() with URL $url" if (C4::Context->preference('BrockhausTraceEnabled'));
            
            # if ( defined($respstruct->{error}) ) {
                # carp "C4::External::Brockhaus->simpleSearch() with URL $url returned with error result. Error id " . $respstruct->{error}->{id} . ": " . $respstruct->{error}->{content} if (C4::Context->preference('BrockhausTraceEnabled')); 
            # }

            carp Dumper($data) if (C4::Context->preference('BrockhausTraceEnabled'));
            
            push @$results, $data if ($data->{numFound} > 0);
        }
        else {
            carp "C4::External::Brockhaus->simpleSearch() with URL $url returned with HTTP error code " . $response->error_as_HTML if (C4::Context->preference('BrockhausTraceEnabled'));   
        }
    }
    return $results;
}

sub sanitizeResultStructure {
    my $self = shift;
    my $data = shift;
    my $user = shift;
    
    my $result = {};
    my @checkelements = qw(title thumbnail type subtype summary url);
    
    if ( $data && exists($data->{'result'}) ) {
        $data = $data->{'result'};
        
        $result->{start} = 0;
        $result->{start} += $self->{'scrubber'}->scrub($data->{'start'}) if ( exists($data->{'start'}) );
        
        $result->{numFound} = 0;
        $result->{numFound} += $self->{'scrubber'}->scrub($data->{'numFound'}) if ( exists($data->{'numFound'}) );
        
        $result->{hits} = 0;
        $result->{hitList} = [];
        
        if ( exists($data->{'document'}) &&  reftype($data->{'document'}) eq 'ARRAY') {
            foreach my $hit ( @{$data->{'document'}} ) {
                my $entry = {};
                foreach my $elem(@checkelements) {
                    if ( exists($hit->{$elem}) ) {
                        my $elemData = $self->{'scrubber'}->scrub($hit->{$elem});
                        $entry->{$elem} = $elemData if ( $elemData );
                    }
                }
                if ( exists($entry->{title}) && exists($entry->{url}) ) {
                    if ( $user ) {
                        $entry->{url} = $self->{'brockhausAccessURLAuth'} . $entry->{url};
                    } else {
                        $entry->{url} = $self->{'brockhausAccessURL'} . $entry->{url};
                    }
                    $result->{hits}++;
                    push(@{$result->{hitList}},$entry);
                }
            }
        }
    }
    return $result;
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