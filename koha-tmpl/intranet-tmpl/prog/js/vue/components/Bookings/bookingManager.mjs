// bookingManager.js
// Pure utility functions for date/booking calculations and business logic
// To be used by the Pinia store and BookingModal.vue

import dayjs from "../../utils/dayjs.mjs";
import { managerLogger as logger } from "./bookingLogger.mjs";

// Use global $__ function (available in browser, mocked in tests)
const $__ = globalThis.$__ || (str => str);
import {
    IntervalTree,
    BookingInterval,
    buildIntervalTree,
} from "./IntervalTree.mjs";
import {
    SweepLineProcessor,
    processCalendarView,
} from "./SweepLineProcessor.mjs";

/**
 * Build unavailableByDate map from IntervalTree for backward compatibility
 * @param {IntervalTree} intervalTree - The interval tree containing all bookings/checkouts
 * @param {dayjs} today - Today's date for range calculation
 * @param {Array} allItemIds - Array of all item IDs
 * @param {number|string|null} editBookingId - The booking_id being edited (exclude from results)
 * @returns {Object} - Map of date strings to item unavailability data
 */
function buildUnavailableByDateMap(
    intervalTree,
    today,
    allItemIds,
    editBookingId
) {
    const unavailableByDate = {};

    if (!intervalTree || intervalTree.size === 0) {
        return unavailableByDate;
    }

    // Calculate a reasonable date range for unavailability data
    // Start from today minus some buffer, go to today plus some buffer
    const startDate = today.subtract(90, "day"); // 3 months ago
    const endDate = today.add(365, "day"); // 1 year ahead

    // Iterate through each day in the range
    for (
        let current = startDate;
        current.isSameOrBefore(endDate, "day");
        current = current.add(1, "day")
    ) {
        const dateKey = current.format("YYYY-MM-DD");
        const timestamp = current.valueOf();

        // Query intervals that overlap with this day
        const overlappingIntervals = intervalTree.query(timestamp);

        // Filter out the booking being edited
        const relevantIntervals = overlappingIntervals.filter(
            interval =>
                !editBookingId ||
                !interval.metadata ||
                interval.metadata.booking_id != editBookingId
        );

        if (relevantIntervals.length > 0) {
            unavailableByDate[dateKey] = {};

            // Group by item and collect reasons
            for (const interval of relevantIntervals) {
                const itemId = String(interval.itemId);

                if (!unavailableByDate[dateKey][itemId]) {
                    unavailableByDate[dateKey][itemId] = new Set();
                }

                // Add the reason for unavailability
                unavailableByDate[dateKey][itemId].add(interval.type);
            }
        }
    }

    return unavailableByDate;
}

// Map flatpickr format strings to dayjs format strings and regex patterns
const DATE_FORMAT_MAP = {
    "Y-m-d": {
        pattern: /\d{4}-\d{2}-\d{2}/g,
        dayjsFormat: "YYYY-MM-DD",
    },
    "m/d/Y": {
        pattern: /\d{1,2}\/\d{1,2}\/\d{4}/g,
        dayjsFormat: "MM/DD/YYYY",
    },
    "d/m/Y": {
        pattern: /\d{1,2}\/\d{1,2}\/\d{4}/g,
        dayjsFormat: "DD/MM/YYYY",
    },
    "d.m.Y": {
        pattern: /\d{1,2}\.\d{1,2}\.\d{4}/g,
        dayjsFormat: "DD.MM.YYYY",
    },
};

