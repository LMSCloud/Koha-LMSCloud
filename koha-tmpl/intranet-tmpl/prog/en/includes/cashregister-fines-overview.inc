[% PROCESS 'cashregister-fines-macros.inc' %]
[% USE KohaDates %]

[% IF (finesstats.type == 'inoutpaymentoverview') %]
    <h2>Cash register overview: [% Branches.GetName(sessionbranch) %] ([% journalfrom %][% IF (journalfrom != journalto) %] - [% journalto %][% END %])</h2>
    <p>Manager: [% loggedinusername %], Date: [% datetimenow %]</p>
    [% IF (! printview) %]
    <form id="showfinesoverview" action="/cgi-bin/koha/[% used_perl_script %]" method="post">
        <input type="hidden" name="op" value="dayview" />
        <fieldset class="rows" style="float: unset">
            <ol>
                <li>
                    Cash register overview <input type="text" size="16" id="journalfrom" name="journalfrom" value="[% journalfrom %]" class="datetimepicker" />
                    to <input type="text" size="16" id="journalto" name="journalto" value="[% journalto %]" class="datetimepicker" />
                    <input type="hidden" name="finestype" value="inoutpaymentoverview" />
                    <input type="hidden" name="printview" value="" />
                    <button id="noprintview" type="submit" name="allFromOpening" value="0">Select</button>
                    <button id="printview" type="button" name="printview" value="print">Printview</button>
                </li>
            </ol>                      
        </fieldset>
    </form>
    [% END %]
    [% showCashRegisterOverview %]
    <h4 style="margin-top:20px;">Inpayment overview ([% cash_register.cash_register_name %])</h4>
    <table id="inpaymentoverview">
        <thead>
            <tr>
                <th>Inpayment type</th>
                <th>Amount</th>
                <th>Reason</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH showstat IN finesstats.INPAYMENT %]
                <tr>
                    <td>[% resolveCashRegisterActionName(showstat.action) %]</td>
                    <td style="text-align:right;">[% showstat.booking_amount_formatted %]</td>
                    <td style="text-align:right;">[% showstat.reason %][% IF (showstat.accounttype) %][% resolveFinesTypeName(showstat.accounttype) %][% END %]</td>
                </tr>
            [% END %]
        </tbody>
        <tfoot>
            <tr>
                <td>
                    Total
                </td>
                <td style="text-align:right;">[% finesstats.SUM_INPAYMENT.booking_amount_formatted %]</td>
                <td></td>
            </tr>
        </tfoot>
    </table>
    <h4 style="margin-top:20px;">Outpayment overview ([% cash_register.cash_register_name %])</h4>
    <table id="outpaymentoverview">
        <thead>
            <tr>
                <th>Outpayment type</th>
                <th>Amount</th>
                <th>Reason</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH showstat IN finesstats.OUTPAYMENT %]
                <tr>
                    <td>[% resolveCashRegisterActionName(showstat.action) %]</td>
                    <td style="text-align:right;">[% showstat.booking_amount_formatted %]</td>
                    <td style="text-align:right;">[% showstat.reason %][% IF (showstat.accounttype) %][% resolveFinesTypeName(showstat.accounttype) %][% END %]</td>
                </tr>
            [% END %]
        </tbody>
        <tfoot>
            <tr>
                <td>
                    Total
                </td>
                <td style="text-align:right;">[% finesstats.SUM_OUTPAYMENT.booking_amount_formatted %]</td>
                <td></td>
            </tr>
        </tfoot>
    </table>
