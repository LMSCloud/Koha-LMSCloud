import dayjs from "../../../../utils/dayjs.mjs";
import {
    isoArrayToDates,
    toDayjs,
    addDays,
    subDays,
    formatYMD,
} from "./date-utils.mjs";
import { managerLogger as logger } from "./logger.mjs";
import { createConstraintStrategy } from "./strategies.mjs";
import {
    // eslint-disable-next-line no-unused-vars
    IntervalTree,
    buildIntervalTree,
} from "./algorithms/interval-tree.mjs";
import {
    SweepLineProcessor,
    processCalendarView,
} from "./algorithms/sweep-line-processor.mjs";
import { idsEqual, includesId } from "./id-utils.mjs";
import {
    CONSTRAINT_MODE_END_DATE_ONLY,
    CONSTRAINT_MODE_NORMAL,
    SELECTION_ANY_AVAILABLE,
    SELECTION_SPECIFIC_ITEM,
} from "./constants.mjs";

const $__ = globalThis.$__ || (str => str);

/**
 * Build unavailableByDate map from IntervalTree for backward compatibility
 * @param {IntervalTree} intervalTree - The interval tree containing all bookings/checkouts
 * @param {import('dayjs').Dayjs} today - Today's date for range calculation
 * @param {Array} allItemIds - Array of all item IDs
 * @param {number|string|null} editBookingId - The booking_id being edited (exclude from results)
 * @param {Object} options - Additional options for optimization
 * @param {Object} [options] - Additional options for optimization
 * @param {Date} [options.visibleStartDate] - Start of visible calendar range
 * @param {Date} [options.visibleEndDate] - End of visible calendar range
 * @param {boolean} [options.onDemand] - Whether to build map on-demand for visible dates only
 * @returns {import('../../types/bookings').UnavailableByDate}
 */
function buildUnavailableByDateMap(
    intervalTree,
    today,
    allItemIds,
    editBookingId,
    options = {}
) {
    /** @type {import('../../types/bookings').UnavailableByDate} */
    const unavailableByDate = {};

    if (!intervalTree || intervalTree.size === 0) {
        return unavailableByDate;
    }

    let startDate, endDate;
    if (
        options.onDemand &&
        options.visibleStartDate &&
        options.visibleEndDate
    ) {
        startDate = subDays(options.visibleStartDate, 7);
        endDate = addDays(options.visibleEndDate, 7);
        logger.debug("Building unavailableByDate map for visible range only", {
            start: formatYMD(startDate),
            end: formatYMD(endDate),
            days: endDate.diff(startDate, "day") + 1,
        });
    } else {
        startDate = subDays(today, 7);
        endDate = addDays(today, 90);
        logger.debug("Building unavailableByDate map with limited range", {
            start: formatYMD(startDate),
            end: formatYMD(endDate),
            days: endDate.diff(startDate, "day") + 1,
        });
    }

    const rangeIntervals = intervalTree.queryRange(
        startDate.toDate(),
        endDate.toDate()
    );

    // Exclude the booking being edited
    const relevantIntervals = editBookingId
        ? rangeIntervals.filter(
              interval => interval.metadata?.booking_id != editBookingId
          )
        : rangeIntervals;

    const processor = new SweepLineProcessor();
    const sweptMap = processor.processIntervals(
        relevantIntervals,
        startDate.toDate(),
        endDate.toDate(),
        allItemIds
    );

    // Ensure the map contains all dates in the requested range, even if empty
    const filledMap = sweptMap && typeof sweptMap === "object" ? sweptMap : {};
    for (
        let d = startDate.clone();
        d.isSameOrBefore(endDate, "day");
        d = d.add(1, "day")
    ) {
        const key = d.format("YYYY-MM-DD");
        if (!filledMap[key]) filledMap[key] = {};
    }

    // Normalize reasons for legacy API expectations: convert 'core' -> 'booking'
    Object.keys(filledMap).forEach(dateKey => {
        const byItem = filledMap[dateKey];
        Object.keys(byItem).forEach(itemId => {
            const original = byItem[itemId];
            if (original && original instanceof Set) {
                const mapped = new Set();
                original.forEach(reason => {
                    mapped.add(reason === "core" ? "booking" : reason);
                });
                byItem[itemId] = mapped;
            }
        });
    });

    return filledMap;
}

