// Copyright 2021 LMSCloud GmbH
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

var helimaData = new Object;
var origResultHeaderHeLiMa;
var prevPageTextHeLiMa;
var nextPageTextHeLiMa;
var maxHitCountHeLiMa;
var targetLinkHeLiMa = "_blank";
var readMoreHeLiMa = "Read more »";
var readLessHeLiMa = "« Read less";
var authorByHeLiMa = "by/with ";
var licensorNameHeLiMa = "Hesse offers";
var durationHeLiMa = "Duration:";
var suitableForHeLiMa = "suitable for ";
var suitableForGradeHeLiMa = "suitable for grade ";

function getHeLiMaFacet(query_desc,maxHitCount,licensorName,prevPageText,nextPageText,readMore,readLess,madeby,durationText,suitableForText,suitableForGradeText) {
    if (!origResultHeaderHeLiMa) {
        origResultHeaderHeLiMa = $('#numresults').html();
    }
    prevPageTextHeLiMa = prevPageText;
    nextPageTextHeLiMa = nextPageText;
    readMoreHeLiMa     = readMore;
    readLessHeLiMa     = readLess;
    authorByHeLiMa     = madeby;
    maxHitCountHeLiMa  = maxHitCount;
    licensorNameHeLiMa = licensorName;
    durationHeLiMa     = durationText;
    suitableForHeLiMa  = suitableForText;
    suitableForGradeHeLiMa = suitableForGradeText;
    $.ajax({
    url: "/cgi-bin/koha/opac-helima.pl",
        method: "POST",
        cache: false,
        data: { 'search' : query_desc, 'maxcount' : 0 },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result.collections && data.result.collections.length > 0 ) {
                showHeLiMaFacetEntries(data.result,query_desc);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading HeLiMa hits:", data1, data2, data3);
        }
   });
}
function getHeLiMaResult(facetID, offset) {
    var query_desc = helimaData['query'];
    $.ajax({
    url: "/cgi-bin/koha/opac-helima.pl",
        method: "POST",
        cache: false,
        data: { 'search' : query_desc, 'maxcount' : maxHitCountHeLiMa, 'offset' : offset, 'collection' : facetID  },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result.hits && data.result.hits.length > 0 ) {
                helimaData['results'][facetID] = data.result;
                showHeLiMaResult(facetID);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading HeLiMa hits:", data1, data2, data3);
        }
   });
}
function showHeLiMaFacetEntries(facetData,query) {
    facetData = facetData.collections;
    var saveFacetData = new Object;
    
    if ( facetData.length > 0 ) {
        var listElement = document.createElement("ul");
        var foundHits = 0;
        for (var i=0; i<facetData.length; i++) {
            if ( facetData[i].id && facetData[i].name.length > 0 ) {
                var facetElement = document.createElement("li");
                var spanElement  = document.createElement("span");
                spanElement.setAttribute('class','facet-label');
                var hrefElement  = document.createElement("a");
                var facetElementName = facetData[i].name;
                hrefElement.setAttribute('href','javascript:getHeLiMaResult("'+ facetData[i].id +'",0)');
                hrefElement.setAttribute('title',facetData[i].description ? facetData[i].description : facetData[i].name + " Angebot");
                hrefElement.textContent = facetElementName;
                spanElement.appendChild(hrefElement);
                facetElement.appendChild(spanElement);
                spanElement  = document.createElement("span");
                spanElement.innerHTML = '&#160;';
                facetElement.appendChild(spanElement);
                spanElement  = document.createElement("span");
                spanElement.setAttribute('class','facet-count');
                spanElement.textContent = "(" +  facetData[i].hits + ")";
                facetElement.appendChild(spanElement);
                listElement.appendChild(facetElement);
                foundHits += facetData[i].hits;
                saveFacetData[facetData[i].id] = facetData[i];
            }
        }
        $('#helima-facet ul').html(listElement.innerHTML);
        $('#helima-count').text(foundHits);
        $('#helima-facet').css("display","block");
        $('#encyclopedia-facets').css("display","block");
        
        helimaData['facets'] = saveFacetData;
        helimaData['results'] = facetData;
        helimaData['query'] = query;
    }
}

