/// <reference path="./globals.d.ts" />
// @ts-check
/**
 * Main entry point for modular booking table functionality
 * This file imports from individual modules and exports the complete public API
 */

// Import from individual modules
import {
    BOOKING_TABLE_CONSTANTS,
    BOOKING_TABLE_FEATURES,
} from "./constants.js";
import {
    initializeBookingExtendedAttributes,
    filterExtendedAttributesWithValues,
    getBookingTableColumns,
} from "./columns.js";
import {
    getBookingTableFeatures,
    isFeatureEnabled,
    shouldAddDateRangeFilter,
    getColumnFilterType,
    getStandardStatusOptions,
    mapColumnDataToApiField,
    calculateBookingStatus,
} from "./features.js";
import {
    initializeGlobalFilterArrays,
    getBookingsFilterOptions,
    getLibraryFilterOptions,
    createDateFilter,
    createAdditionalFilters,
} from "./filters.js";
import {
    getBookingsEmbed,
    getBookingsUrl,
    getBookingsColumnFilterFlag,
} from "./config.js";
import {
    populateDynamicFilterOptionsFromData,
    updateDynamicFilterDropdowns,
    enhanceBookingTableFilters,
} from "./enhancements.js";
import { BookingTableFilterManager } from "./BookingTableFilterManager.js";

/**
 * Create a unified bookings table with configurable behavior based on variant
 * @param {string|jQuery} tableElement - The table element or selector
 * @param {Object} tableSettings - KohaTable settings object
 * @param {Object} [options={}] - Configuration options
 * @param {string} [options.variant='default'] - The variant to use for table configuration
 *   - 'default': Standard bookings table with basic configuration
 *   - 'pending': Pending bookings table with date filters and library filters
 *   - 'biblio': Biblio-specific bookings table (excludes biblio from embed, uses biblio-specific URL)
 * @param {string} [options.url] - API endpoint URL (auto-configured based on variant if not provided)
 * @param {string} [options.biblionumber] - Biblionumber for biblio-specific variants
 * @param {Array<any>} [options.order=[[7, "asc"]]] - Default sort order (column index, direction)
 * @param {Object} [options.additionalFilters] - Additional filters (auto-configured based on variant)
 * @param {Object} [options.filterOptions] - Filter options (auto-configured based on variant)
 * @param {Array<any>} [options.embed] - Embed configuration (auto-configured based on variant)
 * @param {Object} [options.columnOptions={}] - Column display options
 *   - showCallnumber: {boolean} - Show callnumber column
 *   - showLocation: {boolean} - Show location column
 *   - showPickupLibrary: {boolean} - Show pickup library column
 *   - showBookingDates: {boolean} - Show combined booking dates
 *   - patronOptions: {Object} - Patron display options
 * @returns {jQuery} KohaTable instance
 */
export function createBookingsTable(tableElement, tableSettings, options = {}) {
    const {
        variant = "default",
        url,
        biblionumber,
        order,
        additionalFilters = createAdditionalFilters(variant, /** @type {any} */ (options)),
        // computed later if needed to avoid unused binding warnings
        // filterOptions = getBookingsFilterOptions(variant),
        embed = getBookingsEmbed(variant),
        columnOptions = {},
    } = options;

    // If required extended attribute context is missing, fetch it internally and re-invoke
    if (
        typeof /** @type {any} */ (options).extended_attribute_types === "undefined" ||
        typeof /** @type {any} */ (options).authorised_values === "undefined"
    ) {
        return /** @type {any} */ (initializeBookingExtendedAttributes().then(
            ({ extended_attribute_types, authorised_values }) =>
                createBookingsTable(tableElement, tableSettings, /** @type {any} */ ({
                    ...options,
                    extended_attribute_types,
                    authorised_values,
                }))
        ));
    }

    let finalUrl = url ?? getBookingsUrl(variant, biblionumber);

    // Set default column options based on variant
    let defaultColumnOptions = {
        showCallnumber: false,
        showLocation: false,
        showPickupLibrary: true,
        showBookingDates: true,
        patronOptions: { display_cardnumber: true, url: true },
    };

    // Merge with provided column options
    const finalColumnOptions = { ...defaultColumnOptions, ...columnOptions };

    // Get columns first to determine filter positions
    const columns = getBookingTableColumns(
        /** @type {any} */ (options).extended_attribute_types,
        /** @type {any} */ (options).authorised_values,
        { ...finalColumnOptions, variant: variant }
    );

    // Prepare filter options with column-specific assignments
    let finalFilterOptions = getBookingsFilterOptions(variant);

    // Create headers with data-filter attributes before kohaTable initialization
    const $root = $(/** @type {any} */ (tableElement));
    if ($root.find("thead").length === 0) {
        let headerRow = "<thead><tr>";
        columns.forEach((col, _index) => {
            let dataFilter = "";
            let additionalAttrs = "";

            // Get the filter type for this column using helper function
            const filterType = getColumnFilterType(
                variant,
                col,
                finalColumnOptions
            );
            if (filterType) {
                dataFilter = ` data-filter="${filterType}"`;
            }

            // Check if this column should have date range filtering
            if (shouldAddDateRangeFilter(variant, col)) {
                additionalAttrs = ' data-date-range-filter="true"';
            }

            headerRow += `<th${dataFilter}${additionalAttrs}>${col.title}</th>`;
        });
        headerRow += "</tr></thead>";
        $root.html(headerRow);
    }

    // Generate unique table ID for filter manager
    const tableId = $root.attr("id") || "bookings-table-" + Date.now();
    const filterManager = BookingTableFilterManager.getInstance(tableId);

    const kohaTable = /** @type {any} */ ($root).kohaTable(
        {
            ajax: {
                url: finalUrl,
                dataSrc: function (/** @type {any} */ json) {
                    // Only populate filter options on initial load using instance state
                    if (!filterManager.dynamicFiltersPopulated) {
                        populateDynamicFilterOptionsFromData(
                            json.data || json,
                            filterManager
                        );
                        filterManager.dynamicFiltersPopulated = true;
                    }
                    return json.data || json;
                },
            },
            embed: embed,
            order: order,
            columns: columns,
        },
        tableSettings,
        getBookingsColumnFilterFlag(variant),
        additionalFilters,
        finalFilterOptions
    );

    // Use proper DataTables events instead of setTimeout
    if (getBookingsColumnFilterFlag(variant) === 1) {
        const dataTable = kohaTable.DataTable();

        // Apply custom enhancements based on variant feature configuration
        if (isFeatureEnabled(variant, "customEnhancements")) {
            // Event-driven enhancement after table is fully initialized
            dataTable.on("init.dt", function () {
                enhanceBookingTableFilters(
                    dataTable,
                    tableElement,
                    additionalFilters,
                    filterManager
                );
                // Also update dropdowns on init to ensure they're populated from initial data
                updateDynamicFilterDropdowns(tableElement, filterManager);
            });

            // Handle dynamic filter updates after subsequent data loads
            dataTable.on("xhr.dt", function () {
                // Always update dropdowns after data loads to ensure they're populated
                updateDynamicFilterDropdowns(tableElement, filterManager);
            });
        }
    }

    return kohaTable;
}

