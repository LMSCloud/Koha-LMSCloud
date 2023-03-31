// Copyright 2020,2023 LMSCloud GmbH
//
// This file is part of Koha.
//
// Koha is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// Koha is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Koha; if not, see <http://www.gnu.org/licenses>.

var munzingerData = new Object;
var origResultHeaderMunzinger;
var prevPageTextMunzinger;
var nextPageTextMunzinger;
var maxHitCountMunzinger;
var munzingerHitFieldname;
var munzingerHitShowHide;
var munzingerBestHitName;
var canShowMunzingerHitWords = false;

function getMunzingerFacet(query_desc,maxHitCount,prevPageText,nextPageText,hitName,hitShowHide,bestHitName) {
    if (!origResultHeaderMunzinger) {
        origResultHeaderMunzinger = $('#numresults').html();
    }
    prevPageTextMunzinger = prevPageText;
    nextPageTextMunzinger = nextPageText;
    maxHitCountMunzinger  = maxHitCount;
    munzingerHitFieldname = hitName;
    munzingerHitShowHide = hitShowHide;
    munzingerBestHitName = bestHitName;
    $.ajax({
    url: "/cgi-bin/koha/opac-munzinger.pl",
        method: "POST",
        cache: false,
        data: { 'search' : query_desc, 'maxcount' : 0 },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result.categorycount && data.result.categorycount > 0 ) {
                showMunzingerFacetEntries(data.result,query_desc);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading Munzinger titles:", data1, data2, data3);
        }
   });
}

function getMunzingerResult(facetID, offset) {
    var query_desc = munzingerData['query'];
    var publication = munzingerData['results'].categories[facetID].id;
    var canShowMunzingerHitWords = 0;
    $.ajax({
    url: "/cgi-bin/koha/opac-munzinger.pl",
        method: "POST",
        cache: false,
        data: { 'search' : munzingerData['query'], 'maxcount' : maxHitCountMunzinger, 'offset' : offset, 'publication' : publication  },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result.categories && data.result.categories.length > 0 ) {
                munzingerData.results.categories[facetID] = data.result.categories[0];
                showMunzingerResult(facetID);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading Munzinger hits:", data1, data2, data3);
        }
   });
}

function showMunzingerFacetEntries(facetData,query) {
    var listElement = document.createElement("ul");
    for (var i=0; i<facetData.categorycount; i++) {
        var facetElement = document.createElement("li");
        var spanElement  = document.createElement("span");
        spanElement.setAttribute('class','facet-label');
        var hrefElement  = document.createElement("a");
        hrefElement.setAttribute('href','javascript:getMunzingerResult('+i+',0)');
        hrefElement.textContent = facetData.categories[i].name;
        spanElement.appendChild(hrefElement);
        facetElement.appendChild(spanElement);
        spanElement  = document.createElement("span");
        spanElement.innerHTML = '&#160;';
        facetElement.appendChild(spanElement);
        spanElement  = document.createElement("span");
        spanElement.setAttribute('class','facet-count');
        spanElement.textContent = "(" + facetData.categories[i].count + ")";
        facetElement.appendChild(spanElement);
        listElement.appendChild(facetElement);
    }
    $('#munzinger-facet ul').html(listElement.innerHTML);
    $('#munzinger-count').text(facetData.hitcount);
    $('#munzinger-facet').css("display","block");
    $('#encyclopedia-facets').css("display","block");
    
    munzingerData['query'] = query;
    munzingerData['results'] = facetData;
}

function showMunzingerResult(facetID) {
    var pagination = getMunzingerPagination(facetID, maxHitCountMunzinger);
    var content = '';
    
    for (var i=0; i<munzingerData.results.categories[facetID].hits.length;i++) {
        content += generateMunzingerEntry(facetID,i);
    }

    if ( $("#userresults").css("display") != "none" ){
        $('#encyclopediaresults').toggle();
        $('#userresults').toggle();
    }
    $('#encyclopediahits').html(content);
    if ( pagination.length == 0 ) {
        $('#encyclopediaheader').html('<strong><span class="encyclopediasource"></span></strong> <span class="encyclopediasourceaction"></span>');
    } else {
        $('#encyclopediaheader').html('<div class="container-fluid"><div class="row"><div class="col-sm-6"><strong><span class="encyclopediasource"></span> <span class="encyclopediasourceaction"></span></strong></div><div class="col-sm-6">' + pagination + '</div></div></div>');
    }
    $('.encyclopediasource').html(munzingerData.results.categories[facetID].name);
    if ( canShowMunzingerHitWords > 0 ) {
        $('.encyclopediasourceaction').html('<a href="#" onclick="try{$(\'.munzingerHitFoundDisplay\').toggle()}catch(e){}return false" title="' + munzingerHitShowHide + '"><i class="fa fa-search"></i></a> ');
    }
    
    $('.encyclopediaprovider').html(' <a href="' + munzingerData.results.searchmunzinger + '" target="_blank">' + 'Munzinger</a> ' );
    $('.encyclopediasearchhitcount').html(' ' + munzingerData.results.categories[facetID].count + ' ');
    
    $('.munzingerHitFoundDisplay span.highlighter').css('font-weight','bold');
    
    if ( $('.onlyAdditionalOfferFacets').length > 0 )
        $('#numresultsAdditionalOffers').html($('#encyclopedianumresults').html());
    else
        $('#numresults').html($('#encyclopedianumresults').html());
    $('#showCatalogHitList').attr("href", "javascript:showCatalogHitListMunzinger()");
}

