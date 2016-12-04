[% USE Price %]
[% SET NoIssuesCharge = Koha.Preference('noissuescharge') %]
[% IF fines > 0 %]
    <li>
        <span class="circ-hlt">Fees &amp; Charges:</span>
        Patron has outstanding fees &amp; charges of [% fines | $Price %].
        [% IF !Koha.Preference('AllowFineOverride') && NoIssuesCharge && fines > NoIssuesCharge %]
           <span class="circ-hlt">Checkouts are BLOCKED because fine balance is OVER THE LIMIT.</span>
        [% END %]
        [% IF (checkCashRegisterFailed) %] 
            <a href="javascript:void()" class="btn btn-mini" disabled="disabled">Make payment</a>
            <a href="javascript:void()" class="btn btn-mini" disabled="disabled">Pay all fines</a></li>
            <div class="warn"><i class="fa fa-warning"></i> 
                Please open a cash register to enable cash payments. 
            </div>
        [% ELSE %]
            <a href="/cgi-bin/koha/members/pay.pl?borrowernumber=[% borrowernumber %]" class="btn btn-mini" >Make payment</a>
            <a href="/cgi-bin/koha/members/paycollect.pl?borrowernumber=[% borrowernumber %]" class="btn btn-mini" >Pay all fines</a></li>
        [% END %]
    </li>
[% END %]
