use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "",
    description => "Add HOLD_CANCELLATION notice for Storno hold cancellations",
    up => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add HOLD_CANCELLATION notice (email + print) for EKZ standing order Storno processing.
        # NOTE: Koha/Hold.pm cancel() looks up letter_code 'HOLD_CANCELLATION' by default.
        #       If this notice uses 'HOLD_CANCELLATION', Hold.pm must be patched accordingly.
        $dbh->do(q{
            INSERT IGNORE INTO `letter`
                (`module`, `code`, `branchcode`, `name`, `is_html`, `title`, `content`, `message_transport_type`, `lang`)
            VALUES
            (
                'reserves',
                'HOLD_CANCELLATION',
                '',
                'Vormerkung storniert (EKZ)',
                1,
                'Ihre Vormerkung wurde storniert',
                '[%- USE KohaDates -%]\r\nGuten Tag [% borrowers.firstname %] [% borrowers.surname %],<br>\r\n<br>\r\nIhre Vormerkung für das folgende Medium wurde storniert, da der Titel nicht lieferbar ist:<br>\r\n<br>\r\nTitel: [% biblio.title %]<br>\r\nAutor/in: [% biblio.author %]<br>\r\nVorgemerkt am: [% reserves.reservedate | $KohaDates %]<br>\r\n<br>\r\nFalls Sie Fragen haben, wenden Sie sich bitte an Ihre Bibliothek.<br>\r\n<br>\r\nMit freundlichen Grüßen<br>\r\n[% branches.branchname %]',
                'email',
                'default'
            ),
            (
                'reserves',
                'HOLD_CANCELLATION',
                '',
                'Vormerkung storniert (EKZ)',
                0,
                'Ihre Vormerkung wurde storniert',
                'Guten Tag [% borrowers.firstname %] [% borrowers.surname %],\r\n\r\nIhre Vormerkung für das folgende Medium wurde storniert, da der Titel nicht lieferbar ist:\r\n\r\nTitel: [% biblio.title %]\r\nAutor/in: [% biblio.author %]\r\nVorgemerkt am: [% reserves.reservedate | $KohaDates %]\r\n\r\nFalls Sie Fragen haben, wenden Sie sich bitte an Ihre Bibliothek.\r\n\r\nMit freundlichen Grüßen\r\n[% branches.branchname %]',
                'print',
                'default'
            )
        });

        say_success( $out, "Added HOLD_CANCELLATION notice (email + print)" );
    },
};