/**
 * Pure function for Flatpickr's `disable` option.
 * Disables dates that overlap with existing bookings or checkouts for the selected item, or when not enough items are available.
 * Also handles end_date_only constraint mode by disabling intermediate dates.
 *
 * @param {Array} bookings - Array of booking objects ({ booking_id, item_id, start_date, end_date })
 * @param {Array} checkouts - Array of checkout objects ({ item_id, due_date, ... })
 * @param {Array} bookableItems - Array of all bookable item objects (must have item_id)
 * @param {number|string|null} selectedItem - The currently selected item (item_id or null for 'any')
 * @param {number|string|null} editBookingId - The booking_id being edited (if any)
 * @param {Array} selectedDates - Array of currently selected dates in Flatpickr (can be empty, or [start], or [start, end])
 * @param {Object} circulationRules - Circulation rules object (leadDays, trailDays, maxPeriod, booking_constraint_mode, etc.)
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
    logger.time("calculateDisabledDates");
    logger.debug("calculateDisabledDates called", {
        bookingsCount: bookings.length,
        checkoutsCount: checkouts.length,
        itemsCount: bookableItems.length,
        selectedItem,
        editBookingId,
        selectedDates,
        circulationRules,
    });

    // DEBUG: Log detailed selection parameters for OPAC debugging
    logger.debug("OPAC Selection Debug:", {
        selectedItem: selectedItem,
        selectedItemType:
            selectedItem === null ? "ANY_AVAILABLE" : "SPECIFIC_ITEM",
        bookableItems: bookableItems.map(item => ({
            item_id: item.item_id,
            title: item.title,
            item_type_id: item.item_type_id,
            holding_library: item.holding_library,
            available_pickup_locations: item.available_pickup_locations,
        })),
        circulationRules: {
            booking_constraint_mode: circulationRules?.booking_constraint_mode,
            maxPeriod: circulationRules?.maxPeriod,
            bookings_lead_period: circulationRules?.bookings_lead_period,
            bookings_trail_period: circulationRules?.bookings_trail_period,
        },
        bookings: bookings.map(b => ({
            booking_id: b.booking_id,
            item_id: b.item_id,
            start_date: b.start_date,
            end_date: b.end_date,
            patron_id: b.patron_id,
        })),
        checkouts: checkouts.map(c => ({
            item_id: c.item_id,
            checkout_date: c.checkout_date,
            due_date: c.due_date,
            patron_id: c.patron_id,
        })),
    });

    // Build IntervalTree with all booking/checkout data
    const intervalTree = buildIntervalTree(
        bookings,
        checkouts,
        circulationRules
    );

    const today = todayArg
        ? dayjs(todayArg).startOf("day")
        : dayjs().startOf("day");
    const leadDays = Number(circulationRules?.bookings_lead_period) || 0;
    const trailDays = Number(circulationRules?.bookings_trail_period) || 0;
    const maxPeriod =
        Number(circulationRules?.maxPeriod) ||
        Number(circulationRules?.issuelength) ||
        30;
    const isEndDateOnly =
        circulationRules?.booking_constraint_mode === "end_date_only";
    const allItemIds = bookableItems.map(i => i.item_id);

    // Create optimized disable function using IntervalTree
    const disableFunction = date => {
        const dayjs_date = dayjs(date).startOf("day");

        // Basic validations
        if (dayjs_date.isBefore(today, "day")) return true;

        // CRITICAL FIX: end_date_only complete range validation
        logger.debug(`Checking end_date_only conditions:`, {
            isEndDateOnly: isEndDateOnly,
            selectedDates: selectedDates,
            selectedDatesLength: selectedDates?.length || 0,
            selectedItem: selectedItem,
            shouldEnterEndDateOnlyLogic:
                isEndDateOnly && (!selectedDates || selectedDates.length === 0),
        });

        if (isEndDateOnly && (!selectedDates || selectedDates.length === 0)) {
            // This is a potential start date - validate ENTIRE range
            const targetEndDate = dayjs_date.add(maxPeriod - 1, "day");

            logger.debug(
                `Checking end_date_only range: ${dayjs_date.format(
                    "YYYY-MM-DD"
                )} to ${targetEndDate.format("YYYY-MM-DD")}`
            );

            if (selectedItem) {
                // Specific item selected - check if that item has conflicts in the range
                const conflicts = intervalTree.queryRange(
                    dayjs_date.valueOf(),
                    targetEndDate.valueOf(),
                    String(selectedItem)
                );

                const relevantConflicts = conflicts.filter(
                    interval =>
                        !editBookingId ||
                        interval.metadata.booking_id != editBookingId
                );

                if (relevantConflicts.length > 0) {
                    logger.debug(
                        `Start date blocked - range conflicts for specific item ${selectedItem}`
                    );
                    return true;
                }
            } else {
                // "Any item" mode - check if ALL items are unavailable for ANY date in the range
                // Use efficient day-by-day check to find if all items are ever blocked simultaneously
                let allItemsBlockedOnSomeDate = false;

                // Check each day in the range to see if all items are unavailable
                for (
                    let checkDate = dayjs_date;
                    checkDate.isSameOrBefore(targetEndDate, "day");
                    checkDate = checkDate.add(1, "day")
                ) {
                    const dayConflicts = intervalTree.query(
                        checkDate.valueOf()
                    );
                    const relevantDayConflicts = dayConflicts.filter(
                        interval =>
                            !editBookingId ||
                            interval.metadata.booking_id != editBookingId
                    );

                    // Check if all items are unavailable on this specific day
                    const unavailableItemIds = new Set(
                        relevantDayConflicts.map(c => String(c.itemId))
                    );
                    const allItemsUnavailableOnThisDay =
                        allItemIds.length > 0 &&
                        allItemIds.every(id =>
                            unavailableItemIds.has(String(id))
                        );

                    if (allItemsUnavailableOnThisDay) {
                        allItemsBlockedOnSomeDate = true;
                        logger.debug(
                            `Start date blocked - all items unavailable on ${checkDate.format(
                                "YYYY-MM-DD"
                            )} within end_date_only range`
                        );
                        break;
                    }
                }

                logger.debug(`End_date_only range validation (Any item):`, {
                    mode: "end_date_only",
                    startDate: dayjs_date.format("YYYY-MM-DD"),
                    endDate: targetEndDate.format("YYYY-MM-DD"),
                    selectedItem: "ANY_AVAILABLE",
                    totalItems: allItemIds.length,
                    allItemsBlockedOnSomeDate: allItemsBlockedOnSomeDate,
                    decision: allItemsBlockedOnSomeDate ? "BLOCK" : "CONTINUE",
                });

                if (allItemsBlockedOnSomeDate) {
                    return true;
                }
            }
        }

        // Standard point-in-time availability check
        const pointConflicts = intervalTree.query(
            dayjs_date.valueOf(),
            selectedItem ? String(selectedItem) : null
        );
        const relevantPointConflicts = pointConflicts.filter(
            interval =>
                !editBookingId || interval.metadata.booking_id != editBookingId
        );

        // Check if this affects the selected item or all items
        if (selectedItem) {
            // Specific item selected - check only that item
            if (relevantPointConflicts.length > 0) {
                logger.debug(
                    `Date ${dayjs_date.format(
                        "YYYY-MM-DD"
                    )} blocked for item ${selectedItem}:`,
                    relevantPointConflicts.map(c => c.type)
                );
                return true;
            }
        } else {
            // No specific item - check if ALL items are unavailable
            const unavailableItemIds = new Set(
                relevantPointConflicts.map(c => c.itemId)
            );
            const allUnavailable =
                allItemIds.length > 0 &&
                allItemIds.every(id => unavailableItemIds.has(String(id)));

            // DEBUG: Log multi-item availability details
            logger.debug(
                `Multi-item availability check for ${dayjs_date.format(
                    "YYYY-MM-DD"
                )}:`,
                {
                    totalItems: allItemIds.length,
                    allItemIds: allItemIds,
                    conflictsFound: relevantPointConflicts.length,
                    unavailableItemIds: Array.from(unavailableItemIds),
                    allUnavailable: allUnavailable,
                    decision: allUnavailable ? "BLOCK" : "ALLOW",
                }
            );

            if (allUnavailable) {
                logger.debug(
                    `Date ${dayjs_date.format(
                        "YYYY-MM-DD"
                    )} blocked - all items unavailable`
                );
                return true;
            }
        }

        // Lead/trail period validation using tree queries
        if (!selectedDates || selectedDates.length === 0) {
            // Potential start date - check lead period
            if (leadDays > 0) {
                logger.debug(
                    `Checking lead period for ${dayjs_date.format(
                        "YYYY-MM-DD"
                    )} (${leadDays} days)`
                );
            }

            for (let i = 1; i <= leadDays; i++) {
                const leadDay = dayjs_date.subtract(i, "day");
                const leadConflicts = intervalTree.query(
                    leadDay.valueOf(),
                    selectedItem ? String(selectedItem) : null
                );
                const relevantLeadConflicts = leadConflicts.filter(
                    c =>
                        !editBookingId || c.metadata.booking_id != editBookingId
                );

                logger.debug(
                    `Lead period check day ${i}: ${leadDay.format(
                        "YYYY-MM-DD"
                    )}`,
                    {
                        selectedItem: selectedItem,
                        conflicts: relevantLeadConflicts.length,
                        conflictDetails: relevantLeadConflicts.map(c => ({
                            type: c.type,
                            item: c.itemId,
                        })),
                    }
                );

                if (selectedItem) {
                    if (relevantLeadConflicts.length > 0) {
                        logger.debug(
                            `Start date ${dayjs_date.format(
                                "YYYY-MM-DD"
                            )} blocked - lead period conflict on ${leadDay.format(
                                "YYYY-MM-DD"
                            )}`
                        );
                        return true;
                    }
                } else {
                    // Check if all items unavailable in lead period
                    const leadUnavailableIds = new Set(
                        relevantLeadConflicts.map(c => c.itemId)
                    );
                    const allUnavailableInLead =
                        allItemIds.length > 0 &&
                        allItemIds.every(id =>
                            leadUnavailableIds.has(String(id))
                        );

                    logger.debug(`Lead period multi-item check:`, {
                        leadDay: leadDay.format("YYYY-MM-DD"),
                        totalItems: allItemIds.length,
                        unavailableItems: Array.from(leadUnavailableIds),
                        allUnavailable: allUnavailableInLead,
                    });

                    if (allUnavailableInLead) {
                        logger.debug(
                            `Start date ${dayjs_date.format(
                                "YYYY-MM-DD"
                            )} blocked - all items in lead period unavailable on ${leadDay.format(
                                "YYYY-MM-DD"
                            )}`
                        );
                        return true;
                    }
                }
            }
        } else if (
            selectedDates[0] &&
            (!selectedDates[1] ||
                dayjs(selectedDates[1]).isSame(dayjs_date, "day"))
        ) {
            // Potential end date - check trail period
            const start = dayjs(selectedDates[0]).startOf("day");

            // Basic end date validations
            if (dayjs_date.isBefore(start, "day")) return true;
            if (
                maxPeriod > 0 &&
                dayjs_date.isAfter(start.add(maxPeriod - 1, "day"), "day")
            )
                return true;

            for (let i = 1; i <= trailDays; i++) {
                const trailDay = dayjs_date.add(i, "day");
                const trailConflicts = intervalTree.query(
                    trailDay.valueOf(),
                    selectedItem ? String(selectedItem) : null
                );
                const relevantTrailConflicts = trailConflicts.filter(
                    c =>
                        !editBookingId || c.metadata.booking_id != editBookingId
                );

                if (selectedItem) {
                    if (relevantTrailConflicts.length > 0) {
                        logger.debug(
                            `End date ${dayjs_date.format(
                                "YYYY-MM-DD"
                            )} blocked - trail period conflict`
                        );
                        return true;
                    }
                } else {
                    // Check if all items unavailable in trail period
                    const trailUnavailableIds = new Set(
                        relevantTrailConflicts.map(c => c.itemId)
                    );
                    if (
                        allItemIds.length > 0 &&
                        allItemIds.every(id =>
                            trailUnavailableIds.has(String(id))
                        )
                    ) {
                        logger.debug(
                            `End date ${dayjs_date.format(
                                "YYYY-MM-DD"
                            )} blocked - all items in trail period unavailable`
                        );
                        return true;
                    }
                }
            }
        }

        return false;
    };

    // Build unavailableByDate for backward compatibility and markers
    // Use SweepLineProcessor to build comprehensive unavailability data
    const unavailableByDate = buildUnavailableByDateMap(
        intervalTree,
        today,
        allItemIds,
        editBookingId
    );

    logger.debug("IntervalTree-based availability calculated", {
        treeSize: intervalTree.size,
        treeHeight: intervalTree._getHeight(intervalTree.root),
    });
    logger.timeEnd("calculateDisabledDates");

    return {
        disable: disableFunction,
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
    logger.time("handleBookingDateChange");
    logger.debug("handleBookingDateChange called", {
        selectedDates,
        circulationRules,
        selectedItem,
        editBookingId,
    });
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
        errors.push(String($__("Start date is required.")));
        valid = false;
    } else {
        // Apply circulation rules: leadDays, trailDays, maxPeriod (in days)
        const leadDays = circulationRules?.leadDays || 0;
        const trailDays = circulationRules?.trailDays || 0; // Still needed for start date check
        const maxPeriod =
            Number(circulationRules?.maxPeriod) ||
            Number(circulationRules?.issuelength) ||
            30;

        // Calculate min/max end date
        newMinEndDate = dayjsStart.add(1, "day").startOf("day"); // Assign here
        newMaxEndDate = dayjsStart.add(maxPeriod - 1, "day").startOf("day"); // Assign here

        // Validate: start must be after today + leadDays
        const today = todayArg
            ? dayjs(todayArg).startOf("day")
            : dayjs().startOf("day");
        if (dayjsStart.isBefore(today.add(leadDays, "day"))) {
            errors.push(
                String($__("Start date is too soon (lead time required)"))
            );
            valid = false;
        }

        // Validate: end must not be before start (only if end date exists)
        if (dayjsEnd && dayjsEnd.isBefore(dayjsStart)) {
            errors.push(String($__("End date is before start date")));
            valid = false;
        }

        // Validate: period must not exceed maxPeriod (only if end date exists)
        if (dayjsEnd && dayjsEnd.diff(dayjsStart, "day") + 1 > maxPeriod) {
            errors.push(String($__("Booking period exceeds maximum allowed")));
            valid = false;
        }

        // Validate: end_date_only constraint (only if end date exists)
        if (
            dayjsEnd &&
            circulationRules?.booking_constraint_mode === "end_date_only"
        ) {
            const numericMaxPeriod =
                Number(circulationRules.maxPeriod) ||
                Number(circulationRules.issuelength) ||
                30;
            const targetEndDate = dayjsStart.add(numericMaxPeriod - 1, "day");

            // In end_date_only mode, end date must exactly match the calculated target end date
            if (!dayjsEnd.isSame(targetEndDate, "day")) {
                errors.push(
                    String(
                        $__(
                            "In end date only mode, you can only select the calculated end date"
                        )
                    )
                );
                valid = false;
            }
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
                errors.push(
                    String(
                        $__("Date %s is unavailable.").format(
                            d.format("YYYY-MM-DD")
                        )
                    )
                );
                valid = false;
                break;
            }
        }
    }

    logger.debug("Date change validation result", { valid, errors });
    logger.timeEnd("handleBookingDateChange");

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
            i =>
                i.item_id != null &&
                (String(i.item_id) === String(item_id) ||
                    Number(i.item_id) === Number(item_id))
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
            // Map IntervalTree types to CSS class names
            if (type === "booking") type = "booked";
            if (type === "checkout") type = "checked-out";
            // lead and trail periods keep their original names for CSS
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
    if (typeof val === "string" && window?.flatpickr) {
        // Use flatpickr's built-in parseDate method
        const dateFormat = window?.flatpickr_dateformat_string || "Y-m-d";
        const formatConfig =
            DATE_FORMAT_MAP[dateFormat] || DATE_FORMAT_MAP["Y-m-d"];

        // Find dates in the string using our regex pattern
        const foundDates = val.match(formatConfig.pattern);

        if (foundDates?.length >= 2) {
            try {
                // Use flatpickr's parseDate for consistent parsing with the picker
                const start = flatpickr.parseDate(foundDates[0], dateFormat);
                const end = flatpickr.parseDate(foundDates[1], dateFormat);

                if (start && end) {
                    return [
                        dayjs(start).toISOString(),
                        dayjs(end).toISOString(),
                    ];
                }
            } catch (e) {
                // Fall back to dayjs parsing if flatpickr fails
                const [start, end] = foundDates.slice(0, 2).map(dateStr => {
                    const parsed = dayjs(dateStr, formatConfig.dayjsFormat);
                    return parsed.isValid() ? parsed.toISOString() : null;
                });

                if (start && end) {
                    return [start, end];
                }
            }
        }
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
    logger.debug("constrainPickupLocations called", {
        inputLocations: pickupLocations.length,
        bookingItemtypeId,
        bookingItemId,
        bookableItems: bookableItems.length,
        locationDetails: pickupLocations.map(loc => ({
            library_id: loc.library_id,
            pickup_items: loc.pickup_items?.length || 0,
        })),
    });

    if (!bookingItemtypeId && !bookingItemId) {
        logger.debug(
            "constrainPickupLocations: No constraints, returning all locations"
        );
        return {
            filtered: pickupLocations,
            filteredOutCount: 0,
            total: pickupLocations.length,
        };
    }
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
    logger.debug("constrainPickupLocations result", {
        inputCount: pickupLocations.length,
        outputCount: filtered.length,
        filteredOutCount: pickupLocations.length - filtered.length,
        constraints: {
            bookingItemtypeId,
            bookingItemId,
        },
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
    logger.debug("constrainBookableItems called", {
        inputItems: bookableItems.length,
        pickupLibraryId,
        bookingItemtypeId,
        pickupLocations: pickupLocations.length,
        itemDetails: bookableItems.map(item => ({
            item_id: item.item_id,
            item_type_id: item.item_type_id,
            title: item.title,
        })),
    });

    if (!pickupLibraryId && !bookingItemtypeId) {
        logger.debug(
            "constrainBookableItems: No constraints, returning all items"
        );
        return {
            filtered: bookableItems,
            filteredOutCount: 0,
            total: bookableItems.length,
        };
    }
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
    logger.debug("constrainBookableItems result", {
        inputCount: bookableItems.length,
        outputCount: filtered.length,
        filteredOutCount: bookableItems.length - filtered.length,
        filteredItems: filtered.map(item => ({
            item_id: item.item_id,
            item_type_id: item.item_type_id,
            title: item.title,
        })),
        constraints: {
            pickupLibraryId,
            bookingItemtypeId,
        },
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

/**
 * Calculate constraint highlighting data for calendar display
 * @param {Date|dayjs} startDate - Selected start date
 * @param {Object} circulationRules - Circulation rules object
 * @param {Object} constraintOptions - Additional constraint options
 * @returns {Object} Constraint highlighting configuration
 */
