/**
 * IntervalTree.test.js - Unit tests for IntervalTree data structure
 *
 * Tests the core functionality of the interval tree including insertion,
 * querying, and performance characteristics.
 */

// Set up global mocks first
import dayjsLib from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";
import { describe, it, beforeEach } from "mocha";
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
    clear: () => {},
};

// Use dynamic imports for modules that depend on window object
let dayjs, IntervalTree, BookingInterval, buildIntervalTree;

// Import modules dynamically after setting up mocks
before(async () => {
    const dayjsModule = await import(
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs"
    );
    dayjs = dayjsModule.default;

    const intervalTreeModule = await import(
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/IntervalTree.mjs"
    );
    IntervalTree = intervalTreeModule.IntervalTree;
    BookingInterval = intervalTreeModule.BookingInterval;
    buildIntervalTree = intervalTreeModule.buildIntervalTree;
});

describe("BookingInterval", () => {
    it("should create a valid interval with timestamps", () => {
        const start = "2024-01-15";
        const end = "2024-01-20";
        const interval = new BookingInterval(start, end, "item1", "booking", {
            id: 123,
        });

        expect(interval.start).to.equal(dayjs(start).valueOf());
        expect(interval.end).to.equal(dayjs(end).valueOf());
        expect(interval.itemId).to.equal("item1");
        expect(interval.type).to.equal("booking");
        expect(interval.metadata.id).to.equal(123);
    });

    it("should throw error for invalid intervals (start after end)", () => {
        expect(() => {
            new BookingInterval("2024-01-20", "2024-01-15", "item1", "booking");
        }).to.throw("Invalid interval");
    });

    it("should correctly check if interval contains a date", () => {
        const interval = new BookingInterval(
            "2024-01-15",
            "2024-01-20",
            "item1",
            "booking"
        );

        expect(interval.containsDate("2024-01-17")).to.be.true;
        expect(interval.containsDate("2024-01-15")).to.be.true; // start date
        expect(interval.containsDate("2024-01-20")).to.be.true; // end date
        expect(interval.containsDate("2024-01-14")).to.be.false; // before
        expect(interval.containsDate("2024-01-21")).to.be.false; // after
    });

    it("should correctly check interval overlaps", () => {
        const interval1 = new BookingInterval(
            "2024-01-15",
            "2024-01-20",
            "item1",
            "booking"
        );
        const interval2 = new BookingInterval(
            "2024-01-18",
            "2024-01-25",
            "item1",
            "booking"
        );
        const interval3 = new BookingInterval(
            "2024-01-21",
            "2024-01-25",
            "item1",
            "booking"
        );

        expect(interval1.overlaps(interval2)).to.be.true; // overlapping
        expect(interval1.overlaps(interval3)).to.be.false; // non-overlapping
    });

    it("should provide readable string representation", () => {
        const interval = new BookingInterval(
            "2024-01-15",
            "2024-01-20",
            "item1",
            "booking"
        );
        const str = interval.toString();

        expect(str).to.include("booking");
        expect(str).to.include("2024-01-15");
        expect(str).to.include("2024-01-20");
        expect(str).to.include("item1");
    });
});

