/**
 * Cataloging editor: the warning about MARC21 fixed-length control fields
 * with an invalid length only shows when MARC21FixedLengthWarning is on.
 */

const SYSPREFS = ["MARC21FixedLengthWarning"];

describe("LMSCloud fixed-length control field warning", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("lmsGetSysprefs", { names: SYSPREFS }).as("sysprefs");
        cy.task("insertSampleBiblio", { item_count: 0 }).then(biblio => {
            cy.task("lmsAddMarcField", {
                biblio_id: biblio.biblio.biblio_id,
                field: { "007": "sd" },
            });
            cy.wrap(biblio).as("biblio");
        });
    });

    afterEach(function () {
        cy.visit("/cgi-bin/koha/mainpage.pl");
        cy.task("lmsDeleteSampleObjects", [this.biblio]);
        SYSPREFS.forEach(name => cy.set_syspref(name, this.sysprefs[name]));
    });

    it("does not warn when the preference is off", function () {
        cy.set_syspref("MARC21FixedLengthWarning", "0");
        cy.visit(
            `/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=${this.biblio.biblio.biblio_id}`
        );
        cy.get("form#f.marc_editor").should("exist");
        cy.contains(".alert-warning", "fixed-length control field").should(
            "not.exist"
        );
    });

    it("warns about the short 007 when the preference is on", function () {
        cy.set_syspref("MARC21FixedLengthWarning", "1");
        cy.visit(
            `/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=${this.biblio.biblio.biblio_id}`
        );
        cy.contains(".alert-warning", "fixed-length control field").should(
            "contain",
            "007"
        );
    });
});
