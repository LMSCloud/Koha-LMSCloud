/**
 * Checkout, checkin and renewal: LMSCloud behaviour inside community's
 * circulation pages and C4::Circulation.
 */

const dayjs = require("dayjs");

const SYSPREFS = [
    "RentalFeesCheckoutConfirmation",
    "IssuingBranchBecomesHomeBranch",
    "ReturnBranchBecomesHomeBranch",
    "UpdateItemLocationOnCheckin",
    "AlwaysLoadCheckoutsTable",
    "WaitingNotifyAtCheckout",
];
// LMSCloud preferences that are not part of the installer
const HIDDEN_SYSPREFS = [
    "IssuingDiscardRentalFeesOfPatronCategory",
    "RenewalDiscardRentalFeesOfPatronCategory",
];

/**
 * @returns {Cypress.Chainable<string>} the logged in staff user's library
 */
function staffLibrary() {
    const q = JSON.stringify({ userid: Cypress.env("apiUsername") });
    return cy
        .task("apiGet", { endpoint: `/api/v1/patrons?q=${q}` })
        .then(patrons => patrons[0].library_id);
}

/**
 * @param {number} item_id
 * @returns {Cypress.Chainable<Object>} the item
 */
function getItem(item_id) {
    return cy.task("apiGet", { endpoint: `/api/v1/items/${item_id}` });
}

/**
 * @param {number} item_id
 * @returns {Cypress.Chainable<Object|null>} the item's current checkout
 */
function currentCheckout(item_id) {
    const q = JSON.stringify({ item_id });
    return cy
        .task("apiGet", { endpoint: `/api/v1/checkouts?q=${q}` })
        .then(checkouts => checkouts[0] ?? null);
}

/**
 * @param {number} patron_id
 * @returns {Cypress.Chainable<Array<string>>} the patron's debit types, oldest first
 */
function debitTypes(patron_id) {
    return cy
        .task("apiGet", {
            endpoint: `/api/v1/patrons/${patron_id}/account/debits`,
        })
        .then(debits =>
            [...debits]
                .sort((a, b) => a.account_line_id - b.account_line_id)
                .map(d => d.type)
        );
}

/**
 * Submits a barcode on the patron's staff checkout page.
 *
 * @param {number} patron_id
 * @param {string} barcode
 */
function submitCheckout(patron_id, barcode) {
    cy.visit(`/cgi-bin/koha/circ/circulation.pl?borrowernumber=${patron_id}`);
    cy.get("#barcode").type(barcode);
    cy.get("#mainform").submit();
}

/**
 * Checks out a barcode to the patron and waits for the checkout confirmation.
 *
 * @param {number} patron_id
 * @param {string} barcode
 */
function checkout(patron_id, barcode) {
    submitCheckout(patron_id, barcode);
    cy.get("div.lastchecked .lastcheckoutbarcode").should("have.text", barcode);
}

/**
 * Checks in a barcode on the staff checkin page.
 *
 * @param {string} barcode
 */
function checkin(barcode) {
    cy.visit("/cgi-bin/koha/circ/returns.pl");
    cy.get("#barcode").type(`${barcode}{enter}`);
}

/**
 * Renews a barcode on the staff renew page.
 *
 * @param {string} barcode
 */
function renew(barcode) {
    cy.visit("/cgi-bin/koha/circ/renew.pl");
    cy.get("input[name='barcode']:visible").type(`${barcode}{enter}`);
    cy.get("main").should("contain", "renewed");
}

/**
 * Sets the rental charge of an item type through the item type editor.
 *
 * @param {string} item_type_id
 * @param {string} amount
 */
function setRentalCharge(item_type_id, amount) {
    cy.visit(
        `/cgi-bin/koha/admin/itemtypes.pl?op=add_form&itemtype=${item_type_id}`
    );
    cy.get("#rentalcharge").clear().type(amount);
    cy.get("#itemtypeentry").submit();
    cy.location("search").should("not.contain", "op=add_form");
    cy.task("apiGet", {
        endpoint: `/api/v1/item_types?q=${JSON.stringify({ item_type_id })}`,
    })
        .its("0.rentalcharge")
        .then(Number)
        .should("eq", Number(amount));
}

