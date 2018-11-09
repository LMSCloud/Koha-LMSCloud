[% USE Koha %]

<script type="text/javascript">//<![CDATA[
    $(document).ready(function() {

        [% IF (CAN_user_circulate_send_adhoc_notices && Koha.Preference('AdhocNoticesLetterCodes') ) %]
            $("#notice_sent_dialog").hide();
        [% END %]
    });
//]]>
</script>

[% IF (CAN_user_circulate_send_adhoc_notices && Koha.Preference('AdhocNoticesLetterCodes') ) %]
    <div id="notice_sent_dialog" class="dialog alert" style="display:none;" >
        Letter "<span class="letter-name"></span>" successfully created as notice to <span class="patrons-length"></span> patron(s).
        <span class="letter-email"><br /><span class="letter-email-count"></span> patron(s) notified by email.</span>
        <span class="letter-print"><br />Print notices created for <span class="letter-print-count"></span> patron(s). <a href="/cgi-bin/koha/tools/download-files.pl" target="_blank">Click here to download the notices for printing.</a></span>
    </div>
[% END %]
