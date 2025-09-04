import { describe, it } from "mocha";
import { expect } from "chai";
import { idsEqual, includesId, toIdSet } from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/id-utils.mjs";

describe("idUtils helpers", () => {
    it("idsEqual normalizes string/number IDs", () => {
        expect(idsEqual("1", 1)).to.be.true;
        expect(idsEqual(0, false)).to.be.false;
        expect(idsEqual(null, 1)).to.be.false;
    });

    it("includesId checks inclusion with normalization", () => {
        expect(includesId([1, 2, 3], "2")).to.be.true;
        expect(includesId(["10"], 10)).to.be.true;
        expect(includesId(["a"], "b")).to.be.false;
    });

    it("toIdSet builds normalized Set", () => {
        const set = toIdSet([1, "1", 2]);
        expect(set.has("1")).to.be.true;
        expect(set.has("2")).to.be.true;
        expect(set.size).to.equal(2);
    });
});
