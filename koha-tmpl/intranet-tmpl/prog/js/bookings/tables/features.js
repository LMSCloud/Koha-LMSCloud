/// <reference path="./globals.d.ts" />
// @ts-check
/**
 * Feature configuration utilities for booking tables
 */

import {
    BOOKING_TABLE_FEATURES,
    BOOKING_TABLE_CONSTANTS,
} from "./constants.js";
import { dayjsFn } from "./utils.js";

// shared helpers moved to utils.js

/**
 * @typedef {Object} FeatureFlags
 * @property {boolean=} dateRangeFilters
 * @property {boolean=} dynamicLocationFilter
 * @property {boolean=} dynamicItemTypeFilter
 * @property {boolean=} enhancedStatusFilter
 * @property {boolean=} customEnhancements
 */

/**
 * @typedef {Object} Column
 * @property {string=} name
 * @property {string=} type
 * @property {string=} data
 * @property {string=} title
 */

/**
 * @typedef {Object} ColumnOptions
 * @property {boolean=} showHoldingLibrary
 * @property {boolean=} showPickupLibrary
 * @property {boolean=} showLocation
 * @property {boolean=} showItemType
 * @property {string=} linkBiblio
 * @property {{display_cardnumber?: boolean, url?: boolean}=} patronOptions
 */

/**
 * Get feature configuration for a booking table variant
 * @param {string} variant - The table variant ('default', 'pending', 'biblio')
 * @returns {Object} Feature configuration object
 */
export function getBookingTableFeatures(variant = "default") {
    /** @type {Record<string, FeatureFlags>} */
    const FEATURES = /** @type {any} */ (BOOKING_TABLE_FEATURES);
    return FEATURES[variant] || FEATURES.default;
}

/**
 * Check if a feature is enabled for a variant
 * @param {string} variant - The table variant
 * @param {string} feature - The feature name
 * @returns {boolean} Whether the feature is enabled
 */
export function isFeatureEnabled(variant, feature) {
    const features = getBookingTableFeatures(variant);
    /** @type {Record<string, boolean>} */
    const f = /** @type {any} */ (features);
    return f[feature] === true ? true : false;
}

/**
 * Determine if a column should have a date range filter
 * @param {string} variant - The table variant
 * @param {Object} col - The column configuration
 * @returns {boolean} Whether to add date range filter
 */
export function shouldAddDateRangeFilter(variant, /** @type {Column} */ col) {
    return (
        isFeatureEnabled(variant, "dateRangeFilters") &&
        (col.type === "date" || (!!col.name && col.name.includes("date")))
    );
}

/**
 * Determine if a column should have a dynamic dropdown filter
 * @param {string} variant - The table variant
 * @param {Object} col - The column configuration
 * @param {Object} columnOptions - The column display options
 * @returns {string} The data-filter attribute value or empty string
 */
export function getColumnFilterType(
    variant,
    /** @type {Column} */ col,
    /** @type {ColumnOptions} */ columnOptions
) {
    // Status column is handled separately
    if (col.name === "home_library_id" && columnOptions.showHoldingLibrary) {
        return "getLibraryOptions";
    } else if (
        (col.name === "pickup_library" || col.name === "pickup_library_id") &&
        columnOptions.showPickupLibrary
    ) {
        return "getLibraryOptions";
    } else if (
        col.name === "location" &&
        columnOptions.showLocation &&
        isFeatureEnabled(variant, "dynamicLocationFilter")
    ) {
        return "getLocationOptions";
    } else if (
        col.name === "itemtype" &&
        columnOptions.showItemType &&
        isFeatureEnabled(variant, "dynamicItemTypeFilter")
    ) {
        return "getItemTypeOptions";
    }
    return "";
}

/**
 * Get standard status filter options
 * @returns {Array<{ _id: string | number, _str: string }>} Array of status options with _id and _str properties
 */
export function getStandardStatusOptions() {
    return [
        { _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.NEW, _str: __("New") },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.PENDING,
            _str: __("Pending"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.ACTIVE,
            _str: __("Active"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.EXPIRED,
            _str: __("Expired"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.CANCELLED,
            _str: __("Cancelled"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.COMPLETED,
            _str: __("Completed"),
        },
    ];
}

/**
 * Map column data field to API field name for date filtering
 * @param {string} columnData - The column data field name
 * @returns {string} The corresponding API field name
 */
export function mapColumnDataToApiField(columnData) {
    /** @type {Record<string, string>} */
    const fieldMap = {
        creation_date: "me.creation_date",
        start_date: "me.start_date",
        end_date: "me.end_date",
    };
    return fieldMap[columnData] || columnData;
}

/**
 * Calculate the booking status based on the same logic used in the column render function
 * @param {string} dbStatus - The database status value
 * @param {string} startDate - The booking start date
 * @param {string} endDate - The booking end date
 * @returns {string} The calculated status (new, pending, active, expired, cancelled, completed, unknown)
 */
export function calculateBookingStatus(dbStatus, startDate, endDate) {
    /** @param {string} date */
    const isExpired = date => dayjsFn()(date).isBefore(new Date());
    /** @param {string} startDate @param {string} endDate */
    const isActive = (startDate, endDate) => {
        const now = dayjsFn()();
        return (
            now.isAfter(dayjsFn()(startDate)) &&
            now.isBefore(dayjsFn()(endDate).add(1, "day"))
        );
    };

    switch (dbStatus) {
        case "new":
            if (isExpired(endDate)) {
                return "expired";
            }
            if (isActive(startDate, endDate)) {
                return "active";
            }
            if (dayjsFn()(startDate).isAfter(new Date())) {
                return "pending";
            }
            return "new";
        case "cancelled":
            return "cancelled";
        case "completed":
            return "completed";
        default:
            return "unknown";
    }
}
