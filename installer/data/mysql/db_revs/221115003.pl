use Modern::Perl;

return {
    bug_number => "Karlsruhe",
    description => "Extend field exclude of table browser and add field usesearch.",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        if( column_exists( 'browser', 'exclude' ) && !column_exists( 'browser', 'usesearch' ) ) {
            $dbh->do(q{ ALTER TABLE `browser` MODIFY `exclude` mediumtext, ADD `usesearch` mediumtext AFTER `exclude`  });
            say $out "Updated browser table: field exclude extended, field usesearch added.";
        }
    },
};
