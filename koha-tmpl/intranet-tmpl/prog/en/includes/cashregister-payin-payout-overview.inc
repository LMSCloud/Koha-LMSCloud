[% PROCESS 'cashregister-fines-macros.inc' %]
[% USE KohaDates %]
[% USE raw %]


<h2>Revenues and expenditures overview: [% Branches.GetName(sessionbranch) | html %] ([% journalfrom | $KohaDates with_hours => 1 %][% IF (journalfrom != journalto) %] - [% journalto | $KohaDates with_hours => 1 %][% END %])</h2>
<p>Manager: [% loggedinusername | html %], Date: [% datetimenow | html %]</p>
[% IF (! printview) %]
<form id="showfinesoverview" action="/cgi-bin/koha/[% used_perl_script | html %]" method="post">
    [% INCLUDE 'csrf-token.inc' %]
    <input type="hidden" name="op" value="cud-payinoutoverview" />
    <fieldset class="rows" style="float: unset">
        <ol>
            <li>
                Cash register overview <input type="text" size="16" id="journalfrom" name="journalfrom" value="[% journalfrom | html %]" class="flatpickr" data-flatpickr-enable-time="true" />
                to <input type="text" size="16" id="journalto" name="journalto" value="[% journalto | html %]" class="flatpickr" data-flatpickr-enable-time="true" />
                <input type="hidden" name="finestype" value="payinoutoverview" />
                <input type="hidden" name="printview" value="" />
                <button id="noprintview" type="submit" name="allFromOpening" value="0">Select</button>
                <button id="printview" type="button" name="printview" value="print">Printview</button>
            </li>
        </ol>                      
    </fieldset>
</form>
[% END %]

[% showCashRegisterOverview | $raw %]
<h4 style="margin-top:20px;">Inpayment overview ([% cash_register.cash_register_name | html %])</h4>
<table id="inpaymentoverview" class="table-bordered">
    <thead>
        <tr>
            <th>Inpayment type</th>
            <th>Amount</th>
            <th>Reason</th>
        </tr>
    </thead>
    <tbody>
        [% FOREACH showstat IN finesstats.cashinout.INPAYMENT %]
            <tr>
                <td>[% resolveCashRegisterActionName(showstat.action) | html %]</td>
                <td style="text-align:right;">[% showstat.booking_amount_formatted | html %]</td>
                <td style="text-align:right;">[% showstat.reason | html %][% IF (showstat.accounttype) %][% resolveFinesTypeName(showstat.accounttype) | html %][% END %]</td>
            </tr>
        [% END %]
    </tbody>
    <tfoot>
        <tr>
            <td>
                Total
            </td>
            <td style="text-align:right;">[% finesstats.cashinout.SUM_INPAYMENT.booking_amount_formatted | html %]</td>
            <td></td>
        </tr>
    </tfoot>
</table>
<h4 style="margin-top:20px;">Outpayment overview ([% cash_register.cash_register_name | html %])</h4>
<table id="outpaymentoverview" class="table-bordered">
    <thead>
        <tr>
            <th>Outpayment type</th>
            <th>Amount</th>
            <th>Reason</th>
        </tr>
    </thead>
    <tbody>
        [% FOREACH showstat IN finesstats.cashinout.OUTPAYMENT %]
            <tr>
                <td>[% resolveCashRegisterActionName(showstat.action) | html %]</td>
                <td style="text-align:right;">[% showstat.booking_amount_formatted | html %]</td>
                <td style="text-align:right;">[% showstat.reason | html %][% IF (showstat.accounttype) %][% resolveFinesTypeName(showstat.accounttype) | html %][% END %]</td>
            </tr>
        [% END %]
    </tbody>
    <tfoot>
        <tr>
            <td>
                Total
            </td>
            <td style="text-align:right;">[% finesstats.cashinout.SUM_OUTPAYMENT.booking_amount_formatted | html %]</td>
            <td></td>
        </tr>
    </tfoot>
</table>


<h3 style="margin-top:30px">Fines overviews</h3>

