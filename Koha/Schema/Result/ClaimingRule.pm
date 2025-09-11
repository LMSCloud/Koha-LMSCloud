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

ID of the configuration line

=head2 categorycode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

patron category this rule is for (categories.categorycode)

=head2 itemtype

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

item type this rule is for (itemtypes.itemtype)

=head2 branchcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

the branch this rule applies to (branches.branchcode)

=head2 claim_fee_level1

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

fine amount for reaching 1st claim

=head2 claim_fee_level2

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

fine amount for reaching 2nd claim

=head2 claim_fee_level3

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

fine amount for reaching 3nd claim

=head2 claim_fee_level4

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

fine amount for reaching 4nd claim

=head2 claim_fee_level5

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

fine amount for reaching 5nd claim

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zGFRuaLtz2k2Auj1UnPHnw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
