// Common JavaScript functions and configurations for booking templates

// Global filter arrays will be initialized after function definitions

// Constants for booking table configuration
const BOOKING_TABLE_CONSTANTS = {
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
const BOOKING_TABLE_FEATURES = {
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

/**
 * Initialize extended attributes for bookings
 * @returns {Promise<Object>} Promise that resolves to an object containing extended_attribute_types and authorised_values
 */
function initializeBookingExtendedAttributes() {
    var extended_attribute_types;
    var authorised_values;

    return AdditionalFields.fetchAndProcessExtendedAttributes("booking")
        .then(types => {
            extended_attribute_types = types;
            const catArray = Object.values(types)
                .map(attr => attr.authorised_value_category_name)
                .filter(Boolean);
            return AdditionalFields.fetchAndProcessAuthorizedValues(catArray);
        })
        .then(values => {
            authorised_values = values;
            return { extended_attribute_types, authorised_values };
        });
}

/**
 * Get unified column definitions for booking tables
 * @param {Object} extended_attribute_types - Extended attribute types configuration
 * @param {Object} authorised_values - Authorized values configuration
 * @param {Object} options - Column configuration options
 * @param {string} [options.variant='default'] - The variant to use for column configuration
 * @param {boolean} [options.showActions=false] - Whether to show action buttons (edit/cancel)
 * @param {boolean} [options.showStatus=false] - Whether to show status column with badges
 * @param {boolean} [options.showCreationDate=false] - Whether to show creation date column
 * @param {boolean} [options.showCallnumber=false] - Whether to show callnumber column
 * @param {boolean} [options.showLocation=false] - Whether to show location column
 * @param {boolean} [options.showItemType=false] - Whether to show item type column
 * @param {boolean} [options.showPickupLibrary=true] - Whether to show pickup library column
 * @param {boolean} [options.showHoldingLibrary=false] - Whether to show holding library column
 * @param {boolean} [options.showBookingDates=true] - Whether to show combined booking dates column
 * @param {boolean} [options.showStartEndDates=false] - Whether to show separate start/end date columns
 * @param {string} [options.linkBiblio='bookings'] - How to link biblio titles ('bookings', 'catalogue', etc.)
 * @param {Object} [options.patronOptions={display_cardnumber: true, url: true}] - Patron display options
 * @param {boolean} [options.showBiblioTitle=true] - Whether to show biblio title column
 * @param {boolean} [options.showItemData=true] - Whether to show item data column
 * @returns {Array} Array of column definitions for DataTables
 */
function getBookingTableColumns(
    extended_attribute_types,
    authorised_values,
    options = {}
) {
    const {
        variant = "default",
        showActions = false,
        showStatus = false,
        showCreationDate = false,
        showCallnumber = false,
        showLocation = false,
        showItemType = false,
        showPickupLibrary = true,
        showHoldingLibrary = false,
        showBookingDates = true,
        showStartEndDates = false,
        linkBiblio = "bookings",
        patronOptions = { display_cardnumber: true, url: true },
        showBiblioTitle = true,
        showItemData = true,
    } = options;

    let columns = [];

    // Booking ID (usually hidden)
    columns.push({
        data: "booking_id",
        name: "booking_id",
        title: __("Booking ID"),
        visible: false,
    });

    // Creation date (optional)
    if (showCreationDate) {
        columns.push({
            data: "creation_date",
            name: "creation_date",
            title: __("Reserved on"),
            type: "date",
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return row.creation_date ? $date(row.creation_date) : "";
            },
        });
    }

    // Status (optional)
    if (showStatus) {
        columns.push({
            data: "status",
            title: __("Status"),
            name: "status",
            searchable: false,
            orderable: false,
            visible: variant === "biblio" ? false : true,
            render: function (data, type, row, meta) {
                const isExpired = date => dayjs(date).isBefore(new Date());
                const isActive = (startDate, endDate) => {
                    const now = dayjs();
                    return (
                        now.isAfter(dayjs(startDate)) &&
                        now.isBefore(dayjs(endDate).add(1, "day"))
                    );
                };

                const statusMap = {
                    new: () => {
                        if (isExpired(row.end_date)) {
                            return __("Expired");
                        }
                        if (isActive(row.start_date, row.end_date)) {
                            return __("Active");
                        }
                        if (dayjs(row.start_date).isAfter(new Date())) {
                            return __("Pending");
                        }
                        return __("New");
                    },
                    cancelled: () =>
                        [__("Cancelled"), row.cancellation_reason]
                            .filter(Boolean)
                            .join(": "),
                    completed: () => __("Completed"),
                };

                const statusText = statusMap[row.status]
                    ? statusMap[row.status]()
                    : __("Unknown");

                const classMap = [
                    { status: __("Expired"), class: "bg-secondary" },
                    { status: __("Cancelled"), class: "bg-secondary" },
                    { status: __("Pending"), class: "bg-warning" },
                    { status: __("Active"), class: "bg-primary" },
                    { status: __("Completed"), class: "bg-info" },
                    { status: __("New"), class: "bg-success" },
                ];

                const badgeClass =
                    classMap.find(mapping =>
                        statusText.startsWith(mapping.status)
                    )?.class || "bg-secondary";

                return `<span class="badge rounded-pill ${badgeClass}">${statusText}</span>`;
            },
        });
    }

    // Holding library
    if (showHoldingLibrary) {
        columns.push({
            data: "item.home_library_id",
            name: "home_library_id",
            title: __("Holding library"),
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return row.item._strings.home_library_id.str || "";
            },
        });
    }

    // Title
    if (showBiblioTitle) {
        columns.push({
            data: "biblio.title",
            name: "title",
            title: __("Title"),
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return row.biblio
                    ? $biblio_to_html(row.biblio, {
                          link: linkBiblio,
                      })
                    : "";
            },
        });
    }

    // Item
    if (showItemData) {
        columns.push({
            data: "item.external_id",
            name: "itemdata",
            title: __("Item"),
            searchable: true,
            orderable: true,
            defaultContent: __("Any item"),
            render: function (data, type, row, meta) {
                if (row.item) {
                    return row.item.external_id + " (" + row.booking_id + ")";
                } else {
                    return null;
                }
            },
        });
    }

    // Callnumber (optional)
    if (showCallnumber) {
        columns.push({
            data: "item.callnumber",
            name: "callnumber",
            title: __("Callnumber"),
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                if (row.item) {
                    return row.item.callnumber || "";
                } else {
                    return null;
                }
            },
        });
    }

    // Location (optional)
    if (showLocation) {
        columns.push({
            data: "item.location",
            name: "location",
            title: __("Location"),
            searchable: true,
            orderable: false,
            render: function (data, type, row, meta) {
                if (row.item) {
                    if (row.item.checked_out_date) {
                        return (
                            __("On loan, due: ") +
                            $date(row.item.checked_out_date)
                        );
                    } else {
                        return row.item._strings.location.str;
                    }
                } else {
                    return null;
                }
            },
        });
    }

    // Item type (optional)
    if (showItemType) {
        columns.push({
            data: "item.itype",
            title: __("Item type"),
            name: "itemtype",
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return row.item._strings.item_type_id.str || "";
            },
        });
    }

    // Patron
    columns.push({
        data: "patron.firstname:patron.surname",
        name: "patron",
        title: __("Patron"),
        searchable: true,
        orderable: true,
        render: function (data, type, row, meta) {
            return $patron_to_html(row.patron, patronOptions);
        },
    });

    // Pickup library
    if (showPickupLibrary) {
        columns.push({
            data: "pickup_library.name",
            name: "pickup_library",
            title: __("Pickup library"),
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return row.pickup_library.name || "";
            },
        });
    }

    // Date columns
    if (showBookingDates) {
        columns.push({
            data: "start_date",
            name: "start_date",
            title: __("Booking dates"),
            type: "date",
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return $date(row.start_date) + " - " + $date(row.end_date);
            },
        });
    } else if (showStartEndDates) {
        columns.push({
            data: "start_date",
            name: "start_date",
            title: __("Start date"),
            type: "date",
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return $date(row.start_date);
            },
        });
        columns.push({
            data: "end_date",
            title: __("End date"),
            type: "date",
            searchable: true,
            orderable: true,
            render: function (data, type, row, meta) {
                return $date(row.end_date);
            },
        });
    }

    // Extended attributes
    columns.push({
        data: "extended_attributes",
        name: "extended_attributes",
        title: __("Additional fields"),
        searchable: false,
        orderable: false,
        render: function (data, type, row, meta) {
            return AdditionalFields.renderExtendedAttributesValues(
                data,
                extended_attribute_types,
                authorised_values,
                row.booking_id
            ).join("<br>");
        },
    });

    // Actions (optional)
    if (showActions) {
        columns.push({
            data: null,
            name: "actions",
            title: __("Actions"),
            searchable: false,
            orderable: false,
            render: function (data, type, row, meta) {
                let result = "";
                let is_cancelled = row.status === "cancelled";
                if (
                    typeof CAN_user_circulate_manage_bookings !== "undefined" &&
                    CAN_user_circulate_manage_bookings
                ) {
                    if (!is_cancelled) {
                        result += `
                        <button
                            type="button"
                            class="btn btn-default btn-xs edit-action"
                            data-booking-modal
                            data-booking="${row.booking_id}"
                            data-biblionumber="${row.biblio_id}"
                            data-itemnumber="${row.item_id}"
                            data-patron="${row.patron_id}"
                            data-pickup_library="${row.pickup_library_id}"
                            data-start_date="${row.start_date}"
                            data-end_date="${row.end_date}"
                            data-item_type_id="${row.item.item_type_id}"
                            data-extended_attributes='${JSON.stringify(
                                row.extended_attributes
                                    ?.filter(
                                        attribute =>
                                            attribute.record_id ==
                                            row.booking_id
                                    )
                                    ?.map(attribute => ({
                                        field_id: attribute.field_id,
                                        value: attribute.value,
                                    })) ?? []
                            )}'
                        >
                            <i class="fa fa-pencil" aria-hidden="true"></i> ${__(
                                "Edit"
                            )}
                        </button>
                        <button type="button" class="btn btn-default btn-xs cancel-action"
                            data-toggle="modal"
                            data-target="#cancelBookingModal"
                            data-booking="${row.booking_id}">
                            <i class="fa fa-trash" aria-hidden="true"></i> ${__(
                                "Cancel"
                            )}
                        </button>`;
                    }
                }
                return result;
            },
        });
    }

    return columns;
}

