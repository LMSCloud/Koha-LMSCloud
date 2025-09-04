import { watchEffect, ref } from "vue";

/**
 * Watches patron, item type, pickup, and date to fetch pickup locations and
 * circulation rules with de-duplication based on a computed key.
 */
/**
 * Watch core selections and fetch pickup locations and circulation rules.
 * De-duplicates rules fetches by building a stable key from inputs.
 *
 * @typedef {import('../types/bookings').BookingStoreLike & import('../types/bookings').BookingStoreActions} StoreWithActions
 * @param {Object} options
 * @param {StoreWithActions} options.store
 * @param {{value:Object|null}} options.bookingPatron
 * @param {{value:string|null}} options.bookingPickupLibraryId
 * @param {{value:string|number|null}} options.bookingItemtypeId
 * @param {{value:Array}} options.constrainedItemTypes
 * @param {{value:Array}} options.selectedDateRange
 * @param {string|{value:string}} options.biblionumber
 */
export function useRulesFetcher(options) {
    const {
        store,
        bookingPatron, // ref(Object|null)
        bookingPickupLibraryId, // ref(String|null)
        bookingItemtypeId, // ref(String|Number|null)
        constrainedItemTypes, // ref(Array)
        selectedDateRange, // ref([ISO, ISO])
        biblionumber, // string or ref(optional)
    } = options;

    const lastRulesKey = ref(null);

    watchEffect(
        () => {
            const patronId = bookingPatron.value?.patron_id;
            const biblio =
                typeof biblionumber === "object"
                    ? biblionumber.value
                    : biblionumber;

            if (patronId && biblio) {
                store.fetchPickupLocations(biblio, patronId);
            }

            const patron = bookingPatron.value;
            const derivedItemTypeId =
                bookingItemtypeId.value ??
                (Array.isArray(constrainedItemTypes.value) &&
                constrainedItemTypes.value.length === 1
                    ? constrainedItemTypes.value[0].item_type_id
                    : undefined);

            const rulesParams = {
                patron_category_id: patron?.category_id,
                item_type_id: derivedItemTypeId,
                library_id: bookingPickupLibraryId.value,
                start_date: selectedDateRange.value?.[0] || undefined,
            };
            const key = buildRulesKey(rulesParams);
            if (lastRulesKey.value !== key) {
                lastRulesKey.value = key;
                // Invalidate stale backend due so UI falls back to maxPeriod until fresh rules arrive
                store.invalidateCalculatedDue();
                store.fetchCirculationRules(rulesParams);
            }
        },
        { flush: "post" }
    );

    return { lastRulesKey };
}

function buildRulesKey(params) {
    // Stable, explicit, order-preserving key builder to avoid JSON quirks
    return [
        ["pc", params.patron_category_id],
        ["it", params.item_type_id],
        ["lib", params.library_id],
        ["start", params.start_date],
    ]
        .filter(([, v]) => v ?? v === 0)
        .map(([k, v]) => `${k}=${String(v)}`)
        .join("|");
}
