use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "LMSCLOUD-claim-level-seeds",
    description => "Backfill CLAIM_LEVEL1..5 + NOTIFICATION account_debit_types and letter templates on existing DBs",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my @debit_types = (
            [ 'CLAIM_LEVEL1', 'Overdue fine (level 1)' ],
            [ 'CLAIM_LEVEL2', 'Overdue fine (level 2)' ],
            [ 'CLAIM_LEVEL3', 'Overdue fine (level 3)' ],
            [ 'CLAIM_LEVEL4', 'Overdue fine (level 4)' ],
            [ 'CLAIM_LEVEL5', 'Overdue fine (level 5)' ],
            [ 'NOTIFICATION', 'Notification fee' ],
        );

        my $dt_sth = $dbh->prepare(
            q{INSERT IGNORE INTO account_debit_types
              (code, description, can_be_invoiced, can_be_sold, is_system)
              VALUES (?, ?, 1, 0, 1)}
        );
        for my $row (@debit_types) {
            my ( $code, $desc ) = @$row;
            $dt_sth->execute( $code, $desc );
            if ( $dt_sth->rows ) {
                say_success( $out, "Inserted account_debit_types row '$code'" );
            } else {
                say_info( $out, "account_debit_types row '$code' already exists" );
            }
        }

        my @letter_bodies = (
            [
                'CLAIM_LEVEL1', 'Overdue claim notice (level 1)', 'First overdue claim notice',
                'The following items are overdue (claim level 1). Please return or renew them as soon as possible.'
            ],
            [
                'CLAIM_LEVEL2', 'Overdue claim notice (level 2)', 'Second overdue claim notice',
                'Despite a previous reminder, the following items remain overdue (claim level 2). A claim fee applies.'
            ],
            [
                'CLAIM_LEVEL3', 'Overdue claim notice (level 3)', 'Third overdue claim notice',
                'The following items are still overdue (claim level 3). An additional claim fee has been charged to your account.'
            ],
            [
                'CLAIM_LEVEL4', 'Overdue claim notice (level 4)', 'Fourth overdue claim notice',
                'The following items remain overdue (claim level 4). This is a formal reminder.'
            ],
            [
                'CLAIM_LEVEL5', 'Overdue claim notice (level 5)', 'Final overdue claim notice',
                'Final notice: the following items are still not returned (claim level 5). The outstanding debt may be forwarded to a collection agency.'
            ],
        );

        my $item_line = q{<item>"<<biblio.title>>" <<items.barcode>> due <<issues.date_due>></item>};

        my $letter_sth = $dbh->prepare(
            q{INSERT IGNORE INTO letter
              (module, code, branchcode, name, is_html, title, message_transport_type, lang, content)
              VALUES ('circulation', ?, '', ?, 0, ?, 'email', 'default', ?)}
        );
        for my $row (@letter_bodies) {
            my ( $code, $name, $title, $body ) = @$row;
            my $content = join(
                "\n",
                'Dear <<borrowers.firstname>> <<borrowers.surname>>,',
                '',
                $body,
                '',
                $item_line,
                '',
                '<<branches.branchname>>',
            );
            $letter_sth->execute( $code, $name, $title, $content );
            if ( $letter_sth->rows ) {
                say_success( $out, "Inserted letter template '$code'" );
            } else {
                say_info( $out, "Letter template '$code' already exists" );
            }
        }
    },
};
