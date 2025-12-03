<!-- Convert to checkout confirmation modal -->
<div class="modal" id="convertToCheckoutModal" tabindex="-1" role="dialog" aria-labelledby="convertToCheckoutLabel">
    <form id="convertToCheckoutForm" method="post" action="">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                    <h4 class="modal-title" id="convertToCheckoutLabel">Convert to checkout</h4>
                </div>
                <div class="modal-body">
                    <div id="convert_to_checkout_result"></div>
                    <input type="hidden" name="borrowernumber" id="convert_borrowernumber">
                    <input type="hidden" name="barcode" id="convert_barcode">
                    <input type="hidden" name="duedatespec" id="convert_duedatespec">
                    <p>Are you sure you want to convert this booking to a checkout?</p>
                    <dl>
                        <dt>Title</dt>
                        <dd id="convert_title"></dd>
                        <dt>Patron</dt>
                        <dd><span id="convert_patron"></span> <span id="convert_cardnumber"></span></dd>
                        <dt>Barcode</dt>
                        <dd><span id="convert_barcode_display"></span> <span id="convert_itemid"></span></dd>
                        <dt>Due date</dt>
                        <dd id="convert_due_date"></dd>
                    </dl>
                </div> <!-- /.modal-body -->
                <div class="modal-footer">
                    <button type="submit" class="btn btn-primary">Confirm checkout</button>
                    <button type="button" class="btn btn-default" data-dismiss="modal" aria-hidden="true">Cancel</button>
                </div> <!-- /.modal-footer -->
            </div> <!-- /.modal-content -->
        </div> <!-- /.modal-dialog -->
    </form>
</div> <!-- /#convertToCheckoutModal -->
