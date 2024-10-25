[% USE AuthorisedValues %]
<!-- Cancel booking modal -->
<div class="modal" id="cancelBookingModal" tabindex="-1" role="dialog" aria-labelledby="cancelBookingLabel">
    <form id="cancelBookingForm">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                    <h4 class="modal-title" id="cancelBookingLabel">Cancel booking</h4>
                </div>
                <div class="modal-body overflow-visible">
                    <div id="cancel_booking_result"></div>
                    <input type="hidden" name="booking_id" id="cancel_booking_id">
                    <p>Are you sure you want to cancel this booking?</p>
                    <fieldset class="brief">
                        [% SET booking_cancellation = AuthorisedValues.GetAuthValueDropbox('BOOKING_CANCELLATION') %]
                        <div class="combobox-container">
                            <label for="cancellation-reason" class="form-label">Cancellation Reason:</label>
                            <input type="text" id="cancellation-reason" name="cancellation_reason" class="form-control" maxlength="80" />
                            <ul id="cancellation-reason-list" class="dropdown-menu">
                                [% IF booking_cancellation.count %]
                                    [% FOR reason IN booking_cancellation %]
                                        <li>
                                            <button type="button" class="dropdown-item" data-id="[% reason.authorised_value | html %]">
                                                [% reason.lib | html %]
                                            </button>
                                        </li>
                                    [% END %]
                                [% END %]
                            </ul>
                        </div>
                    </fieldset> <!-- /.brief -->
                </div> <!-- /.modal-body -->
                <div class="modal-footer">
                    <button type="submit" class="btn btn-danger">Confirm</button>
                    <button type="button" class="btn btn-default" data-dismiss="modal" aria-hidden="true">Cancel</button>
                </div> <!-- /.modal-footer -->
            </div> <!-- /.modal-content -->
        </div> <!-- /.modal-dialog -->
    </form>
</div> <!-- /#cancelBookingModal -->
