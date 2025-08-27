/**
 * Vue composable for reactive booking validation
 * Provides reactive computed properties that automatically update when store changes
 */

import { computed } from "vue";
import { storeToRefs } from "pinia";
import {
    canProceedToStep3,
    canSubmitBooking,
    validateDateSelection,
} from "../bookingValidation.mjs";

/**
 * Composable for booking validation with reactive state
 * @param {Object} store - Pinia booking store instance
 * @returns {Object} Reactive validation properties and methods
 */
export function useBookingValidation(store) {
    // Extract reactive refs from store
    const {
        bookingPatron,
        pickupLibraryId,
        bookingItemtypeId,
        itemtypeOptions,
        bookingItemId,
        bookableItems,
        selectedDateRange,
        bookings,
        checkouts,
        circulationRules,
        bookingId,
    } = storeToRefs(store);

    // Computed property for step 3 validation
    const canProceedToStep3Computed = computed(() => {
        return canProceedToStep3({
            showPatronSelect: store.showPatronSelect,
            bookingPatron: bookingPatron.value,
            showItemDetailsSelects: store.showItemDetailsSelects,
            showPickupLocationSelect: store.showPickupLocationSelect,
            pickupLibraryId: pickupLibraryId.value,
            bookingItemtypeId: bookingItemtypeId.value,
            itemtypeOptions: itemtypeOptions.value,
            bookingItemId: bookingItemId.value,
            bookableItems: bookableItems.value,
        });
    });

    // Computed property for form submission validation
    const canSubmitComputed = computed(() => {
        const validationData = {
            showPatronSelect: store.showPatronSelect,
            bookingPatron: bookingPatron.value,
            showItemDetailsSelects: store.showItemDetailsSelects,
            showPickupLocationSelect: store.showPickupLocationSelect,
            pickupLibraryId: pickupLibraryId.value,
            bookingItemtypeId: bookingItemtypeId.value,
            itemtypeOptions: itemtypeOptions.value,
            bookingItemId: bookingItemId.value,
            bookableItems: bookableItems.value,
        };
        return canSubmitBooking(validationData, selectedDateRange.value);
    });

    // Method for validating date selections
    const validateDates = selectedDates => {
        return validateDateSelection(
            selectedDates,
            circulationRules.value,
            bookings.value,
            checkouts.value,
            bookableItems.value,
            bookingItemId.value,
            bookingId.value
        );
    };

    return {
        canProceedToStep3: canProceedToStep3Computed,
        canSubmit: canSubmitComputed,
        validateDates,
    };
}
