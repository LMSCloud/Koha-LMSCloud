use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "",
    description => "Add system preference SepaDirectDebitPainFormat to choose the pain.008 format of SEPA direct debit files",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # INSERT IGNORE keeps the value of an already existing preference
        # (for example one that has been created manually before this update).
        my $inserted = $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` )
            VALUES (
                'SepaDirectDebitPainFormat',
                'pain.008.001.08',
                'pain.008.001.02|pain.008.001.08',
                'Format version of the XML file containing the SEPA direct debits. pain.008.001.08 (DK version 3.7 and later) is required by many banks from november 2026.',
                'Choice'
            )
        }
        );
        if ( $inserted && $inserted > 0 ) {
            say_success( $out, "Added new system preference 'SepaDirectDebitPainFormat'" );
            say_info(
                $out,
                "SepaDirectDebitPainFormat is set to pain.008.001.08. Switch to pain.008.001.02 if your bank still requires DK version 3.6 or older."
            );
        } else {
            say_warning( $out, "System preference 'SepaDirectDebitPainFormat' already exists" );
        }
    },
};