describe("IntervalTree", () => {
    let tree;

    beforeEach(() => {
        tree = new IntervalTree();
    });

    describe("Basic Operations", () => {
        it("should start empty", () => {
            expect(tree.size).to.equal(0);
            expect(tree.root).to.be.null;
        });

        it("should insert a single interval", () => {
            const interval = new BookingInterval(
                "2024-01-15",
                "2024-01-20",
                "item1",
                "booking"
            );
            tree.insert(interval);

            expect(tree.size).to.equal(1);
            expect(tree.root).to.not.be.null;
            expect(tree.root.interval).to.equal(interval);
        });

        it("should insert multiple intervals and maintain balance", () => {
            const intervals = [
                new BookingInterval(
                    "2024-01-15",
                    "2024-01-20",
                    "item1",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-10",
                    "2024-01-12",
                    "item2",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-25",
                    "2024-01-30",
                    "item3",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-05",
                    "2024-01-08",
                    "item4",
                    "booking"
                ),
                new BookingInterval(
                    "2024-01-22",
                    "2024-01-24",
                    "item5",
                    "booking"
                ),
            ];

            intervals.forEach(interval => tree.insert(interval));

            expect(tree.size).to.equal(5);

            const stats = tree.getStats();
            expect(stats.balanced).to.be.true;
            expect(stats.height).to.be.lessThan(5); // Should be well-balanced
        });
    });

    describe("Point Queries", () => {
        beforeEach(() => {
            // Insert test intervals
            tree.insert(
                new BookingInterval(
                    "2024-01-15",
                    "2024-01-20",
                    "item1",
                    "booking"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-18",
                    "2024-01-25",
                    "item2",
                    "booking"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-10",
                    "2024-01-12",
                    "item3",
                    "checkout"
                )
            );
            tree.insert(
                new BookingInterval("2024-01-22", "2024-01-24", "item1", "lead")
            );
        });

        it("should find all intervals containing a specific date", () => {
            const results = tree.query("2024-01-19");

            expect(results).to.have.length(2);
            expect(results.map(r => r.itemId)).to.include.members([
                "item1",
                "item2",
            ]);
        });

        it("should return empty array for dates with no overlaps", () => {
            const results = tree.query("2024-01-05");
            expect(results).to.have.length(0);
        });

        it("should filter by item ID when specified", () => {
            const results = tree.query("2024-01-19", "item1");

            expect(results).to.have.length(1);
            expect(results[0].itemId).to.equal("item1");
            expect(results[0].type).to.equal("booking");
        });

        it("should work with different date formats", () => {
            const dateObj = new Date("2024-01-19");
            const dayjsObj = dayjs("2024-01-19");
            const timestamp = dayjs("2024-01-19").valueOf();

            expect(tree.query(dateObj)).to.have.length(2);
            expect(tree.query(dayjsObj)).to.have.length(2);
            expect(tree.query(timestamp)).to.have.length(2);
        });
    });

    describe("Range Queries", () => {
        beforeEach(() => {
            tree.insert(
                new BookingInterval(
                    "2024-01-15",
                    "2024-01-20",
                    "item1",
                    "booking"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-18",
                    "2024-01-25",
                    "item2",
                    "booking"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-10",
                    "2024-01-12",
                    "item3",
                    "checkout"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-30",
                    "2024-02-05",
                    "item4",
                    "booking"
                )
            );
        });

        it("should find all intervals overlapping with a date range", () => {
            const results = tree.queryRange("2024-01-17", "2024-01-22");

            expect(results).to.have.length(2);
            expect(results.map(r => r.itemId)).to.include.members([
                "item1",
                "item2",
            ]);
        });

        it("should include intervals that partially overlap", () => {
            const results = tree.queryRange("2024-01-11", "2024-01-16");

            expect(results).to.have.length(2);
            expect(results.map(r => r.itemId)).to.include.members([
                "item1",
                "item3",
            ]);
        });

        it("should return empty array for non-overlapping ranges", () => {
            const results = tree.queryRange("2024-01-01", "2024-01-05");
            expect(results).to.have.length(0);
        });

        it("should filter by item ID in range queries", () => {
            const results = tree.queryRange(
                "2024-01-01",
                "2024-12-31",
                "item1"
            );

            expect(results).to.have.length(1);
            expect(results[0].itemId).to.equal("item1");
        });
    });

    describe("Performance Characteristics", () => {
        it("should handle large datasets efficiently", () => {
            const startTime = performance.now();

            // Insert 1000 intervals
            for (let i = 0; i < 1000; i++) {
                const start = dayjs("2024-01-01").add(i, "day");
                const end = start.add(5, "day");
                tree.insert(
                    new BookingInterval(start, end, `item${i % 100}`, "booking")
                );
            }

            const insertTime = performance.now() - startTime;

            // Query 100 dates
            const queryStartTime = performance.now();
            for (let i = 0; i < 100; i++) {
                const queryDate = dayjs("2024-01-01").add(i * 10, "day");
                tree.query(queryDate);
            }
            const queryTime = performance.now() - queryStartTime;

            // Performance should be reasonable (adjust thresholds as needed)
            expect(insertTime).to.be.lessThan(1000); // 1 second for 1000 insertions
            expect(queryTime).to.be.lessThan(100); // 100ms for 100 queries

            const stats = tree.getStats();
            expect(stats.height).to.be.lessThan(20); // Logarithmic height
        });
    });

    describe("Tree Maintenance", () => {
        it("should maintain balance after many insertions", () => {
            // Insert intervals in sorted order (worst case for unbalanced tree)
            for (let i = 0; i < 50; i++) {
                const start = dayjs("2024-01-01").add(i, "day");
                const end = start.add(1, "day");
                tree.insert(
                    new BookingInterval(start, end, `item${i}`, "booking")
                );
            }

            const stats = tree.getStats();
            expect(stats.balanced).to.be.true;
            expect(stats.height).to.be.lessThan(10); // Should remain logarithmic
        });

        it("should clear all intervals", () => {
            tree.insert(
                new BookingInterval(
                    "2024-01-15",
                    "2024-01-20",
                    "item1",
                    "booking"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-18",
                    "2024-01-25",
                    "item2",
                    "booking"
                )
            );

            expect(tree.size).to.equal(2);

            tree.clear();

            expect(tree.size).to.equal(0);
            expect(tree.root).to.be.null;
        });

        it("should remove intervals matching a predicate", () => {
            tree.insert(
                new BookingInterval(
                    "2024-01-15",
                    "2024-01-20",
                    "item1",
                    "booking"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-18",
                    "2024-01-25",
                    "item2",
                    "booking"
                )
            );
            tree.insert(
                new BookingInterval(
                    "2024-01-10",
                    "2024-01-12",
                    "item1",
                    "checkout"
                )
            );

            const removedCount = tree.removeWhere(
                interval => interval.itemId === "item1"
            );

            expect(removedCount).to.equal(2);
            expect(tree.size).to.equal(1);

            const remaining = tree.query("2024-01-01", null);
            expect(remaining.every(r => r.itemId === "item2")).to.be.true;
        });
    });
});

