/**
 * Direct unit tests for the pure helpers in
 * koha-tmpl/opac-tmpl/bootstrap/js/LMSCoverFlow.js.
 *
 * The helpers live inside the UMD factory (so they don't leak to the global
 * scope) and are exposed for testing through the internal `_internals` export.
 * Anything not on `_internals` is only reachable through the behavioural
 * characterization tests in LMSCoverFlow.test.mjs.
 */

import mocha from "mocha";
import * as chai from "chai";
import jsdom from "jsdom";
import rewire from "rewire";
import { fileURLToPath } from "url";
import { resolve, dirname } from "path";

const { JSDOM } = jsdom;
const { expect } = chai;
const { describe, it, before } = mocha;

const __dirname = dirname(fileURLToPath(import.meta.url));
const LCF_PATH = resolve(
    __dirname,
    "../../../koha-tmpl/opac-tmpl/bootstrap/js/LMSCoverFlow.js"
);

const dom = new JSDOM("<!DOCTYPE html><html><body></body></html>");
global.window = dom.window;
global.document = dom.window.document;
global.HTMLElement = dom.window.HTMLElement;

// classList[1] is the second class on the node; getLcfItemId reads the id from there.
function nodeWithClasses(...classes) {
    const el = document.createElement("div");
    el.classList.add(...classes);
    return el;
}

