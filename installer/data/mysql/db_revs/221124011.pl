use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "CHANGEME",
    description => "Adds new system preference 'OPACBookings'",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('OPACBookings', '0', NULL, 'If ON, enables patrons to place and manage their bookings on the OPAC', 'YesNo')}
        );

        say_success( $out, "Added new system preference 'OPACBookings'" );
    },
};
