import { describe, it } from "mocha";
import { expect } from "chai";
import { resolveOpacDefaultPickupLibrary } from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/lib/booking/opac-default-pickup.js";

const LOCATIONS = [{ library_id: "MAIN" }, { library_id: "BR1" }];

describe("resolveOpacDefaultPickupLibrary", () => {
    it("returns the configured library when enabled and offered", () => {
        expect(
            resolveOpacDefaultPickupLibrary({
                enabled: true,
                libraryId: "BR1",
                pickupLocations: LOCATIONS,
            })
        ).to.equal("BR1");
    });

    it("accepts the preference as the rendered string '1'", () => {
        expect(
            resolveOpacDefaultPickupLibrary({
                enabled: "1",
                libraryId: "BR1",
                pickupLocations: LOCATIONS,
            })
        ).to.equal("BR1");
    });

    it("returns null when the preference is off", () => {
        expect(
            resolveOpacDefaultPickupLibrary({
                enabled: "0",
                libraryId: "BR1",
                pickupLocations: LOCATIONS,
            })
        ).to.equal(null);
    });

    it("returns null when the configured library is not a pickup location", () => {
        expect(
            resolveOpacDefaultPickupLibrary({
                enabled: true,
                libraryId: "BR9",
                pickupLocations: LOCATIONS,
            })
        ).to.equal(null);
    });

    it("returns null without a configured library or locations", () => {
        expect(
            resolveOpacDefaultPickupLibrary({
                enabled: true,
                libraryId: "",
                pickupLocations: LOCATIONS,
            })
        ).to.equal(null);
        expect(
            resolveOpacDefaultPickupLibrary({
                enabled: true,
                libraryId: "BR1",
            })
        ).to.equal(null);
        expect(resolveOpacDefaultPickupLibrary()).to.equal(null);
    });
});
