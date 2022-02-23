/* global dataTablesDefaults allColumns Cookies */
// Set expiration date for cookies
var date = new Date();
date.setTime(date.getTime() + (365 * 24 * 60 * 60 * 1000));

function hideColumns() {
    var valCookie = Cookies.get("showColumns");
    if (valCookie) {
        valCookie = valCookie.split("/");
        $("#showall").prop("checked", false).parent().removeClass("selected");
        for ( var i = 0; i < valCookie.length; i++ ) {
            if (valCookie[i] !== '') {
                var index = valCookie[i] - 3;
                $("#itemst td:nth-child(" + valCookie[i] + "),#itemst th:nth-child(" + valCookie[i] + ")").toggle();
                $("#checkheader" + index).prop("checked", false).parent().removeClass("selected");
            }
        }
    }
}

function hideColumn(num) {
    $("#hideall,#showall").prop("checked", false).parent().removeClass("selected");
    var valCookie = Cookies.get("showColumns");
    // set the index of the table column to hide
    $("#" + num).parent().removeClass("selected");
    var hide = Number(num.replace("checkheader", "")) + 3;
    // hide header and cells matching the index
    $("#itemst td:nth-child(" + hide + "),#itemst th:nth-child(" + hide + ")").toggle();
    // set or modify cookie with the hidden column's index
    if (valCookie) {
        valCookie = valCookie.split("/");
        var found = false;
        for ( var i = 0; i < valCookie.length; i++ ) {
            if (hide == valCookie[i]) {
                found = true;
                break;
            }
        }
        if (!found) {
            valCookie.push(hide);
            var cookieString = valCookie.join("/");
            Cookies.set("showColumns", cookieString, { expires: date, path: '/' });
        }
    } else {
        Cookies.set("showColumns", hide, { expires: date, path: '/' });
    }
}

// Array Remove - By John Resig (MIT Licensed)
// http://ejohn.org/blog/javascript-array-remove/
Array.prototype.remove = function (from, to) {
    var rest = this.slice((to || from) + 1 || this.length);
    this.length = from < 0 ? this.length + from : from;
    return this.push.apply(this, rest);
};

function showColumn(num) {
    $("#hideall").prop("checked", false).parent().removeClass("selected");
    $("#" + num).parent().addClass("selected");
    var valCookie = Cookies.get("showColumns");
    // set the index of the table column to hide
    var show = Number(num.replace("checkheader", "")) + 3;
    // hide header and cells matching the index
    $("#itemst td:nth-child(" + show + "),#itemst th:nth-child(" + show + ")").toggle();
    // set or modify cookie with the hidden column's index
    if (valCookie) {
        valCookie = valCookie.split("/");
        var found = false;
        for ( var i = 0; i < valCookie.length; i++ ) {
            if (show == valCookie[i]) {
                valCookie.remove(i);
                found = true;
            }
        }
        if (found) {
            var cookieString = valCookie.join("/");
            Cookies.set("showColumns", cookieString, { expires: date, path: '/' });
        }
    }
}

function showAllColumns() {
    $("#selections input:checkbox").each(function () {
        $(this).prop("checked", true);
    });
    $("#selections span").addClass("selected");
    $("#itemst td:nth-child(3),#itemst tr th:nth-child(3)").nextAll().show();
    Cookies.remove("showColumns", { path: '/' });
    $("#hideall").prop("checked", false).parent().removeClass("selected");
}

function hideAllColumns() {
    $("#selections input:checkbox").each(function () {
        $(this).prop("checked", false);
    });
    $("#selections span").removeClass("selected");
    $("#itemst td:nth-child(3),#itemst th:nth-child(3)").nextAll().hide();
    $("#hideall").prop("checked", true).parent().addClass("selected");
    var cookieString = allColumns.join("/");
    Cookies.set("showColumns", cookieString, { expires: date, path: '/' });
}

$(document).ready(function () {
    hideColumns();
    $("#itemst").dataTable($.extend(true, {}, dataTablesDefaults, {
        "sDom": 't',
        "aoColumnDefs": [
            { "aTargets": [0], "bSortable": false, "bSearchable": false },
            { "sType": "anti-the", "aTargets": ["anti-the"] }
        ],
        "bPaginate": false,
    }));
    $("#selectallbutton").click(function (e) {
        e.preventDefault();
        $("#itemst input:checkbox").each(function () {
            $(this).prop("checked", true);
        });
    });
    $("#clearallbutton").click(function (e) {
        e.preventDefault();
        $("#itemst input:checkbox").each(function () {
            $(this).prop("checked", false);
        });
    });
    $("#clearonloanbutton").click(function () {
        $("#itemst input[name='itemnumber'][data-is-onloan='1']").each(function () {
            $(this).prop('checked', false);
        });
        return false;
    });
    $("#selections input").change(function (e) {
        var num = $(this).attr("id");
        if (num == 'showall') {
            showAllColumns();
            e.stopPropagation();
        } else if (num == 'hideall') {
            hideAllColumns();
            e.stopPropagation();
        } else {
            if ($(this).prop("checked")) {
                showColumn(num);
            } else {
                hideColumn(num);
            }
        }
    });
});
