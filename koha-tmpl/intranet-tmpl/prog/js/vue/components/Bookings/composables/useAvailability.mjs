import { computed } from "vue";
import dayjs from "../../../utils/dayjs.mjs";
import { calculateDisabledDates } from "../lib/booking/bookingManager.mjs";
import { deriveEffectiveRules } from "../lib/booking/bookingCalendar.mjs";

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

        const baseRules = circulationRules.value?.[0] || {};
        const effectiveRules = deriveEffectiveRules(baseRules, optionsRef.value || {});

        const selectedDatesArray = (selectedDateRange.value || [])
            .filter(Boolean)
            .map(d => dayjs(d).toDate());

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

    const disableFnRef = computed(() => availability.value.disable || (() => false));
    const unavailableByDateRef = computed(
        () => availability.value.unavailableByDate || {}
    );

    return { availability, disableFnRef, unavailableByDateRef };
}

