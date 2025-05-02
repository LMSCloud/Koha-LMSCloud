// bookingManager.js
// Pure utility functions for date/booking calculations and business logic
// To be used by the Pinia store and BookingModal.vue

import dayjs from "dayjs";
import isSameOrBefore from "dayjs/plugin/isSameOrBefore.js";
import isSameOrAfter from "dayjs/plugin/isSameOrAfter.js";

dayjs.extend(isSameOrBefore);
dayjs.extend(isSameOrAfter);

/**
 * Pure function for Flatpickr's `disable` option.
 * Disables dates that overlap with existing bookings or checkouts for the selected item, or when not enough items are available.
 *
 * @param {Array} bookings - Array of booking objects ({ booking_id, item_id, start_date, end_date })
 * @param {Array} checkouts - Array of checkout objects ({ item_id, due_date, ... })
 * @param {Array} bookableItems - Array of all bookable item objects (must have item_id)
 * @param {number|string|null} selectedItem - The currently selected item (item_id or null for 'any')
 * @param {number|string|null} editBookingId - The booking_id being edited (if any)
 * @param {Array} selectedDates - Array of currently selected dates in Flatpickr (can be empty, or [start], or [start, end])
 * @param {Object} circulationRules - Circulation rules object (leadDays, trailDays, maxPeriod, etc.)
 * @param {Date|dayjs} todayArg - Optional today value for deterministic tests
 * @returns {Object} - { disable: Function, unavailableByDate: Object }
 */
export function calculateDisabledDates(
    bookings,
    checkouts,
    bookableItems,
    selectedItem,
    editBookingId,
    selectedDates = [],
    circulationRules = {},
    todayArg = undefined
) {
    const parse = d =>
        typeof d === "string" ? dayjs(d).startOf("day") : dayjs(d);

    // Build an object of unavailable item_ids and reasons per date
    // Structure: unavailableByDate[date][item_id] = Set of reasons
    const unavailableByDate = {};
    for (const booking of bookings) {
        if (editBookingId && booking.booking_id == editBookingId) continue;
        const start = parse(booking.start_date);
        const end = parse(booking.end_date);
        const leadDays =
            circulationRules.leadDays ||
            circulationRules.bookings_lead_period ||
            0;
        const trailDays =
            circulationRules.trailDays ||
            circulationRules.bookings_trail_period ||
            0;
        const effectiveStart = start.clone().subtract(leadDays, "day");
        const effectiveEnd = end.clone().add(trailDays, "day");
        for (
            let d = effectiveStart.clone();
            d.isSameOrBefore(effectiveEnd, "day");
            d = d.add(1, "day")
        ) {
            const key = d.format("YYYY-MM-DD");
            if (!unavailableByDate[key]) unavailableByDate[key] = {};
            if (!unavailableByDate[key][booking.item_id])
                unavailableByDate[key][booking.item_id] = new Set();
            // Determine reason
            if (d.isSameOrAfter(start, "day") && d.isSameOrBefore(end, "day")) {
                unavailableByDate[key][booking.item_id].add("core");
            } else if (d.isBefore(start, "day")) {
                unavailableByDate[key][booking.item_id].add("lead");
            } else if (d.isAfter(end, "day")) {
                unavailableByDate[key][booking.item_id].add("trail");
            }
        }
    }
    for (const checkout of checkouts) {
        const due = parse(checkout.due_date);
        const key = due.format("YYYY-MM-DD");
        if (!unavailableByDate[key]) unavailableByDate[key] = {};
        if (!unavailableByDate[key][checkout.item_id])
            unavailableByDate[key][checkout.item_id] = new Set();
        unavailableByDate[key][checkout.item_id].add("checkout");
    }

    const allItemIds = bookableItems.map(i => i.item_id);

    // Circulation rules
    const leadDays = Number(circulationRules.bookings_lead_period) || 0;
    const trailDays = Number(circulationRules.bookings_trail_period) || 0;
    const maxPeriod =
        Number(circulationRules.maxPeriod) ||
        Number(circulationRules.issuelength) ||
        0;
    // Use injected today if provided (for tests), else system today
    const today = todayArg
        ? dayjs(todayArg).startOf("day")
        : dayjs().startOf("day");

    // --- Functional pipeline for disabling dates ---
    function pipeDisableFns(fns) {
        const fn = function (date) {
            for (const f of fns) {
                if (f(date)) return true;
            }
            return false;
        };
        // Attach unavailableByDate for UI/marker access
        fn.unavailableByDate = unavailableByDate;
        return fn;
    }

    // Helper to check if all items are unavailable on a specific date
    const checkDateFullyUnavailable = dateToCheck => {
        const key = dateToCheck.format("YYYY-MM-DD");
        return (
            unavailableByDate[key] &&
            allItemIds.every(
                id =>
                    unavailableByDate[key][id] &&
                    unavailableByDate[key][id].size > 0
            )
        );
    };

    function isAllItemsUnavailable(unavailableByDate, allItemIds) {
        return d_raw => {
            const d = dayjs(d_raw).startOf("day"); // Ensure dayjs object
            return checkDateFullyUnavailable(d);
        };
    }

    function violatesCirculationRules(
        today,
        leadDays,
        maxPeriod,
        trailDays,
        selectedDates,
        checkDateFullyUnavailableFn // Renamed for clarity
    ) {
        return d_raw => {
            const d = dayjs(d_raw).startOf("day");

            if (d.isBefore(today, "day")) {
                return true;
            }

            if (!selectedDates || !selectedDates[0]) {
                // d is a potential start date
                if (leadDays > 0) {
                    for (let i = 1; i <= leadDays; i++) {
                        const leadDay = d.subtract(i, "day");
                        if (checkDateFullyUnavailableFn(leadDay)) {
                            return true;
                        }
                    }
                }
            } else if (
                selectedDates[0] &&
                (!selectedDates[1] || dayjs(selectedDates[1]).isSame(d, "day"))
            ) {
                // d is a potential end date
                const start = dayjs(selectedDates[0]).startOf("day");

                if (d.isBefore(start, "day")) {
                    return true;
                }

                if (
                    maxPeriod > 0 &&
                    d.isAfter(start.add(maxPeriod - 1, "day"), "day")
                ) {
                    return true;
                }

                if (trailDays > 0) {
                    for (let i = 1; i <= trailDays; i++) {
                        const trailDay = d.add(i, "day");
                        if (checkDateFullyUnavailableFn(trailDay)) {
                            return true;
                        }
                    }
                }
            }
            return false;
        };
    }

    // Compose pipeline
    const pipeline = pipeDisableFns([
        isAllItemsUnavailable(unavailableByDate, allItemIds), // Checks direct unavailability of date 'd'
        violatesCirculationRules(
            // Checks prospective lead/trail/maxPeriod for date 'd'
            today,
            leadDays,
            maxPeriod,
            trailDays,
            selectedDates,
            checkDateFullyUnavailable // Pass the helper itself
        ),
    ]);

    return {
        disable: date => pipeline(dayjs(date).startOf("day")), // Ensure dayjs object is passed to pipeline
        unavailableByDate: unavailableByDate,
    };
}

