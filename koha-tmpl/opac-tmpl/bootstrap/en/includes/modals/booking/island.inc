[% USE To %]
[% USE AdditionalFields %]
[% USE AuthorisedValues %]

<div id="booking-modal-mount">
    <booking-modal-island biblionumber="[% biblionumber | html %]" submit-type="form-submission" submit-url="/cgi-bin/koha/opac-bookings.pl" show-additional-fields></booking-modal-island>
</div>

[% SET islands = Asset.js("js/vue/dist/islands.esm.js").match('(src="([^"]+)")').1 %] <script src="[% islands %]" type="module">
</script>
[% SET additional_fields_data = AdditionalFields.with_authorised_values({ tablename => 'bookings' }) %]
<script type="module">
    import { hydrate } from "[% islands %]";
    hydrate();

    const island = document.querySelector("booking-modal-island");
    if (island) {
        // The 'close' event is emitted by the vue component.
        // We just need to make sure the island closes itself.
        // The timeline has its own separate listener.
        island.addEventListener('close', () => {
            island.open = false;
        });

        document.addEventListener('click', e => {
            const bookingModalButton = e.target.closest("[data-booking-modal]");
            if (bookingModalButton) {
                const props = bookingModalButton.dataset;
                island.bookingId = props.booking;
                island.itemId = props.itemnumber;
                island.patronId = props.patron || "[% borrowernumber | html %]";
                island.pickupLibraryId = props.pickup_library;
                island.startDate = props.start_date;
                island.endDate = props.end_date;
                island.itemtypeId = props.item_type_id;
                island.extendedAttributes = JSON.parse(props.extended_attributes || "[]");

                // Use the new idiomatic interface for additional fields and authorized values
                // Convert the Perl data structure to JSON using a more reliable method
                const additionalFieldsData = {
                    fields: [% To.json(additional_fields_data.fields) %],
                    authorised_values_by_category: [% To.json(additional_fields_data.authorised_values_by_category) %]
                };

                island.extendedAttributeTypes = JSON.parse(props.extended_attribute_types || JSON.stringify(additionalFieldsData.fields) || "[]");
                island.authorizedValues = JSON.parse(props.authorized_values || JSON.stringify(additionalFieldsData.authorised_values_by_category) || "{}");
                island.open = true;
            }
        }, { passive: true });
    }
</script>
