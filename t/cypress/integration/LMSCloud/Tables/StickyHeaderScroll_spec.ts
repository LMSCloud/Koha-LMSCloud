/**
 * A table header that becomes sticky keeps the table's elements in the order
 * colgroup, thead, tbody, tfoot; Chrome makes the page jump back otherwise.
 */

const ROWS = Array.from(
    { length: 200 },
    (_, i) => `<tr><td>Row ${i}</td><td>Value ${i}</td></tr>`
).join("");

const TABLE = `<table id="sticky_header_scroll">
    <thead><tr><th>Name</th><th>Value</th></tr></thead>
    <tbody>${ROWS}</tbody>
</table>`;

/**
 * @param {Window} win
 * @returns {Array<string>} the tag names of the table's children
 */
function tableParts(win) {
    return win
        .$("#sticky_header_scroll")
        .children()
        .map((i, el) => el.tagName.toLowerCase())
        .get();
}

/**
 * @param {Window} win
 * @param {number} top
 */
function scrollTo(win, top) {
    win.scrollTo({ top, behavior: "instant" });
}

describe("LMSCloud sticky table header", () => {
    it("keeps the table elements in order while the header floats", () => {
        cy.login();
        cy.visit("/cgi-bin/koha/catalogue/detail.pl?biblionumber=1");
        cy.window().then(win => {
            win.$("main, #main, body").first().append(TABLE);
            win.$("#sticky_header_scroll").kohaTable({ paging: false });
        });

        cy.window().should(win => {
            const table = win.$("#sticky_header_scroll")[0];
            scrollTo(
                win,
                table.getBoundingClientRect().top + win.scrollY + 300
            );
            expect(
                win.$(".dtfh-floatingparent thead"),
                "floating header"
            ).to.have.length(1);
        });
        cy.window().then(win => {
            expect(tableParts(win), "while floating").to.deep.equal([
                "colgroup",
                "thead",
                "tbody",
                "tfoot",
            ]);
            scrollTo(win, 0);
        });

        cy.get(".dtfh-floatingparent").should("not.exist");
        cy.window().then(win => {
            expect(tableParts(win), "back in place").to.deep.equal([
                "colgroup",
                "thead",
                "tbody",
                "tfoot",
            ]);
        });
    });
});
