use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "",
    description => "Add the EKZ_STORNO reason to the HOLD_CANCELLATION authorised value category",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Koha::Hold::cancellation_reason_str resolves the reason through this
        # category; without the row staff see the raw code.
        my $added = $dbh->do(
            q{INSERT IGNORE INTO authorised_values (category, authorised_value, lib)
              VALUES ('HOLD_CANCELLATION', 'EKZ_STORNO', ?)},
            undef, 'Titel nicht lieferbar (ekz-Storno)'
        );

        # DBI returns the truthy string "0E0" for zero affected rows, so compare numerically
        if ( $added > 0 ) {
            say_success( $out, "Added the EKZ_STORNO hold cancellation reason" );
        } else {
            say_info( $out, "EKZ_STORNO hold cancellation reason already present, skipping" );
        }
    },
};
