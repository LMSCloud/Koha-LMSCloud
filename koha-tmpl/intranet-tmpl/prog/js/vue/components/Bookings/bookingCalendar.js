import {
    handleBookingDateChange,
    getBookingMarkersForDate,
    calculateConstraintHighlighting,
    getCalendarNavigationTarget,
    aggregateMarkersByType,
} from "./bookingManager.mjs";
import dayjs from "../../utils/dayjs.mjs";
import { calendarLogger as logger } from "./bookingLogger.mjs";

/**
 * Clear constraint highlighting from flatpickr calendar
 */
export function clearCalendarHighlighting(instance) {
    logger.debug("Clearing calendar highlighting");

    if (!instance || !instance.calendarContainer) return;

    const existingHighlights = instance.calendarContainer.querySelectorAll(
        ".booking-constrained-range-marker"
    );
    existingHighlights.forEach(elem => {
        elem.classList.remove(
            "booking-constrained-range-marker",
            "booking-intermediate-blocked"
        );
    });
}

// Keep internal function for backward compatibility
function clearConstraintHighlighting(instance) {
    clearCalendarHighlighting(instance);
}

/**
 * Apply constraint highlighting to flatpickr calendar
 * This is a pure UI function that applies visual styling based on data from the manager
 */
export function applyCalendarHighlighting(instance, highlightingData) {
    if (!instance || !instance.calendarContainer || !highlightingData) {
        logger.debug("Missing requirements", {
            hasInstance: !!instance,
            hasContainer: !!instance?.calendarContainer,
            hasData: !!highlightingData,
        });
        return;
    }

    // Store data for reuse (e.g., after month navigation)
    instance._constraintHighlighting = highlightingData;

    // Clear any existing highlighting first
    clearConstraintHighlighting(instance);

    // Apply highlighting with retry logic for DOM readiness
    const applyHighlighting = (retryCount = 0) => {
        // Start group only when actually processing
        if (retryCount === 0) {
            logger.group("applyCalendarHighlighting");
        }
        const dayElements =
            instance.calendarContainer.querySelectorAll(".flatpickr-day");

        // Retry if DOM not ready
        if (dayElements.length === 0 && retryCount < 5) {
            logger.debug(`No day elements found, retry ${retryCount + 1}`);
            requestAnimationFrame(() => applyHighlighting(retryCount + 1));
            return;
        }

        let highlightedCount = 0;
        let blockedCount = 0;

        dayElements.forEach(dayElem => {
            if (!dayElem.dateObj) return;

            const dayTime = dayElem.dateObj.getTime();
            const startTime = highlightingData.startDate.getTime();
            const targetTime = highlightingData.targetEndDate.getTime();

            // Apply highlighting based on constraint mode
            if (dayTime >= startTime && dayTime <= targetTime) {
                if (highlightingData.constraintMode === "end_date_only") {
                    // Check if this is an intermediate blocked date
                    const isBlocked =
                        highlightingData.blockedIntermediateDates.some(
                            blockedDate => dayTime === blockedDate.getTime()
                        );

                    if (isBlocked) {
                        // Intermediate dates - visual blocking
                        if (!dayElem.classList.contains("flatpickr-disabled")) {
                            dayElem.classList.add(
                                "booking-constrained-range-marker",
                                "booking-intermediate-blocked"
                            );
                            blockedCount++;
                        }
                    } else {
                        // Start or end date - available
                        if (!dayElem.classList.contains("flatpickr-disabled")) {
                            dayElem.classList.add(
                                "booking-constrained-range-marker"
                            );
                            highlightedCount++;
                        }
                    }
                } else {
                    // Normal range mode - highlight entire range
                    if (!dayElem.classList.contains("flatpickr-disabled")) {
                        dayElem.classList.add(
                            "booking-constrained-range-marker"
                        );
                        highlightedCount++;
                    }
                }
            }
        });

        logger.debug("Highlighting applied", {
            highlightedCount,
            blockedCount,
            retryCount,
            constraintMode: highlightingData.constraintMode,
        });

        // Apply click prevention for blocked dates
        if (highlightingData.constraintMode === "end_date_only") {
            applyClickPrevention(instance);
            fixTargetEndDateAvailability(
                instance,
                dayElements,
                highlightingData.targetEndDate
            );

            // Re-apply highlighting for target end date after our modifications
            const targetEndElem = Array.from(dayElements).find(
                elem =>
                    elem.dateObj &&
                    elem.dateObj.getTime() ===
                        highlightingData.targetEndDate.getTime()
            );
            if (
                targetEndElem &&
                !targetEndElem.classList.contains("flatpickr-disabled")
            ) {
                // Ensure the target end date has proper highlighting
                targetEndElem.classList.add("booking-constrained-range-marker");
                logger.debug(
                    "Re-applied highlighting to target end date after availability fix"
                );
            }
        }

        // End group when done processing
        logger.groupEnd();
    };

    // Start the highlighting process
    requestAnimationFrame(() => applyHighlighting());
}

