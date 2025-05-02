(() => {
    document
        .getElementById("cancelBookingModal")
        ?.addEventListener("show.bs.modal", handleShowBsModal);

    document
        .getElementById("cancelBookingModal")
        ?.addEventListener("hide.bs.modal", () => {
            $("#cancellation-reason").comboBox("reset");
        });

    function handleShowBsModal(e) {
        const button = e.relatedTarget;
        if (!button) {
            return;
        }

        const booking = button.dataset.booking;
        if (!booking) {
            return;
        }

        const bookingIdInput = document.getElementById("cancel_booking_id");
        if (!bookingIdInput) {
            return;
        }

        bookingIdInput.value = booking;
    }
})();
