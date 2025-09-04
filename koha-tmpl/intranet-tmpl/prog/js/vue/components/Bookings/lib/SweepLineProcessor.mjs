/**
 * SweepLineProcessor.js - Efficient sweep line algorithm for processing date ranges
 *
 * Processes all bookings/checkouts in a date range using a sweep line algorithm
 * to efficiently determine availability for each day in O(n log n) time
 */

import dayjs from "../../../utils/dayjs.mjs";
import { managerLogger as logger } from "./booking/logger.mjs";

/**
 * Event types for the sweep line algorithm
 * @readonly
 * @enum {string}
 */
const EventType = {
    /** Start of an interval */
    START: "start",
    /** End of an interval */
    END: "end",
};

/**
 * Represents an event in the sweep line algorithm (internal class)
 * @class SweepEvent
 * @private
 */
class SweepEvent {
    /**
     * Create a sweep event
     * @param {number} timestamp - Unix timestamp of the event
     * @param {'start'|'end'} type - Type of event
     * @param {any} interval - The interval associated with this event
     */
    constructor(timestamp, type, interval) {
        /** @type {number} Unix timestamp of the event */
        this.timestamp = timestamp;
        /** @type {'start'|'end'} Type of event */
        this.type = type; // 'start' or 'end'
        /** @type {any} The booking/checkout interval */
        this.interval = interval; // The booking/checkout interval
    }
}

/**
 * Sweep line processor for efficient date range queries
 * Uses sweep line algorithm to process intervals in O(n log n) time
 * @class SweepLineProcessor
 */
export class SweepLineProcessor {
    /**
     * Create a new sweep line processor
     */
    constructor() {
        /** @type {SweepEvent[]} Array of sweep events */
        this.events = [];
    }

    /**
     * Process intervals to generate unavailability data for a date range
     * @param {Array} intervals - All booking/checkout intervals
     * @param {Date|import("dayjs").Dayjs} viewStart - Start of the visible date range
     * @param {Date|import("dayjs").Dayjs} viewEnd - End of the visible date range
     * @param {Array<string>} allItemIds - All bookable item IDs
     * @returns {Object<string, Object<string, Set<string>>>} unavailableByDate map
     */
    processIntervals(intervals, viewStart, viewEnd, allItemIds) {
        logger.time("SweepLineProcessor.processIntervals");
        logger.debug("Processing intervals for date range", {
            intervalCount: intervals.length,
            viewStart: dayjs(viewStart).format("YYYY-MM-DD"),
            viewEnd: dayjs(viewEnd).format("YYYY-MM-DD"),
            itemCount: allItemIds.length,
        });

        const startTimestamp = dayjs(viewStart).startOf("day").valueOf();
        const endTimestamp = dayjs(viewEnd).endOf("day").valueOf();

        // Create events for intervals that overlap with the view range
        this.events = [];
        intervals.forEach(interval => {
            // Skip intervals completely outside the view range
            if (
                interval.end < startTimestamp ||
                interval.start > endTimestamp
            ) {
                return;
            }

            // Clamp interval to view range for starts
            const clampedStart = Math.max(interval.start, startTimestamp);
            // For ends, schedule removal at the START of the next day so the interval remains active for its end date
            const nextDayStart = dayjs(interval.end)
                .add(1, "day")
                .startOf("day")
                .valueOf();
            const endRemovalTs = Math.min(nextDayStart, endTimestamp + 1);

            this.events.push(new SweepEvent(clampedStart, "start", interval));
            this.events.push(new SweepEvent(endRemovalTs, "end", interval));
        });

        // Sort events by timestamp, with starts before ends at the same time
        this.events.sort((a, b) => {
            if (a.timestamp !== b.timestamp) {
                return a.timestamp - b.timestamp;
            }
            // At the same timestamp, process starts before ends
            return a.type === "start" ? -1 : 1;
        });

        logger.debug(`Created ${this.events.length} sweep events`);

        // Process events using sweep line
        /** @type {Record<string, Record<string, Set<string>>>} */
        const unavailableByDate = {};
        const activeIntervals = new Map(); // itemId -> Set of intervals

        // Initialize active intervals map
        allItemIds.forEach(itemId => {
            activeIntervals.set(itemId, new Set());
        });

        let currentDate = null;
        let eventIndex = 0;

        // Sweep through each day in the range
        for (
            let date = dayjs(viewStart).startOf("day");
            date.isSameOrBefore(viewEnd, "day");
            date = date.add(1, "day")
        ) {
            const dateKey = date.format("YYYY-MM-DD");
            const dateStart = date.valueOf();
            const dateEnd = date.endOf("day").valueOf();

            // Process all events up to the end of this day
            while (
                eventIndex < this.events.length &&
                this.events[eventIndex].timestamp <= dateEnd
            ) {
                const event = this.events[eventIndex];
                const itemId = event.interval.itemId;

                if (event.type === EventType.START) {
                    // Add interval to active set
                    if (!activeIntervals.has(itemId)) {
                        activeIntervals.set(itemId, new Set());
                    }
                    activeIntervals.get(itemId).add(event.interval);
                } else {
                    // Remove interval from active set
                    if (activeIntervals.has(itemId)) {
                        activeIntervals.get(itemId).delete(event.interval);
                    }
                }

                eventIndex++;
            }

            // Check which items are unavailable on this date
            unavailableByDate[dateKey] = {};

            activeIntervals.forEach((intervals, itemId) => {
                const reasons = new Set();

                intervals.forEach(interval => {
                    // Check if this interval actually covers this date
                    if (
                        interval.start <= dateEnd &&
                        interval.end >= dateStart
                    ) {
                        // Map interval types to reason strings (processor uses 'core' for bookings)
                        if (interval.type === "booking") {
                            reasons.add("core");
                        } else if (interval.type === "checkout") {
                            reasons.add("checkout");
                        } else {
                            reasons.add(interval.type); // 'lead' or 'trail'
                        }
                    }
                });

                if (reasons.size > 0) {
                    unavailableByDate[dateKey][itemId] = reasons;
                }
            });
        }

        logger.debug("Sweep line processing complete", {
            datesProcessed: Object.keys(unavailableByDate).length,
            totalUnavailable: Object.values(unavailableByDate).reduce(
                (sum, items) => sum + Object.keys(items).length,
                0
            ),
        });

        logger.timeEnd("SweepLineProcessor.processIntervals");

        return unavailableByDate;
    }

