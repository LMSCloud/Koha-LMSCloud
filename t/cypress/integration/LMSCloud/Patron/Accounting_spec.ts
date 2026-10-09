const REGISTER_NAME = "Cypress LMS register";
const SYSPREFS = [
    "ActivateCashRegisterTransactionsOnly",
    "PermitConcurrentCashRegisterUsers",
    "UseCashRegisters",
    "RequirePaymentType",
    "SepaDirectDebitCashRegisterName",
];

/**
 * Adds a debit to the patron's account through the REST API.
 *
 * @param {number} patron_id
 * @param {string} type - account_debit_types.code
 * @param {number} amount
 * @param {string} description
 * @returns {Cypress.Chainable<Object>} the created debit
 */
function addDebit(patron_id, type, amount, description) {
    return cy.task("apiPost", {
        endpoint: `/api/v1/patrons/${patron_id}/account/debits`,
        body: { type, amount, description },
    });
}

/**
 * @param {number} patron_id
 * @param {"debits"|"credits"} kind
 * @returns {Cypress.Chainable<Array<Object>>} the patron's debits or credits, oldest first
 */
function accountLines(patron_id, kind) {
    return cy
        .task("apiGet", {
            endpoint: `/api/v1/patrons/${patron_id}/account/${kind}`,
        })
        .then(lines =>
            [...lines].sort((a, b) => a.account_line_id - b.account_line_id)
        );
}

/**
 * Asserts that the patron's only payment has the payment type and is booked
 * with its amount on the LMSCloud cash register.
 *
 * @param {number} patron_id
 * @param {string} payment_type
 * @param {number} amount
 */
function expectBooked(patron_id, payment_type, amount) {
    accountLines(patron_id, "credits").then(credits => {
        expect(credits.map(c => c.type)).to.deep.equal(["PAYMENT"]);
        expect(credits[0].payment_type).to.equal(payment_type);
        cy.task("lmsCashRegisterBookings", {
            accountlines_id: credits[0].account_line_id,
        }).then(bookings => {
            expect(bookings).to.have.length(1);
            expect(bookings[0].register).to.equal(REGISTER_NAME);
            expect(Number(bookings[0].booking_amount)).to.equal(amount);
        });
    });
}

/**
 * @param {number} patron_id
 * @returns {Cypress.Chainable<Array<number>>} the outstanding amounts of the patron's debits, oldest first
 */
function outstanding(patron_id) {
    return accountLines(patron_id, "debits").then(debits =>
        debits.map(d => Number(d.amount_outstanding))
    );
}

/**
 * @param {number} patron_id
 * @returns {Cypress.Chainable<Array<string>>} the credit types on the patron's account
 */
function creditTypes(patron_id) {
    return accountLines(patron_id, "credits").then(credits =>
        credits.map(c => c.type)
    );
}

