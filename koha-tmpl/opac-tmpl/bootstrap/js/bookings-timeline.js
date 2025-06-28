(() => {
    function processBookingsData(loggedInUser, bookings, bookableItems) {
        const visSetItems = new vis.DataSet([
            { id: 0, content: __("Record level") },
            ...bookableItems.map(bookableItem => ({
                id: bookableItem.itemnumber,
                content: __("Item %s").format(bookableItem.barcode),
            })),
        ]);

        const visSetBookings = new vis.DataSet(
            bookings.map(booking => {
                const isActive = ["new", "pending", "active"].includes(
                    booking.status
                );
                const patronContent = `${__("Booked by")}: ${loggedInUser == booking.patron_id ? __("You") : __("Another patron")}`;
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
            let startDate = dayjs(data.start);
            let endDate = dayjs(data.end).endOf("day");

            const island = document.querySelector("booking-modal-island");
            if (island) {
                const currentBooking = visSetBookings.get(data.id);
                island.bookingId = data.id;
                island.itemId = data.group;
                island.patronId = data.patron;
                island.pickupLibraryId = data.pickup_library;
                island.startDate = startDate.toISOString();
                island.endDate = endDate.toISOString();
                island.extendedAttributes = currentBooking.extended_attributes
                    ? currentBooking.extended_attributes.map(attribute => ({
                          field_id: attribute.field_id,
                          value: attribute.value,
                      }))
                    : [];
                island.open = true;

                const onModalClose = e => {
                    if (e.detail.success) {
                        callback(data);
                    } else {
                        callback(null);
                    }
                    island.removeEventListener("close", onModalClose);
                };
                island.addEventListener("close", onModalClose);
            } else {
                callback(null); // No modal available
            }
        };
    }

    function createTempModalTrigger(bookingId, modalId) {
        const tempButton = document.createElement("button");
        tempButton.setAttribute("data-booking", bookingId);
        tempButton.setAttribute("data-bs-toggle", "modal");
        tempButton.setAttribute("data-bs-target", `#${modalId}`);
        tempButton.style.display = "none";
        document.body.appendChild(tempButton);

        // Trigger the modal using the button
        tempButton.click();

        // Clean up the temporary button
        setTimeout(() => {
            if (document.body.contains(tempButton)) {
                document.body.removeChild(tempButton);
            }
        }, 100);
    }

    function handleOnRemove(item, callback) {
        const cancelBookingModal =
            document.getElementById("cancelBookingModal");
        if (!cancelBookingModal) {
            return;
        }

        // Create and trigger the modal using a temporary button
        createTempModalTrigger(item.id, "cancelBookingModal");

        const modalHideHandler = function () {
            if (cancel_success) {
                cancel_success = 0;
                callback(item);
            } else {
                callback(null);
            }
            $("#cancelBookingModal").off("hidden.bs.modal", modalHideHandler);
        };

        $("#cancelBookingModal").on("hidden.bs.modal", modalHideHandler);
    }

    function initBookingsTimeline({
        containerId,
        loadingIndicatorId,
        loggedInUser,
        bookings,
        bookableItems,
        visTimelineOptions
    }) {
        const container = document.getElementById(containerId);
        const loadingIndicator = document.getElementById(loadingIndicatorId);
        const { visSetItems, visSetBookings } = processBookingsData(
            loggedInUser,
            bookings,
            bookableItems
        );

        const handleOnMoving = makeHandleOnMoving(visSetBookings);
        const handleOnMove = makeHandleOnMove(visSetBookings);
        const bookingsTimelineOptions = {
            stack: true,
            editable: false,
            verticalScroll: true,
            orientation: {
                axis: "both",
                item: "top",
            },
            timeAxis: { scale: "day", step: 1 },
            dataAttributes: ["booking"],
            autoResize: false,
            onInitialDrawComplete: () => {
                // hide spinner after initialization is complete
                loadingIndicator?.classList.replace("d-flex", "d-none");
            },
            snap: handleSnap, // always snap to full days, independent of the scale
            onMoving: handleOnMoving, // prevent overlapping bookings
            onMove: handleOnMove,
            onRemove: handleOnRemove,
            ...visTimelineOptions,
        };

        const bookingsTimeline = new vis.Timeline(
            container,
            visSetBookings,
            visSetItems,
            bookingsTimelineOptions
        );

        return bookingsTimeline;
    }

    function BookingsTimeline({
        containerId = "bookings-timeline",
        loadingIndicatorId = "bookings-timeline-loading",
        loggedInUser,
        bookings,
        bookableItems,
        visTimelineOptions = {}
    }) {
        return {
            init: () => {
                if (
                    !containerId ||
                    !loadingIndicatorId ||
                    !loggedInUser ||
                    !bookings ||
                    !bookableItems
                ) {
                    console.debug(
                        "Missing required parameters for BookingsTimeline"
                    );
                }

                return initBookingsTimeline({
                    containerId,
                    loadingIndicatorId,
                    loggedInUser,
                    bookings,
                    bookableItems,
                    visTimelineOptions
                });
            },
        };
    }

    window["BookingsTimeline"] = BookingsTimeline;
})();
