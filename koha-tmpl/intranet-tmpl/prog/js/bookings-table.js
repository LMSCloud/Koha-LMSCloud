/**
 * Common booking table functionality
 * Provides reusable functions for initializing and managing booking tables
 */

class BookingsTable {
    constructor(tableId, options = {}) {
        this.tableId = tableId;
        this.options = {
            apiUrl: '/api/v1/bookings?',
            tableSettings: null,
            columns: [],
            embed: [
                "biblio",
                "item+strings", 
                "item.checkout",
                "patron",
                "pickup_library",
                "extended_attributes"
            ],
            order: [[0, "desc"]],
            additionalFilters: {},
            filtersOptions: {},
            ...options
        };
        
        this.extended_attribute_types = null;
        this.authorised_values = null;
        this.table = null;
    }

    /**
     * Initialize the booking table
     */
    async initialize() {
        // Initialize extended attributes
        await this.initializeExtendedAttributes();
        
        // Initialize the table
        this.table = $(`#${this.tableId}`).kohaTable({
            "ajax": {
                "url": this.options.apiUrl
            },
            "embed": this.options.embed,
            "order": this.options.order,
            "columns": this.options.columns,
            ...this.options.tableSettings
        }, this.options.tableSettings, 0, this.options.additionalFilters, this.options.filtersOptions);

        return this.table;
    }

    /**
     * Initialize extended attributes for bookings
     */
    async initializeExtendedAttributes() {
        try {
            const types = await AdditionalFields.fetchAndProcessExtendedAttributes("booking");
            this.extended_attribute_types = types;
            
            const catArray = Object.values(types)
                .map(attr => attr.authorised_value_category_name)
                .filter(Boolean);
                
            this.authorised_values = await AdditionalFields.fetchAndProcessAuthorizedValues(catArray);
            
            return { extended_attribute_types: types, authorised_values: this.authorised_values };
        } catch (error) {
            console.error('Error initializing extended attributes:', error);
            return { extended_attribute_types: {}, authorised_values: {} };
        }
    }

    /**
     * Get extended attributes for use in column definitions
     */
    getExtendedAttributes() {
        return {
            extended_attribute_types: this.extended_attribute_types,
            authorised_values: this.authorised_values
        };
    }

    /**
     * Refresh the table data
     */
    refresh() {
        if (this.table) {
            this.table.DataTable().ajax.reload();
        }
    }

    /**
     * Redraw the table
     */
    redraw() {
        if (this.table) {
            this.table.DataTable().draw();
        }
    }

    /**
     * Get the DataTable instance
     */
    getDataTable() {
        return this.table ? this.table.DataTable() : null;
    }
}

/**
 * Common filter functions for booking tables
 */
const BookingFilters = {
    /**
     * Create a date range filter
     */
    createDateFilter: function(fromSelector, toSelector) {
        return function() {
            let fromdate = $(fromSelector);
            let isoFrom;
            if (fromdate.val() !== '') {
                let selectedDate = fromdate.get(0)._flatpickr.selectedDates[0];
                selectedDate.setHours(0, 0, 0, 0);
                isoFrom = selectedDate.toISOString();
            }

            let todate = $(toSelector);
            let isoTo;
            if (todate.val() !== '') {
                let selectedDate = todate.get(0)._flatpickr.selectedDates[0];
                selectedDate.setHours(23, 59, 59, 999);
                isoTo = selectedDate.toISOString();
            }

            if (isoFrom || isoTo) {
                return { '>=': isoFrom, '<=': isoTo };
            } else {
                return;
            }
        };
    },

    /**
     * Create a library filter
     */
    createLibraryFilter: function(selector) {
        return function() {
            let library = $(selector).find(":selected").val();
            return library;
        };
    },

    /**
     * Create a status filter
     */
    createStatusFilter: function(statuses) {
        return function() {
            return { "-in": statuses };
        };
    },

    /**
     * Create an end date filter for expired items
     */
    createExpiredFilter: function(includeExpired = true) {
        return function() {
            if (includeExpired) {
                let today = new Date();
                return { ">=": today.toISOString() };
            }
        };
    }
};

/**
 * Common column renderers for booking tables
 */
const BookingRenderers = {
    /**
     * Render pickup library column
     */
    pickupLibrary: function(data, type, row, meta) {
        return escape_str(row.pickup_library_id ? row.pickup_library.name : row.pickup_library_id);
    },

    /**
     * Render holding library column
     */
    holdingLibrary: function(data, type, row, meta) {
        return row.item._strings.home_library_id.str || '';
    },

    /**
     * Render title column
     */
    title: function(data, type, row, meta, linkType = 'bookings') {
        return row.biblio ? $biblio_to_html(row.biblio, { link: linkType }) : '';
    },

    /**
     * Render item column
     */
    item: function(data, type, row, meta) {
        if (row.item) {
            return row.item.external_id + " (" + row.booking_id + ")";
        } else {
            return null;
        }
    },

    /**
     * Render callnumber column
     */
    callnumber: function(data, type, row, meta) {
        if (row.item) {
            return row.item.callnumber;
        } else {
            return null;
        }
    },

    /**
     * Render location column
     */
    location: function(data, type, row, meta) {
        if (row.item) {
            if (row.item.checked_out_date) {
                return _("On loan, due: ") + $date(row.item.checked_out_date);
            } else {
                return row.item._strings.location.str;
            }
        } else {
            return null;
        }
    },

    /**
     * Render patron column
     */
    patron: function(data, type, row, meta, options = { display_cardnumber: true, url: true }) {
        return $patron_to_html(row.patron, options);
    },

    /**
     * Render booking dates column
     */
    bookingDates: function(data, type, row, meta) {
        return $date(row.start_date) + ' - ' + $date(row.end_date);
    },

    /**
     * Render start date column
     */
    startDate: function(data, type, row, meta) {
        return row.start_date ? $date(row.start_date) : '';
    },

    /**
     * Render end date column
     */
    endDate: function(data, type, row, meta) {
        return row.end_date ? $date(row.end_date) : '';
    },

    /**
     * Render creation date column
     */
    creationDate: function(data, type, row, meta) {
        return row.creation_date ? $date(row.creation_date) : '';
    },

    /**
     * Render item type column
     */
    itemType: function(data, type, row, meta) {
        return row.item._strings.item_type_id.str || '';
    },

    /**
     * Render extended attributes column
     */
    extendedAttributes: function(data, type, row, meta, extended_attribute_types, authorised_values) {
        return AdditionalFields.renderExtendedAttributesValues(
            data,
            extended_attribute_types,
            authorised_values,
            row.booking_id
        ).join("<br>");
    }
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { BookingsTable, BookingFilters, BookingRenderers };
} 