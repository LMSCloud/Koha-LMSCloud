[% USE ItemTypes %]
<!-- Place booking modal -->
<div class="modal" id="placeBookingModal" tabindex="-1" role="dialog" aria-labelledby="placeBookingLabel">
    <form id="placeBookingForm">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                    <h4 class="modal-title" id="placeBookingLabel"></h4>
                </div>
                <div class="modal-body">
                    <div id="booking_result"></div>
                    <fieldset class="brief">
                        <input type="hidden" name="biblio_id" id="booking_id">
                        <input type="hidden" name="biblio_id" id="booking_biblio_id">
                        <input type="hidden" name="start_date" id="booking_start_date">
                        <input type="hidden" name="end_date" id="booking_end_date">
                        <ol>
                            <li>
                                <label class="required" for="booking_patron_id">Patron: </label>
                                <select name="booking_patron_id" id="booking_patron_id" required="required">
                                    <option></option>
                                    [% IF patron %]
                                    <option value="[% borrowernumber | uri %]" selected="selected">[% patron.firstname | html %] [% patron.surname | html %] ([% patron.cardnumber | html %] )</option>
                                    [% END %]
                                </select>
                                <div class="hint">Enter patron card number or partial name</div>
                            </li>
                            <li>
                                <label class="required" for="booking_pickup">Pickup at:</label>
                                <select name="booking_pickup" id="pickup_library_id" required="required" disabled="true"></select>
                                <span class="required">Required</span>
                            </li>
                            <li>
                                <label for="booking_itemtype">Itemtype: </label>
                                <select id="booking_itemtype" name="booking_itemtype" disabled="disabled">
                                </select>
                            <li>
                            <label for="booking_item_id">Item: </label>
                                <select name="booking_item_id" id="booking_item_id" disabled="true">
                                    <option value="0">Any item</option>
                                </select>
                            </li>
                            <li>
                                <div id="period_fields">
                                    <label class="required" for="period">Booking dates: </label>
                                    <input type="text" id="period" name="period" class="flatpickr" data-flatpickr-futuredate="true" data-flatpickr-disable-shortcuts="true" required="required" disabled="true" autocomplete="off">
                                    <span class="required">Required</span>
                                </div>
                                <div class="hint">Select the booking start and end date</div>
                            </li>
                        </ol>
                    </fieldset>
                    <fieldset class="brief" id="booking_extended_attributes"></fieldset>
                </div> <!-- /.modal-body -->
                <div class="modal-footer">
                    <button type="submit" class="btn btn-primary">Submit</button>
                    <button type="button" class="btn btn-default" data-dismiss="modal" aria-hidden="true">Cancel</button>
                </div> <!-- /.modal-footer -->
            </div> <!-- /.modal-content -->
        </div> <!-- /.modal-dialog -->
    </form>
</div> <!-- /#placeBookingModal -->
