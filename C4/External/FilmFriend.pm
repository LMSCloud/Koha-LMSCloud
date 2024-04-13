package C4::External::FilmFriend;

# Copyright 2021 LMSCloud GmbH
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
use C4::Languages;
use C4::Scrubber;
use Koha::Patrons;
use C4::External::DivibibPatronStatus;

use LWP::UserAgent;
use JSON;
use Encode;
use Scalar::Util qw(reftype);
use URI::Escape;

use Data::Dumper;
use Carp;

use POSIX;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    require Exporter;
    $VERSION = 3.07.00.049;
    @ISA = qw(Exporter);
    @EXPORT = qw();
    @EXPORT_OK = qw();
}

=head1 NAME

C4::External::FilmFriend - Interface to use FilmFriends metasearch API

=head1 SYNOPSIS

use C4::External::FilmFriend;

my $filmfriendService = C4::External::FilmFriend->new();

$filmfriendService->simpleSearch(1,"Bernstein","Movie",10,0);

=head1 DESCRIPTION

The module searches the FilmFriend database for relevant information. A search is done using
a HTTPS GET request. The interface can be testet at https://api.vod.filmwerte.de/api/v1/customers(tenant)/39bedc69-884f-4883-8ae7-003f1d28284d/search?.
The functions perform a simple search and extract the information from the resulting hit list.

=head1 FUNCTIONS

=head2 new

C4::External::FilmFriend->new();

Instantiate a new FielmFriend service that uses an LWP::UserAgent to perform requests.