/**
 * Pure function to handle Flatpickr's onChange event logic for booking period selection.
 * Determines the valid end date range, applies circulation rules, and returns validation info.
 *
 * @param {Array} selectedDates - Array of currently selected dates ([start], or [start, end])
 * @param {Object} circulationRules - Circulation rules object (leadDays, trailDays, maxPeriod, etc.)
 * @param {Array} bookings - Array of bookings
 * @param {Array} checkouts - Array of checkouts
 * @param {Array} bookableItems - Array of all bookable items
 * @param {number|string|null} selectedItem - The currently selected item
 * @param {number|string|null} editBookingId - The booking_id being edited (if any)
 * @param {Date|dayjs} todayArg - Optional today value for deterministic tests
 * @returns {Object} - { valid: boolean, errors: Array<string>, newMaxEndDate: Date|null, newMinEndDate: Date|null }
 */
export function handleBookingDateChange(
    selectedDates,
    circulationRules,
    bookings,
    checkouts,
    bookableItems,
    selectedItem,
    editBookingId,
    todayArg = undefined
) {
    const dayjsStart = selectedDates[0]
        ? dayjs(selectedDates[0]).startOf("day")
        : null;
    const dayjsEnd = selectedDates[1]
        ? dayjs(selectedDates[1]).endOf("day")
        : null;
    const errors = [];
    let valid = true;
    let newMaxEndDate = null;
    let newMinEndDate = null; // Declare and initialize here

    // Validate: ensure start date is present
    if (!dayjsStart) {
        errors.push("Start date is required.");
        valid = false;
    } else {
        // Apply circulation rules: leadDays, trailDays, maxPeriod (in days)
        const leadDays = circulationRules?.leadDays || 0;
        const trailDays = circulationRules?.trailDays || 0; // Still needed for start date check
        const maxPeriod = circulationRules?.maxPeriod || 30;

        // Calculate min/max end date
        newMinEndDate = dayjsStart.add(1, "day"); // Assign here
        newMaxEndDate = dayjsStart.add(maxPeriod - 1, "day"); // Assign here

        // Validate: start must be after today + leadDays
        const today = todayArg
            ? dayjs(todayArg).startOf("day")
            : dayjs().startOf("day");
        if (dayjsStart.isBefore(today.add(leadDays, "day"))) {
            errors.push("Start date is too soon (lead time required)");
            valid = false;
        }

        // Validate: end must not be before start (only if end date exists)
        if (dayjsEnd && dayjsEnd.isBefore(dayjsStart)) {
            errors.push("End date is before start date");
            valid = false;
        }

        // Validate: period must not exceed maxPeriod (only if end date exists)
        if (dayjsEnd && dayjsEnd.diff(dayjsStart, "day") + 1 > maxPeriod) {
            errors.push("Booking period exceeds maximum allowed");
            valid = false;
        }

        // Validate: check for booking/checkouts overlap using calculateDisabledDates
        // This check is only meaningful if we have at least a start date,
        // and if an end date is also present, we check the whole range.
        // If only start date, effectively checks that single day.
        const endDateForLoop = dayjsEnd || dayjsStart; // If no end date, loop for the start date only

        const disableFnResults = calculateDisabledDates(
            bookings,
            checkouts,
            bookableItems,
            selectedItem,
            editBookingId,
            selectedDates, // Pass selectedDates
            circulationRules, // Pass circulationRules
            todayArg // Pass todayArg
        );
        for (
            let d = dayjsStart.clone();
            d.isSameOrBefore(endDateForLoop, "day");
            d = d.add(1, "day")
        ) {
            if (disableFnResults.disable(d.toDate())) {
                errors.push(`Date ${d.format("YYYY-MM-DD")} is unavailable.`);
                valid = false;
                break;
            }
        }
    }

    return {
        valid,
        errors,
        newMaxEndDate: newMaxEndDate ? newMaxEndDate.toDate() : null,
        newMinEndDate: newMinEndDate ? newMinEndDate.toDate() : null,
    };
}

