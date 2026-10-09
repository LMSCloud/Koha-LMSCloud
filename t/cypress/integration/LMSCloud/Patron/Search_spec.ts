/**
 * Staff patron search: the LMSCloud filters in the search sidebar, their
 * translation into SQL in Koha::REST::V1::Patrons, and the LMSCloud search
 * description, on top of community's patron search table.
 */

const dayjs = require("dayjs");

const TABLE = "#memberresultst";

/**
 * Creates a patron through the REST API.
 *
 * @param {Object} values - patron attributes, merged over library and category
 * @returns {Cypress.Chainable<Object>} the created patron
 */
function addPatron(values) {
    return cy.task("apiPost", { endpoint: "/api/v1/patrons", body: values });
}

/**
 * @returns {Cypress.Chainable<JQuery>} the patron search sidebar form
 */
function sidebar() {
    return cy.get("aside form.patron_search_form");
}

/**
 * Searches for the shared surname from the sidebar, so the following filter
 * runs are not the first draw that redirects on a single result.
 *
 * @param {string} surname
 */
function searchSurname(surname) {
    cy.visit("/cgi-bin/koha/members/member.pl");
    sidebar().find("#search_patron_filter").clear().type(surname);
    sidebar().submit();
    cy.get(`${TABLE} tbody tr`).should("have.length", 3);
}

/**
 * Sets a date filter through its flatpickr instance; the page holds several
 * date pickers, which the calendar-clicking helpers cannot tell apart.
 *
 * @param {string} selector
 * @param {string} iso - YYYY-MM-DD
 */
function setDate(selector, iso) {
    sidebar()
        .find(selector)
        .then($input => $input[0]._flatpickr.setDate(iso, true));
}

/**
 * Submits the sidebar form and asserts which seeded patrons it finds. A single
 * hit redirects to that patron's details, like community's search does.
 *
 * @param {Array<Object>} patrons - the expected patrons
 */
function expectResults(patrons) {
    sidebar().submit();
    if (patrons.length === 1) {
        cy.location("pathname").should(
            "eq",
            "/cgi-bin/koha/members/moremember.pl"
        );
        cy.location("search").should(
            "contain",
            `borrowernumber=${patrons[0].patron_id}`
        );
    } else if (patrons.length) {
        cy.get(`${TABLE} tbody tr`).should("have.length", patrons.length);
        patrons.forEach(p => cy.get(TABLE).should("contain", p.firstname));
    } else {
        cy.get(`${TABLE} tbody td.dt-empty`).should("exist");
    }
}

