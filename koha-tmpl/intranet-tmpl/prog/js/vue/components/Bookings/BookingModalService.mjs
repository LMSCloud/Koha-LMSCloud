/**
 * Business logic service for BookingModal
 * Extracts validation, configuration, and state management from the Vue component
 */

import dayjs from "../../utils/dayjs.mjs";
import {
    calculateDisabledDates,
    handleBookingDateChange,
    parseDateRange,
} from "./bookingManager.mjs";
import {
    createFlatpickrConfig,
    FlatpickrEventHandlers,
} from "./bookingCalendar.js";

/**
 * Service class for booking form validation and business logic
 */
export class BookingValidationService {
    constructor(store) {
        this.store = store;
    }

    /**
     * Validate if user can proceed to step 3 (period selection)
     */
    canProceedToStep3() {
        // Step 1: Patron validation (if required)
        if (this.store.showPatronSelect && !this.store.bookingPatron) {
            return false;
        }

        // Step 2: Item details validation
        if (
            this.store.showItemDetailsSelects ||
            this.store.showPickupLocationSelect
        ) {
            if (
                this.store.showPickupLocationSelect &&
                !this.store.pickupLibraryId
            ) {
                return false;
            }
            if (this.store.showItemDetailsSelects) {
                if (
                    !this.store.bookingItemtypeId &&
                    this.store.itemtypeOptions.length > 0
                ) {
                    return false;
                }
                if (
                    !this.store.bookingItemId &&
                    this.store.bookableItems.length > 0
                ) {
                    return false;
                }
            }
        }

        // Additional validation: Check if there are any bookable items available
        if (
            !this.store.bookableItems ||
            this.store.bookableItems.length === 0
        ) {
            return false;
        }

        return true;
    }

    /**
     * Validate if form can be submitted
     */
    canSubmit(dateRange) {
        if (!this.canProceedToStep3()) return false;
        if (!dateRange || dateRange.length === 0) return false;

        // For range mode, need both start and end dates
        if (Array.isArray(dateRange) && dateRange.length < 2) {
            return false;
        }

        return true;
    }

    /**
     * Validate date selection and return detailed result
     */
    validateDateSelection(selectedDates, circulationRules) {
        return handleBookingDateChange(
            selectedDates,
            circulationRules,
            this.store.bookings,
            this.store.checkouts,
            this.store.bookableItems,
            this.store.bookingItemId,
            this.store.bookingId
        );
    }
}

/**
 * Service class for booking configuration and constraint handling
 */
export class BookingConfigurationService {
    constructor(
        store,
        dateRangeConstraint = null,
        customDateRangeFormula = null
    ) {
        this.store = store;
        this.dateRangeConstraint = dateRangeConstraint;
        this.customDateRangeFormula = customDateRangeFormula;
    }

    /**
     * Calculate maximum booking period based on constraints
     */
    calculateMaxBookingPeriod() {
        if (!this.dateRangeConstraint) return null;

        const rules = this.store.circulationRules[0];
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
    calculateAvailabilityData(dateRange) {
        if (
            !this.store.bookings ||
            !this.store.checkouts ||
            !this.store.bookableItems
        ) {
            return { disable: () => false, unavailableByDate: {} };
        }

        const baseRules = this.store.circulationRules[0] || {};

        // Apply date range constraint only for constraining modes; otherwise strip caps
        const effectiveRules = { ...baseRules };
        const maxBookingPeriod = this.calculateMaxBookingPeriod();
        if (
            this.dateRangeConstraint === "issuelength" ||
            this.dateRangeConstraint === "issuelength_with_renewals"
        ) {
            if (maxBookingPeriod) {
                effectiveRules.maxPeriod = maxBookingPeriod;
            }
        } else {
            if ("maxPeriod" in effectiveRules) delete effectiveRules.maxPeriod;
            if ("issuelength" in effectiveRules) delete effectiveRules.issuelength;
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
            this.store.bookings,
            this.store.checkouts,
            this.store.bookableItems,
            this.store.bookingItemId,
            this.store.bookingId,
            selectedDatesArray,
            effectiveRules
        );
    }

    /**
     * Create Flatpickr configuration with event handlers
     */
    createFlatpickrConfiguration(
        dateRange,
        errorMessage,
        tooltipVisible,
        tooltipMarkers,
        tooltipX,
        tooltipY,
        flatpickrInstance,
        canProceedToStep3
    ) {
        const availabilityData = this.calculateAvailabilityData(dateRange);
        const maxBookingPeriod = this.calculateMaxBookingPeriod();

        const constraintOptions = {
            dateRangeConstraint: this.dateRangeConstraint,
            maxBookingPeriod: maxBookingPeriod,
        };

        // Create event handlers using the new class-based approach
        const eventHandlers = new FlatpickrEventHandlers(
            this.store,
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

/**
 * Service class for step management and flow control
 */
export class BookingStepService {
    /**
     * Calculate step numbers based on configuration
     */
    static calculateStepNumbers(
        showPatronSelect,
        showItemDetailsSelects,
        showPickupLocationSelect,
        showAdditionalFields,
        hasAdditionalFields
    ) {
        let currentStep = 1;
        const steps = {
            patron: 0,
            details: 0,
            period: 0,
            additionalFields: 0,
        };

        if (showPatronSelect) {
            steps.patron = currentStep++;
        }

        if (showItemDetailsSelects || showPickupLocationSelect) {
            steps.details = currentStep++;
        }

        steps.period = currentStep++;

        if (showAdditionalFields && hasAdditionalFields) {
            steps.additionalFields = currentStep++;
        }

        return steps;
    }

    /**
     * Determine if additional fields section should be shown
     */
    static shouldShowAdditionalFields(
        showAdditionalFields,
        hasAdditionalFields
    ) {
        return showAdditionalFields && hasAdditionalFields;
    }
}

/**
 * Factory function to create booking services
 */
export function createBookingServices(store, options = {}) {
    const validationService = new BookingValidationService(store);
    const configurationService = new BookingConfigurationService(
        store,
        options.dateRangeConstraint,
        options.customDateRangeFormula
    );

    return {
        validation: validationService,
        configuration: configurationService,
        step: BookingStepService,
    };
}
