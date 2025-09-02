import dayjs from "../../../../utils/dayjs.mjs";

export function debounce(fn, delay) {
    let timeout;
    return function (...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => fn.apply(this, args), delay);
    };
}

/**
 * Default dependencies for external updates - can be overridden in tests
 */
import { win } from "../index.mjs";

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
                el.innerHTML = html.replace(/(\d+)/, newCount);
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
 * @param {Object} newBooking - The booking data that was created/updated
 * @param {Object|null} bookingPatron - The patron data for rendering
 * @param {boolean} isUpdate - Whether this is an update (true) or create (false)
 * @param {Object} dependencies - Injectable dependencies (for testing)
 * @returns {Object} Results summary with success/failure details
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

/**
 * Legacy wrapper for backward compatibility
 * @deprecated Use updateExternalDependents with proper error handling
 */
// Note: Legacy wrapper removed. Use updateExternalDependents(newBooking, bookingPatron, isUpdate).
