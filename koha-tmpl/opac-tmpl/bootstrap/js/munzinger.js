var munzingerData;

function getMunzingerFacet(query_desc) {
    $.ajax({
    url: "/cgi-bin/koha/opac-munzinger.pl",
        type: "POST",
        cache: false,
        data: { 'search' : query_desc },
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
function showMunzingerFacetEntries(facetData,query) {
    var listElement = document.createElement("ul");
    for (var i=0; i<facetData.categorycount; i++) {
        var facetElement = document.createElement("li");
        var spanElement  = document.createElement("span");
        spanElement.setAttribute('class','facet-label');
        var hrefElement  = document.createElement("a");
        hrefElement.setAttribute('href','javascript:showMunzingerResult('+i+')');
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
    
    munzingerData = facetData;
    munzingerData['query'] = query;
}
function retrieveAdditionalMunzingerData(facetID) {
    $.ajax({
    url: "/cgi-bin/koha/opac-munzinger.pl",
        type: "POST",
        cache: false,
        data: { 'search' : munzingerData['query'], 'publication' : munzingerData.categories[facetID].name, 'maxcount' : munzingerData.categories[facetID].count },
        dataType: "json",
        success: function(data) {
            if ( data && data.result && data.result.categorycount && data.result.categorycount > 0 ) {
                var facetData = data.result;
                for (var i=0; i<facetData.categorycount; i++) {
                    if ( munzingerData.categories[facetID].name == facetData.categories[i].name ) {
                        munzingerData.categories[facetID].hits = facetData.categories[i].hits;
                        showMunzingerResult(facetID, 1);
                    }
                }
            }
        }
   });
}
function showMunzingerResult(facetID, callOpt) {
    callOpt = (typeof callOpt === 'undefined') ? '0' : callOpt;
    
    var content = '';
    for (var i=0; i<munzingerData.categories[facetID].hits.length;i++) {
        content += generateMunzingerEntry(facetID,i);
    }
    if ( !("catalogResultHeaderText" in munzingerData) ) {
        munzingerData['catalogResultHeaderText'] = $('#numresults').html();
    }
    if ( $("#userresults").css("display") != "none" ){
        $('#encyclopediaresults').toggle();
        $('#userresults').toggle();
    }
    $('#encyclopediahits').html(content);
    
    if ( munzingerData.categories[facetID].name == 'KLG' ) {
        $('.encyclopediasource').html('Kritisches Lexikon zur deutschsprachigen Gegenwartsliteratur');
    }
    else if ( munzingerData.categories[facetID].name == 'KLfG' ) {
        $('.encyclopediasource').html('Kritisches Lexikon zur fremdsprachigen Gegenwartsliteratur');
    }
    else if ( munzingerData.categories[facetID].name == 'KDG' ) {
        $('.encyclopediasource').html('Komponisten der Gegenwart');
    }
    else {
        $('.encyclopediasource').html(munzingerData.categories[facetID].name);
    }
    $('.encyclopediaprovider').html('<a href="' + munzingerData.searchmunzinger + '" target="_blank">' + 'Munzinger</a>' );
    $('.encyclopediasearchhitcount').html(munzingerData.categories[facetID].count);
    $('#numresults').html($('#encyclopedianumresults').html());
    
    if ( callOpt != 1 && munzingerData.categories[facetID].hits.length < munzingerData.categories[facetID].count ) {
        retrieveAdditionalMunzingerData(facetID);
    }
}
function showCatalogHitList() {
    if ( $("#userresults").css("display") == "none" ){
        $('#numresults').html(munzingerData['catalogResultHeaderText']);
        $('#userresults').toggle();
        $('#encyclopediaresults').toggle();
    }
}
function generateMunzingerEntry(facetID,entryID) {
    var rowElement = document.createElement("tr");
    var colElement = document.createElement("td");
    colElement.setAttribute('class','bibliocol');
    var txtElement = document.createElement("a");
    txtElement.setAttribute('class','title');
    txtElement.setAttribute('target','_blank');
    txtElement.setAttribute('href',munzingerData.categories[facetID].hits[entryID].link);
    txtElement.textContent = munzingerData.categories[facetID].hits[entryID].title;
    colElement.appendChild(txtElement);
    txtElement = document.createElement("span");
    txtElement.setAttribute('class','results_summary summary');
    txtElement.innerHTML = munzingerData.categories[facetID].hits[entryID].text;
    colElement.appendChild(txtElement);
    rowElement.appendChild(colElement);
    return '<tr>' + rowElement.innerHTML + '</tr>';
}