describe("LMSCoverFlow internals (_internals helpers)", () => {
    let mod;

    before(() => {
        mod = rewire(LCF_PATH);
    });

    describe("getLcfItemId", () => {
        it("returns the id class (2nd class) when it matches _<7 digits>", () => {
            const getLcfItemId = mod._internals.getLcfItemId;
            expect(
                getLcfItemId(nodeWithClasses("lcfItemContainer", "_1234567"))
            ).to.equal("_1234567");
        });

        it("throws when the id class does not match the pattern", () => {
            const getLcfItemId = mod._internals.getLcfItemId;
            expect(() =>
                getLcfItemId(nodeWithClasses("lcfItemContainer", "nope"))
            ).to.throw("Id doesn't match pattern.");
        });
    });

    describe("pure computation helpers", () => {
        it("isPromise detects thenables", () => {
            const isPromise = mod._internals.isPromise;
            expect(isPromise(Promise.resolve())).to.equal(true);
            expect(isPromise({ then() {} })).to.equal(true);
            expect(isPromise({})).to.equal(false);
            expect(isPromise("x")).to.equal(false);
        });

        it("processHeights caps the tallest image at the fallback height", () => {
            const processHeights = mod._internals.processHeights;
            expect(
                processHeights([100, 180, 150], {
                    coverImageFallbackHeight: 210,
                })
            ).to.equal(180);
            expect(
                processHeights([100, 300, 150], {
                    coverImageFallbackHeight: 210,
                })
            ).to.equal(210);
            // null/NaN entries fall back to 0.
            expect(
                processHeights([null, 120], { coverImageFallbackHeight: 210 })
            ).to.equal(120);
        });

        it("flattenPromiseResults pulls .value out of each entry", () => {
            const flattenPromiseResults = mod._internals.flattenPromiseResults;
            expect(
                flattenPromiseResults([{ value: "a" }, { value: "b" }])
            ).to.deep.equal(["a", "b"]);
        });

        it("calculateCoverFlowPlusGaps sums widths plus one gap per card", () => {
            const calculateCoverFlowPlusGaps =
                mod._internals.calculateCoverFlowPlusGaps;
            // (100 + 200 + 300) widths + 3 gaps of 10 = 630
            expect(calculateCoverFlowPlusGaps([100, 200, 300], 10)).to.equal(
                630
            );
        });

        it("resyncExecution resolves after the delay", async () => {
            const resyncExecution = mod._internals.resyncExecution;
            const result = await resyncExecution(0);
            expect(result).to.equal(undefined);
        });

        it("generateId produces an id matching the getLcfItemId pattern", () => {
            const generateId = mod._internals.generateId;
            const getLcfItemId = mod._internals.getLcfItemId;
            const id = generateId();
            expect(id).to.match(/^_[0-9]{7}$/);
            // round-trip: an id generated here is accepted by the id reader.
            expect(
                getLcfItemId(nodeWithClasses("lcfItemContainer", id))
            ).to.equal(id);
        });

        it("shouldScrollShelfBrowserIntoView scrolls only on the initial open", () => {
            const fn = mod._internals.shouldScrollShelfBrowserIntoView;
            // initial open: flag on, not extending -> scroll
            expect(
                fn({
                    shelfBrowserScrollIntoView: true,
                    shelfBrowserExtendedCoverFlow: false,
                })
            ).to.equal(true);
            // paging / load-more: extending -> do NOT scroll (page-jump fix)
            expect(
                fn({
                    shelfBrowserScrollIntoView: true,
                    shelfBrowserExtendedCoverFlow: true,
                })
            ).to.equal(false);
            // feature off -> never scroll
            expect(
                fn({
                    shelfBrowserScrollIntoView: false,
                    shelfBrowserExtendedCoverFlow: false,
                })
            ).to.equal(false);
            expect(fn({})).to.equal(false);
        });
    });

    describe("request-URI builders", () => {
        it("nearbyItemsRequestURI uses the default endpoint and appends quantity", () => {
            const nearbyItemsRequestURI = mod._internals.nearbyItemsRequestURI;
            expect(
                nearbyItemsRequestURI({ itemnumber: 42, quantity: 7 })
            ).to.equal(
                "/api/v1/public/coverflow_data_nearby_items/42?quantity=7"
            );
            expect(
                nearbyItemsRequestURI({
                    endpoint: "/x/",
                    itemnumber: 1,
                    quantity: 2,
                })
            ).to.equal("/x/1?quantity=2");
        });

        it("generatedCoverRequestURI encodes title/author and omits absent ones", () => {
            const generatedCoverRequestURI =
                mod._internals.generatedCoverRequestURI;
            expect(
                generatedCoverRequestURI({ title: "A B", author: "C&D" })
            ).to.equal(
                "/api/v1/public/generated_cover?title=A%20B&author=C%26D"
            );
            expect(generatedCoverRequestURI({})).to.equal(
                "/api/v1/public/generated_cover"
            );
        });

        it("byQueryRequestURI composes query/offset/maxcount", () => {
            const byQueryRequestURI = mod._internals.byQueryRequestURI;
            expect(
                byQueryRequestURI({ query: "cats", offset: 0, maxcount: 10 })
            ).to.equal(
                "/api/v1/public/coverflow_data_query?query=cats&offset=0&maxcount=10"
            );
        });
    });

    describe("attribute-instruction engine", () => {
        it("describeArgShape flags whether attribute and data are arrays", () => {
            const describeArgShape = mod._internals.describeArgShape;
            expect(describeArgShape("href", "x")).to.deep.equal([false, false]);
            expect(describeArgShape(["a", "b"], "x")).to.deep.equal([
                true,
                false,
            ]);
            expect(describeArgShape("src", ["x", "y"])).to.deep.equal([
                false,
                true,
            ]);
        });

        it("isTextContent recognises the textContent sink", () => {
            const isTextContent = mod._internals.isTextContent;
            expect(isTextContent("textContent")).to.equal(true);
            expect(isTextContent("href")).to.equal(false);
        });

        it("instructionsForClass reads an instruction out of the map", () => {
            const instructionsForClass = mod._internals.instructionsForClass;
            const map = new Map([["lcfAnchor", ["href", "/x"]]]);
            expect(instructionsForClass("lcfAnchor", map)).to.deep.equal([
                "href",
                "/x",
            ]);
            expect(instructionsForClass("missing", map)).to.equal(undefined);
        });

        it("additionalProperties builds data-* pairs, or undefined when absent", () => {
            const additionalProperties = mod._internals.additionalProperties;
            expect(
                additionalProperties({
                    additionalProperties: { foo: "bar", n: 1 },
                })
            ).to.deep.equal([
                ["data-foo", "bar"],
                ["data-n", 1],
            ]);
            expect(additionalProperties({})).to.equal(undefined);
        });

        it("attributeInstructionsFor maps aspect classes to instructions", () => {
            const attributeInstructionsFor =
                mod._internals.attributeInstructionsFor;
            const map = attributeInstructionsFor({
                title: "Alpha",
                author: "A. Uthor",
                itemCallNumber: "QA 1",
                referenceToDetailsView: "/detail?biblionumber=11",
                coverurl: "http://x/c.jpg?a=1&amp;b=2",
            });
            expect(map.get("lcfAnchor")).to.deep.equal([
                "href",
                "/detail?biblionumber=11",
            ]);
            // &amp; is normalised back to & in the cover src.
            expect(map.get("lcfCoverImage")).to.deep.equal([
                "src",
                "http://x/c.jpg?a=1&b=2",
            ]);
            expect(map.get("lcfMediaTitle")).to.deep.equal([
                ["textContent", "data-text"],
                "Alpha",
            ]);
            expect(map.get("lcfMediaISBD")).to.deep.equal([
                "textContent",
                "A. Uthor: Alpha",
            ]);
        });

        describe("applyInstructions", () => {
            let applyInstructions;
            before(() => {
                applyInstructions = mod._internals.applyInstructions;
            });

            it("sets a scalar attribute", () => {
                const el = document.createElement("a");
                applyInstructions(el, ["href", "/detail"]);
                expect(el.getAttribute("href")).to.equal("/detail");
            });

            it("routes a scalar textContent instruction to textContent", () => {
                const el = document.createElement("p");
                applyInstructions(el, ["textContent", "Alpha"]);
                expect(el.textContent).to.equal("Alpha");
                expect(el.getAttribute("textContent")).to.equal(null);
            });

            it("applies one value across several attributes (attribute is array)", () => {
                const el = document.createElement("p");
                applyInstructions(el, [["textContent", "data-text"], "Alpha"]);
                expect(el.textContent).to.equal("Alpha");
                expect(el.getAttribute("data-text")).to.equal("Alpha");
            });

            it("applies several values to one attribute (data is array)", () => {
                const el = document.createElement("div");
                applyInstructions(el, ["data-x", ["1", "2"]]);
                // last write wins for a repeated attribute
                expect(el.getAttribute("data-x")).to.equal("2");
            });

            it("applies paired attribute/value lists (both arrays)", () => {
                const el = document.createElement("div");
                applyInstructions(el, [
                    ["href", "/x"],
                    ["data-y", "z"],
                ]);
                expect(el.getAttribute("href")).to.equal("/x");
                expect(el.getAttribute("data-y")).to.equal("z");
            });
        });
    });
});
