use Modern::Perl;

return {
    bug_number => "15067",
    description => "Add missing languages",
    up => sub {
        my ($args) = @_;
        my $dbh = $args->{dbh};

        if( !unique_key_exists( 'language_subtag_registry', 'uniq_lang' ) ) {

            $dbh->do(q{
                DELETE a
                FROM language_subtag_registry AS a, language_subtag_registry AS b
                WHERE a.id < b.id
                AND a.subtag IS NOT NULL
                AND a.subtag=b.subtag
                AND a.type=b.type
            });
            $dbh->do(q{
                ALTER TABLE language_subtag_registry
                ADD UNIQUE KEY uniq_lang (subtag, type)
            });
        };

        if( !unique_key_exists( 'language_descriptions', 'uniq_desc' ) ) {

            $dbh->do(q{
                DELETE a
                FROM language_descriptions AS a, language_descriptions AS b
                WHERE a.id < b.id
                AND a.subtag IS NOT NULL
                AND a.subtag=b.subtag
                AND a.lang IS NOT NULL
                AND a.lang=b.lang
                AND a.type=b.type
            });
            $dbh->do(q{
                ALTER TABLE language_descriptions
                ADD UNIQUE KEY uniq_desc (subtag, type, lang)
            });
        };

        if( !unique_key_exists( 'language_rfc4646_to_iso639', 'uniq_code' ) ) {

            $dbh->do(q{
                DELETE a
                FROM language_rfc4646_to_iso639 AS a, language_rfc4646_to_iso639 AS b
                WHERE a.id < b.id
                AND a.rfc4646_subtag IS NOT NULL
                AND a.rfc4646_subtag=b.rfc4646_subtag
                AND a.iso639_2_code=b.iso639_2_code
            });
            $dbh->do(q{
                ALTER TABLE language_rfc4646_to_iso639
                ADD UNIQUE KEY uniq_code (rfc4646_subtag, iso639_2_code)
            });
        };

        $dbh->do(q{
            INSERT IGNORE INTO language_subtag_registry (subtag, type, description, added)
            VALUES
            ('et', 'language', 'Estonian', now()),
            ('lv', 'language', 'Latvian', now()),
            ('lt', 'language', 'Lithuanian', now()),
            ('iu', 'language', 'Inuktitut', now()),
            ('ik', 'language', 'Inupiaq', now()),
            ('aa', 'language', 'Afar', now()),
            ('af', 'language', 'Afrikaans', now()),
            ('arc', 'language', 'Aramaic', now()),
            ('ee', 'language', 'Ewe', now()),
            ('ff', 'language', 'Fula/Fulani', now()),
            ('ha', 'language', 'Hausa', now()),
            ('ig', 'language', 'Igbo', now()),
            ('ki', 'language', 'Kikuyu', now()),
            ('kg', 'language', 'Kongo/Kikongo', now()),
            ('lu', 'language', 'Luba-Katanga/Kiluba', now()),
            ('ml', 'language', 'Malayalam', now()),
            ('om', 'language', 'Oromo', now()),
            ('ps', 'language', 'Pashto', now()),
            ('ti', 'language', 'Tigrinya', now()),
            ('so', 'language', 'Somali', now()),
            ('syr', 'language', 'Syriac', now())
        });

        $dbh->do(q{
            INSERT IGNORE INTO language_descriptions (subtag, type, lang, description)
            VALUES
            ('et', 'language', 'en', 'Estonian'),
            ('et', 'language', 'et', 'Eesti'),
            ('et', 'language', 'de', 'Estnisch'),
            ('lv', 'language', 'en', 'Latvian'),
            ('lv', 'language', 'lv', 'Latvija'),
            ('lv', 'language', 'de', 'Lettisch'),
            ('lt', 'language', 'en', 'Lithuanian'),
            ('lt', 'language', 'lt', 'Lietuvių'),
            ('lt', 'language', 'de', 'Litauisch'),
            ('iu', 'language', 'en', 'Inuktitut'),
            ('iu', 'language', 'iu', 'ᐃᓄᒃᑎᑐᑦ'),
            ('iu', 'language', 'de', 'Inuktitut'),
            ('ik', 'language', 'en', 'Inupiaq'),
            ('ik', 'language', 'ik', 'Iñupiaq'),
            ('ik', 'language', 'de', 'Inupiaq'),
            ('aa', 'language', 'en', 'Afar'),
            ('aa', 'language', 'aa', 'Qafaraf'),
            ('aa', 'language', 'de', 'Afar'),
            ('af', 'language', 'en', 'Afrikaans'),
            ('af', 'language', 'af', 'Afrikaans'),
            ('af', 'language', 'de', 'Afrikaans'),
            ('arc', 'language', 'en', 'Aramaic'),
            ('arc', 'language', 'arc', 'ארמית'),
            ('arc', 'language', 'de', 'Aramäisch'),
            ('ee', 'language', 'en', 'Ewe'),
            ('ee', 'language', 'ee', 'Eʋegbe'),
            ('ee', 'language', 'de', 'Ewe'),
            ('ff', 'language', 'en', 'Fula/Fulani'),
            ('ff', 'language', 'ff', '𞤊𞤵𞤤𞤬𞤵𞤤𞤣𞤫'),
            ('ff', 'language', 'de', 'Fulfulde/Ful'),
            ('ha', 'language', 'en', 'Hausa'),
            ('ha', 'language', 'ha', 'هَوُسَا'),
            ('ha', 'language', 'de', 'Hausa'),
            ('ig', 'language', 'en', 'Igbo'),
            ('ig', 'language', 'ig', 'Ásụ̀sụ́ Ìgbò'),
            ('ig', 'language', 'de', 'Igbo'),
            ('ki', 'language', 'en', 'Kikuyu'),
            ('ki', 'language', 'ki', 'Gĩkũyũ'),
            ('ki', 'language', 'de', 'Kikuyu'),
            ('kg', 'language', 'en', 'Kongo/Kikongo'),
            ('kg', 'language', 'kg', 'Kikongo'),
            ('kg', 'language', 'de', 'Kikongo/Kongo'),
            ('lu', 'language', 'en', 'Luba-Katanga/Kiluba'),
            ('lu', 'language', 'lu', 'Kiluba'),
            ('lu', 'language', 'de', 'Kiluba'),
            ('ml', 'language', 'en', 'Malayalam'),
            ('ml', 'language', 'ml', 'മലയാളം'),
            ('ml', 'language', 'de', 'Malayalam'),
            ('om', 'language', 'en', 'Oromo'),
            ('om', 'language', 'om', 'Afaan Oromoo'),
            ('om', 'language', 'de', 'Oromo'),
            ('ps', 'language', 'en', 'Pashto'),
            ('ps', 'language', 'ps', 'پښتو, Pəx̌tó'),
            ('ps', 'language', 'de', 'Paschtu'),
            ('ti', 'language', 'en', 'Tigrinya'),
            ('ti', 'language', 'ti', 'ትግርኛ'),
            ('ti', 'language', 'de', 'Tigrinisch'),
            ('so', 'language', 'en', 'Somali'),
            ('so', 'language', 'so', 'اَف سٝومالِ‎/𐒖𐒍 𐒈𐒝𐒑𐒛𐒐𐒘'),
            ('so', 'language', 'de', 'Somali'),
            ('syr', 'language', 'en', 'Syriac'),
            ('syr', 'language', 'syr', 'ܠܫܢܐ ܣܘܪܝܝܐ'),
            ('syr', 'language', 'de', 'Syrisch')
        });

        $dbh->do(q{
            INSERT IGNORE INTO language_rfc4646_to_iso639 (rfc4646_subtag, iso639_2_code)
            VALUES
            ('et', 'est'),
            ('lv', 'lav'),
            ('lt', 'lit'),
            ('iu', 'iku'),
            ('ik', 'ipk'),
            ('aa', 'aar'),
            ('af', 'afr'),
            ('arc', 'arc'),
            ('ee', 'ewe'),
            ('ff', 'ful'),
            ('ha', 'hau'),
            ('ig', 'ibo'),
            ('ki', 'kik'),
            ('kg','kon'),
            ('lu','lub'),
            ('ml','mal'),
            ('om','orm'),
            ('ps','pus'),
            ('ti','tir'),
            ('so','som'),
            ('syr','syr')
        });
    },
}
