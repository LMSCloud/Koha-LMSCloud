/**
 * IntervalTree.js - Efficient interval tree data structure for booking date queries
 *
 * Provides O(log n) query performance for finding overlapping bookings/checkouts
 * Based on augmented red-black tree with interval overlap detection
 */

import dayjs from "../../../../../utils/dayjs.mjs"
import { managerLogger as logger } from "../logger.mjs";

/**
 * Represents a booking or checkout interval
 * @class BookingInterval
 */
export class BookingInterval {
    /**
     * Create a booking interval
     * @param {string|Date|import("dayjs").Dayjs} startDate - Start date of the interval
     * @param {string|Date|import("dayjs").Dayjs} endDate - End date of the interval
     * @param {string|number} itemId - Item ID (will be converted to string)
     * @param {'booking'|'checkout'|'lead'|'trail'|'query'} type - Type of interval
     * @param {Object} metadata - Additional metadata (booking_id, patron_id, etc.)
     * @param {number} [metadata.booking_id] - Booking ID for bookings
     * @param {number} [metadata.patron_id] - Patron ID
     * @param {number} [metadata.checkout_id] - Checkout ID for checkouts
     * @param {number} [metadata.days] - Number of lead/trail days
     */
    constructor(startDate, endDate, itemId, type, metadata = {}) {
        /** @type {number} Unix timestamp for start date */
        this.start = dayjs(startDate).valueOf(); // Convert to timestamp for fast comparison
        /** @type {number} Unix timestamp for end date */
        this.end = dayjs(endDate).valueOf();
        /** @type {string} Item ID as string for consistent comparison */
        this.itemId = String(itemId); // Ensure string for consistent comparison
        /** @type {'booking'|'checkout'|'lead'|'trail'|'query'} Type of interval */
        this.type = type; // 'booking', 'checkout', 'lead', 'trail'
        /** @type {Object} Additional metadata */
        this.metadata = metadata; // booking_id, patron info, etc.

        // Validate interval
        if (this.start > this.end) {
            throw new Error(
                `Invalid interval: start (${startDate}) is after end (${endDate})`
            );
        }
    }

    /**
     * Check if this interval contains a specific date
     * @param {number|Date|import("dayjs").Dayjs} date - Date to check (timestamp, Date object, or dayjs instance)
     * @returns {boolean} True if the date is within this interval (inclusive)
     */
    containsDate(date) {
        const timestamp =
            typeof date === "number" ? date : dayjs(date).valueOf();
        return timestamp >= this.start && timestamp <= this.end;
    }

    /**
     * Check if this interval overlaps with another interval
     * @param {BookingInterval} other - The other interval to check for overlap
     * @returns {boolean} True if the intervals overlap
     */
    overlaps(other) {
        return this.start <= other.end && other.start <= this.end;
    }

    /**
     * Get a string representation for debugging
     * @returns {string} Human-readable string representation
     */
    toString() {
        const startStr = dayjs(this.start).format("YYYY-MM-DD");
        const endStr = dayjs(this.end).format("YYYY-MM-DD");
        return `${this.type}[${startStr} to ${endStr}] item:${this.itemId}`;
    }
}

/**
 * Node in the interval tree (internal class)
 * @class IntervalTreeNode
 * @private
 */
class IntervalTreeNode {
    /**
     * Create an interval tree node
     * @param {BookingInterval} interval - The interval stored in this node
     */
    constructor(interval) {
        /** @type {BookingInterval} The interval stored in this node */
        this.interval = interval;
        /** @type {number} Maximum end value in this subtree (for efficient queries) */
        this.max = interval.end; // Max end value in this subtree
        /** @type {IntervalTreeNode|null} Left child node */
        this.left = null;
        /** @type {IntervalTreeNode|null} Right child node */
        this.right = null;
        /** @type {number} Height of this node for AVL balancing */
        this.height = 1;
    }

    /**
     * Update the max value based on children (internal method)
     */
    updateMax() {
        this.max = this.interval.end;
        if (this.left && this.left.max > this.max) {
            this.max = this.left.max;
        }
        if (this.right && this.right.max > this.max) {
            this.max = this.right.max;
        }
    }
}

/**
 * Interval tree implementation with AVL balancing
 * Provides efficient O(log n) queries for interval overlaps
 * @class IntervalTree
 */
