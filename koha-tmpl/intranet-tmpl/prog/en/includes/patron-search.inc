[% USE Koha %]
[% USE Branches %]
[% USE Categories %]
[% USE Letters %]
[% USE raw %]
[% PROCESS 'html_helpers.inc' %]
[% PROCESS 'patronfields.inc' %]
<div class="gradient">
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl">[% LibraryName | html %]</a></h1><!-- Begin Patrons Resident Search Box -->
<div id="header_search">
    <div id="patron_search" class="residentsearch">
    <form action="/cgi-bin/koha/members/member.pl" method="post">
        <label class="tip" for="searchmember">Enter patron card number or partial name:</label>
    <div class="autocomplete">
        <input id="searchmember" data-toggle="tooltip" size="25" class="head-searchbox focus" name="searchmember" type="text" value="[% searchmember | html %]" autocomplete="off" />
        <input type="hidden" name="quicksearch" value="1" />
        <span class="filteraction" id="filteraction_off"> <a href="#">[-]</a></span>
        <span class="filteraction" id="filteraction_on"> <a href="#">[+]</a></span>
        <input value="Search" class="submit" type="submit" />
    </div>


    <div id="filters">
        <p><label for="searchfieldstype">Search fields:</label>
            <select name="searchfieldstype" id="searchfieldstype">
              [% pref_fields = Koha.Preference('DefaultPatronSearchFields').split(',') %]
              [% default_fields = [ 'standard', 'surname', 'cardnumber', 'email', 'borrowernumber', 'userid', 'phone', 'address', 'city', 'dateofbirth', 'sort1', 'sort2' ] %]
              [% search_options = default_fields.merge(pref_fields).unique %]
              [% FOREACH s_o IN search_options %]
                  [% display_name = PROCESS patron_fields name=s_o %]
                  [% NEXT IF !display_name.length %]
                  [% IF searchfieldstype == s_o %]
                      <option selected="selected" value="[% s_o | html %]">[% display_name | $raw %]</option>
                  [% ELSE %]
                      <option value="[% s_o | html %]">[% display_name | $raw %]</option>
                  [% END %]
              [% END %]
            </select>
        </p>
        <p>
            <label for="searchtype">Search type:</label>
            <select name="searchtype" id="searchtype">
              [% IF searchtype == 'start_with' %]
                  <option selected="selected" value='start_with'>Starts with</option>
                  <option value='contain'>Contains</option>
              [% ELSE %]
                  <option value='start_with'>Starts with</option>
                  <option selected="selected" value='contain'>Contains</option>
              [% END %]
            </select>
        </p>

        <p>
            <label for="branchcode">Library: </label>
            [% SET branches = Branches.all( selected => branchcode_filter, only_from_group => 1 ) %]
            <select name="branchcode_filter" id="branchcode">
                [% IF branches.size != 1 %]
                  <option value="">Any</option>
                [% END %]
                [% PROCESS options_for_libraries libraries => branches %]
            </select>
        </p>
        
        <p>
            <label for="categorycode">Category: </label>
            [% SET categories = Categories.all() %]
            <select name="categorycode_filter" id="categorycode">
                <option value="">Any</option>
                [% FOREACH category IN categories %]
                    [% IF category.categorycode == categorycode_filter %]
                        <option value="[% category.categorycode | html %]" selected="selected">[% category.description | html %]</option>
                    [% ELSE %]
                        <option value="[% category.categorycode | html %]">[% category.description | html %]</option>
                    [% END %]
                [% END %]
            </select>
        </p>
        
        <p>
            <label for="chargesfrom">Patron age: </label>
            from&#160;
            <input type="number" name="agerangestart" id="agerangestart" value="" step="1" min="0" class="ageinput" />
            to&#160;
            <input type="number" name="agerangeend" id="agerangeend" value="" step="1" min="0" class="ageinput" />
        </p>
        
        <p>
            <label for="chargesfrom">Number of loans: </label>
            from&#160;
            <input type="number" name="issuecountstart" id="issuecountstart" value="" step="1" min="0" class="issuecountinput" />
            to&#160;
            <input type="number" name="issuecountend" id="issuecountend" value="" step="1" min="0" class="issuecountinput" />
        </p>
        
        <p>
            <label for="chargesfrom">Open charges amount: </label>
            from&#160;
            <input type="number" name="chargesfrom" id="chargesfrom" value="" step="any" min="0" class="priceinput" />
            to&#160;
            <input type="number" name="chargesto" id="chargesto" value="" step="any" min="0" class="priceinput" />
        </p>
        
        <p>
            <label for="chargessince">Open charges since: </label>
            <input type="text" size="13" id="chargessince" name="chargessince" value="" class="datepicker" />
        </p>
        
        <p>
            <label for="accountexpiresfrom">Account expires/expired: </label>
            from&#160;<input type="text" size="13" id="accountexpiresfrom" name="accountexpiresfrom" value="" class="datepicker" />
            to&#160;<input type="text" size="13" id="accountexpiresto" name="accountexpiresto" value="" class="datepicker" />
        </p>
        
        <p>
            <label for="debarreduntilfrom">Debarred until: </label>
            from&#160;<input type="text" size="13" id="debarreduntilfrom" name="debarreduntilfrom" value="" class="datepicker" />
            to&#160;<input type="text" size="13" id="debarreduntilto" name="debarreduntilto" value="" class="datepicker" />
        </p>
        
        <p>
            <label for="inactivesince">Inactive since: </label>
            <input type="text" size="13" id="inactivesince" name="inactivesince" value="" class="datepicker" />
        </p>
        
        <p>
            <label for="lastlettercode">Last letter: </label>
            [% SET letters = Letters.all( selected => lastlettercode) %]
            <select id="lastlettercode" name="lastlettercode">
              [% IF letters.size != 1 %]
                <option value="">Any</option>
              [% END %]
              [% FOREACH b IN letters %]
                [% IF b.selected %]
                  <option selected="selected" value="[% b.code %]">[% b.name %]</option>
                [% ELSE %]
                  <option value="[% b.code %]">[% b.name %]</option>
                [% END %]
              [% END %]
            </select>
        </p>
        
        <p>
           <label for="overduelevel">Checkouts overdue level: </label>
           <select id="overduelevel" name="overduelevel">
              <option value="">Not selected</option>
              [% levels = ['1','2','3','4','5'] %]
              [% FOREACH b IN levels %]
                [% IF b == overduelevel %]
                  <option selected="selected" value="[% b %]">Level [% b %]</option>
                [% ELSE %]
                  <option value="[% b %]">Level [% b %]</option>
                [% END %]
              [% END %]
           </select>
        </p>
        
        <p>
           <label for="validemailavailable">Email Address: </label>
           <select id="validemailavailable" name="validemailavailable">
                <option value="">Not selected</option>
                [% IF ( validemailavailable == 'yes' ) %]
                    <option value="yes" selected="selected">Email available</option>
                [% ELSE %]
                    <option value="yes">Email available</option>
                [% END %]
                [% IF ( validemailavailable == 'no' ) %]
                    <option value="no" selected="selected">Email not available</option>
                [% ELSE %]
                    <option value="no">Email not available</option>
                [% END %]
           </select>
        </p>
        
        <p>
            <label for="patronlistid">Patron list: </label>
            <select id="patronlistid" name="patronlistid">
              <option value="">Not selected</option>
                [% FOREACH p IN patron_lists %]
                  [% IF p.patron_list_id == patronlistid %]
                    <option selected="selected" value="[% p.patron_list_id %]">[% p.name %]</option>
                  [% ELSE %]
                    <option value="[% p.patron_list_id %]">[% p.name %]</option>
                  [% END %]
                [% END %]
            </select>
        </p>
    </div>
    </form>