describe("LMSCloud patron accounting", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("lmsGetSysprefs", { names: SYSPREFS }).as("sysprefs");
        cy.set_syspref("ActivateCashRegisterTransactionsOnly", 0);
        cy.set_syspref("PermitConcurrentCashRegisterUsers", 0);
        cy.set_syspref("UseCashRegisters", 0);
        cy.set_syspref("RequirePaymentType", 0);

        cy.task("insertSamplePatron").then(objects => {
            cy.wrap(objects).as("objects");
            cy.wrap(objects.patron.patron_id).as("patron_id");
        });
    });

    afterEach(function () {
        SYSPREFS.forEach(name => cy.set_syspref(name, this.sysprefs[name]));
        cy.task("lmsDeleteCashRegister", { name: REGISTER_NAME });
        cy.task("lmsDeleteSampleObjects", [this.objects]);
    });

    it("labels the LMSCloud debit types on the transactions tab", function () {
        addDebit(this.patron_id, "CLAIM_LEVEL1", 2, "Claim one");
        addDebit(this.patron_id, "NOTIFICATION", 1.5, "Notice");

        cy.visit(
            `/cgi-bin/koha/members/boraccount.pl?borrowernumber=${this.patron_id}`
        );
        cy.get("#table_account_fines")
            .should("contain", "Overdue fine (level 1)")
            .and("contain", "Notice fee");
    });

    it("pays an individual charge and shows the change due", function () {
        addDebit(this.patron_id, "MANUAL", 3, "Pay me");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.get("#finest tbody tr")
            .first()
            .find("button")
            .contains("Pay")
            .click();

        cy.get("#payindivfine").should("be.visible");
        cy.get("#paid").should("have.value", "3.00");
        cy.get("#tendered").clear().type("5").blur();
        cy.get("#change").should("have.text", "2.00");
        cy.get("#payindivfine input[type='submit']").click();
        cy.get("#confirm_change_form")
            .should("be.visible")
            .and("contain", "2.00");
        cy.get("#modal_submit").click();

        cy.location("search").should("match", /payment_id=\d+/);
        outstanding(this.patron_id).should("deep.equal", [0]);
        creditTypes(this.patron_id).should("deep.equal", ["PAYMENT"]);
    });

    it("writes off an individual charge", function () {
        addDebit(this.patron_id, "MANUAL", 4, "Write me off");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.get("#finest tbody tr")
            .first()
            .find("button")
            .contains("Write off")
            .click();

        cy.get("#woindivfine").should("be.visible");
        cy.get("#amountwrittenoff").should("have.value", "4.00");
        cy.get("#woindivfine input[type='submit']").click();

        cy.location("search").should("match", /payment_id=\d+/);
        outstanding(this.patron_id).should("deep.equal", [0]);
        creditTypes(this.patron_id).should("deep.equal", ["WRITEOFF"]);
    });

    it("refuses to write off more than the outstanding amount", function () {
        addDebit(this.patron_id, "MANUAL", 4, "Too much");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.get("#finest tbody tr")
            .first()
            .find("button")
            .contains("Write off")
            .click();

        const alerts = cy.stub().as("alert");
        cy.on("window:alert", alerts);
        cy.get("#amountwrittenoff").clear().type("4.50");
        cy.get("#woindivfine input[type='submit']").click();
        cy.get("@alert").should(
            "have.been.calledWithMatch",
            /more than the value of the fee/
        );

        outstanding(this.patron_id).should("deep.equal", [4]);
        creditTypes(this.patron_id).should("be.empty");
    });

    it("cancels an individual charge", function () {
        addDebit(this.patron_id, "NOTIFICATION", 2.5, "Cancel me");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.get("#finest tbody tr")
            .first()
            .find("button")
            .contains("Cancel fee")
            .click();

        cy.get("#cancelindivfine")
            .should("be.visible")
            .and("contain", "Notice fee")
            .and("contain", "Total amount to be cancelled");
        cy.get("#cancelindivfine input[type='submit']").click();

        cy.location("pathname").should("eq", "/cgi-bin/koha/members/pay.pl");
        outstanding(this.patron_id).should("deep.equal", [0]);
        creditTypes(this.patron_id).should("deep.equal", ["CANCELLATION"]);
    });

    it("cancels the selected charges for their full amount", function () {
        addDebit(this.patron_id, "MANUAL", 1, "First");
        addDebit(this.patron_id, "MANUAL", 2, "Second");
        addDebit(this.patron_id, "MANUAL", 4, "Kept");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.get("#finest tbody tr")
            .contains("td", "Kept")
            .parent("tr")
            .find("input.cb")
            .uncheck();
        cy.get("#cancel-selected").should("be.enabled").click();

        cy.get("#paid")
            .should("have.value", "3.00")
            .and("have.attr", "readonly");
        cy.get("#tendered").should("not.exist");
        cy.get("input[type='submit'][value='Confirm']").click();

        outstanding(this.patron_id).should("deep.equal", [0, 0, 4]);
        creditTypes(this.patron_id).should("deep.equal", ["CANCELLATION"]);
    });

    it("writes off nothing when 'Write off all' is not confirmed", function () {
        addDebit(this.patron_id, "MANUAL", 1, "Keep");
        addDebit(this.patron_id, "MANUAL", 2, "Keep too");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.on("window:confirm", () => false);
        cy.get("#woall").click();

        cy.location("pathname").should("eq", "/cgi-bin/koha/members/pay.pl");
        outstanding(this.patron_id).should("deep.equal", [1, 2]);
        creditTypes(this.patron_id).should("be.empty");
    });

    it("writes off every charge when 'Write off all' is confirmed", function () {
        addDebit(this.patron_id, "MANUAL", 1, "Gone");
        addDebit(this.patron_id, "MANUAL", 2, "Gone too");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.on("window:confirm", () => true);
        cy.get("#woall").click();
        cy.get("input[type='submit'][value='Confirm']").click();

        outstanding(this.patron_id).should("deep.equal", [0, 0]);
        creditTypes(this.patron_id).should("include", "WRITEOFF");
    });

    it("cancels every charge with 'Cancel all'", function () {
        addDebit(this.patron_id, "MANUAL", 1, "Gone");
        addDebit(this.patron_id, "NOTIFICATION", 2, "Gone too");

        cy.visit(
            `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
        );
        cy.get("#cancelall").click();
        cy.get("#paid").should("have.value", "3.00");
        cy.get("input[type='submit'][value='Confirm']").click();

        outstanding(this.patron_id).should("deep.equal", [0, 0]);
        creditTypes(this.patron_id).should("include", "CANCELLATION");
    });

    describe("with cash register management active", () => {
        beforeEach(() => {
            cy.set_syspref("ActivateCashRegisterTransactionsOnly", 1);
        });

        it("disables payments, but not write-offs or cancellations, without an open register", function () {
            addDebit(this.patron_id, "MANUAL", 3, "Blocked");

            cy.visit(
                `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
            );
            cy.get(".warn").should(
                "contain",
                "Please open a cash register to enable cash payments."
            );
            cy.get("#paycollect, #payselected").should("be.disabled");
            const row = () => cy.get("#finest tbody tr").first();
            row().find("button").contains("Pay").should("be.disabled");
            row().find("button").contains("Write off").should("be.enabled");
            row().find("button").contains("Cancel fee").should("be.enabled");
            cy.get("#writeoff-selected, #cancel-selected").should("be.enabled");

            cy.visit(
                `/cgi-bin/koha/members/boraccount.pl?borrowernumber=${this.patron_id}`
            );
            cy.get(".warn").should(
                "contain",
                "Please open a cash register to reverse payments."
            );
            cy.get("#table_account_fines .pay-action").should(
                "have.attr",
                "disabled"
            );
        });

        it("offers the cash register in the staff menu", function () {
            const entry =
                "a.dropdown-item[href='/cgi-bin/koha/circ/managecashregister.pl']";
            cy.visit("/cgi-bin/koha/mainpage.pl");
            cy.get(entry).should("contain", "Cash register");

            cy.set_syspref("ActivateCashRegisterTransactionsOnly", 0);
            cy.visit("/cgi-bin/koha/mainpage.pl");
            cy.get(entry).should("not.exist");
        });

        it("offers to pay a manual invoice only with an open register", function () {
            const save_and_pay = "button[value='save and pay']";
            cy.visit(
                `/cgi-bin/koha/members/maninvoice.pl?borrowernumber=${this.patron_id}`
            );
            cy.get("button[value='save']").should("exist");
            cy.get(save_and_pay).should("not.exist");

            cy.task("lmsInsertCashRegister", {
                name: REGISTER_NAME,
                manager_userid: Cypress.env("apiUsername"),
            });
            cy.visit(
                `/cgi-bin/koha/members/maninvoice.pl?borrowernumber=${this.patron_id}`
            );
            cy.get(save_and_pay).should("exist");
        });

        it("keeps a patron who manages an open register from being deleted", function () {
            cy.task("lmsInsertCashRegister", {
                name: REGISTER_NAME,
                manager_userid: this.objects.patron.userid,
                library_id: this.objects.patron.library_id,
            });
            cy.visit(
                `/cgi-bin/koha/members/deletemem.pl?member=${this.patron_id}`
            );
            cy.get(".alert-warning")
                .should("contain", "Cannot delete patron")
                .and(
                    "contain",
                    `Patron has opened a cash register of library ${this.objects.patron.library_id}.`
                );
        });

        it("books a payment on the opened register", function () {
            cy.task("lmsInsertCashRegister", {
                name: REGISTER_NAME,
                manager_userid: Cypress.env("apiUsername"),
            });
            addDebit(this.patron_id, "MANUAL", 3, "Booked");

            cy.visit(
                `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
            );
            cy.get(".warn").should("not.exist");
            cy.get("#finest tbody tr")
                .first()
                .find("button")
                .contains("Pay")
                .click();

            cy.get("#payindivfine")
                .should("contain", "Opened cash register:")
                .and("contain", REGISTER_NAME);
            cy.get("#payment_type").should("have.value", "CASH");
            cy.get("#payindivfine input[type='submit']").click();

            cy.location("search").should("match", /payment_id=\d+/);
            accountLines(this.patron_id, "credits").then(([payment]) => {
                expect(payment.type).to.equal("PAYMENT");
                expect(payment.payment_type).to.equal("CASH");
                cy.task("lmsCashRegisterBookings", {
                    accountlines_id: payment.account_line_id,
                }).then(bookings => {
                    expect(bookings).to.have.length(1);
                    expect(bookings[0].register).to.equal(REGISTER_NAME);
                    expect(Number(bookings[0].booking_amount)).to.equal(3);
                });
            });
        });

        describe("with an open register", () => {
            beforeEach(() => {
                cy.task("lmsInsertCashRegister", {
                    name: REGISTER_NAME,
                    manager_userid: Cypress.env("apiUsername"),
                });
            });

            it("books the selected charges paid together", function () {
                addDebit(this.patron_id, "MANUAL", 1, "First");
                addDebit(this.patron_id, "MANUAL", 2, "Second");

                cy.visit(
                    `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
                );
                cy.get("#payselected").should("be.enabled").click();
                cy.get("#paid").should("have.value", "3.00");
                cy.get("#payment_type").should("have.value", "CASH");
                cy.get("input[type='submit'][value='Confirm']").click();

                outstanding(this.patron_id).should("deep.equal", [0, 0]);
                expectBooked(this.patron_id, "CASH", 3);
            });

            it("books an amount paid toward all charges", function () {
                addDebit(this.patron_id, "MANUAL", 1, "First");
                addDebit(this.patron_id, "MANUAL", 2, "Second");

                cy.visit(
                    `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
                );
                cy.get("#paycollect").click();
                cy.get("#paid").clear().type("2");
                cy.get("#tendered").clear().type("2");
                cy.get("input[type='submit'][value='Confirm']").click();

                outstanding(this.patron_id).should("deep.equal", [0, 1]);
                expectBooked(this.patron_id, "CASH", 2);
            });

            it("books a manual invoice paid right away", function () {
                cy.visit(
                    `/cgi-bin/koha/members/maninvoice.pl?borrowernumber=${this.patron_id}`
                );
                cy.get("#type").select("MANUAL");
                cy.get("#desc").type("Paid at once");
                cy.get("#amount").clear().type("4");
                cy.get("button[value='save and pay']").click();

                cy.get("#payindivfine")
                    .should("be.visible")
                    .and("contain", REGISTER_NAME);
                cy.get("#paid").should("have.value", "4.00");
                cy.get("#payindivfine input[type='submit']").click();

                cy.location("search").should("match", /payment_id=\d+/);
                outstanding(this.patron_id).should("deep.equal", [0]);
                expectBooked(this.patron_id, "CASH", 4);
            });

            it("books a payment on the SEPA direct debit register as SEPA", function () {
                cy.set_syspref("SepaDirectDebitCashRegisterName", REGISTER_NAME);
                addDebit(this.patron_id, "MANUAL", 3, "Direct debit");

                cy.visit(
                    `/cgi-bin/koha/members/pay.pl?borrowernumber=${this.patron_id}`
                );
                cy.get("#finest tbody tr")
                    .first()
                    .find("button")
                    .contains("Pay")
                    .click();
                cy.get("#payment_type").should("have.value", "SEPA");
                cy.get("#payindivfine input[type='submit']").click();

                cy.location("search").should("match", /payment_id=\d+/);
                expectBooked(this.patron_id, "SEPA", 3);
            });
        });
    });
});
