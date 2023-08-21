package Koha::SearchEngine::Elasticsearch::AutoComplete;

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

Koha::SearchEngine::ElasticSearch::AutoComplete - auto-completion of input texts with Elasticsearch

=head1 SYNOPSIS

    my $complete =
      Koha::SearchEngine::Elasticsearch::AutoComplete->new( { index => 'biblios' } );
    my @resultlist  = $complete->complete(
        {
            'text' => 'wonder',
            'field' => 'title',
            'count' => '20'
        }
    );

=head1 DESCRIPTION

Returns a list of available index terms for a given starting phrase.

=head1 METHODS

=cut

use base qw(Koha::SearchEngine::Elasticsearch);
use Modern::Perl;
use Scalar::Util qw(reftype);
use JSON;
use Unicode::Normalize;

use Koha::SearchEngine::Elasticsearch::QueryBuilder;

=head2 complete

    my @resultlist = $complete->complete({
            'text' => 'wonder',
            'field' => 'title',
            'count' => '20'
        });

Does a index scan for the given C<$text>, looking in C<$field>. Options are:

=over 4

=item text

The prefix text as starting term.

=item field

The field index. Could be one of the following: title, author, subject, isbn, 
issn, title-series, callnum or other Elasticssearch indexes available as suggestion
index.
If fiels is not provided, the suggestion index fields title, author, subject, isbn, 
issn, title-series and callnum are used to build the terms.

=item text

The count of entries that should be returned.

=back

=head3 Returns

This returns a list of availale completion terms.

=cut

sub complete {
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
                if ( $suggestion =~ /_suggestion$/ ) {
                    my $options = $results->{suggest}{$suggestion}[0]{options};
                    foreach my $option(@$options) {
                        push @result, $option->{text} if ( ++$uniqResult{$option->{text}} == 1 );
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
    
    my $count = 20;
    
    if ( defined $request->{count} && $request->{count} =~ /^[0-9]+$/ && $request->{count} > 0 && $request->{count} < 1000 ) {
        $count = $request->{count};
    }
    
    my $field = $request->{field};
    my @fields;
    @fields = grep { $_ =~ s/^\s+|\s+$//; $_ } split(/,/,C4::Context->preference('ElasticsearchDefaultAutoCompleteIndexFields')) if (!defined $field || $field =~ /^\s*$/);
    
    if ( $field ) {
        my $index_params = Koha::SearchEngine::Elasticsearch::QueryBuilder->get_index_field_convert();
        if ( exists( $index_params->{$field} ) ) {
            $fields[0] = $index_params->{$field};
        } else {
            $fields[0] = $field;
        }
    }
    
    # Default fields are 'title,author,subject,title-series,local-classification'
    if (! scalar(@fields) ) {
        @fields = ('title','author','subject','title-series','local-classification');
    }
    
    my $mappings = $self->get_elasticsearch_mappings();
    my @suggestionfields;
    for $field(@fields) {
        push @suggestionfields, $field if ( exists($mappings->{properties}->{$field}) && exists($mappings->{properties}->{"${field}__suggestion"}) );
    }
    
    my $query = {
        _source => ["title-cover","author-title"],
        size    => 1,
        suggest => {}
    };
    foreach $field(@suggestionfields) {
        $query->{suggest}->{"${field}_suggestion"} =
            {
                prefix => $searchstring,
                completion => {
                    field           => "${field}__suggestion",
                    size            => $count,
                    skip_duplicates => JSON::true
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
