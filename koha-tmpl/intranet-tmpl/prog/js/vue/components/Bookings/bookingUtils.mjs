import dayjs from "../../utils/dayjs.js";

export function debounce(fn, delay) {
    let timeout;
    return function (...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => fn.apply(this, args), delay);
    };
}

function renderContent(bookingPatron) {
    if (typeof window.$patron_to_html === "function" && bookingPatron) {
        return window.$patron_to_html(bookingPatron, {
            display_cardnumber: true,
            url: true,
        });
    }

    if (bookingPatron?.cardnumber) {
        return bookingPatron.cardnumber;
    }

    return "";
}

export function updateExternalDependents(store, newBooking, isUpdate = false) {
    if (typeof window.timeline !== "undefined" && window.timeline !== null) {
        const itemData = {
            id: newBooking.booking_id,
            booking: newBooking.booking_id,
            patron: newBooking.patron_id,
            start: dayjs(newBooking.start_date).toDate(),
            end: dayjs(newBooking.end_date).toDate(),
            content: renderContent(store.bookingPatron),
            type: "range",
            group: newBooking.item_id ? newBooking.item_id : 0,
        };
        if (isUpdate) {
            window.timeline.itemsData.update(itemData);
        } else {
            window.timeline.itemsData.add(itemData);
        }
        window.timeline.focus(newBooking.booking_id);
    }
    if (
        typeof window.bookings_table !== "undefined" &&
        window.bookings_table !== null
    ) {
        window.bookings_table.api().ajax.reload();
    }
    try {
        const countEls = document.querySelectorAll(".bookings_count");
        countEls.forEach((el) => {
            let html = el.innerHTML;
            let match = html.match(/(\d+)/);
            if (match) {
                let newCount = parseInt(match[1], 10) + (isUpdate ? 0 : 1); // Only increment if not an update
                el.innerHTML = html.replace(/(\d+)/, newCount);
            }
        });
    } catch {
        // Fails silently
    }
}
