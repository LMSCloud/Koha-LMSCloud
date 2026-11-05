/**
 * Print windows close once the print dialog is closed. Firefox fires
 * afterprint while window.print() is still running and ignores window.close()
 * until it returns, so the window has to close after print() returns.
 */

/**
 * Visits a print window with print() and close() replaced by stubs that
 * behave like Firefox: afterprint fires inside print(), and close() only
 * counts once print() has returned.
 *
 * @param {string} url
 */
function visitLikeFirefox(url) {
    cy.visit(url, {
        onBeforeLoad(win) {
            const calls = [];
            let printing = false;
            cy.stub(win, "print").callsFake(() => {
                printing = true;
                win.dispatchEvent(new win.Event("afterprint"));
                printing = false;
                calls.push("print returned");
            });
            cy.stub(win, "close").callsFake(() => {
                calls.push(printing ? "close ignored" : "close");
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

    it("closes the slip window after print() returns", function () {
        visitLikeFirefox(
            `/cgi-bin/koha/members/printslip.pl?borrowernumber=${this.objects.patron.patron_id}&print=slip`
        );
        cy.window().its("printWindowCalls").should("include", "close");
    });

    it("closes the POS receipt window after print() returns", function () {
        visitLikeFirefox(
            `/cgi-bin/koha/pos/printreceipt.pl?action=print&accountlines_id=${this.credit_id}&autoprint=1`
        );
        cy.window().its("printWindowCalls").should("include", "close");
    });
});
