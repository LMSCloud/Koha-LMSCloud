use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "CHANGEME",
    description => "Add BookingConstraintMode system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('BookingConstraintMode', 'range', 'range|end_date_only', 'Controls booking date constraint behavior. When set to end_date_only, patrons can only book the calculated start date or end date, with intermediate dates blocked.', 'Choice')}
        );

        say_success(
            $out,
            "Added new system preference 'BookingConstraintMode'"
        );
    },
};