/**
 * Get feature configuration for a booking table variant
 * @param {string} variant - The table variant ('default', 'pending', 'biblio')
 * @returns {Object} Feature configuration object
 */
function getBookingTableFeatures(variant = "default") {
    return BOOKING_TABLE_FEATURES[variant] || BOOKING_TABLE_FEATURES.default;
}

/**
 * Check if a feature is enabled for a variant
 * @param {string} variant - The table variant
 * @param {string} feature - The feature name
 * @returns {boolean} Whether the feature is enabled
 */
function isFeatureEnabled(variant, feature) {
    const features = getBookingTableFeatures(variant);
    return features[feature] === true;
}

/**
 * Determine if a column should have a date range filter
 * @param {string} variant - The table variant
 * @param {Object} col - The column configuration
 * @returns {boolean} Whether to add date range filter
 */
function shouldAddDateRangeFilter(variant, col) {
    return (
        isFeatureEnabled(variant, "dateRangeFilters") &&
        (col.type === "date" || (col.name && col.name.includes("date")))
    );
}

/**
 * Determine if a column should have a dynamic dropdown filter
 * @param {string} variant - The table variant
 * @param {Object} col - The column configuration
 * @param {Object} columnOptions - The column display options
 * @returns {string} The data-filter attribute value or empty string
 */
