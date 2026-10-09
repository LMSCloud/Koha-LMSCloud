/**
 * Staff record detail: LMSCloud covers and the LMSCloud additions to the
 * staff detail XSLT.
 */

import { addCoverLink } from "../../../support/lmscloud/opac";

const SYSPREFS = ["EKZCover", "IncludeAdditionalMARCFieldsInStaffDetailView"];

/**
 * Appends a data field to the sample record.
 *
 * @param {number} biblio_id
 * @param {string} tag
 * @param {Array<Object>} subfields - e.g. [{ a: "value" }]
 * @param {string} [ind1=" "]
 * @param {string} [ind2=" "]
 */
function addField(biblio_id, tag, subfields, ind1 = " ", ind2 = " ") {
    cy.task("lmsAddMarcField", {
        biblio_id,
        field: { [tag]: { ind1, ind2, subfields } },
    });
}

describe("LMSCloud staff record detail", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("lmsGetSysprefs", { names: SYSPREFS }).as("sysprefs");
        cy.task("insertSampleBiblio", { item_count: 1 }).as("biblio");
    });

    afterEach(function () {
        // Leave the detail page first; its holdings table still loads the items
        cy.visit("/cgi-bin/koha/mainpage.pl");
        cy.task("lmsDeleteSampleObjects", [this.biblio]);
        SYSPREFS.forEach(name => cy.set_syspref(name, this.sysprefs[name]));
    });

    /**
     * Opens the sample record's staff detail page.
     */
    function visitDetail() {
        cy.get("@biblio").then(biblio =>
            cy.visit(
                `/cgi-bin/koha/catalogue/detail.pl?biblionumber=${biblio.biblio.biblio_id}`
            )
        );
    }

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

        visitDetail();
        cy.get(".cover-image img[src='https://cover.ekz.de/lms.jpg']")
            .parents(".cover-image")
            .should("contain", "ekz cover image");
    });

    it("puts the alternative title before the title and separates the responsibility", function () {
        const id = this.biblio.biblio.biblio_id;
        addField(id, "246", [{ a: "Alternative" }], "1", "9");
        cy.task("lmsSetMarcSubfield", {
            biblio_id: id,
            tag: "245",
            code: "c",
            value: "Jane Doe",
        });

        visitDetail();
        cy.get("h1.title")
            .invoke("text")
            .then(text => text.replace(/\s+/g, " "))
            .should("match", /^\s*\[Alternative\]: Some boring read/)
            .and("contain", " / Jane Doe");
    });

    it("labels standard numbers by their type", function () {
        const id = this.biblio.biblio.biblio_id;
        addField(id, "024", [{ a: "4006381333931" }], "3");
        addField(id, "024", [{ a: "9790060115615" }], "2");

        visitDetail();
        cy.get(".results_summary.ean")
            .should("contain", "EAN: 4006381333931")
            .and("contain", "ISMN: 9790060115615");
    });

    it("links ekz interest groups and locations to a search", function () {
        const id = this.biblio.biblio.biblio_id;
        addField(id, "072", [{ a: "Roman" }]);
        addField(id, "852", [{ a: "Magazin" }]);

        visitDetail();
        cy.get(".results_summary.interest_group a")
            .should("have.text", "Roman")
            .and("have.attr", "href")
            .and("contain", "q=sbg:%22Roman%22");
        cy.get(".results_summary.location a")
            .should("have.text", "Magazin")
            .and("have.attr", "href")
            .and("contain", "q=sys.phrase:%22Magazin%22");
    });

    it("leaves subject chains out of the subjects", function () {
        const id = this.biblio.biblio.biblio_id;
        addField(id, "650", [{ a: "Visible subject" }], " ", "0");
        addField(id, "689", [{ a: "Chain subject" }], "0", "0");

        visitDetail();
        cy.get("#catalogue_detail_biblio")
            .should("contain", "Visible subject")
            .and("not.contain", "Chain subject");
    });

    it("shows the additional MARC fields configured for the detail view", function () {
        cy.set_syspref(
            "IncludeAdditionalMARCFieldsInStaffDetailView",
            "500$a=Footnote"
        );
        addField(this.biblio.biblio.biblio_id, "500", [{ a: "LMS note" }]);

        visitDetail();
        cy.get(".results_summary.additionalfield").should(
            "contain",
            "Footnote: LMS note"
        );
    });
});
