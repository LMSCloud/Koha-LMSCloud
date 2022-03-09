package C4::External::BibtipRecommendations;

# Copyright 2022 LMSCloud GmbH
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
use Carp;

use C4::Context;
use C4::CoverFlowData qw(GetCoverFlowDataByBiblionumber);
use URI::Escape;

use Koha::Old::Checkouts;
use Koha::Items;
use Koha::Item;
use Koha::DateUtils;

use LWP::UserAgent;
use JSON;
use Data::Dumper;


=head1 NAME

C4::External::BibtipRecommendations - Interface to Bibtip recommendation service

=head1 SYNOPSIS

use C4::External::BibtipRecommendations;

my $recommenderService = C4::External::BibtipRecommendations->new();

$recommenderService->getPatronSpecificRecommendations($userid);

=head1 DESCRIPTION

The module asks for the Bibtip recommendation service for a list of recommendations..

=head1 FUNCTIONS

=head2 new

C4::External::BibtipRecommendations->new();

Instantiate a new Recommendation service instance that uses an LWP::UserAgent to perform requests.

=cut

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout(60);
    $ua->env_proxy;
    
    my $bibtipCatalog = C4::Context->preference('BibtipCatalog');
    
    $self->{'ua'}   = $ua;
    $self->{'url'}  = 'https://recommender.bibtip.de/recommender/vector_recs/apiv1/' . $bibtipCatalog . '/vector_reclist.json';
    
    $self->{'requestHeader'} = [ 'Accept' => 'application/json' ];
    
    return $self;
    
}

=head2 getPatronSpecificRecommendations

Get recommendations for a specific user based on the reading history (list of biblionumber).

=cut

sub getPatronSpecificRecommendations {  
    my $self           = shift;
    my $borrowernumber = shift;
    my $count          = shift;
    
    my $result = [];
    
    # Get old issues
    # Check old issues table
    
    # Create (old)issues search criteria
    my $criteria = {
        borrowernumber => $borrowernumber,
    };
    my $sort = { 'order_by' => { '-desc' => 'issuedate' } };
    
    my $biblionumbers = [];
    my %checkbiblio;
    
    # get current issues of the patron
    foreach my $issue ( Koha::Checkouts->search($criteria,$sort) ) {
        my $itemnumber = $issue->itemnumber;
        
        if ( $itemnumber ) {
            my $item = Koha::Items->find($itemnumber);
            
            if ( $item ) {
                next if ( exists( $checkbiblio{$item->biblionumber} ) );
                push @$biblionumbers, [ $item->biblionumber, $issue->issuedate ];
                $checkbiblio{$item->biblionumber} = 1;
            }
        }
    }
    # get old issue history of the patron
    foreach my $oldissue ( Koha::Old::Checkouts->search($criteria,$sort) ) {
        my $itemnumber = $oldissue->itemnumber;
        
        if ( $itemnumber ) {
            my $item = Koha::Items->find($itemnumber);
            
            if ( $item ) {
                next if ( exists( $checkbiblio{$item->biblionumber} ) );
                push @$biblionumbers, [ $item->biblionumber, $oldissue->issuedate ];
                $checkbiblio{$item->biblionumber} = 1;
            }
        }
    }

    if ( scalar(@$biblionumbers) ) {
        my $json = JSON->new->utf8->allow_nonref;
        
        my $requestData = { items => [] };
        
        foreach my $issue(@$biblionumbers) {
            my $biblionumber = $issue->[0];
            my $issuedate = dt_from_string($issue->[1]);
            
            push @{ $requestData->{items} }, { nd => "$biblionumber", date => output_pref({ dt => $issuedate, dateonly => 1, dateformat => 'iso' }) }; 
        }

        my $content = $json->encode($requestData);
        
        # carp Dumper($content);
        
        my $response = $self->{'ua'}->post($self->{'url'}, $self->{'requestHeader'}, Content => $content );
        
        if ( defined($response) && $response->is_success ) {
            
            my $data = $json->decode( $response->content );
            
            if ( $data && exists($data->{recommended_nds}) && $data->{recommended_nds} && scalar( @{ $data->{recommended_nds} } ) ) {
                my @bibnumbers;
                my $i = 0;
                foreach my $biblionumber( @{ $data->{recommended_nds} } ) {
                    last if ( $count && ++$i > $count);
                    push @bibnumbers, $biblionumber;
                }
                return GetCoverFlowDataByBiblionumber( @bibnumbers );
            }
            
        }
        else {
            carp "C4::External::BibtipRecommendations => Error requesting recommendations using url " .
                 $self->{'url'}.  ": " .
                 $response->error_as_HTML;
        }
    }
    
    return $result;
}

1;