[% IF !(finesstats.overview.data.account.mapped || finesstats.overview.data.account.unmapped) %]
<h4 style="margin-top:20px">Paid fines by account</h4>
<table id="mappedaccountoverview" class="table-bordered">
    <thead>
        <tr>
            <th>Payment type</th>
            <th>Account</th>
            <th>Count</th>
            <th>Sum</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td colspan="4">No paid fines during the selected period.</td>
        </tr>
    </tbody>
</table>
[% END %]

[% IF (finesstats.overview.data.mapaccount) %]
<h4 style="margin-top:20px">Paid fines by account</h4>
<table id="mappedaccountoverview" class="table-bordered">
    <thead>
        <tr>
            <th>Payment type</th>
            <th>Account</th>
            <th>Count</th>
            <th>Sum</th>
        </tr>
    </thead>
    <tbody>
        [% FOREACH ptype IN finesstats.overview.data.mapaccount.paid.mapped.keys.sort %]
            [% showstat = finesstats.overview.data.mapaccount.paid.mapped.$ptype %]
            <tr>
                <td>Payment</td>
                <td>[% ptype | html %]</td>
                <td style="text-align:right;">[% showstat.count | html %]</td>
                <td style="text-align:right;">[% showstat.fines_amount_formatted | html %]</td>
            </tr>
        [% END %]
        [% FOREACH ptype IN finesstats.overview.data.mapaccount.paid.unmapped.keys.sort %]
            [% showstat = finesstats.overview.data.mapaccount.paid.unmapped.$ptype %]
            <tr>
                <td>Payment</td>
                <td>
                    [% resolveFinesTypeName(ptype) | html %] (no account mapped)
                </td>
                <td style="text-align:right;">[% showstat.count | html %]</td>
                <td style="text-align:right;">[% showstat.fines_amount_formatted | html %]</td>
            </tr>
        [% END %]
        [% FOREACH ptype IN finesstats.overview.data.mapaccount.reversed.mapped.keys.sort %]
            [% showstat = finesstats.overview.data.mapaccount.reversed.mapped.$ptype %]
            <tr>
                <td>Reverse Payment</td>
                <td>[% ptype | html %]</td>
                <td style="text-align:right;">[% showstat.count | html %]</td>
                <td style="text-align:right;">[% showstat.fines_amount_formatted | html %]</td>
            </tr>
        [% END %]
        [% FOREACH ptype IN finesstats.overview.data.mapaccount.reversed.unmapped.keys.sort %]
            [% showstat = finesstats.overview.data.mapaccount.reversed.unmapped.$ptype %]
            <tr>
                <td>Reverse Payment</td>
                <td>
                    [% resolveFinesTypeName(ptype) | html %] (no account mapped)
                </td>
                <td style="text-align:right;">[% showstat.count | html %]</td>
                <td style="text-align:right;">[% showstat.fines_amount_formatted | html %]</td>
            </tr>
        [% END %]
    </tbody>
    <tfoot>
        [% IF (finesstats.overview.sum.paid && finesstats.overview.sum.paid.count > 0 ) %]
        <tr>
            <td colspan="2">
                Total fines paid
            </td>
            <td style="text-align:right;">[% finesstats.overview.sum.paid.count | html %]</td>
            <td style="text-align:right;">[% finesstats.overview.sum.paid.fines_amount_formatted | html %]</td>
        </tr>
        <tr>
            <td colspan="2">
                ... paid by card
            </td>
            <td style="text-align:right;">[% finesstats.overview.sum.cashtype.card.payment.count | html %]</td>
            <td style="text-align:right;">[% finesstats.overview.sum.cashtype.card.payment.payment_amount_formatted | html %]</td>
        </tr>
        <tr>
            <td colspan="2">
                ... paid cash
            </td>
            <td style="text-align:right;">[% finesstats.overview.sum.cashtype.cash.payment.count | html %]</td>
            <td style="text-align:right;">[% finesstats.overview.sum.cashtype.cash.payment.payment_amount_formatted | html %]</td>
        </tr>
        [% END %]
        [% IF (finesstats.overview.sum.reversed && finesstats.overview.sum.reversed.count > 0) %]
        <tr>
            <td colspan="2">
                Total reversed
            </td>
            <td style="text-align:right;">[% finesstats.overview.sum.reversed.count | html %]</td>
            <td style="text-align:right;">[% finesstats.overview.sum.reversed.fines_amount_formatted | html %]</td>
        </tr>
        [% END %]
        [% IF (finesstats.overview.sum.overall && finesstats.overview.sum.overall.count > 0) %]
        <tr>
            <td colspan="2">
                Total
            </td>
            <td style="text-align:right;">[% finesstats.overview.sum.overall.count | html %]</td>
            <td style="text-align:right;">[% finesstats.overview.sum.overall.fines_amount_formatted | html %]</td>
        </tr>
        [% END %]
    </tfoot>
