[%# Common JavaScript functions and configurations for booking templates %]

<script>
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
function getBookingTableColumns(extended_attribute_types, authorised_values, options = {}) {
    const {
        variant = 'default',
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
        linkBiblio = 'bookings',
        patronOptions = { display_cardnumber: true, url: true },
        showBiblioTitle = true,
        showItemData = true
    } = options;

    let columns = [];

    // Booking ID (usually hidden)
    columns.push({
        "data": "booking_id",
        "name": "booking_id",
        "title": _("Booking ID"),
        "visible": false
    });

    // Creation date (optional)
    if (showCreationDate) {
        columns.push({
            "data": "creation_date",
            "name": "creation_date",
            "title": _("Reserved on"),
            "type": "date",
            "searchable": true,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return row.creation_date ? $date(row.creation_date) : '';
            }
        });
    }

    // Status (optional)
    if (showStatus) {
        columns.push({
            data: "",
            title: _("Status"),
            name: "status",
            searchable: false,
            orderable: false,
            visible: variant === 'biblio' ? false : true,
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
                            return _("Expired");
                        }
                        if (isActive(row.start_date, row.end_date)) {
                            return _("Active");
                        }
                        if (dayjs(row.start_date).isAfter(new Date())) {
                            return _("Pending");
                        }
                        return _("New");
                    },
                    cancelled: () =>
                        [_("Cancelled"), row.cancellation_reason]
                            .filter(Boolean)
                            .join(": "),
                    completed: () => _("Completed"),
                };

                const statusText = statusMap[row.status]
                    ? statusMap[row.status]()
                    : _("Unknown");

                const classMap = [
                    { status: _("Expired"), class: "bg-secondary" },
                    { status: _("Cancelled"), class: "bg-secondary" },
                    { status: _("Pending"), class: "bg-warning" },
                    { status: _("Active"), class: "bg-primary" },
                    { status: _("Completed"), class: "bg-info" },
                    { status: _("New"), class: "bg-success" },
                ];

                const badgeClass =
                    classMap.find(mapping => statusText.startsWith(mapping.status))
                        ?.class || "bg-secondary";

                return `<span class="badge rounded-pill ${badgeClass}">${statusText}</span>`;
            }
        });
    }

    // Holding library
    if (showHoldingLibrary) {
        columns.push({
            "data": "item.home_library_id",
            "name": "home_library_id",
            "title": _("Holding library"),
            "searchable": true,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return row.item._strings.home_library_id.str || '';
            }
        });
    }

    // Title
    if (showBiblioTitle) {
        columns.push({
            "data": "biblio.title",
            "name": "title",
            "title": _("Title"),
            "searchable": true,
            "orderable": true,
            "render": function(data,type,row,meta) {
                return row.biblio ? $biblio_to_html(row.biblio, {
                    link: linkBiblio
                }) : '';
            }
        });
    }

    // Item
    if (showItemData) {
        columns.push({
            "data": "item.external_id",
            "name": "itemdata",
            "title": _("Item"),
            "searchable": true,
            "orderable": true,
            "defaultContent": _("Any item"),
            "render": function(data,type,row,meta) {
                if ( row.item ) {
                    return row.item.external_id + " (" + row.booking_id + ")";
                } else {
                    return null;
                }
            }
        });
    }

    // Callnumber (optional)
    if (showCallnumber) {
        columns.push({
            "data": "item.callnumber",
            "name": "callnumber",
            "title": _("Callnumber"),
            "searchable": true,
            "orderable": true,
            "render": function(data,type,row,meta) {
                if ( row.item ) {
                    return row.item.callnumber || '';
                } else {
                    return null;
                }
            }
        });
    }

    // Location (optional)
    if (showLocation) {
        columns.push({
            "data": "item.location",
            "name": "location",
            "title": _("Location"),
            "searchable": true,
            "orderable": false,
            "render": function(data,type,row,meta) {
                if ( row.item ) {
                    if ( row.item.checked_out_date ) {
                        return _("On loan, due: ") + $date(row.item.checked_out_date);
                    } else {
                        return row.item._strings.location.str;
                    }
                } else {
                    return null;
                }
            }
        });
    }

    // Item type (optional)
    if (showItemType) {
        columns.push({
            "data": "item.itype",
            "title": _("Item type"),
            "name": "itemtype",
            "searchable": true,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return row.item._strings.item_type_id.str || '';
            }
        });
    }

    // Patron
    columns.push({
        "data": "patron.firstname:patron.surname",
        "name": "patron",
        "title": _("Patron"),
        "searchable": true,
        "orderable": true,
        "render": function(data, type, row, meta) {
            return $patron_to_html(row.patron, patronOptions);
        }
    });

    // Pickup library
    if (showPickupLibrary) {
        columns.push({
            "data": "pickup_library.name",
            "name": "pickup_library",
            "title": _("Pickup library"),
            "searchable": true,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return row.pickup_library.name || '';
            }
        });
    }

    // Date columns
    if (showBookingDates) {
        columns.push({
            "data": "start_date",
            "name": "start_date",
            "title": _("Booking dates"),
            "type": "date",
            "searchable": true,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return $date(row.start_date) + ' - ' + $date(row.end_date);
            }
        });
    } else if (showStartEndDates) {
        columns.push({
            "data": "start_date",
            "name": "start_date",
            "title": _("Start date"),
            "type": "date",
            "searchable": true,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return $date(row.start_date);
            }
        });
        columns.push({
            "data": "end_date",
            "title": _("End date"),
            "type": "date",
            "searchable": true,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return $date(row.end_date);
            }
        });
    }

    // Extended attributes
    columns.push({
        data: "extended_attributes",
        name: "extended_attributes",
        title: _("Additional fields"),
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
            "data": null,
            "name": "actions",
            "title": _("Actions"),
            "searchable": false,
            "orderable": false,
            "render": function(data, type, row, meta) {
                let result = "";
                let is_cancelled = row.status === "cancelled";
                [% IF CAN_user_circulate_manage_bookings %]
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
                                    ?.filter(attribute => attribute.record_id == row.booking_id)
                                    ?.map(attribute => ({
                                        field_id: attribute.field_id,
                                        value: attribute.value,
                                    })) ?? []
                            )}'
                        >
                            <i class="fa fa-pencil" aria-hidden="true"></i> ${_("Edit")}
                        </button>
                        <button type="button" class="btn btn-default btn-xs cancel-action"
                            data-toggle="modal"
                            data-target="#cancelBookingModal"
                            data-booking="${row.booking_id}">
                            <i class="fa fa-trash" aria-hidden="true"></i> ${_("Cancel")}
                        </button>`;
                }
                [% END %]
                return result;
            }
        });
    }

    return columns;
}

/**
 * Get unified library filter options
 * @param {string} [variant='default'] - The variant to use for filter options
 *   - 'default': Standard library filter options for all libraries
 *   - 'pending': Same as default, but can be extended for pending-specific filters
 * @returns {Object} Filter options object for KohaTable
 */
function getLibraryFilterOptions(variant = 'default') {
    // Use the global BOOKINGS_LIBRARIES_DATA if available, otherwise return empty
    let all_libraries = (typeof BOOKINGS_LIBRARIES_DATA !== 'undefined' ? BOOKINGS_LIBRARIES_DATA : []).map(e => {
        e['_id'] = e.branchcode;
        e['_str'] = e.branchname;
        return e;
    });
    
    const filterOptions = {
        [1] : () => all_libraries,
    };

    // Add variant-specific options
    switch (variant) {
        case 'pending':
            // For pending bookings, we might want different filter options
            return filterOptions;
        case 'default':
        default:
            return filterOptions;
    }
}

/**
 * Create a unified date filter function
 * @param {string} fromSelector - CSS selector for the "from" date input
 * @param {string} toSelector - CSS selector for the "to" date input
 * @param {string} [variant='default'] - The variant to use (currently unused, for future extensibility)
 * @returns {Function} A function that returns date filter object for KohaTable
 */
function createDateFilter(fromSelector, toSelector, variant = 'default') {
    return function() {
        let fromdate = $(fromSelector);
        let isoFrom;
        if ( fromdate.val() !== '' ) {
            let selectedDate = fromdate.get(0)._flatpickr.selectedDates[0];
            selectedDate.setHours(0, 0, 0, 0);
            isoFrom = selectedDate.toISOString();
        }

        let todate = $(toSelector);
        let isoTo;
        if ( todate.val() !== '' ) {
            let selectedDate = todate.get(0)._flatpickr.selectedDates[0];
            selectedDate.setHours(23, 59, 59, 999);
            isoTo = selectedDate.toISOString();
        }

        if ( isoFrom || isoTo ) {
            return { '>=': isoFrom, '<=': isoTo };
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
function createAdditionalFilters(variant = 'default', options = {}) {
    const {
        fromSelector = "#from",
        toSelector = "#to",
        holdingLibrarySelector = "#holding_library",
        pickupLibrarySelector = "#pickup_library"
    } = options;

    switch (variant) {
        case 'pending':
            return {
                start_date: createDateFilter(fromSelector, toSelector, variant),
                'item.holding_library_id': function() {
                    let library = $(holdingLibrarySelector).find(":selected").val();
                    return library;
                },
                'pickup_library_id': function() {
                    let library = $(pickupLibrarySelector).find(":selected").val();
                    return library;
                }
            };
        case 'default':
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
function getBookingsEmbed(variant = 'default') {
    switch (variant) {
        case 'biblio':
            return [
                "item",
                "patron",
                "pickup_library",
                "extended_attributes"
            ];
        case 'default':
        default:
            return [
                "biblio",
                "item+strings",
                "item.checkout",
                "patron",
                "pickup_library",
                "extended_attributes"
            ];
    }
}

/**
 * Get unified URL configuration based on variant
 * @param {string} [variant='default'] - The variant to use for URL configuration
 * @param {string} [biblionumber] - Biblionumber for biblio-specific variants
 * @returns {string} API endpoint URL
 */
function getBookingsUrl(variant = 'default', biblionumber) {
    switch (variant) {
        case 'biblio':
            if (!biblionumber) {
                throw new Error('biblionumber is required for biblio variant');
            }
            return `/api/v1/biblios/${biblionumber}/bookings`;
        case 'pending':
        case 'default':
        default:
            return '/api/v1/bookings?';
    }
}

/**
 * Get column filter configuration based on variant
 * @param {string} [variant='default'] - The variant to use for column filter configuration
 * @returns {number} Column filter flag (1 for enabled, 0 for disabled)
 */
function getBookingsColumnFilterFlag(variant = 'default') {
    switch (variant) {
        case 'pending':
            return 1; // Enable column filters for pending bookings
        case 'biblio':
        case 'default':
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
        variant = 'default',
        url,
        biblionumber,
        order,
        additionalFilters = createAdditionalFilters(variant, options),
        filterOptions = getLibraryFilterOptions(variant),
        embed = getBookingsEmbed(variant),
        columnOptions = {}
    } = options;

    let finalUrl = url ?? getBookingsUrl(variant, biblionumber);

    // Set default column options based on variant
    let defaultColumnOptions = {
        showCallnumber: false,
        showLocation: false,
        showPickupLibrary: true,
        showBookingDates: true,
        patronOptions: { display_cardnumber: true, url: true }
    };

    // Merge with provided column options
    const finalColumnOptions = { ...defaultColumnOptions, ...columnOptions };

    return $(tableElement).kohaTable({
        "ajax": {
            "url": finalUrl
        },
        "embed": embed,
        "order": order,
        "columns": getBookingTableColumns(
            options.extended_attribute_types, 
            options.authorised_values, 
            { ...finalColumnOptions, variant: variant }
        )
    }, tableSettings, getBookingsColumnFilterFlag(variant), additionalFilters, filterOptions);
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
        variant: 'pending'
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
function createBiblioBookingsTable(tableElement, tableSettings, biblionumber, options = {}) {
    return createBookingsTable(tableElement, tableSettings, {
        ...options,
        variant: 'biblio',
        biblionumber: biblionumber
    });
}

</script> 
