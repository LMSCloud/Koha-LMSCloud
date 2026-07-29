/**
 * Characterization tests for koha-tmpl/opac-tmpl/bootstrap/js/LMSCoverFlow.js
 *
 * These pin the *public* contract (exports, instance methods, config-key defaults) so the
 * module can be refactored internally without breaking its consumers:
 *   - opac-detail.tt (ShelfBrowser + createLcfInstance)
 *   - opac-user-recommendations.tt (createLcfInstance)
 *   - CoverFlowByQuery.js
 *   - the BibTip CDN script (createLcfInstance + setGlobals + render)
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

// --- Minimal browser environment needed to load/exercise the module ---
const dom = new JSDOM("<!DOCTYPE html><html><body></body></html>", {
    pretendToBeVisual: true,
});
const { window } = dom;

global.window = window;
global.document = window.document;
global.HTMLElement = window.HTMLElement;
global.getComputedStyle = window.getComputedStyle.bind(window);

// generateId() relies on window.crypto.getRandomValues.
if (!window.crypto) window.crypto = {};
if (!window.crypto.getRandomValues) {
    window.crypto.getRandomValues = arr => {
        for (let i = 0; i < arr.length; i += 1) {
            arr[i] = Math.floor(Math.random() * 256);
        }
        return arr;
    };
}

if (!window.requestAnimationFrame) {
    window.requestAnimationFrame = cb => setTimeout(() => cb(Date.now()), 0);
    global.requestAnimationFrame = window.requestAnimationFrame;
}

describe("LMSCoverFlow", () => {
    let mod;

    before(() => {
        mod = rewire(LCF_PATH);
    });

    describe("public export surface", () => {
        it("exposes createLcfInstance / ShelfBrowser / CoverflowByQuery / externalSources", () => {
            expect(mod.createLcfInstance, "createLcfInstance").to.be.a(
                "function"
            );
            expect(mod.ShelfBrowser, "ShelfBrowser").to.be.a("function");
            expect(mod.CoverflowByQuery, "CoverflowByQuery").to.be.a(
                "function"
            );
            expect(mod.externalSources, "externalSources").to.be.an("object");
        });
    });

    describe("instance API surface", () => {
        it("createLcfInstance() returns an instance exposing the documented methods", () => {
            const lcf = mod.createLcfInstance();
            ["setGlobals", "setConfig", "getConfig", "setData", "setContainer", "render"].forEach(
                method => {
                    expect(lcf[method], method).to.be.a("function");
                }
            );
        });

        it("getConfig() reflects the configuration passed via setGlobals()", () => {
            document.body.innerHTML = '<div id="lcf-api-test"></div>';
            const lcf = mod.createLcfInstance();
            lcf.setGlobals(
                { coverImageFallbackHeight: 123 },
                [],
                "lcf-api-test"
            );
            expect(lcf.getConfig()).to.include({ coverImageFallbackHeight: 123 });
        });
    });

    describe("render() rendered-DOM contract (behavioural)", () => {
        // Pins observable output rather than internals, so the module can be refactored
        // freely as long as it still renders the same cards/anchors from the same data.
        let realImage;
        let realFetch;

        // Local-path coverurls + a distinct fallback keep checkUrls on its no-fetch branch.
        const config = {
            coverImageFallbackHeight: 210,
            coverImageFallbackUrl: "/covers/fallback.png",
        };
        const data = [
            {
                biblionumber: 11,
                title: "Alpha",
                author: "A. Uthor",
                coverurl: "/covers/11.jpg",
                referenceToDetailsView:
                    "/cgi-bin/koha/opac-detail.pl?biblionumber=11",
            },
            {
                biblionumber: 22,
                title: "Beta",
                author: "B. Writer",
                coverurl: "/covers/22.jpg",
                referenceToDetailsView:
                    "/cgi-bin/koha/opac-detail.pl?biblionumber=22",
            },
        ];

        before(() => {
            realImage = window.Image;
            realFetch = global.fetch;

            // Cover images "load" immediately with fixed dimensions (jsdom never fires
            // onload for a real src).
            function FakeImage() {}
            Object.defineProperty(FakeImage.prototype, "src", {
                set(value) {
                    this._src = value;
                    this.naturalHeight = 200;
                    this.naturalWidth = 140;
                    this.height = 200;
                    this.width = 140;
                    setTimeout(() => {
                        if (this.onload) this.onload();
                    }, 0);
                },
                get() {
                    return this._src;
                },
            });
            window.Image = FakeImage;
            global.Image = FakeImage;

            // Every cover "exists"; any JSON fetch returns an empty payload.
            const okResponse = {
                ok: true,
                status: 200,
                json: async () => ({ items: [] }),
            };
            global.fetch = async () => okResponse;
            window.fetch = global.fetch;

            // Skip the Babeltheque-style DOM harvester path.
            mod.externalSources.info = "ekz";
        });

        after(() => {
            window.Image = realImage;
            global.Image = realImage;
            global.fetch = realFetch;
            window.fetch = realFetch;
            mod.externalSources.info = undefined;
        });

        it("renders one card per data item into the target container", async () => {
            document.body.innerHTML = '<div id="lcf-render"></div>';
            const lcf = mod.createLcfInstance();
            lcf.setGlobals(config, data, "lcf-render");
            await lcf.render();

            const cards = document.querySelectorAll(
                "#lcf-render .lcfItemContainer"
            );
            expect(cards.length).to.equal(data.length);
        });

        it("links each card to its referenceToDetailsView", async () => {
            document.body.innerHTML = '<div id="lcf-render-links"></div>';
            const lcf = mod.createLcfInstance();
            lcf.setGlobals(config, data, "lcf-render-links");
            await lcf.render();

            const hrefs = [
                ...document.querySelectorAll("#lcf-render-links .lcfAnchor"),
            ].map(anchor => anchor.getAttribute("href"));
            expect(hrefs).to.include.members(
                data.map(item => item.referenceToDetailsView)
            );
        });

        // Two coverflows on one page must each inject into their own <style> tag.
        // Before the fix, addGlobalStyle used getElementById('lcfStyle') (first-wins),
        // so the second container's tag stayed empty and only the first was styled.
        it("scopes injected styles to each container's own style tag", async () => {
            document.body.innerHTML =
                '<div id="lcf-scope-a"></div><div id="lcf-scope-b"></div>';
            const a = mod.createLcfInstance();
            a.setGlobals(config, data, "lcf-scope-a");
            await a.render();
            const b = mod.createLcfInstance();
            b.setGlobals(config, data, "lcf-scope-b");
            await b.render();

            const sheetA = document.querySelector("#lcfStyle.lcf-scope-a");
            const sheetB = document.querySelector("#lcfStyle.lcf-scope-b");
            expect(sheetA && sheetA.sheet.cssRules.length, "container A rules").to.be.above(0);
            expect(sheetB && sheetB.sheet.cssRules.length, "container B rules").to.be.above(0);
        });

        // Grid context uses a separate builder (GridContext) than the default
        // horizontal flow; this guards the grid DOM-build path (buildCoverFlow /
        // createTagAndSetClasses / appendToDom) that the default tests don't reach.
        it("renders one card per item and links them in grid context", async () => {
            document.body.innerHTML = '<div id="lcf-grid"></div>';
            const lcf = mod.createLcfInstance();
            lcf.setGlobals(config, data, "lcf-grid");
            await lcf.render("grid");

            const cards = document.querySelectorAll("#lcf-grid .lcfItemContainer");
            expect(cards.length, "card count").to.equal(data.length);

            const hrefs = [
                ...document.querySelectorAll("#lcf-grid .lcfAnchor"),
            ].map(anchor => anchor.getAttribute("href"));
            expect(hrefs).to.include.members(
                data.map(item => item.referenceToDetailsView)
            );
        });
    });
});
