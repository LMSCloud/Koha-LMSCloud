(() => {
    $("#convertToCheckoutModal")?.on("show.bs.modal", handleShowBsModal);

    function handleShowBsModal(e) {
        const button = e.relatedTarget;
        if (!button) {
            return;
        }

        const borrowernumber = button.dataset.borrowernumber;
        const barcode = button.dataset.barcode;
        const itemid = button.dataset.itemid;
        const duedatespec = button.dataset.duedatespec;
        const title = button.dataset.title;
        const patron = button.dataset.patron;
        const cardnumber = button.dataset.cardnumber;

        if (!borrowernumber || !barcode) {
            return;
        }

        document.getElementById("convert_borrowernumber").value = borrowernumber;
        document.getElementById("convert_barcode").value = barcode;
        document.getElementById("convert_duedatespec").value = duedatespec || "";

        document.getElementById("convert_title").textContent = title || "";
        document.getElementById("convert_patron").textContent = patron || "";
        document.getElementById("convert_cardnumber").textContent = cardnumber ? `(${cardnumber})` : "";
        document.getElementById("convert_barcode_display").textContent = barcode || "";
        document.getElementById("convert_itemid").textContent = itemid ? `(${itemid})` : "";

        const formattedDueDate = duedatespec && typeof $date === "function"
            ? $date(duedatespec)
            : duedatespec || "";
        document.getElementById("convert_due_date").textContent = formattedDueDate;

        const form = document.getElementById("convertToCheckoutForm");
        if (form) {
            form.action = `/cgi-bin/koha/circ/circulation.pl?borrowernumber=${encodeURIComponent(borrowernumber)}`;
        }
    }
})();