function showHeLiMaResult(facetID) {
    var pagination = getHeLiMaPagination(facetID, maxHitCountHeLiMa);
    var content = '';
    
    var with_image = false;
    for (var i=0; i<helimaData.results[facetID].hits.length;i++) {
        if ( helimaData.results[facetID].hits[i].image_url ) {
            with_image = true;
        }
    }

    for (var i=0; i<helimaData.results[facetID].hits.length;i++) {
        content += generateHeLiMaEntry(facetID,i,with_image);
    }

    if ( $("#userresults").css("display") != "none" ){
        $('#encyclopediaresults').toggle();
        $('#userresults').toggle();
        $('#overdrive-results').toggle();
    }
    $('#encyclopediahits').html(content);
    if ( pagination.length == 0 ) {
        $('#encyclopediaheader').html('<strong><span class="encyclopediasource"></span></strong>');
    } else {
        $('#encyclopediaheader').html('<div class="container-fluid"><div class="row"><div class="col-sm-6"><strong><span class="encyclopediasource"></span></strong></div>' + pagination + '</div></div>');
    }
    var name = helimaData.results[facetID].name;
    if ( helimaData.results[facetID].image && helimaData.results[facetID].image.length > 0 ) {
        name = '<img src="' + encodeURI(helimaData.results[facetID].image) + '" style="height: 24px" title="' + name + '">&nbsp;' + name;
    }
    $('.encyclopediasource').html(name);
    
    $('.encyclopediaprovider').html(licensorNameHeLiMa);
    $('.encyclopediasearchhitcount').html(' ' + helimaData.results[facetID].hitCount + ' ');
    if ( $('.onlyAdditionalOfferFacets').length > 0 )
        $('#numresultsAdditionalOffers').html($('#encyclopedianumresults').html());
    else
        $('#numresults').html($('#encyclopedianumresults').html());
    $('#showCatalogHitList').attr("href", "javascript:showCatalogHitListHeLiMa()");

    // calls LMSEllipsis in global namespace
    const lmse = new LMSEllipsis({
        identifier: 'truncable-txt',
        ellipsis: ' ... ',
        watch: false,
        lines: 2,
        explanations: { collapsed: readMoreHeLiMa, expanded: readLessHeLiMa }
    })
    lmse.truncate();
}

function generateHeLiMaEntry(facetID,entryID,with_image) {
    var hit = helimaData.results[facetID].hits[entryID];
    var rowElement = document.createElement("tr");
    var colElement = document.createElement("td");

    colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    
    if ( with_image ) {
        var divElement = document.createElement("div");
        divElement.setAttribute('class','coverimages');
        if ( hit.image_url ) {
            var linkElement;
            if ( hit.url && hit.url.length > 0 && hit.url != '#' ) {
                linkElement = document.createElement("a");
                linkElement.setAttribute('class','p1');
                linkElement.setAttribute('target',targetLinkHeLiMa);
                linkElement.setAttribute('href',hit.url);
                linkElement.setAttribute('alt',hit.title);
                linkElement.setAttribute('title',hit.title);
            }
        
            var imageElement = document.createElement("img");
            imageElement.setAttribute('width','170');
            imageElement.setAttribute('src',hit.image_url);
            if ( hit.url ) {    
                linkElement.appendChild(imageElement);
                divElement.appendChild(linkElement);
            } else {
                divElement.appendChild(imageElement);
            }
        }
        
        colElement.appendChild(divElement);
        rowElement.appendChild(colElement);
        
        colElement = document.createElement("td");
        colElement.setAttribute('class','bibliocol');
    }
    
    if ( hit.url && hit.url.length > 0 && hit.url != '#' ) {
        var txtElement = document.createElement("a");
        txtElement.setAttribute('class','title external-offer-link');
        txtElement.setAttribute('target',targetLinkHeLiMa);
        txtElement.setAttribute('href',hit.url);
        txtElement.textContent = hit.title;
        colElement.appendChild(txtElement);
    } else {
        var txtElement = document.createElement("div");
        txtElement.setAttribute('class','title');
        txtElement.textContent = hit.title;
        colElement.appendChild(txtElement);
    }
    
    var addDescription = document.createElement("p");
    addDescription.setAttribute('class','description');
    var hasDesc = false;
    if ( hit.fach && hit.fach.length > 0 ) {
        if ( 
            facetID == "31" /* Riffreporter */ 
        ) 
        {
            addDescription.appendChild(document.createTextNode(authorByHeLiMa));
        }
        var fach = document.createElement("span");
        fach.setAttribute('class','fach');
        fach.textContent = hit.fach;
        addDescription.append(fach);
        hasDesc = true;
    }
    if ( hit.topic && hit.topic.length > 0 && facetID != "6") {
        var topic = document.createElement("span");
        topic.setAttribute('class','topic');
        topic.textContent = hit.topic;
        if ( facetID == "23" &&  hit.topic == 'AUDIOBOOK' /* Tigerbooks */ ) 
        {
            topic.textContent = 'Hörbuch';
        }
        else if ( facetID == "23" &&  hit.topic == 'BOOK' /* Tigerbooks */ ) 
        {
            topic.textContent = 'Buch';
        }
        if ( hasDesc )
            addDescription.appendChild(document.createTextNode('; '));
        addDescription.append(topic);
        hasDesc = true;
    }
    if ( hit.medium && hit.medium.length > 0 && facetID != "23" /* Tigerbooks */ ) {
        var fach = document.createElement("span");
        fach.setAttribute('class','fach');
        fach.textContent = hit.medium;
        if ( hasDesc )
            addDescription.appendChild(document.createTextNode('; '));
        addDescription.append(fach);
        hasDesc = true;
    }
    if ( hit.klassenstufen && hit.klassenstufen.length > 0) {
        var klstufen = document.createElement("span");
        var txt = hit.klassenstufen;
        if ( /^[0-9,]+$/.test(txt)  ) {
            txt = suitableForGradeHeLiMa + txt;
        }
        else if ( /Klasse/.test(txt) )  {
            txt = suitableForHeLiMa + txt.replace(/,(?!\s)/g, ', ');
        }
        klstufen.setAttribute('class','klassenstufen');
        klstufen.textContent = txt;
        if ( hasDesc )
            addDescription.appendChild(document.createTextNode('; '));
        addDescription.append(klstufen);
        hasDesc = true;
    }
    if ( hit.dauer && hit.dauer.length > 0 ) {
        var dauer = document.createElement("span");
        dauer.setAttribute('class','duration');
        dauer.textContent = durationHeLiMa + hit.dauer;
        if ( hasDesc )
            addDescription.appendChild(document.createTextNode('; '));
        addDescription.append(dauer);
        hasDesc = true;
    }
    if ( hasDesc )
        colElement.appendChild(addDescription);
    
    rowElement.appendChild(colElement);
    return '<tr>' + rowElement.innerHTML + '</tr>';
}

function getHeLiMaPagination(facetID, maxHitCount) {
    var paginationText = '';
    if ( helimaData.facets[facetID].hits <= maxHitCount ) {
        return paginationText;
    }
    paginationText = '<div class="col-sm-6"><div id="top-pages" class="right-align"><nav class="pagination pagination-sm noprint"><ul class="pagination">';
    
    var offset = helimaData.results[facetID].offset;
    var results_per_page = maxHitCount;
    var total = helimaData.facets[facetID].hits;
    console.log("Gefunden total: " + total);
    
    var current_page = offset / results_per_page + 1;
    var last_page = Math.floor(total / results_per_page);
    if ( ( total % results_per_page ) > 0 ) {
        last_page = last_page + 1;
    }
    var last_page_offset = (last_page - 1) * results_per_page;
    var prev_page_offset = offset - results_per_page;
    var next_page_offset = offset + results_per_page;
    if ( prev_page_offset > 0 && last_page > 2 ) {
        paginationText += '<li class="page-item"><a href="javascript:getHeLiMaResult(' + facetID + ',' + prev_page_offset + ')" class="page-link">' + prevPageTextHeLiMa + '</a></li>';
    }
    if ( current_page > 1 ) {
        paginationText += '<li class="page-item"><a href="javascript:getHeLiMaResult(' + facetID + ',0)" class="page-link">1</a></li>';
        if ( current_page > 2 ) {
            paginationText += '<li class="page-item"><a href="#" style="pointer-events: none;cursor: default;" class="page-link">...</a></li>';
        }
        if ( current_page > 2 && current_page == last_page ) {
             paginationText += '<li class="page-item"><a href="javascript:getHeLiMaResult(' + facetID + ',' + prev_page_offset + ')" class="page-link">' + (last_page - 1) + '</a></li>';
        }
        paginationText += '<li class="page-item active"><a href="#" class="page-link">' + current_page + '</a></li>';
    }
    else {
        paginationText += '<li class="page-item active"><a href="#" class="page-link">' + current_page + '</a></li>';
        if ( last_page >= 2 ) {
            paginationText += '<li class="page-item"><a href="javascript:getHeLiMaResult(' + facetID + ',' + results_per_page + ')" class="page-link">2</a></li>';
        }
    }
    if ( ( ( current_page + 1 ) < last_page && current_page > 2 ) || ( last_page > 2 && current_page < 3 ) ) {
        paginationText += '<li class="page-item"><a href="#" style="pointer-events: none;cursor: default;" class="page-link">...</a></li>';
    }
    if ( last_page > 2 && current_page < last_page ) {
        paginationText += '<li class="page-item"><a href="javascript:getHeLiMaResult(' + facetID + ',' + last_page_offset + ')" class="page-link">' + last_page + '</a></li>&nbsp;';
        paginationText += '<li class="page-item"><a href="javascript:getHeLiMaResult(' + facetID + ',' + next_page_offset + ')" class="page-link">' + nextPageTextHeLiMa + '</a></li>';
    }
    
    paginationText += '<ul></nav></div></div>';
    
    return paginationText;
}
function showCatalogHitListHeLiMa() {
    if ( $("#userresults").css("display") == "none" ){
        $('#numresults').html(origResultHeaderHeLiMa);
        $('#userresults').toggle();
        $('#encyclopediaresults').toggle();
        $('#overdrive-results').toggle();
    }
}
