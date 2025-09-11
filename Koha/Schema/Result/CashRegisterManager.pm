use utf8;
package Koha::Schema::Result::CashRegisterManager;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CashRegisterManager

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cash_register_manager>

=cut

__PACKAGE__->table("cash_register_manager");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

ID of the cash register manager record

=head2 cash_register_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

ID of the cash register (cash_register_definition.id)

=head2 manager_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

the staff member who is allowed to manage the cash register (borrowers.borrowernumber)

=head2 modification_time

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

when was the entry last time changed

=head2 authorized_by

  data_type: 'varchar'
  is_nullable: 1
  size: 11

the staff member who authorized the manager to manage the cash register (borrowers.borrowernumber)

=head2 opened

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

this value is used to mark a manager as active for a register if multiple users are authorized to book to a register simultaneously; a staff member can have only one opened cash

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "cash_register_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "manager_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "modification_time",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "authorized_by",
  { data_type => "varchar", is_nullable => 1, size => 11 },
  "opened",
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

=item * L</cash_register_id>

=item * L</manager_id>

=back

=cut

__PACKAGE__->add_unique_constraint("pseudo_key", ["cash_register_id", "manager_id"]);

=head1 RELATIONS

=head2 cash_register

Type: belongs_to

Related object: L<Koha::Schema::Result::CashRegisterDefinition>

=cut

__PACKAGE__->belongs_to(
  "cash_register",
  "Koha::Schema::Result::CashRegisterDefinition",
  { id => "cash_register_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 manager

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "manager",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "manager_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:78W4ft2Ov2NCJLilFOrRrw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
