use utf8;
package Koha::Schema::Result::AcquisitionImport;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcquisitionImport

=head1 DESCRIPTION

for backtracking the vendors information on order, delivery, invoice, etc.

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

unique key, used to identify the record

=head2 vendor_id

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 200

code for identifying the vendor, e.g. "ekz"

=head2 object_type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

code of object type, eg. "order", "delivery", "invoice"

=head2 object_number

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

number of this object, set by vendor

=head2 object_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

date linked to the object, eg. order date, invoice date

=head2 rec_type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

code for type of this record, e.g. "message", "title", "item"

=head2 object_item_number

  data_type: 'varchar'
  is_nullable: 1
  size: 255

number of this object item, set by vendor

=head2 processingstate

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

code for state of this object item when record was created, e.g. "ordered", "delivered", "invoiced"

=head2 processingtime

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time when record was created

=head2 payload

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 0

payload of message received from vendor (only if rec_type=="message")

=head2 object_reference

  data_type: 'integer'
  is_nullable: 1

reference to base object (acquisition_import.id), e.g. the order item a invoice item refers to

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
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
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
  { data_type => "longtext", default_value => "''", is_nullable => 0 },
  "object_reference",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XpJuBL5c+PQa77lAU/7HHw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
