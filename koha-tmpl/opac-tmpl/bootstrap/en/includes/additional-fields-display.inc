[% USE AuthorisedValues %]
[%# Filter to only show fields with actual values %]
[% fields_with_values = [] %]
[% IF additional_field_values && additional_field_values.count > 0 %]
    [% FOREACH additional_field_value IN additional_field_values %]
        [% IF additional_field_value.value && additional_field_value.value != "" %]
            [% fields_with_values.push(additional_field_value) %]
        [% END %]
    [% END %]
[% END %]

[% IF fields_with_values.size > 0 %]
    [% FOREACH additional_field_value IN fields_with_values %]
        [% additional_field_value.field.name | html %]:&nbsp;
        [% IF additional_field_value.field.authorised_value_category %]
            [% AuthorisedValues.GetByCode( additional_field_value.field.authorised_value_category, additional_field_value.value ) | html %]
        [% ELSE %]
            [% additional_field_value.value | html %]
        [% END %]<br />
    [% END %]
[% ELSE %]
    &mdash;
[% END %]
