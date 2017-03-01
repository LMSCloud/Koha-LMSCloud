use utf8;
package Koha::Schema::Result::OverdueIssue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OverdueIssue

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<overdue_issues>

=cut

__PACKAGE__->table("overdue_issues");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 issue_id

  data_type: 'integer'
  is_nullable: 0

=head2 claim_level

  data_type: 'integer'
  is_nullable: 0

=head2 claim_time

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "issue_id",
  { data_type => "integer", is_nullable => 0 },
  "claim_level",
  { data_type => "integer", is_nullable => 0 },
  "claim_time",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2017-01-07 13:43:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Mrm8RbdRXceEqWcT7uHigA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
