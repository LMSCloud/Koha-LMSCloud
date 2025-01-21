use Modern::Perl;

return {
    bug_number => "LMSCLoud: Onleihe version.",
    description => "Set the Divibib Onleihe version.",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        $dbh->do(qq{
            INSERT IGNORE INTO systempreferences( `variable`, `value`, `options`, `explanation`, `type` )
            VALUES
              ('DivibibVersion', '2', NULL, 'Divibib Onleihe version the library is integrating with.', 'Free')
        });
        
        say $out "Add system preference DivibibVersion with value 2.";
    },
};
