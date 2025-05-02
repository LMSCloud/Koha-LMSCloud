[% USE Branches %]
[% USE ItemTypes %]
[% USE KohaDates %]
[% PROCESS 'i18n.inc' %]

<table id="opac-user-bookings-table" class="table table-bordered table-striped">
    <caption>Bookings <span class="count">([% BOOKINGS.count | html %] total)</span></caption>
    <thead>
        <tr>
            <th class="all anti-the">Title</th>
            <th class="psort">Placed on</th>
            <th class="psort">Pickup location</th>
            <th class="psort">Start date</th>
            <th class="psort">End date</th>
            <th class="psort">Item type</th>
            <th class="psort">Barcode</th>
            <th class="psort">Provided by</th>
            <th class="nosort">Modify</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
        [% FOREACH BOOKING IN BOOKINGS %]
            <tr>
                <td class="title">
                    [% INCLUDE 'biblio-title.inc' biblio=BOOKING.biblio link => 1 %]
                    [% BOOKING.item.enumchron | html %]
                    [% BOOKING.biblio.author | html %]
                </td>
                <td class="creation-date">
                    [% BOOKING.creation_date | $KohaDates %]
                </td>
                <td class="pickup-library">
                    [% BOOKING.pickup_library.branchname | html %]
                    <button type="button" class="btn btn-sm btn-link" data-bs-toggle="modal" data-bs-target="#change-pickup-location-[% BOOKING.booking_id | html %]">
                        <i class="fa fa-pencil-alt" aria-hidden="true"></i>&nbsp;Change
                    </button>
                    [% PROCESS 'modals/booking.inc' action = 'change-pickup-location' %]
                </td>
                <td class="start-date">
                    [% BOOKING.start_date | $KohaDates %]
                </td>
                <td class="end-date">
                    [% BOOKING.end_date | $KohaDates %]
                </td>
                [% IF BOOKING.item %]
                    <td class="item-type">
                        [% BOOKING.item.itemtype.description %]
                    </td>
                    <td class="barcode">
                        [% BOOKING.item.barcode %]
                    </td>
                [% ELSE %]
                    <td>&ndash;</td>
                    <td>&ndash;</td>
                [% END %]
                <td class="branch">
                    [% Branches.GetName(BOOKING.item.homebranch) | html %]
                </td>
                <td class="modify">
                    <button
                        type="button"
                        class="btn btn-sm btn-danger btn-delete-booking"
                        data-bs-toggle="modal"
                        data-bs-target="#cancel-[% BOOKING.booking_id | html %]"
                    >
                        <i class="fa fa-times" aria-hidden="true"></i>&nbsp;[% tp('Cancel booking button', 'Cancel') | html %]
                    </button>
                    [% PROCESS 'modals/booking.inc' action = 'cancel' %]
                </td>
                <td></td>
            </tr>
        [% END # /FOREACH HOLDS %]
    </tbody>
</table>
