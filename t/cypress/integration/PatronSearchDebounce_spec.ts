describe("members/members-home.pl", () => {
    beforeEach(() => {
        cy.login();
    });

    it("Patron search button should toggle disabled state during search", function () {
        // Visit the members home page
        cy.visit("/cgi-bin/koha/members/members-home.pl");

        // Find the patron search form and button
        cy.get("form.patron_search_form")
            .first()
            .within(() => {
                cy.get(".search_patron_filter_btn")
                    .first()
                    .should("exist")
                    .and("not.be.disabled") // Confirm enabled by default
                    .click();

                // After clicking, the button should become disabled
                cy.get(".search_patron_filter_btn")
                    .first()
                    .should("be.disabled");

                // Watch for the button to become enabled again
                cy.get(".search_patron_filter_btn", { timeout: 10000 })
                    .first()
                    .should("not.be.disabled");
            });
    });
});
