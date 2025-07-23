// bookingApi.js
/**
 * @module bookingApi
 * @description Service module for all booking-related API calls.
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
        `/api/v1/biblios/${encodeURIComponent(biblionumber)}/items?bookable=1`,
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
        `/api/v1/biblios/${encodeURIComponent(biblionumber)}/bookings?q={"status":{"-in":["new","pending","active"]}}`
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
        `/api/v1/biblios/${encodeURIComponent(biblionumber)}/checkouts`
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
    if (!patronId) {
        throw new Error("patronId is required");
    }

    const params = new URLSearchParams({
        patron_id: patronId,
    });

    const response = await fetch(`/api/v1/patrons?${params.toString()}`, {
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

import { buildPatronSearchQuery } from "./patronUtils";

/**
 * Searches for patrons matching a search term
 * @param {string} term - The search term to match against patron names, cardnumbers, etc.
 * @param {number} [page=1] - The page number for pagination
 * @returns {Promise<Object>} Object containing patron search results
 * @throws {Error} If the request fails or returns a non-OK status
 */
export async function fetchPatrons(term, page = 1) {
    if (!term) {
        return { results: [] }; // Return empty result for empty search term
    }

    // Build the search query using the utility function
    const query = buildPatronSearchQuery(term, {
        search_type: "contains",
        // Add any additional options needed for the search
    });

    const params = new URLSearchParams({
        q: JSON.stringify(query), // Send the query as a JSON string
        _page: page,
        _per_page: "10", // Limit results per page
        _order_by: "surname,firstname",
    });

    const response = await fetch(`/api/v1/patrons?${params.toString()}`, {
        headers: {
            "x-koha-embed": ["library"],
            Accept: "application/json",
        },
    });

    if (!response.ok) {
        const error = new Error(
            `Failed to fetch patrons: ${response.status} ${response.statusText}`
        );
        error.status = response.status;

        try {
            const errorData = await response.json();
            if (errorData.error) {
                error.message += ` - ${errorData.error}`;
            }
        } catch (e) {
            // If we can't parse the error JSON, use the default error message
        }

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
        throw new Error("biblionumber is required");
    }

    const params = new URLSearchParams({
        _order_by: "name",
        _per_page: "-1",
    });

    // Only add patron_id if it's provided
    if (patronId) {
        params.append("patron_id", patronId);
    }

    const response = await fetch(
        `/api/v1/biblios/${encodeURIComponent(biblionumber)}/pickup_locations?${params.toString()}`
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
 * Fetches circulation rules based on the provided context parameters
 * @param {Object} [params={}] - Context parameters for circulation rules
 * @param {string|number} [params.patron_category_id] - Patron category ID
 * @param {string|number} [params.item_type_id] - Item type ID
 * @param {string|number} [params.library_id] - Library ID
 * @returns {Promise<Object>} Object containing circulation rules
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

    const urlParams = new URLSearchParams({
        ...filteredParams,
        rules: "bookings_lead_period,bookings_trail_period,issuelength,renewalsallowed,renewalperiod",
    });

    const response = await fetch(
        `/api/v1/circulation_rules?${urlParams.toString()}`
    );

    if (!response.ok) {
        const error = new Error(
            `Failed to fetch circulation rules: ${response.status} ${response.statusText}`
        );
        error.status = response.status;
        throw error;
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
        throw new Error("bookingData is required");
    }

    const requiredFields = [
        "start_date",
        "end_date",
        "biblio_id",
        "patron_id",
        "pickup_library_id",
    ];
    const missingFields = requiredFields.filter(field => !bookingData[field]);

    if (missingFields.length > 0) {
        throw new Error(`Missing required fields: ${missingFields.join(", ")}`);
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
        let errorMessage = `Failed to create booking: ${response.status} ${response.statusText}`;
        try {
            const errorData = await response.json();
            if (errorData.error) {
                errorMessage += ` - ${errorData.error}`;
            }
        } catch (e) {
            // If we can't parse the error JSON, use the default error message
        }
        const error = new Error(errorMessage);
        error.status = response.status;
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
        throw new Error("bookingId is required");
    }

    if (!bookingData || Object.keys(bookingData).length === 0) {
        throw new Error("No update data provided");
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
        let errorMessage = `Failed to update booking: ${response.status} ${response.statusText}`;
        try {
            const errorData = await response.json();
            if (errorData.error) {
                errorMessage += ` - ${errorData.error}`;
            }
        } catch (e) {
            // If we can't parse the error JSON, use the default error message
        }
        const error = new Error(errorMessage);
        error.status = response.status;
        throw error;
    }

    return await response.json();
}
