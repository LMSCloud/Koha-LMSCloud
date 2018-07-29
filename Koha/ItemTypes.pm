package Koha::ItemTypes;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;

use C4::Languages;

use Koha::Database;
use Koha::ItemType;

use base qw(Koha::Objects);

=head1 NAME

Koha::ItemTypes - Koha ItemType Object set class

=head1 API

=head2 Class Methods

=cut

=head3 search_with_localization

my $itemtypes = Koha::ItemTypes->search_with_localization

=cut

sub search_with_localization {
    my ( $self, $params, $attributes ) = @_;

    my $language = C4::Languages::getlanguage();
    $Koha::Schema::Result::Itemtype::LANGUAGE = $language;
    $attributes->{order_by} = 'translated_description' unless exists $attributes->{order_by};
    $attributes->{join} = 'localization';
    $attributes->{'+select'} = [
        {
            coalesce => [qw( localization.translation me.description )],
            -as      => 'translated_description'
        }
    ];
    $self->SUPER::search( $params, $attributes );
}

=head3 type

=cut

sub _type {
    return 'Itemtype';
}

sub object_class {
    return 'Koha::ItemType';
}

1;
