describe("Invoices - Files for invoices", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.task("buildSampleObject", {
            object: "vendor",
            values: { active: 1 },
        })
            .then(generatedVendor => {
                delete generatedVendor.list_currency;
                delete generatedVendor.invoice_currency;
                return cy.task("insertObject", {
                    type: "vendor",
                    object: generatedVendor,
                });
            })
            .then(vendor => {
                cy.wrap(vendor).as("vendor");
                return cy.task("buildSampleObject", {
                    object: "invoice",
                    values: { vendor_id: vendor.id },
                });
            })
            .then(generatedInvoice => {
                return cy.task("insertObject", {
                    type: "invoice",
                    object: generatedInvoice,
                });
            })
            .then(invoice => {
                cy.wrap(invoice).as("invoice");
            });

        cy.task("query", {
            sql: "SELECT value FROM systempreferences WHERE variable='AcqEnableFiles'",
        }).then(value => {
            cy.wrap(value).as("syspref_AcqEnableFiles");
        });
    });

    afterEach(function () {
        cy.task("deleteSampleObjects", [
            { vendor: this.vendor, invoice: this.invoice },
        ]);
        cy.set_syspref("AcqEnableFiles", this.syspref_AcqEnableFiles);
    });

    it("should return 404 if AcqEnableFiles is disabled", function () {
        const invoice = this.invoice;
        cy.set_syspref("AcqEnableFiles", 0).then(() => {
            cy.intercept(
                `/cgi-bin/koha/acqui/invoice-files.pl?invoiceid=${invoice.invoice_id}`
            ).as("show-invoice");
            cy.visit(
                `/cgi-bin/koha/acqui/invoice-files.pl?invoiceid=${invoice.invoice_id}`,
                { failOnStatusCode: false }
            );
            cy.wait("@show-invoice")
                .its("response.statusCode")
                .should("equal", 404);
        });
    });

    it("should not return 404 if AcqEnableFiles is enabled", function () {
        const invoice = this.invoice;
        cy.set_syspref("AcqEnableFiles", 1).then(() => {
            cy.visit(
                `/cgi-bin/koha/acqui/invoice-files.pl?invoiceid=${invoice.invoice_id}`
            );
            cy.get("h1").contains(
                `Files for invoice: ${invoice.invoice_number}`
            );
        });
    });
});
