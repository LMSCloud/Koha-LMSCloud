import { computed } from "vue";
import { isoArrayToDates } from "../lib/booking/date-utils.mjs";
import {
    calculateDisabledDates,
    toEffectiveRules,
} from "../lib/booking/manager.mjs";

/**
 * Central availability computation.
 *
 * Date type policy:
 * - Input: storeRefs.selectedDateRange is ISO[]; this composable converts to Date[]
 * - Output: `disableFnRef` for Flatpickr, `unavailableByDateRef` for calendar markers
 *
 * @param {{
 *  bookings: import('../types/bookings').RefLike<import('../types/bookings').Booking[]>,
 *  checkouts: import('../types/bookings').RefLike<import('../types/bookings').Checkout[]>,
 *  bookableItems: import('../types/bookings').RefLike<import('../types/bookings').BookableItem[]>,
 *  bookingItemId: import('../types/bookings').RefLike<string|number|null>,
 *  bookingId: import('../types/bookings').RefLike<string|number|null>,
 *  selectedDateRange: import('../types/bookings').RefLike<string[]>,
 *  circulationRules: import('../types/bookings').RefLike<import('../types/bookings').CirculationRule[]>
 * }} storeRefs
 * @param {import('../types/bookings').RefLike<import('../types/bookings').ConstraintOptions>} optionsRef
 * @returns {{ availability: import('vue').ComputedRef<import('../types/bookings').AvailabilityResult>, disableFnRef: import('vue').ComputedRef<import('../types/bookings').DisableFn>, unavailableByDateRef: import('vue').ComputedRef<import('../types/bookings').UnavailableByDate> }}
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

    const inputsReady = computed(
        () =>
            Array.isArray(bookings.value) &&
            Array.isArray(checkouts.value) &&
            Array.isArray(bookableItems.value) &&
            (bookableItems.value?.length ?? 0) > 0
    );

    const availability = computed(() => {
        if (!inputsReady.value)
            return { disable: () => true, unavailableByDate: {} };

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