describe("LMSCloud patron search", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        const surname = `Lmsps${Date.now()}`;
        cy.wrap(surname).as("surname");
        cy.task("insertSampleBiblio", { item_count: 3 }).as("biblio");
        cy.task("insertSamplePatron").then(objects => {
            cy.wrap(objects).as("objects");
            const base = {
                surname,
                library_id: objects.patron.library_id,
                category_id: objects.patron.category_id,
            };
            const today = dayjs();
            addPatron({
                ...base,
                firstname: "Young",
                date_of_birth: today.subtract(10, "year").format("YYYY-MM-DD"),
                email: "young@example.org",
                expiry_date: today.add(2, "year").format("YYYY-MM-DD"),
            }).as("young");
            addPatron({
                ...base,
                firstname: "Old",
                date_of_birth: today.subtract(40, "year").format("YYYY-MM-DD"),
                expiry_date: today.add(10, "day").format("YYYY-MM-DD"),
            }).as("old");
            addPatron({
                ...base,
                firstname: "Middle",
                date_of_birth: today.subtract(25, "year").format("YYYY-MM-DD"),
                email: "not-an-address",
                expiry_date: today.add(2, "year").format("YYYY-MM-DD"),
            }).as("middle");
        });
        cy.get("@old").then(old =>
            cy.task("apiPost", {
                endpoint: `/api/v1/patrons/${old.patron_id}/account/debits`,
                body: { type: "MANUAL", amount: 5, description: "Search" },
            })
        );
        cy.get("@middle").then(function (middle) {
            this.biblio.items.slice(0, 2).forEach(item =>
                cy.task("apiPost", {
                    endpoint: "/api/v1/checkouts",
                    body: {
                        patron_id: middle.patron_id,
                        item_id: item.item_id,
                    },
                })
            );
        });
    });

    afterEach(function () {
        cy.task("lmsDeleteSampleObjects", [
            this.biblio,
            { patrons: [this.young, this.old, this.middle] },
            this.objects,
        ]);
    });

    it("filters by patron age", function () {
        searchSurname(this.surname);
        sidebar().find("#agerangestart_filter").type("18");
        sidebar().find("#agerangeend_filter").type("30");
        expectResults([this.middle]);

        searchSurname(this.surname);
        sidebar().find("#agerangeend_filter").type("30");
        expectResults([this.young, this.middle]);
        cy.get(".search_description .searchpattern").should(
            "contain",
            ", Age to 30"
        );
    });

    it("filters by open charges", function () {
        searchSurname(this.surname);
        sidebar().find("#chargesto_filter").type("1");
        expectResults([this.young, this.middle]);
        cy.get(".search_description .searchpattern").should(
            "contain",
            ", Open charges amount to 1"
        );

        searchSurname(this.surname);
        sidebar().find("#chargesfrom_filter").type("1");
        expectResults([this.old]);
    });

    it("filters by number of loans", function () {
        searchSurname(this.surname);
        sidebar().find("#issuecountend_filter").type("1");
        expectResults([this.young, this.old]);

        searchSurname(this.surname);
        sidebar().find("#issuecountstart_filter").type("2");
        expectResults([this.middle]);
    });

    it("filters by account expiry", function () {
        searchSurname(this.surname);
        setDate(
            "#accountexpiresfrom_filter",
            dayjs().add(1, "year").format("YYYY-MM-DD")
        );
        expectResults([this.young, this.middle]);

        searchSurname(this.surname);
        setDate("#accountexpiresfrom_filter", dayjs().format("YYYY-MM-DD"));
        setDate(
            "#accountexpiresto_filter",
            dayjs().add(30, "day").format("YYYY-MM-DD")
        );
        expectResults([this.old]);
    });

    it("filters by a usable email address", function () {
        searchSurname(this.surname);
        sidebar().find("#validemail_filter").select("no");
        expectResults([this.old, this.middle]);

        searchSurname(this.surname);
        sidebar().find("#validemail_filter").select("yes");
        expectResults([this.young]);
    });

    it("filters by the overdue level of a checkout", function () {
        const q = JSON.stringify({ patron_id: this.middle.patron_id });
        cy.task("apiGet", { endpoint: `/api/v1/checkouts?q=${q}` }).then(
            checkouts =>
                cy.task("lmsInsertOverdueClaim", {
                    checkout_id: checkouts[0].checkout_id,
                    claim_level: 2,
                })
        );
        searchSurname(this.surname);
        sidebar().find("#overduelevel_filter").select("1");
        expectResults([]);

        searchSurname(this.surname);
        sidebar().find("#overduelevel_filter").select("2");
        expectResults([this.middle]);
    });

    it("combines an LMSCloud filter with the community library filter", function () {
        searchSurname(this.surname);
        sidebar().find("#validemail_filter").select("no");
        sidebar()
            .find(".branchcode_filter")
            .select(this.objects.patron.library_id);
        expectResults([this.old, this.middle]);
        cy.task("apiGet", {
            endpoint: `/api/v1/patrons?q=${JSON.stringify({ userid: Cypress.env("apiUsername") })}`,
        }).then(([staff]) => {
            sidebar().find(".branchcode_filter").select(staff.library_id);
            expectResults([]);
        });
    });

    it("clears the LMSCloud filters", function () {
        searchSurname(this.surname);
        sidebar().find("#agerangestart_filter").type("18");
        sidebar().find("#chargesfrom_filter").type("1");
        sidebar().find("#validemail_filter").select("yes");
        sidebar().find("#overduelevel_filter").select("2");
        sidebar().find(".clear_search").first().click();
        sidebar().find("#agerangestart_filter").should("have.value", "");
        sidebar().find("#chargesfrom_filter").should("have.value", "");
        sidebar().find("#validemail_filter").should("have.value", "");
        sidebar().find("#overduelevel_filter").should("have.value", "");
    });
});
