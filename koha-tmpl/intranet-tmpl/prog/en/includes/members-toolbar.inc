[% USE Koha %]
[% USE Borrowers %][% SET IsFamilyCard = (Borrowers.IsFamilyCard( borrowernumber ) || Borrowers.IsFamilyCard( guarantorid )) %]
[% SET NorwegianPatronDBEnable = Koha.Preference( 'NorwegianPatronDBEnable' ) %]
<script type="text/javascript">
//<![CDATA[
$(document).ready(function(){
    [% IF ( CAN_user_borrowers ) %]
        [% IF ( NorwegianPatronDBEnable == 1 ) %]
            $("#deletepatronlocal").click(function(){
                confirm_local_deletion();
                $(".btn-group").removeClass("open");
                return false;
            });
            $("#deletepatronremote").click(function(){
                confirm_remote_deletion();
                $(".btn-group").removeClass("open");
                return false;
            });
            $("#deletepatronboth").click(function(){
                confirm_both_deletion();
                $(".btn-group").removeClass("open");
                return false;
            });
        [% ELSE %]
            $("#deletepatron").click(function(){
                window.location='/cgi-bin/koha/members/deletemem.pl?member=[% borrowernumber | url%]';
            });
        [% END %]
        $("#renewpatron").click(function(){
            confirm_reregistration();
            $(".btn-group").removeClass("open");
            return false;
        });
        [% IF ( is_child ) %]$("#updatechild").click(function(){
            update_child();
            $(".btn-group").removeClass("open");
        });[% END %]
    [% END %]
    $("#updatechild, #patronflags, #renewpatron, #deletepatron, #exportbarcodes").tooltip();
    $("#exportcheckins").click(function(){
        export_barcodes();
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#printsummary").click(function(){
        printx_window("page");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#printslip").click(function(){
        printx_window("slip");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#printquickslip").click(function(){
        printx_window("qslip");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#print_overdues").click(function(){
        window.open("/cgi-bin/koha/members/print_overdues.pl?borrowernumber=[% borrowernumber %]", "printwindow");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#searchtohold").click(function(){
        searchToHold();
        return false;
    })

    [% IF (CAN_user_circulate_send_adhoc_notices && Koha.Preference('AdhocNoticesLetterCodes') ) %]
    $("#notice_sent_dialog").hide();

    $.ajax({
        data: {},
        type: 'POST',
        url: '/cgi-bin/koha/svc/members/adhocletters',
        success: function(data) {
            var letterSelect =  $("#adhocNoticeLetterSelection_letter");
            letterSelect.find('option').remove();
            for (var i=0; i < data.letters.length; i++ ) {
               letterSelect.append($('<option></option>').val(data.letters[i].code).html(data.letters[i].name));
            }

        },
        error: function() {
            alert( _("An error occured while retrieving available letters for adhoc-notices.") );
        }
    });
    $("#send_notice_letter_select").on('click', function(e){
        var patronCount = 1;
        $('#selectAdhocNoticeLetterPatronCount').text(patronCount);
        $("#selectAdhocNoticeLetter").modal("show");

        return true;
    });
    $("#send_notice_submit").on('click', function(e){
        e.preventDefault();
        var patronCount = 1;

        var borrowernumbers = [];
        borrowernumbers.push([% borrowernumber %]);

        var data = {
            use_letter: $("#adhocNoticeLetterSelection_letter").val(),
            use_email: ($('#preferEmail').is(":checked") ? $("#preferEmail").val() : ''),
            no_notice_fees: ($('#dontCharge').is(":checked") ? $("#dontCharge").val() : ''),
            borrowernumbers: borrowernumbers
        };

        $.ajax({
            data: data,
            type: 'POST',
            url: '/cgi-bin/koha/svc/members/sendnotice',
            success: function(data) {
                var patronExportModal = $("#selectAdhocNoticeLetter");
                $("#notice_sent_dialog").show();
                $("#notice_sent_dialog").find(".patrons-length").text(patronCount);
                $("#notice_sent_dialog").find(".letter-name").text($("#adhocNoticeLetterSelection_letter").find("option:selected").text());
                if ( data.letter_mailed > 0 ) {
                    $("#notice_sent_dialog").find(".letter-email-count").text(data.letter_mailed);
                    $("#notice_sent_dialog").find(".letter-email").show();
                }
                else {
                    $("#notice_sent_dialog").find(".letter-email").hide();
                }
                if ( data.letter_printed > 0 ) {
                    $("#notice_sent_dialog").find(".letter-print-count").text(data.letter_printed);
                    $("#notice_sent_dialog").find("a").attr("href","/cgi-bin/koha/tools/download-files.pl?filename=" + data.printedfile + "&op=download");
                    $("#notice_sent_dialog").find(".letter-print").show();
                }
                else {
                    $("#notice_sent_dialog").find(".letter-print").hide();
                }

                //console.log(data);
                patronExportModal.modal("hide");
                $("#memberresultst").DataTable().ajax.reload();
            },
            error: function() {
                alert( _("A server error occured processing the adhoc notice request.") );
            }
        });

        return true;
    });
    [% END %]
});
function confirm_local_deletion() {
    var is_confirmed = window.confirm(_("Are you sure you want to delete this patron from the local database? This cannot be undone."));
    if (is_confirmed) {
        window.location='/cgi-bin/koha/members/deletemem.pl?member=[% borrowernumber %]&deletelocal=true&deleteremote=false';
    }
}
function confirm_remote_deletion() {
    var is_confirmed = window.confirm(_("Are you sure you want to delete this patron from the Norwegian national patron database? This cannot be undone."));
    if (is_confirmed) {
        window.location='/cgi-bin/koha/members/deletemem.pl?member=[% borrowernumber %]&deletelocal=false&deleteremote=true';
    }
}
function confirm_both_deletion() {
    var is_confirmed = window.confirm(_("Are you sure you want to delete this patron both from the local database and from the Norwegian national patron database? This cannot be undone."));
    if (is_confirmed) {
        window.location='/cgi-bin/koha/members/deletemem.pl?member=[% borrowernumber %]&deletelocal=true&deleteremote=true';
    }
}

