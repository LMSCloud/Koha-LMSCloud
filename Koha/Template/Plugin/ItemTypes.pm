package Koha::Template::Plugin::ItemTypes;

# Copyright ByWater Solutions 2012

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
use C4::Koha;

use Template::Plugin;
use base qw( Template::Plugin );

use Koha::Cache::Memory::Lite;
use Koha::ItemTypes;
use Koha::Items;

sub GetDescription {
    my ( $self, $itemtypecode, $want_parent ) = @_;
    return q{} unless defined $itemtypecode;

    my $memory_cache = Koha::Cache::Memory::Lite->get_instance;
    my $cache_key    = $want_parent ? "Itemtype_parent_description:".$itemtypecode : "Itemtype_description:" . $itemtypecode;

    my $cached       = $memory_cache->get_from_cache($cache_key);
    return $cached if $cached;

    my $itemtype = Koha::ItemTypes->find( $itemtypecode );
    unless ($itemtype) {
        $memory_cache->set_in_cache( $cache_key, q{} );
        return q{};
    }

    my $parent;
    $parent = $itemtype->parent if $want_parent;

    my $description = $parent ? $parent->translated_description . "->" . $itemtype->translated_description : $itemtype->translated_description;
    $memory_cache->set_in_cache( $cache_key, $description );

    return $description;
}

sub GetImageLocation {
    my ( $self, $interface, $imageurl ) = @_;
    return C4::Koha::getitemtypeimagelocation( $interface, $imageurl );
}

sub Get {
    return Koha::ItemTypes->search_with_localization->unblessed;
}

sub GetBiblioItemtype {
    my ( $self, $biblioitemnumber ) = @_;
    my $biblioitem = Koha::Biblioitems->find( $biblioitemnumber );
    my $itype = undef;
    if ( $biblioitem ) {
        $itype = $biblioitem->itemtype;
    }
    if (! $itype ) {
        foreach my $item ( Koha::Items->search( { biblionumber => $biblioitemnumber } ) ) {
            if ( $item->itype ) {
                $itype = $item->itype; last;
            }
        }
    }
    return $itype;
}

1;
