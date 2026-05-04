use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-browser-lms-columns",
    description => "Restore LMS extensions on browser table (parent/prefix/classval/startrange/endrange/exclude/usesearch + 4 indexes + classification width)",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my @cols = (
            [ 'parent',     q{varchar(1024)}, 'endnode' ],
            [ 'prefix',     q{varchar(40)},   'parent' ],
            [ 'classval',   q{varchar(40)},   'prefix' ],
            [ 'startrange', q{varchar(20)},   'classval' ],
            [ 'endrange',   q{varchar(20)},   'startrange' ],
            [ 'exclude',    q{mediumtext},    'endrange' ],
            [ 'usesearch',  q{mediumtext},    'exclude' ],
        );

        for my $c (@cols) {
            my ( $name, $spec, $after ) = @$c;
            if ( column_exists( 'browser', $name ) ) {
                say_info( $out, "browser.$name already exists, skipping" );
                next;
            }
            $dbh->do(qq{ALTER TABLE browser ADD COLUMN `$name` $spec AFTER `$after`});
            say_success( $out, "Added browser.$name" );
        }

        my $current_class = $dbh->selectrow_array(
            q{SELECT COLUMN_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'browser' AND COLUMN_NAME = 'classification'}
        );
        if ( $current_class && $current_class !~ /^varchar\(255\)/i ) {
            $dbh->do(q{ALTER TABLE browser MODIFY `classification` varchar(255) NOT NULL});
            say_success( $out, "Widened browser.classification to varchar(255)" );
        }

        my @keys = (
            [ 'browser_by_description',    'description' ],
            [ 'browser_by_level',          'level' ],
            [ 'browser_by_classification', 'classification' ],
            [ 'browser_by_parent',         'parent' ],
        );

        for my $k (@keys) {
            my ( $kname, $kcol ) = @$k;
            if ( index_exists( 'browser', $kname ) ) {
                say_info( $out, "Index browser.$kname already exists, skipping" );
                next;
            }
            $dbh->do(qq{ALTER TABLE browser ADD KEY `$kname` (`$kcol`)});
            say_success( $out, "Added index browser.$kname" );
        }
    },
};