describe("buildIntervalTree", () => {
    it("should build tree from bookings and checkouts", () => {
        const bookings = [
            {
                booking_id: 1,
                item_id: "item1",
                start_date: "2024-01-15",
                end_date: "2024-01-20",
                patron_id: "patron1",
            },
            {
                booking_id: 2,
                item_id: "item2",
                start_date: "2024-01-18",
                end_date: "2024-01-25",
                patron_id: "patron2",
            },
        ];

        const checkouts = [
            {
                issue_id: 1,
                item_id: "item3",
                checkout_date: "2024-01-10",
                due_date: "2024-01-17",
                patron_id: "patron3",
            },
        ];

        const circulationRules = {
            bookings_lead_period: 2,
            bookings_trail_period: 1,
        };

        const tree = buildIntervalTree(bookings, checkouts, circulationRules);

        // Should have: 2 bookings + 2 lead intervals + 2 trail intervals + 1 checkout = 7 intervals
        expect(tree.size).to.equal(7);

        // Test that all types are present
        const allIntervals = tree.queryRange("2024-01-01", "2024-01-31");
        const types = allIntervals.map(i => i.type);
        expect(types).to.include.members([
            "booking",
            "lead",
            "trail",
            "checkout",
        ]);
    });

    it("should handle empty datasets gracefully", () => {
        const tree = buildIntervalTree([], [], {});
        expect(tree.size).to.equal(0);
    });

    it("should skip invalid data", () => {
        const bookings = [
            {
                booking_id: 1,
                item_id: "item1",
                start_date: "2024-01-15",
                end_date: "2024-01-20",
            },
            {
                booking_id: 2,
                item_id: null,
                start_date: "2024-01-18",
                end_date: "2024-01-25",
            }, // Invalid
        ];

        const checkouts = [
            {
                issue_id: 1,
                item_id: "item3",
                checkout_date: "2024-01-10",
                due_date: "2024-01-17",
            },
            { issue_id: 2, item_id: "item4" }, // Invalid - missing dates
        ];

        const tree = buildIntervalTree(bookings, checkouts, {});

        // Should only include valid intervals
        expect(tree.size).to.equal(2); // 1 booking + 1 checkout
    });
});