=cut

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    
    $self->{'traceEnabled'} = 0;
    $self->{'traceEnabled'} = 1 if (C4::Context->preference('FilmfriendTraceEnabled'));

    $self->{'customerID'}   = C4::Context->preference('FilmfriendCustomerID');
    $self->{'providerID'}   = C4::Context->preference('FilmfriendProviderID');
    
    $self->{'filmFriendBaseURL'}         = 'https://api.tenant.frontend.vod.filmwerte.de/v11';
    $self->{'filmFriendAuthURL'}         = 'https://api.vod.filmwerte.de/connect/authorize-external';
    
    
    $self->{'filmFriendTenantGroupIdDE'} = 'fba2f8b5-6a3a-4da3-b555-21613a88d3ef';
    $self->{'filmFriendTenantGroupIdCH'} = 'b9b657d4-48c4-4827-a257-d1b0b44a278a';
    $self->{'filmFriendTenantGroupIdAT'} = '8bd3757f-bb3f-4ffe-9543-3424497ef47d';
    
    $self->{'baseURL'} = 'https://filmfriend.de/de/';
    
    my $language = C4::Languages::getlanguage();
    if ( $language =~ /^(de|fr|es|en)/ ) {
        $language = $1;
    } else {
        $language = "en";
    }
                
    my $instanceURL = C4::Context->preference('FilmfriendCustomerURL');
    if ( $instanceURL ) {
        $instanceURL =~ s/^\s+//;
        $instanceURL =~ s/\s+$//;
        if ( $instanceURL ) {
            $instanceURL = "https://" . $instanceURL if ( $instanceURL !~ /\/\// );
            my($scheme, $authority, $path, $query, $fragment) =
                $instanceURL =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;
            $scheme = "https" if (! $scheme );
            $authority = "filmfriend.de" if (! $authority );
            $instanceURL = "${scheme}://${authority}${path}";
            $instanceURL .= "/" if ( $instanceURL !~ /\/$/ );
            print "$instanceURL\n";
        }
    }
    $self->{'baseURL'} = $instanceURL if ( $instanceURL );
    
    $self->{'Link'}->{'Video'}      = $self->{'baseURL'} . 'movies/';
    $self->{'Link'}->{'Movie'}      = $self->{'baseURL'} . 'movies/';
    $self->{'Link'}->{'Person'}     = $self->{'baseURL'} . 'persons/';
    $self->{'Link'}->{'Collection'} = $self->{'baseURL'} . 'collections/';
    $self->{'Link'}->{'Series'}     = $self->{'baseURL'} . 'series/';
    $self->{'Link'}->{'Season'}     = $self->{'baseURL'} . 'seasons/';
    $self->{'Link'}->{'Episode'}    = $self->{'baseURL'} . 'episodes/';
    
    $self->{'languages'} = ['german','english','frenchTitle','italian','spanish'];
    
    $self->{'IMDbLink'} = 'https://www.imdb.com/title/';
    $self->{'MovieDatabaseLink'} = 'https://www.themoviedb.org/movie/';
    $self->{'FilmPortalLink'} = 'https://www.filmportal.de/film/';
    
    
    if ( $self->{'customerID'} ) {
        $self->{'filmFriendSearchURL'} = $self->{'filmFriendBaseURL'}
                                         . '/' 
                                         . $self->{'customerID'}
                                         . '/search?';
    } else {
        my $lang = C4::Languages::getlanguage();
        my $tenantGroup = C4::Context->preference('FilmfriendTenantGroup');
        
        $self->{'language'} = 'de-DE';
        
        if ( !$tenantGroup && $lang ) {
            $tenantGroup = 'CH' if ( $lang eq 'de-CH' );
            $tenantGroup = 'AT' if ( $lang eq 'de-AT' );
            $tenantGroup = 'DE' if ( $lang eq 'de-DE' );
            $self->{'language'} = $lang;
        }
        $tenantGroup = 'DE' if (! $tenantGroup );
        
        $self->{'filmFriendSearchURL'} = $self->{'filmFriendBaseURL'}
                                         . '/tenant-groups/' 
                                         . $self->{'filmFriendTenantGroupId' . $tenantGroup}
                                         . '/search?';
    }
    
    my @header = ( 'Accept' => 'application/json', 'Accept-Language' => "$language" );
    
    $self->{'requestHeader'} = \@header;
    $self->{'scrubber'} = C4::Scrubber->new();
    
    $self->{'useFields'}->{Video} = [ qw{ id filmfriendLink filmportalId title colorTechnology country genre category actors audio subtitle duration regie releaseYear originalTitle thumbnail thumbnails cover synopsis isActive runtime genres aspectRatio production fsk kind categories IMDbLinkLink FilmPortalLink MovieDatabaseLink furtherTitles description} ];
    $self->{'useFields'}->{Movie} = $self->{'useFields'}->{Video};
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout(3);
    $ua->env_proxy;
    
    $self->{'ua'} = $ua;

    return $self;
}

=head2 getAuth

Get the authentication token.

=cut

sub getAuth {
    my $self     = shift;
    my $user     = shift;
    my $password = shift;
    
    my $auth = undef;
    
    if ( $self && $self->{'providerID'} && $self->{'customerID'} ) {
        
        my @header = @{$self->{'requestHeader'}};
        
        my $url = $self->{'filmFriendAuthURL'};
        
        my $params =  {
                          client_id => "tenant-" . $self->{'customerID'} . "-filmwerte-vod-frontend",
                          provider  => $self->{'providerID'},
                          username  => $user,
                          password  => $password
                      };

        carp "C4::External::FilmFriend->getAuth() calling with URL $url" if ( $self->{'traceEnabled'} );
        my $response = $self->{'ua'}->post($url,$params);
        
        if ( defined($response) && $response->is_success ) {
            
            my $json = JSON->new->utf8->allow_nonref;
            
            $auth = $json->decode( $response->content );
            
            carp "C4::External::FilmFriend->getAuth() result: " . Dumper($auth) if ( $self->{'traceEnabled'} );
            
            if ( $auth && exists($auth->{access_token}) && exists($auth->{expires_in}) && exists($auth->{token_type}) && exists($auth->{refresh_token}) ) {
                return $auth;
            } else {
                return undef;                
            }
        }
        else {
            carp "C4::External::FilmFriend->getAuth() with URL $url and params " . Dumper($params) . " returned with HTTP error code " . $response->error_as_HTML if ( $self->{'traceEnabled'} );   
        }
    }
    return $auth;
}

