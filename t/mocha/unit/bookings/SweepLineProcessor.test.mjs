/**
 * SweepLineProcessor.test.js - Unit tests for SweepLineProcessor
 *
 * Tests the sweep line algorithm for efficient batch processing of date ranges
 * and various utility functions for availability analysis.
 */

import { describe, it, beforeEach } from "mocha";
import { expect } from "chai";

// Mock the translation function that supports .format() method
global.$__ = str => ({
    toString: () => str,
    format: arg => str.replace("%s", arg),
});
import dayjs from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs";
import {
    SweepLineProcessor,
    processCalendarView,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/SweepLineProcessor.mjs";
import {
    IntervalTree,
    BookingInterval,
    buildIntervalTree,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/IntervalTree.mjs";

describe("SweepLineProcessor", () => {
    let processor;
    let intervals;

    beforeEach(() => {
        processor = new SweepLineProcessor();

        // Create test intervals
        intervals = [
            new BookingInterval(
                "2024-01-15",
                "2024-01-20",
                "item1",
                "booking",
                { booking_id: 1 }
            ),
            new BookingInterval(
                "2024-01-18",
                "2024-01-25",
                "item2",
                "booking",
                { booking_id: 2 }
            ),
            new BookingInterval(
                "2024-01-10",
                "2024-01-12",
                "item3",
                "checkout",
                { checkout_id: 1 }
            ),
            new BookingInterval("2024-01-22", "2024-01-24", "item1", "lead", {
                booking_id: 3,
            }),
            new BookingInterval("2024-01-26", "2024-01-28", "item2", "trail", {
                booking_id: 2,
            }),
        ];
    });

    describe("processIntervals", () => {
        it("should generate unavailability map for date range", () => {
            const viewStart = "2024-01-10";
            const viewEnd = "2024-01-30";
            const allItemIds = ["item1", "item2", "item3"];

            const result = processor.processIntervals(
                intervals,
                viewStart,
                viewEnd,
                allItemIds
            );

            // Check that we have data for the expected date range
            const dateKeys = Object.keys(result);
            expect(dateKeys.length).to.be.greaterThan(0);

            // Check specific dates
            expect(result["2024-01-15"]).to.exist;
            expect(result["2024-01-15"]["item1"]).to.exist;
            expect(result["2024-01-15"]["item1"].has("core")).to.be.true;

            expect(result["2024-01-19"]).to.exist;
            expect(result["2024-01-19"]["item1"]).to.exist;
            expect(result["2024-01-19"]["item2"]).to.exist;
        });

        it("should handle overlapping intervals correctly", () => {
            const viewStart = "2024-01-18";
            const viewEnd = "2024-01-20";
            const allItemIds = ["item1", "item2"];

            const result = processor.processIntervals(
                intervals,
                viewStart,
                viewEnd,
                allItemIds
            );

            // On 2024-01-19, both item1 and item2 should be unavailable
            expect(result["2024-01-19"]["item1"]).to.exist;
            expect(result["2024-01-19"]["item2"]).to.exist;
            expect(result["2024-01-19"]["item1"].has("core")).to.be.true;
            expect(result["2024-01-19"]["item2"].has("core")).to.be.true;
        });

        it("should map interval types to correct reasons", () => {
            const viewStart = "2024-01-10";
            const viewEnd = "2024-01-30";
            const allItemIds = ["item1", "item2", "item3"];

            const result = processor.processIntervals(
                intervals,
                viewStart,
                viewEnd,
                allItemIds
            );

            // Booking should map to 'core'
            expect(result["2024-01-15"]["item1"].has("core")).to.be.true;

            // Checkout should map to 'checkout'
            expect(result["2024-01-11"]["item3"].has("checkout")).to.be.true;

            // Lead should remain 'lead'
            expect(result["2024-01-23"]["item1"].has("lead")).to.be.true;

            // Trail should remain 'trail'
            expect(result["2024-01-27"]["item2"].has("trail")).to.be.true;
        });

        it("should handle intervals outside view range", () => {
            const futureInterval = new BookingInterval(
                "2024-02-01",
                "2024-02-05",
                "item1",
                "booking"
            );
            const pastInterval = new BookingInterval(
                "2024-01-01",
                "2024-01-05",
                "item1",
                "booking"
            );
            const testIntervals = [futureInterval, pastInterval];

            const viewStart = "2024-01-10";
            const viewEnd = "2024-01-20";
            const allItemIds = ["item1"];

            const result = processor.processIntervals(
                testIntervals,
                viewStart,
                viewEnd,
                allItemIds
            );

            // Should be empty since no intervals overlap with view range
            const dateKeys = Object.keys(result);
            const hasUnavailableDates = dateKeys.some(
                key => Object.keys(result[key]).length > 0
            );
            expect(hasUnavailableDates).to.be.false;
        });

        it("should handle empty intervals array", () => {
            const result = processor.processIntervals(
                [],
                "2024-01-10",
                "2024-01-20",
                ["item1"]
            );

            expect(result).to.be.an("object");
            const dateKeys = Object.keys(result);
            expect(dateKeys.length).to.be.greaterThan(0); // Should have date keys

            // But no unavailable items
            const hasUnavailableItems = dateKeys.some(
                key => Object.keys(result[key]).length > 0
            );
            expect(hasUnavailableItems).to.be.false;
        });
    });

    describe("getDateRangeStatistics", () => {
        it("should calculate statistics for date range", () => {
            const viewStart = "2024-01-10";
            const viewEnd = "2024-01-30";

            const stats = processor.getDateRangeStatistics(
                intervals,
                viewStart,
                viewEnd
            );

            expect(stats.totalDays).to.equal(21); // Jan 10-30 inclusive
            expect(stats.daysWithBookings).to.be.greaterThan(0);
            expect(stats.daysWithCheckouts).to.be.greaterThan(0);
            expect(stats.peakBookingCount).to.be.greaterThan(0);
            expect(stats.peakDate).to.be.a("string");
            expect(stats.itemUtilization).to.be.a("Map");
            expect(stats.itemUtilization.size).to.be.greaterThan(0);
        });

        it("should identify peak booking dates correctly", () => {
            // Create intervals with known overlap
            const testIntervals = [
                new BookingInterval(
                    "2024-01-15",
                    "2024-01-20",
                    "item1",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-18",
                    "2024-01-22",
                    "item2",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-19",
                    "2024-01-21",
                    "item3",
                    "booking"
                ), // Peak should be around Jan 19
            ];

            const stats = processor.getDateRangeStatistics(
                testIntervals,
                "2024-01-15",
                "2024-01-25"
            );

            expect(stats.peakBookingCount).to.equal(3);
            expect(stats.peakDate).to.include("2024-01-19");
        });

        it("should calculate item utilization correctly", () => {
            const stats = processor.getDateRangeStatistics(
                intervals,
                "2024-01-10",
                "2024-01-30"
            );

            // item1 appears in multiple intervals
            expect(stats.itemUtilization.get("item1")).to.be.greaterThan(0);
            expect(stats.itemUtilization.get("item2")).to.be.greaterThan(0);
            expect(stats.itemUtilization.get("item3")).to.be.greaterThan(0);
        });
    });

    describe("findNextAvailableDate", () => {
        it("should find next available date for an item", () => {
            // item1 is booked 2024-01-15 to 2024-01-20 and has lead 2024-01-22 to 2024-01-24
            const nextAvailable = processor.findNextAvailableDate(
                intervals,
                "item1",
                "2024-01-14"
            );

            expect(nextAvailable).to.not.be.null;
            expect(dayjs(nextAvailable).isBefore("2024-01-15")).to.be.true;
        });

        it("should return null if no date available within search limit", () => {
            // Create an item that's booked for a very long time
            const longBooking = new BookingInterval(
                "2024-01-01",
                "2024-12-31",
                "item1",
                "booking"
            );

            const nextAvailable = processor.findNextAvailableDate(
                [longBooking],
                "item1",
                "2024-01-01",
                10
            );

            expect(nextAvailable).to.be.null;
        });

        it("should find immediate availability if item is free", () => {
            const nextAvailable = processor.findNextAvailableDate(
                intervals,
                "item999",
                "2024-01-15"
            );

            expect(nextAvailable).to.not.be.null;
            expect(dayjs(nextAvailable).format("YYYY-MM-DD")).to.equal(
                "2024-01-15"
            );
        });
    });

    describe("findAvailableGaps", () => {
        it("should identify gaps between bookings", () => {
            // item1 has bookings with gaps between them
            const testIntervals = [
                new BookingInterval(
                    "2024-01-10",
                    "2024-01-12",
                    "item1",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-20",
                    "2024-01-25",
                    "item1",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-30",
                    "2024-02-05",
                    "item1",
                    "booking"
                ),
            ];

            const gaps = processor.findAvailableGaps(
                testIntervals,
                "item1",
                "2024-01-01",
                "2024-02-10",
                2
            );

            expect(gaps.length).to.be.greaterThan(0);

            // Should find gap between Jan 12 and Jan 20
            const gap = gaps.find(
                g =>
                    dayjs(g.start).isAfter("2024-01-12") &&
                    dayjs(g.end).isBefore("2024-01-20")
            );
            expect(gap).to.exist;
            expect(gap.days).to.be.greaterThan(2);
        });

        it("should filter gaps by minimum size", () => {
            const testIntervals = [
                new BookingInterval(
                    "2024-01-10",
                    "2024-01-11",
                    "item1",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-13",
                    "2024-01-14",
                    "item1",
                    "booking"
                ), // 1 day gap
            ];

            const smallGaps = processor.findAvailableGaps(
                testIntervals,
                "item1",
                "2024-01-01",
                "2024-01-20",
                1
            );
            const largeGaps = processor.findAvailableGaps(
                testIntervals,
                "item1",
                "2024-01-01",
                "2024-01-20",
                3
            );

            expect(smallGaps.length).to.be.greaterThan(largeGaps.length);
        });

        it("should return empty array for fully booked item", () => {
            const fullBooking = new BookingInterval(
                "2024-01-01",
                "2024-01-31",
                "item1",
                "booking"
            );

            const gaps = processor.findAvailableGaps(
                [fullBooking],
                "item1",
                "2024-01-01",
                "2024-01-31",
                1
            );

            expect(gaps).to.have.length(0);
        });
    });

    describe("Performance", () => {
        it("should process large datasets efficiently", () => {
            // Create 1000 intervals
            const largeIntervals = [];
            for (let i = 0; i < 1000; i++) {
                const start = dayjs("2024-01-01").add(i, "day");
                const end = start.add(2, "day");
                largeIntervals.push(
                    new BookingInterval(start, end, `item${i % 50}`, "booking")
                );
            }

            const startTime = performance.now();

            const result = processor.processIntervals(
                largeIntervals,
                "2024-01-01",
                "2024-12-31",
                Array.from({ length: 50 }, (_, i) => `item${i}`)
            );

            const processingTime = performance.now() - startTime;

            expect(processingTime).to.be.lessThan(1000); // Should complete within 1 second
            expect(Object.keys(result).length).to.be.greaterThan(300); // Should cover most of the year
        });
    });
});

describe("processCalendarView", () => {
    it("should integrate IntervalTree with SweepLineProcessor", () => {
        const bookings = [
            {
                booking_id: 1,
                item_id: "item1",
                start_date: "2024-01-15",
                end_date: "2024-01-20",
                patron_id: "patron1",
            },
        ];

        const checkouts = [
            {
                issue_id: 1,
                item_id: "item2",
                checkout_date: "2024-01-18",
                due_date: "2024-01-25",
                patron_id: "patron2",
            },
        ];

        const tree = buildIntervalTree(bookings, checkouts, {});
        const result = processCalendarView(tree, "2024-01-10", "2024-01-30", [
            "item1",
            "item2",
        ]);

        expect(result).to.be.an("object");
        expect(Object.keys(result).length).to.be.greaterThan(0);

        // Should have unavailability data for the booking dates
        expect(result["2024-01-17"]).to.exist;
        expect(result["2024-01-17"]["item1"]).to.exist;

        // Should have unavailability data for the checkout dates
        expect(result["2024-01-20"]).to.exist;
        expect(result["2024-01-20"]["item2"]).to.exist;
    });

    it("should handle empty tree gracefully", () => {
        const tree = new IntervalTree();
        const result = processCalendarView(tree, "2024-01-10", "2024-01-20", [
            "item1",
        ]);

        expect(result).to.be.an("object");
        const hasUnavailableItems = Object.values(result).some(
            dayData => Object.keys(dayData).length > 0
        );
        expect(hasUnavailableItems).to.be.false;
    });

    it("should efficiently query only relevant intervals", () => {
        // Create tree with intervals both inside and outside the view range
        const tree = new IntervalTree();

        // Inside view range
        tree.insert(
            new BookingInterval("2024-01-15", "2024-01-20", "item1", "booking")
        );

        // Outside view range
        tree.insert(
            new BookingInterval("2024-02-15", "2024-02-20", "item1", "booking")
        );
        tree.insert(
            new BookingInterval("2023-12-15", "2023-12-20", "item1", "booking")
        );

        const result = processCalendarView(tree, "2024-01-10", "2024-01-25", [
            "item1",
        ]);

        // Should only process the relevant interval
        expect(result["2024-01-17"]["item1"]).to.exist;

        // Should not have data from outside the range
        const allDates = Object.keys(result);
        expect(
            allDates.every(
                date =>
                    dayjs(date).isSameOrAfter("2024-01-10") &&
                    dayjs(date).isSameOrBefore("2024-01-25")
            )
        ).to.be.true;
    });
});
