use utf8;
package Koha::Schema::Result::LanguageDescription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::LanguageDescription

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<language_descriptions>

=cut

__PACKAGE__->table("language_descriptions");

=head1 ACCESSORS

=head2 subtag

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 type

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 lang

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "subtag",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "lang",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<uniq_desc>

=over 4

=item * L</subtag>

=item * L</type>

=item * L</lang>

=back

=cut

__PACKAGE__->add_unique_constraint("uniq_desc", ["subtag", "type", "lang"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-02-02 07:12:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ztJaB84tQXb1T6MnBP/zrQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
