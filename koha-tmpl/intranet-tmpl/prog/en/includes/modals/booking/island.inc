[% USE raw %]
[% USE Asset %]
[% USE To %]
[% USE AdditionalFields %]

[% SET booking_additional_fields = AdditionalFields.with_authorised_values({ tablename => 'bookings' }) %]
<div id="booking-modal-mount">
    <booking-modal biblionumber="[% biblionumber | html %]" show-patron-select show-item-details-selects show-pickup-location-select date-range-constraint="issuelength_with_renewals"></booking-modal>
</div>
[% Asset.js("js/modals/booking.js") | $raw %]
<script nonce="[% Koha.CSPNonce | $raw %]" type="module">
    // Field definitions and their authorised values are template data, so they
    // are attached once rather than carried on every trigger
    const island = document.querySelector("booking-modal");
    if (island) {
        island.extendedAttributeTypes = [% To.json(booking_additional_fields.fields) | $raw %];
        island.authorizedValues = [% To.json(booking_additional_fields.authorised_values_by_category) | $raw %];
        island.showAdditionalFields = true;
    }
</script>
