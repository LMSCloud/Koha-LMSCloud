import { $__ } from "../../i18n/index.js";
import { createValidationErrorHandler } from "../../utils/validationErrors.js";

/**
 * Booking-specific validation error messages
 * Each key maps to a function that returns a translated message
 */
export const bookingValidationMessages = {
    biblionumber_required: () => $__("Biblionumber is required"),
    patron_id_required: () => $__("Patron ID is required"),
    booking_data_required: () => $__("Booking data is required"),
    booking_id_required: () => $__("Booking ID is required"),
    no_update_data: () => $__("No update data provided"),
    data_required: () => $__("Data is required"),
    missing_required_fields: params =>
        $__("Missing required fields: %s").format(params.fields),

    // HTTP failure messages
    fetch_bookable_items_failed: params =>
        $__("Failed to fetch bookable items: %s %s").format(
            params.status,
            params.statusText
        ),
    fetch_bookings_failed: params =>
        $__("Failed to fetch bookings: %s %s").format(
            params.status,
            params.statusText
        ),
    fetch_checkouts_failed: params =>
        $__("Failed to fetch checkouts: %s %s").format(
            params.status,
            params.statusText
        ),
    fetch_patron_failed: params =>
        $__("Failed to fetch patron: %s %s").format(
            params.status,
            params.statusText
        ),
    fetch_patrons_failed: params =>
        $__("Failed to fetch patrons: %s %s").format(
            params.status,
            params.statusText
        ),
    fetch_pickup_locations_failed: params =>
        $__("Failed to fetch pickup locations: %s %s").format(
            params.status,
            params.statusText
        ),
    fetch_circulation_rules_failed: params =>
        $__("Failed to fetch circulation rules: %s %s").format(
            params.status,
            params.statusText
        ),
    create_booking_failed: params =>
        $__("Failed to create booking: %s %s").format(
            params.status,
            params.statusText
        ),
    update_booking_failed: params =>
        $__("Failed to update booking: %s %s").format(
            params.status,
            params.statusText
        ),
};

// Create the booking validation handler
export const bookingValidation = createValidationErrorHandler(
    bookingValidationMessages
);
