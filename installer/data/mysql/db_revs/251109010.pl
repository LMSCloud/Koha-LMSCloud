use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "",
    description => "Load the checkouts table immediately by default",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Bug 14180 replaced the per-user "Always show checkouts immediately"
        # checkbox with AlwaysLoadCheckoutsTable, which community defaults to off.
        $dbh->do(
            q{UPDATE systempreferences SET value = '1' WHERE variable = 'AlwaysLoadCheckoutsTable' AND value <> '1'});
        say_success( $out, "Set AlwaysLoadCheckoutsTable to load the checkouts table immediately" );
    },
};
