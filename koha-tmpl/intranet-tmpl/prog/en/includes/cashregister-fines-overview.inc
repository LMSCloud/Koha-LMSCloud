[% BLOCK accountTypeName %][% SWITCH finestat %]
  [% CASE 'Pay' %]Payment
  [% CASE 'Pay00' %]Cash payment via SIP2
  [% CASE 'Pay01' %]VISA Payment via SIP2
  [% CASE 'Pay02' %]Credit card payment via SIP2
  [% CASE 'N' %]New card
  [% CASE 'F' %]Fine
  [% CASE 'A' %]Account management fee
  [% CASE 'M' %]Sundry
  [% CASE 'L' %]Lost item
  [% CASE 'W' %]Writeoff
  [% CASE 'FU' %]Accruing fine
  [% CASE 'HE' %]Hold waiting too long
  [% CASE 'Rent' %]Rental fee
  [% CASE 'FOR' %]Forgiven
  [% CASE 'LR' %]Lost item fee refund
  [% CASE 'PAY' %]Payment
  [% CASE 'WO' %]Writeoff
  [% CASE 'C' %]Credit
  [% CASE 'CR' %]Credit
  [% CASE 'CL1' %]Claim fee 1<sup>st</sup> reminder
  [% CASE 'CL2' %]Claim fee 2<sup>nd</sup> reminder
  [% CASE 'CL3' %]Claim fee 3<sup>rd</sup> reminder
  [% CASE 'CL4' %]Claim fee 4<sup>th</sup> reminder
  [% CASE 'CL5' %]Claim fee 5<sup>th</sup> reminder
  [% CASE 'NOTF' %]Notice fee
  [% CASE 'Res' %]Reservation
  [% CASE %]([% finestat %])
[%- END -%][% END %]
<script type="text/javascript">
//<![CDATA[

function number_format (number, decimals, dec_point, thousands_sep) {
    var n = number, prec = decimals;

    var toFixedFix = function (n,prec) {
        var k = Math.pow(10,prec);
        return (Math.round(n*k)/k).toString();
    };

    n = !isFinite(+n) ? 0 : +n;
    prec = !isFinite(+prec) ? 0 : Math.abs(prec);
    var sep = (typeof thousands_sep === 'undefined') ? ',' : thousands_sep;
    var dec = (typeof dec_point === 'undefined') ? '.' : dec_point;

    var s = (prec > 0) ? toFixedFix(n, prec) : toFixedFix(Math.round(n), prec); 
    //fix for IE parseFloat(0.55).toFixed(0) = 0;

    var abs = toFixedFix(Math.abs(n), prec);
    var _, i;

    if (abs >= 1000) {
        _ = abs.split(/\D/);
        i = _[0].length % 3 || 3;

        _[0] = s.slice(0,i + (n < 0)) +
               _[0].slice(i).replace(/(\d{3})/g, sep+'$1');
        s = _.join(dec);
    } else {
        s = s.replace('.', dec);
    }

    var decPos = s.indexOf(dec);
    if (prec >= 1 && decPos !== -1 && (s.length-decPos-1) < prec) {
        s += new Array(prec-(s.length-decPos-1)).join(0)+'0';
    }
    else if (prec >= 1 && decPos === -1) {
        s += dec+new Array(prec).join(0)+'0';
    }
    return s; 
}

function money_format(number) {
    return "[% currency_format.1 %]" + number_format(number,[% currency_format.2 %],"[% currency_format.3 %]","[% currency_format.4 %]");
}

