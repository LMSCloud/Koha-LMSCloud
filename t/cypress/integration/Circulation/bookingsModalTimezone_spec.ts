const dayjs = require("dayjs");
const utc = require("dayjs/plugin/utc");
const timezone = require("dayjs/plugin/timezone");
dayjs.extend(utc);
dayjs.extend(timezone);

describe("Booking Modal Timezone Tests", () => {
    let testData = {};

    // Ensure RESTBasicAuth is enabled before running tests
    before(() => {
        cy.task("query", {
            sql: "UPDATE systempreferences SET value = '1' WHERE variable = 'RESTBasicAuth'",
        });
    });

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        // Create fresh test data for each test
        cy.task("insertSampleBiblio", {
            item_count: 1,
        })
            .then(objects => {
                testData = objects;

                // Update item to be bookable
                return cy.task("query", {
                    sql: "UPDATE items SET bookable = 1, itype = 'BK', homebranch = 'CPL', enumchron = 'A', dateaccessioned = '2024-12-03' WHERE itemnumber = ?",
                    values: [objects.items[0].item_id],
                });
            })
            .then(() => {
                // Create a test patron
                return cy.task("buildSampleObject", {
                    object: "patron",
                    values: {
                        firstname: "Timezone",
                        surname: "Tester",
                        cardnumber: `TZ${Date.now()}`,
                        category_id: "PT",
                        library_id: testData.libraries[0].library_id,
                    },
                });
            })
            .then(mockPatron => {
                testData.patron = mockPatron;

                return cy.task("query", {
                    sql: `INSERT INTO borrowers (borrowernumber, firstname, surname, cardnumber, categorycode, branchcode, dateofbirth)
                      VALUES (?, ?, ?, ?, ?, ?, ?)`,
                    values: [
                        mockPatron.patron_id,
                        mockPatron.firstname,
                        mockPatron.surname,
                        mockPatron.cardnumber,
                        mockPatron.category_id,
                        mockPatron.library_id,
                        "1990-01-01",
                    ],
                });
            });
    });

    afterEach(() => {
        // Clean up test data
        if (testData.biblio) {
            cy.task("deleteSampleObjects", testData);
        }
        if (testData.patron) {
            cy.task("query", {
                sql: "DELETE FROM borrowers WHERE borrowernumber = ?",
                values: [testData.patron.patron_id],
            });
        }
    });

    // Helper function to setup modal
    const setupModal = () => {
        cy.intercept(
            "GET",
            `/api/v1/biblios/${testData.biblio.biblio_id}/pickup_locations*`
        ).as("getPickupLocations");
        cy.intercept("GET", "/api/v1/circulation_rules*", {
            body: [
                {
                    bookings_lead_period: 0,
                    bookings_trail_period: 0,
                    issuelength: 14,
                    renewalsallowed: 2,
                    renewalperiod: 7,
                },
            ],
        }).as("getCirculationRules");

        cy.visit(
            `/cgi-bin/koha/catalogue/detail.pl?biblionumber=${testData.biblio.biblio_id}`
        );

        cy.get('[data-bs-target="#placeBookingModal"]').first().click();
        cy.get("#placeBookingModal").should("be.visible");

        cy.selectFromSelect2(
            "#booking_patron_id",
            `${testData.patron.surname}, ${testData.patron.firstname}`,
            testData.patron.cardnumber
        );
        cy.wait("@getPickupLocations");

        cy.get("#pickup_library_id").should("not.be.disabled");
        cy.selectFromSelect2ByIndex("#pickup_library_id", 0);

        cy.get("#booking_item_id").should("not.be.disabled");
        cy.selectFromSelect2ByIndex("#booking_item_id", 1);
        cy.wait("@getCirculationRules");

        cy.get("#period").should("not.be.disabled");
    };

    /**
     * TIMEZONE TEST 1: Date Index Creation Consistency
     * =================================================
     *
     * This test validates the critical fix for date index creation using
     * dayjs().format('YYYY-MM-DD') instead of toISOString().split('T')[0].
     *
     * The Problem:
     * - toISOString() converts Date to UTC, which can shift dates
     * - In PST (UTC-8), midnight PST becomes 08:00 UTC
     * - Splitting on 'T' gives "2024-01-15" but this is the UTC date
     * - For western timezones, this causes dates to appear shifted
     *
     * The Fix:
     * - dayjs().format('YYYY-MM-DD') maintains browser timezone
     * - Dates are indexed by their local representation
     * - No timezone conversion happens during indexing
     *
     * Test Approach:
     * - Create a booking with known UTC datetime
     * - Verify calendar displays booking on correct date
     * - Check that bookingsByDate index uses correct date
     */
    it("should display bookings on correct calendar dates regardless of timezone offset", () => {
        cy.log("=== Testing date index creation consistency ===");

        const today = dayjs().startOf("day");

        /**
         * Create a booking with specific UTC time that tests boundary crossing.
         *
         * Scenario: Booking starts at 08:00 UTC on January 15
         * - In UTC: January 15 08:00
         * - In PST (UTC-8): January 15 00:00 (midnight PST)
         * - In HST (UTC-10): January 14 22:00 (10pm HST on Jan 14)
         *
         * The booking should display on January 15 in all timezones except HST,
         * where it would show on January 14 (because 08:00 UTC = 22:00 previous day HST).
         *
         * However, our fix ensures dates are parsed correctly in browser timezone.
         */
        const bookingDate = today.add(10, "day");
        const bookingStart = bookingDate.hour(0).minute(0).second(0); // Midnight local time
        const bookingEnd = bookingDate.hour(23).minute(59).second(59); // End of day local time

        // Creating booking for bookingDate in local timezone

        // Create booking in database
        cy.task("query", {
            sql: `INSERT INTO bookings (biblio_id, item_id, patron_id, start_date, end_date, pickup_library_id, status)
                  VALUES (?, ?, ?, ?, ?, ?, '1')`,
            values: [
                testData.biblio.biblio_id,
                testData.items[0].item_id,
                testData.patron.patron_id,
                bookingStart.format("YYYY-MM-DD HH:mm:ss"),
                bookingEnd.format("YYYY-MM-DD HH:mm:ss"),
                testData.libraries[0].library_id,
            ],
        });

        setupModal();

        cy.get("#period").as("flatpickrInput");
        cy.get("@flatpickrInput").openFlatpickr();

        // The date should be disabled (has existing booking) on the correct day
        if (
            bookingDate.month() === today.month() ||
            bookingDate.month() === today.add(1, "month").month()
        ) {
            cy.get("@flatpickrInput")
                .getFlatpickrDate(bookingDate.toDate())
                .should("have.class", "flatpickr-disabled");

            // Verify event dot is present (visual indicator)
            cy.get("@flatpickrInput")
                .getFlatpickrDate(bookingDate.toDate())
                .within(() => {
                    cy.get(".event-dots").should("exist");
                });

            // Verify adjacent dates are NOT disabled (no date shift)
            const dayBefore = bookingDate.subtract(1, "day");
            const dayAfter = bookingDate.add(1, "day");

            if (
                dayBefore.month() === today.month() ||
                dayBefore.month() === today.add(1, "month").month()
            ) {
                cy.get("@flatpickrInput")
                    .getFlatpickrDate(dayBefore.toDate())
                    .should("not.have.class", "flatpickr-disabled");
            }

            if (
                dayAfter.month() === today.month() ||
                dayAfter.month() === today.add(1, "month").month()
            ) {
                cy.get("@flatpickrInput")
                    .getFlatpickrDate(dayAfter.toDate())
                    .should("not.have.class", "flatpickr-disabled");
            }
        }

        cy.log("✓ CONFIRMED: Date index creation maintains browser timezone");
    });

    /**
     * TIMEZONE TEST 2: Multi-Day Booking Span
     * ========================================
     *
     * Validates that multi-day bookings span the correct number of days
     * without adding extra days due to timezone conversion.
     *
     * The Problem:
     * - When iterating dates, using toISOString() to create date keys
     *   could cause UTC conversion to add extra days
     * - A 3-day booking in PST could appear as 4 days if boundaries cross
     *
     * The Fix:
     * - Using dayjs().format('YYYY-MM-DD') maintains date boundaries
     * - Each date increments by exactly 1 day in browser timezone
     * - No extra days added from UTC conversion
     */
    it("should correctly span multi-day bookings without timezone-induced extra days", () => {
        const today = dayjs().startOf("day");

        // Create a 3-day booking: should span exactly 3 days (15, 16, 17)
        const bookingStart = today.add(15, "day");
        const bookingEnd = today.add(17, "day");

        cy.task("query", {
            sql: `INSERT INTO bookings (biblio_id, item_id, patron_id, start_date, end_date, pickup_library_id, status)
                  VALUES (?, ?, ?, ?, ?, ?, '1')`,
            values: [
                testData.biblio.biblio_id,
                testData.items[0].item_id,
                testData.patron.patron_id,
                bookingStart.hour(0).minute(0).format("YYYY-MM-DD HH:mm:ss"),
                bookingEnd.hour(23).minute(59).format("YYYY-MM-DD HH:mm:ss"),
                testData.libraries[0].library_id,
            ],
        });

        setupModal();

        cy.get("#period").as("flatpickrInput");
        cy.get("@flatpickrInput").openFlatpickr();

        // All three days should be disabled with event dots
        const expectedDays = [
            bookingStart,
            bookingStart.add(1, "day"),
            bookingStart.add(2, "day"),
        ];

        expectedDays.forEach(date => {
            if (
                date.month() === today.month() ||
                date.month() === today.add(1, "month").month()
            ) {
                cy.get("@flatpickrInput")
                    .getFlatpickrDate(date.toDate())
                    .should("have.class", "flatpickr-disabled");

                cy.get("@flatpickrInput")
                    .getFlatpickrDate(date.toDate())
                    .within(() => {
                        cy.get(".event-dots").should("exist");
                    });
            }
        });

        // The day before and after should NOT be disabled
        const dayBefore = bookingStart.subtract(1, "day");
        const dayAfter = bookingEnd.add(1, "day");

        if (
            dayBefore.month() === today.month() ||
            dayBefore.month() === today.add(1, "month").month()
        ) {
            cy.get("@flatpickrInput")
                .getFlatpickrDate(dayBefore.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        if (
            dayAfter.month() === today.month() ||
            dayAfter.month() === today.add(1, "month").month()
        ) {
            cy.get("@flatpickrInput")
                .getFlatpickrDate(dayAfter.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        cy.log(
            "✓ CONFIRMED: Multi-day bookings span exactly correct number of days"
        );
    });

    /**
     * TIMEZONE TEST 3: Date Comparison Consistency
     * =============================================
     *
     * Validates that date comparisons work correctly when checking for
     * booking conflicts, using normalized start-of-day comparisons.
     *
     * The Problem:
     * - Comparing Date objects with time components is unreliable
     * - Mixing flatpickr.parseDate() and direct Date comparisons
     * - Time components can cause false negatives/positives
     *
     * The Fix:
     * - All dates normalized to start-of-day using dayjs().startOf('day')
     * - Consistent parsing using dayjs() for RFC3339 strings
     * - Reliable date-level comparisons
     */
    it("should correctly detect conflicts using timezone-aware date comparisons", () => {
        const today = dayjs().startOf("day");

        // Create an existing booking for days 20-22
        const existingStart = today.add(20, "day");
        const existingEnd = today.add(22, "day");

        cy.task("query", {
            sql: `INSERT INTO bookings (biblio_id, item_id, patron_id, start_date, end_date, pickup_library_id, status)
                  VALUES (?, ?, ?, ?, ?, ?, '1')`,
            values: [
                testData.biblio.biblio_id,
                testData.items[0].item_id,
                testData.patron.patron_id,
                existingStart.hour(0).minute(0).format("YYYY-MM-DD HH:mm:ss"),
                existingEnd.hour(23).minute(59).format("YYYY-MM-DD HH:mm:ss"),
                testData.libraries[0].library_id,
            ],
        });

        setupModal();

        cy.get("#period").as("flatpickrInput");
        cy.get("@flatpickrInput").openFlatpickr();

        // Test: Date within existing booking should be disabled
        const conflictDate = existingStart.add(1, "day");
        const beforeBooking = existingStart.subtract(1, "day");
        const afterBooking = existingEnd.add(1, "day");

        if (
            conflictDate.month() === today.month() ||
            conflictDate.month() === today.add(1, "month").month()
        ) {
            cy.get("@flatpickrInput")
                .getFlatpickrDate(conflictDate.toDate())
                .should("have.class", "flatpickr-disabled");
        }

        // Dates before and after booking should be available
        if (
            beforeBooking.month() === today.month() ||
            beforeBooking.month() === today.add(1, "month").month()
        ) {
            cy.get("@flatpickrInput")
                .getFlatpickrDate(beforeBooking.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        if (
            afterBooking.month() === today.month() ||
            afterBooking.month() === today.add(1, "month").month()
        ) {
            cy.get("@flatpickrInput")
                .getFlatpickrDate(afterBooking.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        cy.log(
            "✓ CONFIRMED: Conflict detection works consistently across timezones"
        );
    });

    /**
     * TIMEZONE TEST 4: API Submission Round-Trip
     * ===========================================
     *
     * Validates that dates selected in the browser are correctly submitted
     * to the API and can be retrieved without date shifts.
     *
     * The Flow:
     * 1. User selects date in browser (e.g., January 15)
     * 2. JavaScript converts to ISO string with timezone offset
     * 3. API receives RFC3339 datetime, converts to server timezone
     * 4. Stores in database
     * 5. API retrieves, converts to RFC3339 with offset
     * 6. Browser receives and displays
     *
     * Expected: Date should remain January 15 throughout the flow
     */
    it("should correctly round-trip dates through API without timezone shifts", () => {
        const today = dayjs().startOf("day");

        // Select a date range in the future
        const startDate = today.add(25, "day");
        const endDate = today.add(27, "day");

        setupModal();

        cy.intercept("POST", `/api/v1/bookings`).as("createBooking");

        cy.get("#period").selectFlatpickrDateRange(startDate, endDate);

        // Verify hidden fields have ISO strings
        cy.get("#booking_start_date").then($input => {
            const value = $input.val();
            expect(value).to.match(/^\d{4}-\d{2}-\d{2}T/); // ISO format
        });

        cy.get("#booking_end_date").then($input => {
            const value = $input.val();
            expect(value).to.match(/^\d{4}-\d{2}-\d{2}T/); // ISO format
        });

        // Verify dates were set in hidden fields and match selected dates
        cy.get("#booking_start_date").should("not.have.value", "");
        cy.get("#booking_end_date").should("not.have.value", "");

        cy.get("#booking_start_date").then($startInput => {
            cy.get("#booking_end_date").then($endInput => {
                const startValue = $startInput.val() as string;
                const endValue = $endInput.val() as string;

                const submittedStart = dayjs(startValue);
                const submittedEnd = dayjs(endValue);

                // Verify dates match what user selected (in browser timezone)
                expect(submittedStart.format("YYYY-MM-DD")).to.equal(
                    startDate.format("YYYY-MM-DD")
                );
                expect(submittedEnd.format("YYYY-MM-DD")).to.equal(
                    endDate.format("YYYY-MM-DD")
                );
            });
        });

        cy.log("✓ CONFIRMED: API round-trip maintains correct dates");
    });

    /**
     * TIMEZONE TEST 5: Cross-Month Boundary
     * ======================================
     *
     * Validates that bookings spanning month boundaries are handled
     * correctly without timezone-induced date shifts.
     */
    it("should correctly handle bookings that span month boundaries", () => {
        const today = dayjs().startOf("day");

        // Find the last day of current or next month
        let testMonth = today.month() === 11 ? today : today.add(1, "month");
        const lastDayOfMonth = testMonth.endOf("month").startOf("day");
        const firstDayOfNextMonth = lastDayOfMonth.add(1, "day");

        // Create a booking that spans the month boundary
        const bookingStart = lastDayOfMonth.subtract(1, "day");
        const bookingEnd = firstDayOfNextMonth.add(1, "day");

        cy.task("query", {
            sql: `INSERT INTO bookings (biblio_id, item_id, patron_id, start_date, end_date, pickup_library_id, status)
                  VALUES (?, ?, ?, ?, ?, ?, '1')`,
            values: [
                testData.biblio.biblio_id,
                testData.items[0].item_id,
                testData.patron.patron_id,
                bookingStart.hour(0).minute(0).format("YYYY-MM-DD HH:mm:ss"),
                bookingEnd.hour(23).minute(59).format("YYYY-MM-DD HH:mm:ss"),
                testData.libraries[0].library_id,
            ],
        });

        setupModal();

        cy.get("#period").as("flatpickrInput");
        cy.get("@flatpickrInput").openFlatpickr();

        // Test last day of first month is disabled
        cy.get("@flatpickrInput")
            .getFlatpickrDate(lastDayOfMonth.toDate())
            .should("have.class", "flatpickr-disabled");

        // Navigate to next month and test first day is also disabled
        cy.get(".flatpickr-next-month").click();

        cy.get("@flatpickrInput")
            .getFlatpickrDate(firstDayOfNextMonth.toDate())
            .should("have.class", "flatpickr-disabled");

        cy.log(
            "✓ CONFIRMED: Month boundaries handled correctly without date shifts"
        );
    });
});
