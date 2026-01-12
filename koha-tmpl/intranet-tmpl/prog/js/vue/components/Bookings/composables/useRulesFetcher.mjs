import { watchEffect, ref, watch } from "vue";

/**
 * Watch core selections and fetch pickup locations, circulation rules, and holidays.
 * De-duplicates rules fetches by building a stable key from inputs.
 *
 * @param {Object} options
 * @param {import('../types/bookings').StoreWithActions} options.store
 * @param {import('../types/bookings').RefLike<import('../types/bookings').PatronLike|null>} options.bookingPatron
 * @param {import('../types/bookings').RefLike<string|null>} options.bookingPickupLibraryId
 * @param {import('../types/bookings').RefLike<string|number|null>} options.bookingItemtypeId
 * @param {import('../types/bookings').RefLike<Array<import('../types/bookings').ItemType>>} options.constrainedItemTypes
 * @param {import('../types/bookings').RefLike<Array<string>>} options.selectedDateRange
 * @param {string|import('../types/bookings').RefLike<string>} options.biblionumber
 * @returns {{ lastRulesKey: import('vue').Ref<string|null> }}
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
    const lastHolidaysLibrary = ref(null);

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

    watch(
        () => bookingPickupLibraryId.value,
        (libraryId) => {
            if (libraryId === lastHolidaysLibrary.value) {
                return;
            }
            lastHolidaysLibrary.value = libraryId;

            // Fetch holidays for 1 year to cover typical booking scenarios
            // and avoid on-demand fetching lag when navigating calendar months
            const today = new Date();
            const oneYearLater = new Date(today);
            oneYearLater.setFullYear(oneYearLater.getFullYear() + 1);

            const formatDate = d => d.toISOString().split("T")[0];
            store.fetchHolidays(libraryId, formatDate(today), formatDate(oneYearLater));
        },
        { immediate: true }
    );

    return { lastRulesKey };
}

/**
 * Stable, explicit, order-preserving key builder to avoid JSON quirks
 *
 * @param {import('../types/bookings').RulesParams} params
 * @returns {string}
 */
function buildRulesKey(params) {
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
