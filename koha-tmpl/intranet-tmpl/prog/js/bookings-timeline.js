(() => {
    // Timeline item styles
    // Using inline styles because vis-timeline's CSS has higher specificity than utility classes
    const TIMELINE_STYLES = {
        cancelled: 'background-color: var(--bookings-timeline-bg-cancelled); color: var(--bookings-timeline-text-cancelled); text-decoration: line-through;',
        checkout: 'background-color: var(--bookings-timeline-bg-checkout); color: var(--bookings-timeline-text-checkout); font-weight: bold;'
    };

    function processBookingsData(bookings, bookableItems, checkouts = []) {
        const visSetItems = new vis.DataSet([
            { id: 0, content: __("Record level") },
            ...bookableItems.map(bookableItem => ({
                id: bookableItem.item_id,
                content: __("Item %s").format(bookableItem.external_id),
            })),
        ]);

        // Process bookings
        const bookingItems = bookings.map(booking => {
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
                className: booking.status === 'cancelled' ? 'cancelled' : '',
                style: booking.status === 'cancelled' ? TIMELINE_STYLES.cancelled : '',
                editable: booking.status !== 'cancelled'
            };
        });

        // Process checkouts
        const checkoutItems = checkouts.map(checkout => {
            const patronContent = checkout.patron
                ? $patron_to_html(checkout.patron, { display_cardnumber: true, url: true })
                : __("Unknown patron");
            
            return {
                id: `checkout-${checkout.checkout_id}`,
                content: `<span class="checkout-label font-weight-bold">${__("Checkout")}: ${patronContent}</span>`,
                start: dayjs(checkout.checkout_date).toDate(),
                end: checkout.due_date ? dayjs(checkout.due_date).toDate() : dayjs().add(1, 'year').toDate(),
                type: "range",
                group: checkout.item_id,
                className: 'checkout',
                style: TIMELINE_STYLES.checkout,
                editable: false
            };
        });

        const visSetBookings = new vis.DataSet([...bookingItems, ...checkoutItems]);

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
            // Don't allow moving checkout items
            if (item.id && item.id.toString().startsWith('checkout-')) {
                callback(null);
                return;
            }

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
            if (!window.CAN_user_circulate_manage_bookings) {
                callback(null);
                return;
            }

            const booking = visSetBookings.get(data.id);
            if (!booking) {
                callback(null);
                return;
            }

            const island = document.querySelector("booking-modal-island");
            if (!island) return;

            island.bookingId = booking.booking;
            island.itemId = booking.group || null;
            island.patronId = booking.patron;
            island.pickupLibraryId = booking.pickup_library;
            island.startDate = data.start.toISOString();
            island.endDate = data.end.toISOString();
            // Also update the island's internal store via properties to ensure flatpickr sync
            try {
                const startIso = data.start.toISOString();
                const endIso = data.end ? data.end.toISOString() : startIso;
                island.selectedDateRange = [startIso, endIso];
            } catch (e) {}
            island.extendedAttributes = booking.extended_attributes || [];

            island.open = true;

            const handleModalClose = () => {
                island.removeEventListener('close', handleModalClose);
                callback(data);
            };

            island.addEventListener('close', handleModalClose);
        };
    }

    function createTempModalTrigger(bookingId, modalId) {
        const tempButton = document.createElement("button");
        tempButton.setAttribute("data-booking", bookingId);
        tempButton.setAttribute("data-toggle", "modal");
        tempButton.setAttribute("data-target", `#${modalId}`);
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
        // Only handle removal for booking items, not checkout items
        if (!item.booking) {
            callback(null);
            return;
        }

        const cancelBookingModal =
            document.getElementById("cancelBookingModal");
        if (!cancelBookingModal) {
            callback(null);
            return;
        }

        // Create and trigger the modal using a temporary button
        createTempModalTrigger(item.booking, "cancelBookingModal");

        const modalHideHandler = function () {
            if (window.cancel_success) {
                window.cancel_success = 0;
                callback(item);
            } else {
                callback(null);
            }
            cancelBookingModal.removeEventListener(
                "hidden.bs.modal",
                modalHideHandler
            );
        };

        cancelBookingModal.addEventListener(
            "hidden.bs.modal",
            modalHideHandler
        );
    }

    function init({
        containerId,
        bookings,
        bookableItems,
        checkouts = []
    }) {
        const container = document.getElementById(containerId);
        const loadingEl = document.getElementById('bookings-timeline-loading');
        
        const { visSetItems, visSetBookings } = processBookingsData(
            bookings,
            bookableItems,
            checkouts
        );

        const handleOnMoving = makeHandleOnMoving(visSetBookings);
        const handleOnMove = makeHandleOnMove(visSetBookings);

        const options = {
            stack: true,
            editable: {
                remove: window.CAN_user_circulate_manage_bookings,
                updateTime: window.CAN_user_circulate_manage_bookings,
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