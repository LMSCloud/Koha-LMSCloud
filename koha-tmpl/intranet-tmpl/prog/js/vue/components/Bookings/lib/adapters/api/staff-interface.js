/**
 * @module bookingApi
 * @description Service module for all booking-related API calls.
 * All functions return promises and use async/await.
 */

import { bookingValidation } from "../../booking/validation-messages.js";

/**
 * Fetches bookable items for a given biblionumber
 * @param {number|string} biblionumber - The biblionumber to fetch items for
 * @returns {Promise<Array<Object>>} Array of bookable items
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchBookableItems(biblionumber) {
    if (!biblionumber) {
        throw bookingValidation.validationError("biblionumber_required");
    }

    const response = await fetch(
        `/api/v1/biblios/${encodeURIComponent(biblionumber)}/items?bookable=1`,
        {
            headers: {
                "x-koha-embed": "+strings",
            },
        }
    );

    if (!response.ok) {
        throw bookingValidation.validationError("fetch_bookable_items_failed", {
            status: response.status,
            statusText: response.statusText,
        });
    }

    return await response.json();
}

/**
 * Fetches bookings for a given biblionumber
 * @param {number|string} biblionumber - The biblionumber to fetch bookings for
 * @returns {Promise<Array<Object>>} Array of bookings
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchBookings(biblionumber) {
    if (!biblionumber) {
        throw bookingValidation.validationError("biblionumber_required");
    }

    const response = await fetch(
        `/api/v1/biblios/${encodeURIComponent(
            biblionumber
        )}/bookings?q={"status":{"-in":["new","pending","active"]}}`
    );

    if (!response.ok) {
        throw bookingValidation.validationError("fetch_bookings_failed", {
            status: response.status,
            statusText: response.statusText,
        });
    }

    return await response.json();
}

/**
 * Fetches checkouts for a given biblionumber
 * @param {number|string} biblionumber - The biblionumber to fetch checkouts for
 * @returns {Promise<Array<Object>>} Array of checkouts
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchCheckouts(biblionumber) {
    if (!biblionumber) {
        throw bookingValidation.validationError("biblionumber_required");
    }

    const response = await fetch(
        `/api/v1/biblios/${encodeURIComponent(biblionumber)}/checkouts`
    );

    if (!response.ok) {
        throw bookingValidation.validationError("fetch_checkouts_failed", {
            status: response.status,
            statusText: response.statusText,
        });
    }

    return await response.json();
}

/**
 * Fetches a single patron by ID
 * @param {number|string} patronId - The ID of the patron to fetch
 * @returns {Promise<Object>} The patron object
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchPatron(patronId) {
    if (!patronId) {
        throw bookingValidation.validationError("patron_id_required");
    }

    const params = new URLSearchParams({
        patron_id: String(patronId),
    });

    const response = await fetch(`/api/v1/patrons?${params.toString()}`, {
        headers: { "x-koha-embed": "library" },
    });

    if (!response.ok) {
        throw bookingValidation.validationError("fetch_patron_failed", {
            status: response.status,
            statusText: response.statusText,
        });
    }

    return await response.json();
}

import { buildPatronSearchQuery } from "../patron.mjs";

/**
 * Searches for patrons matching a search term
 * @param {string} term - The search term to match against patron names, cardnumbers, etc.
 * @param {number} [page=1] - The page number for pagination
 * @returns {Promise<Object>} Object containing patron search results
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchPatrons(term, page = 1) {
    if (!term) {
        return { results: [] };
    }

    const query = buildPatronSearchQuery(term, {
        search_type: "contains",
    });

    const params = new URLSearchParams({
        q: JSON.stringify(query), // Send the query as a JSON string
        _page: String(page),
        _per_page: "10", // Limit results per page
        _order_by: "surname,firstname",
    });

    const response = await fetch(`/api/v1/patrons?${params.toString()}`, {
        headers: {
            "x-koha-embed": "library",
            Accept: "application/json",
        },
    });

    if (!response.ok) {
        const error = bookingValidation.validationError(
            "fetch_patrons_failed",
            {
                status: response.status,
                statusText: response.statusText,
            }
        );

        try {
            const errorData = await response.json();
            if (errorData.error) {
                error.message += ` - ${errorData.error}`;
            }
        } catch (e) {}

        throw error;
    }

    return await response.json();
}

/**
 * Fetches pickup locations for a biblionumber, optionally filtered by patron
 * @param {number|string} biblionumber - The biblionumber to fetch pickup locations for
 * @param {number|string|null} [patronId] - Optional patron ID to filter pickup locations
 * @returns {Promise<Array<Object>>} Array of pickup location objects
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchPickupLocations(biblionumber, patronId) {
    if (!biblionumber) {
        throw bookingValidation.validationError("biblionumber_required");
    }

    const params = new URLSearchParams({
        _order_by: "name",
        _per_page: "-1",
    });

    if (patronId) {
        params.append("patron_id", String(patronId));
    }

    const response = await fetch(
        `/api/v1/biblios/${encodeURIComponent(
            biblionumber
        )}/pickup_locations?${params.toString()}`
    );

    if (!response.ok) {
        throw bookingValidation.validationError(
            "fetch_pickup_locations_failed",
            {
                status: response.status,
                statusText: response.statusText,
            }
        );
    }

    return await response.json();
}

/**
 * Fetches circulation rules based on the provided context parameters
 * Now uses the enhanced circulation_rules endpoint with date calculation capabilities
 * @param {Object} [params={}] - Context parameters for circulation rules
 * @param {string|number} [params.patron_category_id] - Patron category ID
 * @param {string|number} [params.item_type_id] - Item type ID
 * @param {string|number} [params.library_id] - Library ID
 * @param {string} [params.start_date] - Start date for calculations (ISO format)
 * @param {string} [params.rules] - Comma-separated list of rule kinds (defaults to booking rules)
 * @param {boolean} [params.calculate_dates] - Whether to calculate dates (defaults to true for bookings)
 * @returns {Promise<Object>} Object containing circulation rules with calculated dates
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchCirculationRules(params = {}) {
    // Only include defined (non-null, non-undefined, non-empty) params
    const filteredParams = {};
    for (const key in params) {
        if (
            params[key] !== null &&
            params[key] !== undefined &&
            params[key] !== ""
        ) {
            filteredParams[key] = params[key];
        }
    }

    // Default to calculated dates for bookings unless explicitly disabled
    if (filteredParams.calculate_dates === undefined) {
        filteredParams.calculate_dates = true;
    }

    // Default to booking rules unless specified
    if (!filteredParams.rules) {
        filteredParams.rules =
            "bookings_lead_period,bookings_trail_period,issuelength,renewalsallowed,renewalperiod";
    }

    const urlParams = new URLSearchParams();
    Object.entries(filteredParams).forEach(([k, v]) => {
        if (v === undefined || v === null) return;
        urlParams.set(k, String(v));
    });

    const response = await fetch(
        `/api/v1/circulation_rules?${urlParams.toString()}`
    );

    if (!response.ok) {
        throw bookingValidation.validationError(
            "fetch_circulation_rules_failed",
            {
                status: response.status,
                statusText: response.statusText,
            }
        );
    }

    return await response.json();
}

/**
 * Fetches holidays (closed days) for a library within a date range
 * @param {string} libraryId - The library ID (branchcode)
 * @param {string} [from] - Start date for the range (ISO format, e.g., 2024-01-01). Defaults to today.
 * @param {string} [to] - End date for the range (ISO format, e.g., 2024-03-31). Defaults to 3 months from 'from'.
 * @returns {Promise<string[]>} Array of holiday dates in YYYY-MM-DD format
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchHolidays(libraryId, from, to) {
    if (!libraryId) {
        return [];
    }

    const params = new URLSearchParams();
    if (from) params.set("from", from);
    if (to) params.set("to", to);

    const url = `/api/v1/libraries/${encodeURIComponent(libraryId)}/holidays${params.toString() ? `?${params.toString()}` : ""}`;

    const response = await fetch(url);

    if (!response.ok) {
        throw bookingValidation.validationError("fetch_holidays_failed", {
            status: response.status,
            statusText: response.statusText,
        });
    }

    return await response.json();
}

/**
 * Creates a new booking
 * @param {Object} bookingData - The booking data to create
 * @param {string} bookingData.start_date - Start date of the booking (ISO 8601 format)
 * @param {string} bookingData.end_date - End date of the booking (ISO 8601 format)
 * @param {number|string} bookingData.biblio_id - Biblionumber for the booking
 * @param {number|string} [bookingData.item_id] - Optional item ID for the booking
 * @param {number|string} bookingData.patron_id - Patron ID for the booking
 * @param {number|string} bookingData.pickup_library_id - Pickup library ID
 * @returns {Promise<Object>} The created booking object
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function createBooking(bookingData) {
    if (!bookingData) {
        throw bookingValidation.validationError("booking_data_required");
    }

    const validationError = bookingValidation.validateRequiredFields(
        bookingData,
        [
            "start_date",
            "end_date",
            "biblio_id",
            "patron_id",
            "pickup_library_id",
        ]
    );

    if (validationError) {
        throw validationError;
    }

    const response = await fetch("/api/v1/bookings", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
        },
        body: JSON.stringify(bookingData),
    });

    if (!response.ok) {
        let errorMessage = bookingValidation.validationError(
            "create_booking_failed",
            {
                status: response.status,
                statusText: response.statusText,
            }
        ).message;
        try {
            const errorData = await response.json();
            if (errorData.error) {
                errorMessage += ` - ${errorData.error}`;
            }
        } catch (e) {}
        /** @type {Error & { status?: number }} */
        const error = Object.assign(new Error(errorMessage), {
            status: response.status,
        });
        throw error;
    }

    return await response.json();
}

