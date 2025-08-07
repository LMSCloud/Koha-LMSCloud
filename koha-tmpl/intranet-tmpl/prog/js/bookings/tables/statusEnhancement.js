/// <reference path="./globals.d.ts" />
// @ts-check

import { BOOKING_TABLE_CONSTANTS } from "./constants.js";
import { getStandardStatusOptions } from "./features.js";
import { getSelectValueString } from "./utils.js";

/**
 * Enhance status column filtering to handle calculated statuses
 * @param {any} dataTable
 * @param {any} tableElement
 * @param {any} additionalFilters
 * @param {any} filterManager
 */
export function enhanceStatusFilter(dataTable, tableElement, additionalFilters, filterManager) {
    let statusColumnIndex = -1;
    const $root = $(/** @type {any} */ (tableElement));
    $root
        .find("thead tr:eq(" + BOOKING_TABLE_CONSTANTS.HEADER_ROW_INDEX + ") th")
        .each(function (/** @type {any} */ _index, el) {
            if ($(el).text().trim() === __("Status")) {
                statusColumnIndex = _index;
                return false;
            }
            return undefined;
        });

    if (statusColumnIndex === -1) return;

    const $th = $root
        .find("thead tr:eq(" + BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX + ") th")
        .eq(statusColumnIndex);

    let statusDropdown = $th.find("select");
    if (statusDropdown.length === 0 || statusDropdown.find("option").length <= 1) {
        if (statusDropdown.length === 0) {
            $th.html('<select><option value=""></option></select>');
            statusDropdown = $th.find("select");
        }
        const statusOptions = getStandardStatusOptions();
        statusOptions.forEach(option => {
            if (statusDropdown.find(`option[value="${option._id}"]`).length === 0) {
                statusDropdown.append(`<option value="${option._id}">${option._str}</option>`);
            }
        });
    }

    const columnIndex = statusColumnIndex;
    if (!filterManager.selectedSyntheticStatus) {
        filterManager.selectedSyntheticStatus = "";
    }
    if (!filterManager.statusFilterFunction) {
        filterManager.statusFilterFunction = function () {
            const selectedValue = getSelectValueString(statusDropdown);
            if (!selectedValue) return;
            switch (selectedValue) {
                case "new":
                case "pending":
                case "active":
                case "expired":
                    return "new";
                case "cancelled":
                    return "cancelled";
                case "completed":
                    return "completed";
                default:
                    return undefined;
            }
        };
        if (typeof additionalFilters === "object" && additionalFilters !== null) {
            /** @type {any} */ (additionalFilters)["me.status"] = filterManager.statusFilterFunction;
        }
    }

    statusDropdown.off("change");
    statusDropdown.on("change", function () {
        filterManager.selectedSyntheticStatus = getSelectValueString(statusDropdown);
        dataTable.column(columnIndex).search("");
        dataTable.draw();
    });
}


