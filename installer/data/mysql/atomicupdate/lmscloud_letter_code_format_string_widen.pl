use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-letter-code-format-string-widen",
    description => "Widen letter.code (20->50) and creator_layouts.format_string (210->1024) to match LMS-extended schema",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $letter_code = $dbh->selectrow_array(
            q{SELECT COLUMN_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'letter' AND COLUMN_NAME = 'code'}
        );
        if ( $letter_code && $letter_code !~ /^varchar\(50\)/i ) {
            $dbh->do(q{ALTER TABLE letter MODIFY `code` varchar(50) NOT NULL DEFAULT '' COMMENT 'unique identifier for this notice or slip'});
            say_success( $out, "Widened letter.code to varchar(50)" );
        }
        else {
            say_info( $out, "letter.code already varchar(50) (or table missing), skipping" );
        }

        my $fmt = $dbh->selectrow_array(
            q{SELECT COLUMN_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'creator_layouts' AND COLUMN_NAME = 'format_string'}
        );
        if ( $fmt && $fmt !~ /^varchar\(1024\)/i ) {
            $dbh->do(q{ALTER TABLE creator_layouts MODIFY `format_string` varchar(1024) NOT NULL DEFAULT 'barcode'});
            say_success( $out, "Widened creator_layouts.format_string to varchar(1024)" );
        }
        else {
            say_info( $out, "creator_layouts.format_string already varchar(1024), skipping" );
        }
    },
};
