use Modern::Perl;
use utf8;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "",
    description => "Translate the community patron restriction types to German on upgraded databases",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # The community db_revs insert these types in English only. Rows whose
        # text still matches that English get the community German from the de-DE
        # installer; renamed types are left alone.
        my @types = (
            [ 'MANUAL',     'Manual restriction', 'Manuelle Sperre' ],
            [ 'OVERDUES',   'Overdues',           'Überfälligkeiten' ],
            [ 'SUSPENSION', 'Suspension',         'Suspendierung' ],
            [ 'DISCHARGE',  'Discharge',          'Entlastung' ],
            [
                'NOTICE_FAILURE_SUSPENSION', 'Notice failure suspension',
                'Sperre wegen fehlgeschlagener Benachrichtigung'
            ],
            [ 'FINES', 'Fines suspension', 'Gebührensuspendierung' ],
        );

        my $updated = 0;
        for my $type (@types) {
            my ( $code, $en, $de ) = @$type;
            $updated += $dbh->do(
                q{UPDATE restriction_types SET display_text = ? WHERE code = ? AND display_text = ?},
                undef, $de, $code, $en
            );
        }
        say_success( $out, "Translated $updated patron restriction type(s) to German" );
    },
};