function getMunzingerPagination(facetID, maxHitCount) {
    var paginationText = '';
    if ( munzingerData.results.categories[facetID].count <= maxHitCount ) {
        return paginationText;
    }
    paginationText = '<div id="top-pages" class="right-align"><nav class="pagination pagination-sm noprint"><ul class="pagination">';
    
    var offset = munzingerData.results.categories[facetID].offset;
    var results_per_page = maxHitCount;
    var total = munzingerData.results.categories[facetID].count;
    
    var current_page = offset / results_per_page + 1;
    var last_page = Math.floor(total / results_per_page);
    if ( ( total % results_per_page ) > 0 ) {
        last_page = last_page + 1;
    }
    var last_page_offset = (last_page - 1) * results_per_page;
    var prev_page_offset = offset - results_per_page;
    var next_page_offset = offset + results_per_page;
    if ( prev_page_offset > 0 && last_page > 2 ) {
        paginationText += '<li class="page-item"><a href="javascript:getMunzingerResult(' + facetID + ',' + prev_page_offset + ')" class="page-link">' + prevPageTextMunzinger + '</a></li>';
    }
    if ( current_page > 1 ) {
        paginationText += '<li class="page-item"><a href="javascript:getMunzingerResult(' + facetID + ',0)" class="page-link">1</a></li>';
        if ( current_page > 2 ) {
            paginationText += '<li class="page-item"><a href="#" style="pointer-events: none;cursor: default;" class="page-link">...</a></li>';
        }
        if ( current_page > 2 && current_page == last_page ) {
             paginationText += '<li class="page-item"><a href="javascript:getMunzingerResult(' + facetID + ',' + prev_page_offset + ')" class="page-link">' + (last_page - 1) + '</a></li>';
        }
        paginationText += '<li class="page-item active"><a href="#" class="page-link">' + current_page + '</a></li>';
    }
    else {
        paginationText += '<li class="page-item active"><a href="#" class="page-link">' + current_page + '</a></li>';
        if ( last_page >= 2 ) {
            paginationText += '<li class="page-item"><a href="javascript:getMunzingerResult(' + facetID + ',' + results_per_page + ')" class="page-link">2</a></li>';
        }
    }
    if ( ( ( current_page + 1 ) < last_page && current_page > 2 ) || ( last_page > 2 && current_page < 3 ) ) {
        paginationText += '<li class="page-item"><a href="#" style="pointer-events: none;cursor: default;" class="page-link">...</a></li>';
    }
    if ( last_page > 2 && current_page < last_page ) {
        paginationText += '<li class="page-item"><a href="javascript:getMunzingerResult(' + facetID + ',' + last_page_offset + ')" class="page-link">' + last_page + '</a></li>&nbsp;';
        paginationText += '<li class="page-item"><a href="javascript:getMunzingerResult(' + facetID + ',' + next_page_offset + ')" class="page-link">' + nextPageTextMunzinger + '</a></li>';
    }
    
    paginationText += '<ul></nav></div>';
    
    return paginationText;
}

function showCatalogHitListMunzinger() {
    if ( $("#userresults").css("display") == "none" ){
        $('#numresults').html(origResultHeaderMunzinger);
        $('#userresults').toggle();
        $('#encyclopediaresults').toggle();
    }
}

function generateMunzingerEntry(facetID,entryID) {
    var rowElement = document.createElement("tr");
    var colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    var dateElement = document.createElement("div");
    if ( munzingerData.results.categories[facetID].hits[entryID].date ) {
        dateElement.textContent = munzingerData.results.categories[facetID].hits[entryID].date + " ";
    }
    dateElement.setAttribute('class','encyclopediahitheader');
    if ( munzingerData.results.categories[facetID].hits[entryID].top == 'true' ) {
        var iElement = document.createElement("i");
        iElement.setAttribute('class','fa fa-star');
        iElement.setAttribute('aria-hidden','true');
        iElement.setAttribute('title',munzingerBestHitName);
        dateElement.appendChild(iElement);
    }
    colElement.appendChild(dateElement);
    var txtElement = document.createElement("a");
    txtElement.setAttribute('class','title');
    txtElement.setAttribute('target','_blank');
    txtElement.setAttribute('href',munzingerData.results.categories[facetID].hits[entryID].link);
    if ( munzingerData.results.categories[facetID].hits[entryID].title.length > 0 ) {
        txtElement.textContent = munzingerData.results.categories[facetID].hits[entryID].title;
    }
    colElement.appendChild(txtElement);
    var txtDivElement = document.createElement("div");
    txtDivElement.setAttribute('class','encyclopediahitdescription');
    txtElement = document.createElement("span");
    txtElement.setAttribute('class','results_summary summary');
    txtElement.innerHTML = munzingerData.results.categories[facetID].hits[entryID].text;
    txtDivElement.appendChild(txtElement);
    colElement.appendChild(txtDivElement);
    if ( munzingerData.results.categories[facetID].hits[entryID].words.length > 0 &&
         munzingerData.results.categories[facetID].hits[entryID].words != '...' ) {
        canShowMunzingerHitWords++;
        var hitElement = document.createElement("div");
        hitElement.setAttribute('class','munzingerHitFoundDisplay');
        var hitTxtElement = document.createElement("span");
        hitTxtElement.setAttribute('class','results_summary munzingerHitFoundDisplayName');
        hitTxtElement.innerHTML = munzingerHitFieldname + munzingerData.results.categories[facetID].hits[entryID].words;
        hitElement.appendChild(hitTxtElement);
        colElement.appendChild(hitElement);
    }
    rowElement.appendChild(colElement);
    return '<tr>' + rowElement.innerHTML + '</tr>';
}