export function calculateConstraintHighlighting(
    startDate,
    circulationRules,
    constraintOptions = {}
) {
    logger.debug("Calculating constraint highlighting", {
        startDate,
        circulationRules,
        constraintOptions,
    });

    const start = dayjs(startDate).startOf("day");

    // Determine the constraint period
    let maxPeriod = constraintOptions.maxBookingPeriod;
    if (
        !maxPeriod &&
        circulationRules?.booking_constraint_mode === "end_date_only"
    ) {
        maxPeriod =
            Number(circulationRules.maxPeriod) ||
            Number(circulationRules.issuelength) ||
            30;
    }

    if (!maxPeriod) {
        logger.debug("No constraint period to highlight");
        return null;
    }

    // Calculate target end date
    const targetEndDate = start.add(maxPeriod - 1, "day").toDate();

    // Calculate intermediate dates for end_date_only mode
    const blockedIntermediateDates = [];
    if (circulationRules?.booking_constraint_mode === "end_date_only") {
        for (let i = 1; i < maxPeriod - 1; i++) {
            blockedIntermediateDates.push(start.add(i, "day").toDate());
        }
    }

    const result = {
        startDate: start.toDate(),
        targetEndDate,
        blockedIntermediateDates,
        constraintMode: circulationRules?.booking_constraint_mode || "normal",
        maxPeriod,
    };

    logger.debug("Constraint highlighting calculated", result);
    return result;
}

