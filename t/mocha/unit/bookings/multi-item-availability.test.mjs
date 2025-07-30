/**
 * Multi-Item Availability Test - Tests "Any available item" scenarios
 * Reproduces the issue where 2 items exist but dates are incorrectly disabled
 */

// Set up global mocks first
import dayjsLib from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";
import { expect } from "chai";

// Mock the translation function that supports .format() method
global.$__ = str => ({
    toString: () => str,
    format: arg => str.replace("%s", arg),
});

// Mock window object with dayjs for testing
global.window = global.window || {};
dayjsLib.extend(isSameOrBefore);
dayjsLib.extend(isSameOrAfter);
global.window.dayjs = dayjsLib;
global.window.dayjs_plugin_isSameOrBefore = isSameOrBefore;
global.window.dayjs_plugin_isSameOrAfter = isSameOrAfter;

// Mock localStorage
global.localStorage = global.localStorage || {
    getItem: () => null,
    setItem: () => {},
    removeItem: () => {},
};

// Use dynamic imports for modules that depend on window object
let dayjs, calculateDisabledDates;

// Import modules dynamically after setting up mocks
before(async () => {
    const dayjsModule = await import(
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs"
    );
    dayjs = dayjsModule.default;

    const managerModule = await import(
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/bookingManager.mjs"
    );
    calculateDisabledDates = managerModule.calculateDisabledDates;
});

