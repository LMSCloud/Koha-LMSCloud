/**
 * Staff record bookings list: the LMSCloud status filters, badges and
 * actions on the bookings table of bookings/list.pl.
 */

const dayjs = require("dayjs");

describe("LMSCloud record bookings list", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleBiblio", {
            item_count: 3,
            item_values: { bookable: 1 },
        }).as("biblio");
        cy.task("insertSamplePatron").as("objects");

        cy.get("@objects").then(function (objects) {
            const [new_item, cancelled_item, issued_item] = this.biblio.items;
            const future = {
                start_date: dayjs().add(3, "day").startOf("day").toISOString(),
                end_date: dayjs().add(5, "day").endOf("day").toISOString(),
            };
            cy.task("insertSampleBooking", {
                item: new_item,
                patron: objects.patron,
                ...future,
            });
            cy.task("insertSampleBooking", {
                item: cancelled_item,
                patron: objects.patron,
                ...future,
            }).then(({ booking }) =>
                cy.task("apiPut", {
                    endpoint: `/api/v1/bookings/${booking.booking_id}`,
                    body: {
                        biblio_id: booking.biblio_id,
                        item_id: booking.item_id,
                        patron_id: booking.patron_id,
                        pickup_library_id: booking.pickup_library_id,
                        start_date: booking.start_date,
                        end_date: booking.end_date,
                        status: "cancelled",
                    },
                })
            );
            cy.task("insertSampleBooking", {
                item: issued_item,
                patron: objects.patron,
                start_date: dayjs().startOf("day").toISOString(),
                end_date: dayjs().add(2, "day").endOf("day").toISOString(),
            }).then(() =>
                cy.task("apiPost", {
                    endpoint: "/api/v1/checkouts",
                    body: {
                        patron_id: objects.patron.patron_id,
                        item_id: issued_item.item_id,
                    },
                })
            );
        });
    });

    afterEach(function () {
        cy.visit("/cgi-bin/koha/mainpage.pl");
        cy.task("lmsDeleteSampleObjects", [this.biblio, this.objects]);
    });

    /**
     * Opens the bookings list of the sample record.
     */
    function visitList() {
        cy.get("@biblio").then(biblio =>
            cy.visit(
                `/cgi-bin/koha/bookings/list.pl?biblionumber=${biblio.biblio.biblio_id}`
            )
        );
    }

    /**
     * @param {Object} item
     * @returns {Cypress.Chainable<JQuery>} the bookings table row of an item
     */
    function rowOf(item) {
        return cy.get("#bookings_table tbody").contains("tr", item.external_id);
    }

    it("lists active bookings and includes cancelled ones on request", function () {
        const [new_item, cancelled_item, issued_item] = this.biblio.items;
        visitList();

        cy.get("#bookings_table tbody tr").should("have.length", 2);
        rowOf(new_item).find(".badge").should("have.text", "New");
        rowOf(issued_item).find(".badge").should("have.text", "Issued");

        cy.get("#filter-cancelled").click();
        cy.get("#bookings_table tbody tr").should("have.length", 3);
        rowOf(cancelled_item).find(".badge").should("contain", "Cancelled");
    });

    it("offers the actions that fit each booking's status", function () {
        const [new_item, , issued_item] = this.biblio.items;
        visitList();

        rowOf(new_item).find(".edit-action").should("exist");
        rowOf(new_item).find(".cancel-action").should("exist");
        rowOf(new_item).find(".extend-action").should("not.exist");
        rowOf(issued_item).find(".extend-action").should("exist");
        rowOf(issued_item).find(".edit-action").should("not.exist");
    });

    it("opens the extend dialog for an issued booking", function () {
        const issued_item = this.biblio.items[2];
        visitList();

        rowOf(issued_item).find(".extend-action").click();
        cy.get("#extendBookingModal").should("be.visible");
    });
});