$(document).ready( function() {
    $("#finesoverview").dataTable($.extend(true, {}, dataTablesDefaults, {
        'bAutoWidth': true,
        'aoColumnDefs': [
            { "bSortable": true, "bSearchable": false, 'aTargets': ["_all"] },
            { "aTargets": [ 1 ], "asSorting": [ "desc","asc" ], "sType": "natural"  },
            { "aTargets": [ 0,2 ], "asSorting": [ "asc","desc" ]  }
        ],
        "aoColumns": [ { "sType": 'natural' }, null, null],
        "iDisplayLength": 100,
        "iDisplayStart": 0,
        "order": [[ 0, "asc" ]],
        "bSort" : true,
        "bPaginate": false,
        "serverSide": false,
        "bFilter": false,
        "bInfo" : false,
        "oLanguage": {
            "sEmptyTable": "No fines during the selected period."
        }
    }));
    $("#finesoverview_wrapper .pager").removeClass("pager");

    [% IF (finesstats && ( finesstats.type == 'finesbyday' || finesstats.type == 'finesbytype' ||  finesstats.type == 'finesbymanager' || finesstats.type == 'paymentsbyday' || finesstats.type == 'paymentsbytype' ||  finesstats.type == 'paymentsbymanager')) %]
    [% IF    ( finesstats.type == 'finesbyday' || finesstats.type == 'paymentsbyday')     %][% groupcol = '0' %][% sortdir = 'desc' %]
    [% ELSIF ( finesstats.type == 'finesbytype' || finesstats.type == 'paymentsbytype')    %][% groupcol = '2' %][% sortdir = 'asc' %]
    [% ELSIF ( finesstats.type == 'finesbymanager' || finesstats.type == 'paymentsbymanager') %][% groupcol = '5' %][% sortdir = 'asc' %]
    [% END %]
    $("#finesbydate").dataTable($.extend(true, {}, dataTablesDefaults, {
        'bAutoWidth': true,
        'aoColumnDefs': [
            { "bSortable": true, "bSearchable": false, 'aTargets': ["_all"] },
            { "aTargets": [ 1 ], "asSorting": [ "desc","asc" ], "sType": "natural"  },
            { "visible": false, "aTargets": [[% groupcol %],6] }
        ],
        "aoColumns": [ { "sType": 'natural' }, null, null, null, null, null, null],
        "iDisplayLength": 100,
        "iDisplayStart": 0,
        "order": [[[% groupcol %], "[% sortdir %]"],[3,"asc"]],
        "bSort" : true,
        "bPaginate": false,
        "serverSide": false,
        "bFilter": false,
        "bInfo" : false,
        "drawCallback": function ( settings ) {
            var api = this.api();
            var rows = api.rows( {order:'current'} ).nodes();
            var count = api.rows( {order:'current'} ).count()-1;
            var last = null;
            var sum = 0.0;
            var lastid = '';
            var groupnum = 1;
 
            api.column([% groupcol %], { order:'current'} ).data().each( function ( group, i ) {
                if ( last !== group ) {
                    if ( lastid != '' ) {
                        $("#"+lastid).text(money_format(sum));
                    }
                    var val = group;
                    if ( val.trim() == "" ) {
                        val = "&lt;No value&gt;";
                    }
                    lastid = "finesgrouprow" + groupnum;
                    $(rows).eq( i ).before(
                        '<tr class="group"><td colspan="5" class="finesgroupsum">'+val+':&nbsp;&nbsp;<span id="'+ lastid + '"></span></td></tr>'
                    );
                    last = group;
                    groupnum++;
                    sum = 0.0;
                    txt = '';
                }
                sum += parseFloat(api.cell($(rows).eq( i ),6,{order: 'current'} ).data());
                if ( count == i && lastid != '' ) {
                    $("#"+lastid).text(money_format(sum));
                }
            });
        },
        "oLanguage": {
            "sEmptyTable": "No fines during the selected period."
        }
    }));
    // Order by the grouping
    $('#finesbydate tbody').on( 'click', 'tr.group', function () {
        var currentOrder = table.order()[0];
        if ( currentOrder[0] === [% groupcol %] && currentOrder[1] === 'asc' ) {
            table.order( [ [% groupcol %], 'desc' ] ).draw();
        }
        else {
            table.order( [ [% groupcol %], 'asc' ] ).draw();
        }
    } );
    $("#finesbydate_wrapper .pager").removeClass("pager");
    [% END %]
    
    $('#printview').on('click',function(ev){
        ev.preventDefault();
        $('#showfinesoverview input[name="printview"]').val('print');
        $("#showfinesoverview").attr('target', '_blank').submit();
    });
    $('#noprintview').on('click',function(ev){
        ev.preventDefault();
        $('#showfinesoverview input[name="printview"]').val('');
        $("#showfinesoverview").attr('target', '_self').submit();
    });
});

