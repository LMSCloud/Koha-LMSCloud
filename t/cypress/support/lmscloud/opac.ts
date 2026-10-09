/**
 * Helpers for the LMSCloud OPAC specs: OPAC patrons, switching between the
 * staff and OPAC sessions, and record data the OPAC pages render.
 */

const dayjs = require("dayjs");

export const PASSWORD = "Cypress-LMS-1234";

// An installer category with an enrolment period, which card renewal needs
export const OPAC_PATRON_CATEGORY = "B";

/**
 * Creates a patron who can log into the OPAC with PASSWORD. The OPAC logs in
 * by card number, which is set to the userid.
 *
 * @param {Object} values - patron attributes, library_id is required
 * @returns {Cypress.Chainable<Object>} the created patron
 */
export function addOpacPatron(values) {
    const userid = `lmsopac${Date.now()}`;
    return cy
        .task("apiPost", {
            endpoint: "/api/v1/patrons",
            body: {
                surname: "Opac",
                firstname: userid,
                userid,
                cardnumber: userid,
                category_id: OPAC_PATRON_CATEGORY,
                expiry_date: dayjs().add(2, "year").format("YYYY-MM-DD"),
                ...values,
            },
        })
        .then(patron =>
            cy
                .task("apiPost", {
                    endpoint: `/api/v1/patrons/${patron.patron_id}/password`,
                    body: { password: PASSWORD, password_2: PASSWORD },
                })
                .then(() => patron)
        );
}

/**
 * Logs into the staff interface with a form post rather than by typing, so it
 * also works in the cleanup after a failed test; the OPAC login replaces the
 * staff session because both share one session cookie on the same host.
 */
export function staffLogin() {
    cy.clearCookies();
    cy.request("/cgi-bin/koha/mainpage.pl").then(response => {
        const csrf_token = response.body.match(
            /name="csrf_token" value="([^"]+)"/
        )[1];
        cy.request({
            method: "POST",
            url: "/cgi-bin/koha/mainpage.pl",
            form: true,
            body: {
                login_op: "cud-login",
                koha_login_context: "intranet",
                login_userid: Cypress.env("apiUsername"),
                login_password: Cypress.env("apiPassword"),
                csrf_token,
            },
        });
    });
    cy.visit("/cgi-bin/koha/mainpage.pl");
    cy.title().should("eq", "Koha staff interface");
}

/**
 * Logs into the OPAC as a patron created by addOpacPatron, dropping the staff
 * session first; both interfaces share one session cookie on the same host.
 *
 * @param {Object} patron
 */
export function opacLogin(patron) {
    cy.clearCookies();
    cy.loginOpac(patron.cardnumber, PASSWORD);
    cy.get(".loggedinusername").should("exist");
}

/**
 * Collects uncaught page errors so a test can assert none occurred.
 *
 * @returns {Array<string>}
 */
export function collectErrors() {
    const errors = [];
    cy.on("uncaught:exception", err => {
        errors.push(err.message);
        return false;
    });
    return errors;
}

/**
 * Adds an 856 cover link to a biblio.
 *
 * @param {number} biblio_id
 * @param {string} url
 */
export function addCoverLink(biblio_id, url) {
    cy.task("lmsAddMarcField", {
        biblio_id,
        field: {
            856: {
                ind1: "4",
                ind2: " ",
                subfields: [{ q: "cover" }, { u: url }],
            },
        },
    });
}
