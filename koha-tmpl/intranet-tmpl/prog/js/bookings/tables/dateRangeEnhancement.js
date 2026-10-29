/// <reference path="./globals.d.ts" />
// @ts-check

import { BOOKING_TABLE_CONSTANTS } from "./constants.js";
import { mapColumnDataToApiField } from "./features.js";
import {
    win,
    buildDateRangeInput,
    getFlatpickrConfig,
    rangeToIsoBounds,
} from "./utils.js";

/**
 * Enhance table with date range filters using filter manager
 * @param {any} dataTable
 * @param {any} tableElement
 * @param {any} additionalFilters
 * @param {any} filterManager
 */
export function enhanceDateRangeFilters(
    dataTable,
    tableElement,
    additionalFilters,
    filterManager
) {
    if (!filterManager.dateRangeFilters) {
        filterManager.dateRangeFilters = new Map();
    }
    if (!filterManager.dateRangeInputs) {
        filterManager.dateRangeInputs = new Map();
    }
    if (!filterManager.dateRangeSelections) {
        filterManager.dateRangeSelections = new Map();
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
            const columnInfo = dataTable.column($th[0]);
            const actualColumnIndex = columnInfo.index();
            if (
                actualColumnIndex === undefined ||
                $th.find('input[type="text"]').length === 0
            ) {
                return;
            }
            const columnData = columnInfo.dataSrc();
            const apiFieldName = mapColumnDataToApiField(columnData);

            // The selected range lives in the filter manager, so a rebuilt
            // filter row shows the range chosen in the input it replaces
            const previous = filterManager.dateRangeInputs.get(apiFieldName);
            /** @type {any} */
            const previousFp = previous && previous.get(0)?._flatpickr;
            if (previousFp) previousFp.destroy();
            const selectedDates =
                filterManager.dateRangeSelections.get(apiFieldName) || [];

            const inputId = "date_range_col_" + actualColumnIndex;
            const $input = buildDateRangeInput($th, inputId);
            filterManager.dateRangeInputs.set(apiFieldName, $input);

            filterManager.dateRangeFilters.set(apiFieldName, function () {
                /** @type {any} */
                const el = $input.get(0);
                const fp = el && el._flatpickr;
                if (!fp || !fp.selectedDates || fp.selectedDates.length === 0)
                    return;
                return rangeToIsoBounds(
                    fp.selectedDates,
                    BOOKING_TABLE_CONSTANTS.DAY_START,
                    BOOKING_TABLE_CONSTANTS.DAY_END
                );
            });

            if (
                typeof additionalFilters === "object" &&
                additionalFilters !== null
            ) {
                additionalFilters[apiFieldName] =
                    filterManager.dateRangeFilters.get(apiFieldName);
            }

            requestAnimationFrame(() => {
                const inputEl = $input.get(0);
                // A rebuild in the same frame has already replaced this input
                if (!inputEl || !inputEl.isConnected) return;
                const fp = win("flatpickr")(
                    inputEl,
                    getFlatpickrConfig({
                        defaultDate: selectedDates.length
                            ? selectedDates
                            : undefined,
                        onChange: function (/** @type {Date[]} */ dates) {
                            filterManager.dateRangeSelections.set(
                                apiFieldName,
                                dates.slice()
                            );
                            dataTable.column(actualColumnIndex).search("");
                            clearTimeout($input.data("drawTimeout"));
                            $input.data(
                                "drawTimeout",
                                setTimeout(
                                    () => dataTable.draw(),
                                    BOOKING_TABLE_CONSTANTS.FILTER_REDRAW_DELAY
                                )
                            );
                        },
                        onReady: function (
                            /** @type {any} */ _selectedDates,
                            /** @type {any} */ _dateStr,
                            /** @type {{ input: any; clear: () => void; }} */ instance
                        ) {
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
                                        .attr(
                                            "aria-label",
                                            __("Clear date range")
                                        )
                                        .addClass(
                                            "clear_date fa fa-fw fa-remove"
                                        )
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
                    })
                );

                $input.on("click focus", function (e) {
                    e.stopPropagation();
                    fp.open();
                });
            });
        });
}
