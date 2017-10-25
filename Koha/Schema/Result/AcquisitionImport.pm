use utf8;
package Koha::Schema::Result::AcquisitionImport;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcquisitionImport

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acquisition_import>

=cut

__PACKAGE__->table("acquisition_import");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 vendor_id

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 200

=head2 object_type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

=head2 object_number

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

=head2 object_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 rec_type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

=head2 object_item_number

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 processingstate

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

=head2 processingtime

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 payload

  data_type: 'longtext'
  is_nullable: 0

=head2 object_reference

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "vendor_id",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 200 },
  "object_type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "object_number",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "object_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "rec_type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "object_item_number",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "processingstate",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "processingtime",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "payload",
  { data_type => "longtext", is_nullable => 0 },
  "object_reference",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2017-09-07 12:38:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lQi78W+VyQsdCCZhCF34Sw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
