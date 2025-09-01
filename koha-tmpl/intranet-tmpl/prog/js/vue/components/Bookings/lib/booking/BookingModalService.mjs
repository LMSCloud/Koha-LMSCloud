import dayjs from "../../../../utils/dayjs.mjs";
import { calculateDisabledDates, parseDateRange } from "./bookingManager.mjs";
import { deriveEffectiveRules } from "./bookingCalendar.mjs";
import {
    canProceedToStep3,
    canSubmitBooking,
    validateDateSelection,
} from "./bookingValidation.mjs";
import {
    calculateStepNumbers,
    shouldShowAdditionalFields,
} from "./bookingSteps.mjs";

export function calculateMaxBookingPeriod(circulationRules, dateRangeConstraint, customDateRangeFormula = null) {
    if (!dateRangeConstraint) return null;
    const rules = circulationRules?.[0];
    if (!rules) return null;
    const issuelength = parseInt(rules.issuelength) || 0;
    switch (dateRangeConstraint) {
        case "issuelength":
            return issuelength;
        case "issuelength_with_renewals":
            const renewalperiod = parseInt(rules.renewalperiod) || 0;
            const renewalsallowed = parseInt(rules.renewalsallowed) || 0;
            return issuelength + renewalperiod * renewalsallowed;
        case "custom":
            return typeof customDateRangeFormula === "function"
                ? customDateRangeFormula(rules)
                : null;
        default:
            return null;
    }
}

export function calculateAvailabilityData(dateRange, storeData, options = {}) {
    const {
        bookings,
        checkouts,
        bookableItems,
        circulationRules,
        bookingItemId,
        bookingId,
    } = storeData;

    if (!bookings || !checkouts || !bookableItems) {
        return { disable: () => false, unavailableByDate: {} };
    }

    const baseRules = circulationRules?.[0] || {};
    const maxBookingPeriod = calculateMaxBookingPeriod(
        circulationRules,
        options.dateRangeConstraint,
        options.customDateRangeFormula
    );
    const effectiveRules = deriveEffectiveRules(baseRules, {
        dateRangeConstraint: options.dateRangeConstraint,
        maxBookingPeriod,
    });

    // Convert dateRange to proper selectedDates array for calculateDisabledDates
    let selectedDatesArray = [];
    if (Array.isArray(dateRange)) {
        selectedDatesArray = dateRange.map(isoString => dayjs(isoString).toDate());
    } else if (typeof dateRange === "string") {
        const [startISO, endISO] = parseDateRange(dateRange);
        if (startISO && endISO) {
            selectedDatesArray = [dayjs(startISO).toDate(), dayjs(endISO).toDate()];
        } else if (startISO) {
            selectedDatesArray = [dayjs(startISO).toDate()];
        }
    }

    return calculateDisabledDates(
        bookings,
        checkouts,
        bookableItems,
        bookingItemId,
        bookingId,
        selectedDatesArray,
        effectiveRules
    );
}

export { canProceedToStep3, canSubmitBooking, validateDateSelection, calculateStepNumbers, shouldShowAdditionalFields };
