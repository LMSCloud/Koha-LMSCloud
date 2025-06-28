[%# Common JavaScript functions and configurations for booking templates %]

<script>
[%# Initialize extended attributes for bookings %]
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

[%# Common column definitions for booking tables %]
function getBookingTableColumns(extended_attribute_types, authorised_values, options = {}) {
    const {
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
        "title": _("Booking ID"),
        "visible": false
    });

    // Creation date (optional)
    if (showCreationDate) {
        columns.push({
            "data": "creation_date",
            "title": _("Reserved on"),
            "type": "date",
            "searchable": false,
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
            visible: false,
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
            "data": "item._strings.home_library_id.str",
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
            "title": _("Callnumber"),
            "searchable": true,
            "orderable": true,
            "render": function(data,type,row,meta) {
                if ( row.item ) {
                    return row.item.callnumber;
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
            "title": _("Location"),
            "searchable": false,
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
            "data": "item._strings.item_type_id.str",
            "title": _("Item type"),
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
            "title": _("Pickup library"),
            "searchable": true,
            "orderable": true,
            "render": function( data, type, row, meta ) {
                return row.pickup_library ? row.pickup_library.name : '';
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
            "searchable": false,
            "orderable": true,
            "render": function(data, type, row, meta) {
                return $date(row.start_date) + ' - ' + $date(row.end_date);
            }
        });
    } else if (showStartEndDates) {
        columns.push({
            "data": "start_date",
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

[%# Common library filter options %]
function getLibraryFilterOptions() {
    // Use the global BOOKINGS_LIBRARIES_DATA if available, otherwise return empty
    let all_libraries = (typeof BOOKINGS_LIBRARIES_DATA !== 'undefined' ? BOOKINGS_LIBRARIES_DATA : []).map(e => {
        e['_id'] = e.branchcode;
        e['_str'] = e.branchname;
        return e;
    });
    
    return {
        [1] : () => all_libraries,
    };
}

[%# Common date filter function %]
function createDateFilter(fromSelector, toSelector) {
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

[%# Common additional filters for pending bookings %]
function createPendingBookingsFilters() {
    return {
        start_date: createDateFilter("#from", "#to"),
        'item.holding_library_id': function() {
            let library = $("#holding_library").find(":selected").val();
            return library;
        },
        'pickup_library_id': function() {
            let library = $("#pickup_library").find(":selected").val();
            return library;
        }
    };
}

[%# Common embed configuration for pending bookings %]
function getPendingBookingsEmbed() {
    return [
        "biblio",
        "item+strings",
        "item.checkout",
        "patron",
        "pickup_library",
        "extended_attributes"
    ];
}

[%# Common table configuration for pending bookings %]
function createPendingBookingsTable(tableElement, tableSettings, options = {}) {
    const {
        url = '/api/v1/bookings?',
        order = [[ 7, "asc" ]], // Default order by start_date ascending
        additionalFilters = createPendingBookingsFilters(),
        filterOptions = getLibraryFilterOptions(),
        embed = getPendingBookingsEmbed()
    } = options;

    return $(tableElement).kohaTable({
        "ajax": {
            "url": url
        },
        "embed": embed,
        "order": order,
        "columns": getBookingTableColumns(
            options.extended_attribute_types, 
            options.authorised_values, 
            {
                showCallnumber: true,
                showLocation: true,
                showPickupLibrary: true,
                showBookingDates: true,
                patronOptions: { display_cardnumber: true, url: true }
            }
        )
    }, tableSettings, 1, additionalFilters, filterOptions);
}
</script> 