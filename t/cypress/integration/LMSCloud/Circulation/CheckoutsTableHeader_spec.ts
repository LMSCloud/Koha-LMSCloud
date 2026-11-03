/**
 * Checkouts table: no FixedHeader, which stalls scrolling through long
 * unpaged checkout lists.
 */

describe("LMSCloud checkouts table header", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleCheckout").as("checkout");
    });

    afterEach(function () {
        cy.task("deleteSampleObjects", this.checkout);
    });

    it("does not fix the checkouts table header", function () {
        cy.visit(
            "/cgi-bin/koha/circ/circulation.pl?borrowernumber=" +
                this.checkout.patron.patron_id
        );
        cy.get("#issues-table-load-now-button").then($button => {
            if ($button.is(":visible")) cy.wrap($button).click();
        });
        cy.get("#issues-table tbody tr td", { timeout: 10000 }).should(
            "contain",
            this.checkout.items[0].external_id
        );
        cy.window().then(win => {
            const api = win.$("#issues-table").DataTable();
            expect(api.fixedHeader.enabled(), "checkouts table").to.be.false;
        });
    });
});
