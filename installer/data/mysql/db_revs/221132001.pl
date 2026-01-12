use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number => "",
    description => "Add booking notices",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        # Add booking notices: BOOKING_CONFIRMATION, BOOKING_CANCELLATION, BOOKING_MODIFICATION
        $dbh->do(q{
            INSERT IGNORE INTO `letter` (`module`, `code`, `branchcode`, `name`, `is_html`, `title`, `content`, `message_transport_type`,`lang`) VALUES
            ('bookings','BOOKING_CONFIRMATION','','Buchungsbestätigung','1','Bestätigung Ihrer Medienbuchung','[%- PROCESS \'html_helpers.inc\' -%]\r\n	[%- USE KohaDates -%]\r\n	Guten Tag [%- INCLUDE \'patron-title.inc\' patron => booking.patron -%],\r\n	<br>\r\n	Ihre Buchung ist bei uns eingegangen.<br>\r\n	<br>\r\n	Buchungsdetails:<br />\r\nTitel: [%- INCLUDE \'biblio-title.inc\' biblio=booking.biblio link = 0 -%] <br>\r\n\r\n	Zeitraum: [% booking.start_date | $KohaDates %] bis [% booking.end_date | $KohaDates %]<br>\r\n	Abholort: [% booking.pickup_library.branchname %]<br>\r\n\r\n<br>Alle Buchungsdetails finden Sie auch in Ihrem Benutzerkonto im Onlinekatalog.<br><br>\r\n	Mit freundlichen Grüßen\r\n	<br>\r\n	[% booking.pickup_library.branchname %]\r\n','email','default'),
            ('bookings','BOOKING_CANCELLATION','','Buchung storniert',1,'Ihre Buchung wurde storniert','[%- PROCESS \'html_helpers.inc\' -%]\r\n	[%- USE KohaDates -%]\r\n	Guten Tag [%- INCLUDE \'patron-title.inc\' patron => booking.patron -%],<br>\r\n\r\n	Wir informieren Sie hiermit über die Stornierung Ihrer Buchung.  \r\n	<br><br>\r\n	Buchungsdetails:<br>\r\nTitel: [%- INCLUDE \'biblio-title.inc\' biblio=booking.biblio link = 0 -%] <br>\r\n	Zeitraum: [% booking.start_date | $KohaDates %] bis [% booking.end_date | $KohaDates %]<br>\r\n	Stornierungsgrund: [% booking.cancellation_reason | html %]<br>\r\n\r\n	<br>Details zu Ihren Buchungen finden Sie in Ihrem Benutzerkonto im Onlinekatalog.<br /><br>\r\n	\r\nMit freundlichen Grüßen\r\n	<br>\r\n	[% booking.pickup_library.branchname %]','email','default'),
            ('bookings','BOOKING_MODIFICATION','','Buchung geändert',1,'Ihre Buchung wurde geändert','[%- PROCESS \'html_helpers.inc\' -%]\r\n	[%- USE KohaDates -%]\r\n	Guten Tag [%- INCLUDE \'patron-title.inc\' patron => booking.patron -%],<br>\r\n\r\n	Ihre Buchung wurde verändert.  \r\n	<br><br>\r\n	Neue Buchungsdetails:<br>\r\nTitel: [%- INCLUDE \'biblio-title.inc\' biblio=booking.biblio link = 0 -%] <br>\r\n	Zeitraum: [% booking.start_date | $KohaDates %] bis [% booking.end_date | $KohaDates %]<br>\r\n	Abholort: [% booking.pickup_library.branchname %]<br>\r\n\r\n	<br>Alle Buchungsdetails finden Sie auch in Ihrem Benutzerkonto im Onlinekatalog.<br /><br>\r\n	\r\nMit freundlichen Grüßen\r\n	<br>\r\n	[% booking.pickup_library.branchname %]','email','default')
        });
        
        say_success( $out, "Added booking notices BOOKING_CONFIRMATION, BOOKING_CANCELLATION, BOOKING_MODIFICATION" );
    },
};