[% ELSE %]
     <h2>Fines overview: [% resolveReportBranchName(reportbranch) %] ([% journalfrom %][% IF (journalfrom != journalto) %] - [% journalto %][% END %])</h2>
    [% IF (!printview) %]
        <form id="showfinesoverview" action="/cgi-bin/koha/[% used_perl_script %]" method="post">
            <input type="hidden" name="op" value="finesreport" />
            <fieldset class="rows" style="float: unset">
                <ol>
                    <li>
                        Fines overview <input type="text" size="16" id="journalfrom" name="journalfrom" value="[% journalfrom %]" class="datetimepicker" />
                        to <input type="text" size="16" id="journalto" name="journalto" value="[% journalto %]" class="dateptimeicker" />
                        [% seltypes = [ 'paidfinesbytype', 'paidfinesbymanager', 'paidfinesbyday', 'finesoverview', 'finesbytype', 'finesbymanager', 'finesbyday', 'paymentsbytype', 'paymentsbymanager', 'paymentsbyday'] %]
                        <select name="finestype">
                            [% FOREACH seltype IN seltypes %]
                                [% IF (finesstats.type == seltype) %]
                                <option value="[% seltype %]" selected="selected">
                                [% ELSE %]
                                <option value="[% seltype %]">
                                [% END %]
                                [% SWITCH seltype %]
                                [% CASE 'finesoverview' %]Fines overview
                                [% CASE 'paidfinesbytype' %]Detailed paid fines by type
                                [% CASE 'paidfinesbymanager' %]Detailed paid fines by manager
                                [% CASE 'paidfinesbyday' %]Detailed paid fines by day
                                [% CASE 'finesbytype' %]Detailed accrued fines by type
                                [% CASE 'finesbymanager' %]Detailed accrued fines by manager
                                [% CASE 'finesbyday' %]Detailed accrued fines by day
                                [% CASE 'paymentsbytype' %]Detailed payments by type
                                [% CASE 'paymentsbymanager' %]Detailed payments by manager
                                [% CASE 'paymentsbyday' %]Detailed payments by day
                                [% CASE %][% seltype %]
                                [%- END -%]
                                </option>
                            [% END %]
                        </select>&nbsp;<input type="hidden" name="printview" value="" />
                        of library
                        <select name="reportbranch">
                            <option value="" selected="selected">All libraries</option>
                            [% PROCESS options_for_libraries libraries => Branches.all( selected => reportbranch, restrict => 'NoMobileStations' ) %]
                        </select>
                        <button id="noprintview" type="submit" name="allFromOpening" value="0">Select</button>
                        <button id="printview" type="submit" name="printview" value="print"">Printview</button>
                    </li>
                </ol>                      
            </fieldset>
        </form>
    [% ELSE %]
        <p>Manager: [% loggedinusername %], Date: [% datetimenow %]</p>
    [% END %]