/**
 * Fix flatpickr's incorrect marking of target end date as unavailable
 * Uses CSS-based approach instead of fighting with DOM mutations
 */
function fixTargetEndDateAvailability(instance, dayElements, targetEndDate) {
    // Ensure dayElements is array-like before processing
    if (!dayElements || typeof dayElements.length !== "number") {
        logger.warn(
            "Invalid dayElements passed to fixTargetEndDateAvailability",
            dayElements
        );
        return;
    }

    const targetEndElem = Array.from(dayElements).find(
        elem =>
            elem.dateObj && elem.dateObj.getTime() === targetEndDate.getTime()
    );

    if (!targetEndElem) {
        logger.warn("Target end date element not found", targetEndDate);
        return;
    }

    // Use CSS approach instead of mutation observer hack
    // Mark the element as explicitly allowed, overriding Flatpickr's styles
    targetEndElem.classList.remove("notAllowed");
    targetEndElem.removeAttribute("tabindex");
    targetEndElem.classList.add("booking-override-allowed");

    // Set a data attribute to prevent re-processing
    targetEndElem.setAttribute("data-booking-override", "allowed");

    logger.debug("Applied CSS override for target end date availability", {
        targetDate: targetEndDate,
        element: targetEndElem,
    });

    // Force enable the target end date element immediately
    if (targetEndElem.classList.contains("flatpickr-disabled")) {
        targetEndElem.classList.remove("flatpickr-disabled", "notAllowed");
        targetEndElem.removeAttribute("tabindex");
        targetEndElem.classList.add("booking-override-allowed");

        logger.debug("Applied fix for target end date availability", {
            finalClasses: Array.from(targetEndElem.classList),
        });
    }
}

/**
 * Apply click prevention for intermediate dates in end_date_only mode
 */
function applyClickPrevention(instance) {
    if (!instance || !instance.calendarContainer) return;

    const blockedElements = instance.calendarContainer.querySelectorAll(
        ".booking-intermediate-blocked"
    );
    blockedElements.forEach(elem => {
        // Remove existing listeners to avoid duplicates
        elem.removeEventListener("click", preventClick, { capture: true });
        elem.addEventListener("click", preventClick, { capture: true });
    });
}

/**
 * Click prevention handler - extracted for better cleanup
 */
function preventClick(e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
}

/**
 * Get the current language code from the HTML lang attribute
 */
function getCurrentLanguageCode() {
    const htmlLang = document.documentElement.lang || "en";
    // Extract the language code (e.g., 'de-DE' -> 'de')
    return htmlLang.split("-")[0].toLowerCase();
}

/**
 * Pre-load flatpickr locale based on current language
 * This should ideally be called once when the page loads
 */
export async function preloadFlatpickrLocale() {
    const langCode = getCurrentLanguageCode();

    // English is the default, no need to load
    if (langCode === "en") {
        return;
    }

    try {
        // Try to load the locale dynamically
        // The locale is automatically registered with flatpickr.l10ns
        await import(`flatpickr/dist/l10n/${langCode}.js`);
    } catch (e) {
        console.warn(
            `Flatpickr locale for '${langCode}' not found, will use fallback translations`
        );
    }
}

