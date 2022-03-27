[% IF ( Koha.Preference( 'MunzingerEncyclopediaSearchEnabled' ) || Koha.Preference( 'BrockhausSearchActive' ) || Koha.Preference( 'FilmFriendSearchActive' ) ) %]
<div id="encyclopedia-facets">
    <h2><a href="#abc" class="further-offerings-menu-collapse-toggle">Further offerings</a></h2>
    <ul class="further-offerings-menu-collapse">
        [% IF ( Koha.Preference( 'FilmfriendSearchActive' ) ) %]
        <li id="filmfriend-facet" style="display: none;">
           <h3 id="facet-brockhaus">filmfriend film portal (<span id="filmfriend-count"></span>&nbsp;hits)</h3>
           <ul>
             <li>
                <span class="facet-label"></span> <span class="facet-count"></span>
             </li>
           </ul>
        </li>
       [% END %]
       [% IF ( Koha.Preference( 'MunzingerEncyclopediaSearchEnabled' ) ) %]
        <li id="munzinger-facet" style="display: none;">
           <h3 id="facet-munzinger">Munzinger encyclopedia (<span id="munzinger-count"></span>&nbsp;hits)</h3>
           <ul>
             <li>
                <span class="facet-label"></span> <span class="facet-count"></span>
             </li>
           </ul>
        </li>
        [% END %]
        [% IF ( Koha.Preference( 'BrockhausSearchActive' ) ) %]
        <li id="brockhaus-facet" style="display: none;">
           <h3 id="facet-brockhaus">Brockhaus encyclopedia (<span id="brockhaus-count"></span>&nbsp;hits)</h3>
           <ul>
             <li>
                <span class="facet-label"></span> <span class="facet-count"></span>
             </li>
           </ul>
        </li>
        [% END %]
    </ul>
</div>
[% END %] <!-- / #encyclopedia search if MunzingerEncyclopediaSearchEnabled or BrockhausSearchEnabled or FilmFriendSearchActive -->
