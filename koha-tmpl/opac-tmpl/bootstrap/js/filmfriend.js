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

var filmfriendData = new Object;
var origResultHeaderFilmfriend;
var prevPageTextFilmfriend;
var nextPageTextFilmfriend;
var maxHitCountFilmfriend;
var targetLinkFilmfriend = "_blank";
var readMoreFilmfriend = "Read more &raquo;";

function getFilmfriendFacet(query_desc,maxHitCount,prevPageText,nextPageText,readMore) {
    if (!origResultHeaderFilmfriend) {
        origResultHeaderFilmfriend = $('#numresults').html();
    }
    prevPageTextFilmfriend = prevPageText;
    nextPageTextFilmfriend = nextPageText;
    readMoreFilmfriend     = readMore;
    maxHitCountFilmfriend  = maxHitCount;
    $.ajax({
    url: "/cgi-bin/koha/opac-filmfriend.pl",
        type: "POST",
        cache: false,
        data: { 'search' : query_desc, 'maxcount' : 0 },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result.length > 0 ) {
                showFilmfriendFacetEntries(data.result,query_desc);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading Filmfriend hits:", data1, data2, data3);
        }
   });
}
function getFilmfriendResult(facetID, offset) {
    var query_desc = filmfriendData['query'];
    var collection = filmfriendData['results'][facetID].searchType;
    $.ajax({
    url: "/cgi-bin/koha/opac-filmfriend.pl",
        type: "POST",
        cache: false,
        data: { 'search' : query_desc, 'maxcount' : maxHitCountFilmfriend, 'offset' : offset, 'collection' : collection  },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result.length > 0 ) {
                filmfriendData['results'][facetID] = data.result[0];
                setFilmfriendCollectionName(filmfriendData['results'],facetID);
                showFilmfriendResult(facetID);
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error reading Filmfriend hits:", data1, data2, data3);
        }
   });
}
function showFilmfriendFacetEntries(facetData,query) {
    if ( facetData.length > 0 ) {
        var listElement = document.createElement("ul");
        var foundHits = 0;
        for (var i=0; i<facetData.length; i++) {
            if ( facetData[i].searchType ) {
                var facetElement = document.createElement("li");
                var spanElement  = document.createElement("span");
                spanElement.setAttribute('class','facet-label');
                var hrefElement  = document.createElement("a");
                var facetElementName = setFilmfriendCollectionName(facetData,i);
                hrefElement.setAttribute('href','javascript:getFilmfriendResult('+i+',0)');
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
        $('#filmfriend-facet ul').html(listElement.innerHTML);
        $('#filmfriend-count').text(foundHits);
        $('#filmfriend-facet').css("display","block");
        $('#encyclopedia-facets').css("display","block");
        
        filmfriendData['results'] = facetData;
        filmfriendData['query'] = query;
    }
}

function setFilmfriendCollectionName(facetData, i)  {
    var facetElementName;
    if ( facetData[i].searchType == "Movie" ) {
        facetElementName = "Filme";
    }
    else if ( facetData[i].searchType == "Episode" ) {
        facetElementName = "Serien-Episoden";
    }
    else if ( facetData[i].searchType == "Video" ) {
        facetElementName = "Filme und Serien";
    }
    else if ( facetData[i].searchType == "Season" ) {
        facetElementName = "Serien-Staffel";
    }
    else if ( facetData[i].searchType == "Series" ) {
        facetElementName = "Serien";
    }
    else if ( facetData[i].searchType == "Person" ) {
        facetElementName = "Personen";
    }
    else if ( facetData[i].searchType == "Collection" ) {
        facetElementName = "Sammlungen";
    }
    facetData[i]['name'] = facetElementName;
    
    return facetElementName;
}

function showFilmfriendResult(facetID) {
    var pagination = getPagination(facetID, maxHitCountFilmfriend);
    var content = '';

    for (var i=0; i<filmfriendData.results[facetID].hitList.length;i++) {
        if ( filmfriendData.results[facetID].hitList[i].kind == 'Person' ) {
            content += generateFilmfriendEntryPerson(facetID,i);
        } else {
            content += generateFilmfriendEntryMovie(facetID,i);
        }
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
    $('.encyclopediasource').html(filmfriendData.results[facetID].name);
    
    $('.encyclopediaprovider').html(' <a href="' + filmfriendData.results[facetID].searchAtFilmFriend + '"  target="' + targetLinkFilmfriend + '">' + 'filmfriend</a> ' );
    $('.encyclopediasearchhitcount').html(' ' + filmfriendData.results[facetID].numFound + ' ');
    $('#numresults').html($('#encyclopedianumresults').html());
    $('#showCatalogHitList').attr("href", "javascript:showCatalogHitListFilmfriend()");
    
    truncate_text("#encyclopediahits");
}
function getPagination(facetID, maxHitCount) {
    var paginationText = '';
    if ( filmfriendData.results[facetID].numFound <= maxHitCount ) {
        return paginationText;
    }
    paginationText = '<div class="span6"><div id="top-pages" class="right-align"><div class="pagination pagination-small noprint"><ul>';
    
    var offset = filmfriendData.results[facetID].start;
    var results_per_page = maxHitCount;
    var total = filmfriendData.results[facetID].numFound;
    
    var current_page = offset / results_per_page + 1;
    var last_page = Math.floor(total / results_per_page);
    if ( ( total % results_per_page ) > 0 ) {
        last_page = last_page + 1;
    }
    var last_page_offset = (last_page - 1) * results_per_page;
    var prev_page_offset = offset - results_per_page;
    var next_page_offset = offset + results_per_page;
    if ( prev_page_offset > 0 && last_page > 2 ) {
        paginationText += '<li><a href="javascript:getFilmfriendResult(' + facetID + ',' + prev_page_offset + ')">' + prevPageTextFilmfriend + '</a></li>';
    }
    if ( current_page > 1 ) {
        paginationText += '<li><a href="javascript:getFilmfriendResult(' + facetID + ',0)">1</a></li>';
        if ( current_page > 2 ) {
            paginationText += '<li><a href="#" style="pointer-events: none;cursor: default;">...</a></li>';
        }
        if ( current_page > 2 && current_page == last_page ) {
             paginationText += '<li><a href="javascript:getFilmfriendResult(' + facetID + ',' + prev_page_offset + ')">' + (last_page - 1) + '</a></li>';
        }
        paginationText += '<li class="active"><a href="#">' + current_page + '</a></li>';
    }
    else {
        paginationText += '<li class="active"><a href="#">' + current_page + '</a></li>';
        if ( last_page >= 2 ) {
            paginationText += '<li><a href="javascript:getFilmfriendResult(' + facetID + ',' + results_per_page + ')">2</a></li>';
        }
    }
    if ( ( ( current_page + 1 ) < last_page && current_page > 2 ) || ( last_page > 2 && current_page < 3 ) ) {
        paginationText += '<li><a href="#" style="pointer-events: none;cursor: default;">...</a></li>';
    }
    if ( last_page > 2 && current_page < last_page ) {
        paginationText += '<li><a href="javascript:getFilmfriendResult(' + facetID + ',' + last_page_offset + ')">' + last_page + '</a></li>&nbsp;';
        paginationText += '<li><a href="javascript:getFilmfriendResult(' + facetID + ',' + next_page_offset + ')">' + nextPageTextFilmfriend + '</a></li>';
    }
    
    paginationText += '<ul></div></div></div>';
    
    return paginationText;
}
function showCatalogHitListFilmfriend() {
    if ( $("#userresults").css("display") == "none" ){
        $('#numresults').html(origResultHeaderFilmfriend);
        $('#userresults').toggle();
        $('#encyclopediaresults').toggle();
    }
}
function generateFilmfriendEntryPerson(facetID,entryID) {
    var name = filmfriendData.results[facetID].hitList[entryID].firstName + " " + filmfriendData.results[facetID].hitList[entryID].lastName;

    var rowElement = document.createElement("tr");
    var colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    rowElement.appendChild(colElement);
    
    colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    var txtElement = document.createElement("a");
    txtElement.setAttribute('class','title');
    txtElement.setAttribute('target',targetLinkFilmfriend);
    txtElement.setAttribute('href',filmfriendData.results[facetID].hitList[entryID].filmfriendLink);
    txtElement.textContent = name;
    colElement.appendChild(txtElement);
    
    if ( filmfriendData.results[facetID].hitList[entryID].description ) {
        txtElement = document.createElement("span");
        txtElement.setAttribute('class','results_summary summary description truncable-txt');
        txtElement.setAttribute('style','font-size: 100%');
        txtElement.innerHTML = filmfriendData.results[facetID].hitList[entryID].description;
        colElement.appendChild(txtElement);
    }
    rowElement.appendChild(colElement);
    return '<tr>' + rowElement.innerHTML + '</tr>';
}
function generateFilmfriendEntryMovie(facetID,entryID) {
    var rowElement = document.createElement("tr");
    var colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    var divElement = document.createElement("div");
    divElement.setAttribute('class','coverimages');
    if ( filmfriendData.results[facetID].hitList[entryID].thumbnail ) {
        var linkElement = document.createElement("a");
        linkElement.setAttribute('class','p1');
        linkElement.setAttribute('target',targetLinkFilmfriend);
        linkElement.setAttribute('href',filmfriendData.results[facetID].hitList[entryID].filmfriendLink);
        linkElement.setAttribute('alt',filmfriendData.results[facetID].hitList[entryID].title);
    
        var imageElement = document.createElement("img");
        imageElement.setAttribute('width','170');
        imageElement.setAttribute('src',filmfriendData.results[facetID].hitList[entryID].thumbnail);
        linkElement.appendChild(imageElement);
        
        divElement.appendChild(linkElement);
    }
    colElement.appendChild(divElement);
    rowElement.appendChild(colElement);
    
    colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    var txtElement = document.createElement("a");
    txtElement.setAttribute('class','title');
    txtElement.setAttribute('target',targetLinkFilmfriend);
    txtElement.setAttribute('href',filmfriendData.results[facetID].hitList[entryID].filmfriendLink);
    txtElement.textContent = filmfriendData.results[facetID].hitList[entryID].title;
    colElement.appendChild(txtElement);
    if (   ( filmfriendData.results[facetID].hitList[entryID].regie && filmfriendData.results[facetID].hitList[entryID].regie.length > 0) 
        || ( filmfriendData.results[facetID].hitList[entryID].actors && filmfriendData.results[facetID].hitList[entryID].actors.length > 0) 
        ) 
    {
        var persons = document.createElement("p");
	persons.setAttribute('class','persons');
        persons.appendChild(document.createTextNode("von/mit "));
        var x = 0;
        if ( filmfriendData.results[facetID].hitList[entryID].regie ) {
            for (var s=0;s<filmfriendData.results[facetID].hitList[entryID].regie.length;s++) {
                if ( x++ > 0 ) {
                    var sep = document.createElement("span");
                    sep.appendChild(document.createTextNode(" | "));
                    sep.setAttribute('class','separator');
                    persons.appendChild(sep);
                }
                var personNameSpan = document.createElement("span");
                personNameSpan.setAttribute('class','regie');
                var personNameLink = document.createElement("a");
                personNameLink.setAttribute('href',filmfriendData.results[facetID].hitList[entryID].regie[s].filmfriendLink);
                personNameLink.setAttribute('target',targetLinkFilmfriend);
                personNameLink.textContent = filmfriendData.results[facetID].hitList[entryID].regie[s].person.lastName + ", " + filmfriendData.results[facetID].hitList[entryID].regie[s].person.firstName;
                personNameSpan.appendChild(personNameLink);
                persons.appendChild(personNameSpan);
            }
        }
        if ( filmfriendData.results[facetID].hitList[entryID].actors ) {
            for (var s=0;s<filmfriendData.results[facetID].hitList[entryID].actors.length;s++) {
                if ( x++ > 0 ) {
                    var sep = document.createElement("span");
                    sep.appendChild(document.createTextNode(" | "));
                    sep.setAttribute('class','separator');
                    persons.appendChild(sep);
                }
                var personNameSpan = document.createElement("span");
                personNameSpan.setAttribute('class','actor');
                var personNameLink = document.createElement("a");
                personNameLink.setAttribute('href',filmfriendData.results[facetID].hitList[entryID].actors[s].filmfriendLink);
                personNameLink.setAttribute('target',targetLinkFilmfriend);
                personNameLink.textContent = filmfriendData.results[facetID].hitList[entryID].actors[s].person.lastName + ", " + filmfriendData.results[facetID].hitList[entryID].actors[s].person.firstName;
                personNameSpan.appendChild(personNameLink);
                persons.appendChild(personNameSpan);
            }
        }
        if ( x > 0 ) {
            colElement.appendChild(persons);
        }
    }
    var additionalInfo = document.createElement("p");
    var addCnt = 0;
    if ( filmfriendData.results[facetID].hitList[entryID].genre && filmfriendData.results[facetID].hitList[entryID].genre.length > 0 ) {
        if ( addCnt > 0 ) {
            var sep = document.createElement("span");
            sep.appendChild(document.createTextNode(" | "));
            sep.setAttribute('class','separator');
            additionalInfo.appendChild(sep);
        }
        var elList = document.createElement("span");
        elList.setAttribute('class','genres');
        for (var s=0;s<filmfriendData.results[facetID].hitList[entryID].genre.length;s++) {
            var elAdd = document.createElement("span");
            elAdd.setAttribute('class','genre');
            elAdd.appendChild(document.createTextNode(filmfriendData.results[facetID].hitList[entryID].genre[s]));
            if ( s > 0 ) {
                elList.appendChild(document.createTextNode(", "));
            }
            elList.appendChild(elAdd);
        }
        additionalInfo.appendChild(elList);
        addCnt++;
    }
    if ( filmfriendData.results[facetID].hitList[entryID].releaseYear ) {
        if ( addCnt > 0 ) {
            var sep = document.createElement("span");
            sep.appendChild(document.createTextNode(" | "));
            sep.setAttribute('class','separator');
            additionalInfo.appendChild(sep);
        }
        var elAdd = document.createElement("span");
        elAdd.setAttribute('class','year');
        elAdd.appendChild(document.createTextNode(filmfriendData.results[facetID].hitList[entryID].releaseYear));
        additionalInfo.appendChild(elAdd);
        addCnt++;
    }
    if ( filmfriendData.results[facetID].hitList[entryID].production && filmfriendData.results[facetID].hitList[entryID].production.length > 0 ) {
        if ( addCnt > 0 ) {
            var sep = document.createElement("span");
            sep.appendChild(document.createTextNode(" | "));
            sep.setAttribute('class','separator');
            additionalInfo.appendChild(sep);
        }
        var elList = document.createElement("span");
        elList.setAttribute('class','countries');
        for (var s=0;s<filmfriendData.results[facetID].hitList[entryID].production.length;s++) {
            var elAdd = document.createElement("span");
            elAdd.setAttribute('class','country');
            elAdd.appendChild(document.createTextNode(filmfriendData.results[facetID].hitList[entryID].production[s]));
            if ( s > 0 ) {
                elList.appendChild(document.createTextNode(", "));
            }
            elList.appendChild(elAdd);
        }
        additionalInfo.appendChild(elList);
        addCnt++;
    }
    if ( filmfriendData.results[facetID].hitList[entryID].fsk ) {
        if ( addCnt > 0 ) {
            var sep = document.createElement("span");
            sep.appendChild(document.createTextNode(" | "));
            sep.setAttribute('class','separator');
            additionalInfo.appendChild(sep);
        }
        var elAdd = document.createElement("span");
        elAdd.setAttribute('class','fsk');
        elAdd.appendChild(document.createTextNode("FSK " + filmfriendData.results[facetID].hitList[entryID].fsk));
        additionalInfo.appendChild(elAdd);
        addCnt++;
    }
    if ( filmfriendData.results[facetID].hitList[entryID].duration ) {
        if ( addCnt > 0 ) {
            var sep = document.createElement("span");
            sep.appendChild(document.createTextNode(" | "));
            sep.setAttribute('class','separator');
            additionalInfo.appendChild(sep);
        }
        var elAdd = document.createElement("span");
        elAdd.setAttribute('class','duration');
        elAdd.appendChild(document.createTextNode(filmfriendData.results[facetID].hitList[entryID].duration));
        additionalInfo.appendChild(elAdd);
        addCnt++;
    }
    if ( filmfriendData.results[facetID].hitList[entryID].audio && filmfriendData.results[facetID].hitList[entryID].audio.length > 0 ) {
        if ( addCnt > 0 ) {
            var sep = document.createElement("span");
            sep.appendChild(document.createTextNode(" | "));
            sep.setAttribute('class','separator');
            additionalInfo.appendChild(sep);
        }
        var elList = document.createElement("span");
        elList.setAttribute('class','languages');
        for (var s=0;s<filmfriendData.results[facetID].hitList[entryID].audio.length;s++) {
            var elAdd = document.createElement("span");
            elAdd.setAttribute('class','language');
            elAdd.appendChild(document.createTextNode(filmfriendData.results[facetID].hitList[entryID].audio[s]));
            if ( s > 0 ) {
                elList.appendChild(document.createTextNode(", "));
            } else {
                elList.appendChild(document.createTextNode("Sprache: "));
            }
            elList.appendChild(elAdd);
        }
        additionalInfo.appendChild(elList);
        addCnt++;
    }
    if ( filmfriendData.results[facetID].hitList[entryID].subtitle && filmfriendData.results[facetID].hitList[entryID].subtitle.length > 0 ) {
        if ( addCnt > 0 ) {
            var sep = document.createElement("span");
            sep.appendChild(document.createTextNode(" | "));
            sep.setAttribute('class','separator');
            additionalInfo.appendChild(sep);
        }
        var elList = document.createElement("span");
        elList.setAttribute('class','subtitles');
        for (var s=0;s<filmfriendData.results[facetID].hitList[entryID].subtitle.length;s++) {
            var elAdd = document.createElement("span");
            elAdd.setAttribute('class','subtitle');
            elAdd.appendChild(document.createTextNode(filmfriendData.results[facetID].hitList[entryID].subtitle[s]));
            if ( s > 0 ) {
                elList.appendChild(document.createTextNode(", "));
            } else {
                elList.appendChild(document.createTextNode("Untertitel: "));
            }
            elList.appendChild(elAdd);
        }
        additionalInfo.appendChild(elList);
        addCnt++;
    }
    if ( addCnt > 0 ) {
        colElement.appendChild(additionalInfo);
    }
    
    if ( filmfriendData.results[facetID].hitList[entryID].synopsis ) {
        txtElement = document.createElement("span");
        txtElement.setAttribute('class','results_summary summary truncable-txt');
        txtElement.setAttribute('style','font-size: 100%');
        txtElement.innerHTML = filmfriendData.results[facetID].hitList[entryID].synopsis.replace(/(?:\r\n|\r|\n)+/g, '<br>') + '<a href="javascript:void(0)" class="truncable-txt-readmore">' + readMoreFilmfriend + '</a>';
        colElement.appendChild(txtElement);
        
    }
    rowElement.appendChild(colElement);
    return '<tr>' + rowElement.innerHTML + '</tr>';
}
