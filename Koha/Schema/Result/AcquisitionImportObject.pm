use utf8;
package Koha::Schema::Result::AcquisitionImportObject;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcquisitionImportObject

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

=head2 acquisition_import_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 koha_object

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

=head2 koha_object_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

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


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2017-09-07 12:38:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cecA2CX6bah3O+Pi/fnc6w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
