/**
 * OPAC record detail: LMSCloud suppression, hold and order links, covers,
 * book shop links and the bookings tab inside community's opac-detail page.
 */

const dayjs = require("dayjs");

import {
    addCoverLink,
    addOpacPatron,
    collectErrors,
    opacLogin,
    staffLogin,
} from "../../../support/lmscloud/opac";

const SYSPREFS = [
    "OpacSuppression",
    "OpacSuppressionRedirect",
    "EnableHoldsNotForLoanStatus",
    "HoldFeeMode",
    "EKZCover",
    "OpacDetailBookShopLinks",
    "OpacDetailBookShopLinkContentISBN",
    "OPACBookings",
];

describe("LMSCloud OPAC detail", () => {
    let extraObjects = [];

    beforeEach(function () {
        extraObjects = [];
        cy.task("lmsGetSysprefs", { names: SYSPREFS }).as("sysprefs");
        cy.task("insertSampleBiblio", {
            item_count: 2,
            item_values: { bookable: 1 },
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
     * Opens the sample record's OPAC detail page.
     */
    function visitDetail() {
        cy.get("@biblio").then(biblio =>
            cy.visitOpac(
                `/cgi-bin/koha/opac-detail.pl?biblionumber=${biblio.biblio.biblio_id}`
            )
        );
    }

    it("blocks a record suppressed in 942$n", function () {
        cy.set_syspref("OpacSuppression", 1);
        cy.set_syspref("OpacSuppressionRedirect", 1);
        cy.task("lmsSetMarcSubfield", {
            biblio_id: this.biblio.biblio.biblio_id,
            tag: "942",
            code: "n",
            value: "1",
        });

        cy.clearCookies();
        visitDetail();
        cy.location("pathname").should("eq", "/cgi-bin/koha/opac-blocked.pl");
    });

    describe("hold links", () => {
        it("offers holds on not for loan items only for enabled statuses", function () {
            this.biblio.items.forEach(item =>
                cy.task("apiPut", {
                    endpoint: `/api/v1/biblios/${item.biblio_id}/items/${item.item_id}`,
                    body: { not_for_loan_status: 1 },
                })
            );
            cy.set_syspref("EnableHoldsNotForLoanStatus", "");

            opacLogin(this.patron);
            visitDetail();
            cy.get("#catalogue_detail_biblio").should("exist");
            cy.get(".reserve").should("not.exist");

            staffLogin();
            cy.set_syspref("EnableHoldsNotForLoanStatus", "2|1");
            opacLogin(this.patron);
            visitDetail();
            cy.get(".reserve").should("contain", "Place hold");
        });

        it("offers an order instead of a hold when a hold fee is due on available items", function () {
            cy.set_syspref("HoldFeeMode", "issued_or_reserved");
            opacLogin(this.patron);
            visitDetail();
            cy.get(".reserve").should("contain", "Place order");

            staffLogin();
            cy.set_syspref("HoldFeeMode", "not_always");
            opacLogin(this.patron);
            visitDetail();
            cy.get(".reserve").should("contain", "Place hold");
        });
    });

    it("shows the ekz cover over https", function () {
        cy.set_syspref("EKZCover", 1);
        addCoverLink(
            this.biblio.biblio.biblio_id,
            "http://cover.ekz.de/lms.jpg"
        );
        cy.intercept("GET", "https://cover.ekz.de/**", {
            statusCode: 200,
            body: "",
        });
        const errors = collectErrors();

        cy.clearCookies();
        visitDetail();
        cy.get("#ekz-coverimg img").should(
            "have.attr",
            "src",
            "https://cover.ekz.de/lms.jpg"
        );
        cy.wrap(errors).should("be.empty");
    });

    it("links to the book shop by ISBN-13", function () {
        cy.set_syspref("OpacDetailBookShopLinks", 1);
        cy.set_syspref(
            "OpacDetailBookShopLinkContentISBN",
            '<a class="lms-shop" href="https://shop.example/{ISBN13}">Shop</a>'
        );
        cy.task("lmsAddMarcField", {
            biblio_id: this.biblio.biblio.biblio_id,
            field: {
                "020": {
                    ind1: " ",
                    ind2: " ",
                    subfields: [{ a: "0306406152" }],
                },
            },
        });

        cy.clearCookies();
        visitDetail();
        cy.get("#bookshop_menu a.lms-shop").should(
            "have.attr",
            "href",
            "https://shop.example/9780306406157"
        );
    });

    it("shows booking details only for the patron's own bookings", function () {
        cy.set_syspref("OPACBookings", 1);
        const [own_item, other_item] = this.biblio.items;
        const dates = {
            start_date: dayjs().add(2, "day").startOf("day").toISOString(),
            end_date: dayjs().add(4, "day").endOf("day").toISOString(),
        };
        cy.task("insertSampleBooking", {
            item: own_item,
            patron: this.patron,
            ...dates,
        });
        addOpacPatron({ library_id: this.objects.patron.library_id }).then(
            other => {
                extraObjects.push({ patron: other });
                cy.task("insertSampleBooking", {
                    item: other_item,
                    patron: other,
                    ...dates,
                });
            }
        );

        opacLogin(this.patron);
        visitDetail();
        cy.get("#bookings-tab").should("contain", "Bookings ( 2 )").click();
        cy.get("#bookingst tbody tr").should("have.length", 2);
        cy.get("#bookingst tbody")
            .contains("tr", own_item.external_id)
            .find("td")
            .first()
            .should("contain", this.patron.surname);
        cy.get("#bookingst tbody")
            .contains("tr", other_item.external_id)
            .find("td")
            .then($cells => {
                expect($cells.eq(0).text().trim()).to.equal("—");
                expect($cells.eq(2).text().trim()).to.equal("—");
                expect($cells.eq(5).text().trim()).to.equal("—");
            });
    });
});
