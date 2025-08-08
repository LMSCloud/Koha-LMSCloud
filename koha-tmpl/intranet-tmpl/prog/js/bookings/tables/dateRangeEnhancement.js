/// <reference path="./globals.d.ts" />
// @ts-check

import { BOOKING_TABLE_CONSTANTS } from "./constants.js";
import { mapColumnDataToApiField } from "./features.js";
import { win, buildDateRangeInput, getFlatpickrConfig, rangeToIsoBounds } from "./utils.js";

/**
 * Enhance table with date range filters using filter manager
 * @param {any} dataTable
 * @param {any} tableElement
 * @param {any} additionalFilters
 * @param {any} filterManager
 */
export function enhanceDateRangeFilters(dataTable, tableElement, additionalFilters, filterManager) {
    if (!filterManager.dateRangeFilters) {
        filterManager.dateRangeFilters = new Map();
    }

    const $root = $(/** @type {any} */ (tableElement));
    $root
        .find(
            "thead tr:eq(" +
                BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX +
                ') th[data-date-range-filter="true"]'
        )
        .each(function (_relativeIndex, el) {
            const $th = $(el);
            const actualColumnIndex = $th.data("th-id");
            if (actualColumnIndex === undefined || $th.find('input[type="text"]').length === 0) {
                return;
            }

            const columnInfo = dataTable.column(actualColumnIndex);
            const columnData = columnInfo.dataSrc();
            const apiFieldName = mapColumnDataToApiField(columnData);
            const inputId = "date_range_col_" + actualColumnIndex;
            const $input = buildDateRangeInput($th, inputId);

            filterManager.dateRangeFilters.set(apiFieldName, function () {
                /** @type {any} */
                const el = $input.get(0);
                const fp = el && el._flatpickr;
                if (!fp || !fp.selectedDates || fp.selectedDates.length === 0) return;
                return rangeToIsoBounds(
                    fp.selectedDates,
                    BOOKING_TABLE_CONSTANTS.DAY_START,
                    BOOKING_TABLE_CONSTANTS.DAY_END
                );
            });

            if (typeof additionalFilters === "object" && additionalFilters !== null) {
                additionalFilters[apiFieldName] = filterManager.dateRangeFilters.get(apiFieldName);
            }

            requestAnimationFrame(() => {
                const fp = win("flatpickr")("#" + inputId, getFlatpickrConfig({
                    onChange: function () {
                        dataTable.column(actualColumnIndex).search("");
                        clearTimeout($input.data("drawTimeout"));
                        $input.data(
                            "drawTimeout",
                            setTimeout(() => dataTable.draw(), BOOKING_TABLE_CONSTANTS.FILTER_REDRAW_DELAY)
                        );
                    },
                    onReady: function (/** @type {any} */ _selectedDates, /** @type {any} */ _dateStr, /** @type {{ input: any; clear: () => void; }} */ instance) {
                        const $wrapper = $("<span/>").css({
                            display: "flex",
                            "justify-content": "center",
                            "align-items": "center",
                        });
                        $(instance.input)
                            .attr("autocomplete", "off")
                            .css("flex", "1")
                            .wrap($wrapper)
                            .after(
                                $("<a/>")
                                    .attr("href", "#")
                                    .attr("aria-label", __("Clear date range"))
                                    .addClass("clear_date fa fa-fw fa-remove")
                                    .on("click", function (e) {
                                        e.preventDefault();
                                        instance.clear();
                                    })
                            );
                    },
                    onClear: function () {
                        dataTable.column(actualColumnIndex).search("");
                        dataTable.draw();
                    },
                }));

                $input.on("click focus", function (e) {
                    e.stopPropagation();
                    fp.open();
                });
            });
        });
}


