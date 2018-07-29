$.ajaxSetup({
    url: "/cgi-bin/koha/tags/review.pl",
    type: "POST",
    dataType: "script"
});

var ok_count  = 0;
var nok_count = 0;
var rej_count = 0;
var alerted = 0;

function pull_counts () {
    ok_count  = parseInt(document.getElementById("terms_summary_approved_count"  ).innerHTML);
    nok_count = parseInt(document.getElementById("terms_summary_unapproved_count").innerHTML);
    rej_count = parseInt(document.getElementById("terms_summary_rejected_count"  ).innerHTML);
}

function count_approve () {
    pull_counts();
    if (nok_count > 0) {
        $("#terms_summary_unapproved_count").html(nok_count -1);
        $("#terms_summary_approved_count"  ).html( ok_count +1);
    }
}

function count_reject () {
    pull_counts();
    if (nok_count > 0) {
        $("#terms_summary_unapproved_count").html(nok_count -1);
        $("#terms_summary_rejected_count"  ).html(rej_count +1);
    }
}

var success_approve = function(tag){
    // window.alert(_("AJAX approved tag: ") + tag);
};
var failure_approve = function(tag){
    window.alert(MSG_AJAX_APPROVE_FAILED.format(decodeURIComponent( tag )));
};
var success_reject  = function(tag){
    // window.alert(_("AJAX rejected tag: ") + tag);
};
var failure_reject  = function(tag){
    window.alert(MSG_AJAX_REJECTION_FAILED.format(decodeURIComponent( tag )));
};
var success_test    = function(tag){
    $('#verdict').html(MSG_AJAX_TAG_PERMITTED.format( decodeURIComponent( tag ) ));
};
var failure_test    = function(tag){
    $('#verdict').html(MSG_AJAX_TAG_PROHIBITED.format( decodeURIComponent( tag ) ));
};
var indeterminate_test = function(tag){
    $('#verdict').html(MSG_AJAX_TAG_UNCLASSIFIED.format( decodeURIComponent( tag ) ));
};

var success_test_call = function() {
    $('#test_button').prop('disabled', false);
    $('#test_button').html("<i class='fa fa-check-square-o' aria-hidden='true'></i>" +_(" Test"));
};

$(document).ready(function() {
    $("#tagst").dataTable($.extend(true, {}, dataTablesDefaults, {
        "aoColumnDefs": [
            { "bSortable": false, "bSearchable": false, 'aTargets': [ 'NoSort' ] },
            { "sType": "anti-the", "aTargets" : [ "anti-the" ] },
            { "sType": "title-string", "aTargets" : [ "title-string" ] }
        ],
        "aaSorting": [[ 4, "desc" ]],
        "sPaginationType": "four_button"
    }));
    $('.ajax_buttons' ).css({visibility:"visible"});
    $("p.check").html("<div id=\"searchheader\"><a id=\"CheckAll\" href=\"/cgi-bin/koha/tags/review.pl\"><i class=\"fa fa-check\"><\/i> "+ LABEL_SELECT_ALL +"<\/a> | <a id=\"CheckNone\" href=\"/cgi-bin/koha/tags/review.pl\"><i class=\"fa fa-remove\"><\/i> "+ LABEL_CLEAR_ALL +"<\/a> | <a id=\"CheckPending\" href=\"/cgi-bin/koha/tags/review.pl\"> "+ LABEL_SELECT_ALL_PENDING +"<\/a><\/div>");
    $("#CheckAll").click(function(){
        $(".checkboxed").checkCheckboxes();
        return false;
    });
    $("#CheckNone").click(function(){
        $(".checkboxed").unCheckCheckboxes();
        return false;
    });
    $("#CheckPending").click(function(){
        $(".checkboxed").checkCheckboxes(".pending");
        return false;
    });
    $(".approval_btn").on('click',function(event) {
        event.preventDefault();
        pull_counts();
        var getelement;
        var gettitle;
        // window.alert(_("Click detected on ") + event.target + ": " + $(event.target).html);
        if ($(event.target).is('.ok')) {
            $.ajax({
                data: {
                    ok: $(event.target).attr("title")
                },
                success: count_approve // success_approve
            });
            $(event.target).next(".rej").prop('disabled', false).css("color","#000");
            $(event.target).next(".rej").html("<i class='fa fa-remove'></i> " + _("Reject"));
            $(event.target).prop('disabled', true).css("color","#666");
            $(event.target).html("<i class='fa fa-check'></i> " + LABEL_APPROVED );
            getelement = $(event.target).data("num");
            gettitle = ".status" + getelement;
            $(gettitle).text( LABEL_APPROVED );
            if ($(gettitle).hasClass("pending") ){
                $(gettitle).toggleClass("pending approved");
            } else {
                $(gettitle).toggleClass("rejected approved");
            }
        }
        if ($(event.target).is('.rej')) {
            $.ajax({
                data: {
                    rej: $(event.target).attr("title")
                },
                success: count_reject // success_reject
            });
            $(event.target).prev(".ok").prop('disabled', false).css("color","#000");
            $(event.target).prev(".ok").html("<i class='fa fa-check'></i> " + LABEL_APPROVE );
            $(event.target).prop('disabled', true).css("color","#666");
            $(event.target).html("<i class='fa fa-remove'></i> " + LABEL_REJECTED );
            getelement = $(event.target).data("num");
            gettitle = ".status" + getelement;
            $(gettitle).text( LABEL_REJECTED );
            if ($(gettitle).hasClass("pending") ){
                $(gettitle).toggleClass("pending rejected");
            } else {
                $(gettitle).toggleClass("approved rejected");
            }
            return false;   // cancel submit
        }
        if ($(event.target).is('#test_button')) {
            $(event.target).text( LABEL_TESTING ).prop('disabled', true);
            $.ajax({
                data: {
                    test: $('#test').attr("value")
                },
                success: success_test_call // success_reject
            });
            return false;   // cancel submit
        }
    });
    $("*").ajaxError(function(evt, request, settings){
        if ((alerted +=1) <= 1){ window.alert(MSG_AJAX_ERROR.format(alerted)); }
    });

    var reviewerField = $("#approver");
    reviewerField.autocomplete({
        source: "/cgi-bin/koha/circ/ysearch.pl",
        minLength: 3,
        select: function( event, ui ) {
            reviewerField.val( ui.item.borrowernumber );
            return false;
        }
    })
    .data( "ui-autocomplete" )._renderItem = function( ul, item ) {
        return $( "<li></li>" )
        .data( "ui-autocomplete-item", item )
        .append( "<a>" + item.surname + ", " + item.firstname + " (" + item.cardnumber + ") <small>" + item.address + " " + item.city + " " + item.zipcode + " " + item.country + "</small></a>" )
        .appendTo( ul );
    };
});
