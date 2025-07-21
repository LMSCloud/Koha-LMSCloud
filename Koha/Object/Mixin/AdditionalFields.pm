package Koha::Object::Mixin::AdditionalFields;

use Modern::Perl;
use Koha::AdditionalFields;
use Koha::AdditionalFieldValues;

=head1 NAME

Koha::Object::Mixin::AdditionalFields

=head1 SYNOPSIS

    package Koha::Foo;

    use parent qw( Koha::Object Koha::Object::Mixin::AdditionalFields );

    sub _type { 'Foo' }


    package main;

    use Koha::Foo;

    Koha::Foos->find($id)->set_additional_fields(...);

=head1 API

=head2 Public methods

=head3 set_additional_fields

    $foo->set_additional_fields([
        {
            id => 1,
            value => 'foo',
        },
        {
            id => 2,
            value => 'bar',
        }
    ]);

=cut

sub set_additional_fields {
    my ($self, $additional_fields) = @_;

    $self->additional_field_values->delete;

    my $biblionumber;
    my $record;
    my $record_updated;
    if ($self->_result->has_column('biblionumber')) {
        $biblionumber = $self->biblionumber;
    }

    foreach my $additional_field (@$additional_fields) {
        my $field = Koha::AdditionalFields->find($additional_field->{id});
        my $value = $additional_field->{value};

        if ($biblionumber and $field->marcfield) {
            require Koha::Biblios;
            $record //= Koha::Biblios->find($biblionumber)->metadata->record;

            my ($tag, $subfield) = split /\$/, $field->marcfield;
            my $marc_field = $record->field($tag);
            if ($field->marcfield_mode eq 'get') {
                $value = $marc_field ? $marc_field->subfield($subfield) : '';
            } elsif ($field->marcfield_mode eq 'set') {
                if ($marc_field) {
                    $marc_field->update($subfield => $value);
                } else {
                    $marc_field = MARC::Field->new($tag, '', '', $subfield => $value);
                    $record->append_fields($marc_field);
                }
                $record_updated = 1;
            }
        }

        if (defined $value) {
            my $field_value = Koha::AdditionalFieldValue->new({
                field_id => $additional_field->{id},
                record_id => $self->id,
                value => $value,
            })->store;
        }
    }

    if ($record_updated) {
        C4::Biblio::ModBiblio($record, $biblionumber);
    }
}

=head3 additional_field_values

Returns additional field values

    my @values = $foo->additional_field_values;

=cut

sub additional_field_values {
    my ($self) = @_;

    my $afv_rs = $self->_result->additional_field_values;
    return Koha::AdditionalFieldValues->_new_from_dbic( $afv_rs );
}

=head3 extended_attributes

REST API embed of additional_field_values

=cut

sub extended_attributes {
    my ($self, $extended_attributes) = @_;

    if ($extended_attributes) {
        $self->set_additional_fields($extended_attributes);
    }
    my $afv_rs = $self->_result->extended_attributes;
    return Koha::AdditionalFieldValues->_new_from_dbic($afv_rs);
}

=head3 strings_map

Returns a map of column name to string representations including the string,
the mapping type and the mapping category where appropriate.

Currently handles additional fields values mappings.

Accepts a param hashref where the 'public' key denotes whether we want the public
or staff client strings.

=cut

sub strings_map {
    my ( $self, $params ) = @_;

    my $afvs    = $self->get_additional_field_values_for_template;
    my $strings = {};

    foreach my $af_id ( keys %{$afvs} ) {

        my $additional_field = Koha::AdditionalFields->find($af_id);
        my $av_cat           = $additional_field->effective_authorised_value_category;
        my @af_value_arr;
        my $af_value_str;
        my $value_to_push;

        foreach my $av_value ( @{ $afvs->{$af_id} } ) {
            if ($av_cat) {
                my $av = Koha::AuthorisedValues->search(
                    {
                        category         => $av_cat,
                        authorised_value => $av_value,
                    }
                );

                $value_to_push =
                    $av->count ? $params->{public} ? $av->next->opac_description : $av->next->lib : $av_value;
            } else {
                $value_to_push = $av_value;
            }
            push @af_value_arr, $value_to_push if $value_to_push;
        }

        $af_value_str = join( ", ", @af_value_arr );

        push(
            @{ $strings->{additional_field_values} },
            {
                field_label => $additional_field->name,
                value_str   => $af_value_str,
                type        => $av_cat ? 'av' : 'text',
                field_id    => $af_id,
            }
        );
    }

    my @sorted = sort { $a->{field_id} <=> $b->{field_id} } @{ $strings->{additional_field_values} };
    my @non_empty = grep { $_->{value_str} ne "" } @sorted;
    $strings->{additional_field_values} = \@non_empty;

    return $strings;
}

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=head1 COPYRIGHT AND LICENSE

Copyright 2018 BibLibre

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

Koha is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with Koha; if not, see <http://www.gnu.org/licenses>.

=cut

1;
