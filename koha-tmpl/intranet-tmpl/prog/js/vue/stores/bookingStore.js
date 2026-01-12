// bookingStore.js
// Pinia store for booking modal state management

import { defineStore } from "pinia";
import { processApiError } from "../utils/apiErrors.js";
import * as bookingApi from "@bookingApi";
import {
    transformPatronData,
    transformPatronsData,
} from "../components/Bookings/lib/adapters/patron.mjs";
import {
    formatYMD,
    addMonths,
    addDays,
    compareDates,
} from "../components/Bookings/lib/booking/date-utils.mjs";

/**
 * Higher-order function to standardize async operation error handling
 * Eliminates repetitive try-catch-finally patterns
 */
function withErrorHandling(operation, loadingKey, errorKey = null) {
    return async function (...args) {
        // Use errorKey if provided, otherwise derive from loadingKey
        const errorField = errorKey || loadingKey;

        this.loading[loadingKey] = true;
        this.error[errorField] = null;

        try {
            const result = await operation.call(this, ...args);
            return result;
        } catch (error) {
            this.error[errorField] = processApiError(error);
            // Re-throw to allow caller to handle if needed
            throw error;
        } finally {
            this.loading[loadingKey] = false;
        }
    };
}

/**
 * State shape with improved organization and consistency
 * Maintains backward compatibility with existing API
 */

