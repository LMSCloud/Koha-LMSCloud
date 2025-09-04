/**
 * IntervalTree Query Debug Tests
 * Replicates the exact OPAC scenario to debug why queries aren't finding conflicts
 */

// Set up global mocks first
import dayjsLib from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";
import { expect } from "chai";

// Mock the translation function
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
let dayjs, calculateDisabledDates, buildIntervalTree, IntervalTree;

// Import modules dynamically after setting up mocks
before(async () => {
    const dayjsModule = await import(
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs"
    );
    dayjs = dayjsModule.default;

    const managerModule = await import(
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/manager.mjs"
    );
    calculateDisabledDates = managerModule.calculateDisabledDates;

    const intervalTreeModule = await import(
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/algorithms/interval-tree.mjs"
    );
    buildIntervalTree = intervalTreeModule.buildIntervalTree;
    IntervalTree = intervalTreeModule.IntervalTree;
});

describe("IntervalTree Query Debug - OPAC Scenario Replication", () => {
    describe("Exact OPAC Data Replication", () => {
        const opacBookings = [
            {
                booking_id: 1,
                item_id: 308,
                start_date: "2025-07-31T22:00:00+00:00", // Exact OPAC format
                end_date: "2025-08-04T22:00:00+00:00",
                patron_id: 19,
            },
            {
                booking_id: 5,
                item_id: 308,
                start_date: "2025-08-05T22:00:00+00:00", // Exact OPAC format
                end_date: "2025-09-27T22:00:00+00:00",
                patron_id: 51,
            },
        ];

        const opacItems = [
            { item_id: 307, title: undefined, item_type_id: "BK" },
            { item_id: 308, title: undefined, item_type_id: "BK" },
        ];

        const opacRules = {
            booking_constraint_mode: "end_date_only",
            maxPeriod: 54,
            bookings_lead_period: null,
            bookings_trail_period: null,
        };

        it("should build IntervalTree correctly with OPAC data", () => {
            const tree = buildIntervalTree(opacBookings, [], opacRules);

            console.log("Tree built with stats:", tree.getStats());
            console.log("Tree size:", tree.size);

            expect(tree.size).to.be.greaterThan(0);

            // Test basic point queries
            const aug1 = dayjs("2025-08-01").valueOf();
            const aug9 = dayjs("2025-08-09").valueOf();
            const sep15 = dayjs("2025-09-15").valueOf();

            console.log(
                "Point query Aug 1 (item 308):",
                tree.query(aug1, "308")
            );
            console.log(
                "Point query Aug 9 (item 308):",
                tree.query(aug9, "308")
            );
            console.log(
                "Point query Sep 15 (item 308):",
                tree.query(sep15, "308")
            );

            // These should find conflicts
            const aug1Conflicts = tree.query(aug1, "308");
            const aug9Conflicts = tree.query(aug9, "308");
            const sep15Conflicts = tree.query(sep15, "308");

            expect(
                aug1Conflicts.length,
                "Aug 1 should have conflicts for item 308"
            ).to.be.greaterThan(0);
            expect(
                aug9Conflicts.length,
                "Aug 9 should have conflicts for item 308"
            ).to.be.greaterThan(0);
            expect(
                sep15Conflicts.length,
                "Sep 15 should have conflicts for item 308"
            ).to.be.greaterThan(0);
        });

        it("should handle range queries correctly", () => {
            const tree = buildIntervalTree(opacBookings, [], opacRules);

            // Test the exact range from OPAC logs: 2025-08-09 to 2025-10-01
            const startRange = dayjs("2025-08-09").valueOf();
            const endRange = dayjs("2025-10-01").valueOf();

            console.log("Range query 2025-08-09 to 2025-10-01 (item 308):");
            const rangeConflicts = tree.queryRange(startRange, endRange, "308");
            console.log("Found conflicts:", rangeConflicts.length);

            rangeConflicts.forEach((conflict, i) => {
                console.log(`Conflict ${i + 1}:`, {
                    type: conflict.type,
                    start: dayjs(conflict.start).format("YYYY-MM-DD"),
                    end: dayjs(conflict.end).format("YYYY-MM-DD"),
                    item: conflict.itemId,
                });
            });

            // This should find the second booking (2025-08-05 to 2025-09-27)
            expect(
                rangeConflicts.length,
                "Range should overlap with second booking"
            ).to.be.greaterThan(0);
        });

        it("should match exact calculateDisabledDates behavior", () => {
            // Test item 308 specifically selected on 2025-08-09
            const availability = calculateDisabledDates(
                opacBookings,
                [], // no checkouts
                opacItems,
                308, // specific item selected
                null, // no edit
                [], // no selected dates (start date selection)
                opacRules,
                "2025-07-30" // today
            );

            const aug9Date = new Date("2025-08-09");
            const isDisabled = availability.disable(aug9Date);

            console.log("Aug 9 disabled for item 308:", isDisabled);
            console.log(
                "Should be true (blocked) because item 308 has booking 08-05 to 09-27"
            );

            expect(isDisabled).to.be.true; // Should be blocked
        });

        it("should test various dates within booking periods", () => {
            const availability = calculateDisabledDates(
                opacBookings,
                [],
                opacItems,
                308, // item 308 selected
                null,
                [],
                opacRules,
                "2025-07-30"
            );

            const testDates = [
                { date: "2025-08-01", inBooking: true, booking: "1st booking" },
                { date: "2025-08-03", inBooking: true, booking: "1st booking" },
                {
                    date: "2025-08-05",
                    inBooking: true,
                    booking: "start of 2nd booking",
                },
                { date: "2025-08-06", inBooking: true, booking: "2nd booking" },
                { date: "2025-08-09", inBooking: true, booking: "2nd booking" },
                { date: "2025-09-15", inBooking: true, booking: "2nd booking" },
                { date: "2025-09-27", inBooking: true, booking: "2nd booking" },
                {
                    date: "2025-09-28",
                    inBooking: false,
                    booking: "after bookings",
                },
            ];

            testDates.forEach(test => {
                const testDate = new Date(test.date);
                const isDisabled = availability.disable(testDate);

                console.log(
                    `${test.date} (${test.booking}): ${
                        isDisabled ? "DISABLED" : "AVAILABLE"
                    }`
                );

                if (test.inBooking) {
                    expect(
                        isDisabled,
                        `${test.date} should be blocked (${test.booking})`
                    ).to.be.true;
                } else {
                    expect(
                        isDisabled,
                        `${test.date} should be available (${test.booking})`
                    ).to.be.false;
                }
            });
        });

        it("should test Any item mode with same data", () => {
            const availability = calculateDisabledDates(
                opacBookings,
                [],
                opacItems,
                null, // Any item mode
                null,
                [],
                opacRules,
                "2025-07-30"
            );

            // In Any item mode, all dates should be available since item 307 is always free
            const testDates = ["2025-08-01", "2025-08-09", "2025-09-15"];

            testDates.forEach(dateStr => {
                const testDate = new Date(dateStr);
                const isDisabled = availability.disable(testDate);

                console.log(
                    `${dateStr} (Any item): ${
                        isDisabled ? "DISABLED" : "AVAILABLE"
                    }`
                );
                expect(
                    isDisabled,
                    `${dateStr} should be available in Any item mode (item 307 free)`
                ).to.be.false;
            });
        });
    });
});
