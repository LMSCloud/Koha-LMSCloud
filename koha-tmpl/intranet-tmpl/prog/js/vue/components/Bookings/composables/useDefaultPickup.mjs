import { watch } from "vue";
import { idsEqual } from "../lib/booking/id-utils.mjs";

/**
 * Sets a sensible default pickup library when none is selected.
 * Preference order:
 * - OPAC default when enabled and valid
 * - Patron's home library if available at pickup locations
 * - First bookable item's home library if available at pickup locations
 */
export function useDefaultPickup(options) {
    const {
        bookingPickupLibraryId, // ref
        bookingPatron, // ref
        pickupLocations, // ref(Array)
        bookableItems, // ref(Array)
        opacDefaultBookingLibraryEnabled, // prop value
        opacDefaultBookingLibrary, // prop value
    } = options;

    const stop = watch(
        [() => bookingPatron.value, () => pickupLocations.value],
        ([patron, locations]) => {
            if (bookingPickupLibraryId.value) return;
            const list = Array.isArray(locations) ? locations : [];

            // 1) OPAC default override
            try {
                const enabled =
                    String(opacDefaultBookingLibraryEnabled) === "1" ||
                    opacDefaultBookingLibraryEnabled === true;
                const def = opacDefaultBookingLibrary;
                if (
                    enabled &&
                    typeof def === "string" &&
                    def &&
                    list.some(l => idsEqual(l.library_id, def))
                ) {
                    bookingPickupLibraryId.value = def;
                    return;
                }
            } catch (e) {}

            // 2) Patron library
            if (patron && list.length > 0) {
                const patronLib = patron.library_id;
                if (list.some(l => idsEqual(l.library_id, patronLib))) {
                    bookingPickupLibraryId.value = patronLib;
                    return;
                }
            }

            // 3) First item's home library
            const items = Array.isArray(bookableItems.value)
                ? bookableItems.value
                : [];
            if (items.length > 0 && list.length > 0) {
                const homeLib = items[0]?.home_library_id;
                if (list.some(l => idsEqual(l.library_id, homeLib))) {
                    bookingPickupLibraryId.value = homeLib;
                }
            }
        },
        { immediate: true }
    );

    return { stop };
}

