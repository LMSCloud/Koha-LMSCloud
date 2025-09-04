import { describe, it, beforeEach } from "mocha";
import { expect } from "chai";
import { JSDOM } from "jsdom";
// We will import bookingCalendar after setting up a DOM and dayjs globals
let buildMarkerGrid;
import dayjsLib from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";

describe("Calendar helpers", () => {
    let dom;
    beforeEach(async () => {
        dom = new JSDOM('<!DOCTYPE html><html><body></body></html>');
        global.document = dom.window.document;
        global.window = dom.window;
        // Provide dayjs and required plugins expected by our dayjs adapter
        dayjsLib.extend(isSameOrBefore);
        dayjsLib.extend(isSameOrAfter);
        global.window.dayjs = dayjsLib;
        global.window.dayjs_plugin_isSameOrBefore = isSameOrBefore;
        global.window.dayjs_plugin_isSameOrAfter = isSameOrAfter;

        // Dynamically import after environment is ready
        const mod = await import(
            "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/lib/booking/calendar.mjs"
        );
        buildMarkerGrid = mod.buildMarkerGrid;
    });

    it("buildMarkerGrid builds expected structure", () => {
        const grid = buildMarkerGrid({ booked: 2, "checked-out": 1 });
        expect(grid).to.exist;
        expect(grid.className).to.contain("booking-marker-grid");
        // Should contain two marker items types
        const spans = grid.querySelectorAll("span");
        // There are 2 types; each has a dot span; one has count; total spans >= 3
        expect(spans.length).to.be.greaterThan(2);
        // Dots should have class modifier for type
        const dotBooked = grid.querySelector(".booking-marker-dot--booked");
        const dotChecked = grid.querySelector(".booking-marker-dot--checked-out");
        expect(dotBooked).to.exist;
        expect(dotChecked).to.exist;
    });
});
