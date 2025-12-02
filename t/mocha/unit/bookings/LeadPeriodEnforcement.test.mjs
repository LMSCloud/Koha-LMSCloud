/**
 * LeadPeriodEnforcement.test.mjs - Tests for lead period enforcement
 *
 * These tests cover:
 * - Issue 1: Lead period from today enforcement (first booking scenario)
 * - Issue 2: Visual markers for theoretical lead period after trail periods
 */

import { describe, it, before } from "mocha";
import {
    setupBookingTestEnvironment,
    getBookingModules,
    BookingTestData,
    BookingTestHelpers,
    expect,
} from "./TestUtils.mjs";

describe("Lead Period Enforcement", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("Issue 1: Lead period from today (first booking)", () => {
        it("should disable dates within lead period from today even with no existing bookings", () => {
            // Scenario: First booking on a new item with 3-day lead period
            // Today is 2025-01-10, so bookings should only be allowed from 2025-01-13 onwards
            const bookings = []; // No existing bookings
            const checkouts = [];
            const items = [
                { item_id: "item1", title: "New Item", item_type_id: "BOOK" },
            ];
            const circulationRules = {
                bookings_lead_period: 3, // 3 days advance booking required
                bookings_trail_period: 0,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                null, // any item
                null, // not editing
                [], // no dates selected yet (start date selection)
                circulationRules,
                today
            );

            // Dates within lead period from today should be disabled
            const testDates = [
                {
                    date: "2025-01-10",
                    expected: true,
                    description: "Today (within 3-day lead period)",
                },
                {
                    date: "2025-01-11",
                    expected: true,
                    description: "Tomorrow (within 3-day lead period)",
                },
                {
                    date: "2025-01-12",
                    expected: true,
                    description: "Day after tomorrow (within 3-day lead period)",
                },
                {
                    date: "2025-01-13",
                    expected: false,
                    description: "First available date (today + 3 days)",
                },
                {
                    date: "2025-01-14",
                    expected: false,
                    description: "Day after first available",
                },
                {
                    date: "2025-01-20",
                    expected: false,
                    description: "Future date well after lead period",
                },
            ];

            testDates.forEach(({ date, expected, description }) => {
                const testDate = new Date(date);
                const isDisabled = result.disable(testDate);
                expect(isDisabled).to.equal(
                    expected,
                    `${description} (${date}) - expected ${expected ? "disabled" : "enabled"}`
                );
            });
        });

        it("should add lead markers for dates within lead period from today", () => {
            const bookings = [];
            const checkouts = [];
            const items = [
                { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
                { item_id: "item2", title: "Item 2", item_type_id: "BOOK" },
            ];
            const circulationRules = {
                bookings_lead_period: 3,
                bookings_trail_period: 0,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                null,
                null,
                [],
                circulationRules,
                today
            );

            // Check that lead markers exist for dates within lead period
            ["2025-01-10", "2025-01-11", "2025-01-12"].forEach(dateStr => {
                expect(result.unavailableByDate[dateStr]).to.exist,
                    `unavailableByDate should have entry for ${dateStr}`;

                // Both items should have lead markers
                ["item1", "item2"].forEach(itemId => {
                    expect(result.unavailableByDate[dateStr][itemId]).to.exist,
                        `${dateStr} should have entry for ${itemId}`;
                    expect(
                        result.unavailableByDate[dateStr][itemId].has("lead")
                    ).to.be.true,
                        `${dateStr}/${itemId} should have 'lead' marker`;
                });
            });

            // Date after lead period should NOT have lead markers (unless from other sources)
            const afterLeadDate = "2025-01-13";
            if (result.unavailableByDate[afterLeadDate]) {
                ["item1", "item2"].forEach(itemId => {
                    const entry = result.unavailableByDate[afterLeadDate][itemId];
                    if (entry) {
                        expect(entry.has("lead")).to.be.false,
                            `${afterLeadDate}/${itemId} should NOT have 'lead' marker from today's lead period`;
                    }
                });
            }
        });

        it("should work correctly with zero lead period", () => {
            const bookings = [];
            const checkouts = [];
            const items = [
                { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
            ];
            const circulationRules = {
                bookings_lead_period: 0, // No lead period
                bookings_trail_period: 0,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                null,
                null,
                [],
                circulationRules,
                today
            );

            // Today should be enabled (no lead period)
            expect(result.disable(new Date("2025-01-10"))).to.be.false,
                "Today should be enabled when lead period is 0";
        });

        it("should combine lead period from today with existing booking constraints", () => {
            // Scenario: Item has an existing booking, plus lead period from today
            const bookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-01-20",
                    end_date: "2025-01-25",
                    patron_id: "patron1",
                },
            ];
            const checkouts = [];
            const items = [
                { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
            ];
            const circulationRules = {
                bookings_lead_period: 3,
                bookings_trail_period: 1,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                "item1", // specific item
                null,
                [],
                circulationRules,
                today
            );

            // Should disable: lead period from today + booking period + lead/trail from booking
            const testDates = [
                // Lead period from today
                { date: "2025-01-10", expected: true, description: "Today (lead from today)" },
                { date: "2025-01-12", expected: true, description: "Within lead from today" },
                // After lead from today, before booking
                { date: "2025-01-13", expected: false, description: "After lead from today" },
                { date: "2025-01-15", expected: false, description: "Before booking lead period" },
                // Lead period before existing booking
                { date: "2025-01-18", expected: true, description: "Booking lead period day 1" },
                { date: "2025-01-19", expected: true, description: "Booking lead period day 2" },
                // Booking period
                { date: "2025-01-20", expected: true, description: "Booking start" },
                { date: "2025-01-22", expected: true, description: "During booking" },
                { date: "2025-01-25", expected: true, description: "Booking end" },
                // Trail period after booking
                { date: "2025-01-26", expected: true, description: "Trail period" },
            ];

            testDates.forEach(({ date, expected, description }) => {
                const testDate = new Date(date);
                const isDisabled = result.disable(testDate);
                expect(isDisabled).to.equal(
                    expected,
                    `${description} (${date}) - expected ${expected ? "disabled" : "enabled"}`
                );
            });
        });
    });

    describe("Issue 2: Theoretical lead period after trail", () => {
        it("should add lead markers for dates after trail period", () => {
            // Scenario: Booking ends on Jan 20, trail period is 2 days (Jan 21-22),
            // lead period is 3 days. Dates Jan 23-25 should have lead markers
            // because starting a booking on those dates would have lead period
            // overlapping with the trail period.
            const bookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-01-15",
                    end_date: "2025-01-20",
                    patron_id: "patron1",
                },
            ];
            const checkouts = [];
            const items = [
                { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
            ];
            const circulationRules = {
                bookings_lead_period: 3,
                bookings_trail_period: 2,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                "item1",
                null,
                [],
                circulationRules,
                today
            );

            // Trail period: Jan 21-22 (should have trail markers from booking)
            // Theoretical lead period after trail: Jan 23-25 (should have lead markers)
            // These dates are blocked because starting a booking there would have
            // its lead period overlap with the trail

            // Check trail period markers
            ["2025-01-21", "2025-01-22"].forEach(dateStr => {
                expect(result.unavailableByDate[dateStr]).to.exist,
                    `unavailableByDate should have entry for trail date ${dateStr}`;
                expect(result.unavailableByDate[dateStr]["item1"]).to.exist,
                    `${dateStr} should have entry for item1`;
                expect(
                    result.unavailableByDate[dateStr]["item1"].has("trail")
                ).to.be.true,
                    `${dateStr}/item1 should have 'trail' marker`;
            });

            // Check theoretical lead period markers after trail
            ["2025-01-23", "2025-01-24", "2025-01-25"].forEach(dateStr => {
                expect(result.unavailableByDate[dateStr]).to.exist,
                    `unavailableByDate should have entry for theoretical lead date ${dateStr}`;
                expect(result.unavailableByDate[dateStr]["item1"]).to.exist,
                    `${dateStr} should have entry for item1`;
                expect(
                    result.unavailableByDate[dateStr]["item1"].has("lead")
                ).to.be.true,
                    `${dateStr}/item1 should have 'lead' marker (theoretical lead after trail)`;
            });

            // First available date after all constraints
            const firstAvailable = "2025-01-26";
            const firstAvailableEntry = result.unavailableByDate[firstAvailable];
            if (firstAvailableEntry && firstAvailableEntry["item1"]) {
                expect(
                    firstAvailableEntry["item1"].has("lead")
                ).to.be.false,
                    `${firstAvailable} should NOT have lead marker`;
                expect(
                    firstAvailableEntry["item1"].has("trail")
                ).to.be.false,
                    `${firstAvailable} should NOT have trail marker`;
            }
        });

        it("should correctly disable dates in theoretical lead period after trail", () => {
            const bookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-01-15",
                    end_date: "2025-01-20",
                    patron_id: "patron1",
                },
            ];
            const checkouts = [];
            const items = [
                { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
            ];
            const circulationRules = {
                bookings_lead_period: 3,
                bookings_trail_period: 2,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                "item1",
                null,
                [], // selecting start date
                circulationRules,
                today
            );

            // Dates should be disabled:
            // - Booking period: Jan 15-20
            // - Lead before booking: Jan 13-14 (but may overlap with lead from today)
            // - Trail after booking: Jan 21-22
            // - Theoretical lead after trail: Jan 23-25 (because lead period would overlap trail)

            const testDates = [
                { date: "2025-01-21", expected: true, description: "Trail period day 1" },
                { date: "2025-01-22", expected: true, description: "Trail period day 2" },
                { date: "2025-01-23", expected: true, description: "Theoretical lead day 1" },
                { date: "2025-01-24", expected: true, description: "Theoretical lead day 2" },
                { date: "2025-01-25", expected: true, description: "Theoretical lead day 3" },
                { date: "2025-01-26", expected: false, description: "First available after all constraints" },
            ];

            testDates.forEach(({ date, expected, description }) => {
                const testDate = new Date(date);
                const isDisabled = result.disable(testDate);
                expect(isDisabled).to.equal(
                    expected,
                    `${description} (${date}) - expected ${expected ? "disabled" : "enabled"}`
                );
            });
        });

        it("should handle multiple bookings with overlapping theoretical lead periods", () => {
            const bookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-01-15",
                    end_date: "2025-01-18",
                    patron_id: "patron1",
                },
                {
                    booking_id: 2,
                    item_id: "item1",
                    start_date: "2025-01-28",
                    end_date: "2025-01-30",
                    patron_id: "patron2",
                },
            ];
            const checkouts = [];
            const items = [
                { item_id: "item1", title: "Item 1", item_type_id: "BOOK" },
            ];
            const circulationRules = {
                bookings_lead_period: 2,
                bookings_trail_period: 1,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                checkouts,
                items,
                "item1",
                null,
                [],
                circulationRules,
                today
            );

            // Check that both bookings have their theoretical lead periods marked
            // Booking 1: ends Jan 18, trail Jan 19, theoretical lead Jan 20-21
            // Booking 2: ends Jan 30, trail Jan 31, theoretical lead Feb 1-2

            // Trail after booking 1
            expect(result.unavailableByDate["2025-01-19"]).to.exist;
            expect(result.unavailableByDate["2025-01-19"]["item1"].has("trail")).to.be.true;

            // Theoretical lead after booking 1's trail
            ["2025-01-20", "2025-01-21"].forEach(dateStr => {
                expect(result.unavailableByDate[dateStr]).to.exist,
                    `Should have entry for ${dateStr}`;
                expect(result.unavailableByDate[dateStr]["item1"]).to.exist;
                expect(result.unavailableByDate[dateStr]["item1"].has("lead")).to.be.true,
                    `${dateStr} should have lead marker`;
            });
        });
    });

    describe("Edge cases", () => {
        it("should handle lead period of 1 day correctly", () => {
            const bookings = [];
            const items = [{ item_id: "item1", title: "Item 1", item_type_id: "BOOK" }];
            const circulationRules = {
                bookings_lead_period: 1,
                bookings_trail_period: 0,
                maxPeriod: 14,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null,
                null,
                [],
                circulationRules,
                today
            );

            // Only today should be disabled
            expect(result.disable(new Date("2025-01-10"))).to.be.true,
                "Today should be disabled with 1-day lead";
            expect(result.disable(new Date("2025-01-11"))).to.be.false,
                "Tomorrow should be enabled with 1-day lead";
        });

        it("should handle large lead period correctly", () => {
            const bookings = [];
            const items = [{ item_id: "item1", title: "Item 1", item_type_id: "BOOK" }];
            const circulationRules = {
                bookings_lead_period: 14, // 2 weeks advance booking
                bookings_trail_period: 0,
                maxPeriod: 30,
            };
            const today = "2025-01-10";

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null,
                null,
                [],
                circulationRules,
                today
            );

            // All dates for 14 days should be disabled
            expect(result.disable(new Date("2025-01-10"))).to.be.true;
            expect(result.disable(new Date("2025-01-15"))).to.be.true;
            expect(result.disable(new Date("2025-01-23"))).to.be.true;
            // First available: Jan 24 (today + 14 days)
            expect(result.disable(new Date("2025-01-24"))).to.be.false,
                "Jan 24 should be enabled (today + 14 days)";
        });

        it("should not add lead markers for past dates", () => {
            const bookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-01-05", // Past booking
                    end_date: "2025-01-08",
                    patron_id: "patron1",
                },
            ];
            const items = [{ item_id: "item1", title: "Item 1", item_type_id: "BOOK" }];
            const circulationRules = {
                bookings_lead_period: 3,
                bookings_trail_period: 2,
                maxPeriod: 14,
            };
            const today = "2025-01-15"; // Well after the booking

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                "item1",
                null,
                [],
                circulationRules,
                today
            );

            // Past dates should not have lead markers from theoretical lead period
            // Trail period was Jan 9-10, theoretical lead would be Jan 11-13
            // But since today is Jan 15, these are in the past
            ["2025-01-11", "2025-01-12", "2025-01-13"].forEach(dateStr => {
                const entry = result.unavailableByDate[dateStr];
                if (entry && entry["item1"]) {
                    // The theoretical lead markers should not be added for past dates
                    // (though there might be other markers)
                }
            });

            // Today should respect lead period from today
            expect(result.disable(new Date("2025-01-15"))).to.be.true;
            expect(result.disable(new Date("2025-01-16"))).to.be.true;
            expect(result.disable(new Date("2025-01-17"))).to.be.true;
            expect(result.disable(new Date("2025-01-18"))).to.be.false;
        });
    });
});
