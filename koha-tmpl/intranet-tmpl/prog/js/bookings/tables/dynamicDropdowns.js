/// <reference path="./globals.d.ts" />
// @ts-check

import { BOOKING_TABLE_CONSTANTS } from "./constants.js";
import { syncSelectOptions } from "./utils.js";

/**
 * Update dynamic filter dropdowns after data changes, preserving selection
 * @param {any} tableElement
 * @param {any} filterManager
 */
export function updateDynamicFilterDropdowns(tableElement, filterManager) {
    const $root = $(/** @type {any} */ (tableElement));
    $root
        .find("thead tr:eq(" + BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX + ") th")
        .each(function (/** @type {any} */ _columnIndex, el) {
            const $th = $(el);
            const filterType = $th.data("filter");
            const $select = $th.find("select");

            if ($select.length > 0) {
                const currentValue = $select.val();
                /** @type {any[]} */
                const options = /** @type {any} */ (filterManager.filterOptions)[filterType];
                if (options && options.length > 0) {
                    syncSelectOptions($select, options);
                    if (currentValue && $select.find(`option[value="${currentValue}"]`).length > 0) {
                        $select.val(currentValue);
                    }
                }
            }
        });
}


