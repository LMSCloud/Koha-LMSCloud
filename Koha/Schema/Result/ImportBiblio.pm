use utf8;
package Koha::Schema::Result::ImportBiblio;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ImportBiblio

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<import_biblios>

=cut

__PACKAGE__->table("import_biblios");

=head1 ACCESSORS

=head2 import_record_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 matched_biblionumber

  data_type: 'integer'
  is_nullable: 1

=head2 control_number

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 original_source

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 title

  data_type: 'longtext'
  is_nullable: 1

=head2 author

  data_type: 'longtext'
  is_nullable: 1

=head2 isbn

  data_type: 'longtext'
  is_nullable: 1

=head2 issn

  data_type: 'longtext'
  is_nullable: 1

=head2 has_items

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "import_record_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "matched_biblionumber",
  { data_type => "integer", is_nullable => 1 },
  "control_number",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "original_source",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "title",
  { data_type => "longtext", is_nullable => 1 },
  "author",
  { data_type => "longtext", is_nullable => 1 },
  "isbn",
  { data_type => "longtext", is_nullable => 1 },
  "issn",
  { data_type => "longtext", is_nullable => 1 },
  "has_items",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 RELATIONS

=head2 import_record

Type: belongs_to

Related object: L<Koha::Schema::Result::ImportRecord>

=cut

__PACKAGE__->belongs_to(
  "import_record",
  "Koha::Schema::Result::ImportRecord",
  { import_record_id => "import_record_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2020-11-03 09:53:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/nOWo4fGjdch+K0T+07cSw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
