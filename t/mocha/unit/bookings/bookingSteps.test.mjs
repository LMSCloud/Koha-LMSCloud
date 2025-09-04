/**
 * Unit tests for booking step calculation pure functions
 */

import { describe, it } from "mocha";
import { expect } from "chai";
import {
    calculateStepNumbers,
    shouldShowAdditionalFields,
} from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/steps.mjs";

describe("Booking Step Calculation Pure Functions", () => {
    describe("calculateStepNumbers", () => {
        it("should assign sequential step numbers when all sections are shown", () => {
            const result = calculateStepNumbers(true, true, true, true, true);

            expect(result).to.deep.equal({
                patron: 1,
                details: 2,
                period: 3,
                additionalFields: 4,
            });
        });

        it("should skip patron step when not shown", () => {
            const result = calculateStepNumbers(false, true, true, true, true);

            expect(result).to.deep.equal({
                patron: 0,
                details: 1,
                period: 2,
                additionalFields: 3,
            });
        });

        it("should skip details step when neither item details nor pickup location are shown", () => {
            const result = calculateStepNumbers(true, false, false, true, true);

            expect(result).to.deep.equal({
                patron: 1,
                details: 0,
                period: 2,
                additionalFields: 3,
            });
        });

        it("should show details step when only item details are shown", () => {
            const result = calculateStepNumbers(true, true, false, true, true);

            expect(result).to.deep.equal({
                patron: 1,
                details: 2,
                period: 3,
                additionalFields: 4,
            });
        });

        it("should show details step when only pickup location is shown", () => {
            const result = calculateStepNumbers(true, false, true, true, true);

            expect(result).to.deep.equal({
                patron: 1,
                details: 2,
                period: 3,
                additionalFields: 4,
            });
        });

        it("should skip additional fields when showAdditionalFields is false", () => {
            const result = calculateStepNumbers(true, true, true, false, true);

            expect(result).to.deep.equal({
                patron: 1,
                details: 2,
                period: 3,
                additionalFields: 0,
            });
        });

        it("should skip additional fields when hasAdditionalFields is false", () => {
            const result = calculateStepNumbers(true, true, true, true, false);

            expect(result).to.deep.equal({
                patron: 1,
                details: 2,
                period: 3,
                additionalFields: 0,
            });
        });

        it("should only show period step when all other steps are disabled", () => {
            const result = calculateStepNumbers(
                false,
                false,
                false,
                false,
                false
            );

            expect(result).to.deep.equal({
                patron: 0,
                details: 0,
                period: 1,
                additionalFields: 0,
            });
        });

        it("should handle mixed configurations correctly", () => {
            // Show patron and period, but not details or additional fields
            const result = calculateStepNumbers(
                true,
                false,
                false,
                true,
                false
            );

            expect(result).to.deep.equal({
                patron: 1,
                details: 0,
                period: 2,
                additionalFields: 0,
            });
        });
    });

    describe("shouldShowAdditionalFields", () => {
        it("should return true when both flags are true", () => {
            const result = shouldShowAdditionalFields(true, true);
            expect(result).to.be.true;
        });

        it("should return false when showAdditionalFields is false", () => {
            const result = shouldShowAdditionalFields(false, true);
            expect(result).to.be.false;
        });

        it("should return false when hasAdditionalFields is false", () => {
            const result = shouldShowAdditionalFields(true, false);
            expect(result).to.be.false;
        });

        it("should return false when both flags are false", () => {
            const result = shouldShowAdditionalFields(false, false);
            expect(result).to.be.false;
        });
    });
});
