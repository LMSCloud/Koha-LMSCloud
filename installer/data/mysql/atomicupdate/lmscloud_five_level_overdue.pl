use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "LMSCLOUD-five-level-overdue",
    description => "Restore overduerules columns delay4/5, letter4/5, debarred4/5 (LMS 5-level dunning)",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my @cols = (
            [
                'delay4',
                q{int(4) DEFAULT NULL COMMENT 'number of days after the item is overdue that the fourth notice is sent'},
                'debarred3'
            ],
            [
                'letter4',
                q{varchar(20) DEFAULT NULL COMMENT 'foreign key from the letter table to define which notice should be sent as the fourth notice'},
                'delay4'
            ],
            [
                'debarred4',
                q{int(1) DEFAULT 0 COMMENT 'is the patron restricted when the fourth notice is sent (1 for yes, 0 for no)'},
                'letter4'
            ],
            [
                'delay5',
                q{int(4) DEFAULT NULL COMMENT 'number of days after the item is overdue that the fifth notice is sent'},
                'debarred4'
            ],
            [
                'letter5',
                q{varchar(20) DEFAULT NULL COMMENT 'foreign key from the letter table to define which notice should be sent as the fifth notice'},
                'delay5'
            ],
            [
                'debarred5',
                q{int(1) DEFAULT 0 COMMENT 'is the patron restricted when the fifth notice is sent (1 for yes, 0 for no)'},
                'letter5'
            ],
        );

        for my $c (@cols) {
            my ( $name, $spec, $after ) = @$c;
            if ( column_exists( 'overduerules', $name ) ) {
                say_info( $out, "overduerules.$name already exists, skipping" );
                next;
            }
            $dbh->do(qq{ALTER TABLE overduerules ADD COLUMN `$name` $spec AFTER `$after`});
            say_success( $out, "Added overduerules.$name" );
        }
    },
};