[% END %]    
[% IF (finesstats.type == 'finesoverview') %]

    <h3 style="margin-top:30px">Fines overviews</h3>
    
    [% IF (finesstats.data.account.mapped) %]
        <h4 style="margin-top:20px">Paid fines by account</h4>
        <table id="mappedaccountoverview">
            <thead>
                <tr>
                    <th>Account</th>
                    <th>Count</th>
                    <th>Sum</th>
                </tr>
            </thead>
            <tbody>
                [% FOREACH ptype IN finesstats.data.account.mapped.keys.sort %]
                    [% showstat = finesstats.data.account.mapped.$ptype %]
                    <tr>
                        <td>[% ptype %]</td>
                        <td style="text-align:right;">[% showstat.count %]</td>
                        <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    </tr>
                [% END %]
            </tbody>
        </table>
    
        [% IF (finesstats.data.account.unmapped) %]
        <h4 style="margin-top:20px">Unmapped paid fines (to above accounts)</h4>
        <table id="unmappedaccountoverview">
            <thead>
                <tr>
                    <th>Unmapped fine type</th>
                    <th>Description</th>
                    <th>Count</th>
                    <th>Sum</th>
                </tr>
            </thead>
            <tbody>
                [% FOREACH ptype IN finesstats.data.account.unmapped.keys.sort %]
                    [% showstat = finesstats.data.account.unmapped.$ptype %]
                    <tr>
                        <td>[% ptype %]</td>
                        <td>[% resolveFinesTypeName(ptype) %] </td>
                        <td style="text-align:right;">[% showstat.count %]</td>
                        <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    </tr>
                [% END %]
            </tbody>
        </table>
        [% END %]
    [% END %]
    
    <h4 style="margin-top:20px">Paid fines overview by fine type</h4>
    <table id="finestypeoverview">
        <thead>
            <tr>
                <th>Payment type</th>
                <th>Fine type</th>
                <th>Count</th>
                <th>Sum</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH finestat IN finesstats.data.paidtype.keys.sort %]
                [% showstat = finesstats.data.paidtype.$finestat %]
                <tr>
                    <td>Payment</td>
                    <td>
                        [% resolveFinesTypeName(finestat) %] 
                    </td>
                    <td style="text-align:right;">[% showstat.count %]</td>
                    <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                </tr>
            [% END %]
            [% FOREACH finestat IN finesstats.data.reversedtype.keys.sort %]
                [% showstat = finesstats.data.reversedtype.$finestat %]
                <tr>
                    <td>Reverse Payment</td>
                    <td>
                        [% resolveFinesTypeName(finestat) %] 
                    </td>
                    <td style="text-align:right;">[% showstat.count %]</td>
                    <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                </tr>
            [% END %]
        </tbody>
        <tfoot>
            [% IF (finesstats.sum.paid && finesstats.sum.paid.count > 0 ) %]
            <tr>
                <td colspan="2">
                    Total fines paid
                </td>
                <td style="text-align:right;">[% finesstats.sum.paid.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.paid.fines_amount_formatted %]</td>
            </tr>
            <tr>
                <td colspan="2">
                    ... paid by card
                </td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.card.payment.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.card.payment.payment_amount_formatted %]</td>
            </tr>
            <tr>
                <td colspan="2">
                    ... paid cash
                </td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.cash.payment.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.cash.payment.payment_amount_formatted %]</td>
            </tr>
            [% END %]
            [% IF (finesstats.sum.reversed && finesstats.sum.reversed.count > 0) %]
            <tr>
                <td colspan="2">
                    Total reversed
                </td>
                <td style="text-align:right;">[% finesstats.sum.reversed.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.reversed.fines_amount_formatted %]</td>
            </tr>
            [% END %]
            [% IF (finesstats.sum.overall && finesstats.sum.overall.count > 0) %]
            <tr>
                <td colspan="2">
                    Total
                </td>
                <td style="text-align:right;">[% finesstats.sum.overall.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.overall.fines_amount_formatted %]</td>
            </tr>
            [% END %]
        </tfoot>
    </table>
    
    <h4 style="margin-top:20px">Paid fines overview by fine type and item type</h4>
    <table id="finesoverview">
        <thead>
            <tr>
                <th>Payment type</th>
                <th>Fine type</th>
                <th>Item type</th>
                <th>Count</th>
                <th>Sum</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH finestat IN finesstats.data.paid.keys.sort %]
                [% typestat = finesstats.data.paid.$finestat.keys.sort %]
                [% FOREACH typestat IN finesstats.data.paid.$finestat.keys.sort %]
                    [% showstat = finesstats.data.paid.$finestat.$typestat %]
                    <tr>
                        <td>Payment</td>
                        <td>
                            [% resolveFinesTypeName(finestat) %] 
                        </td>
                        <td>[% showstat.itemtypedescription %]</td>
                        <td style="text-align:right;">[% showstat.count %]</td>
                        <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    </tr>
                [% END %]
            [% END %]
            [% FOREACH finestat IN finesstats.data.reversed.keys.sort %]
                [% typestat = finesstats.data.reversed.$finestat.keys.sort %]
                [% FOREACH typestat IN finesstats.data.reversed.$finestat.keys.sort %]
                    [% showstat = finesstats.data.reversed.$finestat.$typestat %]
                    <tr>
                        <td>Reverse Payment</td>
                        <td>
                            [% resolveFinesTypeName(finestat) %] 
                        </td>
                        <td>[% showstat.itemtypedescription %]</td>
                        <td style="text-align:right;">[% showstat.count %]</td>
                        <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    </tr>
                [% END %]
            [% END %]
        </tbody>
        <tfoot>
            [% IF (finesstats.sum.paid && finesstats.sum.paid.count > 0 ) %]
            <tr>
                <td colspan="3">
                    Total fines paid
                </td>
                <td style="text-align:right;">[% finesstats.sum.paid.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.paid.fines_amount_formatted %]</td>
            </tr>
            <tr>
                <td colspan="3">
                    ... paid by card
                </td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.card.payment.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.card.payment.payment_amount_formatted %]</td>
            </tr>
            <tr>
                <td colspan="3">
                    ... paid cash
                </td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.cash.payment.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.cashtype.cash.payment.payment_amount_formatted %]</td>
            </tr>
            [% END %]
            [% IF (finesstats.sum.reversed && finesstats.sum.reversed.count > 0 ) %]
            <tr>
                <td colspan="3">
                    Total reversed
                </td>
                <td style="text-align:right;">[% finesstats.sum.reversed.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.reversed.fines_amount_formatted %]</td>
            </tr>
            [% END %]
            [% IF (finesstats.sum.overall && finesstats.sum.overall.count > 0) %]
            <tr>
                <td colspan="3">
                    Total
                </td>
                <td style="text-align:right;">[% finesstats.sum.overall.count %]</td>
                <td style="text-align:right;">[% finesstats.sum.overall.fines_amount_formatted %]</td>
            </tr>
            [% END %]
        </tfoot>
    </table>
    
    [% IF (finesstats.data.cashregister) %]
    <h3 style="margin-top:30px">Cash register overview</h3>
    
    [% FOREACH cashreg IN finesstats.data.cashregister.keys.sort %]
    <h4 style="margin-top:20px">Cash register: [% cashreg %]</h4>
    <table id="cashregoverview">
        <thead>
            <tr>
                <th>Payment type</th>
                <th>Reason</th>
                <th>Type</th>
                <th>Count</th>
                <th>Sum</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH action IN finesstats.data.cashregister.$cashreg.keys.sort %]
                [% FOREACH reason IN finesstats.data.cashregister.$cashreg.$action.keys.sort %]
                    [% FOREACH accounttype IN finesstats.data.cashregister.$cashreg.$action.$reason.keys.sort %]
                        [% showstat = finesstats.data.cashregister.$cashreg.$action.$reason.$accounttype %]
                        <tr>
                            <td>[% resolveCashRegisterActionName(action) %]</td>
                            <td>[% reason %]</td>
                            <td>[% IF (accounttype) %][% resolveFinesTypeName(accounttype) %][% END %]</td>
                            <td style="text-align:right;">[% showstat.count %]</td>
                            <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                        </tr>
                    [% END %]
                [% END %]
            [% END %]
        </tbody>
    </table>
    [% END %]
    [% END %]

    [% IF (finesstats.data.accountfee) %]
    <h3 style="margin-top:30px">Account management fees</h3>
    
    [% IF (finesstats.data.accountfee.borrower_type) %]
    <h4 style="margin-top:20px">Paid account management fee by borrower category</h4>
    <table id="accountmanagementfeebyborrowertype">
        <thead>
            <tr>
                <th>Payment type</th>
                <th>Borrower category</th>
                <th>Count</th>
                <th>Sum</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH ptype IN finesstats.data.accountfee.borrower_type.keys.sort %]
                [% FOREACH categ IN finesstats.data.accountfee.borrower_type.$ptype.keys.sort %]
                    [% showstat = finesstats.data.accountfee.borrower_type.$ptype.$categ %]
                    <tr>
                        <td>[% resolveAccountOffsetActionTypeName(ptype) %]</td>
                        <td>[% categ %]</td>
                        <td style="text-align:right;">[% showstat.count %]</td>
                        <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    </tr>
                [% END %]
            [% END %]
        </tbody>
    </table>
    [% END %]
    
    [% IF (finesstats.data.accountfee.borrower_town) %]
    <h4 style="margin-top:20px">Paid account management fee by borrower town</h4>
    <table id="accountmanagementfeebyborrowertown">
        <thead>
            <tr>
                <th>Payment type</th>
                <th>Town</th>
                <th>Count</th>
                <th>Sum</th>
            </tr>
        </thead>
        <tbody>
            [% FOREACH ptype IN finesstats.data.accountfee.borrower_town.keys.sort %]
                [% FOREACH categ IN finesstats.data.accountfee.borrower_town.$ptype.keys.sort %]
                    [% showstat = finesstats.data.accountfee.borrower_town.$ptype.$categ %]
                    <tr>
                        <td>[% resolveAccountOffsetActionTypeName(ptype) %]</td>
                        <td>[% categ %]</td>
                        <td style="text-align:right;">[% showstat.count %]</td>
                        <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    </tr>
                [% END %]
            [% END %]
        </tbody>
    </table>
    [% END %]
    [% END %]
