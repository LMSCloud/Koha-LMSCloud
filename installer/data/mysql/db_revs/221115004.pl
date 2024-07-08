use Modern::Perl;

return {
    bug_number => "LMSCLoud: Language initialization",
    description => "Initialize the patron language to de-DE.",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        $dbh->do(qq{
            INSERT IGNORE INTO systempreferences( `variable`, `value`, `options`, `explanation`, `type` )
            VALUES
              ('DefaultPatronLanguage', 'de-DE', NULL, 'Create new patrons with the given language setting. The value will also be use if parameter TranslateNotices is not activated in order to get translated content of notices correctly.', 'Free')
        });
        
        $dbh->do(qq{
            UPDATE borrowers SET lang = 'de-DE'
        });
        
        say $out "LMSCloud update: set borrowers language to de-DE. Add system preference DefaultPatronLanguage with value de-DE.";
    },
};
