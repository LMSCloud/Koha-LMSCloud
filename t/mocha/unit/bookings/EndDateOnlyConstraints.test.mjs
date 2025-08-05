/**
 * End Date Only Constraints Test Suite
 *
 * Refactored version using centralized TestUtils.
 * Tests the end_date_only constraint mode to ensure proper date selection behavior
 * and prevent bugs where all dates become disabled after selecting a start date.
 */

import { describe, it, before } from "mocha";
import {
    setupBookingTestEnvironment,
    getBookingModules,
    BookingTestData,
    BookingTestHelpers,
    BookingTestPatterns,
    expect,
} from "./TestUtils.mjs";

describe("End date only mode - disable bug reproduction", () => {
    let modules;
    const today = "2025-08-05";

    const circulationRules = {
        issuelength: 30,
        lengthunit: "days",
        bookings_lead_period: 0,
        bookings_trail_period: 0,
        booking_constraint_mode: "end_date_only",
    };

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    it("should not disable all dates when selecting start date in end_date_only mode", () => {
        const bookings = [];
        const checkouts = [];
        const bookableItems = BookingTestData.createItems(1);

        // Test the problematic scenario: ANY_ITEM path with end_date_only
        const result = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null, // ANY_ITEM - this triggers the problematic path
            null, // no edit booking
            [], // no selected dates yet
            circulationRules,
            today
        );

        // These dates should be available for selection as start dates
        const testDates = [
            "2025-08-06", // Tomorrow
            "2025-08-07", // Day after tomorrow
            "2025-08-08", // Further out
            "2025-08-10", // A week later
        ];

        testDates.forEach(dateStr => {
            BookingTestHelpers.expectDateDisabled(
                result.disable,
                dateStr,
                false
            );
        });
    });

    it("should allow end date selection after start date is chosen in end_date_only mode", () => {
        const bookings = [];
        const checkouts = [];
        const bookableItems = BookingTestData.createItems(1);
        const selectedStartDate = new Date("2025-08-06");

        // Simulate selecting a start date
        const result = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null, // ANY_ITEM
            null, // no edit booking
            [selectedStartDate], // start date selected
            circulationRules,
            today
        );

        // In end_date_only mode, the end date should be automatically calculated
        // but we should still be able to select other valid end dates
        const possibleEndDates = [
            "2025-08-07", // Next day
            "2025-08-10", // Few days later
            "2025-08-15", // Further out
        ];

        // Test that at least some end dates are available
        const availableEndDates = possibleEndDates.filter(
            dateStr => !result.disable(new Date(dateStr))
        );

        expect(availableEndDates.length).to.be.greaterThan(0);
    });

    it("should handle specific item selection in end_date_only mode", () => {
        const existingBookings = [
            BookingTestData.createBooking({
                item_id: "item1",
                start_date: "2025-08-10",
                end_date: "2025-08-15",
            }),
        ];
        const bookableItems = BookingTestData.createItems(2);

        // Test with specific item that has existing booking
        // In end_date_only mode, we need to select a start date to test end date availability
        const startDate = new Date("2025-08-06");
        const result = modules.calculateDisabledDates(
            existingBookings,
            [],
            bookableItems,
            "item1", // Specific item with booking
            null,
            [startDate], // Start date selected for end_date_only mode
            circulationRules,
            today
        );

        // Should block end dates that would conflict with existing booking
        BookingTestPatterns.testBasicDisableFunction(result, [
            {
                date: "2025-08-12",
                expected: true,
                description:
                    "End date during existing booking should be blocked",
            },
            {
                date: "2025-08-07",
                expected: false,
                description: "End date before booking should be available",
            },
            {
                date: "2025-08-17",
                expected: false,
                description: "End date after booking should be available",
            },
        ]);
    });

    it("should validate date ranges properly in end_date_only mode", () => {
        const bookings = [];
        const checkouts = [];
        const bookableItems = BookingTestData.createItems(1);

        // Test date range validation - in end_date_only mode, end date must equal start + issuelength
        // Period calculation is inclusive, so 7 days = start + 6 days
        const startDate = "2025-08-06";
        const calculatedEndDate = "2025-08-12"; // 2025-08-06 + 6 days = 7 day period
        const selectedDates = BookingTestHelpers.createDateRange(
            startDate,
            calculatedEndDate
        );
        const rulesWithMaxPeriod = {
            ...circulationRules,
            maxPeriod: 7,
            issuelength: 7, // This determines the calculated end date (7 day period)
        };

        const result = modules.handleBookingDateChange(
            selectedDates,
            rulesWithMaxPeriod,
            bookings,
            checkouts,
            bookableItems,
            null, // selectedItem
            null, // editBookingId
            today
        );

        // If this still fails, log the errors to understand what's wrong
        if (!result.valid) {
            console.log("Validation failed. Errors:", result.errors);
            console.log("Selected dates:", selectedDates);
            console.log("Rules:", rulesWithMaxPeriod);
        }

        expect(result.valid).to.be.true;
        expect(result.errors).to.be.empty;
    });

    it("should handle overlapping bookings correctly in end_date_only mode", () => {
        const overlappingBookings = [
            BookingTestData.createBooking({
                booking_id: 1,
                item_id: "item1",
                start_date: "2025-08-10",
                end_date: "2025-08-15",
            }),
            BookingTestData.createBooking({
                booking_id: 2,
                item_id: "item1",
                start_date: "2025-08-12",
                end_date: "2025-08-18",
            }),
        ];

        const bookableItems = [
            { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
        ];

        // In end_date_only mode, test end date availability after selecting start date
        const startDate = new Date("2025-08-06");
        const result = modules.calculateDisabledDates(
            overlappingBookings,
            [],
            bookableItems,
            "item1",
            null,
            [startDate], // Start date selected for end_date_only mode
            circulationRules,
            today
        );

        // Should block end dates that would overlap with existing bookings
        BookingTestPatterns.testBasicDisableFunction(result, [
            {
                date: "2025-08-07",
                expected: false,
                description: "End date before any booking",
            },
            {
                date: "2025-08-11",
                expected: true,
                description: "End date during first booking",
            },
            {
                date: "2025-08-14",
                expected: true,
                description: "End date during overlap",
            },
            {
                date: "2025-08-17",
                expected: true,
                description: "End date during second booking",
            },
            {
                date: "2025-08-19",
                expected: false,
                description: "End date after all bookings",
            },
        ]);
    });

    it("should respect max period constraints in end_date_only mode", () => {
        const rulesWithShortMaxPeriod = {
            ...circulationRules,
            maxPeriod: 7, // Only 7 days allowed
        };

        const bookings = [];
        const checkouts = [];
        const bookableItems = BookingTestData.createItems(1);
        const selectedStartDate = new Date("2025-08-06");

        const result = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            [selectedStartDate],
            rulesWithShortMaxPeriod,
            today
        );

        // Dates beyond max period should be disabled
        BookingTestPatterns.testBasicDisableFunction(result, [
            {
                date: "2025-08-10",
                expected: false,
                description: "Within max period",
            },
            {
                date: "2025-08-12",
                expected: false,
                description: "At max period boundary",
            },
            {
                date: "2025-08-15",
                expected: true,
                description: "Beyond max period",
            },
        ]);
    });

    it("should work with checkouts in end_date_only mode", () => {
        const bookings = [];
        const checkouts = [
            {
                item_id: "item1",
                checkout_date: "2025-08-01",
                due_date: "2025-08-10",
                patron_id: "patron1",
            },
        ];
        const bookableItems = BookingTestData.createItems(1);

        const result = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            "item1",
            null,
            [],
            circulationRules,
            today
        );

        // Should block dates during checkout period
        BookingTestPatterns.testBasicDisableFunction(result, [
            {
                date: "2025-08-08",
                expected: true,
                description: "During checkout period",
            },
            {
                date: "2025-08-11",
                expected: false,
                description: "After checkout returns",
            },
        ]);
    });

    it("should handle performance with multiple items in end_date_only mode", () => {
        const bookings = Array.from({ length: 20 }, (_, i) =>
            BookingTestData.createBooking({
                booking_id: i + 1,
                item_id: `item${(i % 5) + 1}`,
                start_date: `2025-08-${String(10 + i).padStart(2, "0")}`,
                end_date: `2025-08-${String(15 + i).padStart(2, "0")}`,
            })
        );

        const bookableItems = BookingTestData.createItems(5);

        BookingTestHelpers.measurePerformance(() => {
            const result = modules.calculateDisabledDates(
                bookings,
                [],
                bookableItems,
                null, // ANY_ITEM path
                null,
                [],
                circulationRules,
                today
            );

            expect(result.disable).to.be.a("function");
            expect(result.unavailableByDate).to.be.an("object");
        }, 150); // Should complete within 150ms
    });
});
