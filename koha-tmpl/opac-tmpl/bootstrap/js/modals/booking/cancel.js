(() => {
    $("#cancelBookingModal").on("show.bs.modal", handleShowBsModal);

    $("#cancelBookingModal").on("hide.bs.modal", () => {
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
