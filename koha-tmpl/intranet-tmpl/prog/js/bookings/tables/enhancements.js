/// <reference path="./globals.d.ts" />
// @ts-check
/**
 * Filter enhancement functionality for booking tables
 */

import { calculateBookingStatus } from "./features.js";
import { BOOKING_TABLE_CONSTANTS } from "./constants.js";
import { enhanceDateRangeFilters } from "./dateRangeEnhancement.js";
import { enhanceStatusFilter } from "./statusEnhancement.js";
import { updateDynamicFilterDropdowns as updateDynamicFilterDropdownsDynamic } from "./dynamicDropdowns.js";

// shared helpers moved to utils.js

/**
 * @typedef {{
 *   getLibraryOptions: any[];
 *   getStatusOptions: any[];
 *   getLocationOptions: any[];
 *   getItemTypeOptions: any[];
 * }} FilterOptions
 */

/**
 * @typedef {{
 *   tableId: string;
 *   filterOptions: FilterOptions;
 *   dynamicFiltersPopulated: boolean;
 *   dateRangeFilters: Map<string, () => any>;
 *   selectedSyntheticStatus?: string;
 *   statusFilterFunction?: () => string | undefined;
 * }} FilterManager
 */

/**
 * Enhance table with date range filters using filter manager
 * Replaces setTimeout-based approach with proper event handling
 * @param {any} dataTable - The DataTables instance
 * @param {any} tableElement - The table element or selector
 * @param {any} additionalFilters - Additional filters object to populate
 * @param {FilterManager} filterManager - The filter manager instance
 */
/**
 * Enhance status column filtering to handle calculated statuses
 * The status column shows calculated statuses (Expired, Active, Pending) but the database
 * only stores raw statuses (new, cancelled, completed). This function creates proper filters
 * that map the calculated statuses to the appropriate database queries.
 */
/**
 * Apply client-side status filtering to hide rows that don't match the calculated status
 * This is the "second stage" that filters the server results further based on date calculations
 * @param {any} dataTable - The DataTables instance
 * @param {string} selectedStatus - The selected status filter value
 */
export function applyClientSideStatusFilter(dataTable, selectedStatus) {
    dataTable.rows().every(function () {
        const row = this;
        const data = row.data();
        if (!data || !data.start_date || !data.end_date) return;
        const calculatedStatus = calculateBookingStatus(
            data.status,
            data.start_date,
            data.end_date
        );
        const show =
            !selectedStatus ||
            calculatedStatus.toLowerCase() === selectedStatus.toLowerCase();
        $(row.node()).toggle(show);
    });
}

/**
 * Populate dynamic filter options from raw API data using filter manager
 * @param {Array<any>|Object} data - The raw API data or response object
 * @param {FilterManager} filterManager - The filter manager instance
 */
export function populateDynamicFilterOptionsFromData(data, filterManager) {
    const rows = Array.isArray(data) ? data : (/** @type {any} */ (data)).data || [];

    // Collect unique locations and item types
    const locations = new Map();
    const itemTypes = new Map();

    rows.forEach(function (/** @type {any} */ row) {
        // Extract location data
        if (row.item?.location && row.item._strings?.location) {
            const locationCode = row.item.location;
            const locationName = row.item._strings.location.str || locationCode;
            locations.set(locationCode, locationName);
        }

        // Extract item type data
        if (row.item?._strings?.item_type_id) {
            const itemTypeCode =
                row.item.itype ||
                row.item.item_type_id ||
                row.item.itemtype ||
                Object.keys(row.item).find(
                    key =>
                        key.toLowerCase().includes("type") ||
                        key.toLowerCase().includes("itype")
                )?.[0];

            if (itemTypeCode) {
                const itemTypeName =
                    row.item._strings.item_type_id.str || itemTypeCode;
                itemTypes.set(itemTypeCode, itemTypeName);
            }
        }
    });

    // Update filter manager instance instead of global arrays
    const locationOptions = Array.from(locations.entries())
        .map(([code, name]) => ({ _id: code, _str: name }))
        .sort((a, b) => a._str.localeCompare(b._str));

    const itemTypeOptions = Array.from(itemTypes.entries())
        .map(([code, name]) => ({ _id: code, _str: name }))
        .sort((a, b) => a._str.localeCompare(b._str));

    // Store in manager instance and update global references for Koha compatibility
    filterManager.filterOptions.getLocationOptions = locationOptions;
    filterManager.filterOptions.getItemTypeOptions = itemTypeOptions;

    // Update global arrays for _dt_add_filters compatibility
    // Always update on initial population, preserve selection state via updateDynamicFilterDropdowns
    /** @type {any} */ (window)["getLocationOptions"] = locationOptions;
    /** @type {any} */ (window)["getItemTypeOptions"] = itemTypeOptions;
}