/**
 * Convenience function to create a pending bookings table
 * This is equivalent to calling createBookingsTable with variant: 'pending'
 *
 * @param {string|jQuery} tableElement - The table element or selector
 * @param {Object} tableSettings - KohaTable settings object
 * @param {Object} [options={}] - Configuration options (same as createBookingsTable)
 * @returns {jQuery} KohaTable instance configured for pending bookings
 *
 * @example
 * // Create a pending bookings table with custom column options
 * createPendingBookingsTable('#pending-table', tableSettings, {
 *     columnOptions: { showStatus: true, showCreationDate: true }
 * });
 */
export function createPendingBookingsTable(
    tableElement,
    tableSettings,
    options = {}
) {
    return createBookingsTable(tableElement, tableSettings, {
        ...options,
        variant: "pending",
    });
}

/**
 * Convenience function to create a biblio-specific bookings table
 * This is equivalent to calling createBookingsTable with variant: 'biblio'
 *
 * @param {string|jQuery} tableElement - The table element or selector
 * @param {Object} tableSettings - KohaTable settings object
 * @param {string} biblionumber - The biblionumber for the biblio-specific endpoint
 * @param {Object} [options={}] - Configuration options (same as createBookingsTable)
 * @returns {jQuery} KohaTable instance configured for biblio-specific bookings
 *
 * @example
 * // Create a biblio-specific bookings table with custom column options
 * createBiblioBookingsTable('#biblio-table', tableSettings, biblionumber, {
 *     columnOptions: { showStatus: true, showActions: true }
 * });
 */
export function createBiblioBookingsTable(
    tableElement,
    tableSettings,
    biblionumber,
    options = {}
) {
    return createBookingsTable(tableElement, tableSettings, {
        ...options,
        variant: "biblio",
        biblionumber: biblionumber,
    });
}

// Re-export all constants and utilities for backwards compatibility
export {
    // Constants
    BOOKING_TABLE_CONSTANTS,
    BOOKING_TABLE_FEATURES,

    // Column utilities
    initializeBookingExtendedAttributes,
    filterExtendedAttributesWithValues,
    getBookingTableColumns,

    // Feature utilities
    getBookingTableFeatures,
    isFeatureEnabled,
    shouldAddDateRangeFilter,
    getColumnFilterType,
    getStandardStatusOptions,
    mapColumnDataToApiField,
    calculateBookingStatus,

    // Filter utilities
    initializeGlobalFilterArrays,
    getBookingsFilterOptions,
    getLibraryFilterOptions,
    createDateFilter,
    createAdditionalFilters,
    BookingTableFilterManager,

    // Config utilities
    getBookingsEmbed,
    getBookingsUrl,
    getBookingsColumnFilterFlag,

    // Enhancement utilities (typically internal but exported for extensibility)
    populateDynamicFilterOptionsFromData,
    updateDynamicFilterDropdowns,
    enhanceBookingTableFilters,
};

// Initialize global filter arrays on module load
initializeGlobalFilterArrays();
