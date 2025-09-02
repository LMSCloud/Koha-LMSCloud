/**
 * TestUtils.mjs - Centralized test utilities for booking system tests
 *
 * Provides common mocks, test data factories, and helper functions
 * to reduce duplication across booking system tests.
 */

import dayjsLib from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";
import { expect } from "chai";

// Global test setup - call this in beforeEach or before hooks
export function setupBookingTestEnvironment() {
    // Mock the translation function
    global.$__ = str => ({
        toString: () => str,
        format: arg => str.replace("%s", arg),
        includes: searchStr => str.includes(searchStr),
        valueOf: () => str,
    });

    // Mock window object with dayjs for testing
    global.window = global.window || {};
    dayjsLib.extend(isSameOrBefore);
    dayjsLib.extend(isSameOrAfter);
    global.window.dayjs = dayjsLib;

    // Mock localStorage
    global.localStorage = global.localStorage || {
        getItem: () => null,
        setItem: () => {},
        removeItem: () => {},
    };
}

// Lazy-loaded modules to avoid import issues
let _dayjs, _bookingManager;

export async function getBookingModules() {
    if (!_dayjs || !_bookingManager) {
        const dayjsModule = await import(
            "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs"
        );
        _dayjs = dayjsModule.default;

        _bookingManager = await import(
            "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/bookingManager.mjs"
        );
    }

    return {
        dayjs: _dayjs,
        calculateDisabledDates: _bookingManager.calculateDisabledDates,
        handleBookingDateChange: _bookingManager.handleBookingDateChange,
        getBookingMarkersForDate: _bookingManager.getBookingMarkersForDate,
        calculateConstraintHighlighting:
            _bookingManager.calculateConstraintHighlighting,
        getCalendarNavigationTarget:
            _bookingManager.getCalendarNavigationTarget,
        aggregateMarkersByType: _bookingManager.aggregateMarkersByType,
        constrainPickupLocations: _bookingManager.constrainPickupLocations,
        constrainBookableItems: _bookingManager.constrainBookableItems,
        constrainItemTypes: _bookingManager.constrainItemTypes,
    };
}

// Test data factories
export const BookingTestData = {
    // Standard booking objects
    createBooking: (overrides = {}) => ({
        booking_id: 1,
        item_id: "item1",
        start_date: "2024-01-15",
        end_date: "2024-01-20",
        patron_id: "patron1",
        ...overrides,
    }),

    createBookings: (count = 2) =>
        [
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
        ].slice(0, count),

    // Standard item objects
    createItem: (overrides = {}) => ({
        item_id: "item1",
        title: "Test Item",
        barcode: "123456",
        item_type_id: "BOOK",
        home_library_id: "MAIN",
        ...overrides,
    }),

    createItems: (count = 3) =>
        [
            {
                item_id: "item1",
                title: "Item 1",
                barcode: "123",
                item_type_id: "BOOK",
                home_library_id: "MAIN",
            },
            {
                item_id: "item2",
                title: "Item 2",
                barcode: "456",
                item_type_id: "DVD",
                home_library_id: "BRANCH",
            },
            {
                item_id: "item3",
                title: "Item 3",
                barcode: "789",
                item_type_id: "BOOK",
                home_library_id: "MAIN",
            },
        ].slice(0, count),

    // Standard circulation rules
    createCirculationRules: (overrides = {}) => ({
        bookings_lead_period: 2,
        bookings_trail_period: 1,
        maxPeriod: 7,
        booking_constraint_mode: null,
        ...overrides,
    }),

    // Standard pickup locations
    createPickupLocations: () => [
        {
            library_id: "MAIN",
            name: "Main Library",
            pickup_items: ["item1", "item3"],
        },
        {
            library_id: "BRANCH",
            name: "Branch Library",
            pickup_items: ["item2"],
        },
    ],

    // Multi library scenario
    createMultiLibraryScenario: () => ({
        bookings: [
            {
                booking_id: 1,
                item_id: 1001,
                start_date: "2025-08-10",
                end_date: "2025-08-15",
                patron_id: "patron1",
            },
            {
                booking_id: 2,
                item_id: 2001,
                start_date: "2025-08-12",
                end_date: "2025-08-18",
                patron_id: "patron2",
            },
        ],
        items: [
            {
                item_id: 1001,
                title: "Book A1",
                item_type_id: "BOOK",
                home_library_id: "BRANCH_A",
            },
            {
                item_id: 1002,
                title: "Book A2",
                item_type_id: "BOOK",
                home_library_id: "BRANCH_A",
            },
            {
                item_id: 2001,
                title: "DVD B1",
                item_type_id: "DVD",
                home_library_id: "BRANCH_B",
            },
            {
                item_id: 2002,
                title: "DVD B2",
                item_type_id: "DVD",
                home_library_id: "BRANCH_B",
            },
        ],
        pickupLocations: [
            {
                library_id: "BRANCH_A",
                name: "Main Branch",
                pickup_items: [1001, 1002],
            },
            {
                library_id: "BRANCH_B",
                name: "Secondary Branch",
                pickup_items: [2001, 2002],
            },
            {
                library_id: "BRANCH_C",
                name: "Third Branch (No Items)",
                pickup_items: [],
            },
        ],
    }),

    // Lead/trail period test scenario
    createLeadTrailScenario: () => ({
        bookings: [
            {
                booking_id: 1,
                item_id: "test_item",
                start_date: "2025-08-15",
                end_date: "2025-08-20",
                patron_id: "patron1",
            },
        ],
        items: [
            { item_id: "test_item", title: "Test Item", item_type_id: "BOOK" },
        ],
    }),

    // Mixed type items for comprehensive testing
    createMixedTypeItems: () => [
        { item_id: "book_001", title: "Book 1", item_type_id: "BOOK" },
        { item_id: "book_002", title: "Book 2", item_type_id: "BOOK" },
        { item_id: "dvd_001", title: "DVD 1", item_type_id: "DVD" },
        { item_id: "dvd_002", title: "DVD 2", item_type_id: "DVD" },
        {
            item_id: "magazine_001",
            title: "Magazine 1",
            item_type_id: "MAGAZINE",
        },
        {
            item_id: "magazine_002",
            title: "Magazine 2",
            item_type_id: "MAGAZINE",
        },
    ],

    // Complex constraint scenario for comprehensive testing
    createComplexConstraintScenario: () => ({
        bookings: [
            {
                booking_id: 1,
                item_id: 10001,
                start_date: "2025-08-10",
                end_date: "2025-08-15",
                patron_id: "patron1",
            },
            {
                booking_id: 2,
                item_id: 20001,
                start_date: "2025-08-12",
                end_date: "2025-08-18",
                patron_id: "patron2",
            },
        ],
        items: [
            {
                item_id: 10001,
                title: "Branch A Book 1",
                item_type_id: "BOOK",
                home_library_id: "BRANCH_A",
            },
            {
                item_id: 10002,
                title: "Branch A Book 2",
                item_type_id: "BOOK",
                home_library_id: "BRANCH_A",
            },
            {
                item_id: 10003,
                title: "Branch A DVD 1",
                item_type_id: "DVD",
                home_library_id: "BRANCH_A",
            },
            {
                item_id: 20001,
                title: "Branch B Book 1",
                item_type_id: "BOOK",
                home_library_id: "BRANCH_B",
            },
            {
                item_id: 20002,
                title: "Branch B DVD 1",
                item_type_id: "DVD",
                home_library_id: "BRANCH_B",
            },
            {
                item_id: 20003,
                title: "Branch B DVD 2",
                item_type_id: "DVD",
                home_library_id: "BRANCH_B",
            },
        ],
        pickupLocations: [
            {
                library_id: "BRANCH_A",
                name: "Branch A",
                pickup_items: [10001, 10002, 10003],
            },
            {
                library_id: "BRANCH_B",
                name: "Branch B",
                pickup_items: [20001, 20002, 20003],
            },
        ],
    }),

    // Generate large dataset for performance testing
    createLargeDataset: (itemCount = 200, bookingCount = 50) => {
        const branches = ["BRANCH_A", "BRANCH_B", "BRANCH_C", "BRANCH_D"];
        const types = ["BOOK", "DVD", "CD", "MAGAZINE"];

        const items = Array.from({ length: itemCount }, (_, i) => {
            const branch = branches[i % branches.length];
            const type = types[i % types.length];
            return {
                item_id: `item_${i}`,
                title: `Item ${i}`,
                item_type_id: type,
                home_library_id: branch,
            };
        });

        const bookings = Array.from({ length: bookingCount }, (_, i) => ({
            booking_id: i,
            item_id: `item_${i}`,
            start_date: dayjsLib("2025-08-01")
                .add(i % 30, "days")
                .format("YYYY-MM-DD"),
            end_date: dayjsLib("2025-08-01")
                .add((i % 30) + 3, "days")
                .format("YYYY-MM-DD"),
            patron_id: `patron_${i}`,
        }));

        const pickupLocations = branches.map(branch => ({
            library_id: branch,
            name: `${branch} Library`,
            pickup_items: items
                .filter(item => item.home_library_id === branch)
                .map(item => item.item_id),
        }));

        return { items, bookings, pickupLocations };
    },
};

// Helper functions
export const BookingTestHelpers = {
    // Date creation utilities
    createDate: dateStr => new Date(dateStr),

    createDateRange: (startStr, endStr) => [
        new Date(startStr),
        new Date(endStr),
    ],

    // Assertion helpers
    expectDateDisabled: (disableFunction, dateStr, shouldBeDisabled = true) => {
        const date = new Date(dateStr);
        const isDisabled = disableFunction(date);
        if (shouldBeDisabled) {
            expect(isDisabled).to.be.true;
        } else {
            expect(isDisabled).to.be.false;
        }
    },

    expectUnavailableByDate: (
        unavailableByDate,
        dateStr,
        itemId,
        reasonType
    ) => {
        expect(unavailableByDate[dateStr]).to.exist;
        expect(unavailableByDate[dateStr][itemId]).to.exist;
        expect(unavailableByDate[dateStr][itemId].has(reasonType)).to.be.true;
    },

    // Performance test helper
    measurePerformance: (testFunction, maxTimeMs = 100) => {
        const startTime = performance.now();
        testFunction();
        const duration = performance.now() - startTime;
        expect(duration).to.be.lessThan(maxTimeMs);
        return duration;
    },
};

// Common test patterns
export const BookingTestPatterns = {
    // Standard test for basic disable function behavior
    testBasicDisableFunction: (result, testCases) => {
        testCases.forEach(({ date, expected, description }) => {
            const testDate = new Date(date);
            expect(result.disable(testDate)).to.equal(expected, description);
        });
    },

    // Standard test for constraint filtering
    testConstraintFiltering: (
        filterFunction,
        items,
        constraints,
        expectedCount,
        description
    ) => {
        const constraintArgs = Array.isArray(constraints)
            ? constraints
            : [constraints];
        const result = filterFunction(items, ...constraintArgs);
        expect(result.filtered || result).to.have.length(
            expectedCount,
            description
        );
    },
};

export { expect };
