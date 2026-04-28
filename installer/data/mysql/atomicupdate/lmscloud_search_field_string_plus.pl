use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-search-field-string-plus",
    description => "Restore string_plus to search_field.type enum (LMS DidYouMean trigram fields)",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $current = $dbh->selectrow_array(
            q{SELECT COLUMN_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'search_field' AND COLUMN_NAME = 'type'}
        );

        if ( $current && $current =~ /'string_plus'/ ) {
            say_info( $out, "search_field.type already has string_plus, skipping" );
            return;
        }

        $dbh->do(
            q{ALTER TABLE search_field MODIFY COLUMN `type`
              enum('','string','date','number','boolean','sum','isbn','stdno','year','callnumber','geo_point','string_plus','availability')
              NOT NULL COMMENT 'what type of data this holds, relevant when storing it in the search engine'}
        );
        say_success( $out, "search_field.type extended with string_plus" );
    },
};
