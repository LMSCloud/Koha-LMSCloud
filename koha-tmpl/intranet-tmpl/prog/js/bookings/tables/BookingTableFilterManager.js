// @ts-check
/**
 * Booking Table Filter Manager - Encapsulates all filter-related functionality
 * Eliminates global state pollution and provides clean API
 */

import { getStandardStatusOptions } from "./features.js";
import { getWindowValue, setWindowValue } from "./utils.js";

/**
 * Helper utilities for safely interacting with window-scoped properties
 */
/**
 * Get a value from window by key, initializing with a default if undefined.
 * @template T
 * @param {string} key
 * @param {T} defaultValue
 * @returns {T}
 */
// helpers moved to utils.js

// Private state - no global pollution
const instances = new Map();

/**
 * @typedef {{
 *   getLibraryOptions: any[];
 *   getStatusOptions: any[];
 *   getLocationOptions: any[];
 *   getItemTypeOptions: any[];
 * }} FilterOptions
 */

/**
 * @param {string} tableId
 */
function createInstance(tableId) {
    return {
        tableId: tableId,
        /** @type {FilterOptions} */
        filterOptions: {
            getLibraryOptions: /** @type {any[]} */ ([]),
            getStatusOptions: /** @type {any[]} */ ([]),
            getLocationOptions: /** @type {any[]} */ ([]),
            getItemTypeOptions: /** @type {any[]} */ ([]),
        },
        dynamicFiltersPopulated: false,
        dateRangeFilters: new Map(),

        // Initialize filter options for this table instance
        /**
         * @param {string} [variant="default"]
         * @returns {FilterOptions}
         */
        initializeFilterOptions(variant = "default") {
            // Use the global BOOKINGS_LIBRARIES_DATA if available
            // This comes from the template and must be accessed via window
            /** @type {any[]} */
            const libraries = getWindowValue("BOOKINGS_LIBRARIES_DATA", []);
            const all_libraries = libraries.map((/** @type {any} */ e) => ({
                _id: e.branchcode,
                _str: e.branchname,
            }));

            const statusOptions = getStandardStatusOptions();

            this.filterOptions = {
                getLibraryOptions: all_libraries,
                getStatusOptions: statusOptions,
                getLocationOptions: [], // Will be populated dynamically
                getItemTypeOptions: [], // Will be populated dynamically
            };

            // Update global arrays for _dt_add_filters compatibility
            // These need to be on window for Koha's datatables.js to access them
            getWindowValue("getLibraryOptions", []);
            getWindowValue("getStatusOptions", []);

            // Populate with provided options
            setWindowValue("getLibraryOptions", all_libraries);
            setWindowValue("getStatusOptions", statusOptions);

            return this.filterOptions;
        },
    };
}

export const BookingTableFilterManager = {
    // Get or create filter manager instance for a table
    /**
     * @param {string} tableId
     */
    getInstance(tableId) {
        if (!instances.has(tableId)) {
            instances.set(tableId, createInstance(tableId));
        }
        return instances.get(tableId);
    },

    // Clean up instance when table is destroyed
    /**
     * @param {string} tableId
     */
    destroyInstance(tableId) {
        instances.delete(tableId);
    },
};
