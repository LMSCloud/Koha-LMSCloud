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
import { fetchItemTypeFilterOptions, setWindowValue } from "./utils.js";

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

    // Pre-fetch all item types for the filter dropdown (parent + child hierarchy)
    if (
        isFeatureEnabled(variant, "dynamicItemTypeFilter") &&
        !(/** @type {any} */ (options)._itemTypesFetched)
    ) {
        return /** @type {any} */ (
            fetchItemTypeFilterOptions().then(({ options: itOptions, parentMap, groups }) => {
                setWindowValue("getItemTypeOptions", itOptions);
                return createBookingsTable(
                    tableElement,
                    tableSettings,
                    /** @type {any} */ ({
                        ...options,
                        _itemTypesFetched: true,
                        _itemTypeParentMap: parentMap,
                        _itemTypeGroups: groups,
                    })
                );
            })
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

        // Reorder tableSettings.columns to match actual column order for correct visibility handling
        if (tableSettings && tableSettings.columns) {
            const settingsMap = new Map(
                tableSettings.columns.map((/** @type {any} */ c) => [c.columnname, c])
            );
            // Handle column name aliases (e.g., pickup_library_id -> pickup_library)
            const aliasMap = { pickup_library_id: "pickup_library" };
            tableSettings.columns = columns
                .map(col => settingsMap.get(col.name) || settingsMap.get(aliasMap[col.name]))
                .filter(Boolean);
        }
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

    // Sync pre-fetched itemtype options into this filterManager instance
    // so updateDynamicFilterDropdowns can populate the dropdown without relying on eval()
    if (/** @type {any} */ (options)._itemTypesFetched) {
        /** @type {any} */
        const w = window;
        const itOpts = w["getItemTypeOptions"] || [];
        if (itOpts.length > 0) {
            filterManager.filterOptions.getItemTypeOptions = itOpts;
        }
    }

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
                // Parent-child itemtype map for search expansion
                itemTypeParentMap: /** @type {any} */ (options)._itemTypeParentMap || {},
                // Grouped itemtype data for building optgroup selects
                itemTypeGroups: /** @type {any} */ (options)._itemTypeGroups || [],
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
            autoWidth: false,
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
 * @param {{ dateRange?: boolean, status?: boolean, quickToggles?: boolean, itemTypeParentMap?: Record<string, string[]>, itemTypeGroups?: Array<any> }} [enhancementOptions]
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

        // Enhance itemtype filter to expand parent selections to include children
        const parentMap = enhancementOptions && enhancementOptions.itemTypeParentMap;
        const groups = enhancementOptions && enhancementOptions.itemTypeGroups;
        if (parentMap && Object.keys(parentMap).length > 0) {
            enhanceItemTypeFilterSearch(dataTable, tableElement, parentMap, additionalFilters, groups || []);
        }
    });
    dataTable.on("xhr.dt", function () {
        updateDynamicFilterDropdowns(tableElement, filterManager);
    });
}

/**
 * Enhance the itemtype column filter so that selecting a parent type
 * also matches all its child types via additionalFilters (proper API query).
 * Rebuilds the select with optgroup elements following Koha convention.
 * @param {any} dataTable - The DataTables instance
 * @param {jQuery|string} tableElement - The table element or selector
 * @param {Record<string, string[]>} parentMap - Maps parent type IDs to arrays of child type IDs
 * @param {Object<string, any>} additionalFilters - The additionalFilters object passed to kohaTable
 * @param {Array<any>} groups - Grouped itemtype data with parent/children structure
 */
function enhanceItemTypeFilterSearch(dataTable, tableElement, parentMap, additionalFilters, groups) {
    const $root = $(/** @type {any} */ (tableElement));
    const filterRowIndex = BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX;
    $root.find("thead tr:eq(" + filterRowIndex + ") th").each(function () {
        const $th = $(this);
        if ($th.data("filter") !== "getItemTypeOptions") return;

        const colIndex = $th.data("th-id");
        if (typeof colIndex === "undefined") return;

        // Rebuild select with optgroup hierarchy (Koha convention from smart-rules.tt)
        if (groups && groups.length > 0) {
            const $select = $('<select><option value=""></option></select>');
            groups.forEach(group => {
                if (group.children && group.children.length > 0) {
                    const $optgroup = $("<optgroup/>").attr("label", group._str);
                    $optgroup.append(
                        $("<option/>").val(group._id).text(group._str + " (" + __("All") + ")")
                    );
                    group.children.forEach(child => {
                        $optgroup.append($("<option/>").val(child._id).text(child._str));
                    });
                    $select.append($optgroup);
                } else {
                    $select.append($("<option/>").val(group._id).text(group._str));
                }
            });
            $th.empty().append($select);
        }

        const $select = $th.find("select");
        if ($select.length === 0) return;

        // Replace the default change handler with one that uses additionalFilters
        $select.off("keyup change").on("change", function () {
            const val = /** @type {string} */ ($select.val());

            // Clear any column-level search so it doesn't conflict
            dataTable.column(colIndex).search("", false, false);

            if (!val || !val.length) {
                delete additionalFilters["item.item_type_id"];
            } else {
                const children = parentMap[val];
                if (children && children.length > 0) {
                    const allValues = [val, ...children];
                    additionalFilters["item.item_type_id"] = () => allValues;
                } else {
                    additionalFilters["item.item_type_id"] = () => val;
                }
            }

            dataTable.draw();
        });
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
