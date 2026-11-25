[% USE raw %]
<!-- slip-print.inc -->
[% INCLUDE 'print-window-root.inc' %]
<script>
    [% IF ( Koha.Preference('IntranetSlipPrinterJS') ) %]
        let autoprint = false;
        [% Koha.Preference('IntranetSlipPrinterJS') | $raw %]
    [% ELSE %]
        let autoprint = true;
        window.addEventListener('load', function() {
            // Browsers postpone a print() called while the page is still loading,
            // which includes the load event, and return at once. Called after it,
            // print() returns once the print dialog is closed
            setTimeout(function () {
                window.print();
                window.close();
            });
        });
    [% END %]
</script>
<!-- / slip-print.inc -->