    /**
     * Process intervals and return aggregated statistics
     * @param {Array} intervals
     * @param {Date|import("dayjs").Dayjs} viewStart
     * @param {Date|import("dayjs").Dayjs} viewEnd
     * @returns {Object} Statistics about the date range
     */
    getDateRangeStatistics(intervals, viewStart, viewEnd) {
        logger.time("getDateRangeStatistics");

        const stats = {
            totalDays: 0,
            daysWithBookings: 0,
            daysWithCheckouts: 0,
            fullyBookedDays: 0,
            peakBookingCount: 0,
            peakDate: null,
            itemUtilization: new Map(),
        };

        const startDate = dayjs(viewStart).startOf("day");
        const endDate = dayjs(viewEnd).endOf("day");

        // Count days
        stats.totalDays = endDate.diff(startDate, "day") + 1;

        // Process each day
        for (
            let date = startDate;
            date.isSameOrBefore(endDate, "day");
            date = date.add(1, "day")
        ) {
            const dayStart = date.valueOf();
            const dayEnd = date.endOf("day").valueOf();

            let bookingCount = 0;
            let checkoutCount = 0;
            const itemsInUse = new Set();

            intervals.forEach(interval => {
                if (interval.start <= dayEnd && interval.end >= dayStart) {
                    if (interval.type === "booking") {
                        bookingCount++;
                        itemsInUse.add(interval.itemId);
                    } else if (interval.type === "checkout") {
                        checkoutCount++;
                        itemsInUse.add(interval.itemId);
                    }
                }
            });

            if (bookingCount > 0) stats.daysWithBookings++;
            if (checkoutCount > 0) stats.daysWithCheckouts++;

            const totalCount = bookingCount + checkoutCount;
            if (totalCount > stats.peakBookingCount) {
                stats.peakBookingCount = totalCount;
                stats.peakDate = date.format("YYYY-MM-DD");
            }

            // Update item utilization
            itemsInUse.forEach(itemId => {
                if (!stats.itemUtilization.has(itemId)) {
                    stats.itemUtilization.set(itemId, 0);
                }
                stats.itemUtilization.set(
                    itemId,
                    stats.itemUtilization.get(itemId) + 1
                );
            });
        }

        logger.info("Date range statistics calculated", stats);
        logger.timeEnd("getDateRangeStatistics");

        return stats;
    }