</table>
[% END %]

<h3 style="margin-top:30px">Account management fees</h3>

<h4 style="margin-top:20px">Paid account management fee by borrower category</h4>
<table id="accountmanagementfeebyborrowertype" class="table-bordered">
    <thead>
        <tr>
            <th>Payment type</th>
            <th>Borrower category</th>
            <th>Count</th>
            <th>Sum</th>
        </tr>
    </thead>
    [% IF (finesstats.overview.data.accountfee.borrower_type) %]
        <tbody>
        [% FOREACH ptype IN finesstats.overview.data.accountfee.borrower_type.keys.sort %]
            [% FOREACH categ IN finesstats.overview.data.accountfee.borrower_type.$ptype.keys.sort %]
                [% showstat = finesstats.overview.data.accountfee.borrower_type.$ptype.$categ %]
                <tr>
                    <td>[% resolveAccountOffsetActionTypeName(ptype) | html %]</td>
                    <td>[% categ | html %]</td>
                    <td style="text-align:right;">[% showstat.count | html %]</td>
                    <td style="text-align:right;">[% showstat.fines_amount_formatted | html %]</td>
                </tr>
            [% END %]
        [% END %]
        </tbody>
        <tfoot>
            <tr>
                <td colspan="2">
                    Total
                </td>
                <td style="text-align:right;"></td>
                <td style="text-align:right;">[% finesstats.overview.sum.accountfee.borrower_type.fines_amount_formatted | html %]</td>
            </tr>
        </tfoot>
    [% ELSE %]
        <tbody>
            <tr>
                <td colspan="4">No account management fees accrued during the selected period.</td>
            </tr>
        </tbody>
    [% END %]
</table>


<h3 style="margin-top:20px">Detailed cash register outpayments</h4>

<p>
    The following payment overview lists detailed outpayments (without reverse payments) of the selected branch during the selected period.
</p>

<table id="finesbydate" class="table-bordered">
    <thead>
        <tr>
            <th class="title-string">Day</th>
            <th>Amount</th>
            <th>
                Payment type
            </th>
            <th>Patron/Barcode</th>
            <th>Description</th>
            <th>Amount</th>
        </tr>
    </thead>
    <tbody>
        [% FOREACH showstat IN finesstats.payments.data %]
            [% finestat = showstat.accounttype %]
            <tr>
                <td style="text-align:right;"><span title="[% showstat.date | html %]">[% showstat.date | $KohaDates %]</span></td>
                <td style="text-align:right;">[% showstat.fines_amount_formatted | html %]</td>
                <td>
                    [% IF (showstat.entrytype == 1) %]
                        [% resolveFinesTypeName(showstat.accounttype) | html %]
                    [% ELSE %]
                        [% resolveCashRegisterActionName(showstat.accounttype) | html %] ([% showstat.cash_register_name | html %]) [% IF (showstat.reason) %] ([% showstat.reason | html %])[% END %]
                    [% END %]
                </td>
                <td>
                    [% IF ( showstat.patron_is_deleted ) %]
                        [% showstat.patron_name | html %][% IF (showstat.cardnumber) %] ([% showstat.cardnumber | html %])[% END %]
                    [% ELSE %]
                        [% IF (! printview) %]<a href="/cgi-bin/koha/members/boraccount.pl?borrowernumber=[% showstat.borrowernumber | uri %]">[% END %][% showstat.patron_name | html %][% IF (showstat.cardnumber) %] ([% showstat.cardnumber | html %])[% END %][% IF (! printview) %]</a>[% END %]
                    [% END %]
                </td>
                <td>[% jno = 0 %]
                    [% IF (showstat.cash_register_journalno) %]
                         [% jno = 1 %]Journal no: [% showstat.cash_register_journalno | html %][% IF (showstat.description) %]; [% END %]
                    [% END %]
                    [% showstat.description | html %]
                </td>
                <td>[% showstat.amount | html %]</td>
            </tr>
        [% END %]
    </tbody>
