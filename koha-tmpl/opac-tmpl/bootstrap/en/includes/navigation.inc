[% USE raw %]
[% USE Koha %]
<div id="opacnav">[% OpacNav | $raw %]</div>
[% IF IsPatronPage %]
    [% IF ( Koha.Preference('OpacPatronBarcodeDisplay') ) %]
        <canvas tabindex="0" role="button" aria-label="Patron barcode" id="e-card" data-barcode-format="[% Koha.Preference('OpacPatronBarcodeFormat') %]">[% INCLUDE 'e-card.inc' %]</canvas>
    [% END %]
    <div id="usermenu">[% INCLUDE usermenu.inc %]</div>
[% END %]
<div id="opacnavbottom">[% OpacNavBottom | $raw %]</div>
