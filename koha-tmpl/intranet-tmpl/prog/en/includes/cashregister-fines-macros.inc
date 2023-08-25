[% MACRO resolveFinesTypeName(finestat) BLOCK -%][% SWITCH finestat %]
  [% CASE 'PaymentOfPaidBackPayment' %]Payment of another reversed payment
  [% CASE 'PartialPaymentOfPaidBackPayment' %]Partial payment of another reversed payment
  [% CASE 'PartialPaymentReverseOfPaidBackPayment' %]Partial payment of a reversed payment
  [% CASE 'ReversedPaymentOfPaidBackPayment' %]Reversed payment of another reversed payment
  [% CASE %][% finestat %]
[% END %][% END-%]

[% MACRO resolveCashRegisterActionName(action) BLOCK -%]
[%    SWITCH action %]
[%        CASE 'PAYMENT'         %]Patron payment
[%        CASE 'REVERSE_PAYMENT' %]Reverse payment
[%        CASE 'CREDIT_PAYOUT'   %]Credit payout
[%        CASE 'ADJUSTMENT'      %]Difference posting
[%        CASE 'PAYOUT'          %]Cash payment
[%        CASE 'DEPOSIT'         %]Deposit
[%        CASE 'CREDIT'          %]Credit
[%        CASE %][% action %]
[%    END %]
[% END-%]

[% MACRO resolveAccountOffsetActionTypeName(type) BLOCK -%]
[%    SWITCH type %]
[%        CASE 'Payment'         %]Payment
[%        CASE 'Credit Applied'  %]Payment
[%        CASE 'Reverse Payment' %]Reverse payment
[%        CASE %][% type %]
[%    END %]
[% END-%]

[% MACRO resolveReportBranchName(getbranch) BLOCK -%]
[% IF getbranch == '' %]All libraries[% ELSE %][% FOREACH branch IN branchloop %][% IF (branch.branchcode == getbranch) %][% branch.branchname %]</option>[% END %][% END %][% END %]
[% END %]

[% MACRO showCashRegisterOverview BLOCK -%]
<h4 style="margin-top:20px">Cash position</h4>
<table id="cashpaymentoverview" class="table-bordered">
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
                        [% IF (stat.match('^\d+$') && stat > 0 ) %]
                            [% showstat.info.cash_register_name %]
                        [% ELSIF (stat == 'cash' ) %]
                            Cash payments via SIP2
                        [% ELSIF (stat == 'card' ) %]
                            Credit card payments via SIP2
                        [% ELSIF (stat == 'unassigned' ) %]
                            Other payments (not traced by cash registers)
                        [% END %]
                    </td>
                    <td style="text-align:right;">[% IF (stat.match('^\d+$') && stat > 0 ) %][% showstat.starting_balance.booking_amount_formatted %][%END%]</td>
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
[% END-%]
