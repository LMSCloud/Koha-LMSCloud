import {
    handleBookingDateChange,
    getBookingMarkersForDate,
} from "./bookingManager.mjs";
import dayjs from "dayjs";

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
