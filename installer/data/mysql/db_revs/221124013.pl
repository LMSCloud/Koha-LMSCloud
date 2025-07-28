use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "CHANGEME",
    description => "Adds new system preferences for booking date range constraints",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('BookingDateRangeConstraint', '', 'issuelength|issuelength_with_renewals', 'Constrains booking date ranges based on circulation rules. If set, users can only book for the specified period based on circulation rules.', 'Choice')}
        );

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('OPACBookingDateRangeConstraint', '', 'issuelength|issuelength_with_renewals', 'Constrains booking date ranges in OPAC based on circulation rules. If set, patrons can only book for the specified period based on circulation rules.', 'Choice')}
        );

        say_success(
            $out,
            "Added new system preferences 'BookingDateRangeConstraint' and 'OPACBookingDateRangeConstraint'"
        );
    },
};
