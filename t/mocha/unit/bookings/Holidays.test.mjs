/**
 * Holidays Test Suite
 *
 * Tests the closed days (holidays) functionality in the booking calendar.
 * Holidays should:
 * - Block start date selection (can't pick up when library is closed)
 * - NOT block end date selection via disable function (allows Flatpickr range validation to pass)
 * - Show holiday markers in unavailableByDate for visual feedback
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

describe("Holidays (Closed Days) functionality", () => {
    let modules;
    const today = "2025-08-05";

    const baseCirculationRules = {
        issuelength: 30,
        lengthunit: "days",
        bookings_lead_period: 0,
        bookings_trail_period: 0,
    };

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("Start date selection with holidays", () => {
        it("should disable holidays when selecting start date (no dates selected)", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-11", "2025-08-12"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [], // No dates selected - selecting start date
                baseCirculationRules,
                today,
                { holidays }
            );

            // Holidays should be disabled
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-10",
                    expected: true,
                    description: "First holiday should be disabled",
                },
                {
                    date: "2025-08-11",
                    expected: true,
                    description: "Second holiday should be disabled",
                },
                {
                    date: "2025-08-12",
                    expected: true,
                    description: "Third holiday should be disabled",
                },
            ]);

            // Non-holidays should be available
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-06",
                    expected: false,
                    description: "Day before holidays should be available",
                },
                {
                    date: "2025-08-13",
                    expected: false,
                    description: "Day after holidays should be available",
                },
            ]);
        });

        it("should handle single holiday", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-15"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-15", true);
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-14", false);
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-16", false);
        });

        it("should handle empty holidays array", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = [];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Without holidays, dates should follow normal availability rules
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-10", false);
        });

        it("should handle undefined holidays", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today,
                {} // No holidays property
            );

            // Without holidays, dates should follow normal availability rules
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-10", false);
        });
    });

    describe("End date selection with holidays", () => {
        it("should NOT disable holidays via disable function when selecting end date", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-11", "2025-08-12"];
            const selectedStartDate = new Date("2025-08-06");

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [selectedStartDate], // Start date selected - now selecting end date
                baseCirculationRules,
                today,
                { holidays }
            );

            // Holidays should NOT be disabled by the disable function when selecting end date
            // This allows Flatpickr's range validation to pass
            // Click prevention is added separately via JavaScript
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-10",
                    expected: false,
                    description: "Holiday should not be disabled by function when selecting end date",
                },
                {
                    date: "2025-08-11",
                    expected: false,
                    description: "Holiday should not be disabled by function when selecting end date",
                },
                {
                    date: "2025-08-12",
                    expected: false,
                    description: "Holiday should not be disabled by function when selecting end date",
                },
            ]);
        });

        it("should allow dates after holidays as end dates", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-11", "2025-08-12"];
            const selectedStartDate = new Date("2025-08-06");

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [selectedStartDate],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Dates after holiday range should be available
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-13",
                    expected: false,
                    description: "Day after holiday range should be available",
                },
                {
                    date: "2025-08-15",
                    expected: false,
                    description: "Several days after holidays should be available",
                },
                {
                    date: "2025-08-20",
                    expected: false,
                    description: "Week after holidays should be available",
                },
            ]);
        });
    });

    describe("Holiday markers in unavailableByDate", () => {
        it("should add holiday markers for all items", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(3);
            const holidays = ["2025-08-10"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Holiday markers should exist for all items
            expect(result.unavailableByDate["2025-08-10"]).to.exist;

            bookableItems.forEach(item => {
                const itemId = String(item.item_id);
                expect(result.unavailableByDate["2025-08-10"][itemId]).to.exist;
                expect(
                    result.unavailableByDate["2025-08-10"][itemId].has("holiday")
                ).to.be.true;
            });
        });

        it("should add holiday markers for multiple dates", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-11", "2025-08-12"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            holidays.forEach(dateStr => {
                expect(result.unavailableByDate[dateStr]).to.exist;
                expect(result.unavailableByDate[dateStr]["item1"]).to.exist;
                expect(
                    result.unavailableByDate[dateStr]["item1"].has("holiday")
                ).to.be.true;
            });
        });

        it("should include holiday markers alongside other reasons", () => {
            // Create a booking that overlaps with a holiday
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-09",
                    end_date: "2025-08-11",
                }),
            ];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Date should have both booking and holiday markers
            expect(result.unavailableByDate["2025-08-10"]).to.exist;
            expect(result.unavailableByDate["2025-08-10"]["item1"]).to.exist;
            expect(
                result.unavailableByDate["2025-08-10"]["item1"].has("holiday")
            ).to.be.true;
        });
    });

    describe("Holidays with existing bookings", () => {
        it("should handle holidays that overlap with existing bookings", () => {
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-15",
                    end_date: "2025-08-20",
                }),
            ];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-17"]; // One before, one during booking

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                "item1",
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Both holidays and booking dates should be disabled
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-10",
                    expected: true,
                    description: "Holiday before booking should be disabled",
                },
                {
                    date: "2025-08-17",
                    expected: true,
                    description: "Holiday during booking should be disabled",
                },
                {
                    date: "2025-08-16",
                    expected: true,
                    description: "Booking date should be disabled",
                },
            ]);
        });

        it("should allow selecting start dates between holidays and bookings", () => {
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-20",
                    end_date: "2025-08-25",
                }),
            ];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-11"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                "item1",
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Dates between holidays and booking should be available
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-12",
                    expected: false,
                    description: "Day after holidays, before booking",
                },
                {
                    date: "2025-08-15",
                    expected: false,
                    description: "Well after holidays, before booking",
                },
                {
                    date: "2025-08-19",
                    expected: false,
                    description: "Day before booking",
                },
            ]);
        });
    });

    describe("Holidays with checkouts", () => {
        it("should handle holidays with active checkouts", () => {
            const bookings = [];
            const checkouts = [
                {
                    item_id: "item1",
                    checkout_date: "2025-08-01",
                    due_date: "2025-08-15",
                    patron_id: "patron1",
                },
            ];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-16"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                "item1",
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Both holidays and checkout dates should be disabled
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2025-08-10",
                    expected: true,
                    description: "Holiday during checkout should be disabled",
                },
                {
                    date: "2025-08-12",
                    expected: true,
                    description: "Checkout date should be disabled",
                },
                {
                    date: "2025-08-16",
                    expected: true,
                    description: "Holiday after checkout should be disabled",
                },
                {
                    date: "2025-08-17",
                    expected: false,
                    description: "Day after checkout and holiday should be available",
                },
            ]);
        });
    });

    describe("Holidays with constraint modes", () => {
        it("should work with end_date_only constraint mode", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-15", "2025-08-16"];
            const rulesWithConstraint = {
                ...baseCirculationRules,
                booking_constraint_mode: "end_date_only",
            };

            // Selecting start date
            const resultStart = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                rulesWithConstraint,
                today,
                { holidays }
            );

            // Holidays should block start date selection
            BookingTestHelpers.expectDateDisabled(resultStart.disable, "2025-08-15", true);
            BookingTestHelpers.expectDateDisabled(resultStart.disable, "2025-08-16", true);

            // Non-holidays should be available
            BookingTestHelpers.expectDateDisabled(resultStart.disable, "2025-08-10", false);
        });

        it("should allow end date selection after holidays in end_date_only mode", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-11"];
            const selectedStartDate = new Date("2025-08-06");
            const rulesWithConstraint = {
                ...baseCirculationRules,
                booking_constraint_mode: "end_date_only",
                issuelength: 30,
            };

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [selectedStartDate],
                rulesWithConstraint,
                today,
                { holidays }
            );

            // Dates after holidays should be available (not blocked by disable function)
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-12", false);
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-15", false);
        });
    });

    describe("Any item mode with holidays", () => {
        it("should handle holidays in any item mode", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(3);
            const holidays = ["2025-08-10"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null, // Any item
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Holiday should be disabled for any item selection
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-10", true);

            // Non-holidays should be available
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-09", false);
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-11", false);
        });

        it("should block dates when all items unavailable AND it's a holiday", () => {
            // Scenario: 3 items, all booked on a date that's also a holiday
            const bookings = [
                BookingTestData.createBooking({
                    item_id: "item1",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
                BookingTestData.createBooking({
                    item_id: "item2",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
                BookingTestData.createBooking({
                    item_id: "item3",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                }),
            ];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(3);
            const holidays = ["2025-08-12"]; // During all bookings

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null, // Any item
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Should be disabled both because of holiday and because all items booked
            BookingTestHelpers.expectDateDisabled(result.disable, "2025-08-12", true);
        });
    });

    describe("Performance with holidays", () => {
        it("should handle many holidays efficiently", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(5);

            // Generate 50 holiday dates
            const holidays = Array.from({ length: 50 }, (_, i) => {
                const day = (i % 28) + 1;
                const month = Math.floor(i / 28) + 8;
                return `2025-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
            });

            BookingTestHelpers.measurePerformance(() => {
                const result = modules.calculateDisabledDates(
                    bookings,
                    checkouts,
                    bookableItems,
                    null,
                    null,
                    [],
                    baseCirculationRules,
                    today,
                    { holidays }
                );

                expect(result.disable).to.be.a("function");
                expect(result.unavailableByDate).to.be.an("object");
            }, 200); // Should complete within 200ms
        });

        it("should efficiently check holiday Set lookup", () => {
            const bookings = [];
            const checkouts = [];
            const bookableItems = BookingTestData.createItems(1);
            const holidays = ["2025-08-10", "2025-08-11", "2025-08-12"];

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                bookableItems,
                null,
                null,
                [],
                baseCirculationRules,
                today,
                { holidays }
            );

            // Call disable function many times to test O(1) lookup
            BookingTestHelpers.measurePerformance(() => {
                for (let i = 0; i < 1000; i++) {
                    result.disable(new Date("2025-08-10"));
                    result.disable(new Date("2025-08-15"));
                }
            }, 100); // 1000 lookups should complete within 100ms
        });
    });
});
