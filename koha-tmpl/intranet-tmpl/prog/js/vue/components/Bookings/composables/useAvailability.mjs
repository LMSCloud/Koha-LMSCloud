import { computed } from "vue";
import { isoArrayToDates } from "../lib/booking/date-utils.mjs";
import { calculateDisabledDates, toEffectiveRules } from "../lib/booking/manager.mjs";

/**
 * Central availability computation.
 * Date type policy:
 * - Input: storeRefs.selectedDateRange is ISO[]; this composable converts to Date[]
 * - Output: disableFnRef for Flatpickr, unavailableByDateRef for calendar markers
 */
export function useAvailability(storeRefs, optionsRef) {
    const {
        bookings,
        checkouts,
        bookableItems,
        bookingItemId,
        bookingId,
        selectedDateRange,
        circulationRules,
    } = storeRefs;

    const availability = computed(() => {
        // If data not ready, return safe defaults
        if (
            !Array.isArray(bookings.value) ||
            !Array.isArray(checkouts.value) ||
            !Array.isArray(bookableItems.value) ||
            bookableItems.value.length === 0
        ) {
            return { disable: () => true, unavailableByDate: {} };
        }

        const effectiveRules = toEffectiveRules(
            circulationRules.value,
            optionsRef.value || {}
        );

        const selectedDatesArray = isoArrayToDates(
            selectedDateRange.value || []
        );

        return calculateDisabledDates(
            bookings.value,
            checkouts.value,
            bookableItems.value,
            bookingItemId.value,
            bookingId.value,
            selectedDatesArray,
            effectiveRules
        );
    });

    const disableFnRef = computed(
        () => availability.value.disable || (() => false)
    );
    const unavailableByDateRef = computed(
        () => availability.value.unavailableByDate || {}
    );

    return { availability, disableFnRef, unavailableByDateRef };
}
