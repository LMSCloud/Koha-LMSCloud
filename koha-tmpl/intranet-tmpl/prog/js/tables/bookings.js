/* global __ $biblio_to_html $date AdditionalFilters BookingsTable patron_borrowernumber table_settings_bookings_table */

// Bookings
var bookings_table;
$(document).ready(function () {
    const af = AdditionalFilters.init([
        "filter-completed",
        "filter-cancelled",
    ]).onChange(() => {
        if (bookings_table) {
            bookings_table.DataTable().ajax.reload();
        }
    });

    const additional_filters = {
        patron_id: patron_borrowernumber,
        ...af.build({
            status: ({ filters, isNotApplied }) => {
                const defaults = ["new", "issued"];
                const filtered = [...defaults];
                if (isNotApplied(filters["filter-cancelled"])) {
                    filtered.push("cancelled");
                }
                if (isNotApplied(filters["filter-completed"])) {
                    filtered.push("completed");
                }
                return { "-in": filtered };
            },
        }),
    };

    // Load bookings table on page load
    if (window.location.hash === "#bookings_panel") {
        loadBookingsTable();
    }
    // Load bookings table on tab selection
    $("#bookings-tab").on("click", function () {
        loadBookingsTable();
    });

    function loadBookingsTable() {
        if (!bookings_table) {
            var extended_attribute_types;
            var authorised_values;
            if (typeof AdditionalFields !== "undefined") {
                AdditionalFields.fetchAndProcessExtendedAttributes("booking")
                    .then(types => {
                        extended_attribute_types = types;
                        const catArray = Object.values(types)
                            .map(attr => attr.authorised_value_category_name)
                            .filter(Boolean);
                        return AdditionalFields.fetchAndProcessAuthorizedValues(
                            catArray
                        );
                    })
                    .then(values => {
                        authorised_values = values;
                    })
                    .catch(e => {
                        console.warn(
                            "Could not load additional fields for bookings:",
                            e
                        );
                    });
            }

            var bookings_table_url = "/api/v1/bookings";
            bookings_table = $("#bookings_table").kohaTable(
                {
                    ajax: {
                        url: bookings_table_url,
                    },
                    embed: ["biblio", "item", "item.checkout", "patron", "extended_attributes"],
                    createdRow: function (row, data) {
                        BookingsTable.highlightRow(data, row);
                    },
                    columns: [
                        {
                            data: "booking_id",
                            title: __("Booking ID"),
                        },
                        {
                            data: "",
                            title: __("Status"),
                            name: "status",
                            searchable: false,
                            orderable: false,
                            render: function (data, type, row, meta) {
                                return BookingsTable.statusBadge(row);
                            },
                        },
                        {
                            data: "biblio.title",
                            title: __("Title"),
                            searchable: true,
                            orderable: true,
                            render: function (data, type, row, meta) {
                                return $biblio_to_html(row.biblio, {
                                    link: "bookings",
                                });
                            },
                        },
                        {
                            data: "item.external_id",
                            title: __("Item"),
                            searchable: true,
                            orderable: true,
                            defaultContent: __("Any item"),
                            render: function (data, type, row, meta) {
                                return BookingsTable.itemContent(row);
                            },
                        },
                        {
                            data: "start_date",
                            title: __("Start date"),
                            searchable: true,
                            orderable: true,
                            render: function (data, type, row, meta) {
                                return $date(row.start_date);
                            },
                        },
                        {
                            data: "end_date",
                            title: __("End date"),
                            searchable: true,
                            orderable: true,
                            render: function (data, type, row, meta) {
                                return $date(row.end_date);
                            },
                        },
                        {
                            data: "extended_attributes",
                            title: _("Additional fields"),
                            searchable: false,
                            orderable: false,
                            render: function (data, type, row, meta) {
                                // Filter to only show attributes with actual values
                                const filteredAttributes = (data || []).filter(
                                    attr => {
                                        return (
                                            attr.record_id == row.booking_id &&
                                            attr.value != null &&
                                            attr.value !== ""
                                        );
                                    }
                                );

                                // Only render if there are attributes with values
                                if (filteredAttributes.length === 0) {
                                    return "";
                                }

                                if (typeof AdditionalFields === "undefined")
                                    return "";
                                return AdditionalFields.renderExtendedAttributesValues(
                                    filteredAttributes,
                                    extended_attribute_types,
                                    authorised_values,
                                    row.booking_id
                                ).join("<br>");
                            },
                        },
                        {
                            data: "",
                            title: __("Actions"),
                            class: "actions",
                            searchable: false,
                            orderable: false,
                            render: function (data, type, row, meta) {
                                return BookingsTable.actionsContent(row);
                            },
                        },
                    ],
                },
                table_settings_bookings_table,
                0,
                additional_filters
            );
        }
    }
});