sub getAuthLink {
    my $self = shift;
    my $userid = shift;
    my $collection = shift;
    my $objectID   = shift;
    
    if ( $userid ) {
        my $patron = Koha::Patrons->find({ userid => $userid } );
        if ( $patron ) {
            my $patronStatus = C4::External::DivibibPatronStatus->new();
            my $pStatus = $patronStatus->getPatronStatus( $patron );
            
            if ( $pStatus && $pStatus->{status} eq '3' ) {
                my $auth = $self->getAuth($userid,$patron->password);
                
                if ( $auth ) {
                    return $self->getLink($collection,$objectID,1,$auth);
                }
            }
        }
    }
    
    return undef;
}

=head2 getAuth

Get a filmfriend Link depending on the available authentication token.

=cut

sub getLink {
    my $self       = shift;
    my $collection = shift;
    my $objectID   = shift;
    my $withAuth   = shift;
    my $auth       = shift;
    
    my $url;
    
    if ( !$withAuth ) {
        $url = $self->{'Link'}->{$collection} . uri_escape_utf8($objectID);
    }
    elsif ( !$auth ) {
        $url = '/cgi-bin/koha/opac-filmfriend.pl?collection=' . uri_escape_utf8($collection) . '&objectid=' . uri_escape_utf8($objectID);
    } 
    else {
        $url = $self->{'Link'}->{$collection} . uri_escape_utf8($objectID).
               '#access_token=' . uri_escape_utf8($auth->{access_token}) . 
               '&refresh_token=' . uri_escape_utf8($auth->{refresh_token}) . 
               '&expires_in=' . uri_escape_utf8($auth->{expires_in}) .
               '&token_type=' . uri_escape_utf8($auth->{token_type});
    }
    return $url;
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

    my $withAuth=0;
    
    return undef unless ( C4::Context->preference('FilmfriendSearchActive') );

    $searchtext = $self->normalizeSearchRequest($searchtext);
    
    return undef if (! $searchtext );

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
    $maxcount = 0 if (!$maxcount);
    $searchtypes = [ "Movie" ]  if (!$searchtypes);
    $searchtypes = [ $searchtypes ] if ( !reftype($searchtypes) || reftype($searchtypes) ne 'ARRAY' );
    
    my $results = [];
    
    foreach my $searchtype ( @$searchtypes ) {
    
        my $url = $self->{'filmFriendSearchURL'};
        
        my $orderBy = "Score";
        my $sortDirection = "Descending";
        
        if ( $searchtype eq 'Movie' ) {
            $url .= 'kinds=Movie';
        }
        elsif ( $searchtype eq 'Episode' ) {
            $url .= 'kinds=Episode';
        }
        elsif ( $searchtype eq 'SportsVideo' ) {
            $url .= 'kinds=SportsVideo';
        }
        elsif ( $searchtype eq 'Season' ) {
            $url .= 'kinds=Season';
        }
        elsif ( $searchtype eq 'Series' ) {
            $url .= 'kinds=Series';
            $orderBy = "Title";
            $sortDirection = "Ascending";
        }
        elsif ( $searchtype eq 'Person' ) {
            $url .= 'kinds=Person';
            $orderBy = "Title";
            $sortDirection = "Ascending";
        }
        elsif ( $searchtype eq 'Collection' ) {
            $url .= 'kinds=Collection';
            $orderBy = "Title";
            $sortDirection = "Ascending";
        }
        else {
            next;
        }
         
        $url .= '&search='. uri_escape_utf8($searchtext);
        $url .= '&mode=All';
        
        if ( $maxcount ) {
            $url .= '&take=' . $maxcount;
        }
        else {
            $url .= '&take=0';
        }
        
        if ( $offset ) {
            $url .= '&skip=' . $offset;
        }
        

        $url .= "&orderBy=$orderBy";
        $url .= "&sortDirection=$sortDirection";
        $url .= '&totalCount=true';
        $url .= '&includeDetails=true';
        
        my @header = @{$self->{'requestHeader'}};
        
        carp "C4::External::FilmFriend->simpleSearch() with URL $url" if ( $self->{'traceEnabled'} );
        
        my $response = $self->{'ua'}->get($url,@header);
        
        if ( $self->{'traceEnabled'} ) {
            $Data::Dumper::Indent = 2;
            carp "C4::External::FilmFriend->simpleSearch(): filmfriend response: " . Dumper($response);
        }
        
        if ( defined($response) && $response->is_success ) {
            
            my $json = JSON->new->utf8->allow_nonref;
            
            my $data = $self->sanitizeResultStructure( $self->scrubData($json->decode( $response->content )), $withAuth, $searchtype, $offset, $patronFsk);
            $data->{searchType} = $searchtype;
            $data->{search} = $searchtext;
            $data->{searchUrl} = $url;
            $data->{searchAtFilmFriend} = $self->{'baseURL'} . 'search?search=' . uri_escape_utf8($searchtext);
            
            push @$results, $data if ($data->{numFound} > 0);
        }

    }
    
    if ( $self->{'traceEnabled'} ) {
        $Data::Dumper::Indent = 2;
        carp "C4::External::FilmFriend->simpleSearch(): result: " . Dumper($results);
    }

    return $results;
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

sub sanitizeResultStructure {
    my $self       = shift;
    my $data       = shift;
    my $withAuth   = shift;
    my $searchtype = shift;
    my $offset     = shift;
    my $patronFsk  = shift;
    
    my $result = {};
    
    if ( $data && exists($data->{'results'}) ) {
        
        $result->{start} = 0;
        $result->{start} += $offset;
        
        $result->{numFound} = 0;
        $result->{numFound} += $self->{'scrubber'}->scrub($data->{'totalCount'}) if ( exists($data->{'totalCount'}) );
        
        $result->{hits} = 0;
        $result->{hitList} = [];
        
        if ( exists($data->{'results'}) && reftype($data->{'results'}) && reftype($data->{'results'}) eq 'ARRAY') {
            
            foreach my $hit ( @{$data->{'results'}} ) {   
                my $hitType = $hit->{kind};
                
                if ( $hitType && $hitType ne 'Person' ) {
                    
                    $hit = $hit->{result} if ( $hit->{result} );
                    
                    $hitType = $hit->{kind} if ( exists($hit->{kind}) && $hit->{kind} );
                    my $hitentry = $hitType;
                    $hitentry =~ s/^(.)(.*)$/lc($1).$2/es;
                    
                    $hit = $hit->{$hitentry} if ( $hit->{$hitentry} );
                    
                    $hit->{actors}= [];
                    $hit->{regie}= []; 
                    
                    if ( exists($hit->{imdbId}) && $hit->{imdbId}) {
                        $hit->{IMDbLinkLink} = $hit->{imdbUrl};
                    }
                    if ( exists($hit->{filmportalUrl}) && $hit->{filmportalUrl}) {
                        $hit->{FilmPortalLink} = $hit->{filmportalUrl};
                    }
                    if ( exists($hit->{tmdbId}) && $hit->{tmdbId}) {
                        $hit->{MovieDatabaseLink} = $hit->{tmdbUrl};
                    }
                    
                    if ( exists($hit->{ageRatings}) && reftype($hit->{ageRatings}) && reftype($hit->{ageRatings}) eq 'ARRAY') {
                        $self->setListElement($hit->{ageRatings},'minimumAge',$hit,'fskList');
                        if ( exists($hit->{fskList}) ) {
                            $hit->{fsk} = $hit->{fskList}->[0];
                        }
                    }
                    #if ( exists($hit->{ageRatings}) && exists($hit->{ageRatings}->[0]->{name}) && $hit->{ageRatings}->[0]->{name} =~ /^Fsk([0-9]+)/ ) {
                    #    $hit->{fsk} = $1;
                    #}
                    
                    if ( $hitType eq 'Season' && exists($hit->{series}) ) {
                        $hit->{seriestitle} = $hit->{series}->{title} if ( exists($hit->{series}->{title}) );
                        
                        if ( exists($hit->{seriestitle}) && $hit->{seriestitle} && exists($hit->{seasonNumber}) && $hit->{seasonNumber}) {
                            if ( $self->{'language'} =~ /^de/ ) {
                                $hit->{seriestitle} .= ', Staffel ' . $hit->{seasonNumber};
                            }
                            elsif ( $self->{'language'} =~ /^fr/ ) {
                                $hit->{seriestitle} .= ', Saison ' . $hit->{seasonNumber};
                            }
                            else {
                                $hit->{seriestitle} .= ', Season ' . $hit->{seasonNumber};
                            }
                        }
                        
                        if ( exists($hit->{seriestitle}) && $hit->{seriestitle} ) {
                            if ( exists($hit->{title}) &&  $hit->{title} ) {
                                $hit->{title} = $hit->{seriestitle} . ': ' . $hit->{title};
                            }
                            else {
                                $hit->{title} = $hit->{seriestitle};
                            }
                        }
                        
                        if ( exists($hit->{series}->{genres}) && reftype($hit->{series}->{genres}) && reftype($hit->{series}->{genres}) eq 'ARRAY') {
                            $self->setListElement($hit->{series}->{genres},'name',$hit,'genre');
                        }
                        if ( exists($hit->{series}->{categories}) && reftype($hit->{series}->{categories}) && reftype($hit->{series}->{categories}) eq 'ARRAY') {
                            $self->setListElement($hit->{series}->{categories},'name',$hit,'category');
                        }
                    }

                    
                    
                    if ( $hitType eq 'Episode' && exists($hit->{season}) && exists($hit->{season}->{series}) ) {
                        if ( exists($hit->{season}->{releaseDate}) && $hit->{season}->{releaseDate} =~ /^([0-9]{4})-/ ) {
                            $hit->{releaseYear} = $1;
                        }
                        if ( exists($hit->{season}->{motionPictureContentRating}) && $hit->{season}->{motionPictureContentRating} =~ /^Fsk([0-9]+)/ ) {
                            $hit->{fsk} = $1;
                        }
                        $hit->{seriestitle} = $hit->{season}->{series}->{title} if ( exists($hit->{season}->{series}->{title}) );
                        
                        if ( exists($hit->{seriestitle}) && $hit->{seriestitle} && exists($hit->{season}->{seasonNumber}) && $hit->{season}->{seasonNumber}) {
                            if ( $self->{'language'} =~ /^de/ ) {
                                $hit->{seriestitle} .= ', Staffel ' . $hit->{season}->{seasonNumber};
                            }
                            elsif ( $self->{'language'} =~ /^fr/ ) {
                                $hit->{seriestitle} .= ', Saison ' . $hit->{season}->{seasonNumber};
                            }
                            else {
                                $hit->{seriestitle} .= ', Season ' . $hit->{season}->{seasonNumber};
                            }
                            if ( exists($hit->{episodeNumber}) && $hit->{episodeNumber} ) {
                                if ( $self->{'language'} =~ /^de/ ) {
                                    $hit->{seriestitle} .= ', Folge ' . $hit->{episodeNumber};
                                }
                                elsif ( $self->{'language'} =~ /^fr/ ) {
                                    $hit->{seriestitle} .= ', Èpisode ' . $hit->{episodeNumber};
                                }
                                else {
                                    $hit->{seriestitle} .= ', Episode ' . $hit->{season}->{seasonNumber};
                                }
                            }
                        }
                        if ( exists($hit->{seriestitle}) && $hit->{seriestitle} ) {
                            if ( exists($hit->{title}) &&  $hit->{title} ) {
                                $hit->{title} = $hit->{seriestitle} . ': ' . $hit->{title};
                            }
                            else {
                                $hit->{title} = $hit->{seriestitle};
                            }
                        }
                        
                        if ( exists($hit->{season}->{series}->{genres}) && reftype($hit->{season}->{series}->{genres}) && reftype($hit->{season}->{series}->{genres}) eq 'ARRAY') {
                            $self->setListElement($hit->{season}->{series}->{genres},'name',$hit,'genre');
                        }
                        if ( exists($hit->{season}->{series}->{categories}) && reftype($hit->{season}->{series}->{categories}) && reftype($hit->{season}->{series}->{categories}) eq 'ARRAY') {
                            $self->setListElement($hit->{season}->{series}->{categories},'name',$hit,'category');
                        }
                    }
                    
                    if ( exists($hit->{id}) && $hit->{id}) {
                        my $useAuth = $withAuth;
                        if ( $patronFsk && exists($hit->{fsk}) && $patronFsk < $hit->{fsk} ) {
                            $useAuth = 0;
                        }
                        $hit->{filmfriendLink} = $self->getLink($hitType,$hit->{id},$useAuth);
                    }
                    
                    if ( exists($hit->{synopsis}) && $hit->{synopsis}) {
                        $hit->{Synopsis} = $hit->{synopsis};
                    }
                    
                    if ( exists($hit->{teaser}) && $hit->{teaser}) {
                        $hit->{Teaser} = $hit->{teaser};
                    }
                    
                    if ( exists($hit->{productionCountries}) && reftype($hit->{productionCountries}) && reftype($hit->{productionCountries}) eq 'ARRAY' ) {
                        $self->setListElement($hit->{productionCountries},'name',$hit,'production');
                    }
                    if ( exists($hit->{genres}) && reftype($hit->{genres}) && reftype($hit->{genres}) eq 'ARRAY') {
                        $self->setListElement($hit->{genres},'name',$hit,'genre');
                    }
                    if ( exists($hit->{categories}) && reftype($hit->{categories}) && reftype($hit->{categories}) eq 'ARRAY') {
                        $self->setListElement($hit->{categories},'name',$hit,'category');
                    }
                    if ( exists($hit->{audioLanguages}) && reftype($hit->{audioLanguages}) && reftype($hit->{audioLanguages}) eq 'ARRAY' ) {
                        $self->setListElement($hit->{audioLanguages},'name',$hit,'audio');
                    }
                    if ( exists($hit->{subtitleLanguages}) && reftype($hit->{subtitleLanguages}) && reftype($hit->{subtitleLanguages}) eq 'ARRAY' ) {
                        $self->setListElement($hit->{subtitleLanguages},'name',$hit,'subtitle');
                    }
                    if ( exists($hit->{releaseDate}) && $hit->{releaseDate} =~ /^([0-9]{4})-/ ) {
                        $hit->{releaseYear} = $1;
                    }
                    if ( exists($hit->{artworkUris}) && reftype($hit->{artworkUris}) && reftype($hit->{artworkUris}) eq 'ARRAY' ) {
                        COVER: foreach my $artwork(@{$hit->{artworkUris}}) {
                            if ( exists($artwork->{kind}) && $artwork->{kind} eq 'CoverPortrait' ) {
                                if ( exists($artwork->{thumbnail}) && $artwork->{thumbnail} ) {
                                    $hit->{thumbnail} = $artwork->{thumbnail} if ( !exists($hit->{thumbnail}) );
                                    $hit->{cover} = $artwork->{thumbnail};
                                    last COVER;
                                }
                                if ( exists($artwork->{resolution1x}) && $artwork->{resolution1x} ) {
                                    $hit->{thumbnail} = $artwork->{thumbnail} if ( !exists($hit->{thumbnail}) );
                                    $hit->{cover} = $artwork->{resolution1x};
                                    last COVER;
                                }
                            }
                        }
                        foreach my $artwork(@{$hit->{artworkUris}}) {
                            if ( exists($artwork->{kind}) && $artwork->{kind} eq 'Thumbnail' ) {
                                if ( exists($artwork->{thumbnail}) && $artwork->{thumbnail} ) {
                                    $hit->{thumbnail} = $artwork->{thumbnail} if ( !exists($hit->{thumbnail}) );
                                    $hit->{thumbnails} = [] if ( !exists($hit->{thumbnails}) );
                                    push @{ $hit->{thumbnails} }, $artwork->{thumbnail1x};
                                }
                                elsif ( exists($artwork->{resolution1x}) && $artwork->{resolution1x} ) {
                                    $hit->{thumbnail} = $artwork->{resolution1x}  if ( !exists($hit->{thumbnail}) );
                                    $hit->{thumbnails} = [] if ( !exists($hit->{thumbnails}) );
                                    push @{ $hit->{thumbnails} }, $artwork->{thumbnail1x};
                                }
                            }
                        }
                    }
                    if ( exists($hit->{participants}) && reftype($hit->{participants}) && reftype($hit->{participants}) eq 'ARRAY' ) {
                        foreach my $person(@{$hit->{participants}}) {
                            if ( exists($person->{person}->{id}) && $person->{person}->{id}) {
                                $person->{filmfriendLink}= $self->getLink('Person',$person->{person}->{id},$withAuth);
                            }
                            if ( exists($person->{kind}) && $person->{kind} ) {
                                if ( $person->{kind} eq 'Actor' ) {
                                    push @{$hit->{actors}}, $person;
                                }
                                if ( $person->{kind} eq 'Director' ) {
                                    push @{$hit->{regie}}, $person;
                                }
                            }
                        }
                    }
                }
                elsif ( $hitType && $hitType eq 'Person' ) {
                    $hit = $hit->{result} if ( $hit->{result} );
                    
                    my $hitentry = 'person';
                    $hit = $hit->{$hitentry} if ( $hit->{$hitentry} );
                    $hit->{kind} = 'Person';
                    
                    $hit->{name} = $hit->{lastName};
                    if ( exists($hit->{firstName}) && $hit->{firstName}) {
                        $hit->{name} = $hit->{firstName} . ' ' . $hit->{name};
                    }
                    
                    if ( exists($hit->{id}) && $hit->{id}) {
                        $hit->{filmfriendLink}= $self->getLink($hitType,$hit->{id},$withAuth);
                    }
                    
                    $hit->{description} = $hit->{biography};
                }
                if ( exists($hit->{runtime}) && $hit->{runtime}) {
                    my $mins = POSIX::ceil($hit->{runtime}/60);
                    if ( $mins >= 60 ) {
                        my $hours = POSIX::floor($mins/60);
                        $mins = $mins%60;
                        if ( $mins > 0 ) {
                            $hit->{duration} = "${hours}h ${mins}min";
                        } else {
                            $hit->{duration} = "${hours}h";
                        }
                    } else {
                        $hit->{duration} = "${mins}min";
                    }
                }
                if ( $hitType && exists($self->{'useFields'}->{$hitType}) ) {
                    my $newhit = {};
                    foreach my $key ( @{ $self->{'useFields'}->{$hitType} } ) {
                        $newhit->{$key} = $hit->{$key};
                    }
                    $hit = $newhit;
                }
                $result->{hits}++;
                push(@{$result->{hitList}},$hit);
            }
        }
    }
    return $result;
}
           
sub setListElement {
    my $self        = shift;
    my $elemGet     = shift;
    my $elemGetName = shift;
    my $elemSet     = shift;
    my $elemSetName = shift;
    
    my $ret = 0;
    return $ret if ( !$elemGet || !$elemSet);
    
    if ( reftype($elemGet) && reftype($elemGet) eq 'ARRAY' ) {
        foreach my $elem( @{$elemGet}) {
            if ( exists($elem->{$elemGetName}) ) {
                my $value = $elem->{$elemGetName};
                if ( $value ) {
                    if ( !exists($elemSet->{$elemSetName}) ) {
                        $elemSet->{$elemSetName} = [];
                    }
                    push @{$elemSet->{$elemSetName}}, $value;
                    $ret = 1;
                }
            }
        }
    }

    return $ret;
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
