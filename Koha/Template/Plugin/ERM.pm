package Koha::Template::Plugin::ERM;

# Copyright LMSCloud GmbH 2026

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

use Template::Plugin;
use base qw( Template::Plugin );

use Koha::ERM::EHoldings::Titles;

sub getAToZList {
    my ( $self, $params ) = @_;
    my $searchParams = $params || {};
    my @titles = Koha::ERM::EHoldings::Titles->search($params)->as_list();
	@titles = sort { lc($a->publication_title ? $a->publication_title : "") cmp lc($b->publication_title ? $b->publication_title : "") }
    return \@titles;
}

1;
