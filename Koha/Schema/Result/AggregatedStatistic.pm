use utf8;
package Koha::Schema::Result::AggregatedStatistic;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AggregatedStatistic

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aggregated_statistics>

=cut

__PACKAGE__->table("aggregated_statistics");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 200

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

=head2 startdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 enddate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 200 },
  "description",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "startdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "enddate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2018-01-10 17:34:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l6mytzDpFV+V4cE86dNimw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