describe("LMSCloud circulation", () => {
    // Objects a test creates beyond the beforeEach ones; aliases set inside a
    // test are not visible in afterEach
    let extraObjects = [];

    beforeEach(function () {
        extraObjects = [];
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.task("lmsGetSysprefs", {
            names: [...SYSPREFS, ...HIDDEN_SYSPREFS],
        }).as("sysprefs");
        cy.set_syspref("RentalFeesCheckoutConfirmation", 0);
        cy.set_syspref("IssuingBranchBecomesHomeBranch", 0);
        cy.set_syspref("ReturnBranchBecomesHomeBranch", 0);
        cy.set_syspref("UpdateItemLocationOnCheckin", "");
        cy.set_syspref("AlwaysLoadCheckoutsTable", 0);

        cy.task("insertSampleBiblio", {
            item_count: 2,
            item_values: { bookable: 1 },
        }).as("biblio");
        cy.task("insertSamplePatron").then(objects => {
            cy.wrap(objects).as("objects");
            cy.wrap(objects.patron).as("patron");
        });
    });

    afterEach(function () {
        SYSPREFS.forEach(name => cy.set_syspref(name, this.sysprefs[name]));
        const created = HIDDEN_SYSPREFS.filter(
            name => this.sysprefs[name] === null
        );
        HIDDEN_SYSPREFS.forEach(name =>
            cy.set_syspref(name, this.sysprefs[name] ?? "")
        );
        cy.task("lmsDeleteSysprefs", { names: created });
        cy.task("lmsDeleteSampleObjects", [
            this.biblio,
            this.objects,
            ...extraObjects,
        ]);
    });

    describe("checkout page", () => {
        it("checks out and reports the last checkout without script errors", function () {
            const errors = [];
            cy.on("uncaught:exception", err => {
                errors.push(err.message);
                return false;
            });
            const item = this.biblio.items[0];

            checkout(this.patron.patron_id, item.external_id);

            cy.get("div.lastchecked").should("contain", "Checked out:");
            cy.get("#issues-table-load-now-button").click();
            cy.get("#issues-table").should("contain", item.external_id);
            cy.wrap(errors).should("be.empty");
            currentCheckout(item.item_id)
                .its("patron_id")
                .should("eq", this.patron.patron_id);
        });

        it("guards against submitting a second barcode while the first is in flight", function () {
            cy.visit(
                `/cgi-bin/koha/circ/circulation.pl?borrowernumber=${this.patron.patron_id}`
            );
            cy.get("#mainform").then($form => {
                // Keep the page from navigating so the in-flight state persists
                $form.on("submit", e => e.preventDefault());
            });
            cy.get("#barcode").type(this.biblio.items[0].external_id);
            cy.get("#mainform").submit();
            cy.get("#barcode").type("x");
            cy.get("#barcodeSubmittedModal").should("be.visible");
        });

        it("warns about waiting holds before checking out another item", function () {
            cy.set_syspref("WaitingNotifyAtCheckout", 1);
            const [held, other] = this.biblio.items;
            staffLibrary().then(library_id => {
                cy.task("insertSampleHold", { item: held, library_id }).then(
                    hold => {
                        extraObjects.push({
                            patron: hold.patron,
                            patron_category: hold.patron_category,
                        });

                        checkin(held.external_id);
                        cy.get("#hold-found-modal")
                            .should("be.visible")
                            .contains("button", "Confirm hold")
                            .click();
                        cy.task("apiGet", {
                            endpoint: `/api/v1/holds?q=${JSON.stringify({ hold_id: hold.hold.hold_id })}`,
                        })
                            .its("0.status")
                            .should("eq", "W");

                        cy.visit(
                            `/cgi-bin/koha/circ/circulation.pl?borrowernumber=${hold.patron.patron_id}`
                        );
                        cy.get("#barcode").type(other.external_id);
                        cy.get("#mainform").submit();
                        cy.get("#circ-warnwaitingholds-modal").should(
                            "be.visible"
                        );
                        currentCheckout(other.item_id).should("be.null");
                    }
                );
            });
        });
    });

    describe("rental fees", () => {
        beforeEach(function () {
            setRentalCharge(this.biblio.item_type.item_type_id, "1.50");
        });

        it("charges a rental fee on checkout by default", function () {
            checkout(this.patron.patron_id, this.biblio.items[0].external_id);
            debitTypes(this.patron.patron_id).should("deep.equal", ["RENT"]);
        });

        it("asks for confirmation of the rental fee by default", function () {
            cy.set_syspref("RentalFeesCheckoutConfirmation", 1);
            submitCheckout(
                this.patron.patron_id,
                this.biblio.items[0].external_id
            );
            cy.get(".needsconfirm").should("contain", "1.50");
        });

        it("skips the rental fee and its confirmation for exempt categories", function () {
            cy.set_syspref("RentalFeesCheckoutConfirmation", 1);
            cy.set_syspref(
                "IssuingDiscardRentalFeesOfPatronCategory",
                `NOPE|${this.patron.category_id}`
            );
            checkout(this.patron.patron_id, this.biblio.items[0].external_id);
            cy.get(".needsconfirm").should("not.exist");
            debitTypes(this.patron.patron_id).should("be.empty");
        });

        it("skips the renewal fee for exempt categories", function () {
            cy.set_syspref(
                "IssuingDiscardRentalFeesOfPatronCategory",
                this.patron.category_id
            );
            cy.set_syspref(
                "RenewalDiscardRentalFeesOfPatronCategory",
                this.patron.category_id
            );
            const barcode = this.biblio.items[0].external_id;
            checkout(this.patron.patron_id, barcode);
            renew(barcode);
            debitTypes(this.patron.patron_id).should("be.empty");
        });

        it("charges the renewal fee for other categories", function () {
            cy.set_syspref(
                "IssuingDiscardRentalFeesOfPatronCategory",
                this.patron.category_id
            );
            cy.set_syspref("RenewalDiscardRentalFeesOfPatronCategory", "NOPE");
            const barcode = this.biblio.items[0].external_id;
            checkout(this.patron.patron_id, barcode);
            renew(barcode);
            debitTypes(this.patron.patron_id).should("deep.equal", [
                "RENT_RENEW",
            ]);
        });
    });

    describe("home library rewriting", () => {
        it("moves the home library to the issuing library", function () {
            cy.set_syspref("IssuingBranchBecomesHomeBranch", 1);
            const item = this.biblio.items[0];
            checkout(this.patron.patron_id, item.external_id);
            staffLibrary().then(library_id =>
                getItem(item.item_id)
                    .its("home_library_id")
                    .should("eq", library_id)
            );
        });

        it("keeps the home library on checkout by default", function () {
            const item = this.biblio.items[0];
            checkout(this.patron.patron_id, item.external_id);
            getItem(item.item_id)
                .its("home_library_id")
                .should("eq", item.home_library_id);
        });

        it("moves the home library to the return library", function () {
            cy.set_syspref("ReturnBranchBecomesHomeBranch", 1);
            const item = this.biblio.items[0];
            checkout(this.patron.patron_id, item.external_id);
            checkin(item.external_id);
            cy.get(".lastcheckinbarcode").should("have.text", item.external_id);
            staffLibrary().then(library_id => {
                getItem(item.item_id).then(updated => {
                    expect(updated.home_library_id).to.equal(library_id);
                    expect(updated.holding_library_id).to.equal(library_id);
                });
            });
        });
    });

    describe("checkin", () => {
        it("updates the location on checkin without reporting it as a problem", function () {
            cy.set_syspref("UpdateItemLocationOnCheckin", "_ALL_: FIC");
            const item = this.biblio.items[0];
            checkout(this.patron.patron_id, item.external_id);
            currentCheckout(item.item_id).should("not.be.null");
            checkin(item.external_id);
            cy.get(".lastcheckinbarcode").should("have.text", item.external_id);
            currentCheckout(item.item_id).should("be.null");
            cy.get("main").should(
                "not.contain",
                "Item shelving location updated"
            );
            getItem(item.item_id).its("location").should("eq", "FIC");
        });
    });

    describe("renewal", () => {
        it("clears the overdue claim history of the checkout", function () {
            const item = this.biblio.items[0];
            checkout(this.patron.patron_id, item.external_id);
            currentCheckout(item.item_id).then(({ checkout_id }) => {
                cy.task("lmsInsertOverdueClaim", { checkout_id });
                cy.task("lmsCountOverdueClaims", { checkout_id }).should(
                    "eq",
                    1
                );
                renew(item.external_id);
                cy.task("lmsCountOverdueClaims", { checkout_id }).should(
                    "eq",
                    0
                );
            });
        });
    });

    describe("bookings", () => {
        it("marks the patron's booking issued on checkout and completed on checkin", function () {
            const item = this.biblio.items[0];
            cy.task("insertSampleBooking", {
                item,
                patron: this.patron,
                start_date: dayjs().startOf("day").toISOString(),
                end_date: dayjs().add(3, "day").endOf("day").toISOString(),
            }).then(({ booking }) => {
                const status = () =>
                    cy
                        .task("apiGet", {
                            endpoint: `/api/v1/bookings/${booking.booking_id}`,
                        })
                        .its("status");

                checkout(this.patron.patron_id, item.external_id);
                status().should("eq", "issued");
                currentCheckout(item.item_id)
                    .its("booking_id")
                    .should("eq", booking.booking_id);

                checkin(item.external_id);
                cy.get(".lastcheckinbarcode").should(
                    "have.text",
                    item.external_id
                );
                status().should("eq", "completed");
            });
        });
    });
});
