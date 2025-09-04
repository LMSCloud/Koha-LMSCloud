import {
    handleBookingDateChange,
    getBookingMarkersForDate,
    calculateConstraintHighlighting,
    getCalendarNavigationTarget,
    aggregateMarkersByType,
    deriveEffectiveRules,
} from "../booking/manager.mjs";
import { toISO, formatYMD, toDayjs, addDays } from "../booking/date-utils.mjs";
import { calendarLogger as logger } from "../booking/logger.mjs";
import { CONSTRAINT_MODE_END_DATE_ONLY } from "../booking/constants.mjs";

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
const CLASS_BOOKING_LOAN_BOUNDARY = "booking-loan-boundary";

const DATA_ATTRIBUTE_BOOKING_OVERRIDE = "data-booking-override";

/**
 * Clear constraint highlighting from the Flatpickr calendar.
 *
 * @param {import('flatpickr/dist/types/instance').Instance} instance
 * @returns {void}
 */
export function clearCalendarHighlighting(instance) {
    logger.debug("Clearing calendar highlighting");

    if (!instance || !instance.calendarContainer) return;

    // Query separately to accommodate simple test DOM mocks
    const lists = [
        instance.calendarContainer.querySelectorAll(
            `.${CLASS_BOOKING_CONSTRAINED_RANGE_MARKER}`
        ),
        instance.calendarContainer.querySelectorAll(
            `.${CLASS_BOOKING_INTERMEDIATE_BLOCKED}`
        ),
        instance.calendarContainer.querySelectorAll(
            `.${CLASS_BOOKING_LOAN_BOUNDARY}`
        ),
    ];
    const existingHighlights = lists.flatMap(list => Array.from(list || []));
    existingHighlights.forEach(elem => {
        elem.classList.remove(
            CLASS_BOOKING_CONSTRAINED_RANGE_MARKER,
            CLASS_BOOKING_INTERMEDIATE_BLOCKED,
            CLASS_BOOKING_LOAN_BOUNDARY
        );
    });
}

