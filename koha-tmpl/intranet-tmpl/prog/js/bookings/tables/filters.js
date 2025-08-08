// @ts-check
/**
 * Filter management and configuration for booking tables
 */

import { BOOKING_TABLE_CONSTANTS } from "./constants.js";
import { BookingTableFilterManager } from "./BookingTableFilterManager.js";
import { getWindowValue, setWindowValue } from "./utils.js";

/**
 * Helper utilities for safely interacting with window-scoped properties
 * while keeping TypeScript happy under // @ts-check.
 */
/**
 * Get a value from window by key, initializing with a default if undefined.
 * Uses bracket notation and hides typing behind any casts.
 * @template T
 * @param {string} key
 * @param {T} defaultValue
 * @returns {T}
 */
// moved to utils.js

/**
 * Initialize and manage global filter arrays for _dt_add_filters compatibility
 * @param {Object} options - Filter options to populate global arrays
 */
/**
 * @typedef {{ _id: string|number, _str: string }} OptionPair
 */

/**
 * @typedef {Object} GlobalFilterArraysOptions
 * @property {OptionPair[]=} getLibraryOptions
 * @property {OptionPair[]=} getStatusOptions
 * @property {OptionPair[]=} getLocationOptions
 * @property {OptionPair[]=} getItemTypeOptions
 */

/**
 * Initialize and manage global filter arrays for _dt_add_filters compatibility
 * @param {GlobalFilterArraysOptions} [options={}] - Filter options to populate global arrays
 */
export function initializeGlobalFilterArrays(options = {}) {
    // These need to be on window for Koha's datatables.js to access them
    // Initialize empty arrays if they don't exist
    getWindowValue("getLibraryOptions", []);
    getWindowValue("getStatusOptions", []);
    getWindowValue("getLocationOptions", []);
    getWindowValue("getItemTypeOptions", []);

    // Populate with provided options
    if (options.getLibraryOptions) {
        setWindowValue("getLibraryOptions", options.getLibraryOptions);
    }
    if (options.getStatusOptions) {
        setWindowValue("getStatusOptions", options.getStatusOptions);
    }
    if (options.getLocationOptions) {
        setWindowValue("getLocationOptions", options.getLocationOptions);
    }
    if (options.getItemTypeOptions) {
        setWindowValue("getItemTypeOptions", options.getItemTypeOptions);
    }
}

/**
 * Get unified library and status filter options
 * @param {string} [variant='default'] - The variant to use for filter options
 * @param {string} [tableId='default'] - Unique identifier for the table instance
 * @returns {Object} Filter options object for KohaTable
 */
export function getBookingsFilterOptions(
    variant = "default",
    tableId = "default"
) {
    const manager = BookingTableFilterManager.getInstance(tableId);
    /** @typedef {{ getLibraryOptions?: any[]; getStatusOptions?: any[] }} FilterOptions */
    /** @type {FilterOptions} */
    const options = /** @type {any} */ (manager.initializeFilterOptions(variant));

    // Ensure global arrays are populated for _dt_add_filters compatibility
    // This handles cases where this function is called before createBookingsTable
    /** @type {any[]} */
    const libOptions = getWindowValue("getLibraryOptions", []);
    if (Array.isArray(libOptions) && libOptions.length === 0) {
        setWindowValue("getLibraryOptions", options.getLibraryOptions || []);
    }
    /** @type {any[]} */
    const statusOptions = getWindowValue("getStatusOptions", []);
    if (Array.isArray(statusOptions) && statusOptions.length === 0) {
        setWindowValue("getStatusOptions", options.getStatusOptions || []);
    }

    return options;
}

/**
 * Backwards compatibility function
 * @deprecated Use getBookingsFilterOptions instead
 */
