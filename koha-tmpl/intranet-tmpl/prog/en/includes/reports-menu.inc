[% USE Koha %]

<div id="navmenu">
    <div id="navmenulist">

        <h5>Guided reports</h5>
            <ul>
                <li><a href="/cgi-bin/koha/reports/guided_reports.pl">Guided reports</a></li>
                [% IF ( CAN_user_reports_create_reports ) %]
                    <li><a href="/cgi-bin/koha/reports/guided_reports.pl?phase=Build%20new">Build new</a></li>
                [% END %]
                [% IF ( CAN_user_reports_execute_reports ) %]
                    <li><a href="/cgi-bin/koha/reports/guided_reports.pl?phase=Use%20saved">Use saved</a></li>
                [% END %]
                [% IF ( CAN_user_reports_create_reports ) %]
                    <li><a href="/cgi-bin/koha/reports/guided_reports.pl?phase=Create%20report%20from%20SQL">Create from SQL</a></li>
                [% END %]
            </ul>

        <h5>Aggregated statistics</h5>
            <ul>
                <li><a href="/cgi-bin/koha/reports/aggregated_statistics.pl?statisticstype=DBS">DBS</a></li>
                <li><a href="/cgi-bin/koha/reports/aggregated_statistics.pl?statisticstype=VGWort">VG WORT Export</a></li>
            </ul>
        <h5>Statistics wizards</h5>
            <ul>
                <li><a href="/cgi-bin/koha/reports/acquisitions_stats.pl">Acquisitions</a></li>
                <li><a href="/cgi-bin/koha/reports/borrowers_stats.pl">Patrons</a></li>
                <li><a href="/cgi-bin/koha/reports/catalogue_stats.pl">Catalog</a></li>
                <li><a href="/cgi-bin/koha/reports/issues_stats.pl">Circulation</a></li>
                <li><a href="/cgi-bin/koha/reports/serials_stats.pl">Serials</a></li>
                <li><a href="/cgi-bin/koha/reports/cash_register_stats.pl">Cash register</a></li>
                <li><a href="/cgi-bin/koha/reports/reserves_stats.pl">Holds</a></li>
            </ul>

        [% IF plugins_enabled %]
            <h5>Report plugins</h5>
            <ul>
                <li><a href="/cgi-bin/koha/plugins/plugins-home.pl?method=report">Report plugins</a></li>
            </ul>
        [% END %]

        <h5>Top lists</h5>
        <ul>
            <li><a href="/cgi-bin/koha/reports/bor_issues_top.pl">Patrons with the most checkouts</a></li>
            <li><a href="/cgi-bin/koha/reports/cat_issues_top.pl">Most-circulated items</a></li>
            <li><a href="/cgi-bin/koha/reports/fines_overviews.pl">Fines overview</a></li>
        </ul>

        <h5>Inactive</h5>
        <ul>
            <li><a href="/cgi-bin/koha/reports/borrowers_out.pl">Patrons who haven't checked out</a></li>
            <li><a href="/cgi-bin/koha/reports/catalogue_out.pl">Items with no checkouts</a></li>
        </ul>


        <h5>Other</h5>
        <ul>
            <li><a href="/cgi-bin/koha/reports/itemslost.pl">Lost items</a></li>
            <li><a href="/cgi-bin/koha/reports/orders_by_fund.pl">Orders by fund</a></li>
            <li><a href="/cgi-bin/koha/reports/catalog_by_itemtype.pl">Catalog by item type</a></li>
            <li><a href="/cgi-bin/koha/reports/issues_avg_stats.pl">Average loan time</a></li>
        </ul>
    </div>
</div>
