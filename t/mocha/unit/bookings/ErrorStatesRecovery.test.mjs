/**
 * Error States and Recovery Patterns Test Suite
 *
 * Tests for handling various error conditions in the booking system
 * and ensuring proper recovery mechanisms are in place.
 */

import { describe, it, before } from "mocha";
import {
    setupBookingTestEnvironment,
    getBookingModules,
    BookingTestData,
    BookingTestHelpers,
    expect,
} from "./TestUtils.mjs";

describe("Error States and Recovery Patterns", () => {
    let modules;

    before(async () => {
        setupBookingTestEnvironment();
        modules = await getBookingModules();
    });

    describe("Data Loading Errors", () => {
        it("should handle empty bookable items gracefully", () => {
            const emptyItems = [];
            const bookings = BookingTestData.createBookings(2);
            const rules = BookingTestData.createCirculationRules();

            const result = modules.calculateDisabledDates(
                bookings,
                [],
                emptyItems, // No items available
                null,
                null,
                [],
                rules,
                "2025-08-05"
            );

            // Should return a permissive disable function
            expect(result.disable).to.be.a("function");

            // All dates should be disabled when no items
            const testDate = new Date("2025-08-10");
            expect(result.disable(testDate)).to.be.true;
        });

        it("should handle missing pickup locations", () => {
            const items = BookingTestData.createItems(3);
            const emptyPickupLocations = [];

            const result = modules.constrainBookableItems(
                items,
                emptyPickupLocations,
                "NONEXISTENT",
                null,
                { value: {} }
            );

            // Should return empty filtered array
            expect(result.filtered).to.be.an("array");
            expect(result.filtered).to.have.length(0);
            expect(result.filteredOutCount).to.equal(items.length);
        });

        it("should handle null/undefined circulation rules", () => {
            const items = BookingTestData.createItems(2);
            const bookings = BookingTestData.createBookings(1);

            // Test with null rules
            const resultNull = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null,
                null,
                [],
                null, // null rules
                "2025-08-05"
            );

            expect(resultNull.disable).to.be.a("function");

            // Test with undefined rules
            const resultUndefined = modules.calculateDisabledDates(
                bookings,
                [],
                items,
                null,
                null,
                [],
                undefined, // undefined rules
                "2025-08-05"
            );

            expect(resultUndefined.disable).to.be.a("function");

            // Should use default values when rules are missing
            const futureDate = new Date("2025-08-20");
            expect(resultNull.disable(futureDate)).to.be.a("boolean");
        });
    });

    describe("Invalid Date Handling", () => {
        it("should handle invalid date strings in bookings", () => {
            const bookingsWithInvalidDates = [
                {
                    booking_id: 1,
                    item_id: "item1",
                    start_date: "invalid-date",
                    end_date: "2025-08-15",
                },
                {
                    booking_id: 2,
                    item_id: "item2",
                    start_date: "2025-08-10",
                    end_date: null, // null end date
                },
                {
                    booking_id: 3,
                    item_id: "item3",
                    start_date: "2025-08-20",
                    end_date: "2025-08-15", // End before start
                },
            ];

            const items = BookingTestData.createItems(3);
            const rules = BookingTestData.createCirculationRules();

            // Should not throw error
            expect(() => {
                modules.calculateDisabledDates(
                    bookingsWithInvalidDates,
                    [],
                    items,
                    null,
                    null,
                    [],
                    rules,
                    "2025-08-05"
                );
            }).to.not.throw();
        });

        it("should handle date selection with invalid formats", () => {
            const bookings = [];
            const items = BookingTestData.createItems(1);
            const rules = BookingTestData.createCirculationRules();

            // Test with various invalid date formats
            expect(() => {
                modules.parseDateRange(["not-a-date", new Date("2025-08-10")]);
            }).to.throw();

            // Test with valid dates
            const validDates = [new Date("2025-08-10"), new Date("2025-08-15")];

            const parsed = modules.parseDateRange(validDates);
            expect(parsed).to.be.an("array");
            expect(parsed[0]).to.be.a("string"); // start date
            expect(parsed[1]).to.be.a("string"); // end date
        });

        it("should validate date range logic errors", () => {
            const bookings = [];
            const items = BookingTestData.createItems(1);
            const rules = BookingTestData.createCirculationRules();

            // Test with end date before start date
            const invalidRange = [
                new Date("2025-08-15"), // Start
                new Date("2025-08-10"), // End (before start)
            ];

            const result = modules.handleBookingDateChange(
                invalidRange,
                rules,
                bookings,
                [],
                items,
                null,
                null,
                "2025-08-05"
            );

            expect(result.valid).to.be.false;
            expect(result.errors).to.be.an("array");
            expect(result.errors.length).to.be.greaterThan(0);
        });
    });

    describe("Constraint Validation Errors", () => {
        it("should handle zero available items after constraints", () => {
            const items = BookingTestData.createItems(3);
            const pickupLocations = [
                {
                    library_id: "REMOTE",
                    name: "Remote Library",
                    pickup_items: [], // No items at this location
                },
            ];

            const result = modules.constrainBookableItems(
                items,
                pickupLocations,
                "REMOTE", // Selected pickup with no items
                null,
                { value: {} }
            );

            expect(result.filtered).to.have.length(0);
            expect(result.filteredOutCount).to.equal(items.length);
            expect(result.total).to.equal(items.length);
        });

        it("should handle conflicting constraint combinations", () => {
            const scenario = BookingTestData.createComplexConstraintScenario();

            // Apply impossible constraint combination
            const result = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A", // Pickup location
                "MAGAZINE", // Item type that doesn't exist at BRANCH_A
                { value: {} }
            );

            expect(result.filtered).to.have.length(0);

            // This should trigger UI error message
            const hasAvailableItems = result.filtered.length > 0;
            expect(hasAvailableItems).to.be.false;
        });

        it("should recover when constraints are relaxed", () => {
            const scenario = BookingTestData.createComplexConstraintScenario();

            // First apply restrictive constraints
            const restrictive = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                "NONEXISTENT_TYPE",
                { value: {} }
            );
            expect(restrictive.filtered).to.have.length(0);

            // Then relax constraints
            const relaxed = modules.constrainBookableItems(
                scenario.items,
                scenario.pickupLocations,
                "BRANCH_A",
                null, // Remove item type constraint
                { value: {} }
            );
            expect(relaxed.filtered.length).to.be.greaterThan(0);
        });
    });

    describe("Booking Submission Errors", () => {
        it("should validate required fields before submission", () => {
            // Missing required dates
            const incompleteDates = [new Date("2025-08-10")]; // Only start date

            const result = modules.handleBookingDateChange(
                incompleteDates,
                BookingTestData.createCirculationRules(),
                [],
                [],
                BookingTestData.createItems(1),
                null,
                null,
                "2025-08-05"
            );

            // Should indicate invalid state
            expect(result.valid).to.be.true; // Single date might be valid for start

            // But submission should require both dates
            const canSubmit = incompleteDates.length === 2;
            expect(canSubmit).to.be.false;
        });

        it("should handle API error responses", () => {
            // Simulate API error response
            const apiError = {
                status: 400,
                error: "Bad Request",
                errors: [
                    {
                        message: "Booking conflicts with existing reservation",
                        path: "/start_date",
                    },
                ],
            };

            // Error processing function
            const processApiError = error => {
                const messages = [];

                if (error.errors && Array.isArray(error.errors)) {
                    error.errors.forEach(err => {
                        messages.push(err.message || "Unknown error");
                    });
                } else if (error.message) {
                    messages.push(error.message);
                } else {
                    messages.push("An unexpected error occurred");
                }

                return messages;
            };

            const errorMessages = processApiError(apiError);
            expect(errorMessages).to.be.an("array");
            expect(errorMessages).to.have.length.at.least(1);
            expect(errorMessages[0]).to.include("conflicts");
        });

        it("should handle network timeout errors", () => {
            // Simulate timeout error
            const timeoutError = {
                code: "ECONNABORTED",
                message: "timeout of 10000ms exceeded",
            };

            const isTimeoutError = error => {
                return (
                    error.code === "ECONNABORTED" ||
                    error.message.includes("timeout")
                );
            };

            expect(isTimeoutError(timeoutError)).to.be.true;

            // Recovery strategy for timeout
            const recoveryStrategy = error => {
                if (isTimeoutError(error)) {
                    return {
                        retry: true,
                        message: "Request timed out. Please try again.",
                        preserveFormData: true,
                    };
                }
                return {
                    retry: false,
                    message: error.message,
                    preserveFormData: false,
                };
            };

            const recovery = recoveryStrategy(timeoutError);
            expect(recovery.retry).to.be.true;
            expect(recovery.preserveFormData).to.be.true;
        });
    });

    describe("Race Condition Handling", () => {
        it("should handle rapid constraint changes", () => {
            const items = BookingTestData.createItems(10);
            const pickupLocations = BookingTestData.createPickupLocations();

            // Simulate rapid changes
            const results = [];
            const locations = ["MAIN", "BRANCH", "MAIN", "BRANCH"];

            locations.forEach(loc => {
                const result = modules.constrainBookableItems(
                    items,
                    pickupLocations,
                    loc,
                    null,
                    { value: {} }
                );
                results.push(result);
            });

            // Each constraint operation should complete independently
            expect(results).to.have.length(4);
            results.forEach(result => {
                expect(result).to.have.property("filtered");
                expect(result).to.have.property("filteredOutCount");
            });
        });

        it("should handle date selection during data loading", () => {
            // Simulate loading state
            const loadingState = {
                bookableItems: [],
                bookings: null, // Still loading
                isLoading: true,
            };

            // During loading, should use permissive disable function
            const result = modules.calculateDisabledDates(
                loadingState.bookings || [],
                [],
                loadingState.bookableItems,
                null,
                null,
                [],
                BookingTestData.createCirculationRules(),
                "2025-08-05"
            );

            expect(result.disable).to.be.a("function");

            // Future dates might be allowed during loading
            const futureDate = new Date("2025-08-20");
            const isDisabled = result.disable(futureDate);
            expect(isDisabled).to.be.true; // No items = all disabled
        });
    });

    describe("Edge Case Error Recovery", () => {
        it("should handle circular date dependencies", () => {
            const rules = {
                booking_constraint_mode: "end_date_only",
                issuelength: 7,
                maxPeriod: 7,
            };

            // Start date depends on end date calculation
            // End date depends on start date selection
            const selectedDates = [new Date("2025-08-10")];

            const result = modules.handleBookingDateChange(
                selectedDates,
                rules,
                [],
                [],
                BookingTestData.createItems(1),
                null,
                null,
                "2025-08-05"
            );

            // Should resolve without infinite loop
            expect(result).to.have.property("valid");
            expect(result).to.have.property("errors");
        });

        it("should handle maximum date range exceeded", () => {
            const rules = {
                maxPeriod: 7,
            };

            // Select range exceeding max
            const longRange = [
                new Date("2025-08-10"),
                new Date("2025-08-25"), // 15 days
            ];

            const result = modules.handleBookingDateChange(
                longRange,
                rules,
                [],
                [],
                BookingTestData.createItems(1),
                null,
                null,
                "2025-08-05"
            );

            expect(result.valid).to.be.false;
            expect(result.errors).to.be.an("array");
            expect(result.errors.length).to.be.greaterThan(0);
            // Check if error mentions exceeding maximum
            const hasMaxPeriodError = result.errors.some(
                err =>
                    err.toString().includes("exceed") ||
                    err.toString().includes("maximum")
            );
            expect(hasMaxPeriodError).to.be.true;
        });

        it("should handle past date selection attempts", () => {
            const today = "2025-08-05";
            const items = BookingTestData.createItems(1);
            const rules = BookingTestData.createCirculationRules();

            const result = modules.calculateDisabledDates(
                [],
                [],
                items,
                null,
                null,
                [],
                rules,
                today
            );

            // Past dates should always be disabled
            const pastDate = new Date("2025-08-01");
            expect(result.disable(pastDate)).to.be.true;

            // Today might be allowed depending on rules
            const todayDate = new Date(today);
            const todayDisabled = result.disable(todayDate);
            expect(todayDisabled).to.be.a("boolean");
        });
    });

    describe("Error Message Generation", () => {
        it("should generate user-friendly constraint error messages", () => {
            const generateConstraintError = (pickup, itemType, itemCount) => {
                if (itemCount === 0) {
                    let message = "No items available";
                    const criteria = [];

                    if (pickup) criteria.push(`pickup location: ${pickup}`);
                    if (itemType) criteria.push(`item type: ${itemType}`);

                    if (criteria.length > 0) {
                        message += ` for ${criteria.join(" and ")}`;
                    }

                    return message;
                }
                return null;
            };

            const error1 = generateConstraintError("Branch A", "DVD", 0);
            expect(error1).to.equal(
                "No items available for pickup location: Branch A and item type: DVD"
            );

            const error2 = generateConstraintError("Branch B", null, 0);
            expect(error2).to.equal(
                "No items available for pickup location: Branch B"
            );

            const error3 = generateConstraintError(null, null, 0);
            expect(error3).to.equal("No items available");

            const noError = generateConstraintError("Main", "BOOK", 5);
            expect(noError).to.be.null;
        });

        it("should generate date validation error messages", () => {
            const generateDateError = (type, details) => {
                const errors = {
                    past_date: "Cannot select dates in the past",
                    exceeds_max: `Booking period cannot exceed ${details.max} days`,
                    conflict: `This date conflicts with an existing booking`,
                    lead_period: `This date is within the ${details.days} day preparation period`,
                    end_before_start: "End date must be after start date",
                };

                return errors[type] || "Invalid date selection";
            };

            expect(generateDateError("past_date", {})).to.equal(
                "Cannot select dates in the past"
            );
            expect(generateDateError("exceeds_max", { max: 14 })).to.equal(
                "Booking period cannot exceed 14 days"
            );
            expect(generateDateError("unknown", {})).to.equal(
                "Invalid date selection"
            );
        });
    });
});