/**
 * Apply constraint highlighting to the Flatpickr calendar.
 *
 * @param {import('flatpickr/dist/types/instance').Instance} instance
 * @param {import('../../types/bookings').ConstraintHighlighting} highlightingData
 * @returns {void}
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

    // Cache highlighting data for re-application after navigation
    const instWithCache =
        /** @type {import('flatpickr/dist/types/instance').Instance & { _constraintHighlighting?: import('../../types/bookings').ConstraintHighlighting | null }} */ (
            instance
        );
    instWithCache._constraintHighlighting = highlightingData;

    clearCalendarHighlighting(instance);

    const applyHighlighting = (retryCount = 0) => {
        if (retryCount === 0) {
            logger.group("applyCalendarHighlighting");
        }
        const dayElements = instance.calendarContainer.querySelectorAll(
            `.${CLASS_FLATPICKR_DAY}`
        );

        if (dayElements.length === 0 && retryCount < 5) {
            logger.debug(`No day elements found, retry ${retryCount + 1}`);
            requestAnimationFrame(() => applyHighlighting(retryCount + 1));
            return;
        }

        let highlightedCount = 0;
        let blockedCount = 0;

        // Preload loan boundary times cached on instance (if present)
        const instWithCacheForBoundary =
            /** @type {import('flatpickr/dist/types/instance').Instance & { _loanBoundaryTimes?: Set<number> }} */ (
                instance
            );
        const boundaryTimes = instWithCacheForBoundary?._loanBoundaryTimes;

        dayElements.forEach(dayElem => {
            if (!dayElem.dateObj) return;

            const dayTime = dayElem.dateObj.getTime();
            const startTime = highlightingData.startDate.getTime();
            const targetTime = highlightingData.targetEndDate.getTime();

            // Apply bold styling to loan period boundary dates
            if (boundaryTimes && boundaryTimes.has(dayTime)) {
                dayElem.classList.add(CLASS_BOOKING_LOAN_BOUNDARY);
            }

            if (dayTime >= startTime && dayTime <= targetTime) {
                if (
                    highlightingData.constraintMode ===
                    CONSTRAINT_MODE_END_DATE_ONLY
                ) {
                    const isBlocked =
                        highlightingData.blockedIntermediateDates.some(
                            blockedDate => dayTime === blockedDate.getTime()
                        );

                    if (isBlocked) {
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

        if (highlightingData.constraintMode === CONSTRAINT_MODE_END_DATE_ONLY) {
            applyClickPrevention(instance);
            fixTargetEndDateAvailability(
                instance,
                dayElements,
                highlightingData.targetEndDate
            );

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
                targetEndElem.classList.add(
                    CLASS_BOOKING_CONSTRAINED_RANGE_MARKER
                );
                logger.debug(
                    "Re-applied highlighting to target end date after availability fix"
                );
            }
        }

        logger.groupEnd();
    };

    requestAnimationFrame(() => applyHighlighting());
}

/**
 * Fix incorrect target-end unavailability via a CSS-based override.
 *
 * @param {import('flatpickr/dist/types/instance').Instance} _instance
 * @param {NodeListOf<Element>|Element[]} dayElements
 * @param {Date} targetEndDate
 * @returns {void}
 */
function fixTargetEndDateAvailability(_instance, dayElements, targetEndDate) {
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

    // Mark the element as explicitly allowed, overriding Flatpickr's styles
    targetEndElem.classList.remove(CLASS_FLATPICKR_NOT_ALLOWED);
    targetEndElem.removeAttribute("tabindex");
    targetEndElem.classList.add(CLASS_BOOKING_OVERRIDE_ALLOWED);

    targetEndElem.setAttribute(DATA_ATTRIBUTE_BOOKING_OVERRIDE, "allowed");

    logger.debug("Applied CSS override for target end date availability", {
        targetDate: targetEndDate,
        element: targetEndElem,
    });

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
 * Apply click prevention for intermediate dates in end_date_only mode.
 *
 * @param {import('flatpickr/dist/types/instance').Instance} instance
 * @returns {void}
 */
function applyClickPrevention(instance) {
    if (!instance || !instance.calendarContainer) return;

    const blockedElements = instance.calendarContainer.querySelectorAll(
        `.${CLASS_BOOKING_INTERMEDIATE_BLOCKED}`
    );
    blockedElements.forEach(elem => {
        elem.removeEventListener("click", preventClick, { capture: true });
        elem.addEventListener("click", preventClick, { capture: true });
    });
}

/** Click prevention handler. */
function preventClick(e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
}

/**
 * Get the current language code from the HTML lang attribute
 *
 * @returns {string}
 */
function getCurrentLanguageCode() {
    const htmlLang = document.documentElement.lang || "en";
    return htmlLang.split("-")[0].toLowerCase();
}

/**
 * Pre-load flatpickr locale based on current language
 * This should ideally be called once when the page loads
 *
 * @returns {Promise<void>}
 */
export async function preloadFlatpickrLocale() {
    const langCode = getCurrentLanguageCode();

    if (langCode === "en") {
        return;
    }

    try {
        await import(`flatpickr/dist/l10n/${langCode}.js`);
    } catch (e) {
        console.warn(
            `Flatpickr locale for '${langCode}' not found, will use fallback translations`
        );
    }
}

/**
 * Create a Flatpickr `onChange` handler bound to the booking store.
 *
 * @param {object} store - Booking Pinia store (or compatible shape)
 * @param {import('../../types/bookings').OnChangeOptions} options
 */
export function createOnChange(
    store,
    { setError = null, tooltipVisibleRef = null, constraintOptions = {} } = {}
) {
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

    return function (selectedDates, _dateStr, instance) {
        logger.debug("handleDateChange triggered", { selectedDates });

        const validDates = (selectedDates || []).filter(
            d => d instanceof Date && !Number.isNaN(d.getTime())
        );
        // clear any existing error and sync the store, but skip validation.
        if ((selectedDates || []).length === 0) {
            // Clear cached loan boundaries when clearing selection
            if (instance) {
                const instWithCache =
                    /** @type {import('flatpickr/dist/types/instance').Instance & { _loanBoundaryTimes?: Set<number> }} */ (
                        instance
                    );
                delete instWithCache._loanBoundaryTimes;
            }
            if (
                Array.isArray(store.selectedDateRange) &&
                store.selectedDateRange.length
            ) {
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

        const isoDateRange = validDates.map(d => toISO(d));
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

        // Compute loan boundary times (end of initial loan and renewals) and cache on instance
        try {
            if (instance && validDates.length > 0) {
                const instWithCache =
                    /** @type {import('flatpickr/dist/types/instance').Instance & { _loanBoundaryTimes?: Set<number> }} */ (
                        instance
                    );
                const startDate = toDayjs(validDates[0]).startOf("day");
                const issuelength = parseInt(baseRules?.issuelength) || 0;
                const renewalperiod = parseInt(baseRules?.renewalperiod) || 0;
                const renewalsallowed =
                    parseInt(baseRules?.renewalsallowed) || 0;
                const times = new Set();
                if (issuelength > 0) {
                    // End aligns with due date semantics: start + issuelength days
                    const initialEnd = startDate
                        .add(issuelength, "day")
                        .toDate()
                        .getTime();
                    times.add(initialEnd);
                    if (renewalperiod > 0 && renewalsallowed > 0) {
                        for (let k = 1; k <= renewalsallowed; k++) {
                            const t = startDate
                                .add(issuelength + k * renewalperiod, "day")
                                .toDate()
                                .getTime();
                            times.add(t);
                        }
                    }
                }
                instWithCache._loanBoundaryTimes = times;
            }
        } catch (e) {
            // non-fatal: boundary decoration best-effort
        }

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
                                        ? nav.targetMonth -
                                          instance.currentMonth
                                        : 0;
                                instance.changeMonth(offset, false);
                            }
                        }, 100);
                    }
                }
            }
            if (selectedDates.length === 0) {
                const instWithCache =
                    /** @type {import('../../types/bookings').FlatpickrInstanceWithHighlighting} */ (
                        instance
                    );
                instWithCache._constraintHighlighting = null;
                clearCalendarHighlighting(instance);
            }
        }
    };
}

