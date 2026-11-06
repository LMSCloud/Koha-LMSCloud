/**
 * The holds list on the place hold page marks non priority holds for every
 * hold type, not only for holds on the next available item.
 */

describe("Place hold page: non priority holds", () => {
    let biblio;
    const holds = [];

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleBiblio", { item_count: 2 }).then(b => {
            biblio = b;
            const [first, second] = b.items;
            cy.task("insertSampleHold", { item: first }).then(h =>
                holds.push(h)
            );
            cy.task("insertSampleHold", {
                biblio: b.biblio,
                library_id: first.home_library_id,
            }).then(h => holds.push(h));
            cy.task("insertSampleHold", { item: second }).then(h =>
                holds.push(h)
            );
        });
        // non priority: the item level hold and the next available hold
        cy.then(() => {
            const [itemLevel, nextAvailable, other] = holds.map(
                h => h.hold.hold_id
            );
            cy.task("query", {
                sql: "UPDATE reserves SET non_priority = reserve_id IN (?, ?) WHERE reserve_id IN (?, ?, ?)",
                values: [
                    itemLevel,
                    nextAvailable,
                    itemLevel,
                    nextAvailable,
                    other,
                ],
            });
        });
    });

    afterEach(() => {
        cy.task("deleteSampleObjects", [...holds, biblio]);
        holds.length = 0;
    });

    it("shows the non priority text for item level and next available holds", () => {
        cy.visit(
            `/cgi-bin/koha/reserve/request.pl?biblionumber=${biblio.biblio.biblio_id}`
        );
        cy.get('table[id^="patron_holds_table"] tbody tr').should(
            "have.length",
            3
        );

        const row = hold =>
            cy
                .get('table[id^="patron_holds_table"] tbody tr')
                .filter(`:contains("${hold.patron.cardnumber}")`);

        row(holds[0]).should("contain", "Non priority hold");
        row(holds[1]).should("contain", "Non priority hold");
        row(holds[2]).should("not.contain", "Non priority hold");
    });
});
