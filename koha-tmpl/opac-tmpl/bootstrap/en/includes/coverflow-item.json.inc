    {
        "biblionumber": [% item.biblionumber %],
        "titleblock": "[% FILTER escape_quotes = replace('"', '\"') ~%][% FILTER remove_special_character = replace('([\t\r\n\f\b]|\s{3,})','') ~%][% item.titleblock %][%~ END %][%~ END %]",
        "title": "[% item.title | escape_quotes | remove_special_character %]",
        "subtitle": "[% item.subtitle | escape_quotes | remove_special_character %]",
        "medium": "[% item.medium | escape_quotes | remove_special_character %]",
        "part_number": "[% item.part_number | escape_quotes | remove_special_character %]",
        "part_name": "[% item.part_name | escape_quotes | remove_special_character %]",
        "year": "[% item.year | escape_quotes | remove_special_character %]",
        "edition": "[% item.edition | escape_quotes | remove_special_character %]",
        "publisher": "[% item.publisher | escape_quotes | remove_special_character %]",
        "place": "[% item.place | escape_quotes | remove_special_character %]",
        "author": "[% item.author | escape_quotes | remove_special_character %]",[% IF item.itemnumber %]
        "itemnumber": [% item.itemnumber %],[% END %][% IF item.cn_sort %]
        "cn_sort": "[% item.cn_sort %]",[% END %][% IF item.itemcallnumber %]
        "itemcallnumber": "[% item.itemcallnumber | escape_quotes | remove_special_character %]",[% END %]
        [%- IF item.coverurl %]
        "coverurl": "[% item.coverurl | escape_quotes | remove_special_character %]",
        [%- ELSIF ( (OPACLocalCoverImages && item.local_immage_count > 0) || OPACAmazonCoverImages || ( SyndeticsEnabled && SyndeticsCoverImages ) || GoogleJackets || BakerTaylorEnabled || ( Koha.Preference('OpacCoce') && Koha.Preference('CoceProviders') ) || ( Koha.Preference('OPACCustomCoverImages') AND Koha.Preference('CustomCoverImagesURL') ) ) %]
        "coverhtml": "[% FILTER remove_special_character %][% FILTER escape_quotes %]
            [%- IF ( item.title ) -%]
                [% img_title = item.title %]
            [%- ELSE -%]
                [% img_title = item.biblionumber %]
            [%- END %]
            [% IF ( OPACLocalCoverImages && item.local_immage_count > 0 ) %]
                <div title="[% img_title | html %]" class="[% item.biblionumber | html %] thumbnail-shelfbrowser" id="local-thumbnail-shelf-[% item.biblionumber | html %]"></div>
            [% END %]
            [% IF ( OPACAmazonCoverImages ) %]
                [% IF ( item.browser_normalized_isbn ) %]
                    <img src="https://images-na.ssl-images-amazon.com/images/P/[% item.browser_normalized_isbn | html %].01._AA75_PU_PU-5_.jpg" alt="" />
                [% ELSE %]
                    <span class="no-image">No cover image available</span>
                [% END %]
            [% END %]
            [% IF ( SyndeticsEnabled ) %]
                [% IF ( SyndeticsCoverImages ) %]
                    [% IF ( content_identifier_exists ) %]
                        <img src="https://secure.syndetics.com/index.aspx?isbn=[% item.browser_normalized_isbn | html %]/SC.GIF&amp;client=[% SyndeticsClientCode | html %][% IF ( item.browser_normalized_upc ) %]&amp;upc=[% item.browser_normalized_upc | html %][% END %][% IF ( item.browser_normalized_oclc ) %]&amp;oclc=[% item.browser_normalized_oclc | html %][% END %]&amp;type=xw10" alt="" />
                    [% ELSE %]
                        <span class="no-image">No cover image available</span>
                    [% END %]
                [% END %]
            [% END %]
            [% IF ( GoogleJackets ) %]
                [% IF ( item.browser_normalized_isbn ) %]
                    <div title="[% img_title | html %]" class="[% item.browser_normalized_isbn | html %]" id="gbs-thumbnail-preview[% loop.count | html %]"></div>
                [% ELSE %]
                    <span class="no-image">No cover image available</span>
                [% END %]
            [% END %]
            [% IF ( Koha.Preference('OpacCoce') && Koha.Preference('CoceProviders') ) %]
                [% coce_id = item.browser_normalized_ean || item.browser_normalized_isbn | html %]
                <div title="[% img_title | html %]" class="[% coce_id | html %]" id="coce-thumbnail-preview-[% coce_id | html %]"></div>
            [% END %]
            [% IF ( BakerTaylorEnabled ) %]
                [% bt_id = ( item.browser_normalized_upc || item.browser_normalized_isbn ) | html %]
                [% IF ( bt_id ) %]
                    <img alt="See Baker &amp; Taylor" src="[% BakerTaylorImageURL | html %][% bt_id | html %]" />
                [% ELSE %]
                    <span class="no-image">No cover image available</span>
                [% END %]
            [% END %]
            [% IF Koha.Preference('OPACCustomCoverImages') AND Koha.Preference('CustomCoverImagesURL') %]
                [% SET custom_cover_image_url = item.biblio_object.custom_cover_image_url %]
                [% IF custom_cover_image_url %]
                    <span class="custom_cover_image">
                        <img alt="Cover image" src="[% custom_cover_image_url | url %]" />
                    </span>
                [% END %]
            [% END %][% END %][% END %]",
        [%- ELSE -%]
            "coverurl": "[% item.gencover| escape_quotes | remove_special_character %]",
        [% END %]
        "normalized_upc": "[% item.browser_normalized_upc | escape_quotes | remove_special_character %]",
        "normalized_oclc_number": "[% item.browser_normalized_oclc | escape_quotes | remove_special_character %]",
        "normalized_isbn": "[% item.browser_normalized_isbn | escape_quotes | remove_special_character %]",
        "normalized_ean": "[% item.browser_normalized_ean | escape_quotes | remove_special_character %]"
    }