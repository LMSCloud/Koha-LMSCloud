use utf8;
package Koha::Schema::Result::CashRegisterDefinition;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CashRegisterDefinition

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cash_register_definition>

=cut

__PACKAGE__->table("cash_register_definition");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 branchcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 manager_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 prev_manager_id

  data_type: 'integer'
  is_nullable: 1

=head2 modification_time

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 no_branch_restriction

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "branchcode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "manager_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "prev_manager_id",
  { data_type => "integer", is_nullable => 1 },
  "modification_time",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "no_branch_restriction",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<pseudo_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("pseudo_key", ["name"]);

=head1 RELATIONS

=head2 cash_register_accounts

Type: has_many

Related object: L<Koha::Schema::Result::CashRegisterAccount>

=cut

__PACKAGE__->has_many(
  "cash_register_accounts",
  "Koha::Schema::Result::CashRegisterAccount",
  { "foreign.cash_register_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cash_register_managers

Type: has_many

Related object: L<Koha::Schema::Result::CashRegisterManager>

=cut

__PACKAGE__->has_many(
  "cash_register_managers",
  "Koha::Schema::Result::CashRegisterManager",
  { "foreign.cash_register_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 manager

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "manager",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "manager_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2017-07-11 15:03:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7nsN1hgXaGBR1h2bVtuVtQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;