[% USE AuthorisedValues %]
<!-- Cancel booking modal -->
<div class="modal" id="cancelBookingModal" tabindex="-1" role="dialog" aria-labelledby="cancelBookingLabel">
    <form method="post" id="cancelBookingForm" action="/cgi-bin/koha/opac-bookings.pl">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title" id="cancelBookingLabel">Cancel booking</h1>
                    <button type="button" class="btn btn-ghost" data-dismiss="modal" aria-label="Close"><i class="fa fa-times"></i></button>
                </div>
                <div class="modal-body overflow-visible">
                    <div id="cancel_booking_result"></div>
                    <input type="hidden" name="booking_id" id="cancel_booking_id"  />
                    <input type="hidden" name="op" value="cud-cancel" />
                    [% INCLUDE 'csrf-token.inc' %]
                    <p>Are you sure you want to cancel this booking?</p>
                    <fieldset class="brief">
                        [% SET booking_cancellation = AuthorisedValues.GetAuthValueDropbox('BOOKING_CANCELLATION') %]
                        <div class="combobox-container">
                            <label for="cancellation-reason" class="form-label">Cancellation reason:</label>
                            <input type="text" id="cancellation-reason" name="cancellation_reason" class="form-control" maxlength="80" />
                            <ul id="cancellation-reason-list" class="dropdown-menu">
                                [% IF booking_cancellation.count %]
                                    [% FOR reason IN booking_cancellation %]
                                        <li>
                                            <button type="button" class="dropdown-item" data-id="[% reason.authorised_value | html %]"> [% reason.lib | html %] </button>
                                        </li>
                                    [% END %]
                                [% END %]
                            </ul>
                        </div>
                    </fieldset>
                    <!-- /.brief -->
                </div>
                <!-- /.modal-body -->
                <div class="modal-footer">
                    <button type="submit" class="btn btn-default approve"><i class="fa fa-check"></i> Yes, cancel booking</button>
                    <button type="button" class="btn btn-default deny" data-dismiss="modal"><i class="fa fa-remove"></i> No, do not cancel</button>
                </div>
                <!-- /.modal-footer -->
            </div>
            <!-- /.modal-content -->
        </div>
        <!-- /.modal-dialog -->
    </form>
</div>
<!-- /#cancelBookingModal -->
