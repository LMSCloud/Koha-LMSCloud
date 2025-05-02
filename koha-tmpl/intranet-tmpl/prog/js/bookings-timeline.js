(() => {
    function processBookingsData(bookings, bookableItems) {
        const visSetItems = new vis.DataSet([
            { id: 0, content: __("Record level") },
            ...bookableItems.map(bookableItem => ({
                id: bookableItem.item_id,
                content: __("Item %s").format(bookableItem.external_id),
            })),
        ]);

        const visSetBookings = new vis.DataSet(
            bookings.map(booking => {
                const isActive = ["new", "pending", "active"].includes(
                    booking.status
                );
                
                const patronContent  = booking.patron
                    ? $patron_to_html(booking.patron, { display_cardnumber: true, url: true })
                    : __("Unknown patron");
                
                return {
                    id: booking.booking_id,
                    booking: booking.booking_id,
                    patron: booking.patron_id,
                    pickup_library: booking.pickup_library_id,
                    start: dayjs(booking.start_date).toDate(),
                    end: dayjs(booking.end_date).toDate(),
                    extended_attributes: booking.extended_attributes,
                    content: !isActive
                        ? `<s>${patronContent}</s>`
                        : patronContent,
                    type: "range",
                    group: booking.item_id ?? 0,
                    className: booking.status === 'cancelled' ? 'cancelled' : ''
                };
            })
        );

        return { visSetItems, visSetBookings };
    }

    function handleSnap(date) {
        const MS_PER_MINUTE = 60 * 1000;
        const MS_PER_HOUR = 60 * MS_PER_MINUTE;
        const MS_PER_DAY = 24 * MS_PER_HOUR;
        const offset = date.getTimezoneOffset() * MS_PER_MINUTE;
        const seconds = Math.round(date / MS_PER_DAY) * MS_PER_DAY;
        return seconds + offset;
    }

    function makeHandleOnMoving(visSetBookings) {
        return function (item, callback) {
            const overlapping = visSetBookings.get({
                filter: testItem =>
                    testItem.id !== item.id &&
                    testItem.group === item.group &&
                    item.start < testItem.end &&
                    item.end > testItem.start,
            });

            if (!overlapping.length) callback(item);
        };
    }

    function makeHandleOnMove(visSetBookings) {
        return function (data, callback) {
            // For intranet, we'll use a simpler approach - just show an alert
            // In the future, this could open a proper editing modal
            alert(__("To modify a booking, please cancel the existing booking and create a new one."));
            callback(null); // Revert the move
        };
    }

    function handleOnRemove(item, callback) {
        $("#cancelBookingModal").modal(
            "show",
            $(`<button data-booking-id="${item.id}"></button>`)
        );
        
        const modalHideHandler = function () {
            if (window.cancel_success) {
                window.cancel_success = 0;
                callback(item);
            } else {
                callback(null);
            }
            $("#cancelBookingModal").off("hide.bs.modal", modalHideHandler);
        };
        
        $("#cancelBookingModal").on("hide.bs.modal", modalHideHandler);
    }

    function init({
        containerId,
        bookings,
        bookableItems
    }) {
        const container = document.getElementById(containerId);
        const loadingEl = document.getElementById('bookings-timeline-loading');
        
        const { visSetItems, visSetBookings } = processBookingsData(
            bookings,
            bookableItems
        );

        const handleOnMoving = makeHandleOnMoving(visSetBookings);
        const handleOnMove = makeHandleOnMove(visSetBookings);

        const options = {
            stack: true,
            editable: {
                remove: window.CAN_user_circulate_manage_bookings,
                updateTime: false,
                updateGroup: false
            },
            verticalScroll: true,
            orientation: {
                axis: "both",
                item: "top",
            },
            timeAxis: { scale: "day", step: 1 },
            dataAttributes: ["booking"],
            autoResize: false,
            onInitialDrawComplete: function() {
                if (loadingEl) {
                    loadingEl.style.display = 'none';
                }
            },
            snap: handleSnap,
            onMoving: handleOnMoving,
            onMove: handleOnMove,
            onRemove: window.CAN_user_circulate_manage_bookings ? handleOnRemove : undefined,
        };

        const timeline = new vis.Timeline(
            container,
            visSetBookings,
            visSetItems,
            options
        );

        return timeline;
    }
    
    // Expose the init function to the global scope
    window.BookingsTimeline = {
        init: init
    };
})(); 