import { computed, watch } from "vue";
import { $__ } from "../../../i18n/index.js";

/**
 * Centralized capacity guard for booking period availability.
 * Determines whether circulation rules yield a positive booking period,
 * derives a context-aware message, and can drive a global warning + error state.
 *
 * @param {Object} options
 * @param {import('vue').Ref<Array<import('../types/bookings').CirculationRule>>} options.circulationRules
 * @param {import('vue').Ref<{ bookings: boolean; checkouts: boolean; bookableItems: boolean; circulationRules: boolean }>} options.loading
 * @param {import('vue').Ref<Array<import('../types/bookings').BookableItem>>} options.bookableItems
 * @param {import('vue').Ref<import('../types/bookings').PatronLike|null>} options.bookingPatron
 * @param {import('vue').Ref<string|number|null>} options.bookingItemId
 * @param {import('vue').Ref<string|number|null>} options.bookingItemtypeId
 * @param {boolean} options.showPatronSelect
 * @param {boolean} options.showItemDetailsSelects
 * @param {boolean} options.showPickupLocationSelect
 * @param {string|null} options.dateRangeConstraint
 * @param {(msg: string) => void} options.setError
 * @param {() => void} options.clearError
 */
export function useCapacityGuard(options) {
    const {
        circulationRules,
        loading,
        bookableItems,
        bookingPatron,
        bookingItemId,
        bookingItemtypeId,
        showPatronSelect,
        showItemDetailsSelects,
        showPickupLocationSelect,
        dateRangeConstraint,
        setError,
        clearError,
    } = options;

    const hasPositiveCapacity = computed(() => {
        const rules = circulationRules.value?.[0] || {};
        const issuelength = Number(rules.issuelength) || 0;
        const renewalperiod = Number(rules.renewalperiod) || 0;
        const renewalsallowed = Number(rules.renewalsallowed) || 0;
        const withRenewals = issuelength + renewalperiod * renewalsallowed;

        // Backend-calculated period (end_date_only mode) if present
        const calculatedDays =
            rules.calculated_period_days != null
                ? Number(rules.calculated_period_days) || 0
                : null;

        // Respect explicit constraint if provided
        if (dateRangeConstraint === "issuelength") return issuelength > 0;
        if (dateRangeConstraint === "issuelength_with_renewals")
            return withRenewals > 0;

        // Fallback logic: if backend provided a period, use it; otherwise consider both forms
        if (calculatedDays != null) return calculatedDays > 0;
        return issuelength > 0 || withRenewals > 0;
    });

    // Tailored suggestion text depending on which inputs are available
    const zeroCapacityMessage = computed(() => {
        const both = showItemDetailsSelects && showPickupLocationSelect;
        if (both) {
            return $__ (
                "No valid booking period is available with the current selection. Try a different item type or pickup location."
            );
        }
        if (showItemDetailsSelects) {
            return $__ (
                "No valid booking period is available with the current selection. Try a different item type."
            );
        }
        if (showPickupLocationSelect) {
            return $__ (
                "No valid booking period is available with the current selection. Try a different pickup location."
            );
        }
        // Inputs hidden (e.g., OPAC) — provide generic guidance
        return $__ (
            "No valid booking period is available for this record with your current settings. Please try again later or contact your library."
        );
    });

    // Compute when to show the global capacity banner
    const showCapacityWarning = computed(() => {
        const ready =
            !loading.value?.bookings &&
            !loading.value?.checkouts &&
            !loading.value?.bookableItems &&
            !loading.value?.circulationRules;
        const hasItems = (bookableItems.value?.length ?? 0) > 0;
        const validInputs =
            (!showPatronSelect || !!bookingPatron.value) &&
            (!showItemDetailsSelects ||
                !!bookingItemId.value ||
                !!bookingItemtypeId.value);
        return ready && hasItems && validInputs && !hasPositiveCapacity.value;
    });

    // Surface a helpful error when no capacity is available once data is ready
    watch(
        () => showCapacityWarning.value,
        show => {
            if (show) {
                setError(
                    $__ (
                        "No valid booking period available (circulation rules evaluate to 0)."
                    )
                );
            } else {
                clearError();
            }
        }
    );

    return { hasPositiveCapacity, zeroCapacityMessage, showCapacityWarning };
}
