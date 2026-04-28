use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-letter-code-fk-widen",
    description => "Widen letter_code FK columns (20->50) to match LMS-extended letter.code(50)",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $mt_letter_code = $dbh->selectrow_array(
            q{SELECT COLUMN_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'message_transports' AND COLUMN_NAME = 'letter_code'}
        );
        if ( $mt_letter_code && $mt_letter_code !~ /^varchar\(50\)/i ) {
            $dbh->do(
                q{ALTER TABLE message_transports MODIFY `letter_code` varchar(50) NOT NULL DEFAULT ''}
            );
            say_success( $out, "Widened message_transports.letter_code to varchar(50)" );
        } else {
            say_info( $out, "message_transports.letter_code already varchar(50) (or table missing), skipping" );
        }

        my $pp_letter_code = $dbh->selectrow_array(
            q{SELECT COLUMN_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'preservation_processings' AND COLUMN_NAME = 'letter_code'}
        );
        if ( $pp_letter_code && $pp_letter_code !~ /^varchar\(50\)/i ) {
            $dbh->do(
                q{ALTER TABLE preservation_processings MODIFY `letter_code` varchar(50) DEFAULT NULL COMMENT 'Foreign key to the letters table'}
            );
            say_success( $out, "Widened preservation_processings.letter_code to varchar(50)" );
        } else {
            say_info( $out, "preservation_processings.letter_code already varchar(50) (or table missing), skipping" );
        }
    },
};
