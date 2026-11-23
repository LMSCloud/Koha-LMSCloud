use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "",
    description => "Send membership expiry notices by email to all patrons and categories when they are enabled",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Since bug 30300 membership_expiry.pl follows the Patron_Expiry messaging
        # preference; before, every patron got the notice. Libraries that send
        # expiry notices keep them going out by email to everyone.
        my ($days) =
            $dbh->selectrow_array(q{SELECT value FROM systempreferences WHERE variable = 'MembershipExpiryDaysNotice'});
        unless ( defined $days && $days ne '' ) {
            say_info( $out, "MembershipExpiryDaysNotice is empty, leaving the membership expiry preferences alone" );
            return;
        }

        my ($attribute_id) = $dbh->selectrow_array(
            q{SELECT message_attribute_id FROM message_attributes WHERE message_name = 'Patron_Expiry'});
        return unless $attribute_id;

        my $patrons = $dbh->do(
            q{
                INSERT INTO borrower_message_preferences (borrowernumber, message_attribute_id, wants_digest)
                SELECT b.borrowernumber, ?, 0 FROM borrowers b
                WHERE NOT EXISTS (
                    SELECT 1 FROM borrower_message_preferences p
                    WHERE p.borrowernumber = b.borrowernumber AND p.message_attribute_id = ?
                )
            }, undef, $attribute_id, $attribute_id
        );
        my $categories = $dbh->do(
            q{
                INSERT INTO borrower_message_preferences (categorycode, message_attribute_id, wants_digest)
                SELECT c.categorycode, ?, 0 FROM categories c
                WHERE NOT EXISTS (
                    SELECT 1 FROM borrower_message_preferences p
                    WHERE p.categorycode = c.categorycode AND p.message_attribute_id = ?
                )
            }, undef, $attribute_id, $attribute_id
        );
        my $emails = $dbh->do(
            q{
                INSERT INTO borrower_message_transport_preferences (borrower_message_preference_id, message_transport_type)
                SELECT p.borrower_message_preference_id, 'email' FROM borrower_message_preferences p
                WHERE p.message_attribute_id = ?
                  AND NOT EXISTS (
                    SELECT 1 FROM borrower_message_transport_preferences t
                    WHERE t.borrower_message_preference_id = p.borrower_message_preference_id
                      AND t.message_transport_type = 'email'
                  )
            }, undef, $attribute_id
        );
        say_success(
            $out,
            sprintf "Membership expiry preference added for %d patron(s) and %d category(ies), email enabled on %d",
            $patrons, $categories, $emails
        );
    },
};
