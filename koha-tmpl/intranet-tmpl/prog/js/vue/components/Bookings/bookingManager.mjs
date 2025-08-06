// bookingManager.js
// Pure utility functions for date/booking calculations and business logic
// To be used by the Pinia store and BookingModal.vue

import dayjs from "../../utils/dayjs.mjs";
import { managerLogger as logger } from "./bookingLogger.mjs";

// Use global $__ function (available in browser, mocked in tests)
const $__ = globalThis.$__ || (str => str);

/**
 * Validate end_date_only start date selection - checks entire range for conflicts
 * @param {dayjs.Dayjs} date - Potential start date
 * @param {number} maxPeriod - Maximum booking period
 * @param {Object} intervalTree - Interval tree for conflict checking
 * @param {string|null} selectedItem - Selected item ID
 * @param {number|null} editBookingId - Booking ID being edited
 * @param {Array} allItemIds - All available item IDs
 * @returns {boolean} True if date should be disabled
 */
function validateEndDateOnlyStartDate(
    date,
    maxPeriod,
    intervalTree,
    selectedItem,
    editBookingId,
    allItemIds
) {
    const targetEndDate = date.add(maxPeriod - 1, "day");

    logger.debug(
        `Checking end_date_only range: ${date.format(
            "YYYY-MM-DD"
        )} to ${targetEndDate.format("YYYY-MM-DD")}`
    );

    if (selectedItem) {
        // Specific item selected - check if that item has conflicts in the range
        const conflicts = intervalTree.queryRange(
            date.valueOf(),
            targetEndDate.valueOf(),
            String(selectedItem)
        );

        const relevantConflicts = conflicts.filter(
            interval =>
                !editBookingId || interval.metadata.booking_id != editBookingId
        );

        if (relevantConflicts.length > 0) {
            logger.debug(
                `Start date blocked - range conflicts for specific item ${selectedItem}`
            );
            return true;
        }
    } else {
        // "Any item" mode - check if ALL items are unavailable for ANY date in the range
        let allItemsBlockedOnSomeDate = false;

        for (
            let checkDate = date;
            checkDate.isSameOrBefore(targetEndDate, "day");
            checkDate = checkDate.add(1, "day")
        ) {
            const dayConflicts = intervalTree.query(checkDate.valueOf());
            const relevantDayConflicts = dayConflicts.filter(
                interval =>
                    !editBookingId ||
                    interval.metadata.booking_id != editBookingId
            );

            const unavailableItemIds = new Set(
                relevantDayConflicts.map(c => String(c.itemId))
            );
            const allItemsUnavailableOnThisDay =
                allItemIds.length > 0 &&
                allItemIds.every(id => unavailableItemIds.has(String(id)));

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
            startDate: date.format("YYYY-MM-DD"),
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

    return false;
}

/**
 * Handle end_date_only intermediate date logic when start date is selected
 * @param {dayjs.Dayjs} date - Date being checked
 * @param {Array} selectedDates - Currently selected dates
 * @param {number} maxPeriod - Maximum booking period
 * @returns {boolean|null} True to disable, false to allow, null to continue with normal logic
 */
function handleEndDateOnlyIntermediateDates(date, selectedDates, maxPeriod) {
    if (!selectedDates || selectedDates.length !== 1) {
        return null; // Not applicable, continue with normal logic
    }

    const startDate = dayjs(selectedDates[0]).startOf("day");
    const expectedEndDate = startDate.add(maxPeriod - 1, "day");

    // If this is the expected end date, allow it (let it fall through to normal validation)
    if (date.isSame(expectedEndDate, "day")) {
        logger.debug(
            `Allowing expected end date ${date.format(
                "YYYY-MM-DD"
            )} in end_date_only mode`
        );
        return null; // Continue with normal validation
    }

    // If this is an intermediate date, let calendar highlighting handle visual feedback
    if (
        date.isAfter(startDate, "day") &&
        date.isBefore(expectedEndDate, "day")
    ) {
        logger.debug(
            `Processing intermediate date ${date.format(
                "YYYY-MM-DD"
            )} in end_date_only mode (will be visually highlighted by calendar)`
        );
        return null; // Don't disable - let calendar highlighting handle visual feedback
    }

    // If this is after the expected end date, disable it
    if (date.isAfter(expectedEndDate, "day")) {
        logger.debug(
            `Disabling date ${date.format(
                "YYYY-MM-DD"
            )} beyond end_date_only range`
        );
        return true; // Hard disable dates beyond the range
    }

    return null; // Continue with normal logic for other dates
}
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
        priority: 1, // ISO format always preferred
    },
    "d.m.Y": {
        pattern: /\d{1,2}\.\d{1,2}\.\d{4}/g,
        dayjsFormat: "DD.MM.YYYY",
        priority: 2, // Common European format
    },
    "d/m/Y": {
        pattern: /\d{1,2}\/\d{1,2}\/\d{4}/g,
        dayjsFormat: "DD/MM/YYYY",
        priority: 3, // European slash format
    },
    "m/d/Y": {
        pattern: /\d{1,2}\/\d{1,2}\/\d{4}/g,
        dayjsFormat: "MM/DD/YYYY",
        priority: 4, // US format (lower priority for international use)
    },
    "d-m-Y": {
        pattern: /\d{1,2}-\d{1,2}-\d{4}/g,
        dayjsFormat: "DD-MM-YYYY",
        priority: 5, // European dash format
    },
    "m-d-Y": {
        pattern: /\d{1,2}-\d{1,2}-\d{4}/g,
        dayjsFormat: "MM-DD-YYYY",
        priority: 6, // US dash format
    },
};

