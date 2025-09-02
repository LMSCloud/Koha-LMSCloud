import { onMounted, onUnmounted, watch } from "vue";
import flatpickr from "flatpickr";
import dayjs from "../../../utils/dayjs.mjs";
import { useBookingStore } from "../../../stores/bookingStore.js";
import {
    applyCalendarHighlighting,
    createOnDayCreate,
    createOnClose,
} from "../lib/booking/bookingCalendar.mjs";
import {
    handleBookingDateChange,
    getVisibleCalendarDates,
    calculateConstraintHighlighting,
    deriveEffectiveRules,
} from "../lib/booking/bookingManager.mjs";
import { win } from "../lib/index.mjs";

/**
 * Flatpickr integration for the bookings calendar.
 * Date type policy:
 * - Store holds ISO strings in selectedDateRange (single source of truth)
 * - Flatpickr works with Date objects; we convert at the boundary
 * - API receives ISO strings
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

    let fp = null;

    function toDateArrayFromStore() {
        const current = store.selectedDateRange || [];
        return (current || []).filter(Boolean).map(d => dayjs(d).toDate());
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

    function handleOnChange(selectedDates, _dateStr, instance) {
        // Sanitize dates
        const valid = (selectedDates || []).filter(
            d => d instanceof Date && !Number.isNaN(d.getTime())
        );
        if ((selectedDates || []).length > 0 && valid.length === 0) {
            return;
        }

        const isoRange = valid.map(d => dayjs(d).toISOString());
        const current = store.selectedDateRange || [];
        const same =
            current.length === isoRange.length &&
            current.every((v, i) => v === isoRange[i]);
        if (!same) store.selectedDateRange = isoRange;

        // Effective rules and validation
        const baseRules =
            (store.circulationRules && store.circulationRules[0]) || {};
        const constraintOptions = constraintOptionsRef?.value || {};
        const effectiveRules = deriveEffectiveRules(
            baseRules,
            constraintOptions
        );

        let calcOptions = {};
        if (instance) {
            const visible = getVisibleCalendarDates(instance);
            if (visible && visible.length > 0) {
                calcOptions = {
                    onDemand: true,
                    visibleStartDate: visible[0],
                    visibleEndDate: visible[visible.length - 1],
                };
            }
        }

        const result = handleBookingDateChange(
            selectedDates,
            effectiveRules,
            store.bookings,
            store.checkouts,
            store.bookableItems,
            store.bookingItemId,
            store.bookingId,
            undefined,
            calcOptions
        );

        if (typeof setError === "function")
            setError(result.valid ? "" : result.errors.join(", "));
        if (tooltipVisibleRef) tooltipVisibleRef.value = false;

        // Highlighting
        if (instance) {
            if (selectedDates.length === 1) {
                const highlightingData = calculateConstraintHighlighting(
                    selectedDates[0],
                    effectiveRules,
                    constraintOptions
                );
                if (highlightingData) {
                    applyCalendarHighlighting(instance, highlightingData);
                }
            }
            if (selectedDates.length === 0) {
                instance._constraintHighlighting = null;
            }
        }
    }

    onMounted(() => {
        if (!elRef?.value) return;

        const baseConfig = {
            mode: "range",
            minDate: "today",
            disable: [() => false],
            clickOpens: true,
            dateFormat: win("flatpickr_dateformat_string") || "d.m.Y",
            allowInput: false,
            onChange: handleOnChange,
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
            onMonthChange: (...args) => {
                // re-apply highlighting if cached
                if (fp && fp._constraintHighlighting) {
                    applyCalendarHighlighting(fp, fp._constraintHighlighting);
                }
            },
            onYearChange: (...args) => {
                if (fp && fp._constraintHighlighting) {
                    applyCalendarHighlighting(fp, fp._constraintHighlighting);
                }
            },
        };

        fp = flatpickr(elRef.value, baseConfig);

        setDisableOnInstance();
        syncInstanceDatesFromStore();
    });

    // React to availability updates
    if (disableFnRef) {
        watch(disableFnRef, () => {
            setDisableOnInstance();
        });
    }

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
