use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success say_warning);

return {
    bug_number  => "LMSCLOUD-collections-tracking-itemnumber-fk",
    description => "Restore LMS FK collections_tracking.itemnumber -> items.itemnumber (referential integrity)",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $exists = $dbh->selectrow_array(
            q{SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
              WHERE CONSTRAINT_SCHEMA = DATABASE()
                AND TABLE_NAME = 'collections_tracking'
                AND CONSTRAINT_NAME = 'collectionst_ibfk_2'}
        );
        if ($exists) {
            say_info( $out, "FK collectionst_ibfk_2 already exists, skipping" );
            return;
        }

        my $orphans = $dbh->selectrow_array(
            q{SELECT COUNT(*) FROM collections_tracking ct
              LEFT JOIN items i ON ct.itemnumber = i.itemnumber
              WHERE i.itemnumber IS NULL}
        );
        if ($orphans) {
            say_warning(
                $out,
                "collections_tracking has $orphans orphaned itemnumber rows; cannot add FK. Clean up before re-running."
            );
            return;
        }

        $dbh->do(
            q{ALTER TABLE collections_tracking
              ADD CONSTRAINT collectionst_ibfk_2 FOREIGN KEY (itemnumber)
              REFERENCES items (itemnumber) ON DELETE CASCADE ON UPDATE CASCADE}
        );
        say_success( $out, "Added FK collections_tracking.collectionst_ibfk_2" );
    },
};
