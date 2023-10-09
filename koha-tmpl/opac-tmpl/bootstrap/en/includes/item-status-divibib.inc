[% USE Branches %]
[% USE Koha %]
[% USE AuthorisedValues %]
[% SET itemavailable = 1 %]

[%#- This include takes two parameters: an item structure -%]
[%#- and an optional loan (issue) structure.  The issue -%]
[%#- structure is used by course reserves pages, which do -%]
[%#- not use an API to fetch items that populates item.datedue. -%]

[% SET checkout = item.checkout %]
[% SET waiting  = item.holds.waiting.count %]
[% IF include_schema_org %]
    [% IF item.damaged or checkout or item.itemlost %]
        <link property="availability" href="http://schema.org/OutOfStock" />
    [% ELSIF item.withdrawn %]
        <link property="availability" href="http://schema.org/Discontinued" />
    [% ELSIF item.notforloan or item.itemtype.notforloan %]
        <link property="availability" href="http://schema.org/InStoreOnly" />
    [% ELSE %]
        <link property="availability" href="http://schema.org/InStock" />
    [% END %]
[% END %]

[% IF ( item.itemlost ) %]
    [% SET itemavailable = 0 %]
    [% itemlost_lib = AuthorisedValues.GetDescriptionByKohaField( kohafield => 'items.itemlost', authorised_value => item.itemlost, opac => 1 ) %]
    [% IF itemlost_lib %]
        <span class="item-status lost">[% itemlost_lib | html %]</span>
    [% ELSE %]
        <span class="item-status lost">Item lost</span>
    [% END %]
[% END %]

[% IF checkout %]
    [% SET itemavailable = 0 %]
    <span class="item-status checkedout">Checked out</span>
[% END %]

[% IF ( item.withdrawn ) %]
    [% SET itemavailable = 0 %]
    [% withdrawn_lib = AuthorisedValues.GetDescriptionByKohaField( kohafield => 'items.withdrawn', authorised_value => item.withdrawn, opac => 1 ) %]
    [% IF withdrawn_lib %]
        <span class="item-status withdrawn">[% withdrawn_lib | html %]</span>
    [% ELSE %]
        <span class="item-status withdrawn">Item withdrawn</span>
    [% END %]
[% END %]


[% IF item.notforloan %]
    [% SET itemavailable = 0 %]
    <span class="item-status notforloan">Not for loan</span>
[% END %]

[% IF ( item.damaged ) %]
    [% SET itemavailable = 0 %]
    [% av_lib_include = AuthorisedValues.GetDescriptionByKohaField( kohafield => 'items.damaged', authorised_value => item.damaged, opac => 1 ) %]
    [% IF av_lib_include %]
        <span class="item-status damaged">[% av_lib_include | html %]</span>
    [% ELSE %]
        <span class="item-status damaged">Item damaged</span>
    [% END %]
[% END %]

[% IF ( itemavailable ) %]
    <span class="item-status available">Available</span>
[% END %]
