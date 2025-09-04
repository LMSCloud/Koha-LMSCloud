import { expect } from "chai";
import dayjs from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/utils/dayjs.mjs";
import { deriveEffectiveRules, calculateAvailabilityData } from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/manager.mjs";

describe("Unconstrained preference behavior", () => {
    describe("deriveEffectiveRules", () => {
        it("should strip caps when dateRangeConstraint is null (Don't constrain)", () => {
            const constraintOptions = {
                dateRangeConstraint: null,
                maxBookingPeriod: 10,
            };
            const baseRules = { issuelength: 5, maxPeriod: 7 };
            const effective = deriveEffectiveRules(baseRules, constraintOptions);
            expect(effective).to.not.have.property("maxPeriod");
            expect(effective).to.not.have.property("issuelength");
        });

        it("should apply cap only for constraining modes (issuelength, issuelength_with_renewals)", () => {
            const constraintOptions = {
                dateRangeConstraint: "issuelength",
                maxBookingPeriod: 12,
            };
            const baseRules = { issuelength: 5 };
            const effective = deriveEffectiveRules(baseRules, constraintOptions);
            expect(effective).to.have.property("maxPeriod", 12);
        });
    });

    describe("calculateAvailabilityData", () => {
        const makeStore = (rulesObj = {}) => ({
            bookings: [],
            checkouts: [],
            bookableItems: [
                {
                    item_id: 1,
                    title: "A",
                    item_type_id: 1,
                    holding_library: "CPL",
                    available_pickup_locations: [],
                },
            ],
            bookingItemId: 1,
            bookingId: null,
            circulationRules: [rulesObj],
        });

        it("should not enforce max period when preference is Don't constrain", () => {
            const store = makeStore({ issuelength: 5 });

            const start = dayjs().startOf("day");
            const availability = calculateAvailabilityData([start.toISOString()], store, { dateRangeConstraint: null });

            const farEnd = start.add(20, "day").toDate();
            const disabled = availability.disable(farEnd);
            expect(disabled).to.equal(false);
        });

        it("should enforce max period when preference is issuelength", () => {
            const store = makeStore({ issuelength: 5 });

            const start = dayjs().startOf("day");
            const availability = calculateAvailabilityData([start.toISOString()], store, { dateRangeConstraint: "issuelength" });

            const within = start.add(4, "day").toDate();
            const beyond = start.add(6, "day").toDate();
            expect(availability.disable(within)).to.equal(false);
            expect(availability.disable(beyond)).to.equal(true);
        });
    });
});
