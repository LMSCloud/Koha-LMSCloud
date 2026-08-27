import { idsEqual } from "../../utils/functions.js";

/**
 * Resolve the OPAC's configured default pickup library.
 *
 * OPACBookingDefaultLibraryEnabled fixes every OPAC booking to one library:
 * opac-bookings.pl refuses cud-change_pickup_location while it is set, and the
 * bookings table hides the control, so the modal must not offer a different
 * one either. Returns null when the preference is off or the configured
 * library is not among the offered pickup locations, leaving the caller's own
 * defaulting in charge.
 *
 * @param {Object} options
 * @param {boolean|string|null} [options.enabled] OPACBookingDefaultLibraryEnabled.
 * @param {string|null} [options.libraryId] OPACBookingDefaultLibrary.
 * @param {Array<{library_id: string}>} [options.pickupLocations] Offered pickup locations.
 * @returns {string|null} Library to preselect, or null.
 */
export function resolveOpacDefaultPickupLibrary({
    enabled,
    libraryId,
    pickupLocations,
} = {}) {
    // The preference arrives as a template-rendered "1"/"0" as often as a boolean
    if (enabled !== true && String(enabled) !== "1") return null;
    if (!libraryId) return null;

    const locations = Array.isArray(pickupLocations) ? pickupLocations : [];
    return locations.some(location => idsEqual(location.library_id, libraryId))
        ? libraryId
        : null;
}
