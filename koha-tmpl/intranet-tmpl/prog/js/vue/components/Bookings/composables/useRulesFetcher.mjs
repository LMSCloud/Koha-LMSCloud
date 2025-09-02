import { watchEffect, ref } from "vue";

/**
 * Watches patron, item type, pickup, and date to fetch pickup locations and
 * circulation rules with de-duplication based on a computed key.
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

    function buildRulesKey(params) {
        // Stable, explicit, order-preserving key builder to avoid JSON quirks
        const parts = [];
        const push = (k, v) => {
            if (v === null || v === undefined || v === "") return;
            parts.push(`${k}=${String(v)}`);
        };
        push("pc", params.patron_category_id);
        push("it", params.item_type_id);
        push("lib", params.library_id);
        push("start", params.start_date);
        return parts.join("|");
    }

    watchEffect(
        () => {
            const patronId = bookingPatron.value?.patron_id;
            const biblio = typeof biblionumber === "object"
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