/**
 * Get locale-aware date format configuration
 * @returns {Object} Date format configuration based on current locale
 */
function getLocalizedDateFormat() {
    const dateFormat = window?.flatpickr_dateformat_string || "Y-m-d";
    const langCode =
        window.KohaLanguage ||
        document.documentElement.lang?.toLowerCase() ||
        "en";

    // Get base format configuration
    let formatConfig = DATE_FORMAT_MAP[dateFormat] || DATE_FORMAT_MAP["Y-m-d"];

    // For ambiguous formats (slash-separated), use locale to determine interpretation
    if (dateFormat === "d/m/Y" || dateFormat === "m/d/Y") {
        const isUSLocale =
            langCode.startsWith("en-us") ||
            (langCode === "en" &&
                (navigator.language || "").toLowerCase().includes("us"));

        if (isUSLocale) {
            formatConfig = DATE_FORMAT_MAP["m/d/Y"];
        } else {
            formatConfig = DATE_FORMAT_MAP["d/m/Y"];
        }
    }

    return { dateFormat, formatConfig, langCode };
}

/**
 * Check if a date is in the past (before today)
 * @param {dayjs.Dayjs} date - Date to check
 * @param {dayjs.Dayjs} today - Today's date
 * @returns {boolean} True if date is in the past
 */
function isPastDate(date, today) {
    return date.isBefore(today, "day");
}

/**
 * Optimized lead period validation using range queries instead of individual point queries
 * @param {dayjs.Dayjs} startDate - Potential start date to validate
 * @param {number} leadDays - Number of lead period days to check
 * @param {Object} intervalTree - Interval tree for conflict checking
 * @param {string|null} selectedItem - Selected item ID or null
 * @param {number|null} editBookingId - Booking ID being edited
 * @param {Array} allItemIds - All available item IDs
 * @returns {boolean} True if start date should be blocked due to lead period conflicts
 */
