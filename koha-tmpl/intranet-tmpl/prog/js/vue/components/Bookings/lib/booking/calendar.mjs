import {
    handleBookingDateChange,
    getBookingMarkersForDate,
    calculateConstraintHighlighting,
    getCalendarNavigationTarget,
    aggregateMarkersByType,
    deriveEffectiveRules,
} from "./manager.mjs";
import dayjs from "../../../../utils/dayjs.mjs";
import { calendarLogger as logger } from "./logger.mjs";
import { CONSTRAINT_MODE_END_DATE_ONLY } from "./constants.mjs";

const CLASS_BOOKING_CONSTRAINED_RANGE_MARKER =
    "booking-constrained-range-marker";
const CLASS_BOOKING_DAY_HOVER_LEAD = "booking-day--hover-lead";
const CLASS_BOOKING_DAY_HOVER_TRAIL = "booking-day--hover-trail";
const CLASS_BOOKING_INTERMEDIATE_BLOCKED = "booking-intermediate-blocked";
const CLASS_BOOKING_MARKER_COUNT = "booking-marker-count";
const CLASS_BOOKING_MARKER_DOT = "booking-marker-dot";
const CLASS_BOOKING_MARKER_GRID = "booking-marker-grid";
const CLASS_BOOKING_MARKER_ITEM = "booking-marker-item";
const CLASS_BOOKING_OVERRIDE_ALLOWED = "booking-override-allowed";
const CLASS_FLATPICKR_DAY = "flatpickr-day";
const CLASS_FLATPICKR_DISABLED = "flatpickr-disabled";
const CLASS_FLATPICKR_NOT_ALLOWED = "notAllowed";

const DATA_ATTRIBUTE_BOOKING_OVERRIDE = "data-booking-override";

/**
 * Clear constraint highlighting from flatpickr calendar
 */
export function clearCalendarHighlighting(instance) {
    logger.debug("Clearing calendar highlighting");

    if (!instance || !instance.calendarContainer) return;

    const existingHighlights = instance.calendarContainer.querySelectorAll(
        `.${CLASS_BOOKING_CONSTRAINED_RANGE_MARKER}`
    );
    existingHighlights.forEach(elem => {
        elem.classList.remove(
            CLASS_BOOKING_CONSTRAINED_RANGE_MARKER,
            CLASS_BOOKING_INTERMEDIATE_BLOCKED
        );
    });
}

