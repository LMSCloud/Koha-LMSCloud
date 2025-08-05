/**
 * Unit tests for extracted functions from bookingManager.mjs
 * Tests the helper functions that were extracted to improve code maintainability
 */

// Set up global mocks first
import dayjsLib from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";
import { expect } from "chai";

// Mock the translation function
global.$__ = str => ({
    toString: () => str,
    format: arg => str.replace("%s", arg),
});

// Mock window object with dayjs for testing
global.window = global.window || {};
dayjsLib.extend(isSameOrBefore);
dayjsLib.extend(isSameOrAfter);
global.window.dayjs = dayjsLib;

// Mock localStorage
global.localStorage = global.localStorage || {
    getItem: () => null,
    setItem: () => {},
    removeItem: () => {},
};

// Import modules after setting up mocks
let dayjs, calculateDisabledDates;

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

describe("Extracted Functions - Unit Tests", () => {
    const today = dayjsLib("2025-08-05").startOf("day");

    const baseCirculationRules = {
        issuelength: 30,
        lengthunit: "days",
        bookings_lead_period: 0,
        bookings_trail_period: 0,
        booking_constraint_mode: "end_date_only",
    };

    const bookableItems = [{ item_id: 1015017147 }];
    const emptyBookings = [];
    const emptyCheckouts = [];

    describe("validateEndDateOnlyStartDate logic", () => {
        it("should allow valid start dates in end_date_only mode (ANY_ITEM)", () => {
            const result = calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                bookableItems,
                null, // ANY_ITEM
                null,
                [], // no selected dates
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Test a valid start date (no conflicts)
            const validStartDate = today.toDate();
            const isDisabled = result.disable(validStartDate);

            expect(isDisabled).to.be.false; // Should be allowed as start date
        });

        it("should block start dates with conflicts in specific item mode", () => {
            // Create a booking that would conflict with the range
            const conflictingBooking = {
                booking_id: 999,
                item_id: 1015017147,
                start_date: today.add(15, "days").format("YYYY-MM-DD"),
                end_date: today.add(16, "days").format("YYYY-MM-DD"),
                patron_id: 123,
            };

            const result = calculateDisabledDates(
                [conflictingBooking],
                emptyCheckouts,
                bookableItems,
                1015017147, // specific item
                null,
                [], // no selected dates
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Test start date that would create a conflicting range
            const conflictingStartDate = today.toDate();
            const isDisabled = result.disable(conflictingStartDate);

            expect(isDisabled).to.be.true; // Should be blocked due to range conflict
        });

        it("should allow start dates when conflict is from booking being edited", () => {
            const editBooking = {
                booking_id: 888,
                item_id: 1015017147,
                start_date: today.add(15, "days").format("YYYY-MM-DD"),
                end_date: today.add(16, "days").format("YYYY-MM-DD"),
                patron_id: 123,
            };

            const result = calculateDisabledDates(
                [editBooking],
                emptyCheckouts,
                bookableItems,
                1015017147, // specific item
                888, // editing this booking
                [], // no selected dates
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Test start date - should be allowed because we're editing the conflicting booking
            const startDate = today.toDate();
            const isDisabled = result.disable(startDate);

            expect(isDisabled).to.be.false; // Should be allowed
        });
    });

    describe("handleEndDateOnlyIntermediateDates logic", () => {
        it("should allow the calculated end date when start date is selected", () => {
            const startDate = today.toDate();

            const result = calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                bookableItems,
                null, // ANY_ITEM
                null,
                [startDate], // start date selected
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Test the calculated end date (30 days - 1 = 29 days from start)
            const expectedEndDate = today.add(29, "days").toDate();
            const isEndDateDisabled = result.disable(expectedEndDate);

            expect(isEndDateDisabled).to.be.false; // End date should be selectable
        });

        it("should disable dates beyond the calculated range", () => {
            const startDate = today.toDate();

            const result = calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                bookableItems,
                null, // ANY_ITEM
                null,
                [startDate], // start date selected
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Test dates beyond the expected range
            const beyondRangeDate = today.add(35, "days").toDate();
            const isBeyondRangeDisabled = result.disable(beyondRangeDate);

            expect(isBeyondRangeDisabled).to.be.true; // Should be disabled
        });

        it("should allow intermediate dates for soft highlighting", () => {
            const startDate = today.toDate();

            const result = calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                bookableItems,
                null, // ANY_ITEM
                null,
                [startDate], // start date selected
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Test intermediate dates (should be allowed for soft highlighting)
            const intermediateDates = [
                today.add(1, "day").toDate(),
                today.add(10, "days").toDate(),
                today.add(20, "days").toDate(),
                today.add(28, "days").toDate(), // day before end date
            ];

            intermediateDates.forEach((date, index) => {
                const isDisabled = result.disable(date);
                expect(isDisabled).to.be.false; // Should be allowed for soft highlighting
            });
        });
    });

    describe("Edge cases and integration", () => {
        it("should handle empty bookableItems array", () => {
            const result = calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                [], // empty items array
                null, // ANY_ITEM
                null,
                [],
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Should not crash and should disable all future dates (no items available)
            const futureDate = today.add(5, "days").toDate();
            const isDisabled = result.disable(futureDate);

            expect(isDisabled).to.be.true; // Should be disabled when no items available
        });

        it("should handle invalid selected dates gracefully", () => {
            const result = calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                bookableItems,
                null,
                null,
                [new Date("invalid")], // invalid date
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Should not crash and should handle gracefully
            const testDate = today.add(5, "days").toDate();
            const isDisabled = result.disable(testDate);

            // Should continue with normal logic (not crash)
            expect(typeof isDisabled).to.equal("boolean");
        });

        it("should preserve past date blocking", () => {
            const result = calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today.format("YYYY-MM-DD")
            );

            // Past dates should always be disabled
            const pastDate = today.subtract(1, "day").toDate();
            const isDisabled = result.disable(pastDate);

            expect(isDisabled).to.be.true; // Past dates should be disabled
        });
    });
});
