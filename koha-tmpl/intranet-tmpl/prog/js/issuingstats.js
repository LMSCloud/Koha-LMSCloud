// This file is part of Koha.
//
// Copyright 2020 LMSCloud GmbH
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


/*
    Retrieve issuing stats for biblionumbers for a configurable number
    of yours back from now.
    Replaces the text within an element of class "issuingstats".
    Expects an attribute "data-itemnumbers" with the element that
    contains the itemnumbers(separated by pipe character '|') for which 
    the issuing stats data is been calculated and displayed.
    The displayed data looks like the following:
    textEntry: xx(textTotal), y1(year), y2 (year-1), ..., yn (year-yearscount+1)
*/
function getIssuingStatsForBiblios(biblionumbers,yearscount,ignoredItypes,textEntry,textTotal) {
    $.ajax({
        url: "/cgi-bin/koha/svc/statistics/checkouts_per_year",
        dataType: "json",
        type: 'POST',
        data: {
            biblionumber : biblionumbers.join(","),
            ignoreItypes : ignoredItypes.join(","),
            years : yearscount
        },
        success: function(data) {
            var itemstats = [];
            for (var i=0; i < data.length; i++) {
                for (var k=0; k < data[i].items.length; k++) {
                    itemstats[data[i].items[k].itemnumber] = data[i].items[k];
                }
            }
            // console.log(itemstats);
            $('.issuingstats').each( function( index ) {
                var itemnumbers = $(this).attr("data-itemnumbers").split('|');
                var combinedstats;
                var sumIssues = 0;
                var found = 0;
                for (var i=0; i<itemnumbers.length; i++) {
                    if ( itemstats[itemnumbers[i]] ) {
                        found++;
                        sumIssues += parseInt(itemstats[itemnumbers[i]].sumIssues);
                        if ( i == 0 ) {
                            combinedstats = itemstats[itemnumbers[i]].issuestats;
                        }
                        else {
                            for (var k=0; k<itemstats[itemnumbers[i]].issuestats.length; k++) {
                                var year = "" + itemstats[itemnumbers[i]].issuestats[k].year;
                                var sumIssuesYear = parseInt(itemstats[itemnumbers[i]].issuestats[k].sumIssues);
                                var statfound = false;
                                for (stat of combinedstats) {
                                    if ( stat.year == year ) {
                                        stat.sumIssues += sumIssuesYear;
                                        statfound = true;
                                    }
                                }
                                if ( !statfound ) {
                                    combinedstats.push(itemstats[itemnumbers[i]].issuestats[k]);
                                }
                            }
                        }
                    }
                }
                if ( found > 0 ) {
                    combinedstats = sortItemStatsByYear(combinedstats,"year");
                    var displayText = textEntry + ": " + sumIssues + " (" + textTotal + ")";
                    for (stat of combinedstats) {
                        displayText += ", " + stat.sumIssues + " (" + stat.year + ")";
                    }
                    $(this).text(displayText);
                    
                }
                // console.log(combinedstats);
            });
        }
    });
}

function sortItemStatsByYear(array, key) {
    return array.sort(function(a, b) {
        var x = a[key];
        var y = b[key];

        if (typeof x == "string")
        {
            x = (""+x).toLowerCase(); 
        }
        if (typeof y == "string")
        {
            y = (""+y).toLowerCase();
        }

        return ((x < y) ? 1 : ((x > y) ? -1 : 0));
    });
}
