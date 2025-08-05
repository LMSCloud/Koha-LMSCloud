/**
 * Advanced Constraint Testing Suite
 *
 * Comprehensive tests for constraint functions and lead/trail period logic
 * with detailed validation of business rules.
 */

import { describe, it, before } from "mocha";
import {
    setupBookingTestEnvironment,
    getBookingModules,
    BookingTestData,
    expect,
} from "./TestUtils.mjs";

describe("Advanced Constraint Testing", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("constrainBookableItems Advanced Tests", () => {
        it("should properly handle string item IDs in pickup location filtering", () => {
            // Test with string item IDs to ensure proper comparison
            const items = [
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
            ];

            const pickupLocations = [
                {
                    library_id: "MAIN",
                    name: "Main Library",
                    pickup_items: ["item1", "item3"], // Should only return items item1 and item3
                },
                {
                    library_id: "BRANCH",
                    name: "Branch Library",
                    pickup_items: ["item2"],
                },
            ];

            // Test filtering by MAIN pickup location
            const result = modules.constrainBookableItems(
                items,
                pickupLocations,
                "MAIN", // Should only return items item1, item3
                null, // No item type constraint
                { value: {} }
            );

            // Verify correct filtering with string IDs
            expect(result.filtered).to.have.length(
                2,
                "Should return exactly 2 items available at MAIN"
            );

            const filteredIds = result.filtered.map(item => item.item_id);
            expect(filteredIds).to.include("item1", "Should include item1");
            expect(filteredIds).to.include("item3", "Should include item3");
            expect(filteredIds).to.not.include(
                "item2",
                "Should not include item2 (available at BRANCH)"
            );
        });

        it("should properly handle numeric item IDs in pickup location filtering", () => {
            // Test with numeric item IDs to ensure both string and numeric work
            const items = [
                {
                    item_id: 1001,
                    title: "Branch A Book 1",
                    item_type_id: "BOOK",
                    home_library_id: "BRANCH_A",
                },
                {
                    item_id: 1002,
                    title: "Branch A Book 2",
                    item_type_id: "BOOK",
                    home_library_id: "BRANCH_A",
                },
                {
                    item_id: 2001,
                    title: "Branch B Book 1",
                    item_type_id: "BOOK",
                    home_library_id: "BRANCH_B",
                },
                {
                    item_id: 2002,
                    title: "Branch B DVD 1",
                    item_type_id: "DVD",
                    home_library_id: "BRANCH_B",
                },
                {
                    item_id: 3001,
                    title: "Branch C Magazine 1",
                    item_type_id: "MAGAZINE",
                    home_library_id: "BRANCH_C",
                },
            ];

            const pickupLocations = [
                {
                    library_id: "BRANCH_A",
                    name: "Branch A",
                    pickup_items: [1001, 1002], // Only items 1001 and 1002 available at BRANCH_A
                },
                {
                    library_id: "BRANCH_B",
                    name: "Branch B",
                    pickup_items: [2001, 2002], // Only items 2001 and 2002 available at BRANCH_B
                },
                {
                    library_id: "BRANCH_C",
                    name: "Branch C",
                    pickup_items: [3001], // Only item 3001 available at BRANCH_C
                },
            ];

            // Test filtering by BRANCH_A pickup location
            const result = modules.constrainBookableItems(
                items,
                pickupLocations,
                "BRANCH_A", // Should only return items 1001, 1002
                null, // No item type constraint
                { value: {} }
            );

            // Verify correct filtering with numeric IDs
            expect(result.filtered).to.have.length(
                2,
                "Should return exactly 2 items available at BRANCH_A"
            );

            const filteredIds = result.filtered.map(item => item.item_id);
            expect(filteredIds).to.include(1001, "Should include item 1001");
            expect(filteredIds).to.include(1002, "Should include item 1002");
            expect(filteredIds).to.not.include(
                2001,
                "Should not include item 2001 (not available at BRANCH_A)"
            );
            expect(filteredIds).to.not.include(
                2002,
                "Should not include item 2002 (not available at BRANCH_A)"
            );
            expect(filteredIds).to.not.include(
                3001,
                "Should not include item 3001 (not available at BRANCH_A)"
            );
        });

        it("should properly filter items by pickup location and item type combined", () => {
            const items = [
                {
                    item_id: 1001,
                    title: "Branch A Book 1",
                    item_type_id: "BOOK",
                    home_library_id: "BRANCH_A",
                },
                {
                    item_id: 1002,
                    title: "Branch A DVD 1",
                    item_type_id: "DVD",
                    home_library_id: "BRANCH_A",
                },
                {
                    item_id: 2001,
                    title: "Branch B Book 1",
                    item_type_id: "BOOK",
                    home_library_id: "BRANCH_B",
                },
                {
                    item_id: 2002,
                    title: "Branch B DVD 1",
                    item_type_id: "DVD",
                    home_library_id: "BRANCH_B",
                },
            ];

            const pickupLocations = [
                {
                    library_id: "BRANCH_A",
                    name: "Branch A",
                    pickup_items: [1001, 1002], // Both book and DVD available
                },
                {
                    library_id: "BRANCH_B",
                    name: "Branch B",
                    pickup_items: [2001, 2002], // Both book and DVD available
                },
            ];

            // Test filtering by BRANCH_A pickup location AND BOOK item type
            const result = modules.constrainBookableItems(
                items,
                pickupLocations,
                "BRANCH_A", // Only BRANCH_A items
                "BOOK", // Only BOOK items
                { value: {} }
            );

            // Should return only item 1001 (BOOK at BRANCH_A)
            expect(result.filtered).to.have.length(
                1,
                "Should return exactly 1 item (BOOK available at BRANCH_A)"
            );
            expect(result.filtered[0].item_id).to.equal(
                1001,
                "Should return item 1001"
            );
            expect(result.filtered[0].item_type_id).to.equal(
                "BOOK",
                "Should be a BOOK"
            );
        });

        it("should return empty array when no items match pickup location", () => {
            const items = [
                {
                    item_id: 1001,
                    title: "Branch A Book 1",
                    item_type_id: "BOOK",
                    home_library_id: "BRANCH_A",
                },
                {
                    item_id: 2001,
                    title: "Branch B Book 1",
                    item_type_id: "BOOK",
                    home_library_id: "BRANCH_B",
                },
            ];

            const pickupLocations = [
                {
                    library_id: "BRANCH_A",
                    name: "Branch A",
                    pickup_items: [1001],
                },
                {
                    library_id: "BRANCH_B",
                    name: "Branch B",
                    pickup_items: [2001],
                },
            ];

            // Test filtering by non-existent pickup location
            const result = modules.constrainBookableItems(
                items,
                pickupLocations,
                "BRANCH_C", // No items available at BRANCH_C
                null,
                { value: {} }
            );

            expect(result.filtered).to.have.length(
                0,
                "Should return no items when pickup location has no items"
            );
        });
    });

    describe("Lead/Trail Period Business Logic", () => {
        it("should correctly apply lead/trail period constraints for start date selection", () => {
            const bookings = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "2025-08-15",
                    end_date: "2025-08-20",
                    patron_id: "patron1",
                },
            ];

            const items = [
                { item_id: "item1", title: "Test Item", item_type_id: "BOOK" },
            ];

            // Test with realistic lead/trail periods (not the bandaid 0,0)
            const rulesWithLeadTrail = {
                bookings_lead_period: 2, // 2 days before booking
                bookings_trail_period: 1, // 1 day after booking
                maxPeriod: 14,
            };

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                "item1", // Specific item with booking
                null,
                [],
                rulesWithLeadTrail,
                "2025-08-05"
            );

            // Business logic explanation:
            // - Booking period: 2025-08-15 to 2025-08-20 (item1 unavailable)
            // - Lead period (2 days): 2025-08-13, 2025-08-14 (blocks start dates)
            // - Trail period (1 day): 2025-08-21 (blocks item1 from new bookings)
            // - Lead period check: When selecting start date, check if conflicts exist in lead period

            // Test the dates that should be disabled
            const testDates = [
                {
                    date: "2025-08-12",
                    expected: false,
                    description: "Before lead period",
                },
                {
                    date: "2025-08-13",
                    expected: true,
                    description: "Lead period day 1",
                },
                {
                    date: "2025-08-14",
                    expected: true,
                    description: "Lead period day 2",
                },
                {
                    date: "2025-08-15",
                    expected: true,
                    description: "Booking start",
                },
                {
                    date: "2025-08-17",
                    expected: true,
                    description: "During booking",
                },
                {
                    date: "2025-08-20",
                    expected: true,
                    description: "Booking end",
                },
                {
                    date: "2025-08-21",
                    expected: true,
                    description: "Trail period",
                },
                {
                    date: "2025-08-22",
                    expected: true,
                    description:
                        "Blocked due to conflicts in lead period (2025-08-20, 2025-08-21)",
                },
                {
                    date: "2025-08-24",
                    expected: false,
                    description:
                        "Far enough after trail period that lead period check passes",
                },
            ];

            testDates.forEach(({ date, expected, description }) => {
                const testDate = new Date(date);
                const isDisabled = result.disable(testDate);
                expect(isDisabled).to.equal(
                    expected,
                    `${description} (${date})`
                );
            });
        });
    });
});