/**
 * Create flatpickr locale configuration from Koha's global settings
 * This is a fallback when the proper locale file isn't available
 */
function createFlatpickrLocaleFallback() {
    if (typeof window === "undefined") return {};

    const locale = {};

    // Get translated weekdays and months (prefer global variables from calendar.js)
    const globalLocale = window.flatpickr?.l10ns?.default || {};
    locale.weekdays = window.flatpickr_weekdays || globalLocale.weekdays;
    locale.months = window.flatpickr_months || globalLocale.months;

    // Add first day of week preference
    if (window.calendarFirstDayOfWeek !== undefined) {
        locale.firstDayOfWeek = parseInt(window.calendarFirstDayOfWeek, 10);
    }

    // Add range separator translation
    if (typeof window.__ === "function") {
        const toTranslation = window.__("to");
        locale.rangeSeparator = " " + toTranslation + " ";
    }

    // Override with actual flatpickr locale if available
    if (window.flatpickr?.l10ns) {
        const currentLang =
            window.KohaLanguage ||
            document.documentElement.lang?.toLowerCase() ||
            "en";
        const flatpickrLocale = window.flatpickr.l10ns[currentLang];
        if (flatpickrLocale?.rangeSeparator) {
            locale.rangeSeparator = flatpickrLocale.rangeSeparator;
        }
    }

    return locale;
}

/**
 * Create a complete flatpickr configuration with Koha i18n settings
 * This is now synchronous and uses pre-loaded locale or fallback
 */
export function createFlatpickrConfig(baseConfig = {}) {
    const config = { ...baseConfig };
    const langCode = getCurrentLanguageCode();

    // Check if a locale has been pre-loaded for this language
    if (langCode !== "en" && window.flatpickr?.l10ns?.[langCode]) {
        config.locale = langCode;
    } else if (langCode !== "en") {
        // Use custom fallback locale
        const fallbackLocale = createFlatpickrLocaleFallback();
        if (Object.keys(fallbackLocale).length > 0) {
            config.locale = fallbackLocale;
        }
    }

    if (window.flatpickr_dateformat_string) {
        config.dateFormat = window.flatpickr_dateformat_string;
    }

    if (window.flatpickr_timeformat !== undefined) {
        config.time_24hr = window.flatpickr_timeformat;
    }

    return config;
}

/**
 * Event handler class for Flatpickr calendar events
 * Replaces closure-based factories with explicit state management
 */
export class FlatpickrEventHandlers {
    constructor(store, errorMessage, tooltipVisible, constraintOptions = {}) {
        this.store = store;
        this.errorMessage = errorMessage;
        this.tooltipVisible = tooltipVisible;
        this.constraintOptions = constraintOptions;

        // Bind methods to maintain correct 'this' context
        this.handleDateChange = this.handleDateChange.bind(this);
    }

    /**
     * Handle date selection changes with validation and highlighting
     */
    handleDateChange(selectedDates, dateStr, instance) {
        logger.debug("handleDateChange triggered", { selectedDates, dateStr });

        // Filter out Invalid Date objects and log them
        const validDates = selectedDates.filter(
            date => date instanceof Date && !isNaN(date)
        );
        const invalidDates = selectedDates.filter(
            date => !(date instanceof Date) || isNaN(date)
        );

        if (invalidDates.length > 0) {
            logger.warn("Invalid Date objects detected", {
                invalidDates,
                totalDates: selectedDates.length,
                validDates: validDates.length
            });

            // If we only have invalid dates, skip processing to avoid breaking state
            if (validDates.length === 0 && selectedDates.length > 0) {
                logger.warn("All dates invalid, skipping processing to preserve state");
                return;
            }
        }

        // Extract ISO dates from valid Date objects only
        const isoDateRange = validDates.map(date => dayjs(date).toISOString());

        logger.debug("Date processing complete", { validDates: validDates.length, isoDateRange });

        // Store the ISO dates in the store (our primary source of truth)
        this.store.selectedDateRange = isoDateRange;

        logger.debug("onChange triggered", {
            selectedDates,
            isoDateRange,
            constraintOptions: this.constraintOptions,
        });

        const baseRules = this.store.circulationRules[0] || {};
        const effectiveRules = this._calculateEffectiveRules(baseRules);

        // Validate date selection using manager
        const result = handleBookingDateChange(
            selectedDates,
            effectiveRules,
            this.store.bookings,
            this.store.checkouts,
            this.store.bookableItems,
            this.store.bookingItemId,
            this.store.bookingId
        );

        this._updateValidationUI(result);
        this._handleConstraintHighlighting(
            selectedDates,
            effectiveRules,
            instance
        );
    }

