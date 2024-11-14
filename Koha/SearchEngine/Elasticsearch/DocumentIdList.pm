package Koha::SearchEngine::Elasticsearch::DocumentIdList;

# Copyright 2024 LMSCloud GmbH
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

Koha::SearchEngine::ElasticSearch::DocumentIdList - generate a list of document IDs of the Elasticsearch index

=head1 SYNOPSIS

    my $idListGenerator =
      Koha::SearchEngine::Elasticsearch::DocumentIdList->new( { index => 'biblios' } );
    my @resultlist  = $didyoumean->getIDList();

=head1 DESCRIPTION

Returns a list of document IDs of the Elasticsearch index.

=head1 METHODS

=cut

use base qw(Koha::SearchEngine::Elasticsearch);
use Modern::Perl;
use JSON;
use Data::Dumper;

=head2 find

    my @resultlist = $idListGenerator->getIDList();

Retrieve the defined document IDs in ElasticSearch

=head3 Returns

This returns a list of docuemnt IDs.

=cut

sub getIDList {
    my ($self, $request) = @_;

    my $IDList = {};
    my $count = 0;
    # get the document count
    my $elasticsearch = $self->get_elasticsearch();
    my $result = $elasticsearch->count(
        index => $self->index_name
    );
    
    
    if ( defined $result && defined($result->{count}) ) {
        $count = $result->{count} + 0;
        
        my $IDsFound = 0;
        my $lastID = undef;
        my $size = 10000;
        my $continue = $count;
        
        while ( $continue > 0 ) {
            
            my $query = {
                            index => $self->index_name,
                            body => {
                                size => $size,
                                fields => [ ],
                                query => {
                                    match_all => {}
                                },
                                sort => [ { "biblioitemnumber__sort" => "asc" } ],
                                _source => \0
                            }
                        };
            
            if ( $lastID ) {
                $query->{body}->{search_after} = [ $lastID ];
            }
            
            # now search retrieve all document IDs
            $result = $elasticsearch->search($query);
            if ( defined $result && defined $result->{hits} && $result->{hits}->{hits} ) {
                my $hits = $result->{hits}->{hits};
                foreach my $hit(@$hits) {
                    $IDList->{$hit->{_id}} = 1;
                    $IDsFound++;
                    $lastID = $hit->{sort}->[0];
                }
                # print Dumper($result);
            }
            
            $continue -= $size;
        }
    }
    
    # print scalar(keys %$IDList), " IDs of $count found\n";

    return sort { $a =~ /^[0-9]+$/ && $b =~ /^[0-9]+$/ ? $a <=> $b : $a cmp $b } keys %$IDList;
}

1;

__END__

=head1 AUTHOR

=over 4

=item Roger Grossmann << <roger.grossmann@lmscloud.de> >>

=back

=cut

