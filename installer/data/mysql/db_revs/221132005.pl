use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "BibTip-V5",
    description => "Add BibtipApiKey system preference for BibTip recommender V5 token generation",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES ('BibtipApiKey', '', NULL, 'API key used to authenticate against the Bibtip recommender service. Used server-side to generate the X-API-Token sent by the OPAC.', 'Free')
        });

        say_success( $out, "Added new system preference 'BibtipApiKey'" );
    },
};
