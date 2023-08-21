package C4::Members::Statistics;

# Copyright 2012 BibLibre
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 NAME

C4::Members::Statistics - Get statistics for patron checkouts

=cut

use Modern::Perl;

use C4::Context;

our ( @ISA, @EXPORT_OK );

BEGIN {
    require Exporter;
    @ISA = qw(Exporter);

    @EXPORT_OK = qw(
        get_fields
        GetTotalIssuesTodayByBorrower
        GetTotalIssuesReturnedTodayByBorrower
        GetPrecedentStateByBorrower
    );
}

=head2 get_fields
  Get fields form syspref 'StatisticsFields'
  Returns list of valid fields, defaults to 'location|itype|ccode'
  if syspref is empty or does not contain valid fields

=cut

sub get_fields {

    my $syspref = C4::Context->preference('StatisticsFields');
    my $ret;

    if ( $syspref ) {
        my @ret;
        my @spfields = split ('\|', $syspref);
        my $schema       = Koha::Database->new()->schema();
        my @columns = $schema->source('Item')->columns;

        foreach my $fn ( @spfields ) {
            push ( @ret, $fn ) if ( grep { $_ eq $fn } @columns );
        }
        $ret = join( '|', @ret);
    }
    return $ret || 'location|itype|ccode';
}

=head2 construct_query
  Build a sql query from a subquery
  Adds statistics fields to the select and the group by clause

=cut

sub construct_query {
    my $count    = shift;
    my $subquery = shift;
    my $fields = get_fields();
    my @select_fields = split '\|', $fields;
    my $query = "SELECT COUNT(*) as count_$count,";
    $query .= join ',', @select_fields;

    $query .= " " . $subquery;

    $fields =~ s/\|/,/g;
    $query .= " GROUP BY $fields;";

    return $query;

}

=head2 GetTotalIssuesTodayByBorrower
  Return total issues for a borrower at this current day

=cut

sub GetTotalIssuesTodayByBorrower {
    my ($borrowernumber) = @_;
    my $dbh   = C4::Context->dbh;

    my $query = construct_query "total_issues_today",
        "FROM (
            SELECT it.* FROM issues i, items it WHERE i.itemnumber = it.itemnumber AND i.borrowernumber = ? AND DATE(i.issuedate) = CAST(now() AS date)
            UNION
            SELECT it.* FROM old_issues oi, items it WHERE oi.itemnumber = it.itemnumber AND oi.borrowernumber = ? AND DATE(oi.issuedate) = CAST(now() AS date)
        ) tmp";     # alias is required by MySQL

    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber, $borrowernumber);
    return $sth->fetchall_arrayref( {} );
}

=head2 GetTotalIssuesReturnedTodayByBorrower
  Return total issues returned by a borrower at this current day

=cut

sub GetTotalIssuesReturnedTodayByBorrower {
    my ($borrowernumber) = @_;
    my $dbh   = C4::Context->dbh;

    my $query = construct_query "total_issues_returned_today", "FROM old_issues i, items it WHERE i.itemnumber = it.itemnumber AND i.borrowernumber = ? AND DATE(i.returndate) = CAST(now() AS date) ";

    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    return $sth->fetchall_arrayref( {} );
}

=head2 GetPrecedentStateByBorrower
  Return the precedent state (before today) for a borrower of his checkins and checkouts

=cut

sub GetPrecedentStateByBorrower {
    my ($borrowernumber) = @_;
    my $dbh   = C4::Context->dbh;

    my $query = construct_query "precedent_state",
        "FROM (
            SELECT it.* FROM issues i, items it WHERE i.borrowernumber = ? AND i.itemnumber = it.itemnumber AND DATE(i.issuedate) < CAST(now() AS date)
            UNION
            SELECT it.* FROM old_issues oi, items it WHERE oi.borrowernumber = ? AND oi.itemnumber = it.itemnumber AND DATE(oi.issuedate) < CAST(now() AS date) AND DATE(oi.returndate) = CAST(now() AS date)
        ) tmp";     # alias is required by MySQL

    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber, $borrowernumber);
    return $sth->fetchall_arrayref( {});
}

1;