// Small helper to standardize constraint function return shape
function buildConstraintResult(filtered, total) {
    const filteredOutCount = total - filtered.length;
    return {
        filtered,
        filteredOutCount,
        total,
        constraintApplied: filtered.length !== total,
    };
}

/**
 * Optimized lead period validation using range queries instead of individual point queries
 * @param {import("dayjs").Dayjs} startDate - Potential start date to validate
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
        `Optimized lead period check: ${formatYMD(leadStart)} to ${formatYMD(
            leadEnd
        )}`
    );

    // Use range query to get all conflicts in the lead period at once
    const leadConflicts = intervalTree.queryRange(
        leadStart.valueOf(),
        leadEnd.valueOf(),
        selectedItem != null ? String(selectedItem) : null
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
            leadPeriod: `${formatYMD(leadStart)} to ${formatYMD(leadEnd)}`,
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
 * @param {import("dayjs").Dayjs} endDate - Potential end date to validate
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
        `Optimized trail period check: ${formatYMD(trailStart)} to ${formatYMD(
            trailEnd
        )}`
    );

    // Use range query to get all conflicts in the trail period at once
    const trailConflicts = intervalTree.queryRange(
        trailStart.valueOf(),
        trailEnd.valueOf(),
        selectedItem != null ? String(selectedItem) : null
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
 * @param {Date|import('dayjs').Dayjs} todayArg - Optional today value for deterministic tests
 * @returns {Object} Normalized configuration object
 */
function extractBookingConfiguration(circulationRules, todayArg) {
    const today = todayArg
        ? toDayjs(todayArg).startOf("day")
        : dayjs().startOf("day");
    const leadDays = Number(circulationRules?.bookings_lead_period) || 0;
    const trailDays = Number(circulationRules?.bookings_trail_period) || 0;
    // In unconstrained mode, do not enforce a default max period
    const maxPeriod =
        Number(circulationRules?.maxPeriod) ||
        Number(circulationRules?.issuelength) ||
        0;
    const isEndDateOnly =
        circulationRules?.booking_constraint_mode ===
        CONSTRAINT_MODE_END_DATE_ONLY;
    const calculatedDueDate = circulationRules?.calculated_due_date
        ? dayjs(circulationRules.calculated_due_date).startOf("day")
        : null;
    const calculatedPeriodDays = Number(
        circulationRules?.calculated_period_days
    )
        ? Number(circulationRules.calculated_period_days)
        : null;

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
        calculatedDueDate,
        calculatedPeriodDays,
    };
}

/**
 * Creates the main disable function that determines if a date should be disabled
 * @param {Object} intervalTree - Interval tree for conflict checking
 * @param {Object} config - Configuration object from extractBookingConfiguration
 * @param {Array<import('../../types/bookings').BookableItem>} bookableItems - Array of bookable items
 * @param {string|null} selectedItem - Selected item ID or null
 * @param {number|null} editBookingId - Booking ID being edited
 * @param {Array<Date>} selectedDates - Currently selected dates
 * @returns {(date: Date) => boolean} Disable function for Flatpickr
 */
