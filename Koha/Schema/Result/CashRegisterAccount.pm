use utf8;
package Koha::Schema::Result::CashRegisterAccount;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CashRegisterAccount

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cash_register_account>

=cut

__PACKAGE__->table("cash_register_account");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 cash_register_account_id

  data_type: 'integer'
  is_nullable: 0

=head2 cash_register_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 manager_id

  data_type: 'integer'
  is_nullable: 0

=head2 booking_time

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 accountlines_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 current_balance

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

=head2 action

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 booking_amount

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 description

  data_type: 'longtext'
  is_nullable: 1

=head2 reason

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "cash_register_account_id",
  { data_type => "integer", is_nullable => 0 },
  "cash_register_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "manager_id",
  { data_type => "integer", is_nullable => 0 },
  "booking_time",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "accountlines_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "current_balance",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "action",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "booking_amount",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "description",
  { data_type => "longtext", is_nullable => 1 },
  "reason",
  { data_type => "varchar", is_nullable => 1, size => 250 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cash_reg_account_idx_account_id>

=over 4

=item * L</cash_register_account_id>

=item * L</cash_register_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "cash_reg_account_idx_account_id",
  ["cash_register_account_id", "cash_register_id"],
);

=head1 RELATIONS

=head2 accountline

Type: belongs_to

Related object: L<Koha::Schema::Result::Accountline>

=cut

__PACKAGE__->belongs_to(
  "accountline",
  "Koha::Schema::Result::Accountline",
  { accountlines_id => "accountlines_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 cash_register

Type: belongs_to

Related object: L<Koha::Schema::Result::CashRegister>

=cut

__PACKAGE__->belongs_to(
  "cash_register",
  "Koha::Schema::Result::CashRegister",
  { id => "cash_register_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2018-11-26 12:35:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VeIMWJewRpMoOkppwXL1VQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
