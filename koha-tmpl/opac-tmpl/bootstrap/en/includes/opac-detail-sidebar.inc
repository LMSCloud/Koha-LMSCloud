[% USE raw %]
[% USE Biblio %]
<ul id="action">
    [% UNLESS ( norequests ) %]
        [% IF Koha.Preference( 'opacuserlogin' ) == 1 %]
            [% IF Koha.Preference( 'OPACHoldRequests' ) == 1 %]
                [% IF ( ReservableItems ) %]
                    <li><a class="reserve btn btn-link btn-lg" href="/cgi-bin/koha/opac-reserve.pl?biblionumber=[% biblio.biblionumber | html %]"><i class="fa fa-fw fa-bookmark" aria-hidden="true"></i> Place hold</a></li>
                [% END %]
            [% END %]
        [% END %]

        [% IF Koha.Preference('OPACBookings') && BookableItems %]
            <li>
                [% INCLUDE 'modals/booking/button-place.inc' link => 1 %]
                [% INCLUDE 'modals/booking/island.inc' %]
            </li>
        [% END %]
    [% END %]

    [% IF Koha.Preference('UseRecalls') %]
        <li><a class="recall btn btn-link btn-lg" href="/cgi-bin/koha/opac-recall.pl?biblionumber=[% biblio.biblionumber | html %]"><i class="fa fa-fw fa-bookmark-o" aria-hidden="true"></i>
        Place recall</a></li>
    [% END %]

    <li><a class="print-large btn btn-link btn-lg" href="#"><i class="fa fa-fw fa-print" aria-hidden="true"></i> Print</a></li>

    [% IF Koha.Preference( 'opacuserlogin' ) == 1 %]
        [% IF artreqpossible %]
            <li><a class="article_request btn btn-link btn-lg" href="/cgi-bin/koha/opac-request-article.pl?biblionumber=[% biblio.biblionumber | html %]"><i class="fa fa-fw fa-file-text" aria-hidden="true"></i> Request article</a></li>
        [% END %]
    [% END %]

    [% IF Koha.Preference( 'virtualshelves' ) == 1 %]
        [% IF ( ( Koha.Preference( 'opacuserlogin' ) == 1 ) && loggedinusername ) %]
            <li><a class="addtoshelf btn btn-link btn-lg" href="/cgi-bin/koha/opac-addbybiblionumber.pl?biblionumber=[% biblio.biblionumber | html %]"><i class="fa fa-fw fa-list" aria-hidden="true"></i> Save to your lists</a></li>
        [% END %]
    [% END %]

    [% IF Koha.Preference( 'opacbookbag' ) == 1 %]
        [% IF ( incart ) %]
            <li><a data-biblionumber="[% biblio.biblionumber | html %]" class="addtocart incart cart[% biblio.biblionumber | html %] addrecord btn btn-link btn-lg" href="#"><i class="fa fa-fw fa-shopping-cart" aria-hidden="true"></i> In your cart</a> <a data-biblionumber="[% biblio.biblionumber | html %]" class="cartRemove cartR[% biblio.biblionumber | html %]" href="#">(remove)</a></li>
        [% ELSE %]
            <li><a data-biblionumber="[% biblio.biblionumber | html %]" class="addtocart cart[% biblio.biblionumber | html %] addrecord btn btn-link btn-lg" href="#"><i class="fa fa-fw fa-shopping-cart" aria-hidden="true"></i> Add to your cart</a>  <a style="display:none;" data-biblionumber="[% biblio.biblionumber | html %]" class="cartRemove cartR[% biblio.biblionumber | html %]" href="#">(remove)</a></li>
        [% END %]
    [% END %]

    [% IF ( suggestion ) %]
        <li><a class="suggest_for_purchase btn btn-link btn-lg" href="/cgi-bin/koha/opac-suggestions.pl?op=add&biblionumber=[% biblio.biblionumber | url %]"><i class="fa fa-fw fa-gift" aria-hidden="true"></i> Suggest for purchase</a></li>
    [% END %]

    [% IF ( OpacHighlightedWords && query_desc ) %]
    <li>
        <a href="#" class="highlight_toggle btn btn-link btn-lg" id="highlight_toggle_off"><i class="fa fa-fw fa-pencil" aria-hidden="true"></i> Unhighlight</a>
        <a href="#" class="highlight_toggle btn btn-link btn-lg" id="highlight_toggle_on"><i class="fa fa-fw fa-pencil" aria-hidden="true"></i> Highlight</a>
    </li>
    [% END %]


    [% IF ( Koha.Preference('OPACDetailQRCode' ) ) %]
        <li>
            <a class="show_qrcode btn btn-link btn-lg" href="#"><i class="fa fa-fw fa-qrcode" aria-hidden="true"></i> Send to device</a>
            <div id="qrcode" class="d-none"></div>
        </li>
    [% END %]

    [% IF ( ( MARCURLS ) && ( Koha.Preference('OpacDetailAntolinLinks') ) ) %]
        [% AntolinLinks = 0 %]
        [% FOREACH MARCurl IN MARCURLS %]
            [% IF MARCurl.linktext.match('^Antolin') %]
                [% AntolinLinks = AntolinLinks + 1 %]
                [% IF AntolinLinks == 1 %]
                    <li>
                        <div id="antolinquiz_menu">
                            <div class="dropdown">
                                <a id="open_antolinquiz_menu" class="btn btn-link btn-lg dropdown-toggle" data-toggle="dropdown" href="#"><img src="/webcustom/images/Antolin16.png" alt="Antolin book" title="Antolin book" class="antolin_menu_icon" aria-hidden="true" /> Antolin Quiz <b class="caret"></b></a>
                                <div class="dropdown-menu dropdown-menu-right" aria-labelledby="format">
                [% END # / AntolinLinks == 1 %]
                    [% IF ( OPACURLOpenInNewWindow ) %]
                        <a class="dropdown-item" href="[% MARCurl.MARCURL %]" title="[% MARCurl.MARCURL %]" target="_blank">
                    [% ELSE %]
                        <a class="dropdown-item" href="[% MARCurl.MARCURL %]" title="[% MARCurl.MARCURL %]">
                    [% END %]
                    [% MARCurl.linktext %]</a>
            [% END # / IF MARCurl.linktext.match('^Antolin') %]
        [% END # / FOREACH MARCURLS %]
        [% IF AntolinLinks >= 1 %]
                        </div>
                    </div>
                </div>
            </li>
        [% END # / AntolinLinks >= 1 %]
    [% END # / IF MARCURL &&Koha.Preference('OpacDetailAntolinLinks') %]


    [% IF ( ( MARCURLS ) && ( Koha.Preference('OpacDetailWikipediaLinks') ) ) %]
        [% WikipediaLinks = 0 %]
        [% FOREACH MARCurl IN MARCURLS %]
            [% IF MARCurl.MARCURL.match('wikipedia') %]
                [% WikipediaLinks = WikipediaLinks + 1 %]
                [% IF WikipediaLinks == 1 %]
                    <li>
                        <div id="wikipedia_menu">
                            <div class="dropdown">
                                <a id="format" class="btn btn-link btn-lg dropdown-toggle" data-toggle="dropdown" href="#"><i class="fa fa-fw fa-wikipedia-w" aria-hidden="true"></i> Wikipedia-Article <b class="caret"></b></a>
                                <div class="dropdown-menu dropdown-menu-right" aria-labelledby="format">
                [% END # / WikipediaLinks == 1 %]
                [% IF ( OPACURLOpenInNewWindow ) %]
                    <a class="dropdown-item" href="[% MARCurl.MARCURL | replace('Ä', '%C3%84') | replace('Ö', '%C3%96') | replace('Ü', '%C3%9C') | replace('ä', '%C3%A4') | replace('ö', '%C3%B6') | replace('ü', '%C3%BC') | replace('ß', '%C3%9F') | replace('ẞ', '%E1%BA%9E') %]" title="[% MARCurl.MARCURL %]" target="_blank">
                [% ELSE %]
                    <a class="dropdown-item" href="[% MARCurl.MARCURL | replace('Ä', '%C3%84') | replace('Ö', '%C3%96') | replace('Ü', '%C3%9C') | replace('ä', '%C3%A4') | replace('ö', '%C3%B6') | replace('ü', '%C3%BC') | replace('ß', '%C3%9F') | replace('ẞ', '%E1%BA%9E') %]" title="[% MARCurl.MARCURL %]">
                [% END %]
                [% MARCurl.linktext %]</a>
                
            [% END # / IF MARCurl.MARCURL.match('wikipedia') %]
        [% END # / FOREACH MARCURLS %]
        [% IF WikipediaLinks >= 1 %]
                        </div>
                    </div>
                </div>
            </li>
        [% END # / WikipediaLinks >= 1 %]
    [% END # / IF MARCURL && Koha.Preference('OpacDetailWikipediaLinks') %]
    
    [% IF ( Koha.Preference('OpacDetailBookShopLinks') ) %]
        <li>
            <div id="bookshop_menu">
                <div class="dropdown"> 
                   <a id="open_bookshop_menu" class="btn btn-link btn-lg dropdown-toggle" class="dropdown-toggle" data-toggle="dropdown" href="#"><i class="fa fa-fw fa-eur" aria-hidden="true"></i> Buy here<b class="caret"></b></a>
                    <div class="dropdown-menu dropdown-menu-right" aria-labelledby="format">
                        [% OpacDetailBookShopLinkContent %]
                    </div>
                </div>
            </div>
        </li>
    [% END # IF ( Koha.Preference('OpacDetailBookShopLinks') %]

    [% SET export_options = Koha.Preference('OpacExportOptions').split(',') %]
    [% IF export_options.size %]
        <li>
            <div id="export">
                <div class="dropdown">
                    <a id="format" class="btn btn-link btn-lg dropdown-toggle" data-toggle="dropdown" href="#"><i class="fa fa-fw fa-download" aria-hidden="true"></i> Save record <b class="caret"></b></a>
                    <div class="dropdown-menu dropdown-menu-right" aria-labelledby="format">
                        [% FOREACH option IN export_options %]
                            [% IF option == 'dc' %]
                                <a class="dropdown-item" href="#" data-toggle="modal" data-target="#exportModal_">Dublin Core</a>
                            [% ELSE %]
                                <a class="dropdown-item" href="/cgi-bin/koha/opac-export.pl?op=export&amp;bib=[% biblio.biblionumber | html %]&amp;format=[% option | html %]">
                                    [% SWITCH option %]
                                        [% CASE 'bibtex' %]<span>BIBTEX</span>
                                        [% CASE 'endnote' %]<span>EndNote</span>
                                        [% CASE 'marcxml' %]<span>MARCXML</span>
                                        [% CASE 'marc8' %]<span>MARC (non-Unicode/MARC-8)</span>
                                        [% CASE 'utf8' %]<span>MARC (Unicode/UTF-8)</span>
                                        [% CASE 'marcstd' %]<span>MARC (Unicode/UTF-8, Standard)</span>
                                        [% CASE 'mods' %]<span>MODS (XML)</span>
                                        [% CASE 'ris' %]<span>RIS</span>
                                        [% CASE 'isbd' %]<span>ISBD</span>
                                    [% END %]
                                </a>
                            [% END %]
                        [% END %]
                    </div> <!-- /.dropdown-menu -->
                </div> <!-- /.dropdown -->
            </div> <!-- /#export -->
        </li>
    [% END %]

    [% IF ( OPACSearchForTitleIn ) %]
        <li>
            <div id="moresearches_menu">
                <div class="dropdown">
                    <a id="furthersearches" class="btn btn-link btn-lg dropdown-toggle" data-toggle="dropdown" href="#" role="button" aria-haspopup="true" aria-expanded="false">
                        <i class="fa fa-fw fa-search" aria-hidden="true"></i> More searches
                    </a>
                    <div class="dropdown-menu dropdown-menu-right" aria-labelledby="furthersearches">
                        <div class="dropdown-header">Search for this title in:</div>
                        [% OPACSearchForTitleIn | $raw %]
                    </div>
                </div>
            </div>
        </li>
    [% END %]
</ul>

<!-- Dublin Core Modal Form -->
<div class="modal" id="exportModal_" tabindex="-1" role="dialog" aria-labelledby="exportModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h3 class="modal-title" id="exportModalLabel">Exporting to Dublin Core...</h3>
                <button type="button" class="closebtn" data-dismiss="modal" aria-hidden="true">&times;</button>
            </div>
            <form method="get" action="/cgi-bin/koha/opac-export.pl">
                <div class="modal-body">
                    <fieldset id="dc_fieldset">
                        <input id="input-simple" type="radio" name="format" value="rdfdc">
                        <label class="label_dc" for="input-simple">Simple DC-RDF</label>
                        <br>
                        <input id="input-oai" type="radio" name="format" value="oaidc" checked>
                        <label class="label_dc" for="input-oai">OAI-DC</label>
                        <br>
                        <input id="input-srw" type="radio" name="format" value="srwdc">
                        <label class="label_dc" for="input-srw">SRW-DC</label>
                        <br>
                        <input type="hidden" name="op" value="export">
                        <input type="hidden" name="bib" value="[% biblio.biblionumber | html %]">
                    </fieldset>
                </div>
                <div class="modal-footer">
                    <button type="submit" class="btn btn-primary">Export</button>
                    <button class="btn btn-link btn-lg" data-dismiss="modal" aria-hidden="true">Cancel</button>
                </div>
            </form>
        </div> <!-- /.modal-content -->
    </div> <!-- /.modal-dialog -->
</div> <!-- /.modal -->
