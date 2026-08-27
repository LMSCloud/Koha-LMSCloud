[% USE raw %]
[% USE Asset %]
[% USE Koha %]
[% USE To %]
[% USE AdditionalFields %]

[% SET booking_additional_fields = AdditionalFields.with_authorised_values({ tablename => 'bookings' }) %]
<div id="booking-modal-mount">
    <booking-modal
        biblionumber="[% biblionumber | html %]"
        [%# The OPAC form carries no patron, item or pickup selects, so it needs
            none of the staff modal's width %]
        size="md"
        submit-type="form-submission"
        submit-url="/cgi-bin/koha/opac-bookings.pl"
        date-range-constraint="[% (Koha.Preference('OPACBookingDateRangeConstraint') || 'issuelength_with_renewals') | html %]"
        [%# FIXME: issuelength_with_renewals needs to be the db default, don't constrain needs a value %]
        opac-default-booking-library-enabled="[% Koha.Preference('OPACBookingDefaultLibraryEnabled') | html %]"
        opac-default-booking-library="[% Koha.Preference('OPACBookingDefaultLibrary') | html %]"
    ></booking-modal>
</div>

[% SET islands = Asset.js("js/vue/dist/islands.esm.js").match('(src="([^"]+)")').1 %]
<script type="module">
    import { hydrate } from "[% islands | html %]";
    hydrate();

    // Field definitions and their authorised values are template data, so they
    // are attached once rather than carried on every trigger
    const islandReady = (async () => {
        await customElements.whenDefined("booking-modal");
        const island = document.querySelector("booking-modal");
        if (!island) return null;

        island.extendedAttributeTypes = [% To.json(booking_additional_fields.fields) | $raw %];
        island.authorizedValues = [% To.json(booking_additional_fields.authorised_values_by_category) | $raw %];
        island.showAdditionalFields = true;
        island.addEventListener("close", () => {
            island.open = false;
        });
        return island;
    })();

    document.addEventListener(
        "click",
        async e => {
            const trigger = e.target.closest("[data-booking-modal]");
            if (!trigger) return;
            if (trigger.tagName === "A") {
                e.preventDefault();
            }

            const island = await islandReady;
            if (!island) return;

            const props = trigger.dataset;
            island.bookingId = props.booking ?? null;
            island.itemId = props.itemnumber ?? null;
            island.patronId = props.patron || "[% borrowernumber | html %]";
            island.pickupLibraryId = props.pickup_library ?? null;
            island.startDate = props.start_date ?? null;
            island.endDate = props.end_date ?? null;
            island.itemtypeId = props.item_type_id ?? null;
            island.extendedAttributes = JSON.parse(
                props.extended_attributes || "[]"
            );
            island.open = true;
        }
    );
</script>