export class IntervalTree {
    /**
     * Create a new interval tree
     */
    constructor() {
        /** @type {IntervalTreeNode|null} Root node of the tree */
        this.root = null;
        /** @type {number} Number of intervals in the tree */
        this.size = 0;
    }

    /**
     * Get the height of a node (internal method)
     * @param {IntervalTreeNode|null} node - The node to get height for
     * @returns {number} Height of the node (0 for null nodes)
     * @private
     */
    _getHeight(node) {
        return node ? node.height : 0;
    }

    /**
     * Get the balance factor of a node (internal method)
     * @param {IntervalTreeNode|null} node - The node to get balance factor for
     * @returns {number} Balance factor (left height - right height)
     * @private
     */
    _getBalance(node) {
        return node
            ? this._getHeight(node.left) - this._getHeight(node.right)
            : 0;
    }

    /**
     * Update node height based on children
     * @param {IntervalTreeNode} node
     */
    _updateHeight(node) {
        if (node) {
            node.height =
                1 +
                Math.max(
                    this._getHeight(node.left),
                    this._getHeight(node.right)
                );
        }
    }

    /**
     * Rotate right (for balancing)
     * @param {IntervalTreeNode} y
     * @returns {IntervalTreeNode}
     */
    _rotateRight(y) {
        if (!y || !y.left) {
            logger.error("Invalid rotation: y or y.left is null", {
                y: y?.interval?.toString(),
            });
            return y;
        }

        const x = y.left;
        const T2 = x.right;

        x.right = y;
        y.left = T2;

        this._updateHeight(y);
        this._updateHeight(x);

        // Update max values after rotation
        y.updateMax();
        x.updateMax();

        return x;
    }

    /**
     * Rotate left (for balancing)
     * @param {IntervalTreeNode} x
     * @returns {IntervalTreeNode}
     */
    _rotateLeft(x) {
        if (!x || !x.right) {
            logger.error("Invalid rotation: x or x.right is null", {
                x: x?.interval?.toString(),
            });
            return x;
        }

        const y = x.right;
        const T2 = y.left;

        y.left = x;
        x.right = T2;

        this._updateHeight(x);
        this._updateHeight(y);

        // Update max values after rotation
        x.updateMax();
        y.updateMax();

        return y;
    }

    /**
     * Insert an interval into the tree
     * @param {BookingInterval} interval - The interval to insert
     * @throws {Error} If the interval is invalid
     */
    insert(interval) {
        logger.debug(`Inserting interval: ${interval.toString()}`);
        this.root = this._insertNode(this.root, interval);
        this.size++;
    }

    /**
     * Recursive helper for insertion with balancing
     * @param {IntervalTreeNode} node
     * @param {BookingInterval} interval
     * @returns {IntervalTreeNode}
     */
    _insertNode(node, interval) {
        // Standard BST insertion based on start time
        if (!node) {
            return new IntervalTreeNode(interval);
        }

        if (interval.start < node.interval.start) {
            node.left = this._insertNode(node.left, interval);
        } else {
            node.right = this._insertNode(node.right, interval);
        }

        // Update height and max
        this._updateHeight(node);
        node.updateMax();

        // Balance the tree
        const balance = this._getBalance(node);

        // Left heavy
        if (balance > 1) {
            if (interval.start < node.left.interval.start) {
                return this._rotateRight(node);
            } else {
                node.left = this._rotateLeft(node.left);
                return this._rotateRight(node);
            }
        }

        // Right heavy
        if (balance < -1) {
            if (interval.start > node.right.interval.start) {
                return this._rotateLeft(node);
            } else {
                node.right = this._rotateRight(node.right);
                return this._rotateLeft(node);
            }
        }

        return node;
    }

    /**
     * Query all intervals that contain a specific date
     * @param {Date|import("dayjs").Dayjs|number} date - The date to query (Date object, dayjs instance, or timestamp)
     * @param {string|null} [itemId=null] - Optional: filter by item ID (null for all items)
     * @returns {BookingInterval[]} Array of intervals that contain the date
     */
    query(date, itemId = null) {
        const timestamp =
            typeof date === "number" ? date : dayjs(date).valueOf();
        logger.debug(
            `Querying intervals containing date: ${dayjs(timestamp).format(
                "YYYY-MM-DD"
            )}`,
            { itemId }
        );

        const results = [];
        this._queryNode(this.root, timestamp, results, itemId);

        logger.debug(`Found ${results.length} intervals`);
        return results;
    }

