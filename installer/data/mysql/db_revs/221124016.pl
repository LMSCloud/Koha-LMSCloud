use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "CHANGME",
    description => "Add OPACBookingConstraintMode system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('OPACBookingConstraintMode', 'range', 'range|end_date_only', 'Controls booking date constraint behavior in the OPAC. When set to end_date_only, patrons can only book the calculated start date or end date, with intermediate dates blocked.', 'Choice')}
        ) or say_failure( $out, "Failed to insert OPACBookingConstraintMode system preference" );

        say_success( $out, "Added OPACBookingConstraintMode system preference" );
    },
};
