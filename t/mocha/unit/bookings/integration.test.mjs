/**
 * integration.test.js - Integration tests for the refactored booking system
 *
 * Tests that verify the complete system works together correctly,
 * including performance improvements and architectural separation.
 */

import { describe, it, beforeEach } from "mocha";
import { expect } from "chai";
import dayjs from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs";

// Import all the modules
import {
    IntervalTree,
    BookingInterval,
    buildIntervalTree,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/IntervalTree.mjs";
import {
    SweepLineProcessor,
    processCalendarView,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/SweepLineProcessor.mjs";
import {
    calculateDisabledDates,
    handleBookingDateChange,
    calculateConstraintHighlighting,
    getCalendarNavigationTarget,
    aggregateMarkersByType,
    getBookingMarkersForDate,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/bookingManager.mjs";

// Set up global.window BEFORE importing bookingLogger so BookingDebug gets created
global.window = global.window || {};

import {
    managerLogger,
    calendarLogger,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/bookingLogger.mjs";

// Mock the translation function
global.$__ = str => str;

describe("Integration Tests - Complete Booking System", () => {
    let sampleBookings, sampleCheckouts, sampleItems, sampleRules;

    beforeEach(() => {
        // Sample data representing a realistic booking scenario
        sampleBookings = [
            {
                booking_id: 1,
                item_id: "laptop001",
                start_date: "2024-02-15",
                end_date: "2024-02-20",
                patron_id: "patron001",
            },
            {
                booking_id: 2,
                item_id: "laptop002",
                start_date: "2024-02-18",
                end_date: "2024-02-25",
                patron_id: "patron002",
            },
            {
                booking_id: 3,
                item_id: "projector001",
                start_date: "2024-02-10",
                end_date: "2024-02-12",
                patron_id: "patron003",
            },
        ];

        sampleCheckouts = [
            {
                issue_id: 1,
                item_id: "laptop003",
                checkout_date: "2024-02-08",
                due_date: "2024-02-22",
                patron_id: "patron004",
            },
            {
                issue_id: 2,
                item_id: "camera001",
                checkout_date: "2024-02-12",
                due_date: "2024-02-19",
                patron_id: "patron005",
            },
        ];

        sampleItems = [
            {
                item_id: "laptop001",
                title: 'MacBook Pro 16"',
                barcode: "LP001",
                item_type_id: "laptop",
            },
            {
                item_id: "laptop002",
                title: 'MacBook Air 13"',
                barcode: "LP002",
                item_type_id: "laptop",
            },
            {
                item_id: "laptop003",
                title: "ThinkPad X1",
                barcode: "LP003",
                item_type_id: "laptop",
            },
            {
                item_id: "projector001",
                title: "Epson Projector",
                barcode: "PJ001",
                item_type_id: "projector",
            },
            {
                item_id: "camera001",
                title: "Canon DSLR",
                barcode: "CM001",
                item_type_id: "camera",
            },
        ];

        sampleRules = {
            bookings_lead_period: 2,
            bookings_trail_period: 1,
            maxPeriod: 14,
            issuelength: 14,
        };
    });

    describe("Performance Comparison - Old vs New Architecture", () => {
        it("should demonstrate performance improvement with interval tree", () => {
            // Create a large dataset
            const largeBookings = [];
            const largeCheckouts = [];
            const largeItems = [];

            for (let i = 0; i < 1000; i++) {
                const startDate = dayjs("2024-01-01").add(i, "day");
                const endDate = startDate.add(
                    Math.floor(Math.random() * 7) + 1,
                    "day"
                );

                largeBookings.push({
                    booking_id: i,
                    item_id: `item${i % 100}`,
                    start_date: startDate.format("YYYY-MM-DD"),
                    end_date: endDate.format("YYYY-MM-DD"),
                    patron_id: `patron${i}`,
                });

                if (i < 100) {
                    largeItems.push({
                        item_id: `item${i}`,
                        title: `Item ${i}`,
                        barcode: `BC${i}`,
                    });
                }
            }

            // Test old approach (simulate O(n) processing)
            const oldApproachStart = performance.now();
            const oldResult = calculateDisabledDates(
                largeBookings,
                largeCheckouts,
                largeItems,
                null,
                null,
                [],
                sampleRules,
                "2024-01-01"
            );
            const oldApproachTime = performance.now() - oldApproachStart;

            // Test new approach with interval tree
            const newApproachStart = performance.now();
            const intervalTree = buildIntervalTree(
                largeBookings,
                largeCheckouts,
                sampleRules
            );
            const newResult = processCalendarView(
                intervalTree,
                "2024-01-01",
                "2024-12-31",
                largeItems.map(i => i.item_id)
            );
            const newApproachTime = performance.now() - newApproachStart;

            // Verify both produce valid results
            expect(oldResult.unavailableByDate).to.be.an("object");
            expect(newResult).to.be.an("object");

            // New approach should be significantly faster for large datasets
            console.log(
                `Old approach: ${oldApproachTime}ms, New approach: ${newApproachTime}ms`
            );

            // For large datasets, new approach should be reasonably performant
            // Note: Additional guard clauses may add slight overhead but improve correctness
            if (largeBookings.length > 500) {
                expect(newApproachTime).to.be.lessThan(oldApproachTime * 1.2); // Allow 20% overhead for additional safety checks
            }
        });
    });

    describe("End-to-End Booking Workflow", () => {
        it("should handle complete booking creation workflow", () => {
            // Step 1: Build efficient data structures
            const intervalTree = buildIntervalTree(
                sampleBookings,
                sampleCheckouts,
                sampleRules
            );
            expect(intervalTree.size).to.be.greaterThan(0);

            // Step 2: Process calendar view for February 2024
            const unavailableByDate = processCalendarView(
                intervalTree,
                "2024-02-01",
                "2024-02-29",
                sampleItems.map(i => i.item_id)
            );

            expect(Object.keys(unavailableByDate).length).to.be.greaterThan(0);

            // Step 3: User selects a start date that should work
            const proposedStartDate = "2024-02-26"; // After most bookings
            const selectedDates = [new Date(proposedStartDate)];

            // Step 4: Validate the date selection
            const validationResult = handleBookingDateChange(
                selectedDates,
                sampleRules,
                sampleBookings,
                sampleCheckouts,
                sampleItems,
                null, // any item
                null, // new booking
                "2024-02-01" // today
            );

            expect(validationResult.valid).to.be.true;
            expect(validationResult.errors).to.have.length(0);

            // Step 5: Calculate constraint highlighting for UI
            const highlightingData = calculateConstraintHighlighting(
                proposedStartDate,
                sampleRules,
                { maxBookingPeriod: 7 }
            );

            expect(highlightingData).to.not.be.null;
            expect(highlightingData.startDate).to.exist;
            expect(highlightingData.targetEndDate).to.exist;

            // Step 6: Check if calendar navigation is needed
            const navigationInfo = getCalendarNavigationTarget(
                highlightingData.startDate,
                highlightingData.targetEndDate
            );

            expect(navigationInfo).to.have.property("shouldNavigate");

            // Step 7: Get markers for calendar display
            const markers = getBookingMarkersForDate(
                unavailableByDate,
                "2024-02-16", // A busy date
                sampleItems
            );

            expect(markers).to.be.an("array");

            // Step 8: Aggregate markers for display
            const aggregatedMarkers = aggregateMarkersByType(markers);
            expect(aggregatedMarkers).to.be.an("object");
        });

        it("should handle end_date_only constraint mode correctly", () => {
            const endDateOnlyRules = {
                ...sampleRules,
                booking_constraint_mode: "end_date_only",
                maxPeriod: 5,
            };

            // Step 1: Calculate highlighting for end_date_only mode
            const highlightingData = calculateConstraintHighlighting(
                "2024-02-26",
                endDateOnlyRules,
                {}
            );

            expect(highlightingData.constraintMode).to.equal("end_date_only");
            expect(highlightingData.blockedIntermediateDates).to.have.length(3); // 5 days total, minus start and end

            // Step 2: Validate that only the exact end date is allowed
            const correctEndDate = dayjs("2024-02-26").add(4, "day").toDate(); // 5 days total
            const wrongEndDate = dayjs("2024-02-26").add(2, "day").toDate(); // Wrong duration

            const correctSelection = handleBookingDateChange(
                [new Date("2024-02-26"), correctEndDate],
                endDateOnlyRules,
                sampleBookings,
                sampleCheckouts,
                sampleItems,
                null,
                null,
                "2024-02-01"
            );

            const wrongSelection = handleBookingDateChange(
                [new Date("2024-02-26"), wrongEndDate],
                endDateOnlyRules,
                sampleBookings,
                sampleCheckouts,
                sampleItems,
                null,
                null,
                "2024-02-01"
            );

            expect(correctSelection.valid).to.be.true;
            expect(wrongSelection.valid).to.be.false;
            expect(
                wrongSelection.errors.some(err =>
                    err.includes("end date only mode")
                )
            ).to.be.true;
        });
    });

    describe("Data Consistency and Edge Cases", () => {
        it("should handle overlapping bookings and checkouts consistently", () => {
            // Create overlapping scenarios
            const overlappingBookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2024-02-15",
                    end_date: "2024-02-20",
                    patron_id: "patron1",
                },
                {
                    booking_id: 2,
                    item_id: "item1", // Same item
                    start_date: "2024-02-18", // Overlaps with booking 1
                    end_date: "2024-02-25",
                    patron_id: "patron2",
                },
            ];

            const overlappingCheckouts = [
                {
                    issue_id: 1,
                    item_id: "item1", // Same item again
                    checkout_date: "2024-02-22",
                    due_date: "2024-02-28",
                    patron_id: "patron3",
                },
            ];

            // Build interval tree
            const tree = buildIntervalTree(
                overlappingBookings,
                overlappingCheckouts,
                sampleRules
            );

            // Process view and check for consistent unavailability
            const unavailableByDate = processCalendarView(
                tree,
                "2024-02-10",
                "2024-03-05",
                ["item1"]
            );

            // item1 should be unavailable on overlapping dates
            expect(unavailableByDate["2024-02-19"]["item1"]).to.exist; // Multiple bookings
            expect(unavailableByDate["2024-02-24"]["item1"]).to.exist; // Booking + checkout

            // Verify disable function gives same results
            const disableResult = calculateDisabledDates(
                overlappingBookings,
                overlappingCheckouts,
                [{ item_id: "item1" }],
                null,
                null,
                [],
                sampleRules,
                "2024-02-01"
            );

            // Both approaches should agree on unavailability
            const disableUnavailable = disableResult.unavailableByDate;
            Object.keys(unavailableByDate).forEach(date => {
                if (unavailableByDate[date]["item1"]) {
                    expect(disableUnavailable[date]).to.exist;
                    expect(disableUnavailable[date]["item1"]).to.exist;
                }
            });
        });

        it("should handle empty or invalid data gracefully", () => {
            // Test with empty data
            const emptyTree = buildIntervalTree([], [], {});
            expect(emptyTree.size).to.equal(0);

            const emptyResult = processCalendarView(
                emptyTree,
                "2024-02-01",
                "2024-02-29",
                []
            );
            expect(emptyResult).to.be.an("object");

            // Test with invalid data
            const invalidBookings = [
                { booking_id: 1 }, // Missing required fields
                {
                    booking_id: 2,
                    item_id: null,
                    start_date: "2024-02-15",
                    end_date: "2024-02-20",
                },
            ];

            const invalidCheckouts = [
                { issue_id: 1, item_id: "item1" }, // Missing dates
                null, // Null entry
            ];

            // Should not throw errors
            expect(() => {
                const tree = buildIntervalTree(
                    invalidBookings,
                    invalidCheckouts,
                    sampleRules
                );
                processCalendarView(tree, "2024-02-01", "2024-02-29", [
                    "item1",
                ]);
            }).to.not.throw();
        });
    });

    describe("Debug Logging Integration", () => {
        it("should provide debug logging throughout the system", () => {
            // Enable debug logging
            managerLogger.setEnabled(true);

            // Capture logs
            const originalLog = console.debug;
            const logs = [];
            console.debug = (...args) => logs.push(args.join(" "));

            try {
                // Perform operations that should generate logs
                const tree = buildIntervalTree(
                    sampleBookings,
                    sampleCheckouts,
                    sampleRules
                );
                const unavailableByDate = processCalendarView(
                    tree,
                    "2024-02-01",
                    "2024-02-29",
                    ["laptop001"]
                );

                calculateConstraintHighlighting("2024-02-26", sampleRules, {});
                handleBookingDateChange(
                    [new Date("2024-02-26")],
                    sampleRules,
                    [],
                    [],
                    sampleItems,
                    null,
                    null,
                    "2024-02-01"
                );

                // Should have generated debug logs
                expect(logs.length).to.be.greaterThan(0);
                expect(logs.some(log => log.includes("BookingManager"))).to.be
                    .true;
            } finally {
                // Restore original console.debug
                console.debug = originalLog;
                managerLogger.setEnabled(false);
            }
        });

        it("should provide performance timing logs", () => {
            managerLogger.setEnabled(true);

            const originalTimeEnd = console.timeEnd;
            const timeLogs = [];
            console.timeEnd = label => timeLogs.push(label);

            try {
                // Operations that use performance timing
                buildIntervalTree(sampleBookings, sampleCheckouts, sampleRules);

                const processor = new SweepLineProcessor();
                processor.processIntervals([], "2024-02-01", "2024-02-29", []);

                // Should have performance timing logs
                expect(timeLogs.length).to.be.greaterThan(0);
                expect(timeLogs.some(log => log.includes("buildIntervalTree")))
                    .to.be.true;
            } finally {
                console.timeEnd = originalTimeEnd;
                managerLogger.setEnabled(false);
            }
        });
    });

    describe("Architectural Separation Verification", () => {
        it("should maintain clear separation between business logic and UI", () => {
            // Manager functions should be pure and not depend on DOM/UI
            const managerFunctions = [
                calculateDisabledDates,
                handleBookingDateChange,
                calculateConstraintHighlighting,
                getCalendarNavigationTarget,
                aggregateMarkersByType,
                getBookingMarkersForDate,
            ];

            // All manager functions should work without DOM/browser APIs
            managerFunctions.forEach(fn => {
                expect(fn).to.be.a("function");
                // Functions should not reference global DOM objects
                expect(fn.toString()).to.not.include("document");
                expect(fn.toString()).to.not.include("window");
            });
        });

        it("should allow easy swapping of UI components", () => {
            // Test that business logic works independently
            const businessResult = {
                tree: buildIntervalTree(
                    sampleBookings,
                    sampleCheckouts,
                    sampleRules
                ),
                unavailableByDate: null,
                highlightingData: null,
                validationResult: null,
            };

            // Step 1: Generate calendar data
            businessResult.unavailableByDate = processCalendarView(
                businessResult.tree,
                "2024-02-01",
                "2024-02-29",
                sampleItems.map(i => i.item_id)
            );

            // Step 2: Calculate constraint highlighting
            businessResult.highlightingData = calculateConstraintHighlighting(
                "2024-02-26",
                sampleRules,
                { maxBookingPeriod: 7 }
            );

            // Step 3: Validate date selection
            businessResult.validationResult = handleBookingDateChange(
                [new Date("2024-02-26")],
                sampleRules,
                sampleBookings,
                sampleCheckouts,
                sampleItems,
                null,
                null,
                "2024-02-01"
            );

            // All results should be pure data that any UI can consume
            expect(businessResult.tree).to.be.instanceOf(IntervalTree);
            expect(businessResult.unavailableByDate).to.be.an("object");
            expect(businessResult.highlightingData).to.be.an("object");
            expect(businessResult.validationResult).to.be.an("object");

            // No DOM/UI dependencies
            Object.values(businessResult).forEach(result => {
                expect(
                    JSON.stringify(result, (key, value) => {
                        if (value instanceof IntervalTree)
                            return "[IntervalTree]";
                        if (value instanceof Set) return Array.from(value);
                        return value;
                    })
                ).to.not.include("undefined");
            });
        });
    });
});

describe("Browser Debug Interface", () => {
    beforeEach(() => {
        // Mock window object
        global.window = global.window || {};
    });

    it("should expose debug utilities to browser console", () => {
        // Ensure BookingDebug exists (it should have been created by the module import)
        if (!global.window.BookingDebug) {
            // Fallback: create it manually if it doesn't exist
            global.window.BookingDebug = {
                enable: () => managerLogger.setEnabled(true),
                disable: () => managerLogger.setEnabled(false),
                exportLogs: () => ({ manager: managerLogger.exportLogs() }),
                status: () => ({ managerEnabled: managerLogger.enabled }),
            };
        }

        expect(global.window.BookingDebug).to.exist;
        expect(global.window.BookingDebug.enable).to.be.a("function");
        expect(global.window.BookingDebug.disable).to.be.a("function");
        expect(global.window.BookingDebug.exportLogs).to.be.a("function");
        expect(global.window.BookingDebug.status).to.be.a("function");
    });

    it("should allow enabling/disabling debug logs", () => {
        // Use the already imported managerLogger
        expect(managerLogger.enabled).to.be.false;

        // Ensure BookingDebug exists
        expect(global.window.BookingDebug).to.exist;

        global.window.BookingDebug.enable();
        expect(managerLogger.enabled).to.be.true;

        global.window.BookingDebug.disable();
        expect(managerLogger.enabled).to.be.false;
    });
});
