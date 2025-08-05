/**
 * bookingManager.test.mjs - Unit tests for booking manager business logic
 *
 * Refactored version using centralized TestUtils for reduced duplication
 */

import { describe, it, beforeEach, before } from "mocha";
import {
    setupBookingTestEnvironment,
    getBookingModules,
    BookingTestData,
    BookingTestHelpers,
    BookingTestPatterns,
    expect,
} from "./TestUtils.mjs";

describe("calculateDisabledDates", () => {
    let modules, bookings, checkouts, bookableItems, circulationRules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    beforeEach(() => {
        bookings = BookingTestData.createBookings(2);
        checkouts = [
            {
                item_id: "item3",
                checkout_date: "2024-01-10",
                due_date: "2024-01-17",
                patron_id: "patron3",
            },
        ];
        bookableItems = BookingTestData.createItems(3);
        circulationRules = BookingTestData.createCirculationRules();
    });

    it("should generate disable function and unavailability data", () => {
        const result = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null, // selectedItem
            null, // editBookingId
            [], // selectedDates
            circulationRules,
            "2024-01-10" // today
        );

        expect(result).to.have.property("disable");
        expect(result).to.have.property("unavailableByDate");
        expect(result.disable).to.be.a("function");
        expect(result.unavailableByDate).to.be.an("object");
    });

    it("should disable dates with bookings", () => {
        const result = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            [],
            circulationRules,
            "2024-01-10"
        );

        // Test using the helper pattern
        BookingTestPatterns.testBasicDisableFunction(result, [
            {
                date: "2024-01-16",
                expected: true,
                description: "Date during first booking should be disabled",
            },
            {
                date: "2024-01-19",
                expected: true,
                description: "Date during second booking should be disabled",
            },
            {
                date: "2024-01-12",
                expected: false,
                description: "Date before bookings should be enabled",
            },
        ]);
    });

    it("should handle lead and trail periods correctly", () => {
        const result = modules.calculateDisabledDates(
            bookings,
            [],
            bookableItems,
            "item1", // specific item
            null,
            [],
            circulationRules,
            "2024-01-10"
        );

        // Check lead time (2 days before start)
        BookingTestHelpers.expectUnavailableByDate(
            result.unavailableByDate,
            "2024-01-13", // 2 days before Jan 15
            "item1",
            "lead"
        );

        // Check trail time (1 day after end)
        BookingTestHelpers.expectUnavailableByDate(
            result.unavailableByDate,
            "2024-01-21", // 1 day after Jan 20
            "item1",
            "trail"
        );
    });

    it("should exclude booking being edited", () => {
        const resultWithEdit = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            1, // editing booking_id 1
            [],
            circulationRules,
            "2024-01-10"
        );

        const resultWithoutEdit = modules.calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null, // not editing
            [],
            circulationRules,
            "2024-01-10"
        );

        // Date from first booking should be available when editing that booking
        const jan16 = new Date("2024-01-16");
        expect(resultWithEdit.disable(jan16)).to.be.false;
        expect(resultWithoutEdit.disable(jan16)).to.be.true;
    });

    it("should handle performance requirements", () => {
        const largeBookings = Array.from({ length: 100 }, (_, i) =>
            BookingTestData.createBooking({
                booking_id: i + 1,
                item_id: `item${i % 10}`,
                start_date: `2024-01-${String((i % 28) + 1).padStart(2, "0")}`,
                end_date: `2024-01-${String((i % 28) + 2).padStart(2, "0")}`,
            })
        );

        BookingTestHelpers.measurePerformance(() => {
            modules.calculateDisabledDates(
                largeBookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                circulationRules,
                "2024-01-10"
            );
        }, 200); // Should complete within 200ms
    });
});

describe("Constraint Functions", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("constrainBookableItems", () => {
        it("should filter items by pickup location", () => {
            const items = BookingTestData.createItems(3);
            const pickupLocations = BookingTestData.createPickupLocations();

            // Fixed: constrainBookableItems now properly filters by pickup location
            // Should return only items in the pickup_items array for MAIN library (item1, item3 = 2 items)

            BookingTestPatterns.testConstraintFiltering(
                modules.constrainBookableItems,
                items,
                [pickupLocations, "MAIN", null],
                2, // Correctly returns 2 items available at MAIN library
                "Should filter to items available at MAIN library"
            );
        });

        it("should handle empty constraints gracefully", () => {
            const result = modules.constrainBookableItems([], [], null, null, {
                value: {},
            });
            expect(result).to.be.an("object");
            expect(result.filtered).to.be.an("array").with.length(0);
            expect(result.total).to.equal(0);
        });
    });
});

describe("Date Handling Functions", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("handleBookingDateChange", () => {
        it("should validate successful date selection", () => {
            const selectedDates = BookingTestHelpers.createDateRange(
                "2024-01-20",
                "2024-01-25"
            );
            const circulationRules = BookingTestData.createCirculationRules({
                leadDays: 1,
                trailDays: 1,
                maxPeriod: 7,
                issuelength: 7,
            });

            const result = modules.handleBookingDateChange(
                selectedDates,
                circulationRules,
                [], // bookings
                [], // checkouts
                BookingTestData.createItems(1),
                null, // selectedItem
                null, // editBookingId
                "2024-01-19" // today
            );

            expect(result.valid).to.be.true;
            expect(result.errors).to.be.empty;
        });
    });
});
