import { win } from "./globals.mjs";
/**
 * Builds a search query for patron searches
 * This is a wrapper around the global buildPatronSearchQuery function
 * @param {string} term - The search term
 * @param {Object} [options] - Search options
 * @param {string} [options.search_type] - 'contains' or 'starts_with'
 * @param {string} [options.search_fields] - Comma-separated list of fields to search
 * @param {Array} [options.extended_attribute_types] - Extended attribute types to search
 * @param {string} [options.table_prefix] - Table name prefix for fields
 * @returns {Array} Query conditions for the API
 */
export function buildPatronSearchQuery(term, options = {}) {
    /** @type {((term: string, options?: object) => any) | null} */
    const globalBuilder =
        typeof win("buildPatronSearchQuery") === "function"
            ? /** @type {any} */ (win("buildPatronSearchQuery"))
            : null;
    if (globalBuilder) {
        return globalBuilder(term, options);
    }

    // Fallback implementation if the global function is not available
    console.warn(
        "window.buildPatronSearchQuery is not available, using fallback implementation"
    );
    const q = [];
    if (!term) return q;

    const table_prefix = options.table_prefix || "me";
    const search_fields = options.search_fields
        ? options.search_fields.split(",").map(f => f.trim())
        : ["surname", "firstname", "cardnumber", "userid"];

    search_fields.forEach(field => {
        q.push({
            [`${table_prefix}.${field}`]: {
                like: `%${term}%`,
            },
        });
    });

    return [{ "-or": q }];
}

/**
 * Transforms patron data into a consistent format for display
 * @param {Object} patron - The patron object to transform
 * @returns {Object} Transformed patron object with a display label
 */
export function transformPatronData(patron) {
    if (!patron) return null;

    return {
        ...patron,
        label: [
            patron.surname,
            patron.firstname,
            patron.cardnumber ? `(${patron.cardnumber})` : "",
        ]
            .filter(Boolean)
            .join(" ")
            .trim(),
    };
}

/**
 * Transforms an array of patrons using transformPatronData
 * @param {Array|Object} data - The patron data (single object or array)
 * @returns {Array|Object} Transformed patron(s)
 */
export function transformPatronsData(data) {
    if (!data) return [];

    const patrons = Array.isArray(data) ? data : data.results || [];
    return patrons.map(transformPatronData);
}
