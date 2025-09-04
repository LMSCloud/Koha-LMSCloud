/**
 * Debug test specifically for July 31st selection issue
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
        "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/IntervalTree.mjs"
    );
    buildIntervalTree = intervalTreeModule.buildIntervalTree;
    IntervalTree = intervalTreeModule.IntervalTree;
});

describe("July 31st Selection Debug", () => {
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

    it("should investigate why July 31st is selectable for item 308", () => {
        // Test July 31st specifically for item 308
        const availability = calculateDisabledDates(
            opacBookings,
            [],
            opacItems,
            308, // item 308 selected
            null,
            [], // no selected dates (start date selection)
            opacRules,
            "2025-07-30"
        );

        const july31Date = new Date("2025-07-31");
        const isDisabled = availability.disable(july31Date);

        console.log("July 31st analysis for item 308:");
        console.log("- Date:", july31Date);
        console.log("- Is disabled:", isDisabled);
        console.log("- Should be disabled: TRUE (because range conflicts)");

        // Debug the range calculation
        const startDate = dayjs("2025-07-31");
        const calculatedEndDate = startDate.add(54 - 1, "day"); // maxPeriod - 1
        console.log(
            "- Calculated range:",
            startDate.format("YYYY-MM-DD"),
            "to",
            calculatedEndDate.format("YYYY-MM-DD")
        );

        // Test the IntervalTree directly
        const tree = buildIntervalTree(opacBookings, [], opacRules);
        const rangeConflicts = tree.queryRange(
            startDate.valueOf(),
            calculatedEndDate.valueOf(),
            "308"
        );

        console.log("- Range conflicts found:", rangeConflicts.length);
        rangeConflicts.forEach((conflict, i) => {
            console.log(`  Conflict ${i + 1}:`, {
                type: conflict.type,
                start: dayjs(conflict.start).format("YYYY-MM-DD HH:mm"),
                end: dayjs(conflict.end).format("YYYY-MM-DD HH:mm"),
                item: conflict.itemId,
            });
        });

        // This should be true - July 31st should be blocked
        expect(
            isDisabled,
            "July 31st should be blocked for item 308 due to range conflicts"
        ).to.be.true;
    });
});
