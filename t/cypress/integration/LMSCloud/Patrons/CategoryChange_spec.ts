/**
 * Changing an existing patron's category asks whether to reset the expiry date
 * and the messaging preferences; UpdateExpiryDateOnCategoryChange decides
 * whether the expiry date question is asked, preselected, or skipped.
 */

/**
 * The expiry date currently set in the patron form, as YYYY-MM-DD.
 *
 * @returns {Cypress.Chainable<string>}
 */
function formExpiryDate() {
    return cy
        .get("#to")
        .should($input => expect($input[0]._flatpickr).to.exist)
        .then($input => {
            const fp = $input[0]._flatpickr;
            return fp.selectedDates.length
                ? fp.formatDate(fp.selectedDates[0], "Y-m-d")
                : "";
        });
}

/**
 * Selects a category whose default expiry date differs from the one in the
 * form and yields that default (YYYY-MM-DD).
 *
 * @param {string} current expiry date in the form
 * @returns {Cypress.Chainable<string>}
 */
function selectOtherCategory(current) {
    return cy.get("#categorycode_entry option").then($options => {
        const target = [...$options].find(option => {
            const expiry = (option.dataset.expiryDate || "").split("T")[0];
            return option.value && expiry && expiry !== current;
        });
        expect(target, "category with another default expiry date").to.exist;
        cy.get("#categorycode_entry").select(target.value);
        return cy.wrap(target.dataset.expiryDate.split("T")[0]);
    });
}

describe("Patron category change: expiry date", () => {
    let objects;

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSamplePatron").then(o => (objects = o));
        cy.set_syspref("UpdateMessagingPrefsOnCategoryChange", "softyes");
    });

    afterEach(() => {
        cy.visit("/cgi-bin/koha/mainpage.pl");
        cy.set_syspref("UpdateExpiryDateOnCategoryChange", "softyes");
        cy.task("deleteSampleObjects", [objects]);
    });

    const cases = [
        { value: "softyes", checkbox: "checked", updated: true },
        { value: "softno", checkbox: "unchecked", updated: false },
        { value: "no", checkbox: "absent", updated: false },
        { value: "yes", checkbox: "absent", updated: true },
    ];

    cases.forEach(({ value, checkbox, updated }) => {
        it(`${value}: expiry checkbox ${checkbox}, date ${updated ? "reset" : "kept"}`, () => {
            cy.set_syspref("UpdateExpiryDateOnCategoryChange", value);
            cy.visit(
                `/cgi-bin/koha/members/memberentry.pl?op=edit_form&borrowernumber=${objects.patron.patron_id}`
            );
            formExpiryDate().then(before => {
                selectOtherCategory(before).then(categoryDefault => {
                    cy.get("#categoryChangeModal").should("be.visible");
                    if (checkbox === "absent") {
                        cy.get("#categoryChangeUpdateExpiry").should(
                            "not.exist"
                        );
                    } else {
                        cy.get("#categoryChangeUpdateExpiry").should(
                            checkbox === "checked"
                                ? "be.checked"
                                : "not.be.checked"
                        );
                    }
                    cy.get("#categoryChangeConfirmBtn").click();
                    formExpiryDate().should(
                        "eq",
                        updated ? categoryDefault : before
                    );
                });
            });
        });
    });
});