[% ELSIF (finesstats.type == 'paidfinesbyday' || finesstats.type == 'paidfinesbymanager' || finesstats.type == 'paidfinesbytype' || finesstats.type == 'finesbyday' || finesstats.type == 'finesbymanager' || finesstats.type == 'finesbytype' || finesstats.type == 'paymentsbyday' || finesstats.type == 'paymentsbymanager' || finesstats.type == 'paymentsbytype') %]
    <h3 style="margin-top:20px">
        [% SWITCH finesstats.type %]
        [% CASE 'paidfinesbytype' %]Detailed paid fines by type
        [% CASE 'paidfinesbymanager' %]Detailed paid fines by manager
        [% CASE 'paidfinesbyday' %]Detailed paid fines by day
        [% CASE 'finesbytype' %]Detailed accrued fines by type
        [% CASE 'finesbymanager' %]Detailed accrued fines by manager
        [% CASE 'finesbyday' %]Detailed accrued fines by day
        [% CASE 'paymentsbytype' %]Detailed payments by type
        [% CASE 'paymentsbymanager' %]Detailed payments by manager
        [% CASE 'paymentsbyday' %]Detailed payments by day
        [% CASE %][% seltype %]
        [%- END -%]
    </h4>
    [% IF (finesstats.type == 'paymentsbyday' || finesstats.type == 'paymentsbymanager' || finesstats.type == 'paymentsbytype') %]
    <p>
        The following payment overview lists detailed payments of the selected branch during the selected period. It includes all cash payments, deposits and adjustments of cash registers during the selected period.
    </p>
    [% END %]
    <table id="finesbydate">
        <thead>
            <tr>
                <th class="title-string" >Day</th>
                <th>Amount</th>
                <th>
                    [% IF (finesstats.type == 'paidfinesbyday' || finesstats.type == 'paidfinesbymanager' || finesstats.type == 'paidfinesbytype' || finesstats.type == 'finesbyday' || finesstats.type == 'finesbymanager' || finesstats.type == 'finesbytype' ) %]Fine type[% ELSE %]Payment type[% END %]
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
                    <td style="text-align:right;"><span title="[% showstat.date %]">[% showstat.date | $KohaDates %]</span></td>
                    <td style="text-align:right;">[% showstat.fines_amount_formatted %]</td>
                    <td>
                        [% IF (showstat.entrytype == 1) %]
                            [% resolveFinesTypeName(showstat.accounttype) %]
                        [% ELSE %]
                            [% resolveCashRegisterActionName(showstat.accounttype) %] ([% showstat.cash_register_name %]) [% IF (showstat.reason) %] ([% showstat.reason %])[% END %]
                        [% END %]
                    </td>
                    <td>
                        [% IF ( showstat.patron_is_deleted ) %]
                            [% showstat.patron_name %][% IF (showstat.cardnumber) %] ([% showstat.cardnumber %])[% END %]
                        [% ELSE %]
                            [% IF (! printview) %]<a href="/cgi-bin/koha/members/boraccount.pl?borrowernumber=[% showstat.borrowernumber %]">[% END %][% showstat.patron_name %][% IF (showstat.cardnumber) %] ([% showstat.cardnumber %])[% END %][% IF (! printview) %]</a>[% END %]
                        [% END %]
                    </td>
                    <td>[% showstat.description %]</td>
                    <td>[% showstat.manager_name %]</td>
                    <td>[% showstat.amount %]</td>
                </tr>
            [% END %]
        </tbody>
    </table>
