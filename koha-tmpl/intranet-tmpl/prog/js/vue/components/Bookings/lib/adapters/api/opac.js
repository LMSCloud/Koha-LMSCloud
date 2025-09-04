/**
 * @module opacBookingApi
 * @description Service module for all OPAC booking-related API calls.
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
        `/api/v1/public/biblios/${encodeURIComponent(biblionumber)}/items`,
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
        `/api/v1/public/biblios/${encodeURIComponent(
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
        `/api/v1/public/biblios/${encodeURIComponent(biblionumber)}/checkouts`
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
    const response = await fetch(`/api/v1/public/patrons/${patronId}`, {
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

/**
 * Searches for patrons - not used in OPAC
 * @returns {Promise<Array>}
 */
export async function fetchPatrons() {
    return [];
}

/**
 * Fetches pickup locations for a biblionumber
 * @param {number|string} biblionumber - The biblionumber to fetch pickup locations for
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
        params.append("patron_id", patronId);
    }

    const response = await fetch(
        `/api/v1/public/biblios/${encodeURIComponent(
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
 * Fetches circulation rules for booking constraints
 * Now uses the enhanced circulation_rules endpoint with date calculation capabilities
 * @param {Object} params - Parameters for circulation rules query
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
        `/api/v1/public/circulation_rules?${urlParams.toString()}`
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

export async function createBooking() {
    return {};
}

export async function updateBooking() {
    return {};
}