function getColumnFilterType(variant, col, columnOptions) {
    // Status column is handled separately
    if (col.name === "home_library_id" && columnOptions.showHoldingLibrary) {
        return "getLibraryOptions";
    } else if (
        col.name === "pickup_library" &&
        columnOptions.showPickupLibrary
    ) {
        return "getLibraryOptions";
    } else if (
        col.name === "location" &&
        columnOptions.showLocation &&
        isFeatureEnabled(variant, "dynamicLocationFilter")
    ) {
        return "getLocationOptions";
    } else if (
        col.name === "itemtype" &&
        columnOptions.showItemType &&
        isFeatureEnabled(variant, "dynamicItemTypeFilter")
    ) {
        return "getItemTypeOptions";
    }
    return "";
}

/**
 * Get standard status filter options
 * @returns {Array} Array of status options with _id and _str properties
 */
function getStandardStatusOptions() {
    return [
        { _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.NEW, _str: __("New") },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.PENDING,
            _str: __("Pending"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.ACTIVE,
            _str: __("Active"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.EXPIRED,
            _str: __("Expired"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.CANCELLED,
            _str: __("Cancelled"),
        },
        {
            _id: BOOKING_TABLE_CONSTANTS.STATUS_VALUES.COMPLETED,
            _str: __("Completed"),
        },
    ];
}

/**
 * Map column data field to API field name for date filtering
 * @param {string} columnData - The column data field name
 * @returns {string} The corresponding API field name
 */
function mapColumnDataToApiField(columnData) {
    const fieldMap = {
        creation_date: "me.creation_date",
        start_date: "me.start_date",
        end_date: "me.end_date",
    };
    return fieldMap[columnData] || columnData;
}

/**
 * Initialize and manage global filter arrays for _dt_add_filters compatibility
 * @param {Object} options - Filter options to populate global arrays
 */
function initializeGlobalFilterArrays(options = {}) {
    // Initialize empty arrays if they don't exist
    if (typeof window.getLibraryOptions === "undefined") {
        window.getLibraryOptions = [];
    }
    if (typeof window.getStatusOptions === "undefined") {
        window.getStatusOptions = [];
    }
    if (typeof window.getLocationOptions === "undefined") {
        window.getLocationOptions = [];
    }
    if (typeof window.getItemTypeOptions === "undefined") {
        window.getItemTypeOptions = [];
    }

    // Populate with provided options
    if (options.getLibraryOptions) {
        window.getLibraryOptions = options.getLibraryOptions;
    }
    if (options.getStatusOptions) {
        window.getStatusOptions = options.getStatusOptions;
    }
    if (options.getLocationOptions) {
        window.getLocationOptions = options.getLocationOptions;
    }
    if (options.getItemTypeOptions) {
        window.getItemTypeOptions = options.getItemTypeOptions;
    }
}

/**
 * Booking Table Filter Manager - Encapsulates all filter-related functionality
 * Eliminates global state pollution and provides clean API
 */
const BookingTableFilterManager = (function () {
    // Private state - no global pollution
    const instances = new Map();

    function createInstance(tableId) {
        return {
            tableId: tableId,
            filterOptions: {
                getLibraryOptions: [],
                getStatusOptions: [],
                getLocationOptions: [],
                getItemTypeOptions: [],
            },
            dynamicFiltersPopulated: false,
            dateRangeFilters: new Map(),

            // Initialize filter options for this table instance
            initializeFilterOptions(variant = "default") {
                // Use the global BOOKINGS_LIBRARIES_DATA if available
                const all_libraries = (
                    typeof BOOKINGS_LIBRARIES_DATA !== "undefined"
                        ? BOOKINGS_LIBRARIES_DATA
                        : []
                ).map(e => ({
                    _id: e.branchcode,
                    _str: e.branchname,
                }));

                // Status filter options
                const statusOptions = getStandardStatusOptions();

                this.filterOptions = {
                    getLibraryOptions: all_libraries,
                    getStatusOptions: statusOptions,
                    getLocationOptions: [], // Will be populated dynamically
                    getItemTypeOptions: [], // Will be populated dynamically
                };

                // Update global arrays for _dt_add_filters compatibility
                initializeGlobalFilterArrays({
                    getLibraryOptions: all_libraries,
                    getStatusOptions: statusOptions,
                });

                return this.filterOptions;
            },
        };
    }

    return {
        // Get or create filter manager instance for a table
        getInstance(tableId) {
            if (!instances.has(tableId)) {
                instances.set(tableId, createInstance(tableId));
            }
            return instances.get(tableId);
        },

        // Clean up instance when table is destroyed
        destroyInstance(tableId) {
            instances.delete(tableId);
        },
    };
})();

/**
 * Get unified library and status filter options
 * @param {string} [variant='default'] - The variant to use for filter options
 * @param {string} [tableId='default'] - Unique identifier for the table instance
 * @returns {Object} Filter options object for KohaTable
 */
function getBookingsFilterOptions(variant = "default", tableId = "default") {
    const manager = BookingTableFilterManager.getInstance(tableId);
    const options = manager.initializeFilterOptions(variant);

    // Ensure global arrays are populated for _dt_add_filters compatibility
    // This handles cases where this function is called before createBookingsTable
    if (
        typeof window.getLibraryOptions !== "undefined" &&
        window.getLibraryOptions.length === 0
    ) {
        window.getLibraryOptions = options.getLibraryOptions || [];
    }
    if (
        typeof window.getStatusOptions !== "undefined" &&
        window.getStatusOptions.length === 0
    ) {
        window.getStatusOptions = options.getStatusOptions || [];
    }

    return options;
}

/**
 * Backwards compatibility function
 * @deprecated Use getBookingsFilterOptions instead
 */
function getLibraryFilterOptions(variant = "default") {
    const options = getBookingsFilterOptions(variant);
    return {
        // Return only library options for backwards compatibility
        [1]: () => options.getLibraryOptions,
    };
}

/**
 * Create a unified date filter function
 * @param {string} fromSelector - CSS selector for the "from" date input
 * @param {string} toSelector - CSS selector for the "to" date input
 * @param {string} [variant='default'] - The variant to use (currently unused, for future extensibility)
 * @returns {Function} A function that returns date filter object for KohaTable
 */
function createDateFilter(fromSelector, toSelector, variant = "default") {
    return function () {
        let fromdate = $(fromSelector);
        let isoFrom;
        if (fromdate.val() !== "") {
            let selectedDate = fromdate.get(0)._flatpickr.selectedDates[0];
            selectedDate.setHours(
                BOOKING_TABLE_CONSTANTS.DAY_START.hour,
                BOOKING_TABLE_CONSTANTS.DAY_START.minute,
                BOOKING_TABLE_CONSTANTS.DAY_START.second,
                BOOKING_TABLE_CONSTANTS.DAY_START.millisecond
            );
            isoFrom = selectedDate.toISOString();
        }

        let todate = $(toSelector);
        let isoTo;
        if (todate.val() !== "") {
            let selectedDate = todate.get(0)._flatpickr.selectedDates[0];
            selectedDate.setHours(
                BOOKING_TABLE_CONSTANTS.DAY_END.hour,
                BOOKING_TABLE_CONSTANTS.DAY_END.minute,
                BOOKING_TABLE_CONSTANTS.DAY_END.second,
                BOOKING_TABLE_CONSTANTS.DAY_END.millisecond
            );
            isoTo = selectedDate.toISOString();
        }

        if (isoFrom || isoTo) {
            return { ">=": isoFrom, "<=": isoTo };
        } else {
            return;
        }
    };
}

/**
 * Create unified additional filters based on variant
 * @param {string} [variant='default'] - The variant to use for filter configuration
 *   - 'default': No additional filters (empty object)
 *   - 'pending': Includes date range, holding library, and pickup library filters
 * @param {Object} [options={}] - Options for customizing selectors
 * @param {string} [options.fromSelector='#from'] - CSS selector for "from" date input
 * @param {string} [options.toSelector='#to'] - CSS selector for "to" date input
 * @param {string} [options.holdingLibrarySelector='#holding_library'] - CSS selector for holding library dropdown
 * @param {string} [options.pickupLibrarySelector='#pickup_library'] - CSS selector for pickup library dropdown
 * @returns {Object} Additional filters object for KohaTable
 */
function createAdditionalFilters(variant = "default", options = {}) {
    const {
        fromSelector = "#from",
        toSelector = "#to",
        holdingLibrarySelector = "#holding_library",
        pickupLibrarySelector = "#pickup_library",
    } = options;

    switch (variant) {
        case "pending":
            return {
                start_date: createDateFilter(fromSelector, toSelector, variant),
                "item.holding_library_id": function () {
                    let library = $(holdingLibrarySelector)
                        .find(":selected")
                        .val();
                    return library;
                },
                pickup_library_id: function () {
                    let library = $(pickupLibrarySelector)
                        .find(":selected")
                        .val();
                    return library;
                },
            };
        case "default":
        default:
            return {};
    }
}

/**
 * Get unified embed configuration based on variant
 * @param {string} [variant='default'] - The variant to use for embed configuration
 *   - 'default': Standard embed configuration for all booking types
 *   - 'pending': Same as default (currently identical, but can be extended)
 *   - 'biblio': Embed configuration for biblio-specific bookings (excludes biblio since context is known)
 * @returns {Array<string>} Array of embed strings for KohaTable
 */
function getBookingsEmbed(variant = "default") {
    switch (variant) {
        case "biblio":
            return ["item", "patron", "pickup_library", "extended_attributes"];
        case "default":
        default:
            return [
                "biblio",
                "item+strings",
                "item.checkout",
                "patron",
                "pickup_library",
                "extended_attributes",
            ];
    }
}

/**
 * Get unified URL configuration based on variant
 * @param {string} [variant='default'] - The variant to use for URL configuration
 * @param {string} [biblionumber] - Biblionumber for biblio-specific variants
 * @returns {string} API endpoint URL
 */
function getBookingsUrl(variant = "default", biblionumber) {
    switch (variant) {
        case "biblio":
            if (!biblionumber) {
                throw new Error("biblionumber is required for biblio variant");
            }
            return `/api/v1/biblios/${biblionumber}/bookings`;
        case "pending":
        case "default":
        default:
            return "/api/v1/bookings?";
    }
}

/**
 * Get column filter configuration based on variant
 * @param {string} [variant='default'] - The variant to use for column filter configuration
 * @returns {number} Column filter flag (1 for enabled, 0 for disabled)
 */
function getBookingsColumnFilterFlag(variant = "default") {
    switch (variant) {
        case "pending":
        case "default":
            return 1; // Enable column filters for both pending and regular bookings
        case "biblio":
        default:
            return 0; // Disable column filters for other variants
    }
}

/**
 * Create a unified bookings table with configurable behavior based on variant
 * @param {string|jQuery} tableElement - The table element or selector
 * @param {Object} tableSettings - KohaTable settings object
 * @param {Object} [options={}] - Configuration options
 * @param {string} [options.variant='default'] - The variant to use for table configuration
 *   - 'default': Standard bookings table with basic configuration
 *   - 'pending': Pending bookings table with date filters and library filters
 *   - 'biblio': Biblio-specific bookings table (excludes biblio from embed, uses biblio-specific URL)
 * @param {string} [options.url] - API endpoint URL (auto-configured based on variant if not provided)
 * @param {string} [options.biblionumber] - Biblionumber for biblio-specific variants
 * @param {Array} [options.order=[[7, "asc"]]] - Default sort order (column index, direction)
 * @param {Object} [options.additionalFilters] - Additional filters (auto-configured based on variant)
 * @param {Object} [options.filterOptions] - Filter options (auto-configured based on variant)
 * @param {Array} [options.embed] - Embed configuration (auto-configured based on variant)
 * @param {Object} [options.columnOptions={}] - Column display options
 *   - showCallnumber: {boolean} - Show callnumber column
 *   - showLocation: {boolean} - Show location column
 *   - showPickupLibrary: {boolean} - Show pickup library column
 *   - showBookingDates: {boolean} - Show combined booking dates
 *   - patronOptions: {Object} - Patron display options
 * @returns {jQuery} KohaTable instance
 */
function createBookingsTable(tableElement, tableSettings, options = {}) {
    const {
        variant = "default",
        url,
        biblionumber,
        order,
        additionalFilters = createAdditionalFilters(variant, options),
        filterOptions = getBookingsFilterOptions(variant),
        embed = getBookingsEmbed(variant),
        columnOptions = {},
    } = options;

    let finalUrl = url ?? getBookingsUrl(variant, biblionumber);

    // Set default column options based on variant
    let defaultColumnOptions = {
        showCallnumber: false,
        showLocation: false,
        showPickupLibrary: true,
        showBookingDates: true,
        patronOptions: { display_cardnumber: true, url: true },
    };

    // Merge with provided column options
    const finalColumnOptions = { ...defaultColumnOptions, ...columnOptions };

    // Get columns first to determine filter positions
    const columns = getBookingTableColumns(
        options.extended_attribute_types,
        options.authorised_values,
        { ...finalColumnOptions, variant: variant }
    );

    // Prepare filter options with column-specific assignments
    let finalFilterOptions = getBookingsFilterOptions(variant);

    // Create headers with data-filter attributes before kohaTable initialization
    if ($(tableElement).find("thead").length === 0) {
        let headerRow = "<thead><tr>";
        columns.forEach((col, index) => {
            let dataFilter = "";
            let additionalAttrs = "";

            // Get the filter type for this column using helper function
            const filterType = getColumnFilterType(
                variant,
                col,
                finalColumnOptions
            );
            if (filterType) {
                dataFilter = ` data-filter="${filterType}"`;
            }

            // Check if this column should have date range filtering
            if (shouldAddDateRangeFilter(variant, col)) {
                additionalAttrs = ' data-date-range-filter="true"';
            }

            headerRow += `<th${dataFilter}${additionalAttrs}>${col.title}</th>`;
        });
        headerRow += "</tr></thead>";
        $(tableElement).html(headerRow);
    }

    // Generate unique table ID for filter manager
    const tableId =
        $(tableElement).attr("id") || "bookings-table-" + Date.now();
    const filterManager = BookingTableFilterManager.getInstance(tableId);

    const kohaTable = $(tableElement).kohaTable(
        {
            ajax: {
                url: finalUrl,
                dataSrc: function (json) {
                    // Only populate filter options on initial load using instance state
                    if (!filterManager.dynamicFiltersPopulated) {
                        populateDynamicFilterOptionsFromData(
                            json.data || json,
                            filterManager
                        );
                        filterManager.dynamicFiltersPopulated = true;
                    }
                    return json.data || json;
                },
            },
            embed: embed,
            order: order,
            columns: columns,
        },
        tableSettings,
        getBookingsColumnFilterFlag(variant),
        additionalFilters,
        finalFilterOptions
    );

    // Use proper DataTables events instead of setTimeout
    if (getBookingsColumnFilterFlag(variant) === 1) {
        const dataTable = kohaTable.DataTable();

        // Apply custom enhancements based on variant feature configuration
        if (isFeatureEnabled(variant, "customEnhancements")) {
            // Event-driven enhancement after table is fully initialized
            dataTable.on("init.dt", function () {
                enhanceBookingTableFilters(
                    dataTable,
                    tableElement,
                    additionalFilters,
                    filterManager
                );
                // Also update dropdowns on init to ensure they're populated from initial data
                updateDynamicFilterDropdowns(tableElement, filterManager);
            });

            // Handle dynamic filter updates after subsequent data loads
            dataTable.on("xhr.dt", function () {
                // Always update dropdowns after data loads to ensure they're populated
                updateDynamicFilterDropdowns(tableElement, filterManager);
            });
        }
    }

    return kohaTable;
}

/**
 * Convenience function to create a pending bookings table
 * This is equivalent to calling createBookingsTable with variant: 'pending'
 *
 * @param {string|jQuery} tableElement - The table element or selector
 * @param {Object} tableSettings - KohaTable settings object
 * @param {Object} [options={}] - Configuration options (same as createBookingsTable)
 * @returns {jQuery} KohaTable instance configured for pending bookings
 *
 * @example
 * // Create a pending bookings table with custom column options
 * createPendingBookingsTable('#pending-table', tableSettings, {
 *     columnOptions: { showStatus: true, showCreationDate: true }
 * });
 */
function createPendingBookingsTable(tableElement, tableSettings, options = {}) {
    return createBookingsTable(tableElement, tableSettings, {
        ...options,
        variant: "pending",
    });
}

/**
 * Convenience function to create a biblio-specific bookings table
 * This is equivalent to calling createBookingsTable with variant: 'biblio'
 *
 * @param {string|jQuery} tableElement - The table element or selector
 * @param {Object} tableSettings - KohaTable settings object
 * @param {string} biblionumber - The biblionumber for the biblio-specific endpoint
 * @param {Object} [options={}] - Configuration options (same as createBookingsTable)
 * @returns {jQuery} KohaTable instance configured for biblio-specific bookings
 *
 * @example
 * // Create a biblio-specific bookings table with custom column options
 * createBiblioBookingsTable('#biblio-table', tableSettings, biblionumber, {
 *     columnOptions: { showStatus: true, showActions: true }
 * });
 */
function createBiblioBookingsTable(
    tableElement,
    tableSettings,
    biblionumber,
    options = {}
) {
    return createBookingsTable(tableElement, tableSettings, {
        ...options,
        variant: "biblio",
        biblionumber: biblionumber,
    });
}

/**
 * Enhance table with date range filters using filter manager
 * Replaces setTimeout-based approach with proper event handling
 * @param {DataTable} dataTable - The DataTables instance
 * @param {jQuery|string} tableElement - The table element or selector
 * @param {Object} additionalFilters - Additional filters object to populate
 * @param {Object} filterManager - The filter manager instance
 * @private
 */
function enhanceDateRangeFilters(
    dataTable,
    tableElement,
    additionalFilters,
    filterManager
) {
    // Store date range filters in manager instance instead of global state
    if (!filterManager.dateRangeFilters) {
        filterManager.dateRangeFilters = new Map();
    }

    $(tableElement)
        .find(
            "thead tr:eq(" +
                BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX +
                ') th[data-date-range-filter="true"]'
        )
        .each(function (relativeIndex) {
            const $th = $(this);
            const actualColumnIndex = $th.data("th-id");

            if (
                actualColumnIndex !== undefined &&
                $th.find('input[type="text"]').length > 0
            ) {
                // Get column information to determine the API field name
                const columnInfo = dataTable.column(actualColumnIndex);
                const columnData = columnInfo.dataSrc();

                // Map column data to API field names
                const apiFieldName = mapColumnDataToApiField(columnData);

                const inputId = "date_range_col_" + actualColumnIndex;

                const html =
                    '<input type="text" id="' +
                    inputId +
                    '" ' +
                    'placeholder="Select date range" />';

                $th.html(html);

                // Create a filter function for this date field in manager instance
                filterManager.dateRangeFilters.set(apiFieldName, function () {
                    const input = $("#" + inputId);
                    const fp = input.get(0)?._flatpickr;
                    if (
                        !fp ||
                        !fp.selectedDates ||
                        fp.selectedDates.length === 0
                    ) {
                        return; // No filter
                    }

                    // Only proceed if we have a complete range (both dates selected)
                    if (fp.selectedDates.length === 2) {
                        // Date range selected
                        const fromDate = new Date(fp.selectedDates[0]);
                        const toDate = new Date(fp.selectedDates[1]);
                        fromDate.setHours(
                            BOOKING_TABLE_CONSTANTS.DAY_START.hour,
                            BOOKING_TABLE_CONSTANTS.DAY_START.minute,
                            BOOKING_TABLE_CONSTANTS.DAY_START.second,
                            BOOKING_TABLE_CONSTANTS.DAY_START.millisecond
                        );
                        toDate.setHours(
                            BOOKING_TABLE_CONSTANTS.DAY_END.hour,
                            BOOKING_TABLE_CONSTANTS.DAY_END.minute,
                            BOOKING_TABLE_CONSTANTS.DAY_END.second,
                            BOOKING_TABLE_CONSTANTS.DAY_END.millisecond
                        );
                        return {
                            ">=": fromDate.toISOString(),
                            "<=": toDate.toISOString(),
                        };
                    }

                    // For single date selection, don't apply filter yet (wait for complete range)
                    return;
                });

                // Add the filter function to additionalFilters using manager reference
                if (
                    typeof additionalFilters === "object" &&
                    additionalFilters !== null
                ) {
                    additionalFilters[apiFieldName] =
                        filterManager.dateRangeFilters.get(apiFieldName);
                }

                // Use requestAnimationFrame for better timing than setTimeout
                requestAnimationFrame(() => {
                    const input = $("#" + inputId);

                    const fp = flatpickr("#" + inputId, {
                        mode: "range",
                        dateFormat: flatpickr_dateformat_string,
                        locale: {
                            firstDayOfWeek: calendarFirstDayOfWeek,
                            weekdays: flatpickr_weekdays,
                            months: flatpickr_months,
                        },
                        onChange: function (selectedDates, dateStr, instance) {
                            // Clear any column search since we're using additionalFilters
                            dataTable.column(actualColumnIndex).search("");

                            // Trigger table redraw with throttling
                            clearTimeout(input.data("drawTimeout"));
                            input.data(
                                "drawTimeout",
                                setTimeout(() => {
                                    dataTable.draw();
                                }, BOOKING_TABLE_CONSTANTS.FILTER_REDRAW_DELAY)
                            );
                        },
                        onReady: function (selectedDates, dateStr, instance) {
                            // Add Koha-style clear button (same as in calendar.inc)
                            // Create flex container around input and button to control column width
                            const $wrapper = $("<span/>").css({
                                display: "flex",
                                "justify-content": "center",
                                "align-items": "center",
                            });
                            $(instance.input)
                                .attr("autocomplete", "off")
                                .css("flex", "1")
                                .wrap($wrapper)
                                .after(
                                    $("<a/>")
                                        .attr("href", "#")
                                        .attr(
                                            "aria-label",
                                            __("Clear date range")
                                        )
                                        .addClass(
                                            "clear_date fa fa-fw fa-remove"
                                        )
                                        .on("click", function (e) {
                                            e.preventDefault();
                                            instance.clear();
                                        })
                                );
                        },
                        onClear: function () {
                            // Clear column search and refresh table
                            dataTable.column(actualColumnIndex).search("");
                            dataTable.draw();
                        },
                    });

                    input.on("click focus", function (e) {
                        e.stopPropagation();
                        fp.open();
                    });
                });
            }
        });
}

/**
 * Enhance status column filtering to handle calculated statuses
 * The status column shows calculated statuses (Expired, Active, Pending) but the database
 * only stores raw statuses (new, cancelled, completed). This function creates proper filters
 * that map the calculated statuses to the appropriate database queries.
 */
function enhanceStatusFilter(
    dataTable,
    tableElement,
    additionalFilters,
    filterManager
) {
    // Find the status column by looking for the header with "Status" title
    let statusColumnIndex = -1;
    $(tableElement)
        .find(
            "thead tr:eq(" + BOOKING_TABLE_CONSTANTS.HEADER_ROW_INDEX + ") th"
        )
        .each(function (index) {
            if ($(this).text().trim() === __("Status")) {
                statusColumnIndex = index;
                return false; // break
            }
        });

    if (statusColumnIndex === -1) {
        return; // Status column not found
    }

    // Get the filter cell for the status column
    const $th = $(tableElement)
        .find(
            "thead tr:eq(" + BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX + ") th"
        )
        .eq(statusColumnIndex);

    // Check what's currently in the cell
    let statusDropdown = $th.find("select");

    // If there's no dropdown or it only has the default "Filter" option, create/populate it
    if (
        statusDropdown.length === 0 ||
        statusDropdown.find("option").length <= 1
    ) {
        if (statusDropdown.length === 0) {
            // No dropdown exists, create one
            const selectHtml = '<select><option value=""></option></select>';
            $th.html(selectHtml);
            statusDropdown = $th.find("select");
        }

        // Always use the standard status options
        const statusOptions = getStandardStatusOptions();

        // Add options if they don't exist
        statusOptions.forEach(option => {
            if (
                statusDropdown.find(`option[value="${option._id}"]`).length ===
                0
            ) {
                statusDropdown.append(
                    `<option value="${option._id}">${option._str}</option>`
                );
            }
        });
    }

    // Use the column index we already found
    const columnIndex = statusColumnIndex;

    // Store selected status in filter manager instance instead of global state
    if (!filterManager.selectedSyntheticStatus) {
        filterManager.selectedSyntheticStatus = "";
    }

    // Create status filter function in manager instance
    if (!filterManager.statusFilterFunction) {
        filterManager.statusFilterFunction = function () {
            const selectedValue = statusDropdown.val();
            if (!selectedValue) return; // No filter selected

            // Map synthetic statuses to base database statuses
            switch (selectedValue) {
                case "new":
                case "pending":
                case "active":
                case "expired":
                    // All calculated statuses are based on 'new' in database
                    return "new";
                case "cancelled":
                    return "cancelled";
                case "completed":
                    return "completed";
                default:
                    return;
            }
        };

        // Add the status filter to additionalFilters - use correct field name
        if (
            typeof additionalFilters === "object" &&
            additionalFilters !== null
        ) {
            additionalFilters["me.status"] = filterManager.statusFilterFunction;
        }
    }

    // Override the dropdown's change handler - remove ALL handlers first
    statusDropdown.off("change"); // Remove all change handlers including DataTables'
    statusDropdown.on("change", function (e) {
        // Store the selected value for client-side filtering in manager instance
        filterManager.selectedSyntheticStatus = $(this).val();

        // Don't use column search at all for status - only our custom filter
        dataTable.column(columnIndex).search("");

        // Trigger redraw - our additionalFilters will handle the actual filtering
        dataTable.draw();
    });

    // Add client-side filtering after data loads using manager instance
    dataTable.off("draw.statusFilter").on("draw.statusFilter", function () {
        if (filterManager.selectedSyntheticStatus) {
            applyClientSideStatusFilter(
                dataTable,
                filterManager.selectedSyntheticStatus
            );
        }
    });
}

/**
 * Apply client-side status filtering to hide rows that don't match the calculated status
 * This is the "second stage" that filters the server results further based on date calculations
 * @param {DataTable} dataTable - The DataTables instance
 * @param {string} selectedStatus - The selected status filter value
 * @private
 */
function applyClientSideStatusFilter(dataTable, selectedStatus) {
    let visibleCount = 0;
    let totalCount = 0;

    // Get all rows
    dataTable
        .rows()
        .nodes()
        .each(function (row, index) {
            const $row = $(row);
            const data = dataTable.row(row).data();
            totalCount++;

            // Skip if no data
            if (!data || !data.start_date || !data.end_date) {
                return;
            }

            // Calculate the actual status based on the same logic as the render function
            const calculatedStatus = calculateBookingStatus(
                data.status,
                data.start_date,
                data.end_date
            );

            // Show/hide row based on whether calculated status matches selected filter
            if (
                selectedStatus === "" ||
                calculatedStatus.toLowerCase() === selectedStatus.toLowerCase()
            ) {
                $row.show();
                visibleCount++;
            } else {
                $row.hide();
            }
        });

    // If no rows are visible, trigger DataTables empty state
    if (visibleCount === 0 && totalCount > 0) {
        // Force DataTables to recognize there are no visible rows
        dataTable.rows().remove();
        dataTable.draw();
    }
}

/**
 * Consolidated booking table filter enhancement system
 * Replaces individual enhancement functions with unified approach
 * @param {DataTable} dataTable - The DataTables instance
 * @param {jQuery|string} tableElement - The table element or selector
 * @param {Object} additionalFilters - Additional filters object
 * @param {Object} filterManager - The filter manager instance
 */
function enhanceBookingTableFilters(
    dataTable,
    tableElement,
    additionalFilters,
    filterManager
) {
    // Enhanced filters in priority order
    const enhancements = [
        { type: "dateRange", handler: enhanceDateRangeFilters },
        { type: "status", handler: enhanceStatusFilter },
        { type: "dynamic", handler: updateDynamicFilterDropdowns },
    ];

    enhancements.forEach(enhancement => {
        try {
            enhancement.handler(
                dataTable,
                tableElement,
                additionalFilters,
                filterManager
            );
        } catch (error) {
            console.warn(
                `Failed to enhance ${enhancement.type} filters:`,
                error
            );
        }
    });
}

/**
 * Populate dynamic filter options from raw API data using filter manager
 * @param {Array|Object} data - The raw API data or response object
 * @param {Object} filterManager - The filter manager instance
 * @private
 */
function populateDynamicFilterOptionsFromData(data, filterManager) {
    const rows = Array.isArray(data) ? data : data.data || [];

    // Collect unique locations and item types
    const locations = new Map();
    const itemTypes = new Map();

    rows.forEach(function (row) {
        // Extract location data
        if (row.item?.location && row.item._strings?.location) {
            const locationCode = row.item.location;
            const locationName = row.item._strings.location.str || locationCode;
            locations.set(locationCode, locationName);
        }

        // Extract item type data
        if (row.item?._strings?.item_type_id) {
            const itemTypeCode =
                row.item.itype ||
                row.item.item_type_id ||
                row.item.itemtype ||
                Object.keys(row.item).find(
                    key =>
                        key.toLowerCase().includes("type") ||
                        key.toLowerCase().includes("itype")
                )?.[0];

            if (itemTypeCode) {
                const itemTypeName =
                    row.item._strings.item_type_id.str || itemTypeCode;
                itemTypes.set(itemTypeCode, itemTypeName);
            }
        }
    });

    // Update filter manager instance instead of global arrays
    const locationOptions = Array.from(locations.entries())
        .map(([code, name]) => ({ _id: code, _str: name }))
        .sort((a, b) => a._str.localeCompare(b._str));

    const itemTypeOptions = Array.from(itemTypes.entries())
        .map(([code, name]) => ({ _id: code, _str: name }))
        .sort((a, b) => a._str.localeCompare(b._str));

    // Store in manager instance and update global references for Koha compatibility
    filterManager.filterOptions.getLocationOptions = locationOptions;
    filterManager.filterOptions.getItemTypeOptions = itemTypeOptions;

    // Update global arrays for _dt_add_filters compatibility
    // Always update on initial population, preserve selection state via updateDynamicFilterDropdowns
    window.getLocationOptions = locationOptions;
    window.getItemTypeOptions = itemTypeOptions;
}

/**
 * Update dynamic filter dropdowns after data changes
 * Preserves current selection to prevent reset behavior
 * @param {jQuery|string} tableElement - The table element or selector
 * @param {Object} filterManager - The filter manager instance
 * @private
 */
function updateDynamicFilterDropdowns(tableElement, filterManager) {
    $(tableElement)
        .find(
            "thead tr:eq(" + BOOKING_TABLE_CONSTANTS.FILTER_ROW_INDEX + ") th"
        )
        .each(function (columnIndex) {
            const $th = $(this);
            const filterType = $th.data("filter");
            const $select = $th.find("select");

            if ($select.length > 0) {
                // Save current selection before updating
                const currentValue = $select.val();

                const options = filterManager.filterOptions[filterType];
                if (options && options.length > 0) {
                    // Only update if options are different or empty
                    const currentOptions = $select
                        .find("option")
                        .not(":first")
                        .map(function () {
                            return $(this).val();
                        })
                        .get();

                    const newOptionValues = options.map(opt => opt._id);

                    // Update if options have changed OR if dropdown is empty (initial load)
                    if (
                        currentOptions.length === 0 ||
                        currentOptions.length !== newOptionValues.length ||
                        !currentOptions.every(val =>
                            newOptionValues.includes(val)
                        )
                    ) {
                        // Clear existing options except the empty one
                        $select.find("option").not(":first").remove();
                        // Add new options
                        options.forEach(option => {
                            $select.append(
                                `<option value="${option._id}">${option._str}</option>`
                            );
                        });

                        // Restore previous selection if it still exists
                        if (
                            currentValue &&
                            $select.find(`option[value="${currentValue}"]`)
                                .length > 0
                        ) {
                            $select.val(currentValue);
                        }
                    }
                }
            }
        });
}

/**
 * Legacy function - kept for compatibility
 * @deprecated Use populateDynamicFilterOptionsFromData instead
 * @private
 */
function populateDynamicFilterOptions(dataTable) {
    // Get all data from the table and delegate to the data function
    const data = [];
    dataTable
        .rows()
        .data()
        .each(function (row) {
            data.push(row);
        });
    populateDynamicFilterOptionsFromData(data);
}

/**
 * Calculate the booking status based on the same logic used in the column render function
 * @param {string} dbStatus - The database status value
 * @param {string} startDate - The booking start date
 * @param {string} endDate - The booking end date
 * @returns {string} The calculated status (new, pending, active, expired, cancelled, completed, unknown)
 * @private
 */
function calculateBookingStatus(dbStatus, startDate, endDate) {
    const isExpired = date => dayjs(date).isBefore(new Date());
    const isActive = (startDate, endDate) => {
        const now = dayjs();
        return (
            now.isAfter(dayjs(startDate)) &&
            now.isBefore(dayjs(endDate).add(1, "day"))
        );
    };

    switch (dbStatus) {
        case "new":
            if (isExpired(endDate)) {
                return "expired";
            }
            if (isActive(startDate, endDate)) {
                return "active";
            }
            if (dayjs(startDate).isAfter(new Date())) {
                return "pending";
            }
            return "new";
        case "cancelled":
            return "cancelled";
        case "completed":
            return "completed";
        default:
            return "unknown";
    }
}

// Initialize global filter arrays for _dt_add_filters compatibility
initializeGlobalFilterArrays();
