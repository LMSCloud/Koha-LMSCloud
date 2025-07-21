// bookingStore.js
// Pinia store for booking modal state management

import { defineStore } from "pinia";
import * as bookingApi from "@bookingApi";
import { transformPatronData, transformPatronsData } from "./patronUtils";

/**
 * State shape is derived from legacy global variables and async data:
 * - bookable_items, bookings, checkouts, booking_id, booking_item_id, booking_patron, booking_itemtype_id
 * - loading flags, error messages, etc.
 */

export const useBookingStore = defineStore("bookingStore", {
    state: () => ({
        dataFetched: false,
        bookableItems: [],
        bookings: [],
        checkouts: [],
        bookingId: null,
        bookingItemId: null,
        bookingPatron: null,
        bookingItemtypeId: null,
        patronId: null,
        pickupLibraryId: null,
        startDate: null,
        endDate: null,
        itemTypeId: null,
        loading: {
            items: false,
            bookings: false,
            checkouts: false,
            patrons: false,
            pickupLocations: false,
            circulationRules: false,
            submit: false,
        },
        error: {
            items: null,
            bookings: null,
            checkouts: null,
            patrons: null,
            pickupLocations: null,
            circulationRules: null,
            submit: null,
        },
        pickupLocations: [],
        itemTypes: [],
        circulationRules: {},
        unavailableByDate: {},
        // Add more as needed
    }),

    actions: {
        setUnavailableByDate(unavailableByDate) {
            this.unavailableByDate = unavailableByDate;
        },
        /**
         * Fetch bookable items for a biblionumber
         */
        async fetchBookableItems(biblionumber) {
            this.loading.items = true;
            this.error.items = null;
            try {
                const data = await bookingApi.fetchBookableItems(biblionumber);
                this.bookableItems = data;
            } catch (e) {
                this.error.items =
                    e.message || "Failed to fetch bookable items.";
            } finally {
                this.loading.items = false;
            }
        },
        /**
         * Fetch bookings for a biblionumber
         */
        async fetchBookings(biblionumber) {
            this.loading.bookings = true;
            this.error.bookings = null;
            try {
                const data = await bookingApi.fetchBookings(biblionumber);
                this.bookings = data;
            } catch (e) {
                this.error.bookings = e.message || "Failed to fetch bookings.";
            } finally {
                this.loading.bookings = false;
            }
        },
        /**
         * Fetch checkouts for a biblionumber
         */
        async fetchCheckouts(biblionumber) {
            this.loading.checkouts = true;
            this.error.checkouts = null;
            try {
                const data = await bookingApi.fetchCheckouts(biblionumber);
                this.checkouts = data;
            } catch (e) {
                this.error.checkouts =
                    e.message || "Failed to fetch checkouts.";
            } finally {
                this.loading.checkouts = false;
            }
        },
        /**
         * Fetch patrons by search term and page
         */
        async fetchPatron(patronId) {
            this.loading.bookingPatron = true;
            this.error.bookingPatron = null;
            try {
                const data = await bookingApi.fetchPatron(patronId);
                return transformPatronData(
                    Array.isArray(data) ? data[0] : data
                );
            } catch (e) {
                this.error.bookingPatron =
                    e.message || "Failed to fetch patron.";
                return null;
            } finally {
                this.loading.bookingPatron = false;
            }
        },
        /**
         * Fetch patrons by search term and page
         */
        async fetchPatrons(term, page = 1) {
            this.loading.patrons = true;
            this.error.patrons = null;
            try {
                const data = await bookingApi.fetchPatrons(term, page);
                return transformPatronsData(data);
            } catch (e) {
                this.error.patrons = e.message || "Failed to fetch patrons.";
                return [];
            } finally {
                this.loading.patrons = false;
            }
        },
        /**
         * Fetch pickup locations for a biblionumber (optionally filtered by patron)
         */
        async fetchPickupLocations(biblionumber, patron_id) {
            this.loading.pickupLocations = true;
            this.error.pickupLocations = null;
            try {
                const data = await bookingApi.fetchPickupLocations(
                    biblionumber,
                    patron_id
                );
                this.pickupLocations = data;
            } catch (e) {
                this.error.pickupLocations =
                    e.message || "Failed to fetch pickup locations.";
            } finally {
                this.loading.pickupLocations = false;
            }
        },
        /**
         * Fetch circulation rules for given context
         */
        async fetchCirculationRules(params) {
            this.loading.circulationRules = true;
            this.error.circulationRules = null;
            try {
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
                const data =
                    await bookingApi.fetchCirculationRules(filteredParams);
                this.circulationRules = data;
            } catch (e) {
                this.error.circulationRules =
                    e.message || "Failed to fetch circulation rules.";
            } finally {
                this.loading.circulationRules = false;
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
        async saveOrUpdateBooking(bookingData) {
            this.loading.submit = true;
            this.error.submit = null;
            try {
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
            } catch (e) {
                this.error.submit = e.message || "Failed to save booking.";
                throw e;
            } finally {
                this.loading.submit = false;
            }
        },
    },
});
