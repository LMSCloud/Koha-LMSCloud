package Koha::NewsItem;

# Copyright ByWater Solutions 2015
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

use Carp;

use Koha::Database;
use Koha::Patrons;

use base qw(Koha::Object);

=head1 NAME

Koha::NewsItem - Koha News Item object class

Koha::NewsItem represents a single piece of news from the opac_news table

=head1 API

=head2 Class Methods

=cut

=head3 author

    $newsitem->author;

Return the Koha::Patron object for the patron who authored this news item

=cut

sub author {
    my ($self) = @_;
    my $author_rs = $self->_result->borrowernumber;
    return unless $author_rs;
    return Koha::Patron->_new_from_dbic($author_rs);
}

=head3 _type

=cut

sub _type {
    return 'OpacNews';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
