use utf8;
package Koha::Schema::Result::AggregatedStatisticsValue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AggregatedStatisticsValue

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aggregated_statistics_values>

=cut

__PACKAGE__->table("aggregated_statistics_values");

=head1 ACCESSORS

=head2 statistics_id

  data_type: 'integer'
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

=head2 value

  data_type: 'longtext'
  is_nullable: 1

=head2 type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 20

=cut

__PACKAGE__->add_columns(
  "statistics_id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "value",
  { data_type => "longtext", is_nullable => 1 },
  "type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 20 },
);

=head1 PRIMARY KEY

=over 4

=item * L</statistics_id>

=item * L</name>

=back

=cut

__PACKAGE__->set_primary_key("statistics_id", "name");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2018-11-26 12:25:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7VThyP++g65PQiDL0DB3Yg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
