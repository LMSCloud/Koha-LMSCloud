use utf8;
package Koha::Schema::Result::OldIllcomment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OldIllcomment

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<old_illcomments>

=cut

__PACKAGE__->table("old_illcomments");

=head1 ACCESSORS

=head2 illcomment_id

  data_type: 'integer'
  is_nullable: 0

=head2 illrequest_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "illcomment_id",
  { data_type => "integer", is_nullable => 0 },
  "illrequest_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</illcomment_id>

=back

=cut

__PACKAGE__->set_primary_key("illcomment_id");

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

=head2 illrequest

Type: belongs_to

Related object: L<Koha::Schema::Result::OldIllrequest>

=cut

__PACKAGE__->belongs_to(
  "illrequest",
  "Koha::Schema::Result::OldIllrequest",
  { illrequest_id => "illrequest_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-23 15:33:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3SlX0sV08A9n4dgzmmH6uA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
