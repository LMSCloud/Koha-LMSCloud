[%# Common filters form for booking templates %]

[%# Parameters:
    - form_id: Form ID (default: bookingsf)
    - show_holding_library: Whether to show holding library filter
    - show_pickup_library: Whether to show pickup library filter
    - show_date_filters: Whether to show date filters
    - from_date: Default from date
    - to_date: Default to date
    - branchcode: Selected branch code
%]

<form id="[% form_id || 'bookingsf' %]">
    <fieldset class="brief">
        <h4>Refine results</h4>
        <ol>
            [% IF show_holding_library %]
            <li>
                <label for="holding_library">Holding library:</label>
                <select name="holding_library" id="holding_library">
                    [% SET libraries = Branches.all( only_from_group => 1 ) %]
                    [% IF libraries.size != 1 %]
                        <option value="">Any</option>
                    [% END %]
                    [% FOREACH l IN libraries %]
                        [% IF (l.branchcode == branchcode) %]
                            <option value="[% l.branchcode | html %]" selected="selected">[% l.branchname | html %]</option>
                        [% ELSE %]
                            <option value="[% l.branchcode | html %]">[% l.branchname | html %]</option>
                        [% END %]
                    [% END %]
                </select>
            </li>
            [% END %]
            
            [% IF show_pickup_library %]
            <li>
                <label for="pickup_library">Pickup library:</label>
                <select name="pickup_library" id="pickup_library">
                    [% SET libraries = Branches.all( only_from_group => 1 ) %]
                    [% IF libraries.size != 1 %]
                        <option value="">Any</option>
                    [% END %]
                    [% FOREACH l IN libraries %]
                        [% IF (l.branchcode == branchcode) %]
                            <option value="[% l.branchcode | html %]" selected="selected">[% l.branchname | html %]</option>
                        [% ELSE %]
                            <option value="[% l.branchcode | html %]">[% l.branchname | html %]</option>
                        [% END %]
                    [% END %]
                </select>
            </li>
            [% END %]
            
            [% IF show_date_filters %]
            <li>
                <label for="from">Starts after: </label>
                <input type="text" size="10" id="from" name="from" value="[% from_date | html %]" class="flatpickr" data-date_to="to" />
            </li>
            <li>
                <label for="to">Starts before: </label>
                <input type="text" size="10" id="to" name="to" value="[% to_date | html %]" class="flatpickr" />
            </li>
            [% END %]
        </ol>
    </fieldset>
    <fieldset class="action">
        <input type="submit" name="run_report" value="Submit" class="btn btn-primary" />
    </fieldset>
</form> 