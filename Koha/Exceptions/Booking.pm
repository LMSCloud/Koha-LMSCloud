package Koha::Exceptions::Booking;

use Modern::Perl;

use Exception::Class (
    'Koha::Exceptions::Booking'        => { description => "Something went wrong!" },
    'Koha::Exceptions::Booking::Clash' => {
        isa         => 'Koha::Exceptions::Booking',
        description => "Adding or updating the booking would result in a clash"
    },
    'Koha::Exceptions::Booking::DateRangeConstraint' => {
        isa         => 'Koha::Exceptions::Booking',
        description => "Booking period exceeds maximum allowed by circulation rules",
        fields      => [ 'requested_days', 'max_days', 'constraint_type' ]
    },
);

1;