    /**
     * Find the next available date for a specific item
     * @param {Array} intervals
     * @param {string} itemId
     * @param {Date|dayjs} startDate
     * @param {number} maxDaysToSearch
     * @returns {Date|null}
     */
    findNextAvailableDate(intervals, itemId, startDate, maxDaysToSearch = 365) {
        logger.debug("Finding next available date", {
            itemId,
            startDate: dayjs(startDate).format("YYYY-MM-DD"),
        });

        const start = dayjs(startDate).startOf("day");
        const itemIntervals = intervals.filter(
            interval => interval.itemId === itemId
        );

        // Sort intervals by start date
        itemIntervals.sort((a, b) => a.start - b.start);

        for (let i = 0; i < maxDaysToSearch; i++) {
            const checkDate = start.add(i, "day");
            const dateStart = checkDate.valueOf();
            const dateEnd = checkDate.endOf("day").valueOf();

            const isAvailable = !itemIntervals.some(
                interval =>
                    interval.start <= dateEnd && interval.end >= dateStart
            );

            if (isAvailable) {
                logger.debug("Found available date", {
                    date: checkDate.format("YYYY-MM-DD"),
                    daysFromStart: i,
                });
                return checkDate.toDate();
            }
        }

        logger.warn("No available date found within search limit");
        return null;
    }

    /**
     * Find gaps (available periods) for an item
     * @param {Array} intervals
     * @param {string} itemId
     * @param {Date|dayjs} viewStart
     * @param {Date|dayjs} viewEnd
     * @param {number} minGapDays - Minimum gap size to report
     * @returns {Array<{start: Date, end: Date, days: number}>}
     */
    findAvailableGaps(intervals, itemId, viewStart, viewEnd, minGapDays = 1) {
        logger.debug("Finding available gaps", {
            itemId,
            viewStart: dayjs(viewStart).format("YYYY-MM-DD"),
            viewEnd: dayjs(viewEnd).format("YYYY-MM-DD"),
            minGapDays,
        });

        const gaps = [];
        const itemIntervals = intervals
            .filter(interval => interval.itemId === itemId)
            .sort((a, b) => a.start - b.start);

        const rangeStart = dayjs(viewStart).startOf("day").valueOf();
        const rangeEnd = dayjs(viewEnd).endOf("day").valueOf();

        let lastEnd = rangeStart;

        itemIntervals.forEach(interval => {
            // Skip intervals outside our range
            if (interval.end < rangeStart || interval.start > rangeEnd) {
                return;
            }

            const gapStart = Math.max(lastEnd, rangeStart);
            const gapEnd = Math.min(interval.start, rangeEnd);

            if (gapEnd > gapStart) {
                const gapDays = dayjs(gapEnd).diff(dayjs(gapStart), "day");
                if (gapDays >= minGapDays) {
                    gaps.push({
                        start: new Date(gapStart),
                        end: new Date(gapEnd - 1), // End of previous day
                        days: gapDays,
                    });
                }
            }

            lastEnd = Math.max(lastEnd, interval.end + 1); // Start of next day
        });

        // Check for gap after last interval
        if (lastEnd < rangeEnd) {
            const gapDays = dayjs(rangeEnd).diff(dayjs(lastEnd), "day");
            if (gapDays >= minGapDays) {
                gaps.push({
                    start: new Date(lastEnd),
                    end: new Date(rangeEnd),
                    days: gapDays,
                });
            }
        }

        logger.debug(`Found ${gaps.length} available gaps`);
        return gaps;
    }
}

/**
 * Create and process unavailability data using sweep line algorithm
 * @param {any} intervalTree - The interval tree containing all bookings/checkouts
 * @param {Date|import("dayjs").Dayjs} viewStart - Start of the calendar view date range
 * @param {Date|import("dayjs").Dayjs} viewEnd - End of the calendar view date range
 * @param {Array<string>} allItemIds - All bookable item IDs
 * @returns {Object<string, Object<string, Set<string>>>} unavailableByDate map
 */
export function processCalendarView(
    intervalTree,
    viewStart,
    viewEnd,
    allItemIds
) {
    logger.time("processCalendarView");

    // Extract all intervals from the tree that might affect the view
    const relevantIntervals = intervalTree.queryRange(viewStart, viewEnd);

    // Use sweep line processor
    const processor = new SweepLineProcessor();
    const unavailableByDate = processor.processIntervals(
        relevantIntervals,
        viewStart,
        viewEnd,
        allItemIds
    );

    logger.timeEnd("processCalendarView");
    return unavailableByDate;
}