/**
 * Aggregate all booking/checkouts for a given date (for calendar indicators)
 * @param {Array} bookings - Array of booking objects
 * @param {Array} checkouts - Array of checkout objects
 * @param {string|Date|dayjs} dateStr - date to check (YYYY-MM-DD or Date or dayjs)
 * @param {Array} bookableItems - Array of all bookable items
 * @param {Object} circulationRules - Circulation rules object (leadDays, trailDays)
 * @param {Array} selectedDates - Array of currently selected dates ([start], or [start, end])
 * @returns {Array<{ type: string, item: string, itemName: string, barcode: string|null }>} indicators for that date
 */
export function getBookingMarkersForDate(
    unavailableByDate,
    dateStr,
    bookableItems = []
) {
    // Guard against unavailableByDate itself being undefined or null
    if (!unavailableByDate) {
        return []; // No data, so no markers
    }

    const d =
        typeof dateStr === "string"
            ? dayjs(dateStr).startOf("day")
            : dayjs(dateStr).isValid()
              ? dayjs(dateStr).startOf("day")
              : dayjs().startOf("day");
    const key = d.format("YYYY-MM-DD");
    const markers = [];

    const findItem = item_id => {
        if (item_id == null) return undefined;
        return bookableItems.find(
            i => i.item_id != null && Number(i.item_id) === Number(item_id)
        );
    };

    const entry = unavailableByDate[key]; // This was line 496

    // Guard against the specific date key not being in the map
    if (!entry) {
        return []; // No data for this specific date, so no markers
    }

    // Now it's safe to use Object.entries(entry)
    for (const [item_id, reasons] of Object.entries(entry)) {
        const item = findItem(item_id);
        for (const reason of reasons) {
            let type = reason;
            if (type === "core") type = "booked";
            if (type === "checkout") type = "checked-out";
            markers.push({
                type,
                item: item_id,
                itemName: item?.title || item_id,
                barcode: item?.barcode || item?.external_id || null,
            });
        }
    }
    return markers;
}

/**
 * Helper to generate all visible dates for the current calendar view
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
 * Accepts array, string, or null and returns [start, end] ISO strings (or null)
 * @param {Array|string|null} val - Date range value
 * @returns {Array<string|null>} - [start, end] ISO strings (or null)
 */
