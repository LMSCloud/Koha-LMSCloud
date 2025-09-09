import dayjs from "../../../../utils/dayjs.mjs";
import { addDays, formatYMD } from "./date-utils.mjs";
import { managerLogger as logger } from "./logger.mjs";
import { calculateMaxEndDate } from "./manager.mjs";
import {
    CONSTRAINT_MODE_END_DATE_ONLY,
    CONSTRAINT_MODE_NORMAL,
} from "./constants.mjs";
import { toStringId } from "./id-utils.mjs";

// Internal helpers for end_date_only mode
function validateEndDateOnlyStartDateInternal(
    date,
    config,
    intervalTree,
    selectedItem,
    editBookingId,
    allItemIds
) {
    // Determine target end date based on backend due date override when available
    let targetEndDate;
    const due = config?.calculatedDueDate || null;
    if (due && !due.isBefore(date, "day")) {
        targetEndDate = due.clone();
    } else {
        const maxPeriod = Number(config?.maxPeriod) || 0;
        targetEndDate = maxPeriod > 0 ? calculateMaxEndDate(date, maxPeriod).toDate() : date;
    }

    logger.debug(
        `Checking ${CONSTRAINT_MODE_END_DATE_ONLY} range: ${formatYMD(
            date
        )} to ${formatYMD(targetEndDate)}`
    );

    if (selectedItem) {
        const conflicts = intervalTree.queryRange(
            date.valueOf(),
            targetEndDate.valueOf(),
            toStringId(selectedItem)
        );
        const relevantConflicts = conflicts.filter(
            interval =>
                !editBookingId || interval.metadata.booking_id != editBookingId
        );
        return relevantConflicts.length > 0;
    } else {
        // Any item mode: block if all items are unavailable on any date in the range
        for (
            let checkDate = date;
            checkDate.isSameOrBefore(targetEndDate, "day");
            checkDate = checkDate.add(1, "day")
        ) {
            const dayConflicts = intervalTree.query(checkDate.valueOf());
            const relevantDayConflicts = dayConflicts.filter(
                interval =>
                    !editBookingId ||
                    interval.metadata.booking_id != editBookingId
            );
            const unavailableItemIds = new Set(
                relevantDayConflicts.map(c => toStringId(c.itemId))
            );
            const allItemsUnavailableOnThisDay =
                allItemIds.length > 0 &&
                allItemIds.every(id => unavailableItemIds.has(toStringId(id)));
            if (allItemsUnavailableOnThisDay) {
                return true;
            }
        }
        return false;
    }
}

function handleEndDateOnlyIntermediateDatesInternal(
    date,
    selectedDates,
    maxPeriod
) {
    if (!selectedDates || selectedDates.length !== 1) {
        return null; // Not applicable
    }
    const startDate = dayjs(selectedDates[0]).startOf("day");
    const expectedEndDate = calculateMaxEndDate(startDate, maxPeriod);
    if (date.isSame(expectedEndDate, "day")) {
        return null; // Allow normal validation for expected end
    }
    if (date.isAfter(expectedEndDate, "day")) {
        return true; // Hard disable beyond expected end
    }
    // Intermediate date: leave to UI highlighting (no hard disable)
    return null;
}

