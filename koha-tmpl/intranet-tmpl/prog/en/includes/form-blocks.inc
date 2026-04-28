[% BLOCK selectoptionopen %]
    [% IF value == selected %]
        <option value="[% value | html %]" selected="selected"> </option>
    [% ELSE %]
        <option value="[% value | html %]"> </option>
    [% END %]
[% END %]
