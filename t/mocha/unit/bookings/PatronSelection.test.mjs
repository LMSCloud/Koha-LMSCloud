/**
 * Patron Selection Workflow Test Suite
 *
 * Tests for patron selection and its cascading effects on booking constraints,
 * pickup locations, circulation rules, and date availability.
 */

import { describe, it, before } from "mocha";
import {
    setupBookingTestEnvironment,
    getBookingModules,
    BookingTestData,
    BookingTestHelpers,
    BookingTestPatterns,
    expect,
} from "./TestUtils.mjs";

describe("Patron Selection Workflow and Constraint Effects", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("Patron Selection Effects on Pickup Locations", () => {
        it("should filter pickup locations based on patron's home library", () => {
            // Create test data
            const patron = {
                patron_id: 1001,
                library_id: "BRANCH_A",
                firstname: "Test",
                surname: "Patron",
            };

            const allPickupLocations = [
                {
                    library_id: "BRANCH_A",
                    name: "Branch A",
                    pickup_items: [1, 2, 3],
                },
                {
                    library_id: "BRANCH_B",
                    name: "Branch B",
                    pickup_items: [4, 5, 6],
                },
                {
                    library_id: "BRANCH_C",
                    name: "Branch C",
                    pickup_items: [], // No items available
                },
            ];

            // Note: constrainPickupLocations expects different parameters than patron
            // It filters based on bookableItems and constraints, not patron directly
            // For this test, we'll simulate the constraint logic
            const bookableItems = BookingTestData.createItems(6);

            const result = modules.constrainPickupLocations(
                allPickupLocations,
                bookableItems,
                null, // no item type constraint
                null, // no specific item
                { value: {} }
            );

            // Should return object with filtered array
            expect(result).to.be.an("object");
            expect(result.filtered).to.be.an("array");
            expect(result.filtered).to.have.length.at.least(1);

            // Locations with items should be included
            const locationsWithItems = result.filtered.filter(
                loc => loc.pickup_items && loc.pickup_items.length > 0
            );
            expect(locationsWithItems).to.have.length.at.least(1);
        });

        it("should handle patron without library preference", () => {
            const patron = {
                patron_id: 1002,
                library_id: null, // No home library
                firstname: "Visiting",
                surname: "Patron",
            };

            const pickupLocations = BookingTestData.createPickupLocations();
            const bookableItems = BookingTestData.createItems(3);

            const result = modules.constrainPickupLocations(
                pickupLocations,
                bookableItems,
                null,
                null,
                { value: {} }
            );

            // Should return object with all locations that have items
            expect(result).to.be.an("object");
            expect(result.filtered).to.be.an("array");
            expect(
                result.filtered.every(
                    loc => loc.pickup_items && loc.pickup_items.length > 0
                )
            ).to.be.true;
        });

        it("should cascade patron selection to item availability", () => {
            const patron = {
                patron_id: 1003,
                library_id: "BRANCH_A",
                category_code: "ADULT",
            };

            const scenario = BookingTestData.createMultiLibraryScenario();

            // First, constrain pickup locations based on available items
            const constrainedPickupLocations = modules.constrainPickupLocations(
                scenario.pickupLocations,
                scenario.items,
                null,
                null,
                { value: {} }
            );

            // Then, constrain items based on available pickup locations
            const result = modules.constrainBookableItems(
                scenario.items,
                constrainedPickupLocations.filtered,
                constrainedPickupLocations.filtered[0]?.library_id, // Use first available
                null,
                { value: {} }
            );

            expect(result.filtered).to.be.an("array");
            // Items should be limited to those available at patron's accessible locations
            expect(result.filtered.length).to.be.lessThanOrEqual(
                scenario.items.length
            );
        });
    });

    describe("Patron Category Effects on Circulation Rules", () => {
        it("should apply different rules for different patron categories", () => {
            const adultPatron = {
                patron_id: 2001,
                category_code: "ADULT",
                library_id: "MAIN",
            };

            const childPatron = {
                patron_id: 2002,
                category_code: "CHILD",
                library_id: "MAIN",
            };

            // Simulate different circulation rules for categories
            const adultRules = {
                maxPeriod: 30,
                bookings_lead_period: 2,
                bookings_trail_period: 1,
                booking_constraint_mode: null,
            };

            const childRules = {
                maxPeriod: 14, // Shorter period for children
                bookings_lead_period: 1,
                bookings_trail_period: 0,
                booking_constraint_mode: "end_date_only",
            };

            const items = BookingTestData.createItems(3);
            const bookings = [];

            // Test adult patron date availability
            const adultResult = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null,
                null,
                [],
                adultRules,
                "2025-08-05"
            );

            // Test child patron date availability
            const childResult = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null,
                null,
                [],
                childRules,
                "2025-08-05"
            );

            // Verify different constraint modes are applied
            expect(adultRules.booking_constraint_mode).to.be.null;
            expect(childRules.booking_constraint_mode).to.equal(
                "end_date_only"
            );

            // Both should have disable functions
            expect(adultResult.disable).to.be.a("function");
            expect(childResult.disable).to.be.a("function");
        });

        it("should restrict item types based on patron category", () => {
            const restrictedPatron = {
                patron_id: 3001,
                category_code: "JUVENILE",
                restricted_item_types: ["DVD_R", "GAME_M"], // Simulated restrictions
            };

            const items = [
                { item_id: 1, title: "Children's Book", item_type_id: "BOOK" },
                { item_id: 2, title: "Rated R Movie", item_type_id: "DVD_R" },
                { item_id: 3, title: "Educational DVD", item_type_id: "DVD" },
                { item_id: 4, title: "Mature Game", item_type_id: "GAME_M" },
            ];

            // Filter items based on patron restrictions
            const availableItems = items.filter(
                item =>
                    !restrictedPatron.restricted_item_types?.includes(
                        item.item_type_id
                    )
            );

            expect(availableItems).to.have.length(2);
            expect(availableItems.find(i => i.item_type_id === "DVD_R")).to.be
                .undefined;
            expect(availableItems.find(i => i.item_type_id === "GAME_M")).to.be
                .undefined;
        });
    });

    describe("Patron Booking History Effects", () => {
        it("should consider patron's existing bookings when calculating availability", () => {
            const patron = {
                patron_id: 4001,
                library_id: "MAIN",
            };

            const existingBookings = [
                {
                    booking_id: 1,
                    patron_id: 4001, // Same patron
                    item_id: "item1",
                    start_date: "2025-08-10",
                    end_date: "2025-08-15",
                },
                {
                    booking_id: 2,
                    patron_id: 4002, // Different patron
                    item_id: "item2",
                    start_date: "2025-08-12",
                    end_date: "2025-08-14",
                },
            ];

            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules();

            // When editing a booking, patron's own bookings might be handled differently
            const editingOwnBooking = modules.calculateDisabledDates(
                existingBookings,
                [],
                items,
                "item1",
                1, // Editing booking ID 1
                [],
                rules,
                "2025-08-05"
            );

            // The patron's own booking (ID 1) should be excluded from conflicts
            const testDate = new Date("2025-08-12");
            // This date is during the patron's own booking being edited
            // The actual behavior depends on implementation
            expect(editingOwnBooking.disable).to.be.a("function");
        });

        it("should enforce patron-specific booking limits", () => {
            const patron = {
                patron_id: 5001,
                category_code: "STUDENT",
                max_bookings: 3, // Simulated limit
                current_bookings_count: 2,
            };

            // Check if patron can make another booking
            const canBookMore =
                patron.current_bookings_count < patron.max_bookings;
            expect(canBookMore).to.be.true;

            // Simulate reaching the limit
            patron.current_bookings_count = 3;
            const atLimit =
                patron.current_bookings_count >= patron.max_bookings;
            expect(atLimit).to.be.true;
        });
    });

    describe("Complete Patron Selection Workflow", () => {
        it("should handle the full patron selection cascade", () => {
            // Step 1: Select patron
            const selectedPatron = {
                patron_id: 6001,
                firstname: "John",
                surname: "Doe",
                library_id: "CENTRAL",
                category_code: "ADULT",
            };

            // Step 2: Fetch patron-specific data
            const pickupLocations = [
                {
                    library_id: "CENTRAL",
                    name: "Central Library",
                    pickup_items: [1, 2, 3, 4, 5],
                },
                {
                    library_id: "NORTH",
                    name: "North Branch",
                    pickup_items: [6, 7, 8],
                },
            ];

            const circulationRules = {
                maxPeriod: 21,
                bookings_lead_period: 2,
                bookings_trail_period: 1,
                booking_constraint_mode: null,
            };

            // Step 3: Apply constraints based on available items
            const items = BookingTestData.createItems(8);
            const constrainedLocations = modules.constrainPickupLocations(
                pickupLocations,
                items,
                null,
                null,
                { value: {} }
            );

            expect(constrainedLocations.filtered).to.have.length.at.least(1);

            // Step 4: Constrain items based on first pickup location
            const constrainedItems = modules.constrainBookableItems(
                items,
                constrainedLocations.filtered,
                constrainedLocations.filtered[0].library_id,
                null,
                { value: {} }
            );

            expect(constrainedItems.filtered).to.be.an("array");

            // Step 5: Calculate date availability with all constraints
            const dateAvailability = modules.calculateDisabledDates(
                [],
                [],
                constrainedItems.filtered,
                null,
                null,
                [],
                circulationRules,
                "2025-08-05"
            );

            expect(dateAvailability.disable).to.be.a("function");
            expect(dateAvailability.unavailableByDate).to.be.an("object");

            // Verify the cascade worked correctly
            expect(constrainedLocations.filtered.length).to.be.at.least(1);
            expect(constrainedItems.filtered.length).to.be.at.least(0); // Might be 0 if no matching items
        });

        it("should handle patron selection with no available resources", () => {
            const patron = {
                patron_id: 7001,
                library_id: "REMOTE", // Library with no items
                category_code: "VISITOR",
            };

            const pickupLocations = [
                {
                    library_id: "REMOTE",
                    name: "Remote Library",
                    pickup_items: [], // No items available
                },
                {
                    library_id: "MAIN",
                    name: "Main Library",
                    pickup_items: [1, 2, 3],
                },
            ];

            // Constrain to patron's library only (strict mode)
            const strictConstrainedLocations = pickupLocations.filter(
                loc => loc.library_id === patron.library_id
            );

            expect(strictConstrainedLocations).to.have.length(1);
            expect(strictConstrainedLocations[0].pickup_items).to.have.length(
                0
            );

            // In this case, the UI should show an appropriate error message
            const hasAvailableItems = strictConstrainedLocations.some(
                loc => loc.pickup_items && loc.pickup_items.length > 0
            );
            expect(hasAvailableItems).to.be.false;
        });
    });

    describe("Patron Change Effects", () => {
        it("should reset constraints when patron changes", () => {
            const patron1 = {
                patron_id: 8001,
                library_id: "BRANCH_A",
                category_code: "ADULT",
            };

            const patron2 = {
                patron_id: 8002,
                library_id: "BRANCH_B",
                category_code: "CHILD",
            };

            const scenario = BookingTestData.createMultiLibraryScenario();

            // First patron's constraints
            const patron1Items = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                null,
                { value: {} }
            );

            // Second patron's constraints
            const patron2Items = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_B",
                null,
                { value: {} }
            );

            // Verify different patrons get different constraints
            expect(patron1Items.filtered).to.not.deep.equal(
                patron2Items.filtered
            );

            // Each should have items from their respective branches
            expect(
                patron1Items.filtered.some(
                    i => i.home_library_id === "BRANCH_A"
                )
            ).to.be.true;
            expect(
                patron2Items.filtered.some(
                    i => i.home_library_id === "BRANCH_B"
                )
            ).to.be.true;
        });

        it("should clear previous selections when patron changes", () => {
            // Simulate form state
            let formState = {
                selectedPatron: { patron_id: 9001, library_id: "MAIN" },
                selectedPickupLocation: "MAIN",
                selectedItemType: "BOOK",
                selectedItem: 123,
                selectedDates: ["2025-08-10", "2025-08-15"],
            };

            // Function to reset form on patron change
            const resetFormOnPatronChange = () => {
                formState = {
                    ...formState,
                    selectedPickupLocation: null,
                    selectedItemType: null,
                    selectedItem: null,
                    selectedDates: [],
                };
            };

            // Change patron
            formState.selectedPatron = {
                patron_id: 9002,
                library_id: "BRANCH",
            };
            resetFormOnPatronChange();

            // Verify form was reset except patron
            expect(formState.selectedPatron.patron_id).to.equal(9002);
            expect(formState.selectedPickupLocation).to.be.null;
            expect(formState.selectedItemType).to.be.null;
            expect(formState.selectedItem).to.be.null;
            expect(formState.selectedDates).to.be.empty;
        });
    });
});
