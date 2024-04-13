use Modern::Perl;

return {
    bug_number => "KOHA2211-67",
    description => "Set categorycode values of statistics table by borrowers and deletedborrowers categorycode",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        if( column_exists( 'statistics', 'categorycode' ) ) {
            my $res = $dbh->do(q{
                UPDATE statistics 
                JOIN   borrowers ON (statistics.borrowernumber = borrowers.borrowernumber)
                SET    statistics.categorycode = borrowers.categorycode
                WHERE  statistics.type IN ('recall','localuse','onsite_checkout','issue','return','renew')
            });
            $res += $dbh->do(q{
                UPDATE statistics 
                JOIN   deletedborrowers ON (statistics.borrowernumber = deletedborrowers.borrowernumber)
                SET    statistics.categorycode = deletedborrowers.categorycode
                WHERE  statistics.type IN ('recall','localuse','onsite_checkout','issue','return','renew')
            });
            $res += 0;
            say $out "Added statistics.categorycode values to $res rows of the statistics table.";
        }
    },
};