export function getLibraryFilterOptions(variant = "default") {
    /** @typedef {{ getLibraryOptions?: any[] }} FilterOptions */
    /** @type {FilterOptions} */
    const options = /** @type {any} */ (getBookingsFilterOptions(variant));
    return {
        // Return only library options for backwards compatibility
        [1]: () => options.getLibraryOptions,
    };
}

/**
 * Create a unified date filter function
 * @param {string} fromSelector - CSS selector for the "from" date input
 * @param {string} toSelector - CSS selector for the "to" date input
 * @param {string} [variant='default'] - The variant to use (currently unused, for future extensibility)
 * @returns {Function} A function that returns date filter object for KohaTable
 */
export function createDateFilter(
    fromSelector,
    toSelector,
    variant = "default"
) {
    return function () {
        // Mark variant as intentionally unused while preserving signature
        void variant;
        let fromdate = $(fromSelector);
        let isoFrom;
        if (fromdate.val() !== "") {
            /** @type {any} */
            const fromEl = fromdate.get(0);
            const selectedDate =
                fromEl &&
                fromEl._flatpickr &&
                fromEl._flatpickr.selectedDates &&
                fromEl._flatpickr.selectedDates[0];
            if (selectedDate) {
                selectedDate.setHours(
                    BOOKING_TABLE_CONSTANTS.DAY_START.hour,
                    BOOKING_TABLE_CONSTANTS.DAY_START.minute,
                    BOOKING_TABLE_CONSTANTS.DAY_START.second,
                    BOOKING_TABLE_CONSTANTS.DAY_START.millisecond
                );
                isoFrom = selectedDate.toISOString();
            }
        }

        let todate = $(toSelector);
        let isoTo;
        if (todate.val() !== "") {
            /** @type {any} */
            const toEl = todate.get(0);
            const selectedDate =
                toEl &&
                toEl._flatpickr &&
                toEl._flatpickr.selectedDates &&
                toEl._flatpickr.selectedDates[0];
            if (selectedDate) {
                selectedDate.setHours(
                    BOOKING_TABLE_CONSTANTS.DAY_END.hour,
                    BOOKING_TABLE_CONSTANTS.DAY_END.minute,
                    BOOKING_TABLE_CONSTANTS.DAY_END.second,
                    BOOKING_TABLE_CONSTANTS.DAY_END.millisecond
                );
                isoTo = selectedDate.toISOString();
            }
        }

        if (isoFrom || isoTo) {
            return { ">=": isoFrom, "<=": isoTo };
        } else {
            return;
        }
    };
}

/**
 * Create unified additional filters based on variant
 * @param {string} [variant='default'] - The variant to use for filter configuration
 *   - 'default': No additional filters (empty object)
 *   - 'pending': Includes date range, holding library, and pickup library filters
 * @param {Object} [options={}] - Options for customizing selectors
 * @param {string} [options.fromSelector='#from'] - CSS selector for "from" date input
 * @param {string} [options.toSelector='#to'] - CSS selector for "to" date input
 * @param {string} [options.holdingLibrarySelector='#holding_library'] - CSS selector for holding library dropdown
 * @param {string} [options.pickupLibrarySelector='#pickup_library'] - CSS selector for pickup library dropdown
 * @returns {Object} Additional filters object for KohaTable
 */
export function createAdditionalFilters(variant = "default", options = {}) {
    const {
        fromSelector = "#from",
        toSelector = "#to",
        holdingLibrarySelector = "#holding_library",
        pickupLibrarySelector = "#pickup_library",
    } = options;

    switch (variant) {
        case "pending":
            return {
                "me.start_date": createDateFilter(fromSelector, toSelector, variant),
                // Server field names must match API
                "item.home_library_id": function () {
                    let library = $(holdingLibrarySelector)
                        .find(":selected")
                        .val();
                    return library;
                },
                "me.pickup_library_id": function () {
                    let library = $(pickupLibrarySelector)
                        .find(":selected")
                        .val();
                    return library;
                },
            };
        case "default":
        default:
            return {};
    }
}