export const useBookingStore = defineStore("bookingStore", {
    state: () => ({
        // System state
        dataFetched: false,

        // Collections - consistent naming and organization
        bookableItems: [],
        bookings: [],
        checkouts: [],
        pickupLocations: [],
        itemTypes: [],
        circulationRules: [],
        circulationRulesContext: null, // Track the context used for the last rules fetch
        unavailableByDate: {},
        holidays: [], // Closed days for the selected pickup library
        holidaysFetchedRange: { from: null, to: null, libraryId: null }, // Track fetched range to enable on-demand extension

        // Current booking state - normalized property names
        bookingId: null,
        bookingItemId: null, // kept for backward compatibility
        bookingPatron: null,
        bookingItemtypeId: null, // kept for backward compatibility
        patronId: null,
        pickupLibraryId: null,
        /**
         * Canonical date representation for the bookings UI.
         * Always store ISO 8601 strings here (e.g., "2025-03-14T00:00:00.000Z").
         * - Widgets (Flatpickr) work with Date objects and must convert to ISO when writing
         * - Computation utilities convert ISO -> Date close to the boundary
         * - API payloads use ISO strings as-is
         */
        selectedDateRange: [],

        // Async operation state - organized structure
        loading: {
            bookableItems: false,
            bookings: false,
            checkouts: false,
            patrons: false,
            bookingPatron: false,
            pickupLocations: false,
            circulationRules: false,
            holidays: false,
            submit: false,
        },
        error: {
            bookableItems: null,
            bookings: null,
            checkouts: null,
            patrons: null,
            bookingPatron: null,
            pickupLocations: null,
            circulationRules: null,
            holidays: null,
            submit: null,
        },
    }),

    actions: {
        /**
         * Invalidate backend-calculated due values to avoid stale UI when inputs change.
         * Keeps the rules object shape but removes calculated fields so consumers
         * fall back to maxPeriod-based logic until fresh rules arrive.
         */
        invalidateCalculatedDue() {
            if (Array.isArray(this.circulationRules) && this.circulationRules.length > 0) {
                const first = { ...this.circulationRules[0] };
                if ("calculated_due_date" in first) delete first.calculated_due_date;
                if ("calculated_period_days" in first) delete first.calculated_period_days;
                this.circulationRules = [first];
            }
        },
        resetErrors() {
            Object.keys(this.error).forEach(key => {
                this.error[key] = null;
            });
        },
        setUnavailableByDate(unavailableByDate) {
            this.unavailableByDate = unavailableByDate;
        },
        /**
         * Fetch bookable items for a biblionumber
         */
        fetchBookableItems: withErrorHandling(async function (biblionumber) {
            const data = await bookingApi.fetchBookableItems(biblionumber);
            this.bookableItems = data;
            return data;
        }, "bookableItems"),
        /**
         * Fetch bookings for a biblionumber
         */
        fetchBookings: withErrorHandling(async function (biblionumber) {
            const data = await bookingApi.fetchBookings(biblionumber);
            this.bookings = data;
            return data;
        }, "bookings"),
        /**
         * Fetch checkouts for a biblionumber
         */
        fetchCheckouts: withErrorHandling(async function (biblionumber) {
            const data = await bookingApi.fetchCheckouts(biblionumber);
            this.checkouts = data;
            return data;
        }, "checkouts"),
        /**
         * Fetch patrons by search term and page
         */
        fetchPatron: withErrorHandling(async function (patronId) {
            const data = await bookingApi.fetchPatron(patronId);
            return transformPatronData(Array.isArray(data) ? data[0] : data);
        }, "bookingPatron"),
        /**
         * Fetch patrons by search term and page
         */
        fetchPatrons: withErrorHandling(async function (term, page = 1) {
            const data = await bookingApi.fetchPatrons(term, page);
            return transformPatronsData(data);
        }, "patrons"),
        /**
         * Fetch pickup locations for a biblionumber (optionally filtered by patron)
         */
        fetchPickupLocations: withErrorHandling(async function (
            biblionumber,
            patron_id
        ) {
            const data = await bookingApi.fetchPickupLocations(
                biblionumber,
                patron_id
            );
            this.pickupLocations = data;
            return data;
        },
        "pickupLocations"),
        /**
         * Fetch circulation rules for given context
         */
        fetchCirculationRules: withErrorHandling(async function (params) {
            // Only include defined (non-null, non-undefined) params
            const filteredParams = {};
            for (const key in params) {
                if (
                    params[key] !== null &&
                    params[key] !== undefined &&
                    params[key] !== ""
                ) {
                    filteredParams[key] = params[key];
                }
            }
            const data = await bookingApi.fetchCirculationRules(filteredParams);
            this.circulationRules = data;
            // Store the context we requested so we know what specificity we have
            this.circulationRulesContext = {
                patron_category_id: filteredParams.patron_category_id ?? null,
                item_type_id: filteredParams.item_type_id ?? null,
                library_id: filteredParams.library_id ?? null,
            };
            return data;
        }, "circulationRules"),
        /**
         * Fetch holidays (closed days) for a library.
         * Tracks fetched range and accumulates holidays to support on-demand extension.
         * @param {string} libraryId - The library branchcode
         * @param {string} [from] - Start date (ISO format), defaults to today
         * @param {string} [to] - End date (ISO format), defaults to 1 year from start
         */
        fetchHolidays: withErrorHandling(async function (libraryId, from, to) {
            if (!libraryId) {
                this.holidays = [];
                this.holidaysFetchedRange = { from: null, to: null, libraryId: null };
                return [];
            }

            // If library changed, reset and fetch fresh
            if (this.holidaysFetchedRange.libraryId !== libraryId) {
                this.holidays = [];
                this.holidaysFetchedRange = { from: null, to: null, libraryId: null };
            }

            const data = await bookingApi.fetchHolidays(libraryId, from, to);

            // Accumulate holidays using Set to avoid duplicates
            const existingSet = new Set(this.holidays);
            data.forEach(date => existingSet.add(date));
            this.holidays = Array.from(existingSet).sort();

            // Update fetched range (expand to cover new range)
            const currentFrom = this.holidaysFetchedRange.from;
            const currentTo = this.holidaysFetchedRange.to;
            this.holidaysFetchedRange = {
                libraryId,
                from: !currentFrom || compareDates(from, currentFrom) < 0 ? from : currentFrom,
                to: !currentTo || compareDates(to, currentTo) > 0 ? to : currentTo,
            };

            return data;
        }, "holidays"),
        /**
         * Extend holidays range if the visible calendar range exceeds fetched data.
         * Also prefetches upcoming months when approaching the edge of fetched data.
         * @param {string} libraryId - The library branchcode
         * @param {Date} visibleStart - Start of visible calendar range
         * @param {Date} visibleEnd - End of visible calendar range
         */
        async extendHolidaysIfNeeded(libraryId, visibleStart, visibleEnd) {
            if (!libraryId) return;

            const visibleFrom = formatYMD(visibleStart);
            const visibleTo = formatYMD(visibleEnd);

            const { from: fetchedFrom, to: fetchedTo, libraryId: fetchedLib } = this.holidaysFetchedRange;

            // If different library or no data yet, fetch visible range + prefetch buffer
            if (fetchedLib !== libraryId || !fetchedFrom || !fetchedTo) {
                const prefetchEnd = formatYMD(addMonths(visibleEnd, 6));
                await this.fetchHolidays(libraryId, visibleFrom, prefetchEnd);
                return;
            }

            // Check if we need to extend for current view (using proper date comparison)
            const needsExtensionBefore = compareDates(visibleFrom, fetchedFrom) < 0;
            const needsExtensionAfter = compareDates(visibleTo, fetchedTo) > 0;

            if (needsExtensionBefore) {
                const prefetchStart = formatYMD(addMonths(visibleStart, -3));
                // End at day before fetchedFrom to avoid overlap
                const extensionEnd = formatYMD(addDays(fetchedFrom, -1));
                await this.fetchHolidays(libraryId, prefetchStart, extensionEnd);
            }
            if (needsExtensionAfter) {
                // Start at day after fetchedTo to avoid overlap
                const extensionStart = formatYMD(addDays(fetchedTo, 1));
                const prefetchEnd = formatYMD(addMonths(visibleEnd, 6));
                await this.fetchHolidays(libraryId, extensionStart, prefetchEnd);
            }

            // Prefetch ahead if approaching the edge (within 60 days)
            const PREFETCH_THRESHOLD_DAYS = 60;
            const PREFETCH_MONTHS = 6;

            if (!needsExtensionAfter && fetchedTo) {
                const daysToEdge = addDays(fetchedTo, 0).diff(visibleEnd, "day");
                if (daysToEdge < PREFETCH_THRESHOLD_DAYS) {
                    // Start at day after fetchedTo to avoid overlap
                    const extensionStart = formatYMD(addDays(fetchedTo, 1));
                    const prefetchEnd = formatYMD(addMonths(fetchedTo, PREFETCH_MONTHS));
                    // Fire and forget - don't await to avoid blocking
                    this.fetchHolidays(libraryId, extensionStart, prefetchEnd);
                }
            }

            if (!needsExtensionBefore && fetchedFrom) {
                const daysToEdge = addDays(visibleStart, 0).diff(fetchedFrom, "day");
                if (daysToEdge < PREFETCH_THRESHOLD_DAYS) {
                    const prefetchStart = formatYMD(addMonths(fetchedFrom, -PREFETCH_MONTHS));
                    // End at day before fetchedFrom to avoid overlap
                    const extensionEnd = formatYMD(addDays(fetchedFrom, -1));
                    // Fire and forget - don't await to avoid blocking
                    this.fetchHolidays(libraryId, prefetchStart, extensionEnd);
                }
            }
        },
        /**
         * Derive item types from bookableItems
         */
        deriveItemTypesFromBookableItems() {
            const typesMap = {};
            this.bookableItems.forEach(item => {
                // Use effective_item_type_id if present, fallback to item_type_id
                const typeId = item.effective_item_type_id || item.item_type_id;
                if (typeId) {
                    // Use the human-readable string if available
                    const label = item._strings?.item_type_id?.str ?? typeId;
                    typesMap[typeId] = label;
                }
            });
            this.itemTypes = Object.entries(typesMap).map(
                ([item_type_id, description]) => ({
                    item_type_id,
                    description,
                })
            );
        },
        /**
         * Save (POST) or update (PUT) a booking
         * If bookingId is present, update; else, create
         */
        saveOrUpdateBooking: withErrorHandling(async function (bookingData) {
            let result;
            if (bookingData.bookingId || bookingData.booking_id) {
                // Use bookingId from either field
                const id = bookingData.bookingId || bookingData.booking_id;
                result = await bookingApi.updateBooking(id, bookingData);
                // Update in store
                const idx = this.bookings.findIndex(
                    b => b.booking_id === result.booking_id
                );
                if (idx !== -1) this.bookings[idx] = result;
            } else {
                result = await bookingApi.createBooking(bookingData);
                this.bookings.push(result);
            }
            return result;
        }, "submit"),
    },
});
