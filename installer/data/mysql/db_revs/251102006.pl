use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "42083",
    description => "Split send_messages_to_borrowers into email and sms permissions",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE INTO permissions (module_bit, code, description) VALUES (4, 'send_messages_to_borrowers_email', 'Send messages to patrons via email')}
        );
        say_success( $out, "Added new permission 'send_messages_to_borrowers_email'" );

        $dbh->do(
            q{INSERT IGNORE INTO permissions (module_bit, code, description) VALUES (4, 'send_messages_to_borrowers_sms', 'Send messages to patrons via sms')}
        );
        say_success( $out, "Added new permission 'send_messages_to_borrowers_sms'" );

        my $insert_sth =
            $dbh->prepare("INSERT IGNORE INTO user_permissions (borrowernumber, module_bit, code) VALUES (?, ?, ?)");

        my $sth =
            $dbh->prepare("SELECT borrowernumber FROM user_permissions WHERE code = 'send_messages_to_borrowers'");
        $sth->execute();

        while ( my ($borrowernumber) = $sth->fetchrow_array() ) {
            $insert_sth->execute( $borrowernumber, 4, 'send_messages_to_borrowers_email' );
        }

        say_success( $out, "send_messages_to_borrowers_email added to all borrowers with send_messages_to_borrowers" );

        $dbh->do(q{DELETE FROM permissions WHERE code='send_messages_to_borrowers'});
        say_success( $out, "Removed permission 'send_messages_to_borrowers'" );

        $dbh->do(q{DELETE FROM user_permissions WHERE code='send_messages_to_borrowers'});
        say_success( $out, "Removed user_permission 'send_messages_to_borrowers'" );
    },
};
