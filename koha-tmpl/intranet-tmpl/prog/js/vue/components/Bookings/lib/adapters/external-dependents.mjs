import dayjs from "../../../../utils/dayjs.mjs";
import { win } from "./globals.mjs";

/** @typedef {import('../../types/bookings').ExternalDependencies} ExternalDependencies */

// Re-export debounce from shared utils for backward compatibility
export { debounce } from "../../../../utils/functions.mjs";

/**
 * Default dependencies for external updates - can be overridden in tests
 * @type {ExternalDependencies}
 */
const defaultDependencies = {
    timeline: () => win("timeline"),
    bookingsTable: () => win("bookings_table"),
    patronRenderer: () => win("$patron_to_html"),
    domQuery: selector => document.querySelectorAll(selector),
    logger: {
        warn: (msg, data) => console.warn(msg, data),
        error: (msg, error) => console.error(msg, error),
    },
};

/**
 * Renders patron content for display, with injected dependency
 *
 * @param {{ cardnumber?: string }|null} bookingPatron
 * @param {ExternalDependencies} [dependencies=defaultDependencies]
 * @returns {string}
 */
function renderPatronContent(
    bookingPatron,
    dependencies = defaultDependencies
) {
    try {
        const patronRenderer = dependencies.patronRenderer();
        if (typeof patronRenderer === "function" && bookingPatron) {
            return patronRenderer(bookingPatron, {
                display_cardnumber: true,
                url: true,
            });
        }

        if (bookingPatron?.cardnumber) {
            return bookingPatron.cardnumber;
        }

        return "";
    } catch (error) {
        dependencies.logger.error("Failed to render patron content", {
            error,
            bookingPatron,
        });
        return bookingPatron?.cardnumber || "";
    }
}

/**
 * Updates timeline component with booking data
 *
 * @param {import('../../types/bookings').Booking} newBooking
 * @param {{ cardnumber?: string }|null} bookingPatron
 * @param {boolean} isUpdate
 * @param {ExternalDependencies} dependencies
 * @returns {{ success: boolean, reason?: string }}
 */
function updateTimelineComponent(
    newBooking,
    bookingPatron,
    isUpdate,
    dependencies
) {
    const timeline = dependencies.timeline();
    if (!timeline) return { success: false, reason: "Timeline not available" };

    try {
        const itemData = {
            id: newBooking.booking_id,
            booking: newBooking.booking_id,
            patron: newBooking.patron_id,
            start: dayjs(newBooking.start_date).toDate(),
            end: dayjs(newBooking.end_date).toDate(),
            content: renderPatronContent(bookingPatron, dependencies),
            type: "range",
            group: newBooking.item_id ? newBooking.item_id : 0,
        };

        if (isUpdate) {
            timeline.itemsData.update(itemData);
        } else {
            timeline.itemsData.add(itemData);
        }
        timeline.focus(newBooking.booking_id);

        return { success: true };
    } catch (error) {
        dependencies.logger.error("Failed to update timeline", {
            error,
            newBooking,
        });
        return { success: false, reason: error.message };
    }
}

/**
 * Updates bookings table component
 *
 * @param {ExternalDependencies} dependencies
 * @returns {{ success: boolean, reason?: string }}
 */
function updateBookingsTable(dependencies) {
    const bookingsTable = dependencies.bookingsTable();
    if (!bookingsTable)
        return { success: false, reason: "Bookings table not available" };

    try {
        bookingsTable.api().ajax.reload();
        return { success: true };
    } catch (error) {
        dependencies.logger.error("Failed to update bookings table", { error });
        return { success: false, reason: error.message };
    }
}

/**
 * Updates booking count elements in the DOM
 *
 * @param {boolean} isUpdate
 * @param {ExternalDependencies} dependencies
 * @returns {{ success: boolean, reason?: string, updatedElements?: number, totalElements?: number }}
 */
function updateBookingCounts(isUpdate, dependencies) {
    if (isUpdate)
        return { success: true, reason: "No count update needed for updates" };

    try {
        const countEls = dependencies.domQuery(".bookings_count");
        let updatedCount = 0;

        countEls.forEach(el => {
            const html = el.innerHTML;
            const match = html.match(/(\d+)/);
            if (match) {
                const newCount = parseInt(match[1], 10) + 1;
                el.innerHTML = html.replace(/(\d+)/, String(newCount));
                updatedCount++;
            }
        });

        return {
            success: true,
            updatedElements: updatedCount,
            totalElements: countEls.length,
        };
    } catch (error) {
        dependencies.logger.error("Failed to update booking counts", { error });
        return { success: false, reason: error.message };
    }
}

/**
 * Updates external components that depend on booking data
 *
 * This function is designed with dependency injection to make it testable
 * and to provide proper error handling with detailed feedback.
 *
 * @param {import('../../types/bookings').Booking} newBooking - The booking data that was created/updated
 * @param {{ cardnumber?: string }|null} bookingPatron - The patron data for rendering
 * @param {boolean} isUpdate - Whether this is an update (true) or create (false)
 * @param {ExternalDependencies} dependencies - Injectable dependencies (for testing)
 * @returns {Record<string, { attempted: boolean, success?: boolean, reason?: string }>} Results summary with success/failure details
 */
export function updateExternalDependents(
    newBooking,
    bookingPatron,
    isUpdate = false,
    dependencies = defaultDependencies
) {
    const results = {
        timeline: { attempted: false },
        bookingsTable: { attempted: false },
        bookingCounts: { attempted: false },
    };

    // Update timeline if available
    if (dependencies.timeline()) {
        results.timeline = {
            attempted: true,
            ...updateTimelineComponent(
                newBooking,
                bookingPatron,
                isUpdate,
                dependencies
            ),
        };
    }

    // Update bookings table if available
    if (dependencies.bookingsTable()) {
        results.bookingsTable = {
            attempted: true,
            ...updateBookingsTable(dependencies),
        };
    }

    // Update booking counts
    results.bookingCounts = {
        attempted: true,
        ...updateBookingCounts(isUpdate, dependencies),
    };

    // Log summary for debugging
    const successCount = Object.values(results).filter(
        r => r.attempted && r.success
    ).length;
    const attemptedCount = Object.values(results).filter(
        r => r.attempted
    ).length;

    dependencies.logger.warn(
        `External dependents update complete: ${successCount}/${attemptedCount} successful`,
        {
            isUpdate,
            bookingId: newBooking.booking_id,
            results,
        }
    );

    return results;
}