// Keep internal function for backward compatibility
// Deprecated alias removed; use clearCalendarHighlighting directly

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
    clearCalendarHighlighting(instance);

    // Apply highlighting with retry logic for DOM readiness
    const applyHighlighting = (retryCount = 0) => {
        // Start group only when actually processing
        if (retryCount === 0) {
            logger.group("applyCalendarHighlighting");
        }
        const dayElements = instance.calendarContainer.querySelectorAll(
            `.${CLASS_FLATPICKR_DAY}`
        );

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
                if (
                    highlightingData.constraintMode ===
                    CONSTRAINT_MODE_END_DATE_ONLY
                ) {
                    // Check if this is an intermediate blocked date
                    const isBlocked =
                        highlightingData.blockedIntermediateDates.some(
                            blockedDate => dayTime === blockedDate.getTime()
                        );

                    if (isBlocked) {
                        // Intermediate dates - visual blocking
                        if (
                            !dayElem.classList.contains(
                                CLASS_FLATPICKR_DISABLED
                            )
                        ) {
                            dayElem.classList.add(
                                CLASS_BOOKING_CONSTRAINED_RANGE_MARKER,
                                CLASS_BOOKING_INTERMEDIATE_BLOCKED
                            );
                            blockedCount++;
                        }
                    } else {
                        // Start or end date - available
                        if (
                            !dayElem.classList.contains(
                                CLASS_FLATPICKR_DISABLED
                            )
                        ) {
                            dayElem.classList.add(
                                CLASS_BOOKING_CONSTRAINED_RANGE_MARKER
                            );
                            highlightedCount++;
                        }
                    }
                } else {
                    // Normal range mode - highlight entire range
                    if (!dayElem.classList.contains(CLASS_FLATPICKR_DISABLED)) {
                        dayElem.classList.add(
                            CLASS_BOOKING_CONSTRAINED_RANGE_MARKER
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
        if (highlightingData.constraintMode === CONSTRAINT_MODE_END_DATE_ONLY) {
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
                !targetEndElem.classList.contains(CLASS_FLATPICKR_DISABLED)
            ) {
                // Ensure the target end date has proper highlighting
                targetEndElem.classList.add(
                    CLASS_BOOKING_CONSTRAINED_RANGE_MARKER
                );
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
function fixTargetEndDateAvailability(_instance, dayElements, targetEndDate) {
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
    targetEndElem.classList.remove(CLASS_FLATPICKR_NOT_ALLOWED);
    targetEndElem.removeAttribute("tabindex");
    targetEndElem.classList.add(CLASS_BOOKING_OVERRIDE_ALLOWED);

    // Set a data attribute to prevent re-processing
    targetEndElem.setAttribute(DATA_ATTRIBUTE_BOOKING_OVERRIDE, "allowed");

    logger.debug("Applied CSS override for target end date availability", {
        targetDate: targetEndDate,
        element: targetEndElem,
    });

    // Force enable the target end date element immediately
    if (targetEndElem.classList.contains(CLASS_FLATPICKR_DISABLED)) {
        targetEndElem.classList.remove(
            CLASS_FLATPICKR_DISABLED,
            CLASS_FLATPICKR_NOT_ALLOWED
        );
        targetEndElem.removeAttribute("tabindex");
        targetEndElem.classList.add(CLASS_BOOKING_OVERRIDE_ALLOWED);

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
        `.${CLASS_BOOKING_INTERMEDIATE_BLOCKED}`
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
 * Event handler class for Flatpickr calendar events
 * Replaces closure-based factories with explicit state management
 */
//
// Shared rules derivation helper
//
// deriveEffectiveRules moved to bookingManager.mjs (rule/business logic layer)

/**
 * Factory to create functional onChange handler
 */
export function createOnChange(store, arg2, arg3, arg4) {
    // Backward compatible signature shim:
    // - Old: (store, errorMessageRef, tooltipVisibleRef, constraintOptions)
    // - New: (store, { setError, tooltipVisibleRef, constraintOptions })
    let setError = null;
    let tooltipVisibleRef = null;
    let constraintOptions = {};

    if (
        arg2 &&
        typeof arg2 === "object" &&
        (Object.prototype.hasOwnProperty.call(arg2, "setError") ||
            Object.prototype.hasOwnProperty.call(arg2, "tooltipVisibleRef") ||
            Object.prototype.hasOwnProperty.call(arg2, "constraintOptions"))
    ) {
        ({
            setError = null,
            tooltipVisibleRef = null,
            constraintOptions = {},
        } = arg2);
    } else {
        const errorMessageRef = arg2;
        tooltipVisibleRef = arg3 || null;
        constraintOptions = arg4 || {};
        setError = msg => {
            if (
                errorMessageRef &&
                typeof errorMessageRef === "object" &&
                "value" in errorMessageRef
            ) {
                errorMessageRef.value = msg;
            }
        };
    }

    // Allow tests to stub globals; fall back to imported functions
    const _getVisibleCalendarDates =
        globalThis.getVisibleCalendarDates || getVisibleCalendarDates;
    const _calculateConstraintHighlighting =
        globalThis.calculateConstraintHighlighting ||
        calculateConstraintHighlighting;
    const _handleBookingDateChange =
        globalThis.handleBookingDateChange || handleBookingDateChange;
    const _getCalendarNavigationTarget =
        globalThis.getCalendarNavigationTarget || getCalendarNavigationTarget;

    return function (selectedDates, dateStr, instance) {
        logger.debug("handleDateChange triggered", { selectedDates, dateStr });

        const validDates = (selectedDates || []).filter(
            d => d instanceof Date && !Number.isNaN(d.getTime())
        );
        // If no dates are selected (initial render or after clearing),
        // clear any existing error and sync the store, but skip validation.
        if ((selectedDates || []).length === 0) {
            if (Array.isArray(store.selectedDateRange) && store.selectedDateRange.length) {
                store.selectedDateRange = [];
            }
            if (typeof setError === "function") setError("");
            return;
        }
        if ((selectedDates || []).length > 0 && validDates.length === 0) {
            logger.warn(
                "All dates invalid, skipping processing to preserve state"
            );
            return;
        }

        const isoDateRange = validDates.map(d => dayjs(d).toISOString());
        const current = store.selectedDateRange || [];
        const same =
            current.length === isoDateRange.length &&
            current.every((v, i) => v === isoDateRange[i]);
        if (!same) store.selectedDateRange = isoDateRange;

        const baseRules =
            (store.circulationRules && store.circulationRules[0]) || {};
        const effectiveRules = deriveEffectiveRules(
            baseRules,
            constraintOptions
        );

        let calcOptions = {};
        if (instance) {
            const visible = _getVisibleCalendarDates(instance);
            if (visible && visible.length > 0) {
                calcOptions = {
                    onDemand: true,
                    visibleStartDate: visible[0],
                    visibleEndDate: visible[visible.length - 1],
                };
            }
        }

        const result = _handleBookingDateChange(
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

        if (typeof setError === "function") {
            // Support multiple result shapes from handler (backward compatibility for tests)
            const isValid =
                (result && Object.prototype.hasOwnProperty.call(result, "valid")
                    ? result.valid
                    : result?.isValid) ?? true;

            let message = "";
            if (!isValid) {
                if (Array.isArray(result?.errors)) {
                    message = result.errors.join(", ");
                } else if (typeof result?.errorMessage === "string") {
                    message = result.errorMessage;
                } else if (result?.errorMessage != null) {
                    message = String(result.errorMessage);
                } else if (result?.errors != null) {
                    message = String(result.errors);
                }
            }
            setError(message);
        }
        if (tooltipVisibleRef && "value" in tooltipVisibleRef) {
            tooltipVisibleRef.value = false;
        }

        if (instance) {
            if (selectedDates.length === 1) {
                const highlightingData = _calculateConstraintHighlighting(
                    selectedDates[0],
                    effectiveRules,
                    constraintOptions
                );
                if (highlightingData) {
                    applyCalendarHighlighting(instance, highlightingData);
                    // Compute current visible date range for smarter navigation
                    const visible = _getVisibleCalendarDates(instance);
                    const currentView =
                        visible && visible.length > 0
                            ? {
                                  visibleStartDate: visible[0],
                                  visibleEndDate: visible[visible.length - 1],
                              }
                            : {};
                    const nav = _getCalendarNavigationTarget(
                        highlightingData.startDate,
                        highlightingData.targetEndDate,
                        currentView
                    );
                    if (nav.shouldNavigate && nav.targetDate) {
                        setTimeout(() => {
                            if (instance.jumpToDate) {
                                instance.jumpToDate(nav.targetDate);
                            } else if (instance.changeMonth) {
                                // Fallback for older flatpickr builds: first ensure year, then adjust month absolutely
                                if (
                                    typeof instance.changeYear === "function" &&
                                    typeof nav.targetYear === "number" &&
                                    instance.currentYear !== nav.targetYear
                                ) {
                                    instance.changeYear(nav.targetYear);
                                }
                                const offset =
                                    typeof instance.currentMonth === "number"
                                        ? nav.targetMonth - instance.currentMonth
                                        : 0;
                                instance.changeMonth(offset, false);
                            }
                        }, 100);
                    }
                }
            }
            if (selectedDates.length === 0) {
                instance._constraintHighlighting = null;
                clearCalendarHighlighting(instance);
            }
        }
    };
}

export function createOnDayCreate(
    store,
    tooltipMarkers,
    tooltipVisible,
    tooltipX,
    tooltipY
) {
    return function (...[, , fp, dayElem]) {
        const existingGrids = dayElem.querySelectorAll(
            `.${CLASS_BOOKING_MARKER_GRID}`
        );
        existingGrids.forEach(grid => grid.remove());

        const dateStrForMarker = dayjs(dayElem.dateObj).format("YYYY-MM-DD");
        const markersForDots = getBookingMarkersForDate(
            store.unavailableByDate,
            dateStrForMarker,
            store.bookableItems
        );

        if (markersForDots.length > 0) {
            const aggregatedMarkers = aggregateMarkersByType(markersForDots);
            const grid = buildMarkerGrid(aggregatedMarkers);
            if (grid.hasChildNodes()) dayElem.appendChild(grid);
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
                CLASS_BOOKING_DAY_HOVER_LEAD,
                CLASS_BOOKING_DAY_HOVER_TRAIL
            ); // Clear first
            let hasLeadMarker = false;
            let hasTrailMarker = false;

            currentTooltipMarkersData.forEach(marker => {
                if (marker.type === "lead") hasLeadMarker = true;
                if (marker.type === "trail") hasTrailMarker = true;
            });

            if (hasLeadMarker) {
                dayElem.classList.add(CLASS_BOOKING_DAY_HOVER_LEAD);
            }
            if (hasTrailMarker) {
                dayElem.classList.add(CLASS_BOOKING_DAY_HOVER_TRAIL);
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
                CLASS_BOOKING_DAY_HOVER_LEAD,
                CLASS_BOOKING_DAY_HOVER_TRAIL
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
    return function () {
        // Clean up tooltips
        tooltipMarkers.value = [];
        tooltipVisible.value = false;
    };
}

/**
 * Helper to generate all visible dates for the current calendar view
 * UI-level helper; belongs with calendar DOM logic
 * @param {Object} flatpickrInstance - Flatpickr instance
 * @returns {Array<Date>} - Array of Date objects
 */
export function getVisibleCalendarDates(flatpickrInstance) {
    if (
        !flatpickrInstance ||
        !Array.isArray(flatpickrInstance.days) ||
        !flatpickrInstance.days.length
    )
        return [];
    return Array.from(flatpickrInstance.days)
        .filter(el => el && el.dateObj)
        .map(el => el.dateObj);
}

/**
 * Build the DOM grid for aggregated booking markers
 */
export function buildMarkerGrid(aggregatedMarkers) {
    const gridContainer = document.createElement("div");
    gridContainer.className = CLASS_BOOKING_MARKER_GRID;
    Object.entries(aggregatedMarkers).forEach(([type, count]) => {
        const markerSpan = document.createElement("span");
        markerSpan.className = CLASS_BOOKING_MARKER_ITEM;

        const dot = document.createElement("span");
        dot.className = `${CLASS_BOOKING_MARKER_DOT} ${CLASS_BOOKING_MARKER_DOT}--${type}`;
        dot.title = type.charAt(0).toUpperCase() + type.slice(1);
        markerSpan.appendChild(dot);

        if (count > 0) {
            const countSpan = document.createElement("span");
            countSpan.className = CLASS_BOOKING_MARKER_COUNT;
            countSpan.textContent = ` ${count}`;
            markerSpan.appendChild(countSpan);
        }
        gridContainer.appendChild(markerSpan);
    });
    return gridContainer;
}