    /**
     * Recursive helper for point queries
     * @param {IntervalTreeNode} node
     * @param {number} timestamp
     * @param {BookingInterval[]} results
     * @param {string} itemId
     */
    _queryNode(node, timestamp, results, itemId) {
        if (!node) return;

        // Check if current interval contains the timestamp
        if (node.interval.containsDate(timestamp)) {
            if (!itemId || node.interval.itemId === itemId) {
                results.push(node.interval);
            }
        }

        // Recurse left if possible
        if (node.left && node.left.max >= timestamp) {
            this._queryNode(node.left, timestamp, results, itemId);
        }

        // Recurse right if possible
        if (node.right && node.interval.start <= timestamp) {
            this._queryNode(node.right, timestamp, results, itemId);
        }
    }

    /**
     * Query all intervals that overlap with a date range
     * @param {Date|import("dayjs").Dayjs|number} startDate - Start of the range to query
     * @param {Date|import("dayjs").Dayjs|number} endDate - End of the range to query
     * @param {string|null} [itemId=null] - Optional: filter by item ID (null for all items)
     * @returns {BookingInterval[]} Array of intervals that overlap with the range
     */
    queryRange(startDate, endDate, itemId = null) {
        const startTimestamp =
            typeof startDate === "number"
                ? startDate
                : dayjs(startDate).valueOf();
        const endTimestamp =
            typeof endDate === "number" ? endDate : dayjs(endDate).valueOf();

        logger.debug(
            `Querying intervals in range: ${dayjs(startTimestamp).format(
                "YYYY-MM-DD"
            )} to ${dayjs(endTimestamp).format("YYYY-MM-DD")}`,
            { itemId }
        );

        const queryInterval = new BookingInterval(
            new Date(startTimestamp),
            new Date(endTimestamp),
            "",
            "query"
        );
        const results = [];
        this._queryRangeNode(this.root, queryInterval, results, itemId);

        logger.debug(`Found ${results.length} overlapping intervals`);
        return results;
    }

    /**
     * Recursive helper for range queries
     * @param {IntervalTreeNode} node
     * @param {BookingInterval} queryInterval
     * @param {BookingInterval[]} results
     * @param {string} itemId
     */
    _queryRangeNode(node, queryInterval, results, itemId) {
        if (!node) return;

        // Check if current interval overlaps with query
        if (node.interval.overlaps(queryInterval)) {
            if (!itemId || node.interval.itemId === itemId) {
                results.push(node.interval);
            }
        }

        // Recurse left if possible
        if (node.left && node.left.max >= queryInterval.start) {
            this._queryRangeNode(node.left, queryInterval, results, itemId);
        }

        // Recurse right if possible
        if (node.right && node.interval.start <= queryInterval.end) {
            this._queryRangeNode(node.right, queryInterval, results, itemId);
        }
    }

    /**
     * Remove all intervals matching a predicate
     * @param {Function} predicate - Function that returns true for intervals to remove
     * @returns {number} Number of intervals removed
     */
    removeWhere(predicate) {
        const toRemove = [];
        this._collectNodes(this.root, node => {
            if (predicate(node.interval)) {
                toRemove.push(node.interval);
            }
        });

        toRemove.forEach(interval => {
            this.root = this._removeNode(this.root, interval);
            this.size--;
        });

        logger.debug(`Removed ${toRemove.length} intervals`);
        return toRemove.length;
    }

    /**
     * Helper to collect all nodes
     * @param {IntervalTreeNode} node
     * @param {Function} callback
     */
    _collectNodes(node, callback) {
        if (!node) return;
        this._collectNodes(node.left, callback);
        callback(node);
        this._collectNodes(node.right, callback);
    }

