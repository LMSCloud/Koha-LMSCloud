[% USE AdditionalFields %]

<div id="booking-modal-mount">
    <booking-modal-island
        biblionumber="[% biblionumber | html %]"
        show-patron-select
        show-item-details-selects
        show-pickup-location-select
        show-additional-fields
    ></booking-modal-island>
</div>
[% SET islands = Asset.js("js/vue/dist/islands.esm.js").match('(src="([^"]+)")').1 %] <script src="[% islands %]" type="module"></script>
<script type="module">
    import { hydrate } from "[% islands %]";
    hydrate();

    const island = document.querySelector("booking-modal-island");
    if (island) {
        island.addEventListener('close', () => {
            island.open = false;
        });
        /* This might need to be optimised if we ever
         * run into noticable lag on click events. */
        document.addEventListener('click', e => {
            if (e.target.closest("[data-booking-modal]")) {
                const props = e.target.dataset;
                island.bookingId = props.booking;
                island.itemId = props.itemnumber;
                island.patronId = props.patron;
                island.pickupLibraryId = props.pickup_library;
                island.startDate = props.start_date;
                island.endDate = props.end_date;
                island.itemtypeId = props.item_type_id;
                island.extendedAttributes = JSON.parse(props.extended_attributes ?? "[]");
                if (props.biblionumber) {
                    island.biblionumber = props.biblionumber;
                }

                island.open = true;
            }
            return;
        }, { passive: true });
    }
</script>