    /**
     * Calculate effective rules with constraint overrides
     */
    _calculateEffectiveRules(baseRules) {
        const effectiveRules = { ...baseRules };
        if (
            this.constraintOptions.dateRangeConstraint &&
            this.constraintOptions.maxBookingPeriod
        ) {
            effectiveRules.maxPeriod = this.constraintOptions.maxBookingPeriod;
        }
        return effectiveRules;
    }

    /**
     * Update UI based on validation results
     */
    _updateValidationUI(result) {
        if (!result.valid) {
            this.errorMessage.value = result.errors.join(", ");
        } else {
            this.errorMessage.value = "";
        }
        this.tooltipVisible.value = false; // Hide tooltip on date change
    }

    /**
     * Handle constraint highlighting for date selections
     */
    _handleConstraintHighlighting(selectedDates, effectiveRules, instance) {
        if (selectedDates.length === 1 && instance) {
            const highlightingData = calculateConstraintHighlighting(
                selectedDates[0],
                effectiveRules,
                this.constraintOptions
            );

            if (highlightingData) {
                applyCalendarHighlighting(instance, highlightingData);
                this._handleCalendarNavigation(highlightingData, instance);
            }
        }

        // Clear highlighting when selection is cleared
        if (selectedDates.length === 0 && instance) {
            instance._constraintHighlighting = null;
            clearConstraintHighlighting(instance);
        }
    }

    /**
     * Handle calendar navigation to show target dates
     */
    _handleCalendarNavigation(highlightingData, instance) {
        const navigationInfo = getCalendarNavigationTarget(
            highlightingData.startDate,
            highlightingData.targetEndDate
        );

        if (navigationInfo.shouldNavigate && navigationInfo.targetDate) {
            logger.debug("Navigating calendar", navigationInfo);

            setTimeout(() => {
                // Validate the target date before trying to jump
                if (
                    instance &&
                    navigationInfo.targetDate &&
                    !isNaN(navigationInfo.targetDate.getTime())
                ) {
                    if (instance.jumpToDate) {
                        instance.jumpToDate(navigationInfo.targetDate);
                    } else if (instance.changeMonth) {
                        instance.changeMonth(
                            navigationInfo.targetMonth,
                            navigationInfo.targetYear
                        );
                    }
                } else {
                    logger.warn(
                        "Invalid navigation target date",
                        navigationInfo
                    );
                }
            }, 100);
        }
    }
}

/**
 * Factory function to create event handlers - maintains backward compatibility
 * @deprecated Use FlatpickrEventHandlers class directly
 */
export function createOnChange(
    store,
    errorMessage,
    tooltipVisible,
    constraintOptions = {}
) {
    const handlers = new FlatpickrEventHandlers(
        store,
        errorMessage,
        tooltipVisible,
        constraintOptions
    );
    return handlers.handleDateChange;
}

