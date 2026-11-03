/**
 * Staff interface: the API client modules under js/fetch/ load from
 * versioned URLs, so browsers fetch them anew after an upgrade.
 */

const VERSIONED = /_\d{2}\.\d{7}\.js$/;

describe("LMSCloud versioned API client modules", () => {
    it("loads every API client module from a versioned URL", () => {
        cy.login();
        cy.visit("/cgi-bin/koha/mainpage.pl");

        cy.window().then(win =>
            Cypress.Promise.resolve(
                win.APIClient.circulation.then(
                    client => typeof client.checkouts.renew
                )
            ).then(type => {
                expect(type).to.equal("function");
                return null;
            })
        );

        cy.window().then(win => {
            const modules = win.performance
                .getEntriesByType("resource")
                .map(entry => new URL(entry.name).pathname)
                .filter(path => path.includes("/js/fetch/"));

            ["api-client", "http-client", "circulation-api-client"].forEach(
                name =>
                    expect(
                        modules.some(path =>
                            new RegExp(`/${name}_\\d{2}\\.\\d{7}\\.js$`).test(
                                path
                            )
                        ),
                        `${name} loaded`
                    ).to.be.true
            );
            expect(modules.filter(path => !VERSIONED.test(path))).to.deep.equal(
                []
            );
        });
    });
});
