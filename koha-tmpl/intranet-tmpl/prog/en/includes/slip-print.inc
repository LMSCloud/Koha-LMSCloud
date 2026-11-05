[% USE raw %]
<!-- slip-print.inc -->
[% INCLUDE 'print-window-root.inc' %]
<script>
    [% IF ( Koha.Preference('IntranetSlipPrinterJS') ) %]
        let autoprint = false;
        [% Koha.Preference('IntranetSlipPrinterJS') | $raw %]
    [% ELSE %]
        let autoprint = true;
        window.onafterprint = function () {
            window.close();
        }
        window.addEventListener('load', function() {
            window.print();
            // Firefox fires afterprint before the print dialog closes and ignores
            // window.close() while it is open; print() returns once it is closed
            window.close();
        });
    [% END %]
</script>
<!-- / slip-print.inc -->
