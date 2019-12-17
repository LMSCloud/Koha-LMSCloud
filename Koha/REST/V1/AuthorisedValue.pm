package Koha::REST::V1::AuthorisedValue;	

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

use Mojo::Base 'Mojolicious::Controller';

use C4::Auth qw( haspermission );
use Koha::AuthorisedValues;	

# sub list {
    # my ( $c) = @_;

    # my $user = $c->stash('koha.user');
    # unless ( $user && haspermission( $user->userid, { catalogue => 1 } ) ) {
        # return $c->$cb(
            # {
                # error => "You don't have the required permission"
            # },
            # 403
        # );
    # }
    # my $params       = $c->req->params->to_hash;
    # my $av = Koha::AuthorisedValues->search($params);

    # return $c->$cb( $av->unblessed, 200 );
# }

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $authvalues_set = Koha::AuthorisedValues->new;
        my $authvalues     = $c->objects->search( $authvalues_set, \&_to_model, \&_to_api );
        return $c->render( status => 200, openapi => $authvalues );
    }
    catch {
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
        return $c->render(
            status  => 500,
            openapi => { error => "$_" }
        );
    };
}

=head3 _to_api

Helper function that maps a hashref of Koha::Library attributes into REST api
attribute names.

=cut

sub _to_api {
    my $authorised_value = shift;

    # Rename attributes
    foreach my $column ( keys %{ $Koha::REST::V1::AuthorisedValue::to_api_mapping } ) {
        my $mapped_column = $Koha::REST::V1::AuthorisedValue::to_api_mapping->{$column};
        if (    exists $authorised_value->{ $column }
             && defined $mapped_column )
        {
            # key /= undef
            $authorised_value->{ $mapped_column } = delete $authorised_value->{ $column };
        }
        elsif (    exists $authorised_value->{ $column }
                && !defined $mapped_column )
        {
            # key == undef => to be deleted
            delete $authorised_value->{ $column };
        }
    }

    return $authorised_value;
}

=head3 _to_model

Helper function that maps REST api objects into Koha::Library
attribute names.

=cut

sub _to_model {
    my $authorised_value = shift;

    foreach my $attribute ( keys %{ $Koha::REST::V1::AuthorisedValue::to_model_mapping } ) {
        my $mapped_attribute = $Koha::REST::V1::AuthorisedValue::to_model_mapping->{$attribute};
        if (    exists $authorised_value->{ $attribute }
             && defined $mapped_attribute )
        {
            # key /= undef
            $authorised_value->{ $mapped_attribute } = delete $authorised_value->{ $attribute };
        }
        elsif (    exists $authorised_value->{ $attribute }
                && !defined $mapped_attribute )
        {
            # key == undef => to be deleted
            delete $authorised_value->{ $attribute };
        }
    }

    return $authorised_value;
}


=head2 Global variables

=head3 $to_api_mapping

=cut

our $to_api_mapping = {
    id               => 'id',
    category         => 'category',
    authorised_value => 'authorised_value',
    lib              => 'lib',
    lib_opac         => 'lib_opac',
    imageurl         => 'imageurl',
};

=head3 $to_model_mapping

=cut

our $to_model_mapping = {
    id               => 'id',
    category         => 'category',
    authorised_value => 'authorised_value',
    lib              => 'lib',
    lib_opac         => 'lib_opac',
    imageurl         => 'imageurl',
};

1;