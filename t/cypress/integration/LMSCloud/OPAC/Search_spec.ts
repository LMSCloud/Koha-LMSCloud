/**
 * Catalog search on Elasticsearch: the LMSCloud results page, covers,
 * autocomplete and suggestions, plus the staff catalog search.
 */

import {
    addCoverLink,
    collectErrors,
    staffLogin,
} from "../../../support/lmscloud/opac";

const SYSPREFS = [
    "OPACNoResultsFound",
    "EKZCover",
    "OPACSearchAutoComplete",
    "OPACdidyoumean",
];

/**
 * @returns {string} a lowercase word unlikely to occur in the catalog
 */
function uniqueWord() {
    const letters = "bcdfghjklmnpqrstvwxz";
    let word = "lms";
    for (let i = 0; i < 9; i++) {
        word += letters[Math.floor(Math.random() * letters.length)];
    }
    return word;
}

/**
 * Waits until the OPAC search for a term shows some text, polling while the
 * Elasticsearch indexer catches up with recent record changes.
 *
 * @param {string} term
 * @param {string} expected - text the results page must contain
 * @param {number} [attempts=30]
 */
function waitForSearchResult(term, expected, attempts = 30) {
    cy.request(
        `${Cypress.env("opacBaseUrl")}/cgi-bin/koha/opac-search.pl?q=${term}`
    ).then(({ body }) => {
        if (body.includes(expected)) {
            return;
        }
        if (attempts <= 1) {
            throw new Error(`Searching '${term}' never showed '${expected}'`);
        }
        cy.wait(1000);
        waitForSearchResult(term, expected, attempts - 1);
    });
}

/**
 * Waits until the suggestion service offers a term for a misspelled search;
 * Elasticsearch suggests freshly indexed terms only after a delay.
 *
 * @param {string} misspelled
 * @param {string} expected
 * @param {number} [attempts=30]
 */
function waitForSuggestion(misspelled, expected, attempts = 30) {
    cy.request(
        `${Cypress.env("opacBaseUrl")}/cgi-bin/koha/svc/suggestion?render=stub&q=${misspelled}`
    ).then(({ body }) => {
        if (body.includes(expected)) {
            return;
        }
        if (attempts <= 1) {
            throw new Error(
                `No suggestion of '${expected}' for '${misspelled}'`
            );
        }
        cy.wait(1000);
        waitForSuggestion(misspelled, expected, attempts - 1);
    });
}

/**
 * Creates sample records titled "<term> <suffix>" and waits until each is
 * searchable.
 *
 * @param {string} term
 * @param {Array<string>} suffixes - one record per suffix
 * @returns {Cypress.Chainable<Array<Object>>} the insertSampleBiblio results
 */
function addTitledRecords(term, suffixes) {
    const created = [];
    suffixes.forEach(suffix =>
        cy.task("insertSampleBiblio", { item_count: 1 }).then(biblio => {
            created.push(biblio);
            cy.task("lmsSetMarcSubfield", {
                biblio_id: biblio.biblio.biblio_id,
                tag: "245",
                code: "a",
                value: `${term} ${suffix}`,
            });
        })
    );
    return cy.wrap(created).then(records => {
        records.forEach(record =>
            waitForSearchResult(term, `biblionumber=${record.biblio.biblio_id}`)
        );
        cy.wrap(records);
    });
}

