use utf8;
package Koha::Schema::Result::AqorderUser;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AqorderUser

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aqorder_users>

=cut

__PACKAGE__->table("aqorder_users");

=head1 ACCESSORS

=head2 ordernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

the order this patrons receive notifications from (aqorders.ordernumber)

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

the borrowernumber for the patron receiving notifications for this order (borrowers.borrowernumber)

=cut

__PACKAGE__->add_columns(
  "ordernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</ordernumber>

=item * L</borrowernumber>

=back

=cut

__PACKAGE__->set_primary_key("ordernumber", "borrowernumber");

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 ordernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqorder>

=cut

__PACKAGE__->belongs_to(
  "ordernumber",
  "Koha::Schema::Result::Aqorder",
  { ordernumber => "ordernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-01-21 13:39:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:G5LCF3HRXk7YKl8/t7HIyg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
