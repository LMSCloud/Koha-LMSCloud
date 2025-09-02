import { describe, it } from "mocha";
import { expect } from "chai";
import { ref } from "vue";
import { useDefaultPickup } from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/composables/useDefaultPickup.mjs";

function delay(ms = 0) {
    return new Promise(res => setTimeout(res, ms));
}

describe("useDefaultPickup composable", () => {
    it("prefers OPAC default when enabled and present", async () => {
        const bookingPickupLibraryId = ref(null);
        const bookingPatron = ref(null);
        const pickupLocations = ref([{ library_id: "MAIN" }, { library_id: "BR1" }]);
        const bookableItems = ref([]);

        useDefaultPickup({
            bookingPickupLibraryId,
            bookingPatron,
            pickupLocations,
            bookableItems,
            opacDefaultBookingLibraryEnabled: true,
            opacDefaultBookingLibrary: "BR1",
        });
        await delay(0);
        expect(bookingPickupLibraryId.value).to.equal("BR1");
    });

    it("falls back to patron library if available", async () => {
        const bookingPickupLibraryId = ref(null);
        const bookingPatron = ref({ library_id: "MAIN" });
        const pickupLocations = ref([{ library_id: "MAIN" }]);
        const bookableItems = ref([]);

        useDefaultPickup({
            bookingPickupLibraryId,
            bookingPatron,
            pickupLocations,
            bookableItems,
            opacDefaultBookingLibraryEnabled: false,
            opacDefaultBookingLibrary: null,
        });
        await delay(0);
        expect(bookingPickupLibraryId.value).to.equal("MAIN");
    });

    it("falls back to first item's home library when applicable", async () => {
        const bookingPickupLibraryId = ref(null);
        const bookingPatron = ref(null);
        const pickupLocations = ref([{ library_id: "MAIN" }]);
        const bookableItems = ref([{ home_library_id: "MAIN" }]);

        useDefaultPickup({
            bookingPickupLibraryId,
            bookingPatron,
            pickupLocations,
            bookableItems,
            opacDefaultBookingLibraryEnabled: false,
            opacDefaultBookingLibrary: null,
        });
        await delay(0);
        expect(bookingPickupLibraryId.value).to.equal("MAIN");
    });
});
