/// <reference path="./globals.d.ts" />
// @ts-check
/**
 * Main entry point for modular booking table functionality
 * This file imports from individual modules and exports the complete public API
 */

/**
 * @typedef {"default"|"pending"|"biblio"} TableVariant
 */

/**
 * Column display options
 * Mirrors the options forwarded to getBookingTableColumns
 * @typedef {Object} TableColumnOptions
 * @property {boolean=} showActions
 * @property {boolean=} showStatus
 * @property {boolean=} showCreationDate
 * @property {boolean=} showCallnumber
 * @property {boolean=} showLocation
 * @property {boolean=} showItemType
 * @property {boolean=} showPickupLibrary
 * @property {boolean=} showHoldingLibrary
 * @property {boolean=} showBookingDates
 * @property {boolean=} showStartEndDates
 * @property {{display_cardnumber?: boolean, url?: boolean}=} patronOptions
 * @property {boolean=} showBiblioTitle
 * @property {boolean=} showItemData
 * @property {TableVariant=} variant
 */

/**
 * Options for createBookingsTable
 * @typedef {Object} CreateBookingsTableOptions
 * @property {TableVariant=} variant
 * @property {string=} url
 * @property {string=} biblionumber
 * @property {Array<any>=} order
 * @property {Array<string>=} columnOrder - Array of column names to specify display order
 * @property {Object<string, any|(()=>any)>=} additionalFilters
 * @property {Object<string, any>=} filterOptions
 * @property {Array<string>=} embed
 * @property {TableColumnOptions=} columnOptions
 * @property {any=} extended_attribute_types
 * @property {any=} authorised_values
 * @property {boolean=} columnFiltersEnabled
 * @property {boolean=} quickTogglesEnabled
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
 * @param {string|any} tableElement - The table element or selector
 * @param {Object} tableSettings - KohaTable settings object
 * @param {CreateBookingsTableOptions} [options={}] - Configuration options
 * @returns {any} KohaTable instance
 */
