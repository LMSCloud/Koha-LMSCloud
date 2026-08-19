use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-ekz-keep-title-data-on-cancellation",
    description => "Add the ekzKeepTitleDataOnAutomaticCancellation system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $added = $dbh->do(
            q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`)
              VALUES ('ekzKeepTitleDataOnAutomaticCancellation', '0', NULL, ?, 'YesNo')},
            undef,
            'If enabled, bibliographic title records are NOT deleted when EKZ standing order items are automatically cancelled (Storno status 85). Default: disabled (title data is deleted on cancellation).'
        );

        # DBI returns the truthy string "0E0" for zero affected rows, so compare numerically
        if ( $added > 0 ) {
            say_success( $out, "Added system preference ekzKeepTitleDataOnAutomaticCancellation (default: 0)" );
        } else {
            say_info( $out, "ekzKeepTitleDataOnAutomaticCancellation already present, skipping" );
        }
    },
};
