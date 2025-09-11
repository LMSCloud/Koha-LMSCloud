use utf8;
package Koha::Schema::Result::Browser;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Browser

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<browser>

=cut

__PACKAGE__->table("browser");

=head1 ACCESSORS

=head2 level

  data_type: 'integer'
  is_nullable: 0

=head2 classification

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 number

  data_type: 'bigint'
  is_nullable: 0

=head2 endnode

  data_type: 'tinyint'
  is_nullable: 0

=head2 parent

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 prefix

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 classval

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 startrange

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 endrange

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 exclude

  data_type: 'mediumtext'
  is_nullable: 1

=head2 usesearch

  data_type: 'mediumtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "level",
  { data_type => "integer", is_nullable => 0 },
  "classification",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "number",
  { data_type => "bigint", is_nullable => 0 },
  "endnode",
  { data_type => "tinyint", is_nullable => 0 },
  "parent",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "prefix",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "classval",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "startrange",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "endrange",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "exclude",
  { data_type => "mediumtext", is_nullable => 1 },
  "usesearch",
  { data_type => "mediumtext", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EV8BCz1TfUOmWdHNa1Ebww


# You can replace this text with custom content, and it will be preserved on regeneration
1;
