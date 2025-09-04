import { computed } from "vue";
import dayjs from "../../../utils/dayjs.mjs";
import { toEffectiveRules, calculateConstraintHighlighting } from "../lib/booking/manager.mjs";

/**
 * Provides reactive constraint highlighting data for the calendar based on
 * selected start date, circulation rules, and constraint options.
 */
export function useConstraintHighlighting(store, constraintOptionsRef) {
    const highlightingData = computed(() => {
        const startISO = store.selectedDateRange?.[0];
        if (!startISO) return null;
        const opts = constraintOptionsRef?.value ?? {};
        const effectiveRules = toEffectiveRules(store.circulationRules, opts);
        return calculateConstraintHighlighting(
            dayjs(startISO).toDate(),
            effectiveRules,
            opts
        );
    });

    return { highlightingData };
}