</div>
    [% INCLUDE 'patron-search-box.inc' %]

    [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]
    <div id="checkin_search" class="residentsearch">
    <form method="post" action="/cgi-bin/koha/circ/returns.pl" autocomplete="off">
        <label class="tip" for="ret_barcode">Scan a barcode to check in:</label>
    <input class="head-searchbox" name="barcode" id="ret_barcode" size="40" accesskey="r" type="text" />
    <input value="Submit" class="submit" type="submit" />
    </form>
    </div>
        <div id="renew_search" class="residentsearch">
            <form method="post" action="/cgi-bin/koha/circ/renew.pl" autocomplete="off">
                <label class="tip" for="ren_barcode">Scan a barcode to renew:</label>
                <input class="head-searchbox" name="barcode" id="ren_barcode" size="40" type="text" />
                <input value="Submit" class="submit" type="submit" />
            </form>
        </div>
    [% END %]

    [% IF ( CAN_user_catalogue ) %]
    <div id="catalog_search" class="residentsearch">
        <form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
            [% IF ( Koha.Preference('IntranetCatalogSearchPulldown') ) %]
                <label class="tip" for="search-form">Enter search keywords:</label>
                [% INCLUDE 'search_indexes.inc' %]
            [% ELSE %]
                <label class="tip" for="search-form">Enter search keywords:</label>
            [% END %]
             <input type="text" name="q" id="search-form" size="40" value="" title="Enter the terms you wish to search for." class="head-searchbox form-text" />
             <input type="submit" name="op" id="opac-submit" value="Submit" class="submit" />
        </form>
    </div>[% END %]

    <ul>
        <li><a class="keep_text" href="#patron_search">Search patrons</a></li>
        [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]<li><a class="keep_text" href="#circ_search">Check out</a></li>[% END %]
        [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]<li><a class="keep_text" href="#checkin_search">Check in</a></li>[% END %]
        [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]<li><a class="keep_text" href="#renew_search">Renew</a></li>[% END %]
        [% IF ( CAN_user_catalogue ) %]<li><a class="keep_text" href="#catalog_search">Search the catalog</a></li>[% END %]
    </ul>
