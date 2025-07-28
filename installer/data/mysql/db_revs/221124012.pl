use Modern::Perl;

return {
    bug_number => "",
    description => "Add missing German (de) language translation",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{ INSERT IGNORE INTO language_descriptions (subtag, type, lang, description) VALUES ( 'la', 'language', 'de', 'Latein') });


        # Print useful stuff here
        say $out "German (de) language translation added";
    },
};
