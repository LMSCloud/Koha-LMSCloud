[% SWITCH account.accounttype %]
    [% CASE 'Pay' %]Payment, thanks
    [% CASE 'Pay00' %]Payment, thanks (cash via SIP2)
    [% CASE 'Pay01' %]Payment, thanks (VISA via SIP2)
    [% CASE 'Pay02' %]Payment, thanks (credit card via SIP2)
    [% CASE 'N' %]New card
    [% CASE 'F' %]Fine
    [% CASE 'A' %]Account management fee
    [% CASE 'M' %]Sundry
    [% CASE 'L' %]Lost item
    [% CASE 'W' %]Writeoff
    [% CASE 'CAN' %]Fine cancelled
    [% CASE 'FU' %]Accruing fine
    [% CASE 'HE' %]Hold waiting too long
    [% CASE 'Rent' %]Rental fee
    [% CASE 'FOR' %]Forgiven
    [% CASE 'LR' %]Lost item fee refund
    [% CASE 'PF' %]Processing fee
    [% CASE 'PAY' %]Payment
    [% CASE 'WO' %]Writeoff
    [% CASE 'C' %]Credit
    [% CASE 'CR' %]Credit
    [% CASE 'CL1' %]Overdue fine (level 1)
    [% CASE 'CL2' %]Overdue fine (level 2)
    [% CASE 'CL3' %]Overdue fine (level 3)
    [% CASE 'CL4' %]Overdue fine (level 4)
    [% CASE 'CL5' %]Overdue fine (level 5)
    [% CASE 'NOTF' %]Notice fee
    [% CASE %][% account.accounttype %]
[%- END -%]