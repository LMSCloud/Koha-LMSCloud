/**
 * bookingManager.test.js - Unit tests for booking manager business logic
 *
 * Tests all pure functions in the booking manager including date calculations,
 * constraint validation, and data processing functions.
 */

import { describe, it, beforeEach } from "mocha";
import { expect } from "chai";
import dayjs from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs";
import {
    calculateDisabledDates,
    handleBookingDateChange,
    getBookingMarkersForDate,
    calculateConstraintHighlighting,
    getCalendarNavigationTarget,
    aggregateMarkersByType,
    constrainPickupLocations,
    constrainBookableItems,
    constrainItemTypes,
    parseDateRange,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/bookingManager.mjs";

// Mock the translation function that supports both string and object usage
global.$__ = str => ({
    toString: () => str,
    format: arg => str.replace("%s", arg),
    // Make it work with .includes() by proxying string methods
    includes: searchStr => str.includes(searchStr),
    // For array.includes() compatibility
    valueOf: () => str,
});

describe("calculateDisabledDates", () => {
    let bookings, checkouts, bookableItems, circulationRules;

    beforeEach(() => {
        bookings = [
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

        checkouts = [
            {
                item_id: "item3",
                checkout_date: "2024-01-10",
                due_date: "2024-01-17",
                patron_id: "patron3",
            },
        ];

        bookableItems = [
            { item_id: "item1", title: "Item 1", barcode: "123" },
            { item_id: "item2", title: "Item 2", barcode: "456" },
            { item_id: "item3", title: "Item 3", barcode: "789" },
        ];

        circulationRules = {
            bookings_lead_period: 2,
            bookings_trail_period: 1,
            maxPeriod: 7,
        };
    });

    it("should generate disable function and unavailability data", () => {
        const result = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null, // selectedItem
            null, // editBookingId
            [], // selectedDates
            circulationRules,
            "2024-01-10" // today
        );

        expect(result).to.have.property("disable");
        expect(result).to.have.property("unavailableByDate");
        expect(result.disable).to.be.a("function");
        expect(result.unavailableByDate).to.be.an("object");
    });

    it("should disable dates with bookings", () => {
        const result = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            [],
            circulationRules,
            "2024-01-10"
        );

        // Should disable dates when all items are unavailable
        const testDate = new Date("2024-01-17"); // When item1 and item3 are unavailable

        // Check unavailability data
        expect(result.unavailableByDate["2024-01-17"]).to.exist;
        expect(result.unavailableByDate["2024-01-17"]["item1"]).to.exist;
        expect(result.unavailableByDate["2024-01-17"]["item3"]).to.exist;
    });

    it("should include lead and trail times", () => {
        const result = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            [],
            circulationRules,
            "2024-01-10"
        );

        // Check lead time (2 days before start)
        expect(result.unavailableByDate["2024-01-13"]).to.exist; // 2 days before Jan 15
        expect(result.unavailableByDate["2024-01-13"]["item1"]).to.exist;
        expect(result.unavailableByDate["2024-01-13"]["item1"].has("lead")).to
            .be.true;

        // Check trail time (1 day after end)
        expect(result.unavailableByDate["2024-01-21"]).to.exist; // 1 day after Jan 20
        expect(result.unavailableByDate["2024-01-21"]["item1"]).to.exist;
        expect(result.unavailableByDate["2024-01-21"]["item1"].has("trail")).to
            .be.true;
    });

    it("should exclude booking being edited", () => {
        const resultWithEdit = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            1, // editing booking_id 1
            [],
            circulationRules,
            "2024-01-10"
        );

        const resultWithoutEdit = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            [],
            circulationRules,
            "2024-01-10"
        );

        // Should have different unavailability when excluding the edited booking
        // Check that booking 1's core dates are no longer unavailable for item1
        const date1 = "2024-01-16"; // Within booking 1's range
        expect(resultWithoutEdit.unavailableByDate[date1]).to.exist;
        expect(resultWithoutEdit.unavailableByDate[date1]["item1"]).to.exist;

        // After excluding booking 1, item1 should not be unavailable on this date
        // (unless there are overlapping constraints)
        const hasItem1Unavailable =
            resultWithEdit.unavailableByDate[date1] &&
            resultWithEdit.unavailableByDate[date1]["item1"];
        expect(hasItem1Unavailable).to.not.exist;
    });

    it("should handle past dates correctly", () => {
        const result = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            [],
            circulationRules,
            "2024-01-20" // today is later
        );

        const pastDate = new Date("2024-01-15");
        expect(result.disable(pastDate)).to.be.true;
    });

    it("should validate circulation rules constraints", () => {
        const longRules = { ...circulationRules, maxPeriod: 3 };

        const result = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            [new Date("2024-01-25")], // selected start date
            longRules,
            "2024-01-10"
        );

        // Dates beyond maxPeriod should be disabled
        const farDate = new Date("2024-01-30"); // More than 3 days from Jan 25
        expect(result.disable(farDate)).to.be.true;
    });
});