export function createBookingsTable(tableElement, tableSettings, /** @type {CreateBookingsTableOptions} */ options = {}) {
    const {
        variant = "default",
        url,
        biblionumber,
        order,
        additionalFilters = createAdditionalFilters(
            variant,
            /** @type {any} */ (options)
        ),
        // computed later if needed to avoid unused binding warnings
        // filterOptions = getBookingsFilterOptions(variant),
        embed = getBookingsEmbed(variant),
        columnOptions = {},
    } = options;

    // If required extended attribute context is missing, fetch it internally and re-invoke
    if (
        typeof (/** @type {any} */ (options).extended_attribute_types) ===
            "undefined" ||
        typeof (/** @type {any} */ (options).authorised_values) === "undefined"
    ) {
        return /** @type {any} */ (
            initializeBookingExtendedAttributes().then(
                ({ extended_attribute_types, authorised_values }) =>
                    createBookingsTable(
                        tableElement,
                        tableSettings,
                        /** @type {any} */ ({
                            ...options,
                            extended_attribute_types,
                            authorised_values,
                        })
                    )
            )
        );
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
    let columns = getBookingTableColumns(
        /** @type {any} */ (options).extended_attribute_types,
        /** @type {any} */ (options).authorised_values,
        { ...finalColumnOptions, variant: variant }
    );

    // Reorder columns if columnOrder array is provided
    if (options.columnOrder && Array.isArray(options.columnOrder)) {
        /**
         * @type {any[]}
         */
        const orderedColumns = [];
        const columnMap = new Map(columns.map(col => [col.name, col]));

        options.columnOrder.forEach(name => {
            if (columnMap.has(name)) {
                orderedColumns.push(columnMap.get(name));
                columnMap.delete(name);
            }
        });

        // Append remaining columns not specified in order
        columnMap.forEach(col => orderedColumns.push(col));
        columns = orderedColumns;
    }

    // Compute whether column filters should be enabled (allow explicit override)
    const columnFiltersFlag =
        typeof (/** @type {any} */ (options).columnFiltersEnabled) === "boolean"
            ? ((/** @type {any} */ (options).columnFiltersEnabled) ? 1 : 0)
            : getBookingsColumnFilterFlag(variant);

    // Prepare filter options with column-specific assignments
    let finalFilterOptions = columnFiltersFlag === 1 ? getBookingsFilterOptions(variant) : {};

    // Create headers with data-filter attributes before kohaTable initialization
    /** @type {any} */
    const $root = $(/** @type {any} */ (tableElement));
    if ($root.find("thead").length === 0) {
        $root.html(
            columnFiltersFlag === 1
                ? buildHeaderWithFilters(columns, variant, finalColumnOptions)
                : buildPlainHeader(columns)
        );
    }

    // Generate unique table ID for filter manager
    const tableId = /** @type {string} */ ($root.attr("id") || ("bookings-table-" + Date.now()));
    const filterManager = BookingTableFilterManager.getInstance(tableId);

    // Apply default quick toggle filters before first draw so initial load hides expired/cancelled
    if ((/** @type {any} */ (options)).quickTogglesEnabled) {
        applyDefaultQuickToggleFilters(additionalFilters);
    }

    // Set up default status filter for 'default' variant
    if (variant === 'default' && columnFiltersFlag === 1) {
        additionalFilters["-and"] = function() {
            const nowIso = new Date().toISOString();
            return { "-and": [
                { "me.status": "new" },
                { "me.end_date": { ">=": nowIso } },
            ]};
        };
    }

    const kohaTable = initKohaTable(
        $root,
        finalUrl,
        embed,
        order ?? [],
        columns,
        tableSettings,
        variant,
        columnFiltersFlag,
        additionalFilters,
        finalFilterOptions,
        filterManager
    );

    // Use proper DataTables events instead of setTimeout
    if (columnFiltersFlag === 1 || (/** @type {any} */ (options).quickTogglesEnabled)) {
        const dataTable = kohaTable.DataTable();

        // Compute and expose status column metadata via data attributes on the table element
        const statusMeta = getStatusColumnMeta(tableSettings);
        try {
            $root.attr('data-status-hidden-default', statusMeta.isHidden ? '1' : '0');
            $root.attr('data-status-cannot-toggle', statusMeta.cannotBeToggled ? '1' : '0');
            $root.attr('data-bookings-variant', variant);
        } catch (e) { /* ignore */ }

        wireEnhancements(
            dataTable,
            tableElement,
            variant,
            additionalFilters,
            filterManager,
            {
                // Only enable column-based date/status enhancements when column filters are on
                dateRange: columnFiltersFlag === 1,
                // Only enable status enhancement if the status column exists and is user-toggleable
                status: columnFiltersFlag === 1 && isStatusColumnToggleable(tableSettings),
                // Quick toggles are explicitly controlled
                quickToggles: /** @type {any} */ (options).quickTogglesEnabled === true,
            }
        );
    }
    /**
     * Determine if the 'status' column is present, not hidden by default, and can be toggled
     * Uses DataTables table_settings columns metadata populated via Template Toolkit
     * @param {any} tableSettings
     * @returns {boolean}
     */
    function isStatusColumnToggleable(tableSettings) {
        try {
            const cols = (tableSettings && tableSettings.columns) || [];
            const statusCol = cols.find((/** @type {any} */ c) => c.columnname === 'status');
            if (!statusCol) return false; // no status column configured
            // cannot_be_toggled === "0" means user can toggle; "1" means fixed
            const canToggle = String(statusCol.cannot_be_toggled) === '0';
            // If it is hidden by default, treat as not eligible for our enhancement toggling
            const isHidden = String(statusCol.is_hidden) === '1';
            return canToggle && !isHidden;
        } catch (e) {
            return false;
        }
    }

    /**
     * Extract status column metadata from table settings
     * @param {any} tableSettings
     * @returns {{ exists: boolean, isHidden: boolean, cannotBeToggled: boolean, canToggle: boolean }}
     */
    function getStatusColumnMeta(tableSettings) {
        try {
            const cols = (tableSettings && tableSettings.columns) || [];
            const statusCol = cols.find((/** @type {any} */ c) => c.columnname === 'status');
            if (!statusCol) return { exists: false, isHidden: false, cannotBeToggled: false, canToggle: false };
            const isHidden = String(statusCol.is_hidden) === '1';
            const cannotBeToggled = String(statusCol.cannot_be_toggled) === '1';
            return { exists: true, isHidden, cannotBeToggled, canToggle: !cannotBeToggled };
        } catch (e) {
            return { exists: false, isHidden: false, cannotBeToggled: false, canToggle: false };
        }
    }

    return kohaTable;
}

/**
 * Build header HTML with filter metadata
 * @param {Array<any>} columns
 * @param {TableVariant} variant
 * @param {TableColumnOptions} columnOptions
 * @returns {string}
 */
function buildHeaderWithFilters(columns, variant, columnOptions) {
    let headerRow = "<thead><tr>";
    columns.forEach(col => {
        let dataFilter = "";
        let additionalAttrs = "";
        const filterType = getColumnFilterType(variant, col, columnOptions);
        if (filterType) dataFilter = ` data-filter="${filterType}"`;
        if (shouldAddDateRangeFilter(variant, col)) {
            additionalAttrs = ' data-date-range-filter="true"';
        }
        headerRow += `<th${dataFilter}${additionalAttrs}>${col.title}</th>`;
    });
    headerRow += "</tr></thead>";
    return headerRow;
}

/**
 * Build simple header without filter metadata
 * @param {Array<any>} columns
 * @returns {string}
 */
function buildPlainHeader(columns) {
    let headerRow = "<thead><tr>";
    columns.forEach(col => {
        headerRow += `<th>${col.title}</th>`;
    });
    headerRow += "</tr></thead>";
    return headerRow;
}

/**
 * Initialize kohaTable with data hooks and embeds
 * @param {any} $root
 * @param {string} url
 * @param {Array<string>} embed
 * @param {Array<any>} order
 * @param {Array<any>} columns
 * @param {Object} tableSettings
 * @param {TableVariant} variant
 * @param {0|1} columnFiltersFlag
 * @param {Object<string, any>} additionalFilters
 * @param {Object<string, any>} finalFilterOptions
 * @param {any} filterManager
 * @returns {any}
 */
function initKohaTable(
    $root,
    url,
    embed,
    order,
    columns,
    tableSettings,
    variant,
    columnFiltersFlag,
    additionalFilters,
    finalFilterOptions,
    filterManager
) {
    void variant;
    return /** @type {any} */ ($root).kohaTable(
        {
            ajax: {
                url: url,
                dataSrc: function (/** @type {any} */ json) {
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
        columnFiltersFlag,
        additionalFilters,
        finalFilterOptions
    );
}

/**
 * Apply default quick toggle filters to additionalFilters map
 * Ensures initial load hides expired, cancelled and completed when quick toggles are enabled
 * @param {Object<string, any>} additionalFilters
 */
function applyDefaultQuickToggleFilters(additionalFilters) {
    if (!additionalFilters["me.end_date"]) {
        additionalFilters["me.end_date"] = function () {
            const now = new Date();
            return { ">=": now.toISOString() };
        };
    }
    if (!additionalFilters["me.status"]) {
        additionalFilters["me.status"] = function () {
            return ["new"];
        };
    }
}

/**
 * Wire enhancements and dynamic dropdown updates to DataTables events
 * @param {any} dataTable
 * @param {string|any} tableElement
 * @param {TableVariant} variant
 * @param {Object<string, any>} additionalFilters
 * @param {any} filterManager
 * @param {{ dateRange?: boolean, status?: boolean, quickToggles?: boolean }} [enhancementOptions]
 * @returns {void}
 */
function wireEnhancements(
    dataTable,
    tableElement,
    variant,
    additionalFilters,
    filterManager,
    enhancementOptions
) {
    // Allow quick toggles even if custom enhancements are disabled for the variant
    const wantQuickToggles = enhancementOptions && enhancementOptions.quickToggles === true;
    if (!isFeatureEnabled(variant, "customEnhancements") && !wantQuickToggles) return;
    dataTable.on("init.dt", function () {
        enhanceBookingTableFilters(
            dataTable,
            tableElement,
            additionalFilters,
            filterManager,
            enhancementOptions
        );
        updateDynamicFilterDropdowns(tableElement, filterManager);
    });
    dataTable.on("xhr.dt", function () {
        updateDynamicFilterDropdowns(tableElement, filterManager);
    });
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
