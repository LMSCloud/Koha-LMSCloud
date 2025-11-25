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
    let $th = null;
    const $root = $(/** @type {any} */ (tableElement));

    // Find status column by th-id in filter row (more reliable than header row index
    // because DataTables removes hidden th from header but filter row uses .hide())
    const aoColumns = dataTable.settings()[0].aoColumns;
    $root
        .find("thead tr:eq(" + BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX + ") th")
        .each(function (/** @type {any} */ _index, el) {
            const $el = $(el);
            const thId = $el.data("th-id");
            // Check if this th's corresponding column is the status column
            if (typeof thId === "number" && aoColumns[thId]) {
                const colName = aoColumns[thId].sName || aoColumns[thId].data;
                if (colName === "status") {
                    statusColumnIndex = thId;
                    $th = $el;
                    return false;
                }
            }
            return undefined;
        });

    if (statusColumnIndex === -1 || !$th) return;

    let statusDropdown = $th.find("select");
    if (statusDropdown.length === 0 || statusDropdown.find("option").length <= 1) {
        if (statusDropdown.length === 0) {
            $th.html('<select></select>');
            statusDropdown = $th.find("select");
        }
        statusDropdown.append(`<option value="active-pending">${__("Active")} ${__("and")} ${__("Pending")}</option>`);
        const statusOptions = getStandardStatusOptions();
        statusOptions.forEach(option => {
            if (statusDropdown.find(`option[value="${option._id}"]`).length === 0) {
                statusDropdown.append(`<option value="${option._id}">${option._str}</option>`);
            }
        });
        statusDropdown.append(`<option value="all">${__("All")}</option>`);
        statusDropdown.val("active-pending");
    }

    const columnIndex = statusColumnIndex;
    if (!filterManager.selectedSyntheticStatus) {
        filterManager.selectedSyntheticStatus = "active-pending";
    }
    if (!filterManager.statusFilterFunction) {
        // Build server-side filter conditions for synthetic statuses
        filterManager.statusFilterFunction = function () {
            const selectedValue = getSelectValueString(statusDropdown) || filterManager.selectedSyntheticStatus || "active-pending";
            const nowIso = new Date().toISOString();
            switch (selectedValue) {
                case "active-pending":
                    return { "-and": [
                        { "me.status": "new" },
                        { "me.end_date": { ">=": nowIso } },
                    ]};
                case "pending":
                    return { "-and": [
                        { "me.status": "new" },
                        { "me.start_date": { ">": nowIso } },
                    ]};
                case "active":
                    return { "-and": [
                        { "me.status": "new" },
                        { "me.start_date": { "<=": nowIso } },
                        { "me.end_date": { ">=": nowIso } },
                    ]};
                case "expired":
                    return { "-and": [
                        { "me.status": "new" },
                        { "me.end_date": { "<": nowIso } },
                    ]};
                case "new":
                    return { "-and": [ { "me.status": "new" } ] };
                case "cancelled":
                    return { "-and": [ { "me.status": "cancelled" } ] };
                case "completed":
                    return { "-and": [ { "me.status": "completed" } ] };
                case "all":
                    return undefined;
                default:
                    return undefined;
            }
        };
        if (typeof additionalFilters === "object" && additionalFilters !== null) {
            // Inject as an AND clause so datatables.js merges it server-side
            /** @type {any} */ (additionalFilters)["-and"] = filterManager.statusFilterFunction;
        }
    }

    statusDropdown.off("change");
    statusDropdown.on("change", function () {
        filterManager.selectedSyntheticStatus = getSelectValueString(statusDropdown);
        // Clear any local search and redraw; server-side will apply AND clause built above
        dataTable.column(columnIndex).search("");
        dataTable.draw();
    });
}


