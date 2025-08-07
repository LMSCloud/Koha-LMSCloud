// @ts-check
/**
 * Constants for booking table configuration
 */

/** @const {Object} BOOKING_TABLE_CONSTANTS - Core constants for booking tables */
export const BOOKING_TABLE_CONSTANTS = {
    // Timing constants (in milliseconds)
    FILTER_REDRAW_DELAY: 300, // Delay before redrawing table after filter change

    // Time boundaries for date filtering
    DAY_START: { hour: 0, minute: 0, second: 0, millisecond: 0 },
    DAY_END: { hour: 23, minute: 59, second: 59, millisecond: 999 },

    // DataTables row indices
    HEADER_ROW_INDEX: 0, // Main header row
    FILTER_ROW_INDEX: 1, // Filter controls row

    // Status values
    STATUS_VALUES: {
        NEW: "new",
        PENDING: "pending",
        ACTIVE: "active",
        EXPIRED: "expired",
        CANCELLED: "cancelled",
        COMPLETED: "completed",
    },
};

/**
 * Feature configuration for different booking table variants
 *
 * VARIANT USAGE AND DIFFERENCES:
 *
 * 'default' variant:
 * - Used by: /circ/bookings.tt (main bookings management page)
 * - Features: Full-featured table with advanced filtering capabilities
 * - Date filtering: Flatpickr date range pickers with single input field
 * - Status filtering: Enhanced dropdown with synthetic statuses (New, Pending, Active, Expired, etc.)
 * - Location/ItemType filtering: Dropdown filters populated dynamically from table data
 * - Columns: All available columns including actions, status badges, creation date
 * - Use case: Staff interface for comprehensive booking management and filtering
 *
 * 'pending' variant:
 * - Used by: /circ/pendingbookings.tt (items required for collection)
 * - Features: Simplified table focused on collection workflow
 * - Date filtering: Standard text inputs (uses sidebar filters instead of column filters)
 * - Status filtering: No status column (all bookings are pending collection)
 * - Location/ItemType filtering: Standard DataTables text search (no dropdowns)
 * - Columns: Focused on item identification - no actions, status, or creation date
 * - Use case: Staff workflow for collecting items that need to be pulled for bookings
 *
 * 'biblio' variant:
 * - Used by: /bookings/list.tt (bookings for specific bibliography record)
 * - Features: Context-specific table for single biblio record
 * - Date filtering: Standard filtering (biblio-specific timeline used instead)
 * - Status filtering: Standard filtering (uses custom sidebar filters)
 * - Location/ItemType filtering: Standard filtering (less relevant for single biblio)
 * - Columns: Contextual - no biblio title needed, focused on patron and dates
 * - Use case: Catalog interface showing bookings for a specific bibliographic record
 */
export const BOOKING_TABLE_FEATURES = {
    default: {
        dateRangeFilters: true, // Flatpickr date range pickers
        dynamicLocationFilter: true, // Location dropdown populated from data
        dynamicItemTypeFilter: true, // Item type dropdown populated from data
        enhancedStatusFilter: true, // Custom status filtering with synthetic statuses
        customEnhancements: true, // Apply all custom filter enhancements
    },
    pending: {
        dateRangeFilters: false, // Use standard text inputs for dates
        dynamicLocationFilter: false, // Use standard text search for location
        dynamicItemTypeFilter: false, // Item type column not shown
        enhancedStatusFilter: false, // Status column not shown
        customEnhancements: false, // Use standard DataTables filtering only
    },
    biblio: {
        dateRangeFilters: false, // Standard filtering for biblio context
        dynamicLocationFilter: false, // Standard filtering for biblio context
        dynamicItemTypeFilter: false, // Standard filtering for biblio context
        enhancedStatusFilter: false, // Standard filtering for biblio context
        customEnhancements: false, // Use standard DataTables filtering only
    },
};
