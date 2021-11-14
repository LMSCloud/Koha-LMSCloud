package Koha::SearchEngine::Elasticsearch::DidYouMean;

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

=head1 NAME

Koha::SearchEngine::ElasticSearch::DidYouMean - search for similar search expressions

=head1 SYNOPSIS

    my $didyoumean =
      Koha::SearchEngine::Elasticsearch::DidYouMean->new( { index => 'biblios' } );
    my @resultlist  = $didyoumean->find(
        {
            'text' => 'wonder'
        }
    );

=head1 DESCRIPTION

Returns a list of matchings search expressions.

=head1 METHODS

=cut

use base qw(Koha::SearchEngine::Elasticsearch);
use Modern::Perl;
use Scalar::Util qw(reftype);
use JSON;
use Unicode::Normalize;

use Koha::SearchEngine::Elasticsearch::QueryBuilder;

=head2 find

    my @resultlist = $didyoumean->find({
            'text' => 'wonder'
        });

Does a index scan for the given C<$text> 

=head3 Returns

This returns a list of search expressions.

=cut

sub find {
    my ($self, $request) = @_;

    my @result;
    my %uniqResult;
    my ($query,$count) = $self->_build_query($request);

    if ( $query ) {
        my $elasticsearch = $self->get_elasticsearch();
        my $results = $elasticsearch->search(
            index => $self->index_name,
            body => $query
        );
        if ( defined $results->{suggest} ) {
            foreach my $suggestion(keys %{$results->{suggest}}) {
                if ( $suggestion =~ /_phrase$/ ) {
                    my $options = $results->{suggest}{$suggestion}[0]{options};
                    foreach my $option(@$options) {
                        push @result, $option->{text} if ( ++$uniqResult{$option->{text}} == 1 && $option->{collate_match} );
                    }
                }
            }
        }
        @result = sort { lc(NFD($a)) cmp lc(NFD($b)) } @result;
        if ( scalar(@result) > $count ) {
            splice @result, $count;
        }
    }

    return @result;
}

=head2 _build_query

    my $query = $self->_build_query($prefix, $field, $options);

Arguments are the same as for L<browse>. This will return a query structure
for elasticsearch to use.

=cut

sub _build_query {
    my ( $self, $request ) = @_;
    
    return undef if (! defined $request);
    return undef if (! reftype($request) eq 'HASH' );
    
    my $searchstring = $request->{text};
    return undef if (! defined $searchstring);
    
    my $count = 3;
    
    if ( defined $request->{count} && $request->{count} =~ /^[0-9]+$/ && $request->{count} > 0 && $request->{count} < 20 ) {
        $count = $request->{count};
    }
    
    my $field = $request->{field};
    my @fields;
    @fields = ('title','author','subject','title-series') if (!defined $field || $field =~ /^\s*$/);
    
    if ( $field ) {
        my $index_params = Koha::SearchEngine::Elasticsearch::QueryBuilder->get_index_field_convert();
        if ( exists( $index_params->{$field} ) ) {
            $fields[0] = $index_params->{$field};
        } else {
            $fields[0] = $field;
        }
    }
    
    my $mappings = $self->get_elasticsearch_mappings();
    my @suggestionfields;
    for $field(@fields) {
        push @suggestionfields, $field if ( exists($mappings->{data}->{properties}->{$field}) );
    }
    
    my $query = {
        size    => 1,
        suggest => { text => $searchstring }
    };
    foreach $field(@suggestionfields) {
        $query->{suggest}->{"${field}_phrase"} =
            {
                phrase => {
                    field => "${field}.trigram",
                    size  => $count,
                    gram_size => 3,
                    direct_generator => [ 
                        {
                            field => "${field}.trigram",
                            suggest_mode => "popular",
                            min_doc_freq => 1
                        } 
                    ],
                    highlight => {
                        pre_tag => "<em>",
                        post_tag => "</em>"
                    },
                    collate => {
                        query => { 
                            source => {
                                match_phrase => {
                                    title => '{{suggestion}}'
                                }
                            }
                        },
                        prune => JSON::true
                    }
                }
            };
    }
    return ($query,$count);
}

1;

__END__

=head1 AUTHOR

=over 4

=item Roger Grossmann << <roger.grossmann@lmscloud.de> >>

=back

=cut
