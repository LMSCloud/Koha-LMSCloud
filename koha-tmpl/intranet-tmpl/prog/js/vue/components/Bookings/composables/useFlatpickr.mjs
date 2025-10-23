import { onMounted, onUnmounted, watch } from "vue";
import flatpickr from "flatpickr";
import { isoArrayToDates } from "../lib/booking/date-utils.mjs";
import { useBookingStore } from "../../../stores/bookingStore.js";
import {
    applyCalendarHighlighting,
    createOnDayCreate,
    createOnClose,
    createOnChange,
    getVisibleCalendarDates,
    buildMarkerGrid,
    getCurrentLanguageCode,
} from "../lib/adapters/calendar.mjs";
import {
    CLASS_FLATPICKR_DAY,
    CLASS_BOOKING_MARKER_GRID,
} from "../lib/booking/constants.mjs";
import {
    getBookingMarkersForDate,
    aggregateMarkersByType,
} from "../lib/booking/manager.mjs";
import { useConstraintHighlighting } from "./useConstraintHighlighting.mjs";
import { win } from "../lib/adapters/globals.mjs";

/**
 * Flatpickr integration for the bookings calendar.
 *
 * Date type policy:
 * - Store holds ISO strings in selectedDateRange (single source of truth)
 * - Flatpickr works with Date objects; we convert at the boundary
 * - API receives ISO strings
 *
 * @param {{ value: HTMLInputElement|null }} elRef - ref to the input element
 * @param {Object} options
 * @param {import('../types/bookings').BookingStoreLike} [options.store] - booking store (defaults to pinia store)
 * @param {import('../types/bookings').RefLike<import('../types/bookings').DisableFn>} options.disableFnRef - ref to disable fn
 * @param {import('../types/bookings').RefLike<import('../types/bookings').ConstraintOptions>} options.constraintOptionsRef
 * @param {(msg: string) => void} options.setError - set error message callback
 * @param {import('vue').Ref<{visibleStartDate?: Date|null, visibleEndDate?: Date|null}>} [options.visibleRangeRef]
 * @param {import('../types/bookings').RefLike<import('../types/bookings').CalendarMarker[]>} [options.tooltipMarkersRef]
 * @param {import('../types/bookings').RefLike<boolean>} [options.tooltipVisibleRef]
 * @param {import('../types/bookings').RefLike<number>} [options.tooltipXRef]
 * @param {import('../types/bookings').RefLike<number>} [options.tooltipYRef]
 * @returns {{ clear: () => void, getInstance: () => import('../types/bookings').FlatpickrInstanceWithHighlighting | null }}
 */
