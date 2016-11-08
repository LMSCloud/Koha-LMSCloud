package Koha::MetadataRecord;

# Copyright 2013 C & P Bibliography Services
#
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

=head1 NAME

Koha::MetadataRecord - base class for metadata records

=head1 SYNOPSIS

    my $record = new Koha::MetadataRecord({ 'record' => $record });

=head1 DESCRIPTION

Object-oriented class that encapsulates all metadata (i.e. bibliographic
and authority) records in Koha.

=cut

use Modern::Perl;

use Carp;
use C4::Biblio;
use Koha::Util::MARC;

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw( record schema format id ));


=head2 new

    my $metadata_record = new Koha::MetadataRecord({
                                record => $record,
                                schema => $schema,
                                format => $format,
                                id     => $id
                          });

Returns a Koha::MetadataRecord object encapsulating record metadata.

C<$record> is expected to be a deserialized object (for example
a MARC::Record or XML::LibXML::Document object or JSON).

C<$schema> is used to describe the metadata schema (for example
marc21, unimarc, dc, mods, etc).

C<$format> is used to specify the serialization format. It is important
for Koha::RecordProcessor because it will pick the right Koha::Filter
implementation based on this parameter. Valid values are:

   MARC (for MARC::Record objects)
   XML  (for XML::LibXML::Document objects)
   JSON (for JSON objects)

(optional) C<$id> is used so the record carries its own id and Koha doesn't
need to look for it inside the record.

=cut

sub new {

    my $class  = shift;
    my $params = shift;

    if (!defined $params->{ record }) {
        carp 'No record passed';
        return;
    }

    if (!defined $params->{ schema }) {
        carp 'No schema passed';
        return;
    }

    $params->{format} //= 'MARC';
    my $self = $class->SUPER::new($params);

    bless $self, $class;
    return $self;
}

=head2 createMergeHash

Create a hash for use when merging records. At the moment the only
metadata schema supported is MARC.

=cut

sub createMergeHash {
    my ($self, $tagslib) = @_;
    if ($self->schema =~ m/marc/) {
        return Koha::Util::MARC::createMergeHash($self->record, $tagslib);
    }
}

sub getKohaField {
    my ($self, $kohafield) = @_;

    if ($self->schema =~ m/marc/) {
        my $frameworkcode = ""; # FIXME Why do we use the default framework?
        my $mss = C4::Biblio::GetMarcSubfieldStructure( $frameworkcode );
        my $tagfield = $mss->{$kohafield};

        return '' if ref($tagfield) ne 'HASH';

        my ($tag, $subfield) = ( $tagfield->{tagfield}, $tagfield->{tagsubfield} );
        my @kohafield;
        foreach my $field ( $self->record->field($tag) ) {
            if ( $field->tag() < 10 ) {
                push @kohafield, $field->data();
            } else {
                foreach my $contents ( $field->subfield($subfield) ) {
                    push @kohafield, $contents;
                }
            }
        }

        return join ' | ', @kohafield;
    }
}

1;
