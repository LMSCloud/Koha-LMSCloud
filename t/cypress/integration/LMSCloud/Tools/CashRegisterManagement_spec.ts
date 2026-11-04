/**
 * Cash register management: leaving the edit form without saving keeps the
 * register's authorized staff.
 */

const REGISTER_NAME = "Cypress LMS register management";

/**
 * Creates a register through the form and authorizes the first permitted
 * staff member for it.
 */
function createRegister() {
    cy.visit("/cgi-bin/koha/tools/cash-register-management.pl");
    cy.get("#new button").click();
    cy.get("#cash_register_name").type(REGISTER_NAME);
    cy.get("#no_branch_restriction").check();
    cy.get("#cash_register_staffselect option")
        .first()
        .then($option => {
            cy.get("#cash_register_staffselect").select($option.val());
        });
    cy.get("#authorize").click();
    cy.get("#savedata").click();
}

/**
 * @returns {Cypress.Chainable<JQuery>} the register's row in the list
 */
function registerRow() {
    return cy.contains("#cashregt tbody tr", REGISTER_NAME);
}

/**
 * @returns {Cypress.Chainable<string>} the names of the register's authorized staff
 */
function managers() {
    return registerRow()
        .find("td")
        .eq(2)
        .invoke("text")
        .then(text => text.replace(/\s+/g, " ").trim());
}

/**
 * Opens the register's edit form from the list.
 */
function editRegister() {
    registerRow().find("td.actions button").click();
    cy.get("#cash_register_name").should("have.value", REGISTER_NAME);
}

describe("LMSCloud cash register management", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("lmsDeleteCashRegister", { name: REGISTER_NAME });
        createRegister();
        managers().then(names => {
            expect(names, "authorized staff").not.to.be.empty;
            cy.wrap(names).as("managers");
        });
    });

    afterEach(() => {
        cy.task("lmsDeleteCashRegister", { name: REGISTER_NAME });
    });

    it("keeps the authorized staff when editing is cancelled", function () {
        editRegister();
        cy.contains("a.clear_edit", "Cancel").click();

        cy.location("search").should("be.empty");
        managers().should("equal", this.managers);
    });

    it("keeps the authorized staff when the form is sent without the save button", function () {
        editRegister();
        cy.get("#cash_register_manager_list")
            .closest("form")
            .then($form => $form[0].submit());

        managers().should("equal", this.managers);
    });
});
