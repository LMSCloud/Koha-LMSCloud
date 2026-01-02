import { computed } from "vue";
import dayjs from "../../../utils/dayjs.mjs";
import {
    toEffectiveRules,
    calculateConstraintHighlighting,
} from "../lib/booking/manager.mjs";

/**
 * Provides reactive constraint highlighting data for the calendar based on
 * selected start date, circulation rules, and constraint options.
 *
 * @param {import('../types/bookings').BookingStoreLike} store
 * @param {import('../types/bookings').RefLike<import('../types/bookings').ConstraintOptions>|undefined} constraintOptionsRef
 * @returns {{
 *   highlightingData: import('vue').ComputedRef<null | import('../types/bookings').ConstraintHighlighting>
 * }}
 */
export function useConstraintHighlighting(store, constraintOptionsRef) {
    const highlightingData = computed(() => {
        const startISO = store.selectedDateRange?.[0];
        if (!startISO) return null;
        const opts = constraintOptionsRef?.value ?? {};
        const effectiveRules = toEffectiveRules(store.circulationRules, opts);
        const baseHighlighting = calculateConstraintHighlighting(
            dayjs(startISO).toDate(),
            effectiveRules,
            opts
        );
        if (!baseHighlighting) return null;

        const holidays = store.holidays || [];
        return {
            ...baseHighlighting,
            holidays,
        };
    });

    return { highlightingData };
}
