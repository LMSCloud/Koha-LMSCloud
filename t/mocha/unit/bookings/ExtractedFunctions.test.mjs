/**
 * Extracted Functions Test Suite
 *
 * Refactored version using centralized TestUtils.
 * Tests the helper functions that were extracted to improve code maintainability.
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

describe("Extracted Functions - Unit Tests", () => {
    let modules;
    const today = "2025-08-05";

    const baseCirculationRules = {
        issuelength: 30,
        lengthunit: "days",
        bookings_lead_period: 0,
        bookings_trail_period: 0,
        booking_constraint_mode: "normal",
    };

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("calculateDisabledDates with extracted helper functions", () => {
        it("should work correctly with the refactored helper functions", () => {
            const bookableItems = [{ item_id: 1015017147 }];
            const emptyBookings = [];
            const emptyCheckouts = [];

            const result = modules.calculateDisabledDates(
                emptyBookings,
                emptyCheckouts,
                bookableItems,
                1015017147, // specific item
                null,
                [],
                baseCirculationRules,
                today
            );

            expect(result).to.have.property("disable");
            expect(result).to.have.property("unavailableByDate");
            expect(result.disable).to.be.a("function");
        });

        it("should handle extracted validation functions properly", () => {
            const bookings = [
                BookingTestData.createBooking({
                    item_id: 1015017147,
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
            ];
            const bookableItems = [{ item_id: 1015017147 }];

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                bookableItems,
                1015017147,
                null,
                [],
                baseCirculationRules,
                today
            );

            // Test that validation functions work correctly
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-08",
                    expected: false,
                    description: "Before booking should be available",
                },
                {
                    date: "2025-08-12",
                    expected: true,
                    description: "During booking should be blocked",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "After booking should be available",
                },
            ]);
        });

        it("should handle extracted guard clause functions", () => {
            // Test with various edge cases to ensure guard clauses work
            const testCases = [
                {
                    name: "empty bookable items",
                    bookableItems: [],
                    expectedBehavior: "should disable all dates",
                },
                {
                    name: "null specific item",
                    bookableItems: BookingTestData.createItems(2),
                    selectedItem: null,
                    expectedBehavior: "should work with any item logic",
                },
                {
                    name: "past date selection",
                    bookableItems: BookingTestData.createItems(1),
                    today: "2025-08-20", // Set today to future
                    expectedBehavior: "should disable past dates",
                },
            ];

            testCases.forEach(testCase => {
                const result = modules.calculateDisabledDates(
                    [],
                    [],
                    testCase.bookableItems,
                    testCase.selectedItem || 1015017147,
                    null,
                    [],
                    baseCirculationRules,
                    testCase.today || today
                );

                expect(result.disable).to.be.a("function");

                if (testCase.name === "empty bookable items") {
                    // Should disable dates when no items available
                    BookingTestHelpers.expectDateDisabled(
                        result.disable,
                        "2025-08-10",
                        true
                    );
                } else if (testCase.name === "past date selection") {
                    // Should disable past dates
                    BookingTestHelpers.expectDateDisabled(
                        result.disable,
                        "2025-08-10",
                        true
                    );
                }
            });
        });

        it("should handle extracted end_date_only validation functions", () => {
            const endDateOnlyRules = {
                ...baseCirculationRules,
                booking_constraint_mode: "end_date_only",
                maxPeriod: 7,
            };

            const bookableItems = BookingTestData.createItems(1);
            const selectedStartDate = new Date("2025-08-06");

            // Test with start date selected (checking potential end dates)
            const result = modules.calculateDisabledDates(
                [],
                [],
                bookableItems,
                null,
                null,
                [selectedStartDate],
                endDateOnlyRules,
                today
            );

            // Should allow valid end dates within the max period
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-07",
                    expected: false,
                    description: "Valid end date within range",
                },
                {
                    date: "2025-08-12",
                    expected: false,
                    description: "End of max period should be valid",
                },
                {
                    date: "2025-08-15",
                    expected: true,
                    description: "Beyond max period should be blocked",
                },
            ]);
        });

        it("should handle extracted constraint helper functions", () => {
            // Test constraint processing with various scenarios
            const items = BookingTestData.createItems(3);
            const pickupLocations = BookingTestData.createPickupLocations();

            // Test constrainBookableItems helper function
            const constraintResult = modules.constrainBookableItems(
                items,
                pickupLocations,
                "MAIN", // pickup location
                "BOOK", // item type
                { value: { bookableItems: false } }
            );

            expect(constraintResult).to.have.property("filtered");
            expect(constraintResult).to.have.property("total");
            expect(constraintResult.filtered).to.be.an("array");
        });

        it("should handle extracted date comparison functions", () => {
            const bookings = [
                BookingTestData.createBooking({
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
            ];

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                BookingTestData.createItems(1),
                "item1",
                null,
                [],
                baseCirculationRules,
                today
            );

            // Test that date comparison functions work across boundaries
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-09",
                    expected: false,
                    description: "Day before booking",
                },
                {
                    date: "2025-08-10",
                    expected: true,
                    description: "First day of booking",
                },
                {
                    date: "2025-08-15",
                    expected: true,
                    description: "Last day of booking",
                },
                {
                    date: "2025-08-16",
                    expected: false,
                    description: "Day after booking",
                },
            ]);
        });

        it("should handle extracted lead/trail period functions", () => {
            const rulesWithPeriods = {
                ...baseCirculationRules,
                bookings_lead_period: 2,
                bookings_trail_period: 1,
            };

            const bookings = [
                BookingTestData.createBooking({
                    item_id: "test_item",
                    start_date: "2025-08-15",
                    end_date: "2025-08-20",
                }),
            ];

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                [
                    {
                        item_id: "test_item",
                        title: "Test Item",
                        item_type_id: "BOOK",
                    },
                ],
                "test_item",
                null,
                [],
                rulesWithPeriods,
                today
            );

            // Check that lead/trail period functions create proper unavailability
            BookingTestHelpers.expectUnavailableByDate(
                result.unavailableByDate,
                "2025-08-13", // 2 days before start
                "test_item",
                "lead"
            );

            BookingTestHelpers.expectUnavailableByDate(
                result.unavailableByDate,
                "2025-08-21", // 1 day after end
                "test_item",
                "trail"
            );
        });

        it("should handle performance with extracted optimization functions", () => {
            // Test that the extracted functions maintain good performance
            const largeBookings = Array.from({ length: 50 }, (_, i) =>
                BookingTestData.createBooking({
                    booking_id: i + 1,
                    item_id: `item${i % 5}`,
                    start_date: `2025-08-${String(10 + (i % 20)).padStart(
                        2,
                        "0"
                    )}`,
                    end_date: `2025-08-${String(15 + (i % 20)).padStart(
                        2,
                        "0"
                    )}`,
                })
            );

            BookingTestHelpers.measurePerformance(() => {
                const result = modules.calculateDisabledDates(
                    largeBookings,
                    [],
                    BookingTestData.createItems(5),
                    null,
                    null,
                    [],
                    baseCirculationRules,
                    today
                );

                expect(result.disable).to.be.a("function");
                expect(result.unavailableByDate).to.be.an("object");
            }, 100); // Should complete within 100ms
        });

        it("should handle extracted error handling functions", () => {
            // Test error handling with invalid data
            const invalidBookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "invalid-date",
                    end_date: "2025-08-15",
                },
            ];

            // Should not throw errors
            expect(() => {
                modules.calculateDisabledDates(
                    invalidBookings,
                    [],
                    BookingTestData.createItems(1),
                    "item1",
                    null,
                    [],
                    baseCirculationRules,
                    today
                );
            }).to.not.throw();
        });

        it("should handle extracted utility functions for date processing", () => {
            // Test various date processing scenarios
            const scenarios = [
                {
                    name: "month boundary",
                    bookings: [
                        BookingTestData.createBooking({
                            start_date: "2025-08-30",
                            end_date: "2025-09-05",
                        }),
                    ],
                },
                {
                    name: "year boundary",
                    bookings: [
                        BookingTestData.createBooking({
                            start_date: "2025-12-30",
                            end_date: "2026-01-05",
                        }),
                    ],
                },
            ];

            scenarios.forEach(scenario => {
                const result = modules.calculateDisabledDates(
                    scenario.bookings,
                    [],
                    BookingTestData.createItems(1),
                    "item1",
                    null,
                    [],
                    baseCirculationRules,
                    today
                );

                expect(result.disable).to.be.a("function");

                // Test that boundary dates are handled correctly
                if (scenario.name === "month boundary") {
                    BookingTestHelpers.expectDateDisabled(
                        result.disable,
                        "2025-09-01",
                        true
                    );
                } else if (scenario.name === "year boundary") {
                    BookingTestHelpers.expectDateDisabled(
                        result.disable,
                        "2026-01-01",
                        true
                    );
                }
            });
        });
    });
});