function createDisableFunction(
    intervalTree,
    config,
    bookableItems,
    selectedItem,
    editBookingId,
    selectedDates
) {
    const {
        today,
        leadDays,
        trailDays,
        maxPeriod,
        isEndDateOnly,
        calculatedDueDate,
    } = config;
    const allItemIds = bookableItems.map(i => String(i.item_id));
    const strategy = createConstraintStrategy(
        isEndDateOnly ? CONSTRAINT_MODE_END_DATE_ONLY : CONSTRAINT_MODE_NORMAL
    );

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

        // Mode-specific start date validation
        if (
            strategy.validateStartDateSelection(
                dayjs_date,
                {
                    today,
                    leadDays,
                    trailDays,
                    maxPeriod,
                    isEndDateOnly,
                    calculatedDueDate,
                },
                intervalTree,
                selectedItem,
                editBookingId,
                allItemIds,
                selectedDates
            )
        ) {
            return true;
        }

        // Mode-specific intermediate date handling
        const intermediateResult = strategy.handleIntermediateDate(
            dayjs_date,
            selectedDates,
            {
                today,
                leadDays,
                trailDays,
                maxPeriod,
                isEndDateOnly,
                calculatedDueDate,
            }
        );
        if (intermediateResult === true) {
            return true;
        }

        // Guard clause: Standard point-in-time availability check
        const pointConflicts = intervalTree.query(
            dayjs_date.valueOf(),
            selectedItem != null ? String(selectedItem) : null
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
            // Respect backend-calculated due date in end_date_only mode only if it's not before start
            if (
                isEndDateOnly &&
                config.calculatedDueDate &&
                !config.calculatedDueDate.isBefore(start, "day")
            ) {
                const targetEnd = config.calculatedDueDate;
                if (dayjs_date.isAfter(targetEnd, "day")) return true;
            } else if (maxPeriod > 0) {
                if (dayjs_date.isAfter(start.add(maxPeriod - 1, "day"), "day"))
                    return true;
            }

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
            selectedItem === null
                ? SELECTION_ANY_AVAILABLE
                : SELECTION_SPECIFIC_ITEM,
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
 * @param {Date|import('dayjs').Dayjs} todayArg - Optional today value for deterministic tests
 * @param {Object} options - Additional options for optimization
 * @returns {import('../../types/bookings').AvailabilityResult}
 */
export function calculateDisabledDates(
    bookings,
    checkouts,
    bookableItems,
    selectedItem,
    editBookingId,
    selectedDates = [],
    circulationRules = {},
    todayArg = undefined,
    options = {}
) {
    logger.time("calculateDisabledDates");
    const normalizedSelectedItem =
        selectedItem != null ? String(selectedItem) : null;
    logger.debug("calculateDisabledDates called", {
        bookingsCount: bookings.length,
        checkoutsCount: checkouts.length,
        itemsCount: bookableItems.length,
        normalizedSelectedItem,
        editBookingId,
        selectedDates,
        circulationRules,
    });

    // Log comprehensive debug information for OPAC debugging
    logBookingDebugInfo(
        bookings,
        checkouts,
        bookableItems,
        normalizedSelectedItem,
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
    const allItemIds = bookableItems.map(i => String(i.item_id));

    // Create optimized disable function using extracted helper
    const normalizedEditBookingId =
        editBookingId != null ? Number(editBookingId) : null;
    const disableFunction = createDisableFunction(
        intervalTree,
        config,
        bookableItems,
        normalizedSelectedItem,
        normalizedEditBookingId,
        selectedDates
    );

    // Build unavailableByDate for backward compatibility and markers
    // Pass options for performance optimization

    const unavailableByDate = buildUnavailableByDateMap(
        intervalTree,
        config.today,
        allItemIds,
        normalizedEditBookingId,
        options
    );

    logger.debug("IntervalTree-based availability calculated", {
        treeSize: intervalTree.size,
    });
    logger.timeEnd("calculateDisabledDates");

    return {
        disable: disableFunction,
        unavailableByDate: unavailableByDate,
    };
}

/**
 * Derive effective circulation rules with constraint options applied.
 * - Applies maxPeriod only for constraining modes
 * - Strips caps for unconstrained mode
 * @param {import('../../types/bookings').CirculationRule} [baseRules={}]
 * @param {import('../../types/bookings').ConstraintOptions} [constraintOptions={}]
 * @returns {import('../../types/bookings').CirculationRule}
 */
export function deriveEffectiveRules(baseRules = {}, constraintOptions = {}) {
    const effectiveRules = { ...baseRules };
    const mode = constraintOptions.dateRangeConstraint;
    if (mode === "issuelength" || mode === "issuelength_with_renewals") {
        if (constraintOptions.maxBookingPeriod) {
            effectiveRules.maxPeriod = constraintOptions.maxBookingPeriod;
        }
    } else {
        if ("maxPeriod" in effectiveRules) delete effectiveRules.maxPeriod;
        if ("issuelength" in effectiveRules) delete effectiveRules.issuelength;
    }
    return effectiveRules;
}

/**
 * Convenience: take full circulationRules array and constraint options,
 * return effective rules applying maxPeriod logic.
 * @param {import('../../types/bookings').CirculationRule[]} circulationRules
 * @param {import('../../types/bookings').ConstraintOptions} [constraintOptions={}]
 * @returns {import('../../types/bookings').CirculationRule}
 */
export function toEffectiveRules(circulationRules, constraintOptions = {}) {
    const baseRules = circulationRules?.[0] || {};
    return deriveEffectiveRules(baseRules, constraintOptions);
}

/**
 * Calculate maximum booking period from circulation rules and constraint mode.
 */
export function calculateMaxBookingPeriod(
    circulationRules,
    dateRangeConstraint,
    customDateRangeFormula = null
) {
    if (!dateRangeConstraint) return null;
    const rules = circulationRules?.[0];
    if (!rules) return null;
    const issuelength = parseInt(rules.issuelength) || 0;
    switch (dateRangeConstraint) {
        case "issuelength":
            return issuelength;
        case "issuelength_with_renewals":
            const renewalperiod = parseInt(rules.renewalperiod) || 0;
            const renewalsallowed = parseInt(rules.renewalsallowed) || 0;
            return issuelength + renewalperiod * renewalsallowed;
        case "custom":
            return typeof customDateRangeFormula === "function"
                ? customDateRangeFormula(rules)
                : null;
        default:
            return null;
    }
}

/**
 * Convenience wrapper to calculate availability (disable fn + map) given a dateRange.
 * Accepts ISO strings for dateRange and returns the result of calculateDisabledDates.
 * @returns {import('../../types/bookings').AvailabilityResult}
 */
export function calculateAvailabilityData(dateRange, storeData, options = {}) {
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
    const maxBookingPeriod = calculateMaxBookingPeriod(
        circulationRules,
        options.dateRangeConstraint,
        options.customDateRangeFormula
    );
    const effectiveRules = deriveEffectiveRules(baseRules, {
        dateRangeConstraint: options.dateRangeConstraint,
        maxBookingPeriod,
    });

    let selectedDatesArray = [];
    if (Array.isArray(dateRange)) {
        selectedDatesArray = isoArrayToDates(dateRange);
    } else if (typeof dateRange === "string") {
        throw new TypeError(
            "calculateAvailabilityData expects an array of ISO/date values for dateRange"
        );
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
 * @param {Date|import('dayjs').Dayjs} todayArg - Optional today value for deterministic tests
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
    todayArg = undefined,
    options = {}
) {
    logger.time("handleBookingDateChange");
    logger.debug("handleBookingDateChange called", {
        selectedDates,
        circulationRules,
        selectedItem,
        editBookingId,
    });
    const dayjsStart = selectedDates[0]
        ? toDayjs(selectedDates[0]).startOf("day")
        : null;
    const dayjsEnd = selectedDates[1]
        ? toDayjs(selectedDates[1]).endOf("day")
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
        const _trailDays = circulationRules?.trailDays || 0; // Still needed for start date check
        const maxPeriod =
            Number(circulationRules?.maxPeriod) ||
            Number(circulationRules?.issuelength) ||
            0;

        // Calculate min end date; max end date only when constrained
        newMinEndDate = dayjsStart.add(1, "day").startOf("day");
        if (maxPeriod > 0) {
            // Inclusive day cap: last selectable end = start + (maxPeriod - 1)
            newMaxEndDate = dayjsStart.add(maxPeriod - 1, "day").startOf("day");
        } else {
            newMaxEndDate = null;
        }

        // Validate: start must be after today + leadDays
        const today = todayArg
            ? toDayjs(todayArg).startOf("day")
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

        // Validate: period must not exceed maxPeriod unless overridden in end_date_only by backend due date
        if (dayjsEnd) {
            const isEndDateOnly =
                circulationRules?.booking_constraint_mode ===
                CONSTRAINT_MODE_END_DATE_ONLY;
            const dueStr = circulationRules?.calculated_due_date;
            const hasBackendDue = Boolean(dueStr);
            if (!isEndDateOnly || !hasBackendDue) {
                if (
                    maxPeriod > 0 &&
                    dayjsEnd.diff(dayjsStart, "day") + 1 > maxPeriod
                ) {
                    errors.push(
                        String($__("Booking period exceeds maximum allowed"))
                    );
                    valid = false;
                }
            }
        }

        // Strategy-specific enforcement for end date (e.g., end_date_only)
        const strategy = createConstraintStrategy(
            circulationRules?.booking_constraint_mode
        );
        const enforcement = strategy.enforceEndDateSelection(
            dayjsStart,
            dayjsEnd,
            circulationRules
        );
        if (!enforcement.ok) {
            errors.push(
                String(
                    $__(
                        "In end date only mode, you can only select the calculated end date"
                    )
                )
            );
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
            todayArg, // Pass todayArg
            options
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
 * @param {import('../../types/bookings').UnavailableByDate} unavailableByDate - Map produced by buildUnavailableByDateMap
 * @param {string|Date|import("dayjs").Dayjs} dateStr - date to check (YYYY-MM-DD or Date or dayjs)
 * @param {Array<import('../../types/bookings').BookableItem>} bookableItems - Array of all bookable items
 * @returns {import('../../types/bookings').CalendarMarker[]} indicators for that date
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
        return bookableItems.find(i => idsEqual(i?.item_id, item_id));
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
            // Map IntervalTree/Sweep reasons to CSS class names
            if (type === "booking") type = "booked";
            if (type === "core") type = "booked";
            if (type === "checkout") type = "checked-out";
            // lead and trail periods keep their original names for CSS
            markers.push({
                /** @type {import('../../types/bookings').MarkerType} */
                type: /** @type {any} */ (type),
                item: String(item_id),
                itemName: item?.title || String(item_id),
                barcode: item?.barcode || item?.external_id || null,
            });
        }
    }
    return markers;
}

/**
 * Constrain pickup locations based on selected itemtype or item
 * Returns { filtered, filteredOutCount, total, constraintApplied }
 *
 * @param {Array<import('../../types/bookings').PickupLocation>} pickupLocations
 * @param {Array<import('../../types/bookings').BookableItem>} bookableItems
 * @param {string|number|null} bookingItemtypeId
 * @param {string|number|null} bookingItemId
 * @returns {import('../../types/bookings').ConstraintResult<import('../../types/bookings').PickupLocation>}
 */
export function constrainPickupLocations(
    pickupLocations,
    bookableItems,
    bookingItemtypeId,
    bookingItemId
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
        return buildConstraintResult(pickupLocations, pickupLocations.length);
    }
    const filtered = pickupLocations.filter(loc => {
        if (bookingItemId) {
            return (
                loc.pickup_items && includesId(loc.pickup_items, bookingItemId)
            );
        }
        if (bookingItemtypeId) {
            return (
                loc.pickup_items &&
                bookableItems.some(
                    item =>
                        idsEqual(item.item_type_id, bookingItemtypeId) &&
                        includesId(loc.pickup_items, item.item_id)
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

    return buildConstraintResult(filtered, pickupLocations.length);
}

/**
 * Constrain bookable items based on selected pickup location and/or itemtype
 * Returns { filtered, filteredOutCount, total, constraintApplied }
 *
 * @param {Array<import('../../types/bookings').BookableItem>} bookableItems
 * @param {Array<import('../../types/bookings').PickupLocation>} pickupLocations
 * @param {string|null} pickupLibraryId
 * @param {string|number|null} bookingItemtypeId
 * @returns {import('../../types/bookings').ConstraintResult<import('../../types/bookings').BookableItem>}
 */
export function constrainBookableItems(
    bookableItems,
    pickupLocations,
    pickupLibraryId,
    bookingItemtypeId
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
        return buildConstraintResult(bookableItems, bookableItems.length);
    }
    const filtered = bookableItems.filter(item => {
        if (pickupLibraryId && bookingItemtypeId) {
            const found = pickupLocations.find(
                loc =>
                    idsEqual(loc.library_id, pickupLibraryId) &&
                    loc.pickup_items &&
                    includesId(loc.pickup_items, item.item_id)
            );
            const match =
                idsEqual(item.item_type_id, bookingItemtypeId) && found;
            return match;
        }
        if (pickupLibraryId) {
            const found = pickupLocations.find(
                loc =>
                    idsEqual(loc.library_id, pickupLibraryId) &&
                    loc.pickup_items &&
                    includesId(loc.pickup_items, item.item_id)
            );
            return found;
        }
        if (bookingItemtypeId) {
            return idsEqual(item.item_type_id, bookingItemtypeId);
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

    return buildConstraintResult(filtered, bookableItems.length);
}

/**
 * Constrain item types based on selected pickup location or item
 * Returns { filtered, filteredOutCount, total, constraintApplied }
 * @param {Array<import('../../types/bookings').ItemType>} itemTypes
 * @param {Array<import('../../types/bookings').BookableItem>} bookableItems
 * @param {Array<import('../../types/bookings').PickupLocation>} pickupLocations
 * @param {string|null} pickupLibraryId
 * @param {string|number|null} bookingItemId
 * @returns {import('../../types/bookings').ConstraintResult<import('../../types/bookings').ItemType>}
 */
export function constrainItemTypes(
    itemTypes,
    bookableItems,
    pickupLocations,
    pickupLibraryId,
    bookingItemId
) {
    if (!pickupLibraryId && !bookingItemId) {
        return buildConstraintResult(itemTypes, itemTypes.length);
    }
    const filtered = itemTypes.filter(type => {
        if (bookingItemId) {
            return bookableItems.some(
                item =>
                    idsEqual(item.item_id, bookingItemId) &&
                    idsEqual(item.item_type_id, type.item_type_id)
            );
        }
        if (pickupLibraryId) {
            return bookableItems.some(
                item =>
                    idsEqual(item.item_type_id, type.item_type_id) &&
                    pickupLocations.find(
                        loc =>
                            idsEqual(loc.library_id, pickupLibraryId) &&
                            loc.pickup_items &&
                            includesId(loc.pickup_items, item.item_id)
                    )
            );
        }
        return true;
    });
    return buildConstraintResult(filtered, itemTypes.length);
}

/**
 * Calculate constraint highlighting data for calendar display
 * @param {Date|import('dayjs').Dayjs} startDate - Selected start date
 * @param {Object} circulationRules - Circulation rules object
 * @param {Object} constraintOptions - Additional constraint options
 * @returns {import('../../types/bookings').ConstraintHighlighting | null} Constraint highlighting
 */
export function calculateConstraintHighlighting(
    startDate,
    circulationRules,
    constraintOptions = {}
) {
    const strategy = createConstraintStrategy(
        circulationRules?.booking_constraint_mode
    );
    const result = strategy.calculateConstraintHighlighting(
        startDate,
        circulationRules,
        constraintOptions
    );
    logger.debug("Constraint highlighting calculated", result);
    return result;
}

/**
 * Determine if calendar should navigate to show target end date
 * @param {Date|import('dayjs').Dayjs} startDate - Selected start date
 * @param {Date|import('dayjs').Dayjs} targetEndDate - Calculated target end date
 * @param {import('../../types/bookings').CalendarCurrentView} currentView - Current calendar view info
 * @returns {import('../../types/bookings').CalendarNavigationTarget}
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

    const start = toDayjs(startDate);
    const target = toDayjs(targetEndDate);

    // Never navigate backwards if target is before the chosen start
    if (target.isBefore(start, "day")) {
        logger.debug("Target end before start; skip navigation");
        return { shouldNavigate: false };
    }

    // If we know the currently visible range, do not navigate when target is already visible
    if (currentView.visibleStartDate && currentView.visibleEndDate) {
        const visibleStart = toDayjs(currentView.visibleStartDate).startOf(
            "day"
        );
        const visibleEnd = toDayjs(currentView.visibleEndDate).endOf("day");
        const inView = target.isBetween(
            visibleStart,
            visibleEnd,
            undefined,
            "[]"
        );
        if (inView) {
            logger.debug("Target end date already visible; no navigation");
            return { shouldNavigate: false };
        }
    }

    // Fallback: navigate when target month differs from start month
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
 * @returns {import('../../types/bookings').MarkerAggregation} Aggregated counts by type
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
