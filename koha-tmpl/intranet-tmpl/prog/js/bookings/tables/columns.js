/// <reference path="./globals.d.ts" />
// @ts-check
/**
 * Column configuration and rendering for booking tables
 */

import {
    $dateFn,
    $biblioToHtmlFn,
    $patronToHtmlFn,
    additionalFields,
    canManageBookings,
    escapeAttr,
} from "./utils.js";
import { calculateBookingStatus } from "./features.js";

/**
 * @typedef {Object} BookingRow
 * @property {number|string} booking_id
 * @property {number|string} biblio_id
 * @property {number|string} patron_id
 * @property {number|string|null} item_id
 * @property {string} status
 * @property {string} start_date
 * @property {string} end_date
 * @property {{ name: string }} pickup_library
 * @property {{
 *   external_id?: string,
 *   callnumber?: string,
 *   location?: string,
 *   checked_out_date?: string,
 *   item_type_id?: string|number,
 *   _strings?: { location?: { str: string }, item_type_id?: { str: string }, home_library_id?: { str: string } }
 * }} item
 * @property {{ title?: string }} biblio
 * @property {Array<{ record_id: string|number, field_id: string|number, value: any }>} extended_attributes
 */

/**
 * Render a status badge for a booking row
 * @param {BookingRow} row
 * @returns {string}
 */
function renderStatusBadge(row) {
    const derived = calculateBookingStatus(
        row.status,
        row.start_date,
        row.end_date
    );
    /** @type {Record<string, string>} */
    const statusTextMap = {
        expired: __("Expired"),
        cancelled: __("Cancelled"),
        pending: __("Pending"),
        active: __("Active"),
        completed: __("Completed"),
        new: __("New"),
        unknown: __("Unknown"),
    };
    const statusText = statusTextMap[derived] || __("Unknown");
    const classMap = [
        { status: __("Expired"), class: "bg-secondary" },
        { status: __("Cancelled"), class: "bg-secondary" },
        { status: __("Pending"), class: "bg-warning" },
        { status: __("Active"), class: "bg-primary" },
        { status: __("Completed"), class: "bg-info" },
        { status: __("New"), class: "bg-success" },
    ];
    const badgeClass =
        classMap.find(m => statusText.startsWith(m.status))?.class ||
        "bg-secondary";
    return `<span class="badge rounded-pill ${badgeClass}">${statusText}</span>`;
}

/**
 * Render item cell
 * @param {BookingRow} row
 * @returns {string|null}
 */
function renderItemCell(row) {
    if (!row.item) return null;
    return `${escapeAttr(row.item.external_id)} (${escapeAttr(
        row.booking_id
    )})`;
}

/**
 * Render patron cell
 * @param {any} patron
 * @param {any} options
 * @returns {string}
 */