/**
 * Update dynamic filter dropdowns after data changes
 * Preserves current selection to prevent reset behavior
 * @param {jQuery|string} tableElement - The table element or selector
 * @param {FilterManager} filterManager - The filter manager instance
 */
export function updateDynamicFilterDropdowns(tableElement, filterManager) {
    const $root = $(/** @type {any} */ (tableElement));
    $root
        .find(
            "thead tr:eq(" + BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX + ") th"
        )
        .each(function (/** @type {any} */ _columnIndex, el) {
            const $th = $(el);
            const filterType = $th.data("filter");
            const $select = $th.find("select");

            if ($select.length > 0) {
                // Save current selection before updating
                const currentValue = $select.val();

                /** @type {any[]} */
                const options = /** @type {any} */ (
                    filterManager.filterOptions
                )[filterType];
                if (options && options.length > 0) {
                    // Only update if options are different or empty
                    const currentOptions = $select
                        .find("option")
                        .not(":first")
                        .map(function () {
                            return $(this).val();
                        })
                        .get();

                    const newOptionValues = options.map((/** @type {any} */ opt) => opt._id);

                    // Update if options have changed OR if dropdown is empty (initial load)
                    if (
                        currentOptions.length === 0 ||
                        currentOptions.length !== newOptionValues.length ||
                        !currentOptions.every(val =>
                            newOptionValues.includes(val)
                        )
                    ) {
                        // Clear existing options except the empty one
                        $select.find("option").not(":first").remove();
                        // Add new options
                        options.forEach((/** @type {any} */ option) => {
                            $select.append(
                                `<option value="${option._id}">${option._str}</option>`
                            );
                        });

                        // Restore previous selection if it still exists
                        if (
                            currentValue &&
                            $select.find(`option[value="${currentValue}"]`)
                                .length > 0
                        ) {
                            $select.val(currentValue);
                        }
                    }
                }
            }
        });
}

/**
 * Consolidated booking table filter enhancement system
 * Replaces individual enhancement functions with unified approach
 * @param {any} dataTable - The DataTables instance
 * @param {jQuery|string} tableElement - The table element or selector
 * @param {Object} additionalFilters - Additional filters object
 * @param {FilterManager} filterManager - The filter manager instance
 */
export function enhanceBookingTableFilters(
    dataTable,
    tableElement,
    additionalFilters,
    filterManager
) {
    // Enhanced filters in priority order
    const enhancements = [
        { type: "dateRange", handler: enhanceDateRangeFilters },
        { type: "status", handler: enhanceStatusFilter },
        { type: "dynamic", handler: updateDynamicFilterDropdownsDynamic },
    ];

    enhancements.forEach(enhancement => {
        try {
            (/** @type {any} */ (enhancement.handler))(
                dataTable,
                tableElement,
                additionalFilters,
                filterManager
            );
        } catch (error) {
            console.warn(
                `Failed to enhance ${enhancement.type} filters:`,
                error
            );
        }
    });
}
