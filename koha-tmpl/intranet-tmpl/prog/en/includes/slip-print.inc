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
        });
    [% END %]
</script>
<!-- / slip-print.inc -->
