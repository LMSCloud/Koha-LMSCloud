window.BookingsTableFilters = (function() {
    'use strict';

    const filterStates = {
        expired: false,
        cancelled: false
    };

    const bookingsTableFiltersChangedEvent = new CustomEvent('bookingsTableFilters:changed');

    function render() {
        const expiredBtn = document.getElementById('bookings_expired_filter');
        const cancelledBtn = document.getElementById('bookings_cancelled_filter');

        if (expiredBtn) {
            expiredBtn.classList.toggle('filtered', filterStates.expired);
            expiredBtn.innerHTML = `<i class="fa fa-${filterStates.expired ? 'filter' : 'bars'}"></i> ${filterStates.expired ? 'Hide expired' : 'Show expired'}`;
        }
        if (cancelledBtn) {
            cancelledBtn.classList.toggle('filtered', filterStates.cancelled);
            cancelledBtn.innerHTML = `<i class="fa fa-${filterStates.cancelled ? 'filter' : 'bars'}"></i> ${filterStates.cancelled ? 'Hide cancelled' : 'Show cancelled'}`;
        }
    }

    document.addEventListener('click', function(event) {
        const target = event.target;
        if (target.closest('#bookings_expired_filter')) {
            event.preventDefault();
            filterStates.expired = !filterStates.expired;
            render();
            document.dispatchEvent(bookingsTableFiltersChangedEvent);
        } else if (target.closest('#bookings_cancelled_filter')) {
            event.preventDefault();
            filterStates.cancelled = !filterStates.cancelled;
            render();
            document.dispatchEvent(bookingsTableFiltersChangedEvent);
        }
    });

    // Initial render
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", render);
    } else {
        render();
    }

    return {
        getStates: () => ({ ...filterStates })
    };
})(); 