[% USE Koha %]
[% USE Branches %]
[% USE Categories %]
[% USE Letters %]
<div class="gradient">
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl">[% LibraryName %]</a></h1><!-- Begin Patrons Resident Search Box -->
<div id="header_search">
    <div id="patron_search" class="residentsearch">
    <p class="tip">Enter patron card number or partial name:</p>
    <form name="membersearchform" action="/cgi-bin/koha/members/member.pl" method="post">
    <input id="searchmember" data-toggle="tooltip" size="25" class="head-searchbox focus" name="searchmember" type="text" value="[% searchmember %]"/>
    <input type="hidden" name="quicksearch" value="1" />
    <span class="filteraction" id="filteraction_off"> <a href="#">[-]</a></span>
    <span class="filteraction" id="filteraction_on"> <a href="#">[+]</a></span>

    <input value="Search" class="submit" type="submit" />

    <div id="filters">
        <p><label for="searchfieldstype">Search fields:</label>
            <select name="searchfieldstype" id="searchfieldstype">
              [% IF searchfieldstype == "standard" %]
                <option selected="selected" value='standard'>Standard</option>
              [% ELSE %]
                <option value='standard'>Standard</option>
              [% END %]
              [% IF searchfieldstype == "surname" %]
                <option selected="selected" value='surname'>Surname</option>
              [% ELSE %]
                <option value='surname'>Surname</option>
              [% END %]
              [% IF searchfieldstype == "email" %]
                <option selected="selected" value='email'>Email</option>
              [% ELSE %]
                <option value='email'>Email</option>
              [% END %]
              [% IF searchfieldstype == "borrowernumber" %]
                <option selected="selected" value='borrowernumber'>Borrower number</option>
              [% ELSE %]
                <option value='borrowernumber'>Borrower number</option>
              [% END %]
              [% IF searchfieldstype == "userid" %]
                <option selected="selected" value='userid'>Username</option>
              [% ELSE %]
                <option value='userid'>Username</option>
              [% END %]
              [% IF searchfieldstype == "phone" %]
                <option selected="selected" value='phone'>Phone number</option>
              [% ELSE %]
                <option value='phone'>Phone number</option>
              [% END %]
              [% IF searchfieldstype == "address" %]
                <option selected="selected" value='address'>Street Address</option>
              [% ELSE %]
                <option value='address'>Street Address</option>
              [% END %]
              [% IF searchfieldstype == "city" %]
                <option selected="selected" value='city'>City</option>
              [% ELSE %]
                <option value='city'>City</option>
              [% END %]
              [% IF searchfieldstype == "dateofbirth" %]
                <option selected="selected" value='dateofbirth'>Date of birth</option>
              [% ELSE %]
                <option value='dateofbirth'>Date of birth</option>
              [% END %]
              [% IF searchfieldstype == "sort1" %]
                <option selected="selected" value='sort1'>Sort field 1</option>
              [% ELSE %]
                <option value='sort1'>Sort field 1</option>
              [% END %]
              [% IF searchfieldstype == "sort2" %]
                <option selected="selected" value='sort2'>Sort field 2</option>
              [% ELSE %]
                <option value='sort2'>Sort field 2</option>
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
            [% SET branches = Branches.all( selected => branchcode_filter, only_my_group => 1 ) %]
            <select name="branchcode_filter" id="branchcode">
                [% IF branches.size != 1 %]
                  <option value="">Any</option>
                [% END %]
                [% FOREACH b IN branches %]
                    [% IF b.selected %]
                        <option value="[% b.branchcode %]" selected="selected">[% b.branchname %]</option>
                    [% ELSE %]
                        <option value="[% b.branchcode %]">[% b.branchname |html %]</option>
                    [% END %]
                [% END %]
            </select>
        </p>
        
        <p>
            <label for="categorycode">Category: </label>
            [% SET categories = Categories.all() %]
            <select name="categorycode_filter" id="categorycode">
                <option value="">Any</option>
                [% FOREACH category IN categories %]
                    [% IF category.categorycode == categorycode_filter %]
                        <option value="[% category.categorycode %]" selected="selected">[% category.description |html %]</option>
                    [% ELSE %]
                        <option value="[% category.categorycode %]">[% category.description |html %]</option>
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
            <input type="text" size="13" id="chargessince" name="chargessince" value="" class="dateinput" />
        </p>
        
        <p>
            <label for="accountexpiresfrom">Account expires/expired: </label>
            from&#160;<input type="text" size="13" id="accountexpiresfrom" name="accountexpiresfrom" value="" class="dateinput" />
            to&#160;<input type="text" size="13" id="accountexpiresto" name="accountexpiresto" value="" class="dateinput" />
        </p>
        
        <p>
            <label for="debarreduntilfrom">Debarred until: </label>
            from&#160;<input type="text" size="13" id="debarreduntilfrom" name="debarreduntilfrom" value="" class="dateinput" />
            to&#160;<input type="text" size="13" id="debarreduntilto" name="debarreduntilto" value="" class="dateinput" />
        </p>
        
        <p>
            <label for="inactivesince">Inactive since: </label>
            <input type="text" size="13" id="inactivesince" name="inactivesince" value="" class="dateinput" />
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
    <p class="tip">Scan a barcode to check in:</p>
    <form method="post" action="/cgi-bin/koha/circ/returns.pl" autocomplete="off">
    <input class="head-searchbox" name="barcode" id="ret_barcode" size="40" accesskey="r" type="text" />
    <input value="Submit" class="submit" type="submit" />
    </form>
    </div>
        <div id="renew_search" class="residentsearch">
        <p class="tip">Scan a barcode to renew:</p>
            <form method="post" action="/cgi-bin/koha/circ/renew.pl" autocomplete="off">
                <input class="head-searchbox" name="barcode" id="ren_barcode" size="40" type="text" />
                <input value="Submit" class="submit" type="submit" />
            </form>
        </div>
    [% END %]

    [% IF ( CAN_user_catalogue ) %]
    <div id="catalog_search" class="residentsearch">
    <p class="tip">Enter search keywords:</p>
        <form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
             [% IF ( Koha.Preference('IntranetCatalogSearchPulldown') ) %][% INCLUDE 'search_indexes.inc' %][% END %]
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

<script type="text/javascript">
    var advsearch = "[% advsearch %]";
    var destination = "[% destination %]";
    var catcode = "[% catcode %]";
    var dateformat = "[% Koha.Preference('dateformat') %]";
    var CAN_user_borrowers_edit_borrowers = "[% CAN_user_borrowers_edit_borrowers %]";
    var NorwegianPatronDBEnable = "[% NorwegianPatronDBEnable %]";
    var CATCODE_MULTI = "[% CATCODE_MULTI %]";
    var borrowernumber = "[% patron.borrowernumber %]";
</script>

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