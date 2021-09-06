[% USE raw %]
[% IF ( PAGE_NUMBERS ) %]
    <nav class="pagination pagination-sm noprint" aria-label="Search results pagination">
        <ul class="pagination">
            [% current_page = offset / results_per_page + 1 %][% last_page = total div results_per_page%]
            [% IF ( total mod results_per_page ) > 0 %][% last_page = last_page + 1 %][% END %]
            [% last_page_offset = (last_page - 1) * results_per_page %]
            [% IF ( previous_page_offset.defined && last_page > 2 ) %]<li class="page-item"><a class="page-link" href="/cgi-bin/koha/opac-search.pl?[% query_cgi |html %][% limit_cgi |html %]&amp;offset=[% previous_page_offset %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |html %][% END %]">Prev &laquo;</a></li>
            [% END %]
            [% IF current_page > 1 %]
                <li class="page-item"><a class="page-link" href="/cgi-bin/koha/opac-search.pl?[% query_cgi |html %][% limit_cgi |html %]&amp;[% IF ( sort_by ) %]&amp;sort_by=[% sort_by |html %][% END %]">1</a></li>
                [% IF current_page > 2 %]
                    <li class="page-item"><a class="page-link" href="#" style="pointer-events: none;cursor: default;">...</a></li>
                [% END %]
                [% IF current_page > 2 && current_page == last_page %]
                    <li class="page-item"><a class="page-link" href="/cgi-bin/koha/opac-search.pl?[% query_cgi |html %][% limit_cgi |html %]&amp;offset=[% previous_page_offset %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |html %][% END %]">[% last_page - 1 %]</a></li>
                [% END %]
                <li class="page-item active"><a class="page-link" href="#">[% current_page %]</a></li>
            [% ELSE %]
                <li class="page-item active"><a class="page-link" href="#">[% current_page %]</a></li>
                [% IF last_page >= 2 %]
                    <li class="page-item"><a class="page-link" href="/cgi-bin/koha/opac-search.pl?[% query_cgi |html %][% limit_cgi |html %]&amp;offset=[% results_per_page %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |html %][% END %]">2</a></li>
                [% END %]
            [% END %]
            [% IF ( ( ( current_page + 1 ) < last_page && current_page > 2 ) || ( last_page > 2 && current_page < 3 ) )  %]
                <li class="page-item"><a class="page-link" href="#" style="pointer-events: none;cursor: default;">...</a></li>
            [% END %]
            [% IF last_page > 2 && current_page < last_page %]
                <li class="page-item"><a class="page-link" href="/cgi-bin/koha/opac-search.pl?[% query_cgi |html %][% limit_cgi |html %]&amp;offset=[% last_page_offset %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |html %][% END %]">[% last_page %]</a></li>
                <li class="page-item"><a class="page-link" href="/cgi-bin/koha/opac-search.pl?[% query_cgi |html %][% limit_cgi |html %]&amp;offset=[% next_page_offset %][% IF ( sort_by ) %]&amp;sort_by=[% sort_by |html %][% END %]">&raquo; Next</a></li>
            [% END %]
        </ul>
    </nav>
[% END %]
