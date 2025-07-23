import { expect } from "chai";
import { describe, it } from "mocha";
import dayjs from "dayjs";
import {
    calculateDisabledDates,
    handleBookingDateChange,
    getBookingMarkersForDate,
} from "./bookingManager.mjs";

describe("calculateDisabledDates", () => {
    const makeBooking = (item_id, start, end, booking_id = null) => ({
        item_id,
        start_date: start,
        end_date: end,
        booking_id,
    });
    const makeCheckout = (item_id, due) => ({ item_id, due_date: due });
    const item = { item_id: 1 };
    const items = [item];

    it("should disable all dates before today", () => {
        const today = dayjs("2025-05-10");
        const { disable: fn } = calculateDisabledDates(
            [],
            [],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );
        expect(fn(today.subtract(1, "day").toDate())).to.be.true;
        expect(fn(today.toDate())).to.be.false;
    });

    it("should disable dates where all items are booked", () => {
        const today = dayjs("2025-05-10");
        const { disable: fn } = calculateDisabledDates(
            [makeBooking(1, "2025-05-10", "2025-05-12")],
            [],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );
        expect(fn(dayjs("2025-05-11").toDate())).to.be.true;
        expect(fn(dayjs("2025-05-13").toDate())).to.be.false;
    });

    it("should disable start dates if any required lead day is fully unavailable", () => {
        // Lead days: 2, lead days 8th and 9th are booked, trying to select 10th or 11th
        const today = dayjs("2025-05-10");
        const { disable: fn } = calculateDisabledDates(
            [makeBooking(1, "2025-05-08", "2025-05-09")],
            [],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 2 },
            today
        );
        expect(fn(dayjs("2025-05-10").toDate())).to.be.true; // 8th & 9th are booked
        expect(fn(dayjs("2025-05-11").toDate())).to.be.true; // 9th is booked
        expect(fn(dayjs("2025-05-12").toDate())).to.be.false;
    });

    it("should disable end dates if any required trail day is fully unavailable", () => {
        const today = dayjs("2025-05-10");
        // Trail days: 2, trail days 13th and 14th are booked, selecting 11th-12th
        const { disable: fn } = calculateDisabledDates(
            [makeBooking(1, "2025-05-13", "2025-05-14")],
            [],
            items,
            null,
            null,
            ["2025-05-11", "2025-05-12"],
            { bookings_trail_period: 2 },
            today
        );
        expect(fn(dayjs("2025-05-12").toDate())).to.be.true; // 13th is booked
        expect(fn(dayjs("2025-05-11").toDate())).to.be.false;
    });

    it("should disable dates violating maxPeriod", () => {
        const today = dayjs("2025-05-10");
        const { disable: fn } = calculateDisabledDates(
            [],
            [],
            items,
            null,
            null,
            ["2025-05-10"],
            { maxPeriod: 2 },
            today
        );
        expect(fn(dayjs("2025-05-12").toDate())).to.be.true; // 12th is not allowed
        expect(fn(dayjs("2025-05-11").toDate())).to.be.false; // 11th is allowed
    });

    it("should allow dates if no constraints are violated", () => {
        const today = dayjs("2025-05-10");
        const { disable: fn } = calculateDisabledDates(
            [],
            [],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );
        expect(fn(dayjs("2025-05-15").toDate())).to.be.false;
    });

    it("should disable dates where all items are checked out", () => {
        const today = dayjs("2025-05-10");
        const { disable: fn } = calculateDisabledDates(
            [],
            [makeCheckout(1, "2025-05-11")],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );
        expect(fn(dayjs("2025-05-11").toDate())).to.be.true;
        expect(fn(dayjs("2025-05-12").toDate())).to.be.false;
    });

    it("should disable start dates if any required lead day is checked out", () => {
        const today = dayjs("2025-05-10");
        // Lead days: 2, checkouts on 8th and 9th
        const { disable: fn } = calculateDisabledDates(
            [],
            [makeCheckout(1, "2025-05-08"), makeCheckout(1, "2025-05-09")],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 2 },
            today
        );
        expect(fn(dayjs("2025-05-10").toDate())).to.be.true;
        expect(fn(dayjs("2025-05-11").toDate())).to.be.true;
        expect(fn(dayjs("2025-05-12").toDate())).to.be.false;
    });

    it("should disable end dates if any required trail day is checked out", () => {
        const today = dayjs("2025-05-10");
        // Trail days: 2, checkouts on 13th and 14th
        const { disable: fn } = calculateDisabledDates(
            [],
            [makeCheckout(1, "2025-05-13"), makeCheckout(1, "2025-05-14")],
            items,
            null,
            null,
            ["2025-05-11", "2025-05-12"],
            { bookings_trail_period: 2 },
            today
        );
        expect(fn(dayjs("2025-05-12").toDate())).to.be.true;
        expect(fn(dayjs("2025-05-11").toDate())).to.be.false;
    });

    it("should not disable date if at least one item is available (multiple items, partial checkouts/bookings)", () => {
        const today = dayjs("2025-05-10");
        const items2 = [{ item_id: 1 }, { item_id: 2 }];
        // Only item 1 is checked out
        const { disable: fn } = calculateDisabledDates(
            [],
            [makeCheckout(1, "2025-05-11")],
            items2,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );
        expect(fn(dayjs("2025-05-11").toDate())).to.be.false;
    });

    it("should not disable dates for the booking being edited", () => {
        const today = dayjs("2025-05-10");
        // Booking id 42 covers 10th-12th, but we're editing it
        const { disable: fn } = calculateDisabledDates(
            [makeBooking(1, "2025-05-10", "2025-05-12", 42)],
            [],
            items,
            null,
            42,
            [],
            { bookings_lead_period: 0 },
            today
        );
        expect(fn(dayjs("2025-05-11").toDate())).to.be.false;
    });

    it("should disable if booking and checkout overlap for all items", () => {
        const today = dayjs("2025-05-10");
        // Both booking and checkout on 11th
        const { disable: fn } = calculateDisabledDates(
            [makeBooking(1, "2025-05-11", "2025-05-11")],
            [makeCheckout(1, "2025-05-11")],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );
        expect(fn(dayjs("2025-05-11").toDate())).to.be.true;
    });

    it("should populate unavailableByDate correctly for a booking", () => {
        const today = dayjs("2025-05-10");
        const bookings = [makeBooking(1, "2025-05-11", "2025-05-12")]; // Item 1 booked on 11th and 12th
        const { unavailableByDate } = calculateDisabledDates(
            bookings,
            [],
            items,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );

        expect(unavailableByDate["2025-05-11"]).to.deep.equal({
            1: new Set(["core"]),
        });
        expect(unavailableByDate["2025-05-12"]).to.deep.equal({
            1: new Set(["core"]),
        });
        expect(unavailableByDate["2025-05-10"]).to.be.undefined;
    });

    it("should populate unavailableByDate correctly for a checkout", () => {
        const today = dayjs("2025-05-10");
        const checkouts = [makeCheckout(1, "2025-05-13")]; // Item 1 checked out on 13th
        const { unavailableByDate } = calculateDisabledDates(
            [],
            checkouts,
            items,
            null,
            null,
            [],
            { bookings_lead_period: 0 },
            today
        );

        expect(unavailableByDate["2025-05-13"]).to.deep.equal({
            1: new Set(["checkout"]),
        });
        expect(unavailableByDate["2025-05-12"]).to.be.undefined;
    });

    describe("getBookingMarkersForDate", () => {
        const item1 = {
            item_id: 1,
            title: "The Great Gatsby",
            barcode: "GATSBY001",
            effective_itemtype: "BOOK",
        };
        const item2 = {
            item_id: 2,
            title: "Blu-ray Movie",
            barcode: "MOVIE002",
            effective_itemtype: "DVD",
        };
        const allBookableItems = [item1, item2];

        it("should return empty array if unavailableByDate is undefined", () => {
            const markers = getBookingMarkersForDate(
                undefined,
                "2025-05-10",
                allBookableItems
            );
            expect(markers).to.deep.equal([]);
        });

        it("should return empty array if dateStr is not in unavailableByDate", () => {
            const unavailableByDate = {
                "2025-05-10": { 1: ["core"] }, // core maps to booked
            };
            const markers = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-11",
                allBookableItems
            );
            expect(markers).to.deep.equal([]);
        });

        it("should return a marker object for a single booked item (reason 'core')", () => {
            const unavailableByDate = {
                "2025-05-10": { 1: ["core"] },
            };
            const markers = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-10",
                [item1]
            );
            expect(markers).to.deep.equal([
                {
                    type: "booked",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
            ]);
        });

        it("should return a marker object for a single checked-out item (reason 'checkout')", () => {
            const unavailableByDate = {
                "2025-05-10": { 1: ["checkout"] },
            };
            const markers = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-10",
                [item1]
            );
            expect(markers).to.deep.equal([
                {
                    type: "checked-out",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
            ]);
        });

        it("should return marker objects for lead and trail periods (unmapped reasons)", () => {
            const unavailableByDate = {
                "2025-05-10": { 1: ["lead"] },
                "2025-05-11": { 1: ["trail"] },
            };
            const markersLead = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-10",
                [item1]
            );
            expect(markersLead).to.deep.equal([
                {
                    type: "lead",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
            ]);
            const markersTrail = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-11",
                [item1]
            );
            expect(markersTrail).to.deep.equal([
                {
                    type: "trail",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
            ]);
        });

        it("should return multiple marker objects for multiple items with different statuses on the same date", () => {
            const unavailableByDate = {
                "2025-05-10": {
                    1: ["core"], // booked
                    2: ["checkout"], // checked-out
                },
            };
            const markers = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-10",
                allBookableItems
            );
            expect(markers).to.have.deep.members([
                {
                    type: "booked",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
                {
                    type: "checked-out",
                    item: "2",
                    itemName: "Blu-ray Movie",
                    barcode: "MOVIE002",
                },
            ]);
            expect(markers.length).to.equal(2);
        });

        it("should return multiple marker objects for an item that has multiple reasons", () => {
            const unavailableByDate = {
                "2025-05-10": { 1: ["core", "lead"] }, // booked and lead
            };
            const markers = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-10",
                [item1]
            );
            expect(markers).to.have.deep.members([
                {
                    type: "booked",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
                {
                    type: "lead",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
            ]);
            expect(markers.length).to.equal(2);
        });

        it("should provide details from bookableItems when item is found, and default details when not found", () => {
            const unavailableByDate = {
                "2025-05-10": {
                    1: ["core"], // item1 is in currentBookableItems
                    3: ["checkout"], // item3 is NOT in currentBookableItems (which only has item1)
                },
            };
            const currentBookableItems = [item1]; // Only item1 is known here
            const markers = getBookingMarkersForDate(
                unavailableByDate,
                "2025-05-10",
                currentBookableItems
            );
            expect(markers).to.have.deep.members([
                {
                    type: "booked",
                    item: "1",
                    itemName: "The Great Gatsby",
                    barcode: "GATSBY001",
                },
                {
                    type: "checked-out",
                    item: "3",
                    itemName: "3",
                    barcode: null,
                }, // item_id as itemName, null barcode
            ]);
            expect(markers.length).to.equal(2);
        });
    });

    describe("handleBookingDateChange", () => {
        const items = [{ item_id: 1 }];
        it("should enforce maxPeriod", () => {
            const result = handleBookingDateChange(
                ["2025-05-10", "2025-05-13"],
                { maxPeriod: 2 },
                [],
                [],
                items,
                null,
                null
            );
            expect(result.valid).to.be.false;
            expect(result.errors.join(" ")).to.match(/max/i);
        });
        it("should allow valid range", () => {
            const result = handleBookingDateChange(
                ["2025-05-10", "2025-05-11"],
                { maxPeriod: 2 },
                [],
                [],
                items,
                null,
                null,
                "2025-05-10"
            );
            expect(result.valid).to.be.true;
        });
        it("should return errors for missing dates", () => {
            const result = handleBookingDateChange(
                [],
                { maxPeriod: 2 },
                [],
                [],
                items,
                null,
                null
            );
            expect(result.valid).to.be.false;
            expect(result.errors.length).to.be.greaterThan(0);
        });
        it("should respect lead and trail periods in validation", () => {
            const bookings = [
                {
                    item_id: 1,
                    start_date: "2025-05-14",
                    end_date: "2025-05-16",
                },
            ];
            const result = handleBookingDateChange(
                ["2025-05-10", "2025-05-13"],
                { leadDays: 2, trailDays: 2, maxPeriod: 10 },
                bookings,
                [],
                items,
                null,
                null,
                "2025-05-01"
            );
            // Should be invalid, proposed range's dates conflict with existing booking's lead days
            expect(result.valid).to.be.false;
            expect(result.errors.join(" ")).to.match(/unavailable/i);

            const result2 = handleBookingDateChange(
                ["2025-05-13", "2025-05-16"],
                { leadDays: 2, trailDays: 2, maxPeriod: 10 },
                bookings,
                [],
                items,
                null,
                null,
                "2025-05-01"
            );
            // Should be invalid due to overlap with existing booking's lead days / core booking dates
            expect(result2.valid).to.be.false;
        });
    });
});
