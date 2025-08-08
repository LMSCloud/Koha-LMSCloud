use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "CHANGEME",
    description => 'Add OPAC preferences to override default booking pickup library',
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $added = 0;

        eval {
            $dbh->do(q{
                INSERT IGNORE INTO systempreferences
                    (variable, value, options, explanation, type)
                VALUES
                    ('OPACBookingDefaultLibraryEnabled', '0', NULL,
                     'Enable overriding OPAC default booking pickup library with a fixed branch', 'YesNo')
            });
            $added++;
            1;
        } or do { say_failure( $out, "Failed adding 'OPACBookingDefaultLibraryEnabled'" ) };

        eval {
            $dbh->do(q{
                INSERT IGNORE INTO systempreferences
                    (variable, value, options, explanation, type)
                VALUES
                    ('OPACBookingDefaultLibrary', '', NULL,
                     'Branchcode to use as default booking pickup library in OPAC when override is enabled', 'Free')
            });
            $added++;
            1;
        } or do { say_failure( $out, "Failed adding 'OPACBookingDefaultLibrary'" ) };

        if ($added) {
            say_success( $out, "Added OPACBookingDefaultLibrary[Enabled] system preferences" );
        } else {
            say_info( $out, "OPAC default booking library preferences already present" );
        }
    },
};


