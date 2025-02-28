[% IF patron.borrowernumber %]
<table id="ill-requests-patron-[% patron.borrowernumber | html %]">
[% ELSE %]
<table id="ill-requests"[% IF prefilters.length > 0 %] data-prefilters="[% prefilters | html %]"[% END %][% IF infilter.length > 0 %] data-infilter="[% infilter | html %]"[% END %]>
[% END %]
    <thead>
        <tr id="ill_requests_header">
            <th scope="col">Request ID</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="author,Verfasser" data-related-search-on="value">Author</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="title,Titel" data-related-search-on="value">Title</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="article_title" data-related-search-on="value">Article title</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="issue" data-related-search-on="value">Issue</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="volume" data-related-search-on="value">Volume</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="year,publyear,VerlagJahrSonst" data-related-search-on="value">Year</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="pages" data-related-search-on="value">Pages</th>
            <th scope="col">Request type</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="illPartnerLibraryIsil,sendingIllLibraryIsil,BestelltVonSigel,BestelltBeiSigel" data-related-search-on="value">Sigel</th>
            <th scope="col">Order ID</th>
            <th scope="col">Patron</th>
            <th scope="col">Bibliographic record ID</th>
            <th scope="col">Library</th>
            <th scope="col">Status</th>
            <th scope="col" class="placed_formatted">Placed on</th>
            <th scope="col" class="updated_formatted">Updated on</th>
            <th scope="col">Replied</th>
            <th scope="col" class="completed_formatted">Completed on</th>
            <th scope="col">Access URL</th>
            <th scope="col">Cost</th>
            <th scope="col">Price paid</th>
            <th scope="col">Comments</th>
            <th scope="col">OPAC notes</th>
            <th scope="col">Staff notes</th>
            <th scope="col">Backend</th>
            <th scope="col" data-datatype="related-object" data-related="extended_attributes" data-related-key="type" data-related-value="ochk_Bearbeiter" data-related-search-on="value">ILL order last checked by</th>
            <th scope="col" class="actions"></th>
        </tr>
    </thead>
    <tbody id="illview-body">
    </tbody>
</table>
