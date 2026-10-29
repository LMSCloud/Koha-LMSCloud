use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "",
    description => "Send filled hold notices by email as a digest for patrons and categories that get them by email",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Hold_Filled has digest transports since 23.06. Libraries want the digest
        # wherever the hold notice goes out by email, and no digest otherwise.
        my $updated = $dbh->do(
            q{
                UPDATE borrower_message_preferences p
                JOIN message_attributes a ON a.message_attribute_id = p.message_attribute_id
                SET p.wants_digest = EXISTS (
                    SELECT 1 FROM borrower_message_transport_preferences t
                    WHERE t.borrower_message_preference_id = p.borrower_message_preference_id
                      AND t.message_transport_type = 'email'
                )
                WHERE a.message_name = 'Hold_Filled'
            }
        );
        say_success( $out, sprintf "Set the filled hold digest on %d patron and category preference(s)", $updated );
    },
};
