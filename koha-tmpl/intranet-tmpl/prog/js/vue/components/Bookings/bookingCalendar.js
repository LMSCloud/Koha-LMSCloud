import {
    handleBookingDateChange,
    getBookingMarkersForDate,
} from "./bookingManager.mjs";
import dayjs from "dayjs";

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

export function createOnChange(store, errorMessage, tooltipVisible) {
    return function (selectedDates) {
        const result = handleBookingDateChange(
            selectedDates,
            store.circulationRules[0] || {},
            store.bookings,
            store.checkouts,
            store.bookableItems,
            store.bookingItemId,
            store.bookingId
        );
        if (!result.valid) {
            errorMessage.value = result.errors.join(", ");
        } else {
            errorMessage.value = "";
        }
        tooltipVisible.value = false; // Hide tooltip on date change
    };
}

export function createOnDayCreate(
    store,
    tooltipMarkers,
    tooltipVisible,
    tooltipX,
    tooltipY
) {
    return function (...[, , , dayElem]) {
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

            // Aggregate all markers by type, EXCLUDING lead and trail for dot display
            const aggregatedMarkers = markersForDots.reduce((acc, marker) => {
                if (marker.type !== "lead" && marker.type !== "trail") {
                    acc[marker.type] = (acc[marker.type] || 0) + 1;
                }
                return acc;
            }, {});

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
    };
}

export function createOnClose(tooltipMarkers, tooltipVisible) {
    return function () {
        tooltipMarkers.value = [];
        tooltipVisible.value = false;
    };
}

export function createOnFlatpickrReady(flatpickrInstance) {
    return function (...[, , instance]) {
        flatpickrInstance.value = instance;
    };
}

// function handleFlatpickrClose() {
//     tooltipVisible.value = false;
// }
