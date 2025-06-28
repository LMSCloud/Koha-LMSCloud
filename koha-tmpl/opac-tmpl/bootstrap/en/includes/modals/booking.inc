[% USE Branches %]
[% SET booking_id = BOOKING.booking_id | html %]

<div class="modal" id="[% action %]-[% booking_id %]" tabindex="-1" aria-labelledby="[% action %]-[% booking_id %]-label" aria-hidden="true">
    <div class="modal-dialog">
        <form id="[% action %]-form-[% booking_id %]" action="/cgi-bin/koha/opac-bookings.pl" method="post">
            [% INCLUDE 'csrf-token.inc' %]
            <input type="hidden" name="op" value="cud-[% action.replace('-', '_') %]">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title" id="[% action %]-[% booking_id %]-label">
                        [% SWITCH action %]
                            [% CASE 'change-pickup-location' %]
                                Change pickup location for booking of <em>[% INCLUDE 'biblio-title.inc' biblio=BOOKING.item.biblio %]</em>
                            [% CASE 'cancel' %]
                                Cancel booking of <em>[% INCLUDE 'biblio-title.inc' biblio=BOOKING.item.biblio %]</em>
                            [% CASE 'add' %]
                                Place a booking
                            [% CASE %]
                        [% END %]
                    </h1>
                    <button type="button" class="btn-close" data-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    [% SWITCH action %]
                        [% CASE 'change-pickup-location' %]
                            <div class="form-group">
                                <label for="new-pickup-location-[% booking_id %]">New pickup location:</label>
                                <select name="new_pickup_location" id="new-pickup-location-[% booking_id %]" class="form-select">
                                    [% PROCESS options_for_libraries libraries = Branches.pickup_locations({ search_params => { biblio => BOOKING.item.biblio, patron => BOOKING.patron_id }, selected => BOOKING.pickup_library_id }) %]
                                </select>
                            </div>
                        [% CASE 'cancel' %]
                            <span>Are you sure you want to cancel your booking of <em>[% INCLUDE 'biblio-title.inc' biblio=BOOKING.item.biblio %]</em>?</span>
                        [% CASE 'add' %]
                        <!--
                            <input name="biblio_id">
                            <input name="item_id">
                            <input name="pickup_library_id">
                            <input name="start_date">
                            <input name="end_date">
                        -->
                            <fieldset class="brief">
                                <input type="hidden" name="biblio_id" id="biblio-id" value="[% biblio.biblionumber %]">
                                <ol>
                                    <li>
                                        <label class="required" for="pickup-library-id">Pickup at:</label>
                                        <select name="pickup_library_id" id="pickup-library-id" required>
                                            <option selected>Please select a pickup location</option>
                                            [% PROCESS options_for_libraries libraries = Branches.pickup_locations({ search_params => { biblio => biblio.biblionumber, patron => logged_in_user.borrowernumber } }) %]
                                        </select>
                                        <span class="required">Required</span>
                                    </li>
                                    <label for="booking-item-id">Item: </label>
                                        <select name="item_id" id="booking-item-id">
                                            <option value="0">Any item</option>
                                            [% FOR item IN biblio.bookable_items %]
                                                <option value="[% item.itemnumber %]">[% item.barcode %]</option>
                                            [% END %]
                                        </select>
                                    </li>
                                    <li>
                                        <div id="period_fields">
                                            <label class="required" for="period">Booking dates: </label>
                                            <input type="text" id="period" name="period" class="flatpickr" data-flatpickr-futuredate="true" data-flatpickr-disable-shortcuts="true" required autocomplete="off">
                                            <span class="required">Required</span>
                                        </div>
                                        <div class="hint">Select the booking start date (and end date in the next patch)</div>
                                    </li>
                                </ol>
                            </fieldset>
                        [% CASE %]
                    [% END %]
                    <input type="hidden" name="booking_id" value="[% booking_id %]" />
                </div>
                <div class="modal-footer">
                    <button type="submit" name="[% action.replace('-', '_') %]" value="1" class="btn btn-primary">
                        <i class="fa fa-check" aria-hidden="true"></i>&nbsp;
                        [% SWITCH action %]
                            [% CASE 'cancel' %]
                                <span>Confirm</span>
                            [% CASE %]
                                Save
                        [% END %]
                    </button>
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">
                        <i class="fa fa-times" aria-hidden="true"></i>&nbsp;Cancel
                    </button>
                </div>
            </div> <!-- /.modal-content -->
        </form>
    </div> <!-- /.modal-dialog -->
</div> <!-- /.modal -->