use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "",
    description => "Add system preference MARC21FixedLengthWarning, off by default",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $added = $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
                VALUES ('MARC21FixedLengthWarning', '0', NULL,
                    'Warn in the cataloging editor about MARC21 fixed-length control fields with an invalid length', 'YesNo')
            }
        );
        if ( $added > 0 ) {
            say_success( $out, "Added system preference 'MARC21FixedLengthWarning'" );
        } else {
            say_info( $out, "System preference 'MARC21FixedLengthWarning' already exists" );
        }
    },
};
