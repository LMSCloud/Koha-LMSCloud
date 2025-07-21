UPDATE itemtypes
SET bookable = 1
WHERE itemtype = 'BK';
INSERT INTO authorised_value_categories (category_name)
VALUES ('BOOKINGS_URGENCY');
INSERT INTO authorised_values (category, authorised_value, lib)
VALUES ('BOOKINGS_URGENCY', 'LOW', 'Low');
INSERT INTO authorised_values (category, authorised_value, lib)
VALUES (
        'BOOKINGS_URGENCY',
        'MEDIUM',
        'Medium'
    );
INSERT INTO authorised_values (category, authorised_value, lib)
VALUES ('BOOKINGS_URGENCY', 'HIGH', 'High');
INSERT INTO additional_fields (
        tablename,
        name,
        authorised_value_category
    )
VALUES ('bookings', 'Urgency', 'BOOKINGS_URGENCY');
INSERT INTO additional_fields (
        tablename,
        name,
        repeatable
    )
VALUES ('bookings', 'Note', 1);
INSERT INTO additional_fields (tablename, name)
VALUES ('bookings', 'Contact');