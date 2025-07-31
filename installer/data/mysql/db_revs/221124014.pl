use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "",
    description => "Adds new system preference PaymentsPatronCategories to enable the payment function in OPAC based on patron category.",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('PaymentsPatronCategories', '', NULL, 'If set, the parameter enables only the listed patron categories (separated by |) to do online payments in OPAC.', 'free')}
        );

        say_success(
            $out,
            "Added new system preference 'PaymentsPatronCategories'."
        );
    },
};
