package Koha::SearchEngine::Search;

# This file is part of Koha.
#
# Copyright 2015 Catalyst IT
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

# This is a shim that gives you the appropriate search object for your
# system preference.

=head1 NAME

Koha::SearchEngine::Search - instantiate the search object that corresponds to
the C<SearchEngine> system preference.

=head1 DESCRIPTION

This allows you to be agnostic about what the search engine configuration is
and just get whatever search object you need.

=head1 SYNOPSIS

    use Koha::SearchEngine::Search;
    my $searcher = Koha::SearchEngine::Search->new();

=head1 METHODS

=head2 new

Creates a new C<Search> of whatever the relevant type is.

=cut

use Modern::Perl;
use C4::Context;
use C4::Biblio qw//;

sub new {
    my $engine = C4::Context->preference("SearchEngine") // 'Zebra';
    my $file = "Koha/SearchEngine/${engine}/Search.pm";
    my $class = "Koha::SearchEngine::${engine}::Search";
    require $file;
    shift @_;
    return $class->new(@_);
}

=head2 extract_biblionumber

    my $biblionumber = $searcher->extract_biblionumber( $marc );

Returns the biblionumber from $marc. The routine is called from the
extract_biblionumber method of the specific search engine.

=cut

sub extract_biblionumber {
    my ( $record ) = @_;
    return if ref($record) ne 'MARC::Record';
    my ( $biblionumbertagfield, $biblionumbertagsubfield ) = C4::Biblio::GetMarcFromKohaField( 'biblio.biblionumber', '' );
    if( $biblionumbertagfield < 10 ) {
        my $controlfield = $record->field( $biblionumbertagfield );
        return $controlfield ? $controlfield->data : undef;
    }
    return $record->subfield( $biblionumbertagfield, $biblionumbertagsubfield );
}

1;
