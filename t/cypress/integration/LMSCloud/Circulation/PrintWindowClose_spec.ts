/**
 * Print windows close once the print dialog is closed. Chrome and Firefox
 * postpone a print() called while the page is still loading, which includes
 * the load event, and return at once, so a window.close() right after it
 * would close the window before anything is printed. Called after the load
 * event, print() returns once the print dialog is closed.
 */

/**
 * Visits a print window with print() and close() replaced by stubs that
 * record whether print() was called during the load event.
 *
 * @param {string} url
 */
function visitPrintWindow(url) {
    cy.visit(url, {
        onBeforeLoad(win) {
            const calls = [];
            let loading = true;
            // Registered before the page's own listeners, so the timeout runs
            // before any the page schedules from its load listener
            win.addEventListener("load", () => {
                win.setTimeout(() => {
                    loading = false;
                });
            });
            cy.stub(win, "print").callsFake(() => {
                calls.push(loading ? "print during load" : "print");
            });
            cy.stub(win, "close").callsFake(() => {
                calls.push("close");
            });
            win.printWindowCalls = calls;
        },
    });
}

describe("LMSCloud print window closing", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleCheckout").then(objects => {
            cy.wrap(objects).as("objects");
            cy.task("apiPost", {
                endpoint: `/api/v1/patrons/${objects.patron.patron_id}/account/credits`,
                body: { credit_type: "PAYMENT", amount: 2 },
            }).then(credit => cy.wrap(credit.account_line_id).as("credit_id"));
        });
    });

    afterEach(function () {
        cy.task("lmsDeleteSampleObjects", [this.objects]);
    });

    it("prints the slip after the load event and then closes the window", function () {
        visitPrintWindow(
            `/cgi-bin/koha/members/printslip.pl?borrowernumber=${this.objects.patron.patron_id}&print=slip`
        );
        cy.window()
            .its("printWindowCalls")
            .should("deep.equal", ["print", "close"]);
    });

    it("prints the POS receipt after the load event and then closes the window", function () {
        visitPrintWindow(
            `/cgi-bin/koha/pos/printreceipt.pl?action=print&accountlines_id=${this.credit_id}&autoprint=1`
        );
        cy.window()
            .its("printWindowCalls")
            .should("deep.equal", ["print", "close"]);
    });
});
