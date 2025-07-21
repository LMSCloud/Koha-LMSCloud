# Data Flow

## Staff Interface

- members/moremember.pl
- circ/pendingbookings.pl
- circ/circulation-home.pl
- circ/circulation.pl
- circ/bookings.pl
- bookings/list.pl

Requires the following endpoints to work:

- `/api/v1/biblios/{biblionumber}/items?bookable=1`
- `/api/v1/biblios/{biblionumber}/bookings?q={"status":{"-in":["new","pending","active"]}}`
- `/api/v1/biblios/{biblionumber}/checkouts`
- `/api/v1/biblios/{biblionumber}/pickup_locations`
- `/api/v1/patrons`
- `/api/v1/circulation_rules`
- `/api/v1/bookings`

## OPAC

- opac-user.pl
- opac-bookings.pl
- opac-detail.pl

## TODO

- [] 