function renderPatronCell(patron, options) {
    return $patronToHtmlFn()(patron, options);
}

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
                .map(
                    (/** @type {any} */ attr) =>
                        attr.authorised_value_category_name
                )
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
 * @param {boolean} [options.showActions=false] - Whether to show the actions column
 * @param {boolean} [options.showEditAction=true] - Whether to show the edit button in the actions column
 * @param {boolean} [options.showDeleteAction=true] - Whether to show the delete/cancel button in the actions column
 * @param {boolean} [options.showConvertToCheckoutAction] - Whether to show the convert to checkout button in the actions column
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
        showActions = false,
        showEditAction = true,
        showDeleteAction = true,
        showConvertToCheckoutAction = true,
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
                return renderStatusBadge(row);
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
                return row.biblio ? $biblioToHtmlFn()(row.biblio, { link: linkBiblio }) : "";
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
            /** @type {(data:any, type:any, row:BookingRow)=>any} */
            render: function (_data, _type, row) {
                return renderItemCell(row);
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
        /** @type {(data:any, type:any, row:any)=>any} */
        render: function (_data, _type, row) {
            return renderPatronCell(row.patron, patronOptions);
        },
    });

    // Pickup library
    if (showPickupLibrary) {
        columns.push({
            // Use the ID for searching/filtering; render will still show the name
            data: "pickup_library_id",
            // Important: use API field name so server-side filtering targets booking.pickup_library_id
            name: "pickup_library_id",
            title: __("Pickup library"),
            searchable: true,
            orderable: true,
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
                return $dateFn()(row.start_date);
            },
        });
        columns.push({
            data: "end_date",
            name: "end_date",
            title: __("End date"),
            type: "date",
            searchable: true,
            orderable: true,
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
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
        /** @type {(data:any, type:any, row:any)=>any} */
        render: function (data, _type, row) {
            // Filter to only show attributes with actual values
            const filteredAttributes = filterExtendedAttributesWithValues(
                data,
                row.booking_id
            );

            // Only render if there are attributes with values
            if (filteredAttributes.length === 0) {
                return "";
            }

            return additionalFields()
                .renderExtendedAttributesValues(
                    filteredAttributes,
                    extended_attribute_types,
                    authorised_values,
                    row.booking_id
                )
                .join("<br>");
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
            /** @type {(data:any, type:any, row:any)=>any} */
            render: function (_data, _type, row) {
                if (!canManageBookings()) return "";
                const isReadOnly = ["cancelled", "completed"].includes(row.status);
                if (isReadOnly) return "";
                const ext = (row.extended_attributes || [])
                    .filter(
                        (/** @type {{record_id:string|number}} */ a) =>
                            a && String(a.record_id) === String(row.booking_id)
                    )
                    .map(
                        (
                            /** @type {{field_id:string|number, value:any}} */ a
                        ) => ({ field_id: a.field_id, value: a.value })
                    );
                const attrs = JSON.stringify(ext);
                let html = "";
                if (showEditAction) {
                    html += `
                        <button
                            type="button"
                            class="btn btn-default btn-xs edit-action"
                            data-booking-modal
                            data-booking="${escapeAttr(row.booking_id)}"
                            data-biblionumber="${escapeAttr(row.biblio_id)}"
                            data-itemnumber="${escapeAttr(row.item_id)}"
                            data-patron="${escapeAttr(row.patron_id)}"
                            data-pickup_library="${escapeAttr(row.pickup_library_id)}"
                            data-start_date="${escapeAttr(row.start_date)}"
                            data-end_date="${escapeAttr(row.end_date)}"
                            data-item_type_id="${escapeAttr(row.item?.item_type_id)}"
                            data-extended_attributes='${escapeAttr(attrs)}'
                        >
                            <i class="fa fa-pencil" aria-hidden="true"></i> ${__("Edit")}
                        </button>`;
                }
                if (showDeleteAction) {
                    html += `
                        <button type="button" class="btn btn-default btn-xs cancel-action"
                            data-toggle="modal"
                            data-target="#cancelBookingModal"
                            data-booking="${escapeAttr(row.booking_id)}">
                            <i class="fa fa-trash" aria-hidden="true"></i> ${__("Cancel")}
                        </button>`;
                }
                if (showConvertToCheckoutAction) {
                    html += `
                        <form name="checkout-transform" method="post" action="/cgi-bin/koha/circ/circulation.pl?borrowernumber=${escapeAttr(row.patron_id)}">
                            <input type="hidden" name="borrowernumber" value="${escapeAttr(row.patron_id)}"/>
                            <input type="hidden" name="barcode" value="${escapeAttr(row.item?.external_id)}"/>
                            <input type="hidden" name="duedatespec" value="${escapeAttr(row.end_date)}"/>
                            <button class="btn btn-default btn-xs convert-to-checkout-action" type="submit">
                                <i class="fa fa-check-circle" aria-hidden="true"></i> ${__("Convert to checkout")}
                            </button>
                        </form>
                    `
                }
                return html;
            },
        });
    }

    return columns;
}