[% IF ( is_child ) %]function confirm_updatechild() {
    var is_confirmed = window.confirm(_("Are you sure you want to update this child to an Adult category?  This cannot be undone."));
    if (is_confirmed) {
        window.location='/cgi-bin/koha/members/update-child.pl?op=update&borrowernumber=[% borrowernumber %]&catcode=[% catcode %]&catcode_multi=[% CATCODE_MULTI %]';
    }
}

function update_child() {
    [% IF ( CATCODE_MULTI ) %]
        window.open('/cgi-bin/koha/members/update-child.pl?op=multi&borrowernumber=[% borrowernumber %]','UpdateChild','width=400,height=300,toolbar=no,scrollbars=yes,resizable=yes');
    [% ELSE %]
        confirm_updatechild();
    [% END %]
}
[% END %]

[% IF ( guarantorid && IsFamilyCard ) %]
function confirm_reregistration() {
    var is_confirmed = window.confirm(_("Are you sure you want to renew this patron's family card registration?"));
    if (is_confirmed) {
        window.location = '/cgi-bin/koha/members/setstatus.pl?borrowernumber=[% guarantorid %]&amp;destination=[% destination %]&amp;reregistration=y;followupborrower=[% borrowernumber %]';
    }
}
[% ELSE %]
function confirm_reregistration() {
    [% IF ( IsFamilyCard ) %]
    var is_confirmed = window.confirm(_("Are you sure you want to renew this patron's family card registration?"));
    [% ELSE %]
    var is_confirmed = window.confirm(_("Are you sure you want to renew this patron's registration?"));
    [% END %]
    if (is_confirmed) {
        window.location = '/cgi-bin/koha/members/setstatus.pl?borrowernumber=[% borrowernumber %]&amp;destination=[% destination %]&amp;reregistration=y';
    }
}
[% END %]
function export_barcodes() {
    window.open('/cgi-bin/koha/members/readingrec.pl?borrowernumber=[% borrowernumber %]&amp;op=export_barcodes');
}
var slip_re = /slip/;
function printx_window(print_type) {
    var handler = print_type.match(slip_re) ? "printslip" : "summary-print";
    window.open("/cgi-bin/koha/members/" + handler + ".pl?borrowernumber=[% borrowernumber %]&amp;print=" + print_type, "printwindow");
    return false;
}
function searchToHold(){
    var date = new Date();
    date.setTime(date.getTime() + (10 * 60 * 1000));
    $.cookie("holdfor", "[% borrowernumber %]", { path: "/", expires: date });
    location.href="/cgi-bin/koha/catalogue/search.pl";
}
//]]>
</script>

