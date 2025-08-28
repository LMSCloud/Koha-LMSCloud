/**
 * Integration Test Suite
 *
 * Refactored version using centralized TestUtils.
 * Integration tests that verify the complete booking system works together correctly,
 * including performance improvements and architectural separation.
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

// Import specialized modules for integration testing
import {
    IntervalTree,
    BookingInterval,
    buildIntervalTree,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/IntervalTree.mjs";
import {
    SweepLineProcessor,
    processCalendarView,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/SweepLineProcessor.mjs";

describe("Booking System Integration Tests", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("Complete System Integration", () => {
        it("should integrate IntervalTree with calculateDisabledDates", () => {
            const bookings = BookingTestData.createBookings(3);
            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules({
                bookings_lead_period: 0,
                bookings_trail_period: 0,
            });

            // Test that IntervalTree and calculateDisabledDates work together
            // Use specific item mode so booked dates are actually disabled
            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                "item1", // Specific item mode - item1 is booked 2024-01-15 to 2024-01-20
                null,
                [],
                rules,
                "2024-01-10"
            );

            expect(result.disable).to.be.a("function");
            expect(result.unavailableByDate).to.be.an("object");

            // Test specific integration points
            // Note: 2024-01-16 is within item1 booking (2024-01-15 to 2024-01-20) so should be disabled
            BookingTestPatterns.testBasicDisableFunction(result, [
                {
                    date: "2024-01-16",
                    expected: true,
                    description:
                        "Should disable dates with bookings for specific item",
                },
                {
                    date: "2024-01-10",
                    expected: false,
                    description:
                        "Should enable dates without conflicts (well before bookings)",
                },
            ]);
        });

        it("should integrate constraint functions with date calculations", () => {
            const scenario = BookingTestData.createMultiLibraryScenario();
            const rules = BookingTestData.createCirculationRules();

            // Test constraint integration
            const constrainedItems = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                "BOOK",
                { value: {} }
            );

            const result = modules.calculateDisabledDates(
                scenario.bookings,
                [],
                constrainedItems.filtered,
                null,
                null,
                [],
                rules,
                "2025-08-05"
            );

            expect(constrainedItems.filtered.length).to.be.greaterThan(0);
            expect(result.disable).to.be.a("function");
        });

        it("should integrate SweepLineProcessor with booking calculations", () => {
            const bookings = BookingTestData.createBookings(5);
            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules();

            // Build interval tree for sweep line processing
            const intervalTree = buildIntervalTree(bookings, [], rules);
            expect(intervalTree).to.be.instanceOf(IntervalTree);

            // Test sweep line integration
            const processor = new SweepLineProcessor(intervalTree);
            expect(processor).to.be.instanceOf(SweepLineProcessor);

            // Process a calendar view
            const calendarResults = processCalendarView(
                intervalTree,
                "2024-01-01",
                "2024-01-31",
                items.map(item => item.item_id)
            );

            expect(calendarResults).to.be.an("object");
        });

        it("should handle complex end-to-end booking workflow", () => {
            const scenario = BookingTestData.createComplexConstraintScenario();
            const rules = {
                ...BookingTestData.createCirculationRules(),
                booking_constraint_mode: "end_date_only",
                maxPeriod: 14,
                issuelength: 14, // Required for end_date_only mode
            };

            // Step 1: Constrain by pickup location
            const step1Result = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                null,
                { value: {} }
            );

            // Step 2: Further constrain by item type
            const step2Result = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                "BOOK",
                { value: {} }
            );

            // Step 3: Calculate disabled dates with constraints
            const dateResult = modules.calculateDisabledDates(
                scenario.bookings,
                [],
                step2Result.filtered,
                null,
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Step 4: Validate date selection - use correct end_date_only dates
            // In end_date_only mode: start + (issuelength-1) days for inclusive period
            const selectedDates = BookingTestHelpers.createDateRange(
                "2025-08-06",
                "2025-08-19"
            ); // 14 day period
            const validationResult = modules.handleBookingDateChange(
                selectedDates,
                rules,
                scenario.bookings,
                [],
                step2Result.filtered,
                null,
                null,
                "2025-08-05"
            );

            // Verify the complete workflow
            expect(step1Result.filtered.length).to.be.greaterThan(0);
            expect(step2Result.filtered.length).to.be.lessThan(
                step1Result.filtered.length
            );
            expect(dateResult.disable).to.be.a("function");
            expect(validationResult.valid).to.be.true;
        });

        it("should maintain performance across integrated components", () => {
            const largeDataset = BookingTestData.createLargeDataset(100, 30);
            const rules = BookingTestData.createCirculationRules();

            BookingTestHelpers.measurePerformance(() => {
                // Test integrated performance
                const constrainedItems = modules.constrainBookableItems(
                    largeDataset.items,
                    largeDataset.pickupLocations,
                    "BRANCH_A",
                    "BOOK",
                    { value: {} }
                );

                const dateResult = modules.calculateDisabledDates(
                    largeDataset.bookings,
                    [],
                    constrainedItems.filtered,
                    null,
                    null,
                    [],
                    rules,
                    "2025-08-05"
                );

                const markers = modules.getBookingMarkersForDate(
                    dateResult.unavailableByDate,
                    "2025-08-10",
                    constrainedItems.filtered
                );
                const aggregatedMarkers =
                    modules.aggregateMarkersByType(markers);

                expect(constrainedItems.filtered).to.be.an("array");
                expect(dateResult.disable).to.be.a("function");
                expect(markers).to.be.an("array");
                expect(aggregatedMarkers).to.be.an("object");
            }, 300); // Should complete within 300ms
        });

        it("should handle error propagation across integrated systems", () => {
            // Test that errors are handled gracefully across the system
            const invalidData = {
                bookings: [
                    {
                        booking_id: 1,
                        item_id: "item1",
                        start_date: "invalid-date",
                        end_date: "also-invalid",
                    },
                ],
                items: [],
                pickupLocations: [],
            };

            // Should not throw errors despite invalid data
            expect(() => {
                const constrainedItems = modules.constrainBookableItems(
                    invalidData.items,
                    invalidData.pickupLocations,
                    "NONEXISTENT",
                    "INVALID",
                    { value: {} }
                );

                modules.calculateDisabledDates(
                    invalidData.bookings,
                    [],
                    constrainedItems.filtered,
                    null,
                    null,
                    [],
                    BookingTestData.createCirculationRules(),
                    "2025-08-05"
                );
            }).to.not.throw();
        });

        it("should integrate calendar navigation with date calculations", () => {
            const bookings = BookingTestData.createBookings(3);
            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules();

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null,
                null,
                [],
                rules,
                "2024-01-10"
            );

            // Test calendar navigation integration
            const navigationTarget = modules.getCalendarNavigationTarget(
                "2024-01-15", // Start date
                "2024-01-20" // End date
            );

            expect(navigationTarget).to.be.an("object");
            expect(navigationTarget).to.have.property("shouldNavigate");
        });

        it("should integrate booking markers with constraint highlighting", () => {
            const scenario = BookingTestData.createLeadTrailScenario();
            const rules = {
                ...BookingTestData.createCirculationRules(),
                bookings_lead_period: 2,
                bookings_trail_period: 1,
            };

            const result = modules.calculateDisabledDates(
                scenario.bookings,
                [],
                scenario.items,
                "test_item",
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Test marker integration
            const markers = modules.getBookingMarkersForDate(
                result.unavailableByDate,
                "2025-08-13", // Lead period date
                scenario.items,
                rules,
                []
            );

            expect(markers).to.be.an("array");

            // Test constraint highlighting integration
            const highlighting = modules.calculateConstraintHighlighting(
                "2025-08-13", // Start date
                rules,
                { maxBookingPeriod: 7 }
            );

            expect(highlighting).to.be.an("object");
        });

        it("should integrate date validation with constraint processing", () => {
            const scenario = BookingTestData.createComplexConstraintScenario();
            const rules = {
                maxPeriod: 7,
                bookings_lead_period: 1,
                bookings_trail_period: 1,
            };

            // Test integrated validation
            const selectedDates = BookingTestHelpers.createDateRange(
                "2025-08-06",
                "2025-08-12"
            );

            const validationResult = modules.handleBookingDateChange(
                selectedDates,
                rules,
                scenario.bookings,
                [],
                scenario.items,
                10001, // specific item
                null,
                "2025-08-05"
            );

            expect(validationResult).to.have.property("valid");
            expect(validationResult).to.have.property("errors");

            if (!validationResult.valid) {
                expect(validationResult.errors).to.be.an("array");
            }
        });
    });

    describe("Regression Testing", () => {
        it("should prevent end_date_only bug regression", () => {
            const rules = {
                booking_constraint_mode: "end_date_only",
                maxPeriod: 7,
            };

            const result = modules.calculateDisabledDates(
                [],
                [],
                BookingTestData.createItems(1),
                null, // ANY_ITEM path
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Should not disable all dates
            const futureDates = ["2025-08-06", "2025-08-07", "2025-08-08"];

            const enabledDates = futureDates.filter(
                date => !result.disable(new Date(date))
            );

            expect(enabledDates.length).to.be.greaterThan(0);
        });

        it("should maintain constraint cascading behavior", () => {
            const scenario = BookingTestData.createMultiLibraryScenario();

            // Test that constraints cascade properly
            const step1 = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                null,
                { value: {} }
            );

            const step2 = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                "BOOK",
                { value: {} }
            );

            expect(step2.filtered.length).to.be.lessThanOrEqual(
                step1.filtered.length
            );
            expect(step2.filtered.every(item => item.item_type_id === "BOOK"))
                .to.be.true;
        });
    });
});