function validateLeadPeriodOptimized(
    startDate,
    leadDays,
    intervalTree,
    selectedItem,
    editBookingId,
    allItemIds
) {
    if (leadDays <= 0) return false;

    const leadStart = startDate.subtract(leadDays, "day");
    const leadEnd = startDate.subtract(1, "day");

    logger.debug(
        `Optimized lead period check: ${leadStart.format(
            "YYYY-MM-DD"
        )} to ${leadEnd.format("YYYY-MM-DD")}`
    );

    // Use range query to get all conflicts in the lead period at once
    const leadConflicts = intervalTree.queryRange(
        leadStart.valueOf(),
        leadEnd.valueOf(),
        selectedItem ? String(selectedItem) : null
    );

    const relevantLeadConflicts = leadConflicts.filter(
        c => !editBookingId || c.metadata.booking_id != editBookingId
    );

    if (selectedItem) {
        // For specific item, any conflict in lead period blocks the start date
        return relevantLeadConflicts.length > 0;
    } else {
        // For "any item" mode, need to check if there are conflicts for ALL items
        // on ANY day in the lead period
        if (relevantLeadConflicts.length === 0) return false;

        const unavailableItemIds = new Set(
            relevantLeadConflicts.map(c => c.itemId)
        );
        const allUnavailable =
            allItemIds.length > 0 &&
            allItemIds.every(id => unavailableItemIds.has(String(id)));

        logger.debug(`Lead period multi-item check (optimized):`, {
            leadPeriod: `${leadStart.format("YYYY-MM-DD")} to ${leadEnd.format(
                "YYYY-MM-DD"
            )}`,
            totalItems: allItemIds.length,
            conflictsFound: relevantLeadConflicts.length,
            unavailableItems: Array.from(unavailableItemIds),
            allUnavailable: allUnavailable,
            decision: allUnavailable ? "BLOCK" : "ALLOW",
        });

        return allUnavailable;
    }
}

/**
 * Optimized trail period validation using range queries instead of individual point queries
 * @param {dayjs.Dayjs} endDate - Potential end date to validate
 * @param {number} trailDays - Number of trail period days to check
 * @param {Object} intervalTree - Interval tree for conflict checking
 * @param {string|null} selectedItem - Selected item ID or null
 * @param {number|null} editBookingId - Booking ID being edited
 * @param {Array} allItemIds - All available item IDs
 * @returns {boolean} True if end date should be blocked due to trail period conflicts
 */
function validateTrailPeriodOptimized(
    endDate,
    trailDays,
    intervalTree,
    selectedItem,
    editBookingId,
    allItemIds
) {
    if (trailDays <= 0) return false;

    const trailStart = endDate.add(1, "day");
    const trailEnd = endDate.add(trailDays, "day");

    logger.debug(
        `Optimized trail period check: ${trailStart.format(
            "YYYY-MM-DD"
        )} to ${trailEnd.format("YYYY-MM-DD")}`
    );

    // Use range query to get all conflicts in the trail period at once
    const trailConflicts = intervalTree.queryRange(
        trailStart.valueOf(),
        trailEnd.valueOf(),
        selectedItem ? String(selectedItem) : null
    );

    const relevantTrailConflicts = trailConflicts.filter(
        c => !editBookingId || c.metadata.booking_id != editBookingId
    );

    if (selectedItem) {
        // For specific item, any conflict in trail period blocks the end date
        return relevantTrailConflicts.length > 0;
    } else {
        // For "any item" mode, need to check if there are conflicts for ALL items
        // on ANY day in the trail period
        if (relevantTrailConflicts.length === 0) return false;

        const unavailableItemIds = new Set(
            relevantTrailConflicts.map(c => c.itemId)
        );
        const allUnavailable =
            allItemIds.length > 0 &&
            allItemIds.every(id => unavailableItemIds.has(String(id)));

        logger.debug(`Trail period multi-item check (optimized):`, {
            trailPeriod: `${trailStart.format(
                "YYYY-MM-DD"
            )} to ${trailEnd.format("YYYY-MM-DD")}`,
            totalItems: allItemIds.length,
            conflictsFound: relevantTrailConflicts.length,
            unavailableItems: Array.from(unavailableItemIds),
            allUnavailable: allUnavailable,
            decision: allUnavailable ? "BLOCK" : "ALLOW",
        });

        return allUnavailable;
    }
}

