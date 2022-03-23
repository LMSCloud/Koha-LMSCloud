use utf8;
package Koha::Schema::Result::OldIllrequest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OldIllrequest

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<old_illrequests>

=cut

__PACKAGE__->table("old_illrequests");

=head1 ACCESSORS

=head2 illrequest_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 biblio_id

  data_type: 'integer'
  is_nullable: 1

=head2 branchcode

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 status_alias

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 placed

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 replied

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=head2 completed

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 medium

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 accessurl

  data_type: 'varchar'
  is_nullable: 1
  size: 500

=head2 cost

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 price_paid

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 notesopac

  data_type: 'mediumtext'
  is_nullable: 1

=head2 notesstaff

  data_type: 'mediumtext'
  is_nullable: 1

=head2 orderid

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 backend

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=cut

__PACKAGE__->add_columns(
  "illrequest_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "biblio_id",
  { data_type => "integer", is_nullable => 1 },
  "branchcode",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "status_alias",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "placed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "replied",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "updated",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 1,
  },
  "completed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "medium",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "accessurl",
  { data_type => "varchar", is_nullable => 1, size => 500 },
  "cost",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "price_paid",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "notesopac",
  { data_type => "mediumtext", is_nullable => 1 },
  "notesstaff",
  { data_type => "mediumtext", is_nullable => 1 },
  "orderid",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "backend",
  { data_type => "varchar", is_nullable => 1, size => 20 },
);

=head1 PRIMARY KEY

=over 4

=item * L</illrequest_id>

=back

=cut

__PACKAGE__->set_primary_key("illrequest_id");

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "SET NULL",
  },
);

=head2 branchcode

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "branchcode",
  "Koha::Schema::Result::Branch",
  { branchcode => "branchcode" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "SET NULL",
  },
);

=head2 old_illrequestattributes

Type: has_many

Related object: L<Koha::Schema::Result::OldIllrequestattribute>

=cut

__PACKAGE__->has_many(
  "old_illrequestattributes",
  "Koha::Schema::Result::OldIllrequestattribute",
  { "foreign.illrequest_id" => "self.illrequest_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-22 13:03:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3CW1x80iOnKSCW7k/g66/A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