[% END %]

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
            return "[% currency_format.1 %]" + number_format(number,[% currency_format.2 %],"[% currency_format.3 %]","[% currency_format.4 %]");
        }

        $(document).ready( function() {

            $("#journalfrom:visible").datetimepicker({});
            $("#journalto:visible").datetimepicker({});

            [% IF (finesstats.type == 'finesoverview') %]
            $("#finesoverview").dataTable($.extend(true, {}, dataTablesDefaults, {
                'bAutoWidth': false,
                'aoColumnDefs': [
                    { "bSortable": true, "bSearchable": false, 'aTargets': ["_all"] },
                    { "aTargets": [ 4 ], "asSorting": [ "desc","asc" ], "sType": "natural"  },
                    { "aTargets": [ 0,1,2,4 ], "asSorting": [ "asc","desc" ]  },
                ],
                "aoColumns": [ { "sWidth": '150px' }, { "sWidth": '150px' }, { sWidth: '150px' }, { "sType": 'natural' }, { "sType": 'natural' }],
                "iDisplayLength": 1000,
                "iDisplayStart": 0,
                "order": [[ 0, "asc" ],[ 1, "asc" ],[ 2, "asc" ]],
                "bSort" : true,
                "bPaginate": false,
                "serverSide": false,
                "bFilter": false,
                "bInfo" : false,
                "autoWidth": true,
                "oLanguage": {
                    "sEmptyTable": _("No paid fines during the selected period.")
                }
            }));
            $("#finestypeoverview").dataTable($.extend(true, {}, dataTablesDefaults, {
                'bAutoWidth': false,
                'aoColumnDefs': [
                    { "bSortable": true, "bSearchable": false, 'aTargets': ["_all"] },
                    { "aTargets": [ 3 ], "asSorting": [ "desc","asc" ], "sType": "natural"  },
                    { "aTargets": [ 0,1,3 ], "asSorting": [ "asc","desc" ]  },
                ],
                "aoColumns": [ { "sWidth": '150px' }, { "sWidth": '150px' }, { "sType": 'natural' }, { "sType": 'natural' }],
                "iDisplayLength": 1000,
                "iDisplayStart": 0,
                "order": [[ 0, "asc" ],[ 1, "asc" ]],
                "bSort" : true,
                "bPaginate": false,
                "serverSide": false,
                "bFilter": false,
                "bInfo" : false,
                "autoWidth": true,
                "oLanguage": {
                    "sEmptyTable": _("No paid fines during the selected period.")
                }
            }));
            [% END %]
            
            [% IF (finesstats.type == 'inoutpaymentoverview' ) %]
            $("#inpaymentoverview,#outpaymentoverview").dataTable($.extend(true, {}, dataTablesDefaults, {
                'bAutoWidth': true,
                'aoColumnDefs': [
                    { "bSortable": true, "bSearchable": false, 'aTargets': ["_all"] },
                    { "aTargets": [ 2 ], "asSorting": [ "desc","asc" ], "sType": "natural"  },
                    { "aTargets": [ 0,1 ], "asSorting": [ "asc","desc" ]  },
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
                    "sEmptyTable": _("No changes during the selected period.")
                }
            }));
            [% END %]
            
            $("#finesoverview_wrapper .pager").removeClass("pager");
            $("#finestypeoverview_wrapper .pager").removeClass("pager");

            [% IF (finesstats && ( finesstats.type == 'paidfinesbyday' || finesstats.type == 'paidfinesbytype' ||  finesstats.type == 'paidfinesbymanager' || finesstats.type == 'finesbyday' || finesstats.type == 'finesbytype' ||  finesstats.type == 'finesbymanager' || finesstats.type == 'paymentsbyday' || finesstats.type == 'paymentsbytype' ||  finesstats.type == 'paymentsbymanager')) %]
            [% IF    ( finesstats.type == 'paidfinesbyday' || finesstats.type == 'finesbyday' || finesstats.type == 'paymentsbyday')     %][% groupcol = '0' %][% sortdir = 'desc' %]
            [% ELSIF ( finesstats.type == 'paidfinesbytype' || finesstats.type == 'finesbytype' || finesstats.type == 'paymentsbytype')    %][% groupcol = '2' %][% sortdir = 'asc' %]
            [% ELSIF ( finesstats.type == 'paidfinesbymanager' || finesstats.type == 'finesbymanager' || finesstats.type == 'paymentsbymanager') %][% groupcol = '5' %][% sortdir = 'asc' %]
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
                                val = _("&lt;No value&gt;");
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
                    "sEmptyTable": _("No fines during the selected period.")
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
[% END %]
