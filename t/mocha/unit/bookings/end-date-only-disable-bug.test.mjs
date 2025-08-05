/**
 * Test suite to reproduce the end_date_only bug where all dates are disabled
 * after selecting a start date, making it impossible to select the end date
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
let dayjs, calculateDisabledDates, handleBookingDateChange;

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
    handleBookingDateChange = managerModule.handleBookingDateChange;
});

describe("End date only mode - disable bug reproduction", () => {
    const today = dayjsLib("2025-08-05").startOf("day");

    const circulationRules = {
        issuelength: 30,
        lengthunit: "days",
        bookings_lead_period: 0,
        bookings_trail_period: 0,
        booking_constraint_mode: "end_date_only",
    };

    const bookableItems = [{ item_id: 1015017147 }];
    const bookings = []; // Empty bookings array
    const checkouts = []; // Empty checkouts array

    describe("When ANY_ITEM is selected (Staff Interface bug)", () => {
        const selectedItemId = null; // ANY_ITEM selection
        it("should calculate disabled dates correctly for the initial state", () => {
            // Before any date selection
            const result = calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                selectedItemId,
                null, // no edit booking
                [], // no selected dates yet
                circulationRules,
                "2025-08-05" // today
            );

            expect(result).to.have.property("disable");
            expect(result).to.have.property("unavailableByDate");
            expect(result.disable).to.be.a("function");

            // Log the result to understand the initial state
            console.log(
                "Initial state - disable function available:",
                typeof result.disable
            );
            console.log(
                "Initial state - unavailableByDate keys:",
                Object.keys(result.unavailableByDate).length
            );
        });

        it("should allow selecting the calculated end date after start date is selected", () => {
            const startDate = today.toDate();
            const expectedEndDate = today.add(29, "days"); // 30 day period minus 1

            // First, validate the date change with start date selected
            const validationResult = handleBookingDateChange(
                [startDate], // start date selected
                circulationRules,
                bookings,
                checkouts,
                bookableItems,
                selectedItemId, // null for ANY_ITEM
                null, // no edit booking
                "2025-08-05" // today
            );

            expect(validationResult.valid).to.be.true;
            console.log(
                "Validation result after start date (ANY_ITEM):",
                validationResult
            );

            // Now calculate disabled dates with start date selected
            const result = calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                selectedItemId, // null for ANY_ITEM
                null, // no edit booking
                [startDate], // start date selected
                circulationRules,
                "2025-08-05" // today
            );

            console.log(
                "After start date - disable function available:",
                typeof result.disable
            );
            console.log(
                "After start date - unavailableByDate keys:",
                Object.keys(result.unavailableByDate).length
            );

            // The bug: all dates become disabled after selecting start date in ANY_ITEM mode
            // Expected: only intermediate dates should be disabled, end date should be selectable

            // Check if end date is disabled (it shouldn't be)
            const endDateStr = expectedEndDate.format("YYYY-MM-DD");
            const isEndDateDisabled = result.disable(expectedEndDate.toDate());

            console.log("Expected end date:", endDateStr);
            console.log("Is end date disabled?", isEndDateDisabled);

            // Test a few random dates to see the pattern
            const testDates = [
                today.add(1, "day"),
                today.add(10, "days"),
                today.add(20, "days"),
                expectedEndDate,
                today.add(35, "days"),
            ];

            console.log("Random date disable test:");
            testDates.forEach(date => {
                const disabled = result.disable(date.toDate());
                console.log(
                    `  ${date.format("YYYY-MM-DD")}: ${
                        disabled ? "DISABLED" : "AVAILABLE"
                    }`
                );
            });

            // This test reproduces the Staff Interface bug with ANY_ITEM selection
            expect(isEndDateDisabled).to.be.false; // End date should NOT be disabled
        });

        it("should simulate the flatpickr disable function behavior", () => {
            const startDate = today.toDate();

            // Get disabled dates after selecting start date
            const result = calculateDisabledDates(
                [],
                [],
                bookableItems,
                selectedItemId,
                null,
                [startDate],
                circulationRules,
                "2025-08-05" // today
            );

            // Simulate checking various dates with the disable function
            const testDates = [
                today.add(1, "day"), // tomorrow
                today.add(15, "days"), // middle of range
                today.add(29, "days"), // expected end date
                today.add(30, "days"), // day after end date
            ];

            testDates.forEach(date => {
                const dateStr = date.format("YYYY-MM-DD");
                const isDisabled = result.disable(date.toDate());
                console.log(`Date ${dateStr} disabled:`, isDisabled);
            });
        });
    });

    describe("Compare Staff vs OPAC behavior", () => {
        it("should show the difference between Staff (ANY_ITEM) and OPAC (ANY_AVAILABLE)", () => {
            const startDate = today.toDate();

            // Staff Interface scenario - ANY_ITEM (selectedItemId = null)
            const staffResult = calculateDisabledDates(
                [],
                [],
                bookableItems,
                null, // ANY_ITEM
                null,
                [startDate],
                circulationRules,
                "2025-08-05" // today
            );

            // OPAC scenario - ANY_AVAILABLE (typically works)
            // Note: OPAC might have different logic or parameters
            const opacResult = calculateDisabledDates(
                [],
                [],
                bookableItems,
                "ANY_AVAILABLE", // Different from null
                null,
                [startDate],
                circulationRules,
                "2025-08-05" // today
            );

            console.log(
                "Staff (ANY_ITEM) - disable function:",
                typeof staffResult.disable
            );
            console.log(
                "Staff (ANY_ITEM) - unavailable dates:",
                Object.keys(staffResult.unavailableByDate).length
            );
            console.log(
                "OPAC (ANY_AVAILABLE) - disable function:",
                typeof opacResult.disable
            );
            console.log(
                "OPAC (ANY_AVAILABLE) - unavailable dates:",
                Object.keys(opacResult.unavailableByDate).length
            );

            // The bug manifests as Staff having all dates disabled
            // while OPAC should work correctly
        });
    });

    describe("Expected behavior in end_date_only mode", () => {
        it("should only disable intermediate dates, not the calculated end date", () => {
            const startDate = today.toDate();
            const expectedEndDate = today.add(29, "days");
            const selectedItemId = null; // ANY_ITEM for this test

            const result = calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                selectedItemId,
                null,
                [startDate],
                circulationRules,
                "2025-08-05" // today
            );

            // In end_date_only mode with start date selected:
            // - Start date (already selected) doesn't matter
            // - Intermediate dates (day 1 to day 28) should be disabled
            // - End date (day 29) should be ENABLED

            console.log(
                "Start date selected:",
                startDate.toISOString().split("T")[0]
            );
            console.log(
                "Expected end date:",
                expectedEndDate.format("YYYY-MM-DD")
            );
            console.log("Circulation rules:", circulationRules);

            let intermediateDisabledCount = 0;
            const debugDates = [];
            for (let i = 1; i < 29; i++) {
                const checkDate = today.add(i, "days");
                const isDisabled = result.disable(checkDate.toDate());
                if (isDisabled) {
                    intermediateDisabledCount++;
                }
                if (i <= 5 || i >= 25) {
                    // Log first and last few dates for debugging
                    debugDates.push({
                        date: checkDate.format("YYYY-MM-DD"),
                        disabled: isDisabled,
                    });
                }
            }

            console.log("Debug dates:", debugDates);
            console.log(
                "Intermediate dates disabled:",
                intermediateDisabledCount
            );
            console.log("Expected intermediate dates to disable:", 28);

            // UPDATED EXPECTATION: In end_date_only mode, intermediate dates are NOT hard-disabled
            // because that breaks flatpickr. Instead, they are visually highlighted and click-prevented.
            // The disable function allows them but the calendar highlighting system handles the UX.
            expect(intermediateDisabledCount).to.equal(0);

            // Verify end date is NOT disabled
            const endDateStr = expectedEndDate.format("YYYY-MM-DD");
            expect(result.disable(expectedEndDate.toDate())).to.be.false;
        });
    });
});