export function parseDateRange(val) {
    if (Array.isArray(val)) {
        return [
            val[0] ? dayjs(val[0]).toISOString() : null,
            val[1] ? dayjs(val[1]).toISOString() : null,
        ];
    }
    if (typeof val === "string" && val.includes(" to ")) {
        const parts = val.split(" to ");
        return [
            parts[0] ? dayjs(parts[0].trim()).toISOString() : null,
            parts[1] ? dayjs(parts[1].trim()).toISOString() : null,
        ];
    }
    // Defensive: fallback
    return [null, null];
}

/**
 * Constrain pickup locations based on selected itemtype or item
 * Returns { filtered, filteredOutCount, total }
 */
export function constrainPickupLocations(
    pickupLocations,
    bookableItems,
    bookingItemtypeId,
    bookingItemId,
    constrainedFlagsRef
) {
    if (!bookingItemtypeId && !bookingItemId)
        return {
            filtered: pickupLocations,
            filteredOutCount: 0,
            total: pickupLocations.length,
        };
    const filtered = pickupLocations.filter(loc => {
        if (bookingItemId) {
            return (
                loc.pickup_items &&
                loc.pickup_items.map(Number).includes(Number(bookingItemId))
            );
        }
        if (bookingItemtypeId) {
            return (
                loc.pickup_items &&
                bookableItems.some(
                    item =>
                        item.item_type_id === bookingItemtypeId &&
                        loc.pickup_items
                            .map(Number)
                            .includes(Number(item.item_id))
                )
            );
        }
        return true;
    });
    if (constrainedFlagsRef)
        constrainedFlagsRef.value.pickupLocations =
            filtered.length !== pickupLocations.length;
    return {
        filtered,
        filteredOutCount: pickupLocations.length - filtered.length,
        total: pickupLocations.length,
    };
}

/**
 * Constrain bookable items based on selected pickup location and/or itemtype
 * Returns { filtered, filteredOutCount, total }
 */
export function constrainBookableItems(
    bookableItems,
    pickupLocations,
    pickupLibraryId,
    bookingItemtypeId,
    constrainedFlagsRef
) {
    if (!pickupLibraryId && !bookingItemtypeId)
        return {
            filtered: bookableItems,
            filteredOutCount: 0,
            total: bookableItems.length,
        };
    const filtered = bookableItems.filter(item => {
        if (pickupLibraryId && bookingItemtypeId) {
            const found = pickupLocations.find(
                loc =>
                    loc.library_id === pickupLibraryId &&
                    loc.pickup_items &&
                    loc.pickup_items.map(Number).includes(Number(item.item_id))
            );
            const match = item.item_type_id === bookingItemtypeId && found;
            return match;
        }
        if (pickupLibraryId) {
            const found = pickupLocations.find(
                loc =>
                    loc.library_id === pickupLibraryId &&
                    loc.pickup_items &&
                    loc.pickup_items.map(Number).includes(Number(item.item_id))
            );
            return found;
        }
        if (bookingItemtypeId) {
            return item.item_type_id === bookingItemtypeId;
        }
        return true;
    });
    if (constrainedFlagsRef)
        constrainedFlagsRef.value.bookableItems =
            filtered.length !== bookableItems.length;
    return {
        filtered,
        filteredOutCount: bookableItems.length - filtered.length,
        total: bookableItems.length,
    };
}

/**
 * Constrain item types based on selected pickup location or item
 */
export function constrainItemTypes(
    itemTypes,
    bookableItems,
    pickupLocations,
    pickupLibraryId,
    bookingItemId,
    constrainedFlagsRef
) {
    if (!pickupLibraryId && !bookingItemId) return itemTypes;
    const filtered = itemTypes.filter(type => {
        if (bookingItemId) {
            return bookableItems.some(
                item =>
                    Number(item.item_id) === Number(bookingItemId) &&
                    item.item_type_id === type.item_type_id
            );
        }
        if (pickupLibraryId) {
            return bookableItems.some(
                item =>
                    item.item_type_id === type.item_type_id &&
                    pickupLocations.find(
                        loc =>
                            loc.library_id === pickupLibraryId &&
                            loc.pickup_items &&
                            loc.pickup_items
                                .map(Number)
                                .includes(Number(item.item_id))
                    )
            );
        }
        return true;
    });
    if (constrainedFlagsRef)
        constrainedFlagsRef.value.itemTypes =
            filtered.length !== itemTypes.length;
    return filtered;
}
