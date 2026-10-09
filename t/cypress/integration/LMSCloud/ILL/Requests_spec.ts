/**
 * Staff ILL requests: the LMSCloud default and completed request lists and
 * the handling of unknown requests, on community's ILL module with its
 * Standard backend.
 */

/**
 * Creates a Standard backend ILL request through the REST API.
 *
 * @param {Object} patron
 * @param {string} title
 * @returns {Cypress.Chainable<Object>} the created request
 */
function addRequest(patron, title) {
    return cy.task("apiPost", {
        endpoint: "/api/v1/ill/requests",
        body: {
            ill_backend_id: "Standard",
            patron_id: patron.patron_id,
            library_id: patron.library_id,
            extended_attributes: [{ type: "title", value: title }],
        },
    });
}

/**
 * Confirms and completes a request through the staff request page.
 *
 * @param {number} ill_request_id
 */
function completeRequest(ill_request_id) {
    cy.visit(
        `/cgi-bin/koha/ill/ill-requests.pl?op=illview&illrequest_id=${ill_request_id}`
    );
    cy.contains("a", "Confirm request").click();
    cy.contains(".btn-primary", "Confirm request").click();
    cy.contains("a", "Mark completed").click();
    cy.task("apiGet", {
        endpoint: `/api/v1/ill/requests?q=${JSON.stringify({ ill_request_id })}`,
    })
        .its("0.status")
        .should("eq", "COMP");
}

/**
 * @returns {Cypress.Chainable<JQuery>} the rows of the ILL requests table
 */
function listRows() {
    return cy.get("#ill-requests tbody tr");
}

describe("LMSCloud ILL requests", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("lmsGetSysprefs", { names: ["ILLModule"] }).as("sysprefs");
        cy.set_syspref("ILLModule", 1);
        cy.task("insertSamplePatron").then(objects => {
            cy.wrap(objects).as("objects");
            cy.wrap(`Lmsill${Date.now()}`).as("title");
        });
    });

    afterEach(function () {
        cy.task("lmsDeleteSampleObjects", [this.objects]);
        cy.visit("/cgi-bin/koha/mainpage.pl");
        cy.set_syspref("ILLModule", this.sysprefs.ILLModule);
    });

    it("lists open requests by default and completed ones on request", function () {
        addRequest(this.objects.patron, `${this.title} open`);
        addRequest(this.objects.patron, `${this.title} done`).then(request =>
            completeRequest(request.ill_request_id)
        );

        cy.visit("/cgi-bin/koha/ill/ill-requests.pl");
        cy.get("#hitheader").should("contain", "Details for all open requests");
        cy.get("#illfilter_keyword").type(this.title);
        cy.get("#illfilter_form").submit();
        listRows()
            .should("have.length", 1)
            .and("contain", `${this.title} open`);

        cy.get("#ill-list_closed").click();
        cy.get("#hitheader").should(
            "contain",
            "Details for all completed requests"
        );
        cy.get("#illfilter_keyword").type(this.title);
        cy.get("#illfilter_form").submit();
        listRows()
            .should("have.length", 1)
            .and("contain", `${this.title} done`);
    });

    it("returns to the open requests for an unknown request", function () {
        cy.visit(
            "/cgi-bin/koha/ill/ill-requests.pl?op=illview&illrequest_id=999999999"
        );
        cy.location("pathname").should(
            "eq",
            "/cgi-bin/koha/ill/ill-requests.pl"
        );
        cy.get("#hitheader").should("contain", "Details for all open requests");
    });
});
