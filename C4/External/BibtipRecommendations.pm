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
use Koha::DateUtils qw( dt_from_string output_pref );

use LWP::UserAgent;
use JSON;

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

    $self->{'ua'}  = $ua;
    $self->{'url'} = 'https://recommender.bibtip.de/recommender/vector_recs/apiv1/' . $bibtipCatalog . '/vector_reclist.json';

    $self->{'requestHeader'} = [ 'Accept' => 'application/json' ];

    return $self;

}

=head2 getPatronSpecificRecommendations

Get recommendations for a specific user based on the reading history (list of biblionumber).

=cut

sub getPatronSpecificRecommendations {
    my ( $self, $borrowernumber, $count ) = @_;
    my $result = [];

    my $biblionumbers = $self->_get_old_issues($borrowernumber);
    my $requestData   = $self->_get_request_data($biblionumbers);

    my $content  = JSON->new->utf8->allow_nonref->encode($requestData);
    my $response = $self->{'ua'}->post( $self->{'url'}, $self->{'requestHeader'}, Content => $content );

    return $result unless ( defined($response) && $response->is_success );

    my $data = JSON->new->decode( $response->content );
    unless ( $data && exists( $data->{recommended_nds} ) && $data->{recommended_nds} && scalar( @{ $data->{recommended_nds} } ) ) {
        carp "C4::External::BibtipRecommendations => Invalid response from Bibtip API";
        return $result;
    }

    my $bibnumbers = [];
    my $i          = 0;
    foreach my $biblionumber ( @{ $data->{recommended_nds} } ) {
        last if ( $count && ++$i > $count );
        push @{$bibnumbers}, $biblionumber;
    }
    my $coverFlowData = GetCoverFlowDataByBiblionumber( @{$bibnumbers} );
    if ( ref($coverFlowData) eq 'ARRAY' ) {
        carp sprintf( "C4::External::BibtipRecommendations => Unexpected response from GetCoverFlowDataByBiblionumber: %s", $coverFlowData );
        return $result;
    }

    return $coverFlowData;
}

sub _get_old_issues {
    my ( $self, $borrowernumber ) = @_;
    my $biblionumbers      = [];
    my $seen_biblionumbers = {};

    # Get current and old issues of the patron combined
    my $criteria   = { borrowernumber => $borrowernumber, };
    my $sort       = { 'order_by'     => { '-desc' => 'issuedate' } };
    my $rs_current = Koha::Checkouts->search( $criteria, $sort );
    my $rs_old     = Koha::Old::Checkouts->search( $criteria, $sort );

    # Process current checkouts
    while ( my $issue = $rs_current->next ) {
        _process_issue( $issue, $biblionumbers, $seen_biblionumbers );
    }

    # Process old checkouts
    while ( my $issue = $rs_old->next ) {
        _process_issue( $issue, $biblionumbers, $seen_biblionumbers );
    }

    return $biblionumbers;
}

sub _process_issue {
    my ( $issue, $biblionumbers, $seen_biblionumbers ) = @_;
    my $itemnumber = $issue->itemnumber;
    if ($itemnumber) {
        my $item = Koha::Items->find($itemnumber);
        if ($item) {
            return if ( exists( $seen_biblionumbers->{ $item->biblionumber } ) );
            push @{$biblionumbers}, [ $item->biblionumber, $issue->issuedate ];
            $seen_biblionumbers->{ $item->biblionumber } = 1;
        }
    }
}

sub _get_request_data {
    my ( $self, $biblionumbers ) = @_;
    my $requestData = { items => [] };

    foreach my $issue ( @{$biblionumbers} ) {
        my $biblionumber = $issue->[0];
        my $issuedate    = dt_from_string( $issue->[1] );

        push @{ $requestData->{items} },
            {
            nd   => "$biblionumber",
            date => output_pref( { dt => $issuedate, dateonly => 1, dateformat => 'iso' } )
            };
    }

    return $requestData;
}

1;