</script>
<h3>Day-end closing: [% branchname %] ([% journalfrom %][% IF (journalfrom != journalto) %] - [% journalto %][% END %])</h3>
[% IF (! printview) %]
<form id="showfinesoverview" action="/cgi-bin/koha/circ/managecashregister.pl" method="post">
    <input type="hidden" name="op" value="dayview" />
    <fieldset class="rows" style="float: unset">
        <ol>
            <li>
                Day-end closing statistics <input type="text" size="10" id="journalfrom" name="journalfrom" value="[% journalfrom %]" class="datepicker" />
                to <input type="text" size="10" id="journalto" name="journalto" value="[% journalto %]" class="datepicker" />
                [% seltypes = [ 'finesoverview', 'finesbytype', 'finesbymanager', 'finesbyday', 'paymentsbytype', 'paymentsbymanager', 'paymentsbyday'] %]
                <select name="finestype">
                    [% FOREACH seltype IN seltypes %]
                        [% IF (finesstats.type == seltype) %]
                        <option value="[% seltype %]" selected="selected">
                        [% ELSE %]
                        <option value="[% seltype %]">
                        [% END %]
                        [% SWITCH seltype %]
                        [% CASE 'finesoverview' %]Fines overview
                        [% CASE 'finesbytype' %]Detailed fines by type
                        [% CASE 'finesbymanager' %]Detailed fines by manager
                        [% CASE 'finesbyday' %]Detailed fines by day
                        [% CASE 'paymentsbytype' %]Detailed payments by type
                        [% CASE 'paymentsbymanager' %]Detailed payments by manager
                        [% CASE 'paymentsbyday' %]Detailed payments by day
                        [% CASE %][% seltype %]
                        [%- END -%]
                        </option>
                    [% END %]
                </select>&nbsp;<input type="hidden" name="printview" value="" />
                <button id="noprintview" type="submit" name="allFromOpening" value="0">Select</button>
                <button id="printview" type="submit" name="printview" value="print"">Printview</button>
            </li>
        </ol>                      
    </fieldset>
</form>
[% ELSE %]
<p>Manager: [% loggedinusername %], Date: [% datetimenow %]</p>
[% END %]
<h4 style="margin-top:20px">Cash position</h4>
<table id="cashpaymentoverview">
    <thead>
        <tr>
            <th>Cash register</th>
            <th>Carry-over</th>
            <th>Cash receipts</th>
            <th>Cash payments</th>
            <th>Cash balance</th>
        </tr>
    </thead>
    <tbody>
        [% count_registers = 0 %]
        [% FOREACH stat IN bookingstats.keys.sort %]
            [% showstat = bookingstats.$stat %]
            [% IF ( stat == 'sum' ) %][% sumstat = bookingstats.$stat %][% END %]
            [% IF ( stat.match('^\d+$') && stat > 0 ) %][% count_registers = count_registers + 1 %][% END %]
            [% IF ( stat != 'sum' && (stat != 'unassigned' || showstat.bookings_found)) %]
                <tr>
                    <td>
                        [% IF (stat > 0 ) %]
                            [% showstat.info.cash_register_name %]
                        [% ELSIF (stat == 'cash' ) %]
                            Cash payments via SIP2
                        [% ELSIF (stat == 'card' ) %]
                            Credit card payments via SIP2
                        [% ELSIF (stat == 'unassigned' ) %]
                            Other payments
                        [% END %]
                    </td>
                    <td style="text-align:right;">[% IF (stat > 0 ) %][% showstat.starting_balance.booking_amount_formatted %][%END%]</td>
                    <td style="text-align:right;">[% showstat.payment.booking_amount_formatted %]</td>
                    <td style="text-align:right;">[% showstat.payout.booking_amount_formatted %]</td>
                    <td style="text-align:right;">[% showstat.final_balance.booking_amount_formatted %]</td>
                </tr>
            [% END %]
        [% END %]
    </tbody>
    <tfoot>
        <tr>
            <td>
                Total
            </td>
            <td style="text-align:right;">[% IF (count_registers > 0 ) %][% sumstat.starting_balance.booking_amount_formatted %][%END%]</td>
            <td style="text-align:right;">[% sumstat.payment.booking_amount_formatted %]</td>
            <td style="text-align:right;">[% sumstat.payout.booking_amount_formatted %]</td>
            <td style="text-align:right;">[% sumstat.final_balance.booking_amount_formatted %]</td>
        </tr>
    </tfoot>
