/**
 * @module opacBookingApi
 * @description Service module for all OPAC booking-related API calls.
 * All functions return promises and use async/await.
 */

import { bookingValidation } from "./bookingValidationMessages.js";

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
                "x-koha-embed": ["+strings"],
            },
        }
    );

    if (!response.ok) {
        throw bookingValidation.validationError("fetch_bookable_items_failed", {
            status: response.status,
            statusText: response.statusText
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
        `/api/v1/public/biblios/${encodeURIComponent(biblionumber)}/bookings?q={"status":{"-in":["new","pending","active"]}}`
    );

    if (!response.ok) {
        throw bookingValidation.validationError("fetch_bookings_failed", {
            status: response.status,
            statusText: response.statusText
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
            statusText: response.statusText
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
            statusText: response.statusText
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
        throw bookingValidation.validationError("fetch_pickup_locations_failed", {
            status: response.status,
            statusText: response.statusText
        });
    }

    return await response.json();
}

/**
 * Fetches circulation rules - not used in OPAC
 * @returns {Promise<Object>}
 */
export async function fetchCirculationRules() {
    return {};
}

export async function createBooking() {
    return {};
}

export async function updateBooking() {
    return {};
}
