use utf8;
package Koha::Schema::Result::OldIllrequest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OldIllrequest

=head1 DESCRIPTION

stores ILL requests that have been completed and after a delay deleted from table illrequests for performance reasons

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

ILL request number

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Patron associated with request

=head2 biblio_id

  data_type: 'integer'
  is_nullable: 1

Potential bib linked to request

=head2 branchcode

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 50

The branch associated with the request

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 50

Current Koha status of request

=head2 status_alias

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 80

Foreign key to relevant authorised_values.authorised_value

=head2 placed

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

Date the request was placed

=head2 replied

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

Last API response

=head2 updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

Last modification to request

=head2 completed

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

Date the request was completed

=head2 medium

  data_type: 'varchar'
  is_nullable: 1
  size: 30

The Koha request type

=head2 accessurl

  data_type: 'varchar'
  is_nullable: 1
  size: 500

Potential URL for accessing item

=head2 cost

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Quotes cost of request

=head2 price_paid

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Final cost of request

=head2 notesopac

  data_type: 'mediumtext'
  is_nullable: 1

Patron notes attached to request

=head2 notesstaff

  data_type: 'mediumtext'
  is_nullable: 1

Staff notes attached to request

=head2 orderid

  data_type: 'varchar'
  is_nullable: 1
  size: 50

Backend id attached to request

=head2 backend

  data_type: 'varchar'
  is_nullable: 1
  size: 20

The backend used to create request

=cut

__PACKAGE__->add_columns(
  "illrequest_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "biblio_id",
  { data_type => "integer", is_nullable => 1 },
  "branchcode",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 50 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "status_alias",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 80 },
  "placed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "replied",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "updated",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
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

=head2 old_illcomments

Type: has_many

Related object: L<Koha::Schema::Result::OldIllcomment>

=cut

__PACKAGE__->has_many(
  "old_illcomments",
  "Koha::Schema::Result::OldIllcomment",
  { "foreign.illrequest_id" => "self.illrequest_id" },
  { cascade_copy => 0, cascade_delete => 0 },
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

=head2 status_alias

Type: belongs_to

Related object: L<Koha::Schema::Result::AuthorisedValue>

=cut

__PACKAGE__->belongs_to(
  "status_alias",
  "Koha::Schema::Result::AuthorisedValue",
  { authorised_value => "status_alias" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "SET NULL",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:19Vvq7OAoLm6aMRqHgit0A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
