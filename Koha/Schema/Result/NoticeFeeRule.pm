use utf8;
package Koha::Schema::Result::NoticeFeeRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::NoticeFeeRule

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<notice_fee_rules>

=cut

__PACKAGE__->table("notice_fee_rules");

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

=head2 branchcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

the branch this rule applies to (branches.branchcode)

=head2 message_transport_type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

message channel this rule is for (message_transport_type.message_transport_types)

=head2 letter_code

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 50

optional letter code thise rule is for (letter.code)

=head2 notice_fee

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

fine amount for notififcations

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "categorycode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "branchcode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "message_transport_type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "letter_code",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
  "notice_fee",
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

=item * L</branchcode>

=item * L</categorycode>

=item * L</message_transport_type>

=item * L</letter_code>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "pseudo_key",
  [
    "branchcode",
    "categorycode",
    "message_transport_type",
    "letter_code",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-09-11 13:46:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8XnpEPLRJPEXHvdEDf+iLQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
