use utf8;
package Koha::Schema::Result::Browser;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Browser - store classification values

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

the classification level starting with 1

=head2 classification

  data_type: 'varchar'
  is_nullable: 0
  size: 255

the full classifcation value

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 255

the description of a classification value

=head2 number

  data_type: 'bigint'
  is_nullable: 0

the count of titles which are assigned to the classication value or level

=head2 endnode

  data_type: 'tinyint'
  is_nullable: 0

1 if the classifcation value represents a leafe node

=head2 parent

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

the parent the classification value

=head2 prefix

  data_type: 'varchar'
  is_nullable: 1
  size: 40

the prefix part of a the classifcation value

=head2 classval

  data_type: 'varchar'
  is_nullable: 1
  size: 40

the classication group part of the value

=head2 startrange

  data_type: 'varchar'
  is_nullable: 1
  size: 20

a numeric value part subordinated to a group

=head2 endrange

  data_type: 'varchar'
  is_nullable: 1
  size: 20

if the classification represents a higher level including a range of numbers it represents the end of the range

=head2 exclude

  data_type: 'mediumtext'
  is_nullable: 1

a search string that can be used to extend the query for titles of a classication value (e.g. exclude values that should not be found with a search)

=head2 usesearch

  data_type: 'mediumtext'
  is_nullable: 1

a search string to be used when searching for biblio records of the classification entry

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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-05-05 13:30:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yyZpC2oa18apf7Cp1y/Ejg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
