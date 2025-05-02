package Koha::Template::Plugin::AdditionalFields;

# Copyright ByWater Solutions 2023

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

use Template::Plugin ();
use base             qw( Template::Plugin );

use Koha::AdditionalFields ();
use Koha::AuthorisedValues ();

sub all {
    my ( $self, $params ) = @_;
    return Koha::AdditionalFields->search($params);
}

sub with_authorised_values {
    my ( $self, $params ) = @_;

    # Get additional fields with the given parameters
    my $additional_fields = Koha::AdditionalFields->search($params);

    # Collect all unique authorized value categories
    my %av_categories;
    my @fields_with_av;

    while ( my $field = $additional_fields->next ) {
        my $field_data = {
            extended_attribute_type_id     => $field->id,
            name                           => $field->name,
            resource_type                  => $field->tablename,
            authorised_value_category_name => $field->authorised_value_category,
            marc_field                     => $field->marcfield,
            marc_field_mode                => $field->marcfield_mode,
            searchable                     => $field->searchable,
            repeatable                     => $field->repeatable,
            authorised_values              => []
        };

        # If this field has an authorized value category, collect the values
        if ( $field->authorised_value_category ) {
            $av_categories{ $field->authorised_value_category } = 1;

            # Get authorized values for this category
            my $avs = Koha::AuthorisedValues->search(
                { category => $field->authorised_value_category },
                { order_by => [ 'lib', 'lib_opac' ] }
            );

            while ( my $av = $avs->next ) {
                push @{ $field_data->{authorised_values} }, {
                    authorised_value_id => $av->id,
                    category_name       => $av->category,
                    value               => $av->authorised_value,
                    description         => $av->lib,
                    opac_description    => $av->opac_description,
                    image_url           => $av->imageurl
                };
            }
        }

        push @fields_with_av, $field_data;
    }

    # Create a comprehensive authorized values lookup by category
    my %authorised_values_by_category;
    foreach my $category ( keys %av_categories ) {
        my $avs = Koha::AuthorisedValues->search(
            { category => $category },
            { order_by => [ 'lib', 'lib_opac' ] }
        );

        my @values;
        while ( my $av = $avs->next ) {
            push @values, {
                authorised_value_id => $av->id,
                category_name       => $av->category,
                value               => $av->authorised_value,
                description         => $av->lib,
                opac_description    => $av->opac_description,
                image_url           => $av->imageurl
            };
        }
        $authorised_values_by_category{$category} = \@values;
    }

    return {
        fields                        => \@fields_with_av,
        authorised_values_by_category => \%authorised_values_by_category
    };
}

1;

=head1 NAME

Koha::Template::Plugin::AdditionalFields - TT Plugin for retrieving additional fields

=head1 SYNOPSIS

[% USE AdditionalFields %]

[% AdditionalFields.all() %]

[% AdditionalFields.with_authorised_values({ tablename => 'bookings' }) %]

=head1 ROUTINES

=head2 all

In a template, you can get the searchable additional fields with
the following TT code: [% AdditionalFields.all( staff_searchable => 1 ) %]

The function returns the Koha::AdditionalFields objects

=head2 with_authorised_values

In a template, you can get additional fields with their linked authorized values with
the following TT code: [% AdditionalFields.with_authorised_values({ tablename => 'bookings' }) %]

The function returns a hash with two keys:
- fields: Array of additional field objects with their linked authorized values
- authorised_values_by_category: Hash of authorized values grouped by category

=head1 AUTHOR

Nick Clemens <nick@bywatersolutions.com>
Paul Derscheid <paul.derscheid@lmscloud.de>

=cut
