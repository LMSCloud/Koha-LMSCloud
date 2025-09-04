import { onMounted, onUnmounted, watch } from "vue";
import flatpickr from "flatpickr";
import { isoArrayToDates } from "../lib/booking/date-utils.mjs";
import { useBookingStore } from "../../../stores/bookingStore.js";
import {
    applyCalendarHighlighting,
    createOnDayCreate,
    createOnClose,
    createOnChange,
} from "../lib/adapters/calendar.mjs";
import { useConstraintHighlighting } from "./useConstraintHighlighting.mjs";
import { win } from "../lib/adapters/globals.mjs";

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

        const baseConfig = {
            mode: "range",
            minDate: "today",
            disable: [() => false],
            clickOpens: true,
            dateFormat: win("flatpickr_dateformat_string") || "d.m.Y",
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
