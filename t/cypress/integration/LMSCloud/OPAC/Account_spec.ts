/**
 * OPAC patron account: LMSCloud columns, covers, card renewal, bookings and
 * the fines table inside community's opac-user and opac-account pages.
 */

const dayjs = require("dayjs");

import {
    OPAC_PATRON_CATEGORY,
    addCoverLink,
    addOpacPatron,
    collectErrors,
    opacLogin,
    staffLogin,
} from "../../../support/lmscloud/opac";

const SYSPREFS = [
    "OPACMySummaryLibrary",
    "OPACMySummaryCallNumber",
    "EKZCover",
    "OpacRenewCardPatronCategories",
    "OpacRenewCardLeadTime",
    "NotifyBorrowerDeparture",
    "OPACBookings",
];
describe("LMSCloud OPAC account", () => {
    let extraObjects = [];

    beforeEach(function () {
        extraObjects = [];
        cy.task("lmsGetSysprefs", { names: SYSPREFS }).as("sysprefs");
        cy.task("insertSampleBiblio", {
            item_count: 1,
            item_values: { bookable: 1, callnumber: "LMS 123" },
        }).as("biblio");
        cy.task("insertSamplePatron").as("objects");
        cy.get("@objects").then(objects =>
            addOpacPatron({ library_id: objects.patron.library_id }).then(
                patron => {
                    extraObjects.push({ patron });
                    cy.wrap(patron).as("patron");
                }
            )
        );
        staffLogin();
    });

    afterEach(function () {
        cy.task("lmsDeleteSampleObjects", [
            this.biblio,
            ...extraObjects,
            this.objects,
        ]);
        staffLogin();
        SYSPREFS.forEach(name => cy.set_syspref(name, this.sysprefs[name]));
    });

    /**
     * Checks the sample item out to the OPAC patron.
     */
    function checkoutItem() {
        cy.get("@patron").then(function (patron) {
            cy.task("apiPost", {
                endpoint: "/api/v1/checkouts",
                body: {
                    patron_id: patron.patron_id,
                    item_id: this.biblio.items[0].item_id,
                },
            });
        });
    }

    it("shows the library column and hides call numbers per preference", function () {
        cy.set_syspref("OPACMySummaryLibrary", 1);
        cy.set_syspref("OPACMySummaryCallNumber", 0);
        checkoutItem();
        const errors = collectErrors();

        opacLogin(this.patron);
        cy.visitOpac("/cgi-bin/koha/opac-user.pl");
        cy.get("#checkoutst thead").should("contain", "Library");
        cy.get("#checkoutst thead").should("not.contain", "Call number");
        cy.get("#checkoutst tbody td.branchcode").should("not.be.empty");
        cy.wrap(errors).should("be.empty");

        staffLogin();
        cy.set_syspref("OPACMySummaryCallNumber", 1);
        opacLogin(this.patron);
        cy.visitOpac("/cgi-bin/koha/opac-user.pl");
        cy.get("#checkoutst thead").should("contain", "Call number");
        cy.get("#checkoutst tbody td.call_no").should("contain", "LMS 123");
    });

    it("shows the ekz cover of a checkout over https", function () {
        cy.set_syspref("EKZCover", 1);
        addCoverLink(
            this.biblio.biblio.biblio_id,
            "http://cover.ekz.de/lms.jpg"
        );
        checkoutItem();
        cy.intercept("GET", "https://cover.ekz.de/**", {
            statusCode: 200,
            body: "",
        });

        opacLogin(this.patron);
        cy.visitOpac("/cgi-bin/koha/opac-user.pl");
        cy.get("#checkoutst img.ekzcover").should(
            "have.attr",
            "src",
            "https://cover.ekz.de/lms.jpg"
        );
    });

    describe("card renewal", () => {
        beforeEach(function () {
            cy.set_syspref("NotifyBorrowerDeparture", 30);
            cy.set_syspref("OpacRenewCardLeadTime", 28);
        });

        it("offers no self renewal for categories that are not enabled", function () {
            cy.set_syspref("OpacRenewCardPatronCategories", "NOPE");
            addOpacPatron({
                library_id: this.objects.patron.library_id,
                expiry_date: dayjs().add(10, "day").format("YYYY-MM-DD"),
            }).then(patron => {
                extraObjects.push({ patron });
                opacLogin(patron);
                cy.visitOpac("/cgi-bin/koha/opac-user.pl");
                cy.get("#warndeparture")
                    .should("contain", "Please contact the library")
                    .and("not.contain", "renew your card yourself");
                cy.get("a[href='/cgi-bin/koha/opac-renewcard.pl']").should(
                    "not.exist"
                );
            });
        });

        it("lets the patron renew an expiring card", function () {
            cy.set_syspref(
                "OpacRenewCardPatronCategories",
                `NOPE|${OPAC_PATRON_CATEGORY}`
            );
            const expiry = dayjs().add(10, "day").format("YYYY-MM-DD");
            addOpacPatron({
                library_id: this.objects.patron.library_id,
                expiry_date: expiry,
            }).then(patron => {
                extraObjects.push({ patron });
                opacLogin(patron);
                cy.visitOpac("/cgi-bin/koha/opac-user.pl");
                cy.get(
                    "#menu a[href='/cgi-bin/koha/opac-renewcard.pl']"
                ).should("contain", "renew your card");
                cy.get("#warndeparture")
                    .contains("a", "renew your card yourself")
                    .click();

                cy.get("#submit_renew_card").should("be.enabled").click();
                cy.get(".alert-success").should(
                    "contain",
                    "Library card renewed"
                );
                cy.task("apiGet", {
                    endpoint: `/api/v1/patrons/${patron.patron_id}`,
                })
                    .its("expiry_date")
                    .should(
                        renewed =>
                            expect(dayjs(renewed).isAfter(dayjs(expiry))).to.be
                                .true
                    );
            });
        });
    });

    describe("bookings tab", () => {
        beforeEach(() => {
            cy.set_syspref("OPACBookings", 1);
        });

        it("labels a future booking as pending", function () {
            cy.task("insertSampleBooking", {
                item: this.biblio.items[0],
                patron: this.patron,
                start_date: dayjs().add(2, "day").startOf("day").toISOString(),
                end_date: dayjs().add(4, "day").endOf("day").toISOString(),
            });

            opacLogin(this.patron);
            cy.visitOpac("/cgi-bin/koha/opac-user.pl");
            cy.get("#opac-user-bookings-tab")
                .should("contain", "Bookings (1)")
                .click();
            cy.get("#opac-user-bookings-table td.status .badge").should(
                "have.text",
                "Pending"
            );
        });

        it("labels a running booking as active", function () {
            cy.task("insertSampleBooking", {
                item: this.biblio.items[0],
                patron: this.patron,
                start_date: dayjs().startOf("day").toISOString(),
                end_date: dayjs().add(2, "day").endOf("day").toISOString(),
            });

            opacLogin(this.patron);
            cy.visitOpac("/cgi-bin/koha/opac-user.pl");
            cy.get("#opac-user-bookings-tab").click();
            cy.get("#opac-user-bookings-table td.status .badge").should(
                "have.text",
                "Active"
            );
        });
    });

    it("lists charges with their type in a separate column", function () {
        cy.task("apiPost", {
            endpoint: `/api/v1/patrons/${this.patron.patron_id}/account/debits`,
            body: {
                type: "NOTIFICATION",
                amount: 1.5,
                description: "Reminder",
            },
        });
        const errors = collectErrors();

        opacLogin(this.patron);
        cy.visitOpac("/cgi-bin/koha/opac-account.pl");
        cy.get("#finestable thead th").eq(2).should("have.text", "Type");
        cy.get("#finestable tbody tr")
            .first()
            .within(() => {
                cy.get("td").eq(2).should("contain", "Notice fee");
                cy.get("td").eq(3).should("contain", "Reminder");
            });
        cy.get("#filter_paid")
            .should("contain", "Show all transactions")
            .click();
        cy.get("#filter_paid").should("contain", "Filter paid transactions");
        cy.wrap(errors).should("be.empty");
    });
});
