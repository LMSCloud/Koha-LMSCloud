[%# BibTip recommender for opac-detail. Set BibtipClient to switch the deployed
  # client; v2511 (V5 API) also needs #bibtip_api_token, v215 ignores it.
-%]
[% SET BibtipClient = 'bibtip_lmscloud_v2511.js' %]

[% IF ( Koha.Preference('BibtipEnabled') ) %]
    [% USE BibtipToken %]
    [% IF ( Koha.Preference('BibtipCatalog') ) %]
        <script type="text/javascript">
        //<![CDATA[
            var BibtipCatalog = "[% Koha.Preference('BibtipCatalog') | html %]";
        //]]>
        </script>
    [% END %]
    <div id="bibtip_api_token" style="display:none">[% BibtipToken.generate | html %]</div>
    <script src="https://static.lmscloud.net/js/[% BibtipClient | uri %]" type="text/javascript"></script>
[% END %]
