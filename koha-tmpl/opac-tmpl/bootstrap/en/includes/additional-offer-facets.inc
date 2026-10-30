[% IF ( Koha.Preference( 'MunzingerEncyclopediaSearchEnabled' ) || Koha.Preference( 'BrockhausSearchActive' ) || Koha.Preference( 'FilmfriendSearchActive' ) || Koha.Preference( 'HelimaSearchActive' ) ) %]
    <div id="encyclopedia-facets">
        <h2><a href="#abc" class="further-offerings-menu-collapse-toggle">Further offerings</a></h2>
        <ul class="further-offerings-menu-collapse">
            [% IF ( Koha.Preference( 'FilmfriendSearchActive' ) ) %]
                <li id="filmfriend-facet" style="display: none;">
                    <a class="facet-toggle" aria-expanded="true" data-bs-toggle="collapse" data-bs-target="#filmfriend_collapse" id="facet-filmfriend">filmfriend film portal (<span id="filmfriend-count"></span>&nbsp;hits)</a>
                    <div class="facet-collapse collapse show" id="filmfriend_collapse">
                        <ul>
                            <li> <span class="facet-label"></span> <span class="facet-count"></span> </li>
                        </ul>
                    </div>
                </li>
            [% END %]
            [% IF ( Koha.Preference( 'MunzingerEncyclopediaSearchEnabled' ) ) %]
                <li id="munzinger-facet" style="display: none;">
                    <a class="facet-toggle" aria-expanded="true" data-bs-toggle="collapse" data-bs-target="#munzinger_collapse" id="facet-munzinger">Munzinger encyclopedia (<span id="munzinger-count"></span>&nbsp;hits)</a>
                    <div class="facet-collapse collapse show" id="munzinger_collapse">
                        <ul>
                            <li> <span class="facet-label"></span> <span class="facet-count"></span> </li>
                        </ul>
                    </div>
                </li>
            [% END %]
            [% IF ( Koha.Preference( 'BrockhausSearchActive' ) ) %]
                <li id="brockhaus-facet" style="display: none;">
                    <a class="facet-toggle" aria-expanded="true" data-bs-toggle="collapse" data-bs-target="#brockhaus_collapse" id="facet-brockhaus">Brockhaus encyclopedia (<span id="brockhaus-count"></span>&nbsp;hits)</a>
                    <div class="facet-collapse collapse show" id="brockhaus_collapse">
                        <ul>
                            <li> <span class="facet-label"></span> <span class="facet-count"></span> </li>
                        </ul>
                    </div>
                </li>
            [% END %]
            [% IF ( Koha.Preference( 'HelimaSearchActive' ) ) %]
                <li id="helima-facet" style="display: none;">
                    <a class="facet-toggle" aria-expanded="true" data-bs-toggle="collapse" data-bs-target="#helima_collapse" id="facet-helima">[% Koha.Preference( 'HelimaAdditionalOfferName' ) || 'Hessen-Angebote' %] (<span id="helima-count"></span>&nbsp;hits)</a>
                    <div class="facet-collapse collapse show" id="helima_collapse">
                        <ul>
                            <li> <span class="facet-label"></span> <span class="facet-count"></span> </li>
                        </ul>
                    </div>
                </li>
            [% END %]
        </ul>
    </div>
[% END %]
<!-- / #encyclopedia search if MunzingerEncyclopediaSearchEnabled or BrockhausSearchEnabled or FilmfriendSearchActive or HelimaSearchActive -->
