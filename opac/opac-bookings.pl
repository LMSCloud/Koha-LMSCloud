#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use C4::Auth    qw( get_template_and_user );
use C4::Context ();
use C4::Members ();
use C4::Output  qw( output_html_with_http_headers );

use Koha::Biblios   ();
use Koha::Booking   ();
use Koha::Bookings  ();
use Koha::DateUtils qw(dt_from_string);
use Koha::Patrons   ();

use CGI         qw( -utf8 );
use Carp        qw( croak );
use Digest::SHA qw( sha1_base64 );
use JSON        ();
use Time::HiRes qw( time );

my $query = CGI->new;
if ( !C4::Context->preference('OPACBookings') ) {
    print $query->redirect('/cgi-bin/koha/errors/404.pl') or croak;
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => 'opac-bookings.tt',
        query         => $query,
        type          => 'opac',
    }
);

my $patron = Koha::Patrons->find($borrowernumber);

my $op = $query->param('op') // 'list';
if ( $op eq 'list' ) {
    my $bookings = Koha::Bookings->search( { patron_id => $patron->borrowernumber } );
    my $hash     = sha1_base64( join q{}, time, rand );

    my $biblio;
    my $biblio_id = $query->param('biblio_id');
    if ($biblio_id) {
        $biblio = Koha::Biblios->find($biblio_id);
    }

    $template->param(
        op      => 'list', BOOKINGS => $bookings,
        BOOKING => { booking_id => $hash },
        biblio  => $biblio,
    );
}

if ( $op eq 'cud-add' ) {
    my $patron_id         = $patron->borrowernumber;
    my $biblio_id         = $query->param('biblio_id');
    my $item_id           = $query->param('item_id')           // 0;
    my $pickup_library_id = $query->param('pickup_library_id') // $patron->branchcode;
    my $start_date        = dt_from_string( $query->param('start_date'), 'rfc3339' );
    my $end_date          = dt_from_string( $query->param('end_date'),   'rfc3339' );

    my $booking = Koha::Booking->new(
        {
            patron_id         => $patron_id,
            biblio_id         => $biblio_id,
            item_id           => $item_id,
            pickup_library_id => $pickup_library_id,
            start_date        => $start_date,
            end_date          => $end_date,
        }
    )->store;

    # Handle extended attributes if provided
    my $extended_attributes_json = $query->param('extended_attributes');
    if ($extended_attributes_json) {
        my $json                = JSON->new;
        my $extended_attributes = $json->decode($extended_attributes_json);

        # Convert to the format expected by the extended_attributes method
        my @extended_attributes_formatted =
            map { { 'id' => $_->{field_id}, 'value' => $_->{value} } } @{$extended_attributes};

        $booking->extended_attributes( \@extended_attributes_formatted );
    }

    print $query->redirect( $query->referer ) or croak;
}

if ( $op eq 'cud-cancel' ) {
    my $booking_id          = $query->param('booking_id');
    my $cancellation_reason = $query->param('cancellation_reason');
    my $booking             = Koha::Bookings->find($booking_id);
    if ( !$booking ) {
        print $query->redirect('/cgi-bin/koha/errors/404.pl') or croak;
        exit;
    }

    if ( $booking->patron_id ne $patron->borrowernumber ) {
        print $query->redirect('/cgi-bin/koha/errors/403.pl') or croak;
        exit;
    }

    my $is_updated = $booking->update( { status => 'cancelled', cancellation_reason => $cancellation_reason } );
    if ( !$is_updated ) {
        print $query->redirect('/cgi-bin/koha/errors/500.pl') or croak;
        exit;
    }

    if ( index( $query->referer, 'opac-detail.pl' ) != -1 ) {
        print $query->redirect( $query->referer ) or croak;
        exit;
    }

    print $query->redirect('/cgi-bin/koha/opac-user.pl?tab=opac-user-bookings') or croak;
}

if ( $op eq 'cud-change_pickup_location' ) {
    my $booking_id          = $query->param('booking_id');
    my $new_pickup_location = $query->param('new_pickup_location');
    my $booking             = Koha::Bookings->find($booking_id);

    if ( !$booking ) {
        print $query->redirect('/cgi-bin/koha/errors/404.pl') or croak;
        exit;
    }

    if ( $booking->patron_id ne $patron->borrowernumber ) {
        print $query->redirect('/cgi-bin/koha/errors/403.pl') or croak;
        exit;
    }

    my $is_updated = $booking->update( { pickup_library_id => $new_pickup_location } );
    if ( !$is_updated ) {
        print $query->redirect('/cgi-bin/koha/errors/500.pl') or croak;
        exit;
    }

    print $query->redirect('/cgi-bin/koha/opac-user.pl?tab=opac-user-bookings') or croak;
}

$template->param(
    bookingsview => 1,
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