/**
 * Determine if calendar should navigate to show target end date
 * @param {Date|dayjs} startDate - Selected start date
 * @param {Date|dayjs} targetEndDate - Calculated target end date
 * @param {Object} currentView - Current calendar view info
 * @returns {Object} Navigation info or null
 */
export function getCalendarNavigationTarget(
    startDate,
    targetEndDate,
    currentView = {}
) {
    logger.debug("Checking calendar navigation", {
        startDate,
        targetEndDate,
        currentView,
    });

    const start = dayjs(startDate);
    const target = dayjs(targetEndDate);

    // Check if target is in a different month
    if (start.month() !== target.month() || start.year() !== target.year()) {
        const navigationTarget = {
            shouldNavigate: true,
            targetMonth: target.month(),
            targetYear: target.year(),
            targetDate: target.toDate(),
        };

        logger.debug("Calendar should navigate", navigationTarget);
        return navigationTarget;
    }

    logger.debug("No navigation needed - same month");
    return { shouldNavigate: false };
}

/**
 * Aggregate markers by type for display
 * @param {Array} markers - Array of booking markers
 * @returns {Object} Aggregated counts by type
 */
export function aggregateMarkersByType(markers) {
    logger.debug("Aggregating markers", { count: markers.length });

    const aggregated = markers.reduce((acc, marker) => {
        // Exclude lead and trail markers from visual display
        if (marker.type !== "lead" && marker.type !== "trail") {
            acc[marker.type] = (acc[marker.type] || 0) + 1;
        }
        return acc;
    }, {});

    logger.debug("Markers aggregated", aggregated);
    return aggregated;
}

// Re-export the new efficient data structure builders
export { buildIntervalTree, processCalendarView };
