use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-holdfeemode-issued-or-reserved",
    description => "Add the issued_or_reserved choice to the HoldFeeMode system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $options = 'any_time_is_placed|not_always|issued_or_reserved|any_time_is_collected';

        my ($current) = $dbh->selectrow_array(q{SELECT options FROM systempreferences WHERE variable = 'HoldFeeMode'});

        if ( !defined $current ) {
            say_info( $out, "HoldFeeMode is not present, nothing to extend" );
            return;
        }

        if ( $current eq $options ) {
            say_info( $out, "HoldFeeMode already offers issued_or_reserved, skipping" );
            return;
        }

        $dbh->do( q{UPDATE systempreferences SET options = ? WHERE variable = 'HoldFeeMode'}, undef, $options );
        say_success( $out, "HoldFeeMode now offers the issued_or_reserved choice" );
    },
};
