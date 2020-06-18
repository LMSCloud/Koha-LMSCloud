<script>
function accessDivibibResource(action,divibibID) {
    $.ajax({
        url: "/cgi-bin/koha/opac-divibib-access.pl",
        type: "POST",
        cache: false,
        data: { 'divibibID' : divibibID, 'action' : action },
        dataType: "json",
        success: function(data) {
            console.log(data);
            for (var i=0; i < data.titles.length; i++) {
                if ( data.titles[i].resultOk == 1 ) {
                    var win = window.open(data.titles[i].result.URL, '_blank');
                    win.focus();
                }
            }
        },
        error: function (data1, data2, data3) {
            console.log("Error accessing divibib item: ", data1, data2, data3);
        }
    });
}
function checkDivibibAvalability(idList) {
    var checkIDs;
    if ( $.isArray(idList) ) {
        checkIDs = idList.join(" ");
    }
    else {
        checkIDs = idList;
    }
    if ( idList.length == 0 ) {
        return;
    }
    $.ajax({
        url: "/cgi-bin/koha/opac-divibib-availability.pl",
        type: "POST",
        cache: false,
        data: { divibibID : checkIDs },
        dataType: "json",
        success: function(data) {
            for (var i=0; i < data.titles.length; i++) {
                var statusDisplay;
                if ( data.titles[i].resultOk == 1 ) {
                    var loggedIn=false;
                    [% IF Koha.Preference( 'opacuserlogin' ) == 1 %]
                        [% IF ( loggedinusername ) %]
                        loggedIn=true;
                        [% END %]
                    [% END %]
                    // check whether the item can be loaned
                    if ( data.titles[i].result.Available > 0 ) {
                        [% IF Koha.Preference( 'DivibibTitleAccessURL' ) %]
                        var accessURL = "[% Koha.Preference( 'DivibibTitleAccessURL' ) | html %]";
                        accessURL = accessURL.replace('{TITLEID}',data.titles[i].result.ItemId);
                        statusDisplay = '<a href="' 
                                        + accessURL 
                                        + '" alt="' 
                                        + _("Link to Onleihe") 
                                        + '" target="_blank"><b><span class="available">' 
                                        + _("Available as digital version. Click here for online lending.") 
                                        + '</span></b></a>';
                        [% ELSE %]
                        statusDisplay = '<b><span class="available">' 
                                        + _("Download available for logged in users.") 
                                        + '</span></b>';
                        [% END %]
                        if ( loggedIn ) {
                            statusDisplay = '<a href="#" onclick="accessDivibibResource(' 
                                            + "'loan','" + data.titles[i].result.ItemId 
                                            + "')"
                                            + '">'
                                            + '<b><span class="available">' 
                                            + _("Available for Download.") 
                                            + '</span></b></a>';
                        }
                    }
                    // check whether the item can be reserved
                    else if ( data.titles[i].result.Reservable > 0 ) {
                        // get available date
                        var availableFrom = data.titles[i].result.DateAvailable.split("-");
                        // split date fields to year month and day
                        // and insert the formatted javascriptdate
                        var formattedDate = availableFrom[2] + "." + availableFrom[1] + "." + availableFrom[0];
                        [% IF Koha.Preference( 'DivibibTitleAccessURL' ) %]
                        var accessURL = '[% Koha.Preference( 'DivibibTitleAccessURL' ) | html %]';
                        accessURL = accessURL.replace('{TITLEID}',data.titles[i].result.ItemId);
                        statusDisplay = '<a href="' 
                                        + accessURL 
                                        + '" alt="' 
                                        + _("Link to Onleihe") 
                                        + '" target="_blank"><b><span class="available">' 
                                        + _("Becomes available as digital version on ")
                                        + formattedDate 
                                        + '. '
                                        + _("Click here to make a reservation.") 
                                        + '</span></b></a>';
                        [% ELSE %]
                        statusDisplay = '<b>' 
                                        + _("Available on the ") 
                                        + formattedDate 
                                        + '. ' 
                                        + _("Reservable for logged in users.") 
                                        + '</b>';
                        [% END %]
                        if ( loggedIn ) {
                            statusDisplay = '<a href="#" onclick="accessDivibibResource(' 
                                            + "'reservation','" 
                                            + data.titles[i].result.ItemId 
                                            + "')" 
                                            + '">' 
                                            + '<b><span class="available">'
                                            + _("A copy is available on the ")
                                            + formattedDate 
                                            + ". "
                                            + _("Click here to place a hold.")
                                            + '</span></b></a>';
                        }
                    }
                    else {
                        statusDisplay = '<b>' 
                                        + _("Not available.") 
                                        + '</b>';
                    }
                }
                else {
                    statusDisplay = '<b>' 
                                    + _("Not in stock") 
                                    + '</b>';
                }
                $("#Onleihe-"+data.titles[i].result.ItemId).html(statusDisplay);
                // console.log(data.titles[i]);
            }
        },
        error: function (data1, data2, data3) {
            var statusDisplay = _("Error retrieving availability status from the elctronic library.");
            for (var i=0; i < this.data.divibibID.length; i++) {
                var id = this.data.divibibID[i];
                $("#Onleihe-"+id).html(statusDisplay);
            }
            console.log("Error retrieving divibib availability information: ", data1, data2, data3);
        }
    });
}
</script>