</table>

[% IF (finesstats.type == 'finesoverview') %]
    <h4 style="margin-top:20px">Fines overview by fine type</h4>
    <table id="finesoverview">
        <thead>
            <tr>
                <th>Fine type</th>
                <th>Count</th>
                <th>Sum</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH finestat IN finesstats.data.keys %]
                [% showstat = finesstats.data.$finestat %]
                <tr>
                    <td>
                        [% INCLUDE accountTypeName %] 
                    </td>
                    <td style="text-align:right;">[% showstat.count %]</td>
                    <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                </tr>
            [% END %]
        </tbody>
        <tfoot>
            <tr>
                <td>
                    Total
                </td>
                <td style="text-align:right;">[% finesstats.sum.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.fines_amount_formatted %]</td>
            </tr>
        </tfoot>
    </table>
[% END %]

[% IF (finesstats.type == 'finesbyday' || finesstats.type == 'finesbymanager' || finesstats.type == 'finesbytype' || finesstats.type == 'paymentsbyday' || finesstats.type == 'paymentsbymanager' || finesstats.type == 'paymentsbytype') %]
    
    <h4 style="margin-top:20px">
        [% SWITCH finesstats.type %]
        [% CASE 'finesbytype' %]Detailed fines by type
        [% CASE 'finesbymanager' %]Detailed fines by manager
        [% CASE 'finesbyday' %]Detailed fines by day
        [% CASE 'paymentsbytype' %]Detailed payments by type
        [% CASE 'paymentsbymanager' %]Detailed payments by manager
        [% CASE 'paymentsbyday' %]Detailed payments by day
        [% CASE %][% seltype %]
        [%- END -%]
    </h4>
    <table id="finesbydate">
        <thead>
            <tr>
                <th>Day</th>
                <th>Amount</th>
                <th>
                    [% IF (finesstats.type == 'finesbyday' || finesstats.type == 'finesbymanager' || finesstats.type == 'finesbytype' ) %]Fine type[% ELSE %]Payment type[% END %]
                </th>
                <th>Patron/Barcode</th>
                <th>Description</th>
                <th>Manager</th>
                <th>Amount</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH showstat IN finesstats.data %]
                [% finestat = showstat.accounttype %]
                <tr>
                    <td style="text-align:right;">[% showstat.date %]</td>
                    <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    <td>
                        [% INCLUDE accountTypeName %] 
                    </td>
                    <td>
                        [% IF (! printview) %]<a href="/cgi-bin/koha/members/boraccount.pl?borrowernumber=[% showstat.borrowernumber %]">[% END %][% showstat.patron_name %][% IF (showstat.cardnumber) %] ([% showstat.cardnumber %][% END %])[% IF (! printview) %]</a>[% END %]
                    </td>
                    <td>[% showstat.description %]</td>
                    <td>[% showstat.manager_name %]</td>
                    <td>[% showstat.amount %]</td>
                </tr>
            [% END %]
        </tbody>
    </table>
[% END %]