export function createOnDayCreate(
    store,
    tooltipMarkers,
    tooltipVisible,
    tooltipX,
    tooltipY
) {
    return function (...[, , fp, dayElem]) {
        const existingGrids = dayElem.querySelectorAll(".booking-marker-grid");
        existingGrids.forEach(grid => grid.remove());

        const dateStrForMarker = dayjs(dayElem.dateObj).format("YYYY-MM-DD");
        const markersForDots = getBookingMarkersForDate(
            store.unavailableByDate,
            dateStrForMarker,
            store.bookableItems
        );

        if (markersForDots.length > 0) {
            const gridContainer = document.createElement("div");
            gridContainer.className = "booking-marker-grid";

            // Use manager function to aggregate markers
            const aggregatedMarkers = aggregateMarkersByType(markersForDots);

            Object.entries(aggregatedMarkers).forEach(([type, count]) => {
                const markerSpan = document.createElement("span");
                markerSpan.className = "booking-marker-item";

                const dot = document.createElement("span");
                dot.className = `booking-marker-dot booking-marker-dot--${type}`;
                dot.title = type.charAt(0).toUpperCase() + type.slice(1);
                markerSpan.appendChild(dot);

                if (count > 0) {
                    // Show count
                    const countSpan = document.createElement("span");
                    countSpan.className = "booking-marker-count";
                    countSpan.textContent = ` ${count}`;
                    markerSpan.appendChild(countSpan);
                }
                gridContainer.appendChild(markerSpan);
            });

            if (gridContainer.hasChildNodes()) {
                dayElem.appendChild(gridContainer);
            }
        }

        // Existing tooltip mouseover logic - DO NOT CHANGE unless necessary for aggregation
        dayElem.addEventListener("mouseover", () => {
            const hoveredDateStr = dayjs(dayElem.dateObj).format("YYYY-MM-DD");
            const currentTooltipMarkersData = getBookingMarkersForDate(
                store.unavailableByDate,
                hoveredDateStr,
                store.bookableItems
            );

            // Apply lead/trail hover classes
            dayElem.classList.remove(
                "booking-day--hover-lead",
                "booking-day--hover-trail"
            ); // Clear first
            let hasLeadMarker = false;
            let hasTrailMarker = false;

            currentTooltipMarkersData.forEach(marker => {
                if (marker.type === "lead") hasLeadMarker = true;
                if (marker.type === "trail") hasTrailMarker = true;
            });

            if (hasLeadMarker) {
                dayElem.classList.add("booking-day--hover-lead");
            }
            if (hasTrailMarker) {
                dayElem.classList.add("booking-day--hover-trail");
            }

            // Tooltip visibility logic (existing)
            if (currentTooltipMarkersData.length > 0) {
                tooltipMarkers.value = currentTooltipMarkersData;
                tooltipVisible.value = true;

                const rect = dayElem.getBoundingClientRect();
                tooltipX.value = rect.left + window.scrollX + rect.width / 2;
                tooltipY.value = rect.top + window.scrollY - 10; // Adjust Y to be above the cell
            } else {
                tooltipMarkers.value = [];
                tooltipVisible.value = false;
            }
        });

        // Add mouseout listener to clear hover classes and hide tooltip
        dayElem.addEventListener("mouseout", () => {
            dayElem.classList.remove(
                "booking-day--hover-lead",
                "booking-day--hover-trail"
            );
            tooltipVisible.value = false; // Hide tooltip when mouse leaves the day cell
        });

        // Reapply constraint highlighting if it exists (for month navigation, etc.)
        if (fp && fp._constraintHighlighting && fp.calendarContainer) {
            requestAnimationFrame(() => {
                applyCalendarHighlighting(fp, fp._constraintHighlighting);
            });
        }
    };
}

export function createOnClose(tooltipMarkers, tooltipVisible) {
    return function (selectedDates, dateStr, instance) {
        // Clean up tooltips
        tooltipMarkers.value = [];
        tooltipVisible.value = false;
    };
}

export function createOnFlatpickrReady(flatpickrInstance) {
    return function (...[, , instance]) {
        flatpickrInstance.value = instance;

        // Apply constraint highlighting if it was set up before the instance was ready
        if (instance && instance._constraintHighlighting) {
            // Use a longer delay to ensure the calendar DOM is fully rendered
            setTimeout(() => {
                applyCalendarHighlighting(
                    instance,
                    instance._constraintHighlighting
                );
            }, 100);
        }
    };
}

// function handleFlatpickrClose() {
//     tooltipVisible.value = false;
// }
