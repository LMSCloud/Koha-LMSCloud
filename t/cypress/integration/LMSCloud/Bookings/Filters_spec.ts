/**
 * Staff bookings page: the dropdown column filters of circ/bookings.pl
 * (library, location, item type grouped by parent) and their survival when
 * kohaTable rebuilds the filter row on a column visibility change.
 */

const dayjs = require("dayjs");

describe("LMSCloud bookings page filters", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.window().then(win => win.localStorage.clear());

        cy.task("insertSampleBiblio", {
            item_count: 1,
            item_values: { bookable: 1, location: "FIC" },
        }).as("biblio");
        cy.task("insertSamplePatron").as("objects");
        cy.task("insertObject", {
            type: "item_type",
            object: {
                item_type_id: `P${Date.now() % 1000000}`,
                description: "LMS parent type",
            },
        }).as("parent_type");

        cy.get("@objects").then(function (objects) {
            cy.task("query", {
                sql: "UPDATE itemtypes SET parent_type = ? WHERE itemtype = ?",
                values: [
                    this.parent_type.item_type_id,
                    this.biblio.item_type.item_type_id,
                ],
            });
            cy.task("insertSampleBooking", {
                item: this.biblio.items[0],
                patron: objects.patron,
                start_date: dayjs().add(3, "day").startOf("day").toISOString(),
                end_date: dayjs().add(5, "day").endOf("day").toISOString(),
            });
        });
    });

    afterEach(function () {
        cy.visit("/cgi-bin/koha/mainpage.pl");
        // Clean up whatever beforeEach got to create before a failure
        if (this.biblio) {
            cy.task("query", {
                sql: "UPDATE itemtypes SET parent_type = NULL WHERE itemtype = ?",
                values: [this.biblio.item_type.item_type_id],
            });
        }
        const created = [
            this.biblio,
            this.objects,
            this.parent_type && { item_type: this.parent_type },
        ].filter(Boolean);
        if (created.length) cy.task("lmsDeleteSampleObjects", created);
    });

    /**
     * Opens circ/bookings.pl and waits for the grouped item type filter.
     */
    function visitBookings() {
        cy.intercept("GET", "/api/v1/bookings*").as("bookings");
        cy.visit("/cgi-bin/koha/circ/bookings.pl");
        cy.wait("@bookings");
        cy.get("#bookingst thead tr:eq(1) optgroup", { timeout: 10000 }).should(
            "exist"
        );
    }

    /**
     * @param {string} title - Column header text
     * @returns {Cypress.Chainable<JQuery>} the filter row cell of the column
     */
    function filterCell(title) {
        return cy
            .get("#bookingst thead tr:eq(0)")
            .contains("th", new RegExp(`^\\s*${title}\\s*$`))
            .invoke("index")
            .then(i => cy.get(`#bookingst thead tr:eq(1) th:eq(${i})`));
    }

    it("offers dropdowns with names and filters a parent item type with its children", function () {
        const item = this.biblio.items[0];
        visitBookings();

        ["Item type", "Location", "Holding library", "Pickup library"].forEach(
            title => filterCell(title).find("select").should("exist")
        );
        filterCell("Location").find("option").should("contain", "Fiction");
        filterCell("Item type")
            .find("optgroup[label='LMS parent type'] option")
            .first()
            .should("have.text", "LMS parent type (All)");

        filterCell("Item type").find("select").select("LMS parent type (All)");
        cy.wait("@bookings").then(({ request }) => {
            const q = decodeURIComponent(request.url);
            expect(q).to.contain(this.parent_type.item_type_id);
            expect(q).to.contain(this.biblio.item_type.item_type_id);
        });
        cy.get("#bookingst tbody tr").should("have.length", 1);
        cy.get("#bookingst tbody").should("contain", item.external_id);
    });

    it("keeps every filter when a column is shown or hidden", function () {
        visitBookings();

        filterCell("Status").find("select").select("all");
        cy.wait("@bookings");
        filterCell("Location").find("select").select("Fiction");
        cy.wait("@bookings");
        filterCell("Item type").find("select").select("LMS parent type (All)");
        cy.wait("@bookings");
        cy.window().then(win => {
            const W = win as any;
            const input = W.$(
                "#bookingst thead tr:eq(1) input.booking-date-range-filter"
            ).first()[0];
            input._flatpickr.setDate(
                W.Array.of(
                    new W.Date(dayjs().year(), dayjs().month(), 1),
                    new W.Date(dayjs().add(1, "month").year(), 11, 31)
                ),
                true
            );
        });
        cy.wait("@bookings");

        cy.window().then(win => {
            const dt = (win as any).$("#bookingst").DataTable();
            const column = dt.column("callnumber:name");
            column.visible(!column.visible());
            column.visible(!column.visible());
        });

        filterCell("Status").find("select").should("have.value", "all");
        filterCell("Location").find("select").should("have.value", "FIC");
        filterCell("Item type")
            .find("select")
            .should("have.value", this.parent_type.item_type_id);
        filterCell("Item type")
            .find("optgroup")
            .should("have.length.at.least", 1);
        filterCell("Start date")
            .find("input.booking-date-range-filter")
            .should("not.have.value", "");
        filterCell("Start date").find(".clear_date").should("have.length", 1);

        cy.window().then(win =>
            (win as any).$("#bookingst").DataTable().draw()
        );
        cy.wait("@bookings").then(({ request }) => {
            const q = decodeURIComponent(request.url);
            expect(q, "item type parent").to.contain(
                this.parent_type.item_type_id
            );
            expect(q, "location").to.contain("FIC");
            expect(q, "date range").to.contain("start_date");
        });
        cy.get("#bookingst tbody tr").should("have.length", 1);
    });
});
