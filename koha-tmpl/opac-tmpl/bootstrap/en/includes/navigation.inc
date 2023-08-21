[% USE raw %]
[% USE Koha %]

[% IF ( OpacNav ) %]
    [% PROCESS koha_news_block news => OpacNav %]
[% END %]

[% IF IsPatronPage %]
    [% IF ( Koha.Preference('OpacPatronBarcodeDisplay') ) %]
        <canvas tabindex="0" role="button" aria-label="Patron barcode" data-cardnumber="[% logged_in_user.cardnumber | html %]" id="e-card" data-barcode-format="[% Koha.Preference('OpacPatronBarcodeFormat') %]">[% INCLUDE 'e-card.inc' %]</canvas>
    [% END %]
    <div id="usermenu">[% INCLUDE usermenu.inc %]</div>
[% END %]

[% IF ( OpacNavBottom ) %]
    [% PROCESS koha_news_block news => OpacNavBottom %]
[% END %]
