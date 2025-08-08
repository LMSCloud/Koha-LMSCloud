// @ts-check
/**
 * Bookings Common JavaScript Library
 * 
 * This file serves as the main entry point for the modular booking table system.
 * It re-exports all functionality from the modular structure for use in templates.
 */

// Re-export everything from the main module
export * from './bookings/tables/index.js';

// Import the main functions that templates expect to be available globally
import {
    createBookingsTable,
    createPendingBookingsTable,
    createBiblioBookingsTable,
    initializeBookingExtendedAttributes,
    getBookingTableColumns,
    getBookingsFilterOptions,
    initializeGlobalFilterArrays
} from './bookings/tables/index.js';

// For backwards compatibility with templates, expose the main functions globally
// These will be available on the window object for templates to use
window["createBookingsTable"] = createBookingsTable;
window["createPendingBookingsTable"] = createPendingBookingsTable;
window["createBiblioBookingsTable"] = createBiblioBookingsTable;
window["initializeBookingExtendedAttributes"] = initializeBookingExtendedAttributes;
window["getBookingTableColumns"] = getBookingTableColumns;
window["getBookingsFilterOptions"] = getBookingsFilterOptions;

// Initialize global filter arrays for datatables.js compatibility
initializeGlobalFilterArrays();