describe("LMSCloud catalog search (Elasticsearch)", () => {
    let records = [];

    before(() => {
        cy.task("lmsGetSysprefs", { names: ["SearchEngine"] }).then(prefs => {
            if (prefs.SearchEngine !== "Elasticsearch") {
                throw new Error(
                    "These specs need SearchEngine=Elasticsearch and a built index"
                );
            }
        });
    });

    beforeEach(function () {
        records = [];
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("lmsGetSysprefs", { names: SYSPREFS }).as("sysprefs");
        cy.wrap(uniqueWord()).as("term");
    });

    afterEach(function () {
        // Delete through the API so the records also leave the search index
        records.forEach(record => {
            record.items.forEach(item =>
                cy.task("apiDelete", {
                    endpoint: `/api/v1/items/${item.item_id}`,
                })
            );
            cy.task("apiDelete", {
                endpoint: `/api/v1/biblios/${record.biblio.biblio_id}`,
            });
        });
        cy.task("lmsDeleteSampleObjects", records);
        staffLogin();
        SYSPREFS.forEach(name => cy.set_syspref(name, this.sysprefs[name]));
    });

    it("finds records and names the search in the breadcrumb", function () {
        addTitledRecords(this.term, ["alpha", "beta"]).then(created => {
            records.push(...created);
        });
        const errors = collectErrors();

        cy.visitOpac(`/cgi-bin/koha/opac-search.pl?q=${this.term}`);
        cy.get("#numresults").should("contain", "2");
        cy.get(".breadcrumb").should(
            "contain",
            `Results of search for '${this.term}'`
        );
        cy.get(".searchresults").should("contain", `${this.term} alpha`);
        cy.get(".searchresults").should("contain", `${this.term} beta`);
        cy.wrap(errors).should("be.empty");
    });

    it("reports an empty local result with the configured text", function () {
        cy.set_syspref(
            "OPACNoResultsFound",
            '<p class="lms-noresults">Ask your library</p>'
        );

        cy.visitOpac(`/cgi-bin/koha/opac-search.pl?q=${this.term}`);
        cy.get("#numresults").should(
            "contain",
            "The local catalog search returned no results!"
        );
        cy.get("#noresultsfound .lms-noresults").should(
            "contain",
            "Ask your library"
        );
    });

    it("shows the ekz cover in the results over https", function () {
        cy.set_syspref("EKZCover", 1);
        addTitledRecords(this.term, ["alpha", "beta"]).then(created => {
            records.push(...created);
            addCoverLink(
                created[0].biblio.biblio_id,
                "http://cover.ekz.de/lms.jpg"
            );
            waitForSearchResult(this.term, "https://cover.ekz.de/lms.jpg");
        });
        cy.intercept("GET", "https://cover.ekz.de/**", {
            statusCode: 200,
            body: "",
        });

        cy.visitOpac(`/cgi-bin/koha/opac-search.pl?q=${this.term}`);
        cy.get(".searchresults img.ekzcover").should(
            "have.attr",
            "src",
            "https://cover.ekz.de/lms.jpg"
        );
    });

    it("suggests indexed titles while typing", function () {
        cy.set_syspref("OPACSearchAutoComplete", 1);
        addTitledRecords(this.term, ["alpha", "beta"]).then(created => {
            records.push(...created);
        });

        cy.visitOpac("/cgi-bin/koha/opac-main.pl");
        cy.get("#translControl1").type(this.term.slice(0, 7));
        cy.get("ul.ui-autocomplete:visible").should("contain", this.term);
    });

    it("suggests the indexed spelling for a misspelled search", function () {
        cy.set_syspref(
            "OPACdidyoumean",
            '[{"name":"ElasticsearchSuggester","enabled":1}]'
        );
        addTitledRecords(this.term, ["alpha", "beta"]).then(created => {
            records.push(...created);
        });
        const misspelled = `${this.term.slice(0, -1)}${
            this.term.slice(-1) === "b" ? "c" : "b"
        }`;

        waitForSuggestion(misspelled, this.term);

        cy.visitOpac(`/cgi-bin/koha/opac-search.pl?q=${misspelled}`);
        cy.get("#didyoumean").should("contain", this.term);
    });

    it("finds the records in the staff catalog search", function () {
        addTitledRecords(this.term, ["alpha", "beta"]).then(created => {
            records.push(...created);
        });

        cy.visit(`/cgi-bin/koha/catalogue/search.pl?q=${this.term}`);
        cy.get("#searchresults").should("contain", `${this.term} alpha`);
        cy.get("#searchresults").should("contain", `${this.term} beta`);
    });
});
