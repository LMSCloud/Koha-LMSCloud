/* keep tidy */
// Bookings
var bookings_table;
$(document).ready(function () {
    // Load bookings table on tab selection
    let filter_expired = true;
    $('a[data-tabname="bookings"]').on("click", function () {
        let additional_filters = {
            patron_id: patron_borrowernumber,
            end_date: function () {
                if (filter_expired) {
                    let today = new Date();
                    return { ">=": today.toISOString() }
                } else {
                    return;
                }
            }
        };

        if (!bookings_table) {

            var bookings_table_url = "/api/v1/bookings";
            bookings_table = $("#bookings_table").kohaTable(
                {
                    ajax: {
                        url: bookings_table_url,
                    },
                    embed: ["biblio", "item", "patron"],
                    columns: [
                        {
                            data: "booking_id",
                            title: __("Booking ID"),
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
                                if (row.item) {
                                    return (
                                        row.item.external_id +
                                        " (" +
                                        row.booking_id +
                                        ")"
                                    );
                                } else {
                                    return null;
                                }
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
                            data: "",
                            title: __("Actions"),
                            class: "actions",
                            searchable: false,
                            orderable: false,
                            render: function (data, type, row, meta) {
                                let result = "";
                                if (CAN_user_circulate_manage_bookings) {
                                    result +=
                                        '<button type="button" class="btn btn-default btn-xs cancel-action" data-toggle="modal" data-target="#cancelBookingModal" data-booking="' +
                                        row.booking_id +
                                        '"><i class="fa fa-trash" aria-hidden="true"></i> ' +
                                        __("Cancel") +
                                        "</button>";
                                }
                                return result;
                            },
                        },
                    ],
                },
                table_settings_bookings_table, 0, additional_filters
            );
        }
    });

    var txtActivefilter = _("Show expired");
    var txtInactivefilter = _("Hide expired");
    $("#expired_filter").on("click", function () {
        if ($(this).hasClass('filtered')) {
            filter_expired = false;
            $(this).html('<i class="fa fa-filter"></i> ' + txtInactivefilter);
        } else {
            filter_expired = true;
            $(this).html('<i class="fa fa-bars"></i> ' + txtActivefilter);
        }
        bookings_table.DataTable().draw();
        $(this).toggleClass('filtered');
    });

});