describe('Multi-Item Availability - "Any Available Item" Scenarios', () => {
    describe("Real-world scenario reproduction", () => {
        it("should allow booking when only one of two items is booked", () => {
            // Reproduce your EXACT scenario from the metadata
            const testBookings = [
                {
                    booking_id: "1",
                    item_id: "39999000006018", // Item A - FIRST booking
                    start_date: "2025-07-31",
                    end_date: "2025-08-04",
                },
                {
                    booking_id: "2",
                    item_id: "39999000006018", // Item A - SECOND booking (SAME ITEM!)
                    start_date: "2025-08-05",
                    end_date: "2025-09-27",
                },
            ];

            const testCheckouts = []; // No checkouts

            const testItems = [
                { item_id: "39999000006018", title: "Item A" },
                { item_id: "39999000006019", title: "Item B" },
            ];

            const circulationRules = {
                booking_constraint_mode: "normal", // or end_date_only
                maxPeriod: 30,
                bookings_lead_period: 0,
                bookings_trail_period: 0,
            };

            const availability = calculateDisabledDates(
                testBookings,
                testCheckouts,
                testItems,
                null, // No specific item selected - "Any available item"
                null, // No booking being edited
                [], // No selected dates yet
                circulationRules,
                "2025-07-30" // Today (before all bookings)
            );

            // Test "Any Item" mode - should be available on ALL dates since Item B is always free

            // August 1st - Item A booked, Item B free → Should be AVAILABLE
            const aug1 = new Date("2025-08-01");
            const aug1Disabled = availability.disable(aug1);
            console.log(
                `August 1st (Any Item - Item A booked, Item B free): ${
                    aug1Disabled ? "DISABLED" : "AVAILABLE"
                }`
            );
            expect(aug1Disabled).to.be.false; // Should be available

            // August 6th - Item A booked, Item B free → Should be AVAILABLE
            const aug6 = new Date("2025-08-06");
            const aug6Disabled = availability.disable(aug6);
            console.log(
                `August 6th (Any Item - Item A booked, Item B free): ${
                    aug6Disabled ? "DISABLED" : "AVAILABLE"
                }`
            );
            expect(aug6Disabled).to.be.false; // Should be available

            // Even during Item A's booking periods, Item B is available
            const jul31 = new Date("2025-07-31"); // Item A first booking period
            const sep15 = new Date("2025-09-15"); // Item A second booking period

            expect(availability.disable(jul31)).to.be.false; // Item B available
            expect(availability.disable(sep15)).to.be.false; // Item B available
        });

        it("should block dates only when ALL items are unavailable", () => {
            // Scenario where both items have overlapping bookings
            const testBookings = [
                {
                    booking_id: "1",
                    item_id: "39999000006018",
                    start_date: "2025-08-01",
                    end_date: "2025-08-10",
                },
                {
                    booking_id: "2",
                    item_id: "39999000006019",
                    start_date: "2025-08-05",
                    end_date: "2025-08-15",
                },
            ];

            const testItems = [
                { item_id: "39999000006018", title: "Item A" },
                { item_id: "39999000006019", title: "Item B" },
            ];

            const availability = calculateDisabledDates(
                testBookings,
                [],
                testItems,
                null, // Any available item
                null,
                [],
                { maxPeriod: 30 },
                "2025-07-30"
            );

            // August 2nd - Only Item A booked
            const aug2 = new Date("2025-08-02");
            expect(availability.disable(aug2)).to.be.false; // Item B available

            // August 7th - BOTH items booked (overlap period)
            const aug7 = new Date("2025-08-07");
            expect(availability.disable(aug7)).to.be.true; // All items unavailable

            // August 12th - Only Item B booked
            const aug12 = new Date("2025-08-12");
            expect(availability.disable(aug12)).to.be.false; // Item A available
        });

        it("should prevent overbooking when specific item is selected", () => {
            // Same data as above scenario
            const testBookings = [
                {
                    booking_id: "1",
                    item_id: "39999000006018",
                    start_date: "2025-07-31",
                    end_date: "2025-08-04",
                },
                {
                    booking_id: "2",
                    item_id: "39999000006018", // Same item!
                    start_date: "2025-08-05",
                    end_date: "2025-09-27",
                },
            ];

            const testItems = [
                { item_id: "39999000006018", title: "Item A" },
                { item_id: "39999000006019", title: "Item B" },
            ];

            // Test Item A specifically selected
            const availabilityItemA = calculateDisabledDates(
                testBookings,
                [],
                testItems,
                "39999000006018", // Specific item A selected
                null,
                [],
                { maxPeriod: 30 },
                "2025-07-30"
            );

            // Item A should be blocked during its booking periods
            const aug1ItemA = new Date("2025-08-01"); // During first booking
            const sep15ItemA = new Date("2025-09-15"); // During second booking

            console.log(
                `August 1st (Item A selected): ${
                    availabilityItemA.disable(aug1ItemA)
                        ? "DISABLED"
                        : "AVAILABLE"
                }`
            );
            console.log(
                `September 15th (Item A selected): ${
                    availabilityItemA.disable(sep15ItemA)
                        ? "DISABLED"
                        : "AVAILABLE"
                }`
            );

            expect(availabilityItemA.disable(aug1ItemA)).to.be.true; // Should be blocked
            expect(availabilityItemA.disable(sep15ItemA)).to.be.true; // Should be blocked

            // Test Item B specifically selected
            const availabilityItemB = calculateDisabledDates(
                testBookings,
                [],
                testItems,
                "39999000006019", // Specific item B selected
                null,
                [],
                { maxPeriod: 30 },
                "2025-07-30"
            );

            // Item B should be available on all dates (no bookings)
            const aug1ItemB = new Date("2025-08-01");
            const sep15ItemB = new Date("2025-09-15");

            console.log(
                `August 1st (Item B selected): ${
                    availabilityItemB.disable(aug1ItemB)
                        ? "DISABLED"
                        : "AVAILABLE"
                }`
            );
            console.log(
                `September 15th (Item B selected): ${
                    availabilityItemB.disable(sep15ItemB)
                        ? "DISABLED"
                        : "AVAILABLE"
                }`
            );

            expect(availabilityItemB.disable(aug1ItemB)).to.be.false; // Should be available
            expect(availabilityItemB.disable(sep15ItemB)).to.be.false; // Should be available
        });
    });

    describe("Edge cases", () => {
        it("should handle empty bookableItems array", () => {
            const availability = calculateDisabledDates(
                [],
                [],
                [], // No items available
                null,
                null,
                [],
                { maxPeriod: 30 },
                "2025-07-30"
            );

            const testDate = new Date("2025-08-01");
            // With no items, should probably block (no items to book)
            expect(availability.disable(testDate)).to.be.true;
        });

        it("should handle item ID type mismatches", () => {
            const testBookings = [
                {
                    booking_id: "1",
                    item_id: 123, // Number
                    start_date: "2025-08-01",
                    end_date: "2025-08-05",
                },
            ];

            const testItems = [
                { item_id: "123", title: "Item A" }, // String
                { item_id: "456", title: "Item B" }, // String
            ];

            const availability = calculateDisabledDates(
                testBookings,
                [],
                testItems,
                null,
                null,
                [],
                { maxPeriod: 30 },
                "2025-07-30"
            );

            const aug2 = new Date("2025-08-02");
            // Should handle type conversion correctly
            expect(availability.disable(aug2)).to.be.false; // Item B should be available
        });
    });
});
