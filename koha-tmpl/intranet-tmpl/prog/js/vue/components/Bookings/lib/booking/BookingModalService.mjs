/**
 * Business logic service for BookingModal
 * Refactored to use pure functions and composables instead of store-coupled classes
 */

import dayjs from "../../../../utils/dayjs.mjs";
import { calculateDisabledDates, parseDateRange } from "./bookingManager.mjs";
import {
    createFlatpickrConfig,
    FlatpickrEventHandlers,
} from "./bookingCalendar.mjs";
import {
    canProceedToStep3,
    canSubmitBooking,
    validateDateSelection,
} from "./bookingValidation.mjs";
import {
    calculateStepNumbers,
    shouldShowAdditionalFields,
} from "./bookingSteps.mjs";

// Validation functions are now available as pure functions from bookingValidation.mjs
// Use canProceedToStep3(), canSubmitBooking(), and validateDateSelection() directly

/**
 * Service class for booking configuration and constraint handling
 */
export class BookingConfigurationService {
    constructor(dateRangeConstraint = null, customDateRangeFormula = null) {
        this.dateRangeConstraint = dateRangeConstraint;
        this.customDateRangeFormula = customDateRangeFormula;
    }

    /**
     * Calculate maximum booking period based on constraints
     */
    calculateMaxBookingPeriod(circulationRules) {
        if (!this.dateRangeConstraint) return null;

        const rules = circulationRules?.[0];
        if (!rules) return null;

        const issuelength = parseInt(rules.issuelength) || 0;

        switch (this.dateRangeConstraint) {
            case "issuelength":
                return issuelength;

            case "issuelength_with_renewals":
                const renewalperiod = parseInt(rules.renewalperiod) || 0;
                const renewalsallowed = parseInt(rules.renewalsallowed) || 0;
                return issuelength + renewalperiod * renewalsallowed;

            case "custom":
                if (this.customDateRangeFormula) {
                    return this.customDateRangeFormula(rules);
                }
                return null;

            default:
                return null;
        }
    }

    /**
     * Calculate availability data for calendar disable function
     */
    calculateAvailabilityData(dateRange, storeData) {
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

        // Apply date range constraint only for constraining modes; otherwise strip caps
        const effectiveRules = { ...baseRules };
        const maxBookingPeriod =
            this.calculateMaxBookingPeriod(circulationRules);
        if (
            this.dateRangeConstraint === "issuelength" ||
            this.dateRangeConstraint === "issuelength_with_renewals"
        ) {
            if (maxBookingPeriod) {
                effectiveRules.maxPeriod = maxBookingPeriod;
            }
        } else {
            if ("maxPeriod" in effectiveRules) delete effectiveRules.maxPeriod;
            if ("issuelength" in effectiveRules)
                delete effectiveRules.issuelength;
        }

        // Convert dateRange to proper selectedDates array for calculateDisabledDates
        let selectedDatesArray = [];
        if (Array.isArray(dateRange)) {
            // dateRange now contains ISO strings, convert to Date objects
            selectedDatesArray = dateRange.map(isoString =>
                dayjs(isoString).toDate()
            );
        } else if (typeof dateRange === "string") {
            // Fallback: if somehow we still get a string, try parsing it
            // This should be rare now that we use flatpickrSelectedDates
            // This is now an expected fallback case, no longer an error
            const [startISO, endISO] = parseDateRange(dateRange);
            if (startISO && endISO) {
                selectedDatesArray = [
                    dayjs(startISO).toDate(),
                    dayjs(endISO).toDate(),
                ];
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

    /**
     * Create Flatpickr configuration with event handlers
     */
    createFlatpickrConfiguration(
        dateRange,
        storeData,
        errorMessage,
        tooltipVisible,
        tooltipMarkers,
        tooltipX,
        tooltipY,
        flatpickrInstance,
        canProceedToStep3
    ) {
        const availabilityData = this.calculateAvailabilityData(
            dateRange,
            storeData
        );
        const maxBookingPeriod = this.calculateMaxBookingPeriod(
            storeData.circulationRules
        );

        const constraintOptions = {
            dateRangeConstraint: this.dateRangeConstraint,
            maxBookingPeriod: maxBookingPeriod,
        };

        // Create event handlers using the new class-based approach
        // TODO: This will be refactored in Phase 2 to use callback pattern
        const eventHandlers = new FlatpickrEventHandlers(
            storeData,
            errorMessage,
            tooltipVisible,
            constraintOptions
        );

        // Set additional references needed by handlers
        eventHandlers.setTooltipRefs(tooltipMarkers, tooltipX, tooltipY);
        eventHandlers.setFlatpickrRef(flatpickrInstance);

        const baseConfig = {
            mode: "range",
            minDate: "today",
            disable: [availabilityData.disable],
            clickOpens: canProceedToStep3,
            dateFormat: "Y-m-d",
            wrap: false,
            allowInput: false,
            altInput: false,
            altInputClass: "booking-flatpickr-input",
            onChange: eventHandlers.handleDateChange,
            onDayCreate: eventHandlers.handleDayCreate,
            onClose: eventHandlers.handleClose,
            onFlatpickrReady: eventHandlers.handleReady,
        };

        return createFlatpickrConfig(baseConfig);
    }
}

// Step management functions are now available as pure functions from bookingSteps.mjs
// Use calculateStepNumbers() and shouldShowAdditionalFields() directly

/**
 * Factory function to create booking services - updated for new architecture
 * Returns pure functions and service instances without store coupling
 */
export function createBookingServices(options = {}) {
    const configurationService = new BookingConfigurationService(
        options.dateRangeConstraint,
        options.customDateRangeFormula
    );

    return {
        // Pure validation functions (no longer store-coupled)
        validation: {
            canProceedToStep3,
            canSubmit: canSubmitBooking,
            validateDateSelection,
        },
        // Configuration service (refactored to accept data as parameters)
        configuration: configurationService,
        // Pure step calculation functions
        step: {
            calculateStepNumbers,
            shouldShowAdditionalFields,
        },
    };
}