const EndDateOnlyStrategy = {
    name: CONSTRAINT_MODE_END_DATE_ONLY,
    validateStartDateSelection(
        dayjsDate,
        config,
        intervalTree,
        selectedItem,
        editBookingId,
        allItemIds,
        selectedDates
    ) {
        if (!selectedDates || selectedDates.length === 0) {
            return validateEndDateOnlyStartDateInternal(
                dayjsDate,
                config,
                intervalTree,
                selectedItem,
                editBookingId,
                allItemIds
            );
        }
        return false;
    },
    handleIntermediateDate(dayjsDate, selectedDates, config) {
        // Prefer backend due date when provided and valid; otherwise fall back to maxPeriod
        if (config?.calculatedDueDate) {
            if (!selectedDates || selectedDates.length !== 1) return null;
            const startDate = dayjs(selectedDates[0]).startOf("day");
            const due = config.calculatedDueDate;
            if (!due.isBefore(startDate, "day")) {
                const expectedEndDate = due.clone();
                if (dayjsDate.isSame(expectedEndDate, "day")) return null;
                if (dayjsDate.isAfter(expectedEndDate, "day")) return true; // disable beyond expected end
                return null; // intermediate left to UI highlighting + click prevention
            }
            // Fall through to maxPeriod handling
        }
        return handleEndDateOnlyIntermediateDatesInternal(
            dayjsDate,
            selectedDates,
            Number(config?.maxPeriod) || 0
        );
    },
    /**
     * @param {Date|import('dayjs').Dayjs} startDate
     * @param {import('../../types/bookings').CirculationRule|Object} circulationRules
     * @param {import('../../types/bookings').ConstraintOptions} [constraintOptions={}]
     * @returns {import('../../types/bookings').ConstraintHighlighting|null}
     */
    calculateConstraintHighlighting(
        startDate,
        circulationRules,
        constraintOptions = {}
    ) {
        const start = dayjs(startDate).startOf("day");
        // Prefer backend-calculated due date when provided (respects closures)
        const dueStr = circulationRules?.calculated_due_date;
        let targetEnd;
        let periodForUi = Number(circulationRules?.calculated_period_days) || 0;
        if (dueStr) {
            const due = dayjs(dueStr).startOf("day");
            const start = dayjs(startDate).startOf("day");
            if (!due.isBefore(start, "day")) {
                targetEnd = due;
            }
        }
        if (!targetEnd) {
            let maxPeriod = constraintOptions.maxBookingPeriod;
            if (!maxPeriod) {
                maxPeriod =
                    Number(circulationRules?.maxPeriod) ||
                    Number(circulationRules?.issuelength) ||
                    30;
            }
            if (!maxPeriod) return null;
            targetEnd = calculateMaxEndDate(start, maxPeriod);
            periodForUi = maxPeriod;
        }
        const diffDays = Math.max(0, targetEnd.diff(start, "day"));
        const blockedIntermediateDates = [];
        for (let i = 1; i < diffDays; i++) {
            blockedIntermediateDates.push(addDays(start, i).toDate());
        }
        return {
            startDate: start.toDate(),
            targetEndDate: targetEnd.toDate(),
            blockedIntermediateDates,
            constraintMode: CONSTRAINT_MODE_END_DATE_ONLY,
            maxPeriod: periodForUi,
        };
    },
    enforceEndDateSelection(dayjsStart, dayjsEnd, circulationRules) {
        if (!dayjsEnd) return { ok: true };
        const dueStr = circulationRules?.calculated_due_date;
        let targetEnd;
        if (dueStr) {
            const due = dayjs(dueStr).startOf("day");
            if (!due.isBefore(dayjsStart, "day")) {
                targetEnd = due;
            }
        }
        if (!targetEnd) {
            const numericMaxPeriod =
                Number(circulationRules?.maxPeriod) ||
                Number(circulationRules?.issuelength) ||
                0;
            targetEnd = addDays(dayjsStart, Math.max(1, numericMaxPeriod) - 1);
        }
        return {
            ok: dayjsEnd.isSame(targetEnd, "day"),
            expectedEnd: targetEnd,
        };
    },
};

const NormalStrategy = {
    name: CONSTRAINT_MODE_NORMAL,
    validateStartDateSelection() {
        return false;
    },
    handleIntermediateDate() {
        return null;
    },
    /**
     * @param {Date|import('dayjs').Dayjs} startDate
     * @param {any} _rules
     * @param {import('../../types/bookings').ConstraintOptions} [constraintOptions={}]
     * @returns {import('../../types/bookings').ConstraintHighlighting|null}
     */
    calculateConstraintHighlighting(startDate, _rules, constraintOptions = {}) {
        const start = dayjs(startDate).startOf("day");
        const maxPeriod = constraintOptions.maxBookingPeriod;
        if (!maxPeriod) return null;
        const targetEndDate = calculateMaxEndDate(start, maxPeriod).toDate();
        return {
            startDate: start.toDate(),
            targetEndDate,
            blockedIntermediateDates: [],
            constraintMode: CONSTRAINT_MODE_NORMAL,
            maxPeriod,
        };
    },
    enforceEndDateSelection() {
        return { ok: true };
    },
};

export function createConstraintStrategy(mode) {
    return mode === CONSTRAINT_MODE_END_DATE_ONLY
        ? EndDateOnlyStrategy
        : NormalStrategy;
}