</table>

[% MACRO jsextrainclude BLOCK %]
    <script type="text/javascript">
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
            return "[% currency_format.1 | html %]" + number_format(number,[% currency_format.2 | html %],"[% currency_format.3 | html %]","[% currency_format.4 | html %]");
        }

        $(document).ready( function() {
            
            $("#inpaymentoverview,#outpaymentoverview").dataTable({
                "bAutoWidth": false,
                "autoWidth": false,
                "bDestroy":true,
                "columnDefs": [
                    { "sortable": true, "searchable": false, 'targets': ["_all"] },
                    { "targets": [ 2 ], "sorting": [ "desc","asc" ], "type": "natural"  },
                    { "targets": [ 0,1 ], "sorting": [ "asc","desc" ]  },
                ],
                "columns": [ { "width": '150px' }, { "type": 'natural' }, null ],
                "iDisplayLength": 1000,
                "iDisplayStart": 0,
                "order": [[ 0, "asc" ]],
                "bSort" : true,
                "paging": false, // Dont want paging
                "bPaginate": false,
                "serverSide": false,
                "bFilter": false,
                "bInfo" : false,
                "oLanguage": {
                    "sEmptyTable": _("No changes during the selected period.")
                }
            });

            [%groupcol = '2' %][% sortdir = 'asc' %]

            $("#finesbydate").dataTable({
                'bAutoWidth': false,
                'aoColumnDefs': [
                    { "bSortable": true, "bSearchable": false, 'aTargets': ["_all"] },
                    { "aTargets": [ 1 ], "asSorting": [ "desc","asc" ], "sType": "natural"  },
                    { "visible": false, "aTargets": [[% groupcol | html %],5] }
                ],
                "aoColumns": [ { "sType": 'natural' }, null, null, null, null, null],
                "iDisplayLength": 100,
                "iDisplayStart": 0,
                "order": [[[% groupcol | html %], "[% sortdir | html %]"]],
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
         
                    api.column([% groupcol | html %], { order:'current'} ).data().each( function ( group, i ) {
                        if ( last !== group ) {
                            if ( lastid != '' ) {
                                $("#"+lastid).text(money_format(sum));
                            }
                            var val = group;
                            if ( val.trim() == "" ) {
                                val = _("&lt;No value&gt;");
                            }
                            lastid = "finesgrouprow" + groupnum;
                            $(rows).eq( i ).before(
                                '<tr class="group"><td colspan="4" class="finesgroupsum">'+val+':&nbsp;&nbsp;<span id="'+ lastid + '"></span></td></tr>'
                            );
                            last = group;
                            groupnum++;
                            sum = 0.0;
                            txt = '';
                        }
                        sum += parseFloat(api.cell($(rows).eq( i ),5,{order: 'current'} ).data());
                        if ( count == i && lastid != '' ) {
                            $("#"+lastid).text(money_format(sum));
                        }
                    });
                },
                "oLanguage": {
                    "sEmptyTable": _("No cash register outpayments during the selected period.")
                }
            });
            // Order by the grouping
            $('#finesbydate tbody').on( 'click', 'tr.group', function () {
                var currentOrder = table.order()[0];
                if ( currentOrder[0] === [% groupcol | html %] && currentOrder[1] === 'asc' ) {
                    table.order( [ [% groupcol | html %], 'desc' ] ).draw();
                }
                else {
                    table.order( [ [% groupcol | html %], 'asc' ] ).draw();
                }
            } );
            $("#finesbydate_wrapper .pager").removeClass("pager");
            
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
[% END %]
