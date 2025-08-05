/**
 * Multi-Item Availability Test Suite
 *
 * Refactored version using centralized TestUtils.
 * Tests "Any available item" scenarios and reproduces issues where
 * multiple items exist but dates are incorrectly disabled.
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

describe('Multi-Item Availability - "Any Available Item" Scenarios', () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("Real-world scenario reproduction", () => {
        it("should not disable dates when multiple items are available (any item mode)", () => {
            // Scenario: 2 items exist, one is booked, the other should be available
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
            ];

            const items = [
                { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
                { item_id: "item2", title: "Item 2", item_type_id: "BOOK" },
            ];

            const rules = BookingTestData.createCirculationRules();

            // Test ANY_ITEM mode (selectedItem = null)
            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Aug 12 should be available because item2 is free even though item1 is booked
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-08",
                    expected: false,
                    description: "Before any bookings - should be free",
                },
                {
                    date: "2025-08-12",
                    expected: false,
                    description: "During item1 booking, but item2 is free",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "After bookings - both items free",
                },
            ]);
        });

        it("should handle partial availability correctly", () => {
            // Scenario: 3 items, 2 are booked on different dates, 1 is always free
            const bookings = [
                BookingTestData.createBooking({
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
                BookingTestData.createBooking({
                    booking_id: 2,
                    item_id: "item2",
                    start_date: "2025-08-12",
                    end_date: "2025-08-18",
                }),
            ];

            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules();

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            // All test dates should be available because item3 is never booked
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-11",
                    expected: false,
                    description: "item1 booked, but item2 and item3 free",
                },
                {
                    date: "2025-08-14",
                    expected: false,
                    description: "item1 and item2 booked, but item3 free",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "item2 booked, but item1 and item3 free",
                },
            ]);
        });

        it("should disable dates only when ALL items are booked", () => {
            // Scenario: All items booked on the same dates
            const bookings = [
                BookingTestData.createBooking({
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
                BookingTestData.createBooking({
                    booking_id: 2,
                    item_id: "item2",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
                BookingTestData.createBooking({
                    booking_id: 3,
                    item_id: "item3",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
            ];

            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules({
                bookings_lead_period: 0,
                bookings_trail_period: 0,
            });

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Now dates should be disabled because ALL items are booked
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-08",
                    expected: false,
                    description: "Before bookings - should be free",
                },
                {
                    date: "2025-08-12",
                    expected: true,
                    description: "All items booked - should be disabled",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "After bookings - should be free",
                },
            ]);
        });

        it("should handle overlapping partial bookings", () => {
            // Complex scenario: Items booked at different overlapping times
            const bookings = [
                BookingTestData.createBooking({
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
                BookingTestData.createBooking({
                    booking_id: 2,
                    item_id: "item2",
                    start_date: "2025-08-12",
                    end_date: "2025-08-18",
                }),
                BookingTestData.createBooking({
                    booking_id: 3,
                    item_id: "item3",
                    start_date: "2025-08-16",
                    end_date: "2025-08-20",
                }),
            ];

            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules({
                bookings_lead_period: 0,
                bookings_trail_period: 0,
            });

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Test different time periods
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-09",
                    expected: false,
                    description: "Before any bookings",
                },
                {
                    date: "2025-08-11",
                    expected: false,
                    description: "item1 booked, item2 and item3 free",
                },
                {
                    date: "2025-08-14",
                    expected: false,
                    description: "item1 and item2 booked, item3 free",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "item2 and item3 booked, item1 free",
                },
                {
                    date: "2025-08-21",
                    expected: false,
                    description: "After all bookings",
                },
            ]);
        });

        it("should handle mixed item types in ANY_ITEM mode", () => {
            const bookings = [
                {
                    booking_id: 1,
                    item_id: "book_001",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                    patron_id: "patron1",
                },
                {
                    booking_id: 2,
                    item_id: "dvd_001",
                    start_date: "2025-08-12",
                    end_date: "2025-08-18",
                    patron_id: "patron2",
                },
            ];

            const items = BookingTestData.createMixedTypeItems();
            const rules = BookingTestData.createCirculationRules();

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Should have availability because other items of each type are free
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-12",
                    expected: false,
                    description:
                        "book_001 and dvd_001 booked, but other items free",
                },
                {
                    date: "2025-08-14",
                    expected: false,
                    description: "Multiple items available",
                },
            ]);
        });

        it("should handle checkouts mixed with bookings in ANY_ITEM mode", () => {
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-15",
                    end_date: "2025-08-20",
                }),
            ];

            const checkouts = [
                {
                    item_id: "item2",
                    checkout_date: "2025-08-05",
                    due_date: "2025-08-12",
                    patron_id: "patron1",
                },
            ];

            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules();

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-08",
                    expected: false,
                    description: "item2 checked out, but item1 and item3 free",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "item1 booked, but item2 and item3 free",
                },
            ]);
        });

        it("should handle performance with many items in ANY_ITEM mode", () => {
            const largeDataset = BookingTestData.createLargeDataset(50, 25);
            const rules = BookingTestData.createCirculationRules();

            BookingTestHelpers.measurePerformance(() => {
                const result = modules.calculateDisabledDates(
                    largeDataset.bookings,
                    [],
                    largeDataset.items,
                    null, // ANY_ITEM mode - most complex path
                    null,
                    [],
                    rules,
                    "2025-08-05"
                );

                expect(result.disable).to.be.a("function");
                expect(result.unavailableByDate).to.be.an("object");
            }, 200); // Should complete within 200ms even with many items
        });

        it("should handle edge case: single item in ANY_ITEM mode", () => {
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "only_item",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
            ];

            const items = [
                {
                    item_id: "only_item",
                    title: "Only Item",
                    item_type_id: "BOOK",
                },
            ];

            const rules = BookingTestData.createCirculationRules({
                bookings_lead_period: 0,
                bookings_trail_period: 0,
            });

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode with only one item
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Should behave like specific item mode when only one item exists
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-08",
                    expected: false,
                    description: "Before booking",
                },
                {
                    date: "2025-08-12",
                    expected: true,
                    description: "During booking - only item unavailable",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "After booking",
                },
            ]);
        });

        it("should handle lead/trail periods correctly in ANY_ITEM mode", () => {
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-15",
                    end_date: "2025-08-20",
                }),
            ];

            const items = BookingTestData.createItems(2);
            const rules = {
                ...BookingTestData.createCirculationRules(),
                bookings_lead_period: 2,
                bookings_trail_period: 1,
            };

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Lead/trail periods should only apply when ALL items are affected
            // Since item2 is free, lead/trail periods shouldn't block dates
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-13",
                    expected: false,
                    description: "Lead period for item1, but item2 is free",
                },
                {
                    date: "2025-08-21",
                    expected: false,
                    description: "Trail period for item1, but item2 is free",
                },
            ]);
        });

        it("should generate proper unavailableByDate in ANY_ITEM mode", () => {
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
            ];

            const items = BookingTestData.createItems(2);
            const rules = BookingTestData.createCirculationRules();

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null, // ANY_ITEM mode
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Should track unavailability per item
            expect(result.unavailableByDate["2025-08-12"]).to.exist;
            expect(result.unavailableByDate["2025-08-12"]["item1"]).to.exist;
            expect(
                result.unavailableByDate["2025-08-12"]["item1"].has("booking")
            ).to.be.true;

            // But item2 should not be marked as unavailable
            expect(result.unavailableByDate["2025-08-12"]["item2"]).to.not
                .exist;
        });
    });
});
