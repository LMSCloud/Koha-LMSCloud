import { computed } from "vue";
import { $__ } from "../../../i18n/index.js";

/**
 * Centralized capacity guard for booking period availability.
 * Determines whether circulation rules yield a positive booking period,
 * derives a context-aware message, and drives a global warning state.
 *
 * @param {Object} options
 * @param {import('vue').Ref<Array<import('../types/bookings').CirculationRule>>} options.circulationRules
 * @param {import('vue').Ref<{ bookings: boolean; checkouts: boolean; bookableItems: boolean; circulationRules: boolean }>} options.loading
 * @param {import('vue').Ref<Array<import('../types/bookings').BookableItem>>} options.bookableItems
 * @param {import('vue').Ref<import('../types/bookings').PatronLike|null>} options.bookingPatron
 * @param {import('vue').Ref<string|number|null>} options.bookingItemId
 * @param {import('vue').Ref<string|number|null>} options.bookingItemtypeId
 * @param {import('vue').Ref<string|null>} options.pickupLibraryId
 * @param {boolean} options.showPatronSelect
 * @param {boolean} options.showItemDetailsSelects
 * @param {boolean} options.showPickupLocationSelect
 * @param {string|null} options.dateRangeConstraint
 */
export function useCapacityGuard(options) {
    const {
        circulationRules,
        loading,
        bookableItems,
        bookingPatron,
        bookingItemId,
        bookingItemtypeId,
        pickupLibraryId,
        showPatronSelect,
        showItemDetailsSelects,
        showPickupLocationSelect,
        dateRangeConstraint,
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

    // Tailored error message based on rule values and available inputs
    const zeroCapacityMessage = computed(() => {
        const rules = circulationRules.value?.[0] || {};
        const issuelength = rules.issuelength;
        const hasExplicitZero = issuelength === "0" || issuelength === 0;
        const hasNull = issuelength === null || issuelength === undefined;

        // If rule explicitly set to zero, it's a circulation policy issue
        if (hasExplicitZero) {
            if (showPatronSelect && showItemDetailsSelects && showPickupLocationSelect) {
                return $__(
                    "Bookings are not permitted for this combination of patron category, item type, and pickup location. The circulation rules set the booking period to zero days."
                );
            }
            if (showItemDetailsSelects && showPickupLocationSelect) {
                return $__(
                    "Bookings are not permitted for this item type at the selected pickup location. The circulation rules set the booking period to zero days."
                );
            }
            if (showItemDetailsSelects) {
                return $__(
                    "Bookings are not permitted for this item type. The circulation rules set the booking period to zero days."
                );
            }
            return $__(
                "Bookings are not permitted for this item. The circulation rules set the booking period to zero days."
            );
        }

        // If null, no specific rule exists - suggest trying different options
        if (hasNull) {
            const suggestions = [];
            if (showItemDetailsSelects) suggestions.push($__("item type"));
            if (showPickupLocationSelect) suggestions.push($__("pickup location"));
            if (showPatronSelect) suggestions.push($__("patron"));

            if (suggestions.length > 0) {
                const suggestionText = suggestions.join($__(" or "));
                return $__(
                    "No circulation rule is defined for this combination. Try a different %s."
                ).replace("%s", suggestionText);
            }
        }

        // Fallback for other edge cases
        const both = showItemDetailsSelects && showPickupLocationSelect;
        if (both) {
            return $__(
                "No valid booking period is available with the current selection. Try a different item type or pickup location."
            );
        }
        if (showItemDetailsSelects) {
            return $__(
                "No valid booking period is available with the current selection. Try a different item type."
            );
        }
        if (showPickupLocationSelect) {
            return $__(
                "No valid booking period is available with the current selection. Try a different pickup location."
            );
        }
        return $__(
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
        const hasRules = (circulationRules.value?.length ?? 0) > 0;

        // Only show warning when we have complete context for circulation rules.
        // Partial context (e.g., just item_type without patron or library) can
        // return null/zero values that are false positives.
        const hasCompleteContext =
            (!showPatronSelect || !!bookingPatron.value) &&
            (!showItemDetailsSelects || !!bookingItemId.value || !!bookingItemtypeId.value) &&
            (!showPickupLocationSelect || !!pickupLibraryId.value);

        return ready && hasItems && hasRules && hasCompleteContext && !hasPositiveCapacity.value;
    });

    return { hasPositiveCapacity, zeroCapacityMessage, showCapacityWarning };
}