export function useFlatpickr(elRef, options) {
    const store = options.store || useBookingStore();

    const disableFnRef = options.disableFnRef; // Ref<Function>
    const constraintOptionsRef = options.constraintOptionsRef; // Ref<{dateRangeConstraint,maxBookingPeriod}>
    const setError = options.setError; // function(string)
    const tooltipMarkersRef = options.tooltipMarkersRef; // Ref<Array>
    const tooltipVisibleRef = options.tooltipVisibleRef; // Ref<boolean>
    const tooltipXRef = options.tooltipXRef; // Ref<number>
    const tooltipYRef = options.tooltipYRef; // Ref<number>
    const visibleRangeRef = options.visibleRangeRef; // Ref<{visibleStartDate,visibleEndDate}>

    let fp = null;

    function toDateArrayFromStore() {
        return isoArrayToDates(store.selectedDateRange || []);
    }

    function setDisableOnInstance() {
        if (!fp) return;
        const disableFn = disableFnRef?.value;
        fp.set("disable", [
            typeof disableFn === "function" ? disableFn : () => false,
        ]);
    }

    function syncInstanceDatesFromStore() {
        if (!fp) return;
        try {
            const dates = toDateArrayFromStore();
            if (dates.length > 0) {
                fp.setDate(dates, false);
                if (dates[0] && fp.jumpToDate) fp.jumpToDate(dates[0]);
            } else {
                fp.clear();
            }
        } catch (e) {
            // noop
        }
    }

    onMounted(() => {
        if (!elRef?.value) return;

        const dateFormat =
            typeof win("flatpickr_dateformat_string") === "string"
                ? /** @type {string} */ (win("flatpickr_dateformat_string"))
                : "d.m.Y";

        const langCode = getCurrentLanguageCode();
        const locale = langCode !== "en" ? flatpickr.l10ns[langCode] : undefined;

        /** @type {Partial<import('flatpickr/dist/types/options').Options>} */
        const baseConfig = {
            mode: "range",
            minDate: "today",
            disable: [() => false],
            clickOpens: true,
            dateFormat,
            ...(locale && { locale }),
            allowInput: false,
            onChange: createOnChange(store, {
                setError,
                tooltipVisibleRef: tooltipVisibleRef || { value: false },
                constraintOptions: constraintOptionsRef?.value || {},
            }),
            onClose: createOnClose(
                tooltipMarkersRef || { value: [] },
                tooltipVisibleRef || { value: false }
            ),
            onDayCreate: createOnDayCreate(
                store,
                tooltipMarkersRef || { value: [] },
                tooltipVisibleRef || { value: false },
                tooltipXRef || { value: 0 },
                tooltipYRef || { value: 0 }
            ),
        };

        fp = flatpickr(elRef.value, {
            ...baseConfig,
            onReady: [
                function (_selectedDates, _dateStr, instance) {
                    try {
                        if (visibleRangeRef && instance) {
                            const visible = getVisibleCalendarDates(instance);
                            if (visible && visible.length > 0) {
                                visibleRangeRef.value = {
                                    visibleStartDate: visible[0],
                                    visibleEndDate: visible[visible.length - 1],
                                };
                            }
                        }
                    } catch (e) {
                        // non-fatal
                    }
                },
            ],
            onMonthChange: [
                function (_selectedDates, _dateStr, instance) {
                    try {
                        if (visibleRangeRef && instance) {
                            const visible = getVisibleCalendarDates(instance);
                            if (visible && visible.length > 0) {
                                visibleRangeRef.value = {
                                    visibleStartDate: visible[0],
                                    visibleEndDate: visible[visible.length - 1],
                                };
                            }
                        }
                    } catch (e) {}
                },
            ],
            onYearChange: [
                function (_selectedDates, _dateStr, instance) {
                    try {
                        if (visibleRangeRef && instance) {
                            const visible = getVisibleCalendarDates(instance);
                            if (visible && visible.length > 0) {
                                visibleRangeRef.value = {
                                    visibleStartDate: visible[0],
                                    visibleEndDate: visible[visible.length - 1],
                                };
                            }
                        }
                    } catch (e) {}
                },
            ],
        });

        setDisableOnInstance();
        syncInstanceDatesFromStore();
    });

    // React to availability updates
    if (disableFnRef) {
        watch(disableFnRef, () => {
            setDisableOnInstance();
        });
    }

    // Recalculate visual constraint highlighting when constraint options or rules change
    if (constraintOptionsRef) {
        const { highlightingData } = useConstraintHighlighting(
            store,
            constraintOptionsRef
        );
        watch(
            () => highlightingData.value,
            data => {
                if (!fp || !data) return;
                applyCalendarHighlighting(fp, data);
            }
        );
    }

    // Refresh marker dots when unavailableByDate changes
    watch(
        () => store.unavailableByDate,
        () => {
            if (!fp || !fp.calendarContainer) return;
            try {
                const dayElements = fp.calendarContainer.querySelectorAll(
                    `.${CLASS_FLATPICKR_DAY}`
                );
                dayElements.forEach(dayElem => {
                    const existingGrids = dayElem.querySelectorAll(
                        `.${CLASS_BOOKING_MARKER_GRID}`
                    );
                    existingGrids.forEach(grid => grid.remove());

                    /** @type {import('flatpickr/dist/types/instance').DayElement} */
                    const el = /** @type {import('flatpickr/dist/types/instance').DayElement} */ (dayElem);
                    if (!el.dateObj) return;
                    const markersForDots = getBookingMarkersForDate(
                        store.unavailableByDate,
                        el.dateObj,
                        store.bookableItems
                    );
                    if (markersForDots.length > 0) {
                        const aggregated = aggregateMarkersByType(markersForDots);
                        const grid = buildMarkerGrid(aggregated);
                        if (grid.hasChildNodes()) dayElem.appendChild(grid);
                    }
                });
            } catch (e) {
                // non-fatal
            }
        },
        { deep: true }
    );

    // Sync UI when dates change programmatically
    watch(
        () => store.selectedDateRange,
        () => {
            syncInstanceDatesFromStore();
        },
        { deep: true }
    );

    onUnmounted(() => {
        if (fp?.destroy) fp.destroy();
        fp = null;
    });

    return {
        clear() {
            if (fp?.clear) fp.clear();
        },
        getInstance() {
            return fp;
        },
    };
}
