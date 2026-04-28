[% USE Branches %]
[% IF ( status == 'manage' || status == 'close' ) %]
    <div class="cashregisterinfo">
        <h5>[% cash_register.cash_register_name | html %]</h5>
        <ul>
            <li class="cashregisterinfoentry">Library: [% Branches.GetName(cash_register.cash_register_branchcode) | html %]</li>
            <li>&nbsp;</li>
            <li><span class="hint">Balance</span></li>
            <li class="cashregisterimportantinfoentry">Cash balance: [% cash_register.cash_register_balance_formatted | html %]</li>
            <li class="cashregisterinfoentry">Opening balance: [% cash_register_info.opening_balance_formatted | html %]</li>
            <li class="cashregisterinfoentry">Cash receipts: [% cash_register_info.inpayments_amount_formatted | html %]</li>
            <li class="cahsregisterinfoentry">Cash payments: [% cash_register_info.payouts_amount_formatted | html %]</li>
            [% IF ( lastTransaction ) %]
                <li>&nbsp;</li>
                <li><span class="hint">Last transaction</span></li>
                [% cashaction = lastTransaction.action %]
                <li class="cashregisterinfoentry">Action: [% INCLUDE cashActionName %]</li>
                <li class="cashregisterinfoentry">Amount: [% lastTransaction.booking_amount_formatted | html %]</li>
                <li class="cashregisterinfoentry">Time: [% lastTransaction.booking_time | html %]</li>
            [% END %]
            <li>&nbsp;</li>
            <li><span class="hint">Manager</span></li>
            <li class="cashregisterinfoentry">Opened on: [% cash_register_info.opening_booking_time | html %]</li>
            <li class="cashregisterinfoentry">Opened by: [% cash_register_info.opening_manager | html %]</li>
            [% FOREACH additionalOpener IN cash_register_info.also_used_by_manager %]
                <li class="cashregisterinfoentry">Also in use by: [% additionalOpener.name | html %]</li>
            [% END %]
        </ul>
    </div>
[% END %]
