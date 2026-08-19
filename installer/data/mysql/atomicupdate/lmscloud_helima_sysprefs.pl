use Modern::Perl;
use Koha::Installer::Output qw(say_success say_info);

return {
    bug_number  => "LMSCLOUD-helima-sysprefs",
    description => "Add the HeLiMa license manager search system preferences",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my @prefs = (
            [
                'HelimaAdditionalOfferName', 'eBibliotheken Hessen', undef,
                'Name of the Licensor/Provider of the HeLiMa service.', 'Free'
            ],
            [ 'HelimaCustomerID', '',        undef, 'The customer ID when using the HeLiMa service.', 'Free' ],
            [ 'HelimaLicensor',   'hessian', undef, 'Licensor/provider of the HeLiMa service.',       'Free' ],
            [
                'HelimaNumSearchResults', '20', undef,
                'Maximum number of results per page displayed in the OPAC.', 'Integer'
            ],
            [ 'HelimaSearchActive', '0', undef, 'Activate the HeLiMa license manager search in OPAC.', 'YesNo' ],
            [
                'HeLiMaSearchCollections', '', undef,
                'Limit the HeLiMa search result to the following list of collections. Separate HeLiMa collection names by |. This parameter is optional.',
                'Free'
            ],
        );

        my $added = 0;
        for my $pref (@prefs) {
            $added += $dbh->do(
                q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`)
                  VALUES (?, ?, ?, ?, ?)}, undef, @$pref
            );
        }

        if ($added) {
            say_success( $out, "Added $added HeLiMa system preference(s)" );
        } else {
            say_info( $out, "HeLiMa system preferences already present, skipping" );
        }
    },
};