/**
 * Create Flatpickr `onDayCreate` handler.
 *
 * Renders per-day marker dots, hover classes, and shows a tooltip with
 * aggregated markers. Reapplies constraint highlighting across month
 * navigation using the instance's cached highlighting data.
 *
 * @param {object} store - booking store or compatible state
 * @param {import('../../types/bookings').RefLike<import('../../types/bookings').CalendarMarker[]>} tooltipMarkers - ref of markers shown in tooltip
 * @param {import('../../types/bookings').RefLike<boolean>} tooltipVisible - visibility ref for tooltip
 * @param {import('../../types/bookings').RefLike<number>} tooltipX - x position ref
 * @param {import('../../types/bookings').RefLike<number>} tooltipY - y position ref
 * @returns {import('flatpickr/dist/types/options').Hook}
 */
export function createOnDayCreate(
    store,
    tooltipMarkers,
    tooltipVisible,
    tooltipX,
    tooltipY
) {
    return function (
        ...[
            ,
            ,
            /** @type {import('flatpickr/dist/types/instance').Instance} */ fp,
            /** @type {import('flatpickr/dist/types/instance').DayElement} */ dayElem,
        ]
    ) {
        const existingGrids = dayElem.querySelectorAll(
            `.${CLASS_BOOKING_MARKER_GRID}`
        );
        existingGrids.forEach(grid => grid.remove());

        const el =
            /** @type {import('flatpickr/dist/types/instance').DayElement} */ (
                dayElem
            );
        const dateStrForMarker = formatYMD(el.dateObj);
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
            const hoveredDateStr = formatYMD(el.dateObj);
            const currentTooltipMarkersData = getBookingMarkersForDate(
                store.unavailableByDate,
                hoveredDateStr,
                store.bookableItems
            );

            el.classList.remove(
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
                el.classList.add(CLASS_BOOKING_DAY_HOVER_LEAD);
            }
            if (hasTrailMarker) {
                el.classList.add(CLASS_BOOKING_DAY_HOVER_TRAIL);
            }

            if (currentTooltipMarkersData.length > 0) {
                tooltipMarkers.value = currentTooltipMarkersData;
                tooltipVisible.value = true;

                const rect = el.getBoundingClientRect();
                tooltipX.value = rect.left + window.scrollX + rect.width / 2;
                tooltipY.value = rect.top + window.scrollY - 10; // Adjust Y to be above the cell
            } else {
                tooltipMarkers.value = [];
                tooltipVisible.value = false;
            }
        });

        dayElem.addEventListener("mouseout", () => {
            dayElem.classList.remove(
                CLASS_BOOKING_DAY_HOVER_LEAD,
                CLASS_BOOKING_DAY_HOVER_TRAIL
            );
            tooltipVisible.value = false; // Hide tooltip when mouse leaves the day cell
        });

        // Reapply constraint highlighting if it exists (for month navigation, etc.)
        const fpWithCache =
            /** @type {import('flatpickr/dist/types/instance').Instance & { _constraintHighlighting?: import('../../types/bookings').ConstraintHighlighting | null }} */ (
                fp
            );
        if (
            fpWithCache &&
            fpWithCache._constraintHighlighting &&
            fpWithCache.calendarContainer
        ) {
            requestAnimationFrame(() => {
                applyCalendarHighlighting(
                    fpWithCache,
                    fpWithCache._constraintHighlighting
                );
            });
        }
    };
}

/**
 * Create Flatpickr `onClose` handler to clear tooltip state.
 * @param {import('../../types/bookings').RefLike<import('../../types/bookings').CalendarMarker[]>} tooltipMarkers
 * @param {import('../../types/bookings').RefLike<boolean>} tooltipVisible
 */
export function createOnClose(tooltipMarkers, tooltipVisible) {
    return function () {
        tooltipMarkers.value = [];
        tooltipVisible.value = false;
    };
}

/**
 * Generate all visible dates for the current calendar view.
 * UI-level helper; belongs with calendar DOM logic.
 *
 * @param {Object} flatpickrInstance - Flatpickr instance
 * @returns {Date[]} Array of Date objects
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
 * Build the DOM grid for aggregated booking markers.
 *
 * @param {import('../../types/bookings').MarkerAggregation} aggregatedMarkers - counts by marker type
 * @returns {HTMLDivElement} container element with marker items
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
