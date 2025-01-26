use Modern::Perl;

return {
    bug_number => "LMSCLoud: Notice Fee Update.",
    description => "Discard notice fees for holds if the home branch is listed with parameter DiscardHoldsNoticeFeeOfHomeLibraries: needed for stack material ordering free of charge.",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        $dbh->do(qq{
            INSERT IGNORE INTO systempreferences( `variable`, `value`, `options`, `explanation`, `type` )
            VALUES
              ('DiscardHoldsNoticeFeeOfHomeLibraries','',NULL,'Discard a notice fee for holds if the home branch of the item is one of the specified codes (seperated by |).','Free')
        });
        
        say $out "Add system preference DiscardHoldsNoticeFeeOfHomeLibraries with empty value.";
    },
};
