/**
 * Print windows keep a 10px root font size, so slip CSS sized in % or rem
 * prints as it did before the Bootstrap 5 staff interface; other staff pages
 * keep the 13px root.
 */

/**
 * Visits a page without opening the print dialog.
 *
 * @param {string} url
 */
function visitPrintWindow(url) {
    cy.visit(url, {
        onBeforeLoad(win) {
            cy.stub(win, "print");
        },
    });
}

/**
 * @returns {Cypress.Chainable<string>} the computed root font size of the current page
 */
function rootFontSize() {
    return cy
        .document()
        .then(
            doc =>
                doc.defaultView.getComputedStyle(doc.documentElement).fontSize
        );
}

describe("LMSCloud print window root font size", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleCheckout").then(objects => {
            cy.wrap(objects).as("objects");
            const patron_id = objects.patron.patron_id;
            cy.task("apiPost", {
                endpoint: `/api/v1/patrons/${patron_id}/account/debits`,
                body: { type: "MANUAL", amount: 2, description: "Print root" },
            }).then(debit => cy.wrap(debit.account_line_id).as("debit_id"));
            cy.task("apiPost", {
                endpoint: `/api/v1/patrons/${patron_id}/account/credits`,
                body: { credit_type: "PAYMENT", amount: 2 },
            }).then(credit => cy.wrap(credit.account_line_id).as("credit_id"));
        });
    });

    afterEach(function () {
        cy.task("lmsDeleteSampleObjects", [this.objects]);
    });

    it("uses a 10px root in every print window", function () {
        const patron_id = this.objects.patron.patron_id;
        const barcode = this.objects.items[0].external_id;
        const pages = [
            `/cgi-bin/koha/members/printslip.pl?borrowernumber=${patron_id}&print=slip`,
            `/cgi-bin/koha/members/printslip.pl?borrowernumber=${patron_id}&print=qslip`,
            `/cgi-bin/koha/members/printnotice.pl?notice=ACCOUNTS_SUMMARY&borrowernumber=${patron_id}`,
            `/cgi-bin/koha/members/summary-print.pl?borrowernumber=${patron_id}`,
            `/cgi-bin/koha/members/printfeercpt.pl?action=print&accountlines_id=${this.credit_id}`,
            `/cgi-bin/koha/members/printinvoice.pl?action=print&accountlines_id=${this.debit_id}`,
            `/cgi-bin/koha/pos/printreceipt.pl?action=print&accountlines_id=${this.credit_id}`,
            `/cgi-bin/koha/labels/spinelabel-print.pl?barcode=${barcode}`,
        ];

        pages.forEach(url => {
            visitPrintWindow(url);
            rootFontSize().should(size => expect(size, url).to.equal("10px"));
        });
    });

    it("keeps the 13px root on other staff pages", function () {
        cy.visit(
            `/cgi-bin/koha/circ/circulation.pl?borrowernumber=${this.objects.patron.patron_id}`
        );
        rootFontSize().should("equal", "13px");
    });

    describe("with slip CSS sized in percent", () => {
        beforeEach(() => {
            cy.task("lmsGetSysprefs", { names: ["IntranetUserCSS"] }).as(
                "sysprefs"
            );
            cy.set_syspref(
                "IntranetUserCSS",
                "#circ_printslip { font-size: 150%; }"
            );
        });

        afterEach(function () {
            cy.set_syspref("IntranetUserCSS", this.sysprefs.IntranetUserCSS);
        });

        it("prints the slip at 150% of the 10px root", function () {
            visitPrintWindow(
                `/cgi-bin/koha/members/printslip.pl?borrowernumber=${this.objects.patron.patron_id}&print=slip`
            );
            cy.get("body#circ_printslip").should(
                "have.css",
                "font-size",
                "15px"
            );
        });
    });
});
