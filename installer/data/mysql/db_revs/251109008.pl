use Modern::Perl;
use utf8;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "",
    description => "Translate the return claim resolutions to German on upgraded databases",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # The community update inserted these values in English only. Values whose
        # text still matches that English get the community German from the de-DE
        # installer; renamed values are left alone.
        my @values = (
            [ 'RET_BY_PATRON', 'Returned by patron', 'Vom Benutzer zurückgegeben' ],
            [ 'FOUND_IN_LIB',  'Found in library',   'In der Bibliothek gefunden' ],
        );

        my $updated = 0;
        for my $value (@values) {
            my ( $code, $en, $de ) = @$value;
            for my $column (qw(lib lib_opac)) {
                $updated += $dbh->do(
                    qq{UPDATE authorised_values SET $column = ?
                       WHERE category = 'RETURN_CLAIM_RESOLUTION' AND authorised_value = ? AND $column = ?},
                    undef, $de, $code, $en
                );
            }
        }
        say_success( $out, "Translated $updated return claim resolution description(s) to German" );
    },
};