<div id="toolbar" class="btn-toolbar">
    [% IF ( CAN_user_borrowers ) %]
        [% IF ( guarantor ) %]
            <a id="editpatron" class="btn btn-small" href="/cgi-bin/koha/members/memberentry.pl?op=modify&amp;destination=circ&amp;borrowernumber=[% borrowernumber %]&amp;guarantorid=[% guarantor.borrowernumber %]&amp;categorycode=[% categorycode %]">
        [% ELSE %]
            <a id="editpatron" class="btn btn-small" href="/cgi-bin/koha/members/memberentry.pl?op=modify&amp;destination=circ&amp;borrowernumber=[% borrowernumber %]&amp;categorycode=[% categorycode %]">
        [% END %]
        <i class="fa fa-pencil"></i> Edit</a>
    [% END %]

    [% IF ( CAN_user_borrowers ) %]
        [% IF adultborrower AND Koha.Preference("borrowerRelationship") %]
            [% IF Borrowers.IsFamilyCard(borrowernumber) %]
            <a id="addchild" class="btn btn-default btn-sm" href="/cgi-bin/koha/members/memberentry.pl?op=add&amp;guarantorid=[% borrowernumber %]"><i class="fa fa-plus"></i> Add family card member</a>
            [% ELSE %]
            <a id="addchild" class="btn btn-default btn-sm" href="/cgi-bin/koha/members/memberentry.pl?op=add&amp;guarantorid=[% borrowernumber %]"><i class="fa fa-plus"></i> Add child</a>
            [% END %]
        [% END %]
        [% IF ( CAN_user_borrowers ) %]
            <a id="changepassword" class="btn btn-small" href="/cgi-bin/koha/members/member-password.pl?member=[% borrowernumber %]"><i class="fa fa-lock"></i> Change password</a>
        [% END %]
        <a id="duplicate" class="btn btn-small" href="/cgi-bin/koha/members/memberentry.pl?op=duplicate&amp;borrowernumber=[% borrowernumber %]&amp;categorycode=[% categorycode %]"><i class="fa fa-copy"></i> Duplicate</a>
    [% END %]

    <div class="btn-group">
        <button class="btn btn-small dropdown-toggle" data-toggle="dropdown"><i class="fa fa-print"></i> Print <span class="caret"></span></button>
            <ul class="dropdown-menu">
                [% IF ( CAN_user_borrowers ) %]<li><a id="printsummary" href="#">Print summary</a></li>[% END %]
                <li><a id="printslip" href="#">Print slip</a></li>
                <li><a id="printquickslip" href="#">Print quick slip</a></li>
                [% IF Borrowers.HasOverdues( borrowernumber ) %]
                    <li><a id="print_overdues" href="#">Print overdues</a></li>
                [% END %]
            </ul>
    </div>

    [% IF ( CAN_user_reserveforothers ) %]
        <a id="searchtohold" class="btn btn-small" href="#"><i class="fa fa-search"></i> Search to hold</a>
    [% END %]

         <div class="btn-group">
        <button class="btn btn-small dropdown-toggle" data-toggle="dropdown">More <span class="caret"></span></button>
            <ul class="dropdown-menu">
                [% IF ( CAN_user_borrowers ) %]
                    <li><a id="renewpatron" href="/cgi-bin/koha/members/setstatus.pl?borrowernumber=[% borrowernumber %]&amp;destination=[% destination %]&amp;reregistration=y">[% IF ( IsFamilyCard ) %]Renew family card[% ELSE %]Renew patron[% END %]</a></li>
                [% ELSE %]
                    <li class="disabled"><a data-toggle="tooltip" data-placement="left" title="You are not authorized to renew patrons" id="renewpatron" href="#">Renew patron</a></li>
                [% END %]
                [% IF ( CAN_user_permissions ) %]
                    <li><a id="patronflags" href="/cgi-bin/koha/members/member-flags.pl?member=[% borrowernumber %]">Set permissions</a></li>
                [% ELSE %]
                    <li class="disabled"><a data-toggle="tooltip" data-placement="left" title="You are not authorized to set permissions" id="patronflags" href="#">Set permissions</a></li>
                [% END %]
                [% IF CAN_user_borrowers && useDischarge %]
                    <li><a href="/cgi-bin/koha/members/discharge.pl?borrowernumber=[% borrowernumber %]">Discharge</a></li>
                [% END %]
                [% IF (CAN_user_circulate_send_adhoc_notices && Koha.Preference('AdhocNoticesLetterCodes') ) %]
                    <li><a id="send_notice_letter_select" href="#selectAdhocNoticeLetter" >Send notice</a></li>
                [% END %]
                [% IF ( CAN_user_borrowers ) %]
                    [% IF ( NorwegianPatronDBEnable == 1 ) %]
                        <li><a id="deletepatronlocal" href="#">Delete local</a></li>
                        <li><a id="deletepatronremote" href="#">Delete remote</a></li>
                        <li><a id="deletepatronboth" href="#">Delete local and remote</a></li>
                    [% ELSE %]
                        <li><a id="deletepatron" href="#">Delete</a></li>
                    [% END %]
                [% ELSE %]
                    <li class="disabled"><a data-toggle="tooltip" data-placement="left" title="You are not authorized to delete patrons" id="deletepatron" href="#">Delete</a></li>
                [% END %]
                [% IF ( is_child ) %]
                    <li><a id="updatechild" href="#">Update child to adult patron</a></li>
                [% ELSE %]
                    <li class="disabled"><a data-toggle="tooltip" data-placement="left" title="Patron is an adult" id="updatechild" href="#">Update child to adult patron</a></li></li>
                [% END %]
                [% IF Koha.Preference('intranetreadinghistory') %]
                    [%IF ( privacy == 2 ) %]
                        <li class="disabled"><a data-toggle="tooltip" data-placement="left" title="Not allowed by patron's privacy settings" id="exportbarcodes" href="#">Export today's checked in barcodes</a></li>
                    [% ELSE %]
                        <li><a id="exportcheckins" href="#">Export today's checked in barcodes</a></li>
                    [% END %]
                [% END %]
            </ul>
    </div>
