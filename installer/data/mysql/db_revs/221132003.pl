use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);
return {
    bug_number  => "32142",
    description => "Add issued_or_reserved option to HoldFeeMode system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};
        $dbh->do(
            q{ UPDATE systempreferences SET options = 'any_time_is_placed|not_always|issued_or_reserved|any_time_is_collected' where variable = 'HoldFeeMode' }
        );
        say_success( $out, "Added issued_or_reserved option to HoldFeeMode system preference." );
    },
};
