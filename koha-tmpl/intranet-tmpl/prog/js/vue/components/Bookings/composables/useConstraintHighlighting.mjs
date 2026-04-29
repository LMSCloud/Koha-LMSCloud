import { computed } from "vue";
import dayjs from "../../../utils/dayjs.mjs";
import {
    toEffectiveRules,
    calculateConstraintHighlighting,
    findFirstBlockingDate,
} from "../lib/booking/manager.mjs";
import { subDays } from "../lib/booking/date-utils.mjs";

/**
 * Provides reactive constraint highlighting data for the calendar based on
 * selected start date, circulation rules, and constraint options.
 *
 * Clamps the highlighting range to actual availability: if all items become
 * unavailable before the theoretical end date, highlighting stops at the last
 * available date.
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

        const hasRequiredData =
            Array.isArray(store.bookings) &&
            Array.isArray(store.checkouts) &&
            Array.isArray(store.bookableItems) &&
            store.bookableItems.length > 0;

        if (!hasRequiredData) {
            return {
                ...baseHighlighting,
                holidays,
            };
        }

        const { firstBlockingDate } = findFirstBlockingDate(
            baseHighlighting.startDate,
            baseHighlighting.targetEndDate,
            store.bookings,
            store.checkouts,
            store.bookableItems,
            store.bookingItemId,
            store.bookingId,
            effectiveRules
        );

        if (firstBlockingDate) {
            const clampedEndDate = subDays(firstBlockingDate, 1).toDate();

            if (clampedEndDate < baseHighlighting.targetEndDate) {
                const clampedBlockedDates =
                    baseHighlighting.blockedIntermediateDates.filter(
                        date => date <= clampedEndDate
                    );

                return {
                    ...baseHighlighting,
                    targetEndDate: clampedEndDate,
                    blockedIntermediateDates: clampedBlockedDates,
                    holidays,
                    _clampedDueToAvailability: true,
                };
            }
        }

        return {
            ...baseHighlighting,
            holidays,
        };
    });

    return { highlightingData };
}
