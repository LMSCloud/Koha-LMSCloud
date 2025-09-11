use utf8;
package Koha::Schema::Result::AggregatedStatisticsParameter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AggregatedStatisticsParameter

=head1 DESCRIPTION

contains additional selection parameters for a record in table aggregated_statistics.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aggregated_statistics_parameters>

=cut

__PACKAGE__->table("aggregated_statistics_parameters");

=head1 ACCESSORS

=head2 statistics_id

  data_type: 'integer'
  is_nullable: 0

foreign key from the aggregated_statistics table to identify the join (value of aggregated_statistics.id)

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

name of the parameter, e.g. "branchcode"

=head2 value

  data_type: 'mediumtext'
  is_nullable: 1

value of the parameter, eg. "Zentrale"

=cut

__PACKAGE__->add_columns(
  "statistics_id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "value",
  { data_type => "mediumtext", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</statistics_id>

=item * L</name>

=back

=cut

__PACKAGE__->set_primary_key("statistics_id", "name");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:R2WgyMSDkA91FTbm4u0doA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
