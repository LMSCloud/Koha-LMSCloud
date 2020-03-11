use utf8;
package Koha::Schema::Result::ExternalOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ExternalOrder

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<external_order>

=cut

__PACKAGE__->table("external_order");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 branchcode

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 0

=head2 external_order_id

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 order_type

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 order_time

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 order_data

  data_type: 'mediumtext'
  is_nullable: 0

=head2 processing_status

  data_type: 'enum'
  default_value: 'new'
  extra: {list => ["new","progress","ready"]}
  is_nullable: 0

=head2 created

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 last_update

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "branchcode",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "borrowernumber",
  { data_type => "integer", is_nullable => 0 },
  "external_order_id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "order_type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "order_time",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "order_data",
  { data_type => "mediumtext", is_nullable => 0 },
  "processing_status",
  {
    data_type => "enum",
    default_value => "new",
    extra => { list => ["new", "progress", "ready"] },
    is_nullable => 0,
  },
  "created",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "last_update",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<external_order_extid>

=over 4

=item * L</order_type>

=item * L</external_order_id>

=back

=cut

__PACKAGE__->add_unique_constraint("external_order_extid", ["order_type", "external_order_id"]);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2020-03-10 23:08:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:z3WbcaZRc4/1Ts9U7F509w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