    /**
     * Remove a specific interval (simplified - doesn't rebalance)
     * @param {IntervalTreeNode} node
     * @param {BookingInterval} interval
     * @returns {IntervalTreeNode}
     */
    _removeNode(node, interval) {
        if (!node) return null;

        if (interval.start < node.interval.start) {
            node.left = this._removeNode(node.left, interval);
        } else if (interval.start > node.interval.start) {
            node.right = this._removeNode(node.right, interval);
        } else if (
            interval.end === node.interval.end &&
            interval.itemId === node.interval.itemId &&
            interval.type === node.interval.type
        ) {
            // Found the node to remove
            if (!node.left) return node.right;
            if (!node.right) return node.left;

            // Node has two children - get inorder successor
            let minNode = node.right;
            while (minNode.left) {
                minNode = minNode.left;
            }

            node.interval = minNode.interval;
            node.right = this._removeNode(node.right, minNode.interval);
        } else {
            // Continue searching
            node.right = this._removeNode(node.right, interval);
        }

        if (node) {
            this._updateHeight(node);
            node.updateMax();
        }

        return node;
    }

    /**
     * Clear all intervals
     */
    clear() {
        this.root = null;
        this.size = 0;
        logger.debug("Interval tree cleared");
    }

    /**
     * Get statistics about the tree for debugging and monitoring
     * @returns {Object} Statistics object
     */
    getStats() {
        const stats = {
            size: this.size,
            height: this._getHeight(this.root),
            balanced: Math.abs(this._getBalance(this.root)) <= 1,
        };

        logger.debug("Interval tree stats:", stats);
        return stats;
    }
}

/**
 * Build an interval tree from bookings and checkouts data
 * @param {Array<Object>} bookings - Array of booking objects
 * @param {Array<Object>} checkouts - Array of checkout objects
 * @param {Object} circulationRules - Circulation rules configuration
 * @returns {IntervalTree} Populated interval tree ready for queries
 */
export function buildIntervalTree(bookings, checkouts, circulationRules) {
    logger.time("buildIntervalTree");
    logger.info("Building interval tree", {
        bookingsCount: bookings.length,
        checkoutsCount: checkouts.length,
    });

    const tree = new IntervalTree();

    // Add booking intervals with lead/trail times
    bookings.forEach(booking => {
        try {
            // Skip invalid bookings
            if (!booking.item_id || !booking.start_date || !booking.end_date) {
                logger.warn("Skipping invalid booking", { booking });
                return;
            }

            // Core booking interval
            const bookingInterval = new BookingInterval(
                booking.start_date,
                booking.end_date,
                booking.item_id,
                "booking",
                { booking_id: booking.booking_id, patron_id: booking.patron_id }
            );
            tree.insert(bookingInterval);

            // Lead time interval
            const leadDays = circulationRules?.bookings_lead_period || 0;
            if (leadDays > 0) {
                const leadStart = dayjs(booking.start_date).subtract(
                    leadDays,
                    "day"
                );
                const leadEnd = dayjs(booking.start_date).subtract(1, "day");
                const leadInterval = new BookingInterval(
                    leadStart,
                    leadEnd,
                    booking.item_id,
                    "lead",
                    { booking_id: booking.booking_id, days: leadDays }
                );
                tree.insert(leadInterval);
            }

            // Trail time interval
            const trailDays = circulationRules?.bookings_trail_period || 0;
            if (trailDays > 0) {
                const trailStart = dayjs(booking.end_date).add(1, "day");
                const trailEnd = dayjs(booking.end_date).add(trailDays, "day");
                const trailInterval = new BookingInterval(
                    trailStart,
                    trailEnd,
                    booking.item_id,
                    "trail",
                    { booking_id: booking.booking_id, days: trailDays }
                );
                tree.insert(trailInterval);
            }
        } catch (error) {
            logger.error("Failed to insert booking interval", {
                booking,
                error,
            });
        }
    });

    // Add checkout intervals
    checkouts.forEach(checkout => {
        try {
            if (
                checkout.item_id &&
                checkout.checkout_date &&
                checkout.due_date
            ) {
                const checkoutInterval = new BookingInterval(
                    checkout.checkout_date,
                    checkout.due_date,
                    checkout.item_id,
                    "checkout",
                    {
                        checkout_id: checkout.issue_id,
                        patron_id: checkout.patron_id,
                    }
                );
                tree.insert(checkoutInterval);
            }
        } catch (error) {
            logger.error("Failed to insert checkout interval", {
                checkout,
                error,
            });
        }
    });

    const stats = tree.getStats();
    logger.info("Interval tree built", stats);
    logger.timeEnd("buildIntervalTree");

    return tree;
}