</div><!-- /header_search -->
</div><!-- /gradient -->
<!-- End Patrons Resident Search Box -->

[% MACRO jsextrainclude BLOCK %]
[% INCLUDE 'calendar.inc' %]
<script type="text/javascript">
    $(document).ready(function() {
        $("#chargessince").datepicker( { 
            autoclose: true, 
            maxDate: -1,
            showOn: "both",
            changeMonth: true,
            changeYear: true,
            buttonImage: '/intranet-tmpl/prog/img/famfamfam/silk/calendar.png',
            buttonImageOnly: true,
            showButtonPanel: true,
            showOtherMonths: true,
            selectOtherMonths: true
        });
        $("#accountexpiresfrom").datepicker( { 
            autoclose: true, 
            showOn: "both",
            changeMonth: true,
            changeYear: true,
            buttonImage: '/intranet-tmpl/prog/img/famfamfam/silk/calendar.png',
            buttonImageOnly: true,
            showButtonPanel: true,
            showOtherMonths: true,
            selectOtherMonths: true
        });
        $("#accountexpiresto").datepicker( { 
            autoclose: true, 
            showOn: "both",
            changeMonth: true,
            changeYear: true,
            buttonImage: '/intranet-tmpl/prog/img/famfamfam/silk/calendar.png',
            buttonImageOnly: true,
            showButtonPanel: true,
            showOtherMonths: true,
            selectOtherMonths: true
        });
        $("#debarreduntilfrom").datepicker( {
            autoclose: true,
            showOn: "both",
            changeMonth: true,
            changeYear: true,
            buttonImage: '/intranet-tmpl/prog/img/famfamfam/silk/calendar.png',
            buttonImageOnly: true,
            showButtonPanel: true,
            showOtherMonths: true,
            selectOtherMonths: true
        });
        $("#debarreduntilto").datepicker( {
            autoclose: true,
            showOn: "both",
            changeMonth: true,
            changeYear: true,
            buttonImage: '/intranet-tmpl/prog/img/famfamfam/silk/calendar.png',
            buttonImageOnly: true,
            showButtonPanel: true,
            showOtherMonths: true,
            selectOtherMonths: true
        });
        $("#inactivesince").datepicker( { 
            autoclose: true, 
            maxDate: -1,
            showOn: "both",
            changeMonth: true,
            changeYear: true,
            buttonImage: '/intranet-tmpl/prog/img/famfamfam/silk/calendar.png',
            buttonImageOnly: true,
            showButtonPanel: true,
            showOtherMonths: true,
            selectOtherMonths: true
        });
    });
</script>
[% END %]
