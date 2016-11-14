use utf8;
package Koha::Schema::Result::ClaimingRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ClaimingRule

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<claiming_rules>

=cut

__PACKAGE__->table("claiming_rules");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 categorycode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 itemtype

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 branchcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 claim_fee_level1

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 claim_fee_level2

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 claim_fee_level3

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 claim_fee_level4

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 claim_fee_level5

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "categorycode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "itemtype",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "branchcode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "claim_fee_level1",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "claim_fee_level2",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "claim_fee_level3",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "claim_fee_level4",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "claim_fee_level5",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
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

=item * L</categorycode>

=item * L</itemtype>

=item * L</branchcode>

=back

=cut

__PACKAGE__->add_unique_constraint("pseudo_key", ["categorycode", "itemtype", "branchcode"]);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2016-11-10 12:51:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:e7uojV5yqFkeOO1xlAPSeA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
