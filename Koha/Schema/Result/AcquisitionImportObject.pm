use utf8;
package Koha::Schema::Result::AcquisitionImportObject;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcquisitionImportObject

=head1 DESCRIPTION

supplement to table acquisition_import, showing the connection to Koha records automatically created based on vendors information on orders, deliveries, invoices, etc.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acquisition_import_objects>

=cut

__PACKAGE__->table("acquisition_import_objects");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique key, used to identify the record

=head2 acquisition_import_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

foreign key from the acquisition_import table to identify the connection (value of acquisition_import.id)

=head2 koha_object

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

code of type of created koha object, eg. "title", "item"

=head2 koha_object_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

foreign key of the connected Koha record, e.g. value of items.itemnumber

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "acquisition_import_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "koha_object",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "koha_object_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CxaXpxyLf+awmzsBQwh46w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
