import { describe, it } from "mocha";
import { expect } from "chai";
import { ref } from "vue";
import { useRulesFetcher } from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/composables/useRulesFetcher.mjs";

function delay(ms = 0) {
    return new Promise(res => setTimeout(res, ms));
}

function createMockStore(callLog) {
    return {
        holidays: [],
        invalidateCalculatedDue: () => callLog.push({ name: "invalidateCalculatedDue" }),
        fetchCirculationRules: params => callLog.push({ name: "fetchCirculationRules", params }),
        fetchPickupLocations: (biblio, patronId) =>
            callLog.push({ name: "fetchPickupLocations", biblio, patronId }),
        fetchHolidays: libraryId =>
            callLog.push({ name: "fetchHolidays", libraryId }),
    };
}

describe("useRulesFetcher", () => {
    it("builds stable keys, invalidates before fetching, and de-dupes", async () => {
        const calls = [];
        const store = createMockStore(calls);

        // Reactive inputs
        const bookingPatron = ref({ patron_id: 42, category_id: "ADU" });
        const bookingPickupLibraryId = ref("MAIN");
        const bookingItemtypeId = ref(null);
        const constrainedItemTypes = ref([{ item_type_id: "BOOK" }]);
        const selectedDateRange = ref(["2025-10-27T00:00:00.000Z"]);
        const biblionumber = "B1";

        const { lastRulesKey } = useRulesFetcher({
            store,
            bookingPatron,
            bookingPickupLibraryId,
            bookingItemtypeId,
            constrainedItemTypes,
            selectedDateRange,
            biblionumber,
        });

        await delay(0);

        // Expect key pc, it (derived from constrainedItemTypes), lib, start
        expect(lastRulesKey.value).to.equal(
            "pc=ADU|it=BOOK|lib=MAIN|start=2025-10-27T00:00:00.000Z"
        );

        // First run should invalidate then fetch rules
        const firstInvalidateIdx = calls.findIndex(c => c.name === "invalidateCalculatedDue");
        const firstFetchIdx = calls.findIndex(c => c.name === "fetchCirculationRules");
        expect(firstInvalidateIdx).to.be.greaterThan(-1);
        expect(firstFetchIdx).to.be.greaterThan(-1);
        expect(firstInvalidateIdx).to.be.lessThan(firstFetchIdx);

        // Adding an end date does not change key (uses start only) => no extra fetch
        calls.length = 0; // reset log
        selectedDateRange.value = [
            "2025-10-27T00:00:00.000Z",
            "2025-10-31T00:00:00.000Z",
        ];
        await delay(0);
        expect(lastRulesKey.value).to.equal(
            "pc=ADU|it=BOOK|lib=MAIN|start=2025-10-27T00:00:00.000Z"
        );
        expect(calls.some(c => c.name === "fetchCirculationRules")).to.equal(false);

        // Changing library should update key and trigger invalidate + fetch in order
        bookingPickupLibraryId.value = "BR1";
        await delay(0);
        expect(lastRulesKey.value).to.equal(
            "pc=ADU|it=BOOK|lib=BR1|start=2025-10-27T00:00:00.000Z"
        );
        const invIdx = calls.findIndex(c => c.name === "invalidateCalculatedDue");
        const fetchIdx = calls.findIndex(c => c.name === "fetchCirculationRules");
        expect(invIdx).to.be.greaterThan(-1);
        expect(fetchIdx).to.be.greaterThan(-1);
        expect(invIdx).to.be.lessThan(fetchIdx);
    });

    it("omits undefined params from the key (no empty separators)", async () => {
        const calls = [];
        const store = createMockStore(calls);

        const bookingPatron = ref({ patron_id: 77, category_id: "STU" });
        const bookingPickupLibraryId = ref("MAIN");
        const bookingItemtypeId = ref(null);
        // No single constrained type => derived item_type_id is undefined
        const constrainedItemTypes = ref([ { item_type_id: "BOOK" }, { item_type_id: "DVD" } ]);
        const selectedDateRange = ref(["2025-11-03T00:00:00.000Z"]);
        const biblionumber = "B2";

        const { lastRulesKey } = useRulesFetcher({
            store,
            bookingPatron,
            bookingPickupLibraryId,
            bookingItemtypeId,
            constrainedItemTypes,
            selectedDateRange,
            biblionumber,
        });

        await delay(0);

        // it=... omitted, no double separators
        expect(lastRulesKey.value).to.equal(
            "pc=STU|lib=MAIN|start=2025-11-03T00:00:00.000Z"
        );
    });
});

