/**
 * Pure functions for booking validation logic
 * Extracted from BookingValidationService to eliminate store coupling
 */

import { handleBookingDateChange } from "./manager.mjs";

/**
 * Validate if user can proceed to step 3 (period selection)
 * @param {Object} validationData - All required data for validation
 * @param {boolean} validationData.showPatronSelect - Whether patron selection is required
 * @param {Object} validationData.bookingPatron - Selected booking patron
 * @param {boolean} validationData.showItemDetailsSelects - Whether item details are required
 * @param {boolean} validationData.showPickupLocationSelect - Whether pickup location is required
 * @param {string} validationData.pickupLibraryId - Selected pickup library ID
 * @param {string} validationData.bookingItemtypeId - Selected item type ID
 * @param {Array} validationData.itemtypeOptions - Available item type options
 * @param {string} validationData.bookingItemId - Selected item ID
 * @param {Array} validationData.bookableItems - Available bookable items
 * @returns {boolean} Whether the user can proceed to step 3
 */
export function canProceedToStep3(validationData) {
    const {
        showPatronSelect,
        bookingPatron,
        showItemDetailsSelects,
        showPickupLocationSelect,
        pickupLibraryId,
        bookingItemtypeId,
        itemtypeOptions,
        bookingItemId,
        bookableItems,
    } = validationData;

    // Step 1: Patron validation (if required)
    if (showPatronSelect && !bookingPatron) {
        return false;
    }

    // Step 2: Item details validation
    if (showItemDetailsSelects || showPickupLocationSelect) {
        if (showPickupLocationSelect && !pickupLibraryId) {
            return false;
        }
        if (showItemDetailsSelects) {
            if (!bookingItemtypeId && itemtypeOptions.length > 0) {
                return false;
            }
            if (!bookingItemId && bookableItems.length > 0) {
                return false;
            }
        }
    }

    // Additional validation: Check if there are any bookable items available
    if (!bookableItems || bookableItems.length === 0) {
        return false;
    }

    return true;
}

/**
 * Validate if form can be submitted
 * @param {Object} validationData - Data required for step 3 validation
 * @param {Array} dateRange - Selected date range
 * @returns {boolean} Whether the form can be submitted
 */
export function canSubmitBooking(validationData, dateRange) {
    if (!canProceedToStep3(validationData)) return false;
    if (!dateRange || dateRange.length === 0) return false;

    // For range mode, need both start and end dates
    if (Array.isArray(dateRange) && dateRange.length < 2) {
        return false;
    }

    return true;
}

/**
 * Validate date selection and return detailed result
 * @param {Array} selectedDates - Selected dates from calendar
 * @param {Array} circulationRules - Circulation rules for validation
 * @param {Array} bookings - Existing bookings data
 * @param {Array} checkouts - Existing checkouts data
 * @param {Array} bookableItems - Available bookable items
 * @param {string} bookingItemId - Selected item ID
 * @param {string} bookingId - Current booking ID (for updates)
 * @returns {Object} Validation result with dates and conflicts
 */
export function validateDateSelection(
    selectedDates,
    circulationRules,
    bookings,
    checkouts,
    bookableItems,
    bookingItemId,
    bookingId
) {
    return handleBookingDateChange(
        selectedDates,
        circulationRules,
        bookings,
        checkouts,
        bookableItems,
        bookingItemId,
        bookingId
    );
}
