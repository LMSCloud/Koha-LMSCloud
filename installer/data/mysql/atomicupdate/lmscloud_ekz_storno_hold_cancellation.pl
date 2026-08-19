use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-ekz-storno-hold-cancellation",
    description => "Add the HOLD_CANCELLATION notice and EKZ_STORNO reason for ekz Storno hold cancellations",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Koha::Hold::cancel() looks up letter_code HOLD_CANCELLATION whenever a
        # cancellation_reason is passed, and community 25.11 ships no such notice.
        $dbh->do(
            q{
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
        }
        );

        my ($letters) = $dbh->selectrow_array(q{SELECT COUNT(*) FROM letter WHERE code = 'HOLD_CANCELLATION'});
        say_success( $out, "HOLD_CANCELLATION notice present ($letters row(s))" );

        # Without this the cancellation reason renders as the raw code in the
        # staff interface, since Koha::Hold::cancellation_reason_str resolves it
        # through the HOLD_CANCELLATION authorised value category.
        my $added = $dbh->do(
            q{INSERT IGNORE INTO authorised_values (category, authorised_value, lib)
              VALUES ('HOLD_CANCELLATION', 'EKZ_STORNO', ?)},
            undef, 'Titel nicht lieferbar (ekz-Storno)'
        );

        # DBI returns the truthy string "0E0" for zero affected rows, so compare numerically
        if ( $added > 0 ) {
            say_success( $out, "Added the EKZ_STORNO hold cancellation reason" );
        } else {
            say_info( $out, "EKZ_STORNO hold cancellation reason already present, skipping" );
        }
    },
};
