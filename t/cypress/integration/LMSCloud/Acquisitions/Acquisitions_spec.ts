/**
 * Acquisitions: the LMSCloud basket group lists and form, and the list price
 * of new orders taken from the record.
 */

/**
 * Saves a basket group for a vendor through the basket group form.
 *
 * @param {Object} vendor
 * @param {string} name
 * @param {boolean} [close=false] - close the basket group when saving
 */
function addBasketGroup(vendor, name, close = false) {
    cy.visit(
        `/cgi-bin/koha/acqui/basketgroup.pl?op=add_form&booksellerid=${vendor.id}`
    );
    cy.get("#basketgroupname").clear().type(name);
    if (close) cy.get("input[type='checkbox']#closedbg").check();
    cy.get("#basketgroupname").closest("form").submit();
}

describe("LMSCloud acquisitions", () => {
    let extraObjects = [];

    beforeEach(function () {
        extraObjects = [];
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("buildSampleObject", { object: "vendor" }).then(generated =>
            cy
                .task("insertObject", { type: "vendor", object: generated })
                .as("vendor")
        );
    });

    afterEach(function () {
        cy.visit("/cgi-bin/koha/mainpage.pl");
        // Deleting the vendor deletes its basket groups; baskets are passed in
        cy.task("lmsDeleteSampleObjects", [
            ...extraObjects,
            { vendor: this.vendor },
        ]);
    });

    it("lists open and closed basket groups in their tabs", function () {
        addBasketGroup(this.vendor, "Lms open group");
        addBasketGroup(this.vendor, "Lms closed group", true);

        cy.visit(
            `/cgi-bin/koha/acqui/basketgroup.pl?booksellerid=${this.vendor.id}`
        );
        cy.get("#basket_group_opened tbody")
            .should("contain", "Lms open group")
            .and("not.contain", "Lms closed group");
        cy.get("#closed-tab").click();
        cy.get("#basket_group_closed tbody")
            .should("contain", "Lms closed group")
            .and("not.contain", "Lms open group");
    });

    it("offers no bookmobile stations as billing or delivery place", function () {
        cy.task("insertSampleBiblio", { item_count: 1 }).then(biblio => {
            extraObjects.push(biblio);
            const [station] = biblio.libraries;
            cy.task("lmsSetMobileBranch", {
                library_id: station.library_id,
                mobilebranch: "CPL",
            });
            cy.visit(
                `/cgi-bin/koha/acqui/basketgroup.pl?op=add_form&booksellerid=${this.vendor.id}`
            );
            cy.get(
                `#billingplace option[value='${station.library_id}']`
            ).should("not.exist");
            cy.get(
                `#deliveryplace option[value='${station.library_id}']`
            ).should("not.exist");
            cy.get("#billingplace option[value='CPL']").should("exist");
        });
    });

    it("takes the list price of a new order from the record", function () {
        cy.task("insertSampleBiblio", { item_count: 1 }).then(biblio => {
            extraObjects.push(biblio);
            cy.task("lmsAddMarcField", {
                biblio_id: biblio.biblio.biblio_id,
                field: {
                    "020": {
                        ind1: " ",
                        ind2: " ",
                        subfields: [{ a: "0306406152" }, { c: "12.50" }],
                    },
                },
            });
            cy.task("insertObject", {
                type: "basket",
                object: {
                    name: "Lms basket",
                    vendor_id: this.vendor.id,
                    close_date: null,
                },
            }).then(basket => {
                extraObjects.push({ basket });
                cy.visit(
                    `/cgi-bin/koha/acqui/neworderempty.pl?booksellerid=${this.vendor.id}` +
                        `&basketno=${basket.basket_id}&biblionumber=${biblio.biblio.biblio_id}`
                );
                cy.get("#listprice").should("have.value", "12.50");
            });
        });
    });
});
