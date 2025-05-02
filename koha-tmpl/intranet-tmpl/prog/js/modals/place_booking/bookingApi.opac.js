/**
 * @module opacBookingApi
 * @description Service module for all OPAC booking-related API calls.
 * All functions return promises and use async/await.
 */

/**
 * Fetches bookable items for a given biblionumber
 * @param {number|string} biblionumber - The biblionumber to fetch items for
 * @returns {Promise<Array<Object>>} Array of bookable items
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchBookableItems(biblionumber) {
    if (!biblionumber) {
        throw new Error("biblionumber is required");
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
        const error = new Error(
            `Failed to fetch bookable items: ${response.status} ${response.statusText}`
        );
        error.status = response.status;
        throw error;
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
        throw new Error("biblionumber is required");
    }

    const response = await fetch(
        `/api/v1/public/biblios/${encodeURIComponent(biblionumber)}/bookings?q={"status":{"-in":["new","pending","active"]}}`
    );

    if (!response.ok) {
        const error = new Error(
            `Failed to fetch bookings: ${response.status} ${response.statusText}`
        );
        error.status = response.status;
        throw error;
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
        throw new Error("biblionumber is required");
    }

    const response = await fetch(
        `/api/v1/public/biblios/${encodeURIComponent(biblionumber)}/checkouts`
    );

    if (!response.ok) {
        const error = new Error(
            `Failed to fetch checkouts: ${response.status} ${response.statusText}`
        );
        error.status = response.status;
        throw error;
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
        const error = new Error(
            `Failed to fetch patron: ${response.status} ${response.statusText}`
        );
        error.status = response.status;
        throw error;
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
        throw new Error("biblionumber is required");
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
        const error = new Error(
            `Failed to fetch pickup locations: ${response.status} ${response.statusText}`
        );
        error.status = response.status;
        throw error;
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