/**
 * Updates an existing booking
 * @param {number|string} bookingId - The ID of the booking to update
 * @param {Object} bookingData - The updated booking data
 * @param {string} [bookingData.start_date] - New start date (ISO 8601 format)
 * @param {string} [bookingData.end_date] - New end date (ISO 8601 format)
 * @param {number|string} [bookingData.pickup_library_id] - New pickup library ID
 * @param {number|string} [bookingData.item_id] - New item ID (if changing the item)
 * @returns {Promise<Object>} The updated booking object
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function updateBooking(bookingId, bookingData) {
    if (!bookingId) {
        throw bookingValidation.validationError("booking_id_required");
    }

    if (!bookingData || Object.keys(bookingData).length === 0) {
        throw bookingValidation.validationError("no_update_data");
    }

    const response = await fetch(
        `/api/v1/bookings/${encodeURIComponent(bookingId)}`,
        {
            method: "PUT",
            headers: {
                "Content-Type": "application/json",
                Accept: "application/json",
            },
            body: JSON.stringify({ ...bookingData, booking_id: bookingId }),
        }
    );

    if (!response.ok) {
        let errorMessage = bookingValidation.validationError(
            "update_booking_failed",
            {
                status: response.status,
                statusText: response.statusText,
            }
        ).message;
        try {
            const errorData = await response.json();
            if (errorData.error) {
                errorMessage += ` - ${errorData.error}`;
            }
        } catch (e) {}
        /** @type {Error & { status?: number }} */
        const error = Object.assign(new Error(errorMessage), {
            status: response.status,
        });
        throw error;
    }

    return await response.json();
}
