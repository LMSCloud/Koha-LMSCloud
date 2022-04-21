package Koha::SuggestionEngine::Plugin::ElasticsearchSuggester;

# Copyright (C) 2021 LMSCloud GmbH
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
use LWP::UserAgent;
use XML::Simple qw(XMLin);
use C4::Context;
use base qw(Koha::SuggestionEngine::Base);
use Koha::SearchEngine::Elasticsearch::DidYouMean;

sub NAME {
    return 'ElasticsearchSuggester';
}

sub get_suggestions {
    my ($self, $query) = @_;
    
    my @results;
    
    if ( C4::Context->preference('SearchEngine') eq 'Elasticsearch' && $query && defined $query->{'search'} && $query->{'search'} !~ /[:=]/ ) {
        my $didyoumean = Koha::SearchEngine::Elasticsearch::DidYouMean->new( { index => 'biblios' } );
        my @resultlist  = $didyoumean->find(
            {
                'text' => $query->{'search'},
                'count' => 4
            }
        );
        my $scoresub = 0;
        foreach my $label(@resultlist) {
            push @results,
            {
                'search'  => $label,
                relevance => 100 + $scoresub++,
                label => $label
            };
        }
    }
    return \@results;
}

1;
__END__

=head1 NAME

Koha::SuggestionEngine::Plugin::ElasticsearchSuggester

=head2 FUNCTIONS

This gets "Did you mean?" expressions using Elasticsearch suggestions

=over

=item NAME

my $name = $plugin->NAME;

=back

=over

=item get_suggestions(query)

Sends in the search query to Elasticsearch to get the suggestion

my $suggestions = $plugin->get_suggestions(\%query);

=back

=cut

=head1 NOTES

=cut

=head1 AUTHOR

Roger Grossmann <roger.grossmann@mlscloud.de>

=cut