// Copyright 2020 LMSCloud GmbH
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

var brockhausData = new Object;
var origResultHeaderBrockhaus;
var prevPageTextBrockhaus;
var nextPageTextBrockhaus;
var maxHitCountBrockhaus;

function getBrockhausFacet(query_desc,maxHitCount,prevPageText,nextPageText) {
    if (!origResultHeaderBrockhaus) {
        origResultHeaderBrockhaus = $('#numresults').html();
    }
    prevPageTextBrockhaus = prevPageText;
    nextPageTextBrockhaus = nextPageText;
    maxHitCountBrockhaus  = maxHitCount;
    $.ajax({
    url: "/cgi-bin/koha/opac-brockhaus.pl",
        type: "POST",
        cache: false,
        data: { 'search' : query_desc, 'maxcount' : maxHitCountBrockhaus },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result && data.result.length > 0 ) {
                showBrockhausFacetEntries(data.result,query_desc);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading Brockhaus hits:", data1, data2, data3);
        }
   });
}
function getBrockhausResult(facetID, offset) {
    var query_desc = brockhausData['query'];
    var collection = brockhausData['results'][facetID].searchType;
    $.ajax({
    url: "/cgi-bin/koha/opac-brockhaus.pl",
        type: "POST",
        cache: false,
        data: { 'search' : query_desc, 'maxcount' : maxHitCountBrockhaus, 'offset' : offset, 'collection' : collection  },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result && data.result.length > 0 ) {
                brockhausData['results'][facetID] = data.result[0];
                showBrockhausResult(facetID);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading Brockhaus hits:", data1, data2, data3);
        }
   });
}
function showBrockhausFacetEntries(facetData,query) {
    if ( facetData.length > 0 ) {
        var listElement = document.createElement("ul");
        var foundHits = 0;
        for (var i=0; i<facetData.length; i++) {
            if ( facetData[i].searchType ) {
                var facetElement = document.createElement("li");
                var spanElement  = document.createElement("span");
                spanElement.setAttribute('class','facet-label');
                var hrefElement  = document.createElement("a");
                var facetElementName;
                if ( facetData[i].searchType == "ecs.enzy" ) {
                    facetElementName = "Enzyklopädie";
                }
                else if ( facetData[i].searchType == "ecs.julex" ) {
                    facetElementName = "Jugendlexikon";
                }
                else if ( facetData[i].searchType == "ecs" ) {
                    facetElementName = "Enzyklopädie und Jugendlexikon";
                }
                else if ( facetData[i].searchType == "ecs.kilex" ) {
                    facetElementName = "Kinderlexikon";
                }
                facetData[i]['name'] = facetElementName;
                hrefElement.setAttribute('href','javascript:showBrockhausResult('+i+',' + maxHitCountBrockhaus + ')');
                hrefElement.textContent = facetElementName;
                spanElement.appendChild(hrefElement);
                facetElement.appendChild(spanElement);
                spanElement  = document.createElement("span");
                spanElement.innerHTML = '&#160;';
                facetElement.appendChild(spanElement);
                spanElement  = document.createElement("span");
                spanElement.setAttribute('class','facet-count');
                spanElement.textContent = "(" + facetData[i].numFound + ")";
                facetElement.appendChild(spanElement);
                listElement.appendChild(facetElement);
                foundHits += facetData[i].numFound;
            }
        }
        $('#brockhaus-facet ul').html(listElement.innerHTML);
        $('#brockhaus-count').text(foundHits);
        $('#brockhaus-facet').css("display","block");
        $('#encyclopedia-facets').css("display","block");
        
        brockhausData['results'] = facetData;
        brockhausData['query'] = query;
    }
}
function showBrockhausResult(facetID) {
    var pagination = getPagination(facetID, maxHitCountBrockhaus);
    var content = '';
    for (var i=0; i<brockhausData.results[facetID].hitList.length;i++) {
        content += generateBrockhausEntry(facetID,i);
    }
    if ( $("#userresults").css("display") != "none" ){
        $('#encyclopediaresults').toggle();
        $('#userresults').toggle();
    }
    $('#encyclopediahits').html(content);
    if ( pagination.length == 0 ) {
        $('#encyclopediaheader').html('<strong><span class="encyclopediasource"></span></strong>');
    } else {
        $('#encyclopediaheader').html('<div class="container-fluid"><div class="row"><div class="span6"><strong><span class="encyclopediasource"></span></strong></div>' + pagination + '</div></div>');
    }
    $('.encyclopediasource').html(brockhausData.results[facetID].name);
    
    $('.encyclopediaprovider').html(' <a href="' + brockhausData.results[facetID].searchAtBrockhaus + '" target="_blank">' + 'Brockhaus</a> ' );
    $('.encyclopediasearchhitcount').html(' ' + brockhausData.results[facetID].numFound + ' ');
    $('#numresults').html($('#encyclopedianumresults').html());
    $('#showCatalogHitList').attr("href", "javascript:showCatalogHitListBrockhaus()");
}
function getPagination(facetID, maxHitCount) {
    var paginationText = '';
    if ( brockhausData.results[facetID].numFound <= maxHitCount ) {
        return paginationText;
    }
    paginationText = '<div class="span6"><div id="top-pages" class="right-align"><div class="pagination pagination-small noprint"><ul>';
    
    var offset = brockhausData.results[facetID].start;
    var results_per_page = maxHitCount;
    var total = brockhausData.results[facetID].numFound;
    
    var current_page = offset / results_per_page + 1;
    var last_page = Math.floor(total / results_per_page);
    if ( ( total % results_per_page ) > 0 ) {
        last_page = last_page + 1;
    }
    var last_page_offset = (last_page - 1) * results_per_page;
    var prev_page_offset = offset - results_per_page;
    var next_page_offset = offset + results_per_page;
    if ( prev_page_offset > 0 && last_page > 2 ) {
        paginationText += '<li><a href="javascript:getBrockhausResult(' + facetID + ',' + prev_page_offset + ')">' + prevPageTextBrockhaus + '</a></li>';
    }
    if ( current_page > 1 ) {
        paginationText += '<li><a href="javascript:getBrockhausResult(' + facetID + ',0)">1</a></li>';
        if ( current_page > 2 ) {
            paginationText += '<li><a href="#" style="pointer-events: none;cursor: default;">...</a></li>';
        }
        if ( current_page > 2 && current_page == last_page ) {
             paginationText += '<li><a href="javascript:getBrockhausResult(' + facetID + ',' + prev_page_offset + ')">' + (last_page - 1) + '</a></li>';
        }
        paginationText += '<li class="active"><a href="#">' + current_page + '</a></li>';
    }
    else {
        paginationText += '<li class="active"><a href="#">' + current_page + '</a></li>';
        if ( last_page >= 2 ) {
            paginationText += '<li><a href="javascript:getBrockhausResult(' + facetID + ',' + results_per_page + ')">2</a></li>';
        }
    }
    if ( ( ( current_page + 1 ) < last_page && current_page > 2 ) || ( last_page > 2 && current_page < 3 ) ) {
        paginationText += '<li><a href="#" style="pointer-events: none;cursor: default;">...</a></li>';
    }
    if ( last_page > 2 && current_page < last_page ) {
        paginationText += '<li><a href="javascript:getBrockhausResult(' + facetID + ',' + last_page_offset + ')">' + last_page + '</a></li>&nbsp;';
        paginationText += '<li><a href="javascript:getBrockhausResult(' + facetID + ',' + next_page_offset + ')">' + nextPageTextBrockhaus + '</a></li>';
    }
    
    paginationText += '<ul></div></div></div>';
    
    return paginationText;
}
function showCatalogHitListBrockhaus() {
    if ( $("#userresults").css("display") == "none" ){
        $('#numresults').html(origResultHeaderBrockhaus);
        $('#userresults').toggle();
        $('#encyclopediaresults').toggle();
    }
}
function generateBrockhausEntry(facetID,entryID) {
    var rowElement = document.createElement("tr");
    var colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    var divElement = document.createElement("div");
    divElement.setAttribute('class','coverimages');
    var linkElement = document.createElement("a");
    linkElement.setAttribute('class','p1');
    linkElement.setAttribute('target','_blank');
    linkElement.setAttribute('href',brockhausData.results[facetID].hitList[entryID].url);
    linkElement.setAttribute('alt',brockhausData.results[facetID].hitList[entryID].title);
    if ( brockhausData.results[facetID].hitList[entryID].thumbnail ) {
        var imageElement = document.createElement("img");
        imageElement.setAttribute('width','170');
        imageElement.setAttribute('src',brockhausData.results[facetID].hitList[entryID].thumbnail);
        linkElement.appendChild(imageElement);
    } else {
        var divImageElement = document.createElement("div");
        divImageElement.setAttribute('class','bro-logo');
        divImageElement.setAttribute('style','border:1px solid silver; width:170px; height:60px; opacity:60%; margin:0px; overflow:hidden; text-align:center');
        var imageElement = document.createElement("img");
        imageElement.setAttribute('src','https://www.brockhaus.de/logo/brockhaus_logo_pos_250x250.png');
        imageElement.setAttribute('alt','Brockhaus Logo');
        imageElement.setAttribute('style','width:80px; position:relative; top:-10px');
        divImageElement.appendChild(imageElement);
        linkElement.appendChild(divImageElement);
    }
    divElement.appendChild(linkElement);
    colElement.appendChild(divElement);
    rowElement.appendChild(colElement);
    
    colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    var txtElement = document.createElement("a");
    txtElement.setAttribute('class','title');
    txtElement.setAttribute('target','_blank');
    txtElement.setAttribute('href',brockhausData.results[facetID].hitList[entryID].url);
    txtElement.textContent = brockhausData.results[facetID].hitList[entryID].title;
    colElement.appendChild(txtElement);
    if ( brockhausData.results[facetID].hitList[entryID].summary ) {
        txtElement = document.createElement("span");
        txtElement.setAttribute('class','results_summary summary');
        txtElement.setAttribute('style','font-size: 100%');
        txtElement.innerHTML = brockhausData.results[facetID].hitList[entryID].summary;
        colElement.appendChild(txtElement);
    }
    rowElement.appendChild(colElement);
    return '<tr>' + rowElement.innerHTML + '</tr>';
}