describe("handleBookingDateChange", () => {
    let circulationRules, bookings, checkouts, bookableItems;

    beforeEach(() => {
        circulationRules = {
            leadDays: 1,
            trailDays: 1,
            maxPeriod: 7,
            issuelength: 7,
        };

        bookings = [];
        checkouts = [];
        bookableItems = [{ item_id: "item1" }];
    });

    it("should validate successful date selection", () => {
        const selectedDates = [new Date("2024-01-20"), new Date("2024-01-25")];

        const result = handleBookingDateChange(
            selectedDates,
            circulationRules,
            bookings,
            checkouts,
            bookableItems,
            null, // selectedItem
            null, // editBookingId
            "2024-01-10" // today
        );

        expect(result.valid).to.be.true;
        expect(result.errors).to.have.length(0);
        expect(result.newMinEndDate).to.exist;
        expect(result.newMaxEndDate).to.exist;
    });

    it("should reject missing start date", () => {
        const result = handleBookingDateChange(
            [], // no dates selected
            circulationRules,
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            "2024-01-10"
        );

        expect(result.valid).to.be.false;
        expect(result.errors).to.include("Start date is required.");
    });

    it("should reject start date too soon (lead time)", () => {
        const selectedDates = [new Date("2024-01-10")]; // Same as today, but leadDays = 1

        const result = handleBookingDateChange(
            selectedDates,
            circulationRules,
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            "2024-01-10"
        );

        expect(result.valid).to.be.false;
        expect(result.errors.some(err => err.includes("lead time"))).to.be.true;
    });

    it("should reject end date before start date", () => {
        const selectedDates = [
            new Date("2024-01-20"),
            new Date("2024-01-15"), // End before start
        ];

        const result = handleBookingDateChange(
            selectedDates,
            circulationRules,
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            "2024-01-10"
        );

        expect(result.valid).to.be.false;
        expect(result.errors.some(err => err.includes("before start date"))).to
            .be.true;
    });

    it("should reject period exceeding maximum", () => {
        const selectedDates = [
            new Date("2024-01-20"),
            new Date("2024-01-30"), // 10 days, but maxPeriod is 7
        ];

        const result = handleBookingDateChange(
            selectedDates,
            circulationRules,
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            "2024-01-10"
        );

        expect(result.valid).to.be.false;
        expect(result.errors.some(err => err.includes("exceeds maximum"))).to.be
            .true;
    });

    it("should validate end_date_only constraint mode", () => {
        const endDateOnlyRules = {
            ...circulationRules,
            booking_constraint_mode: "end_date_only",
            maxPeriod: 5,
        };

        const selectedDates = [
            new Date("2024-01-20"),
            new Date("2024-01-23"), // 3 days, but should be exactly 5
        ];

        const result = handleBookingDateChange(
            selectedDates,
            endDateOnlyRules,
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            "2024-01-10"
        );

        expect(result.valid).to.be.false;
        expect(result.errors.some(err => err.includes("end date only mode"))).to
            .be.true;
    });

    it("should calculate correct min/max end dates", () => {
        // Use dayjs for consistent date handling
        const selectedDates = [dayjs("2024-01-20").startOf("day").toDate()];

        const result = handleBookingDateChange(
            selectedDates,
            circulationRules,
            bookings,
            checkouts,
            bookableItems,
            null,
            null,
            "2024-01-10"
        );

        // Compare date strings to avoid timezone issues
        const expectedMinDate = dayjs("2024-01-21").startOf("day").toDate();
        const expectedMaxDate = dayjs("2024-01-26").startOf("day").toDate();

        expect(result.newMinEndDate.toISOString()).to.equal(
            expectedMinDate.toISOString()
        ); // Start + 1 day
        expect(result.newMaxEndDate.toISOString()).to.equal(
            expectedMaxDate.toISOString()
        ); // Start + maxPeriod - 1
    });
});

describe("getBookingMarkersForDate", () => {
    let unavailableByDate, bookableItems;

    beforeEach(() => {
        unavailableByDate = {
            "2024-01-15": {
                item1: new Set(["booking"]),
                item2: new Set(["lead"]),
            },
            "2024-01-16": {
                item1: new Set(["booking"]),
                item3: new Set(["checkout"]),
            },
        };

        bookableItems = [
            { item_id: "item1", title: "Item 1", barcode: "123" },
            { item_id: "item2", title: "Item 2", barcode: "456" },
            { item_id: "item3", title: "Item 3", barcode: "789" },
        ];
    });

    it("should return markers for date with unavailable items", () => {
        const markers = getBookingMarkersForDate(
            unavailableByDate,
            "2024-01-15",
            bookableItems
        );

        expect(markers).to.have.length(2);
        expect(markers.map(m => m.item)).to.include.members(["item1", "item2"]);
        expect(markers.find(m => m.item === "item1").type).to.equal("booked");
        expect(markers.find(m => m.item === "item2").type).to.equal("lead");
    });

    it("should map reason types correctly", () => {
        const markers = getBookingMarkersForDate(
            unavailableByDate,
            "2024-01-16",
            bookableItems
        );

        const bookedMarker = markers.find(m => m.item === "item1");
        const checkoutMarker = markers.find(m => m.item === "item3");

        expect(bookedMarker.type).to.equal("booked"); // core -> booked
        expect(checkoutMarker.type).to.equal("checked-out"); // checkout -> checked-out
    });

    it("should include item details", () => {
        const markers = getBookingMarkersForDate(
            unavailableByDate,
            "2024-01-15",
            bookableItems
        );

        const marker = markers.find(m => m.item === "item1");
        expect(marker.itemName).to.equal("Item 1");
        expect(marker.barcode).to.equal("123");
    });

    it("should return empty array for dates with no data", () => {
        const markers = getBookingMarkersForDate(
            unavailableByDate,
            "2024-01-20",
            bookableItems
        );

        expect(markers).to.have.length(0);
    });

    it("should handle null or undefined unavailableByDate", () => {
        const markers = getBookingMarkersForDate(
            null,
            "2024-01-15",
            bookableItems
        );
        expect(markers).to.have.length(0);

        const markers2 = getBookingMarkersForDate(
            undefined,
            "2024-01-15",
            bookableItems
        );
        expect(markers2).to.have.length(0);
    });
});

describe("calculateConstraintHighlighting", () => {
    it("should calculate highlighting for date range constraint", () => {
        const circulationRules = {
            maxPeriod: 5,
        };

        const constraintOptions = {
            maxBookingPeriod: 7,
        };

        const result = calculateConstraintHighlighting(
            "2024-01-15",
            circulationRules,
            constraintOptions
        );

        expect(result).to.not.be.null;
        expect(result.startDate).to.deep.equal(
            dayjs("2024-01-15").startOf("day").toDate()
        );
        expect(result.targetEndDate).to.deep.equal(
            dayjs("2024-01-15").add(6, "day").toDate()
        ); // 7 - 1
        expect(result.maxPeriod).to.equal(7);
        expect(result.constraintMode).to.equal("normal");
    });

    it("should calculate highlighting for end_date_only mode", () => {
        const circulationRules = {
            booking_constraint_mode: "end_date_only",
            maxPeriod: 5,
        };

        const result = calculateConstraintHighlighting(
            "2024-01-15",
            circulationRules,
            {}
        );

        expect(result).to.not.be.null;
        expect(result.constraintMode).to.equal("end_date_only");
        expect(result.blockedIntermediateDates).to.have.length(3); // Days 2, 3, 4 (between start and end)
        expect(result.maxPeriod).to.equal(5);
    });

    it("should return null when no constraints apply", () => {
        const result = calculateConstraintHighlighting(
            "2024-01-15",
            {}, // no rules
            {} // no options
        );

        expect(result).to.be.null;
    });

    it("should use issuelength as fallback for maxPeriod", () => {
        const circulationRules = {
            booking_constraint_mode: "end_date_only",
            issuelength: 10,
        };

        const result = calculateConstraintHighlighting(
            "2024-01-15",
            circulationRules,
            {}
        );

        expect(result.maxPeriod).to.equal(10);
    });
});

describe("getCalendarNavigationTarget", () => {
    it("should detect when navigation is needed", () => {
        const startDate = "2024-01-15";
        const targetEndDate = "2024-02-10"; // Different month

        const result = getCalendarNavigationTarget(startDate, targetEndDate);

        expect(result.shouldNavigate).to.be.true;
        expect(result.targetMonth).to.equal(1); // February (0-based)
        expect(result.targetYear).to.equal(2024);
        expect(result.targetDate).to.deep.equal(dayjs(targetEndDate).toDate());
    });

    it("should detect when no navigation is needed", () => {
        const startDate = "2024-01-15";
        const targetEndDate = "2024-01-25"; // Same month

        const result = getCalendarNavigationTarget(startDate, targetEndDate);

        expect(result.shouldNavigate).to.be.false;
    });

    it("should handle year changes", () => {
        const startDate = "2024-12-15";
        const targetEndDate = "2025-01-10";

        const result = getCalendarNavigationTarget(startDate, targetEndDate);

        expect(result.shouldNavigate).to.be.true;
        expect(result.targetMonth).to.equal(0); // January
        expect(result.targetYear).to.equal(2025);
    });
});

describe("aggregateMarkersByType", () => {
    it("should aggregate markers by type", () => {
        const markers = [
            { type: "booked", item: "item1" },
            { type: "booked", item: "item2" },
            { type: "checked-out", item: "item3" },
            { type: "lead", item: "item1" }, // Should be excluded
            { type: "trail", item: "item2" }, // Should be excluded
        ];

        const result = aggregateMarkersByType(markers);

        expect(result).to.deep.equal({
            booked: 2,
            "checked-out": 1,
        });
    });

    it("should handle empty markers array", () => {
        const result = aggregateMarkersByType([]);
        expect(result).to.deep.equal({});
    });

    it("should exclude lead and trail markers", () => {
        const markers = [
            { type: "lead", item: "item1" },
            { type: "trail", item: "item2" },
        ];

        const result = aggregateMarkersByType(markers);
        expect(result).to.deep.equal({});
    });
});

describe("Constraint Functions", () => {
    let pickupLocations, bookableItems, itemTypes;

    beforeEach(() => {
        pickupLocations = [
            { library_id: "lib1", pickup_items: ["1", "2"] },
            { library_id: "lib2", pickup_items: ["2", "3"] },
        ];

        bookableItems = [
            { item_id: "1", item_type_id: "type1" }, // Changed from 'item1' to '1'
            { item_id: "2", item_type_id: "type1" }, // Changed from 'item2' to '2'
            { item_id: "3", item_type_id: "type2" }, // Changed from 'item3' to '3'
        ];

        itemTypes = [
            { item_type_id: "type1", name: "Type 1" },
            { item_type_id: "type2", name: "Type 2" },
        ];
    });

    describe("constrainPickupLocations", () => {
        it("should return all locations when no constraints", () => {
            const result = constrainPickupLocations(
                pickupLocations,
                bookableItems,
                null, // no itemtype constraint
                null // no item constraint
            );

            expect(result.filtered).to.have.length(2);
            expect(result.filteredOutCount).to.equal(0);
        });

        it("should filter by specific item", () => {
            const result = constrainPickupLocations(
                pickupLocations,
                bookableItems,
                null,
                "1" // Only available at lib1
            );

            expect(result.filtered).to.have.length(1);
            expect(result.filtered[0].library_id).to.equal("lib1");
            expect(result.filteredOutCount).to.equal(1);
        });

        it("should filter by item type", () => {
            const result = constrainPickupLocations(
                pickupLocations,
                bookableItems,
                "type2", // item3 only
                null
            );

            expect(result.filtered).to.have.length(1);
            expect(result.filtered[0].library_id).to.equal("lib2");
        });
    });

    describe("constrainBookableItems", () => {
        it("should filter by pickup location", () => {
            const result = constrainBookableItems(
                bookableItems,
                pickupLocations,
                "lib1", // Only has items 1 and 2
                null
            );

            expect(result.filtered).to.have.length(2);
            expect(result.filtered.map(i => i.item_id)).to.include.members([
                "1",
                "2",
            ]);
        });

        it("should filter by item type", () => {
            const result = constrainBookableItems(
                bookableItems,
                pickupLocations,
                null,
                "type2"
            );

            expect(result.filtered).to.have.length(1);
            expect(result.filtered[0].item_id).to.equal("3");
        });

        it("should filter by both location and type", () => {
            const result = constrainBookableItems(
                bookableItems,
                pickupLocations,
                "lib1",
                "type1"
            );

            expect(result.filtered).to.have.length(2);
            expect(result.filtered.every(i => i.item_type_id === "type1")).to.be
                .true;
        });
    });

    describe("constrainItemTypes", () => {
        it("should filter by pickup location", () => {
            const result = constrainItemTypes(
                itemTypes,
                bookableItems,
                pickupLocations,
                "lib2", // Has items 2 and 3 (type1 and type2)
                null
            );

            expect(result).to.have.length(2);
        });

        it("should filter by specific item", () => {
            const result = constrainItemTypes(
                itemTypes,
                bookableItems,
                pickupLocations,
                null,
                "3" // type2 only
            );

            expect(result).to.have.length(1);
            expect(result[0].item_type_id).to.equal("type2");
        });
    });
});

describe("parseDateRange", () => {
    beforeEach(() => {
        // Mock flatpickr global
        global.window = {
            flatpickr: {
                parseDate: (dateStr, format) => {
                    // Simple mock implementation
                    return new Date(dateStr);
                },
            },
            flatpickr_dateformat_string: "Y-m-d",
        };
        global.flatpickr = global.window.flatpickr;
    });

    it("should parse array of dates", () => {
        const input = [new Date("2024-01-15"), new Date("2024-01-20")];
        const result = parseDateRange(input);

        expect(result).to.have.length(2);
        expect(result[0]).to.be.a("string");
        expect(result[1]).to.be.a("string");
    });

    it("should parse string with date range", () => {
        const input = "2024-01-15 to 2024-01-20";
        const result = parseDateRange(input);

        expect(result).to.have.length(2);
        expect(result[0]).to.include("2024-01-15");
        expect(result[1]).to.include("2024-01-20");
    });

    it("should handle invalid input gracefully", () => {
        const result = parseDateRange("invalid");
        expect(result).to.deep.equal([null, null]);

        const result2 = parseDateRange(null);
        expect(result2).to.deep.equal([null, null]);
    });
});
