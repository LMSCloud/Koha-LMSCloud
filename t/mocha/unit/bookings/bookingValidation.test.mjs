/**
 * Unit tests for booking validation pure functions
 */

import { describe, it } from "mocha";
import { expect } from "chai";
import {
    canProceedToStep3,
    canSubmitBooking,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/bookingValidation.mjs";

describe("Booking Validation Pure Functions", () => {
    describe("canProceedToStep3", () => {
        it("should return true when all required conditions are met", () => {
            const validationData = {
                showPatronSelect: true,
                bookingPatron: { id: 1, name: "Test Patron" },
                showItemDetailsSelects: true,
                showPickupLocationSelect: true,
                pickupLibraryId: "CPL",
                bookingItemtypeId: "BOOK",
                itemtypeOptions: [{ value: "BOOK", label: "Books" }],
                bookingItemId: "123",
                bookableItems: [{ item_id: "123", title: "Test Item" }],
            };

            const result = canProceedToStep3(validationData);
            expect(result).to.be.true;
        });

        it("should return false when patron is required but not selected", () => {
            const validationData = {
                showPatronSelect: true,
                bookingPatron: null,
                showItemDetailsSelects: false,
                showPickupLocationSelect: false,
                pickupLibraryId: null,
                bookingItemtypeId: null,
                itemtypeOptions: [],
                bookingItemId: null,
                bookableItems: [{ item_id: "123", title: "Test Item" }],
            };

            const result = canProceedToStep3(validationData);
            expect(result).to.be.false;
        });

        it("should return false when pickup location is required but not selected", () => {
            const validationData = {
                showPatronSelect: false,
                bookingPatron: null,
                showItemDetailsSelects: false,
                showPickupLocationSelect: true,
                pickupLibraryId: null,
                bookingItemtypeId: null,
                itemtypeOptions: [],
                bookingItemId: null,
                bookableItems: [{ item_id: "123", title: "Test Item" }],
            };

            const result = canProceedToStep3(validationData);
            expect(result).to.be.false;
        });

        it("should return false when item type is required but not selected", () => {
            const validationData = {
                showPatronSelect: false,
                bookingPatron: null,
                showItemDetailsSelects: true,
                showPickupLocationSelect: false,
                pickupLibraryId: null,
                bookingItemtypeId: null,
                itemtypeOptions: [{ value: "BOOK", label: "Books" }],
                bookingItemId: null,
                bookableItems: [{ item_id: "123", title: "Test Item" }],
            };

            const result = canProceedToStep3(validationData);
            expect(result).to.be.false;
        });

        it("should return false when item is required but not selected", () => {
            const validationData = {
                showPatronSelect: false,
                bookingPatron: null,
                showItemDetailsSelects: true,
                showPickupLocationSelect: false,
                pickupLibraryId: null,
                bookingItemtypeId: "BOOK",
                itemtypeOptions: [{ value: "BOOK", label: "Books" }],
                bookingItemId: null,
                bookableItems: [{ item_id: "123", title: "Test Item" }],
            };

            const result = canProceedToStep3(validationData);
            expect(result).to.be.false;
        });

        it("should return false when no bookable items are available", () => {
            const validationData = {
                showPatronSelect: false,
                bookingPatron: null,
                showItemDetailsSelects: false,
                showPickupLocationSelect: false,
                pickupLibraryId: null,
                bookingItemtypeId: null,
                itemtypeOptions: [],
                bookingItemId: null,
                bookableItems: [],
            };

            const result = canProceedToStep3(validationData);
            expect(result).to.be.false;
        });

        it("should handle optional fields correctly when not required", () => {
            const validationData = {
                showPatronSelect: false,
                bookingPatron: null,
                showItemDetailsSelects: false,
                showPickupLocationSelect: false,
                pickupLibraryId: null,
                bookingItemtypeId: null,
                itemtypeOptions: [],
                bookingItemId: null,
                bookableItems: [{ item_id: "123", title: "Test Item" }],
            };

            const result = canProceedToStep3(validationData);
            expect(result).to.be.true;
        });
    });

    describe("canSubmitBooking", () => {
        const baseValidationData = {
            showPatronSelect: false,
            bookingPatron: null,
            showItemDetailsSelects: false,
            showPickupLocationSelect: false,
            pickupLibraryId: null,
            bookingItemtypeId: null,
            itemtypeOptions: [],
            bookingItemId: null,
            bookableItems: [{ item_id: "123", title: "Test Item" }],
        };

        it("should return true when step 3 validation passes and dates are provided", () => {
            const dateRange = ["2024-01-15", "2024-01-17"];
            const result = canSubmitBooking(baseValidationData, dateRange);
            expect(result).to.be.true;
        });

        it("should return false when step 3 validation fails", () => {
            const invalidData = {
                ...baseValidationData,
                bookableItems: [], // No bookable items
            };
            const dateRange = ["2024-01-15", "2024-01-17"];
            const result = canSubmitBooking(invalidData, dateRange);
            expect(result).to.be.false;
        });

        it("should return false when no date range is provided", () => {
            const result = canSubmitBooking(baseValidationData, null);
            expect(result).to.be.false;
        });

        it("should return false when empty date range is provided", () => {
            const result = canSubmitBooking(baseValidationData, []);
            expect(result).to.be.false;
        });

        it("should return false when incomplete date range is provided", () => {
            const dateRange = ["2024-01-15"]; // Only start date
            const result = canSubmitBooking(baseValidationData, dateRange);
            expect(result).to.be.false;
        });
    });
});
