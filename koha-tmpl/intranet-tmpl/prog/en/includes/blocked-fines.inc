[% USE Price %]
[% SET NoIssuesCharge = Koha.Preference('noissuescharge') %]
[% IF fines and fines > 0 %]
    <li>
        <span class="circ-hlt">Charges:</span>
        Patron has outstanding charges of [% fines | $Price %].
        [% IF !Koha.Preference('AllowFineOverride') && NoIssuesCharge && fines > NoIssuesCharge %]
           <span class="circ-hlt">Checkouts are BLOCKED because fine balance is OVER THE LIMIT.</span>
        [% END %]
        [% IF (checkCashRegisterFailed) %] 
            <a href="javascript:void()" class="btn btn-default btn-xs" disabled="disabled">Make payment</a>
            <a href="javascript:void()" class="btn btn-default btn-xs" disabled="disabled">Pay all fines</a></li>
            <div class="warn"><i class="fa fa-warning"></i> 
                Please open a cash register to enable cash payments. 
            </div>
        [% ELSE %]
            [% IF CAN_user_updatecharges_remaining_permissions %]
                <a href="/cgi-bin/koha/members/pay.pl?borrowernumber=[% patron.borrowernumber | uri %]" class="btn btn-default btn-xs" >Make payment</a>
                <a href="/cgi-bin/koha/members/paycollect.pl?borrowernumber=[% patron.borrowernumber | uri %]" class="btn btn-default btn-xs" >Pay all fines</a></li>
            [% END %]
        [% END %]
    </li>
[% END %]