/**
 * Extracts and validates configuration from circulation rules
 * @param {Object} circulationRules - Raw circulation rules object
 * @param {Date|dayjs} todayArg - Optional today value for deterministic tests
 * @returns {Object} Normalized configuration object
 */
function extractBookingConfiguration(circulationRules, todayArg) {
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

    logger.debug("Booking configuration extracted:", {
        today: today.format("YYYY-MM-DD"),
        leadDays,
        trailDays,
        maxPeriod,
        isEndDateOnly,
        rawRules: circulationRules,
    });

    return {
        today,
        leadDays,
        trailDays,
        maxPeriod,
        isEndDateOnly,
    };
}

/**
 * Creates the main disable function that determines if a date should be disabled
 * @param {Object} intervalTree - Interval tree for conflict checking
 * @param {Object} config - Configuration object from extractBookingConfiguration
 * @param {Array} bookableItems - Array of bookable items
 * @param {string|null} selectedItem - Selected item ID or null
 * @param {number|null} editBookingId - Booking ID being edited
 * @param {Array} selectedDates - Currently selected dates
 * @returns {Function} Disable function for Flatpickr
 */
function createDisableFunction(
    intervalTree,
    config,
    bookableItems,
    selectedItem,
    editBookingId,
    selectedDates
) {
    const { today, leadDays, trailDays, maxPeriod, isEndDateOnly } = config;
    const allItemIds = bookableItems.map(i => i.item_id);

    return date => {
        const dayjs_date = dayjs(date).startOf("day");

        // Guard clause: Basic past date validation
        if (dayjs_date.isBefore(today, "day")) return true;

        // Guard clause: No bookable items available
        if (!bookableItems || bookableItems.length === 0) {
            logger.debug(
                `Date ${dayjs_date.format(
                    "YYYY-MM-DD"
                )} disabled - no bookable items available`
            );
            return true;
        }

        // Guard clause: End date only mode - potential start date validation
        if (isEndDateOnly && (!selectedDates || selectedDates?.length === 0)) {
            if (
                validateEndDateOnlyStartDate(
                    dayjs_date,
                    maxPeriod,
                    intervalTree,
                    selectedItem,
                    editBookingId,
                    allItemIds
                )
            ) {
                return true;
            }
        }

        // Guard clause: End date only mode - intermediate date handling
        if (isEndDateOnly && selectedDates?.length === 1) {
            const intermediateResult = handleEndDateOnlyIntermediateDates(
                dayjs_date,
                selectedDates,
                maxPeriod
            );
            if (intermediateResult === true) {
                return true;
            }
        }

        // Guard clause: Standard point-in-time availability check
        const pointConflicts = intervalTree.query(
            dayjs_date.valueOf(),
            selectedItem ? String(selectedItem) : null
        );
        const relevantPointConflicts = pointConflicts.filter(
            interval =>
                !editBookingId || interval.metadata.booking_id != editBookingId
        );

        // Guard clause: Specific item conflicts
        if (selectedItem && relevantPointConflicts.length > 0) {
            logger.debug(
                `Date ${dayjs_date.format(
                    "YYYY-MM-DD"
                )} blocked for item ${selectedItem}:`,
                relevantPointConflicts.map(c => c.type)
            );
            return true;
        }

        // Guard clause: All items unavailable (any item mode)
        if (!selectedItem) {
            const unavailableItemIds = new Set(
                relevantPointConflicts.map(c => c.itemId)
            );
            const allUnavailable =
                allItemIds.length > 0 &&
                allItemIds.every(id => unavailableItemIds.has(String(id)));

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

        // Lead/trail period validation using optimized queries
        if (!selectedDates || selectedDates.length === 0) {
            // Potential start date - check lead period
            if (leadDays > 0) {
                logger.debug(
                    `Checking lead period for ${dayjs_date.format(
                        "YYYY-MM-DD"
                    )} (${leadDays} days)`
                );
            }

            // Optimized lead period validation using range queries
            if (
                validateLeadPeriodOptimized(
                    dayjs_date,
                    leadDays,
                    intervalTree,
                    selectedItem,
                    editBookingId,
                    allItemIds
                )
            ) {
                logger.debug(
                    `Start date ${dayjs_date.format(
                        "YYYY-MM-DD"
                    )} blocked - lead period conflict (optimized check)`
                );
                return true;
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

            // Optimized trail period validation using range queries
            if (
                validateTrailPeriodOptimized(
                    dayjs_date,
                    trailDays,
                    intervalTree,
                    selectedItem,
                    editBookingId,
                    allItemIds
                )
            ) {
                logger.debug(
                    `End date ${dayjs_date.format(
                        "YYYY-MM-DD"
                    )} blocked - trail period conflict (optimized check)`
                );
                return true;
            }
        }

        return false;
    };
}

/**
 * Logs comprehensive debug information for OPAC booking selection debugging
 * @param {Array} bookings - Array of booking objects
 * @param {Array} checkouts - Array of checkout objects
 * @param {Array} bookableItems - Array of bookable items
 * @param {string|null} selectedItem - Selected item ID
 * @param {Object} circulationRules - Circulation rules
 */
function logBookingDebugInfo(
    bookings,
    checkouts,
    bookableItems,
    selectedItem,
    circulationRules
) {
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
}

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

    // Log comprehensive debug information for OPAC debugging
    logBookingDebugInfo(
        bookings,
        checkouts,
        bookableItems,
        selectedItem,
        circulationRules
    );

    // Build IntervalTree with all booking/checkout data
    const intervalTree = buildIntervalTree(
        bookings,
        checkouts,
        circulationRules
    );

    // Extract and validate configuration
    const config = extractBookingConfiguration(circulationRules, todayArg);
    const allItemIds = bookableItems.map(i => i.item_id);

    // Create optimized disable function using extracted helper
    const disableFunction = createDisableFunction(
        intervalTree,
        config,
        bookableItems,
        selectedItem,
        editBookingId,
        selectedDates
    );

    // Build unavailableByDate for backward compatibility and markers
    const unavailableByDate = buildUnavailableByDateMap(
        intervalTree,
        config.today,
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
 * Parse a date range value into ISO date strings
 *
 * ⚠️  DEPRECATION NOTE: This function should become unnecessary once we eliminate
 * all string-based date handling. The new approach stores ISO strings directly
 * from flatpickr's Date objects, eliminating the need for complex parsing.
 *
 * Current usage: Fallback for cases where legacy string dates still exist.
 * Future: Should be removable once all date handling uses ISO arrays.
 *
 * @param {Array|string|null} val - Date range value
 * @returns {Array<string|null>} - [start, end] ISO strings (or null)
 */
export function parseDateRange(val) {
    if (Array.isArray(val)) {
        const result = [
            val[0] ? dayjs(val[0]).toISOString() : null,
            val[1] ? dayjs(val[1]).toISOString() : null,
        ];
        return result;
    }

    if (typeof val === "string" && window?.flatpickr) {
        const { dateFormat, formatConfig, langCode } = getLocalizedDateFormat();
        console.log("🌍 Locale info:", { dateFormat, langCode, formatConfig });

        // Get locale configuration for flatpickr parsing
        let locale = null;

        if (langCode !== "en" && window.flatpickr?.l10ns?.[langCode]) {
            locale = window.flatpickr.l10ns[langCode];
            console.log("🌍 Using flatpickr locale:", langCode, locale);
        } else if (langCode !== "en") {
            // Create fallback locale using available global settings
            const fallbackLocale = {};
            if (window.flatpickr_weekdays)
                fallbackLocale.weekdays = window.flatpickr_weekdays;
            if (window.flatpickr_months)
                fallbackLocale.months = window.flatpickr_months;
            if (Object.keys(fallbackLocale).length > 0) {
                locale = fallbackLocale;
                console.log("🌍 Using fallback locale:", locale);
            }
        } else {
            console.log("🌍 Using English locale");
        }

        // First try: Use flatpickr's locale-aware range parsing
        try {
            // Get the actual rangeSeparator from flatpickr's loaded locale
            let rangeSeparator = " to "; // default

            if (window.flatpickr?.l10ns) {
                const currentLang = langCode || "en";
                const flatpickrLocale =
                    window.flatpickr.l10ns[currentLang] ||
                    window.flatpickr.l10ns.default;
                if (flatpickrLocale?.rangeSeparator) {
                    rangeSeparator = flatpickrLocale.rangeSeparator;
                }
            }

            console.log(
                "📅 Range separator from flatpickr locale:",
                rangeSeparator
            );

            if (val.includes(rangeSeparator)) {
                const parts = val.split(rangeSeparator);

                if (parts.length >= 2) {
                    console.log(
                        "📅 Parsing range with flatpickr:",
                        parts[0].trim(),
                        "and",
                        parts[1].trim(),
                        "format:",
                        dateFormat
                    );
                    const start = flatpickr.parseDate(
                        parts[0].trim(),
                        dateFormat,
                        locale
                    );
                    const end = flatpickr.parseDate(
                        parts[1].trim(),
                        dateFormat,
                        locale
                    );

                    if (start && end) {
                        const result = [
                            dayjs(start).toISOString(),
                            dayjs(end).toISOString(),
                        ];
                        return result;
                    }
                }
            }

            // Single date case
            console.log(
                "📅 Single date parsing with flatpickr:",
                val,
                "format:",
                dateFormat
            );
            const parsed = flatpickr.parseDate(val, dateFormat, locale);
            if (parsed) {
                const result = [dayjs(parsed).toISOString(), null];
                return result;
            }
        } catch (e) {}

        // Fallback: Pattern-based parsing with dayjs
        console.log(
            "📅 Falling back to pattern matching with regex:",
            formatConfig.pattern
        );
        const foundDates = val.match(formatConfig.pattern);

        if (foundDates?.length >= 2) {
            try {
                const [start, end] = foundDates.slice(0, 2).map(dateStr => {
                    const parsed = dayjs(
                        dateStr,
                        formatConfig.dayjsFormat,
                        true
                    ); // strict parsing
                    return parsed.isValid() ? parsed.toISOString() : null;
                });

                if (start && end) {
                    return [start, end];
                }
            } catch (e) {}
        } else if (foundDates?.length === 1) {
            // Single date found
            try {
                const parsed = dayjs(
                    foundDates[0],
                    formatConfig.dayjsFormat,
                    true
                );
                console.log(
                    "📅 Single date parsed:",
                    parsed.isValid() ? parsed.format() : "INVALID"
                );
                if (parsed.isValid()) {
                    const result = [parsed.toISOString(), null];
                    console.log(
                        "✅ Single date pattern parsing successful:",
                        result
                    );
                    return result;
                }
            } catch (e) {
                console.warn("❌ Single date parsing failed", e);
            }
        }
    }

    // Final fallback: Try ISO parsing with dayjs
    if (typeof val === "string" && val.trim()) {
        try {
            const parsed = dayjs(val);
            if (parsed.isValid()) {
                const result = [parsed.toISOString(), null];
                return result;
            }
        } catch (e) {}
    }

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
                    loc.pickup_items.includes(item.item_id)
            );
            const match = item.item_type_id === bookingItemtypeId && found;
            return match;
        }
        if (pickupLibraryId) {
            const found = pickupLocations.find(
                loc =>
                    loc.library_id === pickupLibraryId &&
                    loc.pickup_items &&
                    loc.pickup_items.includes(item.item_id)
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
