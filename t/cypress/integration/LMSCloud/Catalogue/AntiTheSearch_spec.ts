/**
 * Tables with an anti-the title column find search terms with umlauts and
 * other diacritics, in the staff interface and the OPAC.
 */

const TABLE = `<table id="anti_the_search">
    <thead><tr><th class="anti-the">Title</th></tr></thead>
    <tbody>
        <tr><td><a href="#" title="subscription detail">Für Sie</a></td></tr>
        <tr><td><a href="#">Althaus modernisieren</a></td></tr>
    </tbody>
</table>`;

function matches(win, term) {
    const table = win.$("#anti_the_search").DataTable();
    table.search(term).draw();
    const count = table.rows({ search: "applied" }).count();
    table.search("").draw();
    return count;
}

function checkSearch(win) {
    win.$("body").append(TABLE);
    win.$("#anti_the_search").kohaTable({});

    expect(matches(win, "für"), "für").to.equal(1);
    expect(matches(win, "fu"), "fu").to.equal(1);
    expect(matches(win, "Sie"), "Sie").to.equal(2);
    expect(matches(win, "detail"), "HTML attributes").to.equal(0);
}

describe("LMSCloud anti-the column search", () => {
    it("finds titles with umlauts in the staff interface", () => {
        cy.login();
        cy.visit("/cgi-bin/koha/catalogue/detail.pl?biblionumber=1");
        cy.window().then(checkSearch);
    });

    it("finds titles with umlauts in the OPAC", () => {
        cy.visit(
            Cypress.env("opacBaseUrl") +
                "/cgi-bin/koha/opac-detail.pl?biblionumber=1"
        );
        cy.window().then(checkSearch);
    });
});