</div>


<!-- Modal to send adhoc notices -->
<div class="modal hide" id="selectAdhocNoticeLetter" tabindex="-1" role="dialog" aria-labelledby="selectAdhocNoticeLetter_label" aria-hidden="true">
    <form id="noticeform">
    <div class="modal-header">
        <button type="button" class="closebtn" data-dismiss="modal" aria-hidden="true">&times;</button>
        <h3 id="selectAdhocNoticeLetter_label">Send Notice</h3>
    </div>
    <div class="modal-body">
        <p>
            Please select the letter that will be used to create notices to the selected patron. Please be aware that patrons might be charged for notices depending on the defined notice fee rules.
        </p>
        <p>
            Number of selected patrons: <span id="selectAdhocNoticeLetterPatronCount"></span>
        </p>
        <p id="adhocNoticeLetterSelection">
            <label for="adhocNoticeLetterSelection_letter">Select letter: </label>
            <select name="adhocNoticeLetterSelection_letter" id="adhocNoticeLetterSelection_letter">
            </select>
        </p>
        <p>
            <label>
                Prefer Email notification if an email address is available: <input type="checkbox" id="preferEmail" name="preferEmail" value="yes" checked>
            </label>
        </p>
        <p>
            <label>
                Do not charge patrons despite of possible configured notice fee rules: <input type="checkbox" id="dontCharge" name="dontCharge" value="yes">
            </label>
        </p>
    </div>
    <div class="modal-footer">
        <input id="send_notice_submit" type="submit" class="submit" value="Create notices">
    </div>
    </form>
</div>
