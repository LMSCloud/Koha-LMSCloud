/// <reference path="./globals.d.ts" />
// @ts-check
/**
 * Column configuration and rendering for booking tables
 */

import { dayjsFn, $dateFn, $biblioToHtmlFn, $patronToHtmlFn, additionalFields, canManageBookings } from "./utils.js";

// shared helpers moved to utils.js

/**
 * Initialize extended attributes for bookings
 * @returns {Promise<any>} Promise that resolves to an object containing extended_attribute_types and authorised_values
 */
export function initializeBookingExtendedAttributes() {
    /** @type {any} */
    let extended_attribute_types;
    /** @type {any} */
    let authorised_values;

    return additionalFields()
        .fetchAndProcessExtendedAttributes("booking")
        .then((/** @type {any} */ types) => {
            extended_attribute_types = types;
            const catArray = Object.values(types)
                .map((/** @type {any} */ attr) => attr.authorised_value_category_name)
                .filter(Boolean);
            return additionalFields().fetchAndProcessAuthorizedValues(catArray);
        })
        .then((/** @type {any} */ values) => {
            authorised_values = values;
            return { extended_attribute_types, authorised_values };
        });
}

/**
 * Filter function for extended attributes to only show fields with actual values
 * @param {Array<any>} attributes - Array of extended attributes from the API
 * @param {string} recordId - The booking ID to filter attributes by
 * @returns {Array<any>} Filtered array of attributes with non-empty values
 */
export function filterExtendedAttributesWithValues(attributes, recordId) {
    // Filter out attributes that have null, undefined, or empty string values
    return (attributes || []).filter(attr => {
        return (
            attr.record_id == recordId &&
            attr.value != null &&
            attr.value !== ""
        );
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
 * @returns {Array<any>} Array of column definitions for DataTables
 */
export function getBookingTableColumns(
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                return row.creation_date ? $dateFn()(row.creation_date) : "";
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                /** @param {string} date */
                const isExpired = date => dayjsFn()(date).isBefore(new Date());
                /** @param {string} startDate @param {string} endDate */
                const isActive = (startDate, endDate) => {
                    const now = dayjsFn()();
                    return (
                        now.isAfter(dayjsFn()(startDate)) &&
                        now.isBefore(dayjsFn()(endDate).add(1, "day"))
                    );
                };

                /** @type {any} */
                const statusMap = {
                    new: () => {
                        if (isExpired(row.end_date)) {
                            return __("Expired");
                        }
                        if (isActive(row.start_date, row.end_date)) {
                            return __("Active");
                        }
                        if (dayjsFn()(row.start_date).isAfter(new Date())) {
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                return row.biblio
                    ? $biblioToHtmlFn()(row.biblio, {
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                if (row.item) {
                    if (row.item.checked_out_date) {
                        return (
                            __("On loan, due: ") +
                            $dateFn()(row.item.checked_out_date)
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
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
        /** @type {(data:any, type:any, row:any, meta:any)=>any} */
        render: function (_data, _type, row, _meta) {
            return $patronToHtmlFn()(row.patron, patronOptions);
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                return (
                    $dateFn()(row.start_date) + " - " + $dateFn()(row.end_date)
                );
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                return $dateFn()(row.start_date);
            },
        });
        columns.push({
            data: "end_date",
            title: __("End date"),
            type: "date",
            searchable: true,
            orderable: true,
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                return $dateFn()(row.end_date);
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
        /** @type {(data:any, type:any, row:any, meta:any)=>any} */
        render: function (data, _type, row, _meta) {
            // Filter to only show attributes with actual values
            const filteredAttributes = filterExtendedAttributesWithValues(
                data,
                row.booking_id
            );

            // Only render if there are attributes with values
            if (filteredAttributes.length === 0) {
                return "";
            }

            return additionalFields().renderExtendedAttributesValues(
                filteredAttributes,
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
            /** @type {(data:any, type:any, row:any, meta:any)=>any} */
            render: function (_data, _type, row, _meta) {
                let result = "";
                let is_cancelled = row.status === "cancelled";
                if (
                    canManageBookings()
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
                                        (/** @type {any} */ attribute) =>
                                            attribute.record_id ==
                                            row.booking_id
                                    )
                                    ?.map((/** @type {any} */ attribute) => ({
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
