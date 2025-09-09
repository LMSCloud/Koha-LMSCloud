import { describe, it, before } from "mocha";
import {
    setupBookingTestEnvironment,
    getBookingModules,
    BookingTestData,
    expect,
} from "./TestUtils.mjs";

describe("Normal mode inclusive cap", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    it("caps end at start + maxPeriod", () => {
        const items = BookingTestData.createItems(1);
        const rules = {
            maxPeriod: 5,
            booking_constraint_mode: "normal",
            bookings_lead_period: 0,
            bookings_trail_period: 0,
        };

        const start = new Date("2025-01-10");
        const availability = modules.calculateDisabledDates(
            [],
            [],
            items,
            null,
            null,
            [start],
            rules,
            new Date("2025-01-09")
        );

        const within = new Date("2025-01-15"); // start + 5 (inclusive)
        const beyond = new Date("2025-01-16"); // start + 6 (beyond limit)

        expect(availability.disable(within)).to.equal(false);
        expect(availability.disable(beyond)).to.equal(true);
    });
});
