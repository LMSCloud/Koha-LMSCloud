use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "",
    description => "Add ekzKeepTitleDataOnAutomaticCancellation system preference",
    up => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add system preference to control whether bibliographic/title data is deleted
        # when EKZ standing order items are automatically cancelled via Storno (status 85).
        # Default 0: title data is deleted (previous behaviour).
        # Value  1: title data is kept (biblio record remains in catalogue).
        $dbh->do(q{
            INSERT IGNORE INTO `systempreferences`
                (`variable`, `value`, `options`, `explanation`, `type`)
            VALUES (
                'ekzKeepTitleDataOnAutomaticCancellation',
                '0',
                NULL,
                'If enabled, bibliographic title records are NOT deleted when EKZ standing order items are automatically cancelled (Storno status 85). Default: disabled (title data is deleted on cancellation).',
                'YesNo'
            )
        });

        say_success( $out, "Added system preference KeepTitleDataOnAutomaticCancellation (default: 0)" );
    },
};