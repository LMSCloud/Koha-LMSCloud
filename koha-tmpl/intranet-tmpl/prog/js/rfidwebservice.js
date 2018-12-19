if ( RFIDWebService === undefined ) 
var RFIDWebService = {
    
    messageServiceProvider: {},
    
    checkoutBlockingSelector: '#circ_impossible,#circ_needsconfirmation',
    
    checkinBlockingSelector: '.problem,.error,.alert,.audio-alert-warning,.audio-aler-action',
    
    vendorName: '',
    
    // Init function if the RFIDWebService
    // The function has to handle different Scenarios
    // 1) There is no rfid tag reader
    //    In thise case we want to check only once per session window 
    //    whether an RFID tag reader is available using the ServiceInfo call.
    //    If the call returns no information, than RFID functions need to
    //    be disabled at all
    // 2) There is a local RFID service available, but the ServiceInfo returns
    //    an error. The Reader might not be connected or is disfunctional.
    //    In that case we want to support users finding the problem, but not
    //    making the reader functions avalaible for checkin/checkout.
    //    We can support users by showing a related message. It should be also
    //    supported to do a reinitialization of the RFIDWebService. 
    // 3) The RFID reader service is available and fully functional.
    //    In that case we want to do the initialization only once.
    // The URL of the RFID reader web interface will be stored in the Browser
    // sessionStorage of the Browser tab window. That way it's possible to support
    // working with multiple windows in different stages.
    // The initialization result will be also stored with the sessionStorage and
    // will be checked with each call of the Koha staff interface.
    // A change of the configured URL will result in an re-initialization.
    
    Init: function ( rfidWebServiceURL, rfidWebServiceMessageProvider, checkoutBlocker, checkinBlocker ) {
        
        // set the message provider
        this.messageServiceProvider = rfidWebServiceMessageProvider;
        
        if ( checkoutBlocker && checkoutBlocker.length > 0 ) {
            this.checkoutBlockingSelector = checkoutBlocker;
        }
        
        if ( checkinBlocker && checkinBlocker.length > 0 ) {
            this.checkinBlockingSelector = checkinBlocker;
        }
        
        // check the stored session URL
        var storeURL = window.sessionStorage.getItem('RFIDWebServiceURL');
        var reInit = false;
        
        // check whether the URL has changed or whether we need to initialize a new
        // session
        if ( !storeURL || storeURL != rfidWebServiceURL ) {
            window.sessionStorage.setItem('RFIDWebServiceURL',rfidWebServiceURL);
            reInit = true;
        }
        
        // check whether the service was already initialized
        // if not, we assume it's a new session
        var initialized = window.sessionStorage.getItem('RFIDWebServiceInitialized');
        if ( !initialized ) {
            reInit = true;
        }
        
        // retrieve the status of the last initialization
        var status = window.sessionStorage.getItem('RFIDWebServiceStatus');
        
        // if the reader was already initialized we enable RFID functionality
        if ( status && (status == "ok" || status == "failed") ) {
            
            // add the top level RFID menu
            this.ActivateTopLevelMenuRFID(true);
            
            // if the reader is fully functional, enable checkin/checkout functions
            if ( status == "ok" ) {
                this.EnableRfidCheckinCheckout();
            }
        }
        
        // we may need to (re-)initialize the service
        if ( reInit ) {
            this.InitializeRFIDWebService(rfidWebServiceURL);
        }
    },
    
    // Initialize the service using the passed RFID web service URL using the
    // command ServiceInfo
    // The functions sets the two sessionStorage parameters:
    // RFIDWebServiceInitialized: The service was already initalized during the windows session.
    //                            Can be true or false.
    // RFIDWebServiceStatus: The result of initialization with the following possible values
    //                       'ok': The reader is available and fully functional.
    //                       'failed': The reader service is available but signaled an error.
    //                                 The reader might be not connected or disfunctional.
    //                       'no': No reader available at all.
    InitializeRFIDWebService: function ( rfidWebServiceURL ) {
        
        var checkServiceAvailabilityURL = rfidWebServiceURL;
        
        // Reset the status to 'no'
        window.sessionStorage.setItem('RFIDWebServiceStatus','no');
        
        // Set the initialization mark independent of the result
        window.sessionStorage.setItem('RFIDWebServiceInitialized',true);
        
        // If not URL was passed, read it from the sessionStorage.
        // Might be useful for a later re-initialization if the reader is now connected.
        if ( ! checkServiceAvailabilityURL ) {
            checkServiceAvailabilityURL = window.sessionStorage.getItem('RFIDWebServiceURL');
        }
        
        // If we have a URL we can now call the service
        if ( checkServiceAvailabilityURL ) {
            checkServiceAvailabilityURL.replace(/\/$/, "");
            checkServiceAvailabilityURL += "/ServiceInfo";
            
            // Do the ServiceInfo ajax call
            $.ajax({
                type: 'GET',
                url: checkServiceAvailabilityURL,
                dataType: "json",
                success: function (data) { 
                    if ( data ) {
                        // We need to check, whether we had a previous status in the case it
                        // is a reinitialization
                        var previousStatus = window.sessionStorage.getItem('RFIDWebServiceStatus');
                        var showError = false;
                        if ( data.requestSuccess && data.requestSuccess == true ) {
                            // the reader is available and functional
                            window.sessionStorage.setItem('RFIDWebServiceStatus','ok');
                            
                            // Enable RFID functions
                            RFIDWebService.EnableRfidCheckinCheckout();
                        }
                        else {
                            showError = true;
                            window.sessionStorage.setItem('RFIDWebServiceStatus','failed');
                        }
                        if ( data.responseData && data.responseData.vendorName ) {
                            RFIDWebService.vendorName = data.responseData.vendorName;
                        }
                        
                        // Store the result of the last ServiceInfo call in the sessionStorage 
                        window.sessionStorage.setItem('RFIDWebServiceStatusInfo',JSON.stringify(data));
                        
                        // Activate the RFID menu if it was not already initialized
                        if ( !previousStatus || previousStatus == 'no' ) {
                            RFIDWebService.ActivateTopLevelMenuRFID(true);
                        }
                        
                        if ( showError && data.errorCode && data.errorMessage ) {
                            RFIDWebService.DisplayRFIDServiceErrorMessage(data.errorCode,data.errorMessage);
                            Console.log("RFIDWebService ServiceInfo failed");
                        }
                    }
               },
                error: function (data) {
                    // error, no service available
                    window.sessionStorage.setItem('RFIDWebServiceStatus','no');
                    // disable the top level menu if it is activated currently
                    RFIDWebService.DisableTopLevelMenuRFID();
               }
            });
        }
    },
    
    // Activation and deactivation of the RFID top level menu entries
    ActivateTopLevelMenuRFID: function (enableRFID) {
        
        var menuNames = {
                            topLevelMenuEntry:      "RFID",
                            menuEntryServiceInfo:   "RFID-Service Information",
                            menuEntryServiceTools:  "RFID-Tools"
                        };
        if ( this.messageServiceProvider ) {
            menuNames = this.messageServiceProvider.GetRFIDMenuNames();
        }
        
        $('#toplevelmenu').children().last().before(
            $('<li>').attr("id","rfidWebServiceMenue").attr("class","dropdown").append(
                $('<a>').attr("class","dropdown-toggle")
                    .attr("href","/cgi-bin/koha/tools/rfid-webservice.pl")
                    .attr("data-toggle","dropdown")
                    .append(
                        menuNames.topLevelMenuEntry,
                        $('<b>').attr("class","caret")
                ),
                $('<ul>').attr("class","dropdown-menu dropdown-menu-right").append(
                    $('<li>').append(
                        $('<a>')
                            .bind( "click", function() {
                                RFIDWebService.DisplayRFIDServiceStatus();
                            })
                            .append(menuNames.menuEntryServiceInfo)
                    ),
                    $('<li>').append(
                        $('<a>')
                            .bind( "click", function() {
                                alert("Coming soon!");
                            })
                            .append(menuNames.menuEntryServiceTools)
                    )
                )
            )
        );
        if (! enableRFID) {
            this.DisableTopLevelMenuRFID();
        }
    },
    DisableTopLevelMenuRFID: function () {
        $('#rfidWebServiceMenu' ).hide();
    },
    
    
    // Activation of the RFID actions with checkin/checkout functions
    EnableRfidCheckinCheckout: function () {
        var enabled = window.sessionStorage.getItem('RFIDWebServiceStatus');
        if ( enabled && enabled == 'ok' ) {
            
            // enable RFID checkout
            if ( $('#circ_circulation #circ_circulation_issue #barcode').length ) {
                
                // check whether there was a previous checkout
                this.CheckLastCheckoutAndContinue();
                
                // Setup RFID reading on barcode field
                this.SetupRFIDServerCheckout();
            }
            
            // enable RFID checkin
            if ( $('#circ_returns #checkin-form #barcode').length ) {
                
                // check whether there was a previous checkout
                this.CheckLastCheckinAndContinue();
                
                // Setup RFID reading on barcode field
                this.SetupRFIDServerCheckin();
            }
            
            // active findborrower field in header search
            var findborrower = $('#patronsearch #findborrower');
            if ( findborrower.length ) {
                findborrower.keydown( function( event ) {
                    if ( event.which == 32 ) {
                        var barvalue = $('#patronsearch #findborrower').val();
                        if ( barvalue == "" || barvalue == " " ) {
                            event.preventDefault();
                            RFIDWebService.ReadTagsAndStartCheckout("borrower");
                        }
                    }
                });
            }
            
            // active listener on return barcode in header search
            var returnBarcodeField = $('#checkin_search #ret_barcode');
            if ( returnBarcodeField.length ) {
                returnBarcodeField.keydown( function( event ) {
                    if ( event.which == 32 ) {
                        var barvalue = $('#checkin_search #ret_barcode').val();
                        if ( barvalue == "" || barvalue == " " ) {
                            event.preventDefault();
                            RFIDWebService.ReadTagsAndStartCheckout("checkinstart");
                        }
                    }
                });
            }
        }
    },
    
    // The functions checks, whether there was a previous checkout
    // If so, the item tag needs to be unlocked
    CheckLastCheckoutAndContinue: function () {
        var barcode = window.sessionStorage.getItem('RFIDWebServiceCheckoutItem');
        
        if ( barcode ) {
            if ( $('.lastcheckoutbarcode').length > 0 ) {
                var barcodes = $('.lastcheckoutbarcode').map(function() { return $(this).text(); }).get();
                for (var i=0; i < barcodes.length; i++) {
                    if ( barcode == barcodes[i] ) {
                        RFIDWebService.UnlockItemBarcode(barcode);
                    }
                }
            }
        }
    },
    
    // The functions checks, whether there was a previous checkout
    // If so, the item tag needs to be unlocked
    CheckLastCheckinAndContinue: function () {
        var barcode = window.sessionStorage.getItem('RFIDWebServiceCheckinItem');
        
        if ( barcode ) {
            if ( $('.lastcheckinbarcode').length > 0 ) {
                var barcodes = $('.lastcheckinbarcode').map(function() { return $(this).text(); }).get();
                for (var i=0; i < barcodes.length; i++) {
                    console.log("Compare return item " + barcode + " with returned barcode " + barcodes[i].trim());
                    if ( barcode == barcodes[i].trim() ) {
                        RFIDWebService.LockItemBarcode(barcode);
                    }
                }
            }
        }
    },
    
    // Unlock item barcode with the RFID Web service
    UnlockItemBarcode: function(barcode) {
        console.log("UnlockItemBarcode called to unlock item");
        
        // read URL and status from the sessionStorage
        var rfidWebServiceURL = window.sessionStorage.getItem('RFIDWebServiceURL');
        rfidWebServiceURL += "/CheckoutItems";
        
        $.ajax({
            type: 'POST',
            crossDomain: true,
            cors: true,
            headers: { 'accept': 'application/json', 'content-type': 'application/json' },
            contentType: 'application/json; charset=UTF-8',
            url: rfidWebServiceURL,
            dataType: "json",
            data: '{ "items": [{"itemID": "' + barcode + '"}]}',
            success: function (data) { 
                window.sessionStorage.setItem('RFIDWebServiceCheckoutItem','');
                if ( data.itemResult && data.itemResult.length == 1) {
                    if ( data.itemResult[0].requestSuccess && data.itemResult[0].requestSuccess == true ) {
                        
                        if ( $(RFIDWebService.checkoutBlockingSelector).length < 1 ) {
                            var itemCount = window.sessionStorage.getItem('RFIDWebServiceCheckoutItemCount');
                        
                            if ( itemCount && itemCount >= 1 ) {
                                RFIDWebService.CheckoutNextItem();
                            }
                        }
                    }
                    if ( data.itemResult[0].requestSuccess && data.itemResult[0].requestSuccess == true ) {
                        if ( data.itemResult[0].errorCode && data.itemResult[0].errorMessage ) {
                            RFIDWebService.DisplayRFIDServiceErrorMessage(data.itemResult[0].errorCode,data.itemResult[0].errorMessage);
                            console.log("RFIDWebService CheckoutItems returns error " + data.itemResult[0].errorCode + ": " + data.itemResult[0].errorMessage);
                        }
                    }
                    return;
                }
            },
            error: function (data) { 
                console.log("RFIDWebService CheckoutItems calling error " + data);
            }
        });
    },
    
    // Lock item barcode with the RFID Web service
    LockItemBarcode: function(barcode) {
        console.log("LockItemBarcode called to unlock item");
        
        // read URL and status from the sessionStorage
        var rfidWebServiceURL = window.sessionStorage.getItem('RFIDWebServiceURL');
        rfidWebServiceURL += "/CheckinItems";
        
        $.ajax({
            type: 'POST',
            crossDomain: true,
            cors: true,
            headers: { 'accept': 'application/json', 'content-type': 'application/json' },
            contentType: 'application/json; charset=UTF-8',
            url: rfidWebServiceURL,
            dataType: "json",
            data: '{ "items": [{"itemID": "' + barcode + '"}]}',
            success: function (data) { 
                window.sessionStorage.setItem('RFIDWebServiceCheckinItem','');
                if ( data.itemResult && data.itemResult.length == 1) {
                    if ( data.itemResult[0].requestSuccess && data.itemResult[0].requestSuccess == true ) {
                        
                        if ( $(RFIDWebService.checkinBlockingSelector).length < 1 ) {
                            var itemCount = window.sessionStorage.getItem('RFIDWebServiceCheckinItemCount');
                        
                            if ( itemCount && itemCount >= 1 ) {
                                RFIDWebService.CheckinNextItem("checkin");
                            }
                        }
                    }
                    if ( data.itemResult[0].requestSuccess && data.itemResult[0].requestSuccess == true ) {
                        if ( data.itemResult[0].errorCode && data.itemResult[0].errorMessage ) {
                            RFIDWebService.DisplayRFIDServiceErrorMessage(data.itemResult[0].errorCode,data.itemResult[0].errorMessage);
                            console.log("RFIDWebService CheckinItems returns error " + data.itemResult[0].errorCode + ": " + data.itemResult[0].errorMessage);
                        }
                    }
                    return;
                }
            },
            error: function (data) { 
                console.log("RFIDWebService CheckinItems calling error " + data);
            }
        });
    },

    
    // The function ReadTagsAndStartCheckout reads tags
    ReadTagsAndStartCheckout: function (context) {
        
        // read URL and status from the sessionStorage
        var rfidWebServiceURL = window.sessionStorage.getItem('RFIDWebServiceURL');
        var enabled = window.sessionStorage.getItem('RFIDWebServiceStatus');
        
        // use the GetItems function to read tags available on the pad
        if ( rfidWebServiceURL && enabled && enabled == 'ok' ) {
            rfidWebServiceURL.replace(/\/$/, "");
            rfidWebServiceURL += "/GetItems";
            
            console.log("ReadTagsAndStartCheckout called to read items");
            $.ajax({
                type: 'GET',
                url: rfidWebServiceURL,
                dataType: "json",
                success: function (data) { 
                    if ( data && data.requestSuccess ) {
                        if ( data.requestSuccess == false ) {
                            if ( data.errorCode && data.errorMessage ) {
                                window.sessionStorage.setItem('RFIDWebServiceJustCalling',0);
                                RFIDWebService.DisplayRFIDServiceErrorMessage(data.errorCode,data.errorMessage);
                                console.log("RFIDWebService returns error " + data.errorCode + ": " + data.errorMessage);
                            }
                        }
                        else if ( data.requestSuccess == true 
                               && data.responseData 
                               && data.responseData.numberOfItems
                               && data.responseData.numberOfItems > 0
                               && data.responseData.items 
                               && data.responseData.items.length > 0 ) 
                        {
                           var countUserCards = 0;
                           var userCard = '';
                           var countItems = 0;
                           var items = [];
                           var checkoutNotAllowedItems = [];
                           
                           for (var i=0; i < data.responseData.items.length; i++) 
                           {
                                var barcode         = data.responseData.items[i].itemID;
                                var deleted         = data.responseData.items[i].deleted;
                                var isUserCard      = data.responseData.items[i].isUserCard;
                                var numberOfParts   = data.responseData.items[i].numberOfParts;
                                var partNumber      = data.responseData.items[i].partNumber;
                                var checkoutAllowed = data.responseData.items[i].checkoutAllowed;
                                var checkedOut      = data.responseData.items[i].checkedOut;
                                
                                if ( deleted && deleted != 0 ) { continue; }
                                if ( isUserCard && isUserCard && barcode ) {
                                    countUserCards++;
                                    userCard = barcode;
                                    continue;
                                }
                                if ( barcode ) {
                                    if ( context == "checkout" && checkoutAllowed && checkoutAllowed == false ) {
                                        checkoutNotAllowedItems.push(barcode);
                                    }
                                    else {
                                        items.push([barcode]);
                                    }
                                }
                            }
                            if ( countUserCards > 1 ) {
                                RFIDWebService.DisplayRFIDServiceErrorMessage("MULTIPLE_USER_CARDS_ON_PAD","");
                                return;
                            }
                            if ( !context.startsWith("checkin") && checkoutNotAllowedItems.length >= 1 ) {
                                var msg = checkoutNotAllowedItems.join(", ");
                                RFIDWebService.DisplayRFIDServiceErrorMessage("CHECKOUT_NOT_ALLOWED_ITEMS",msg);
                                return;
                            }
                            if (!(context == "borrower" && countUserCards == 0)) {
                                if ( items.length >= 1 ) {
                                    if ( context.startsWith("checkin") ) {
                                        window.sessionStorage.setItem('RFIDWebServiceCheckinItems',JSON.stringify(items));
                                        window.sessionStorage.setItem('RFIDWebServiceCheckinItemCount',items.length);
                                    }
                                    else {
                                        window.sessionStorage.setItem('RFIDWebServiceCheckoutItems',JSON.stringify(items));
                                        window.sessionStorage.setItem('RFIDWebServiceCheckoutItemCount',items.length);
                                    }
                                }
                            }
                            if ( countUserCards == 1 && !context.startsWith("checkin") ) {
                                window.sessionStorage.setItem('RFIDWebServiceJustCalling',0);
                                RFIDWebService.SwitchPatron(userCard);
                            }
                            if ( context == "checkout" && items.length >= 1 ) {
                                RFIDWebService.CheckoutNextItem();
                            }
                            if ( context.startsWith("checkin") && items.length >= 1 ) {
                                RFIDWebService.CheckinNextItem(context);
                            }
                        }
                    }
                    window.sessionStorage.setItem('RFIDWebServiceJustCalling',0);
                },
                error: function (data) { 
                    window.sessionStorage.setItem('RFIDWebServiceStatus','failed');
                    window.sessionStorage.setItem('RFIDWebServiceJustCalling',0);
                }
            });
        }
    },
    
    // Listen to barcode field input and read barcode if it is just a space
    SetupRFIDServerCheckin: function () {

        // Check whether we are ok calling the RFID WEB service
        var enabled = window.sessionStorage.getItem('RFIDWebServiceStatus')
        
        // The service is active and valid
        var barcodefield = $('#circ_returns #checkin-form #barcode');
        
        window.sessionStorage.setItem('RFIDWebServiceJustCalling', 0);
        if ( barcodefield.length && (enabled && enabled == 'ok') ) {
            barcodefield.keydown( function( event ) {
                if ( event.which == 32 ) {
                    //event.preventDefault();
                    var barvalue = $('#barcode').val();
                    if ( barvalue == "" || barvalue == " " ) {
                        event.preventDefault();
                        var itemCount = window.sessionStorage.getItem('RFIDWebServiceCheckinItemCount');
                        if ( itemCount > 0 ) {
                            RFIDWebService.CheckinNextItem("checkin");
                        } else {
                            RFIDWebService.StartRFIDServerCheckin();
                        }
                    }
                }
            });
        }
    },
    
    // Start RFID-Pad reading for checkout
    StartRFIDServerCheckin: function () {
    		
        // Check whether ther was a previous call
        var busy = window.sessionStorage.getItem('RFIDWebServiceJustCalling');

        // console.log("StartRFIDServerCheckin called: = " + busy);
        
        if ( busy == 0 ) {
        	
            // The service is active and valid
            var barcode = $('#circ_returns #checkin-form #barcode');
        
            // Check whether we are in a return context with the barcode field
            // If there is a barcode field it has to have the input focus
            if (  barcode.length && barcode.is(':focus') ) {
                window.sessionStorage.setItem('RFIDWebServiceJustCalling',1);
                RFIDWebService.ReadTagsAndStartCheckout("checkin");
            }
        }
    },
    
    
    // Listen to barcode field input and read barcode if it is just a space
    SetupRFIDServerCheckout: function () {

        // Check whether we are ok calling the RFID WEB service
        var enabled = window.sessionStorage.getItem('RFIDWebServiceStatus')
        
        // The service is active and valid
        var barcodefield = $('#circ_circulation #circ_circulation_issue #barcode');
        
        window.sessionStorage.setItem('RFIDWebServiceJustCalling', 0);
        if ( barcodefield.length && (enabled && enabled == 'ok') ) {
            barcodefield.keydown( function( event ) {
                if ( event.which == 32 ) {
                    //event.preventDefault();
                    var barvalue = $('#barcode').val();
                    if ( barvalue == "" || barvalue == " " ) {
                        event.preventDefault();
                        
                        var itemCount = window.sessionStorage.getItem('RFIDWebServiceCheckoutItemCount');
                        if ( itemCount > 0 ) {
                            RFIDWebService.CheckoutNextItem();
                        } else {
                            RFIDWebService.StartRFIDServerCheckout();
                        }
                    }
                }
            });
        }
    },
    
    // Start RFID-Pad reading for checkout
    StartRFIDServerCheckout: function () {
    		
        // Check whether ther was a previous call
        var busy = window.sessionStorage.getItem('RFIDWebServiceJustCalling');

        // console.log("StartRFIDServerCheckout called: = " + busy);
        
        if ( busy == 0 ) {
        	
            // The service is active and valid
            var barcode = $('#circ_circulation #circ_circulation_issue #barcode');
        
            // Check whether we are in a circulation context with the barcode field
            // If there is a barcode field it has to have the input focus
            if (  barcode.length && barcode.is(':focus') ) {
                window.sessionStorage.setItem('RFIDWebServiceJustCalling',1);
                RFIDWebService.ReadTagsAndStartCheckout("checkout");
            }
        }
        // setTimeout(RFIDWebService.StartRFIDServerCheckout, 1000, barcodefield);
    },
    
    // Change patron in user interface using the new patron barcode
    SwitchPatron: function(barcode) {
        location.replace('/cgi-bin/koha/circ/circulation.pl?findborrower=' + encodeURIComponent(barcode));
    },
    
    // Checkout the next item of the read stack
    CheckoutNextItem: function() {
        var itemCount = window.sessionStorage.getItem('RFIDWebServiceCheckoutItemCount');
        if ( itemCount > 0 ) {
            var items = JSON.parse(window.sessionStorage.getItem('RFIDWebServiceCheckoutItems'));

            if ( items && items.length > 0 ) {
                var item = items.shift();

                window.sessionStorage.setItem('RFIDWebServiceCheckoutItems',JSON.stringify(items));
                window.sessionStorage.setItem('RFIDWebServiceCheckoutItemCount',items.length);
                window.sessionStorage.setItem('RFIDWebServiceCheckoutItem',item[0]);
                
                $('#barcode').val(item[0]);
                $('form#mainform').submit();
            }
        }
    },
    
    // Checkin the next item of the read stack
    CheckinNextItem: function(context) {
        var itemCount = window.sessionStorage.getItem('RFIDWebServiceCheckinItemCount');
        if ( itemCount > 0 ) {
            var items = JSON.parse(window.sessionStorage.getItem('RFIDWebServiceCheckinItems'));

            if ( items && items.length > 0 ) {
                var item = items.shift();

                window.sessionStorage.setItem('RFIDWebServiceCheckinItems',JSON.stringify(items));
                window.sessionStorage.setItem('RFIDWebServiceCheckinItemCount',items.length);
                window.sessionStorage.setItem('RFIDWebServiceCheckinItem',item[0]);
                
                if ( context == "checkin" ) {
                    $('#barcode').val(item[0]);
                    $('form#checkin-form').submit();
                }
                if ( context == "checkinstart" ) {
                    $('#ret_barcode').val(item[0]);
                    $('#ret_barcode').get(0).form.submit();
                }
            }
        }
    },
    
    // Show an error message dialog
    DisplayRFIDServiceErrorMessage: function (errorCode, errorMessage) {
        var messages = {
                        title:                  "RFID Error Message",
                        actionClose:            "Close"
                    };
        var text  = errorMessage;

        if ( this.messageServiceProvider ) {
            messages = this.messageServiceProvider.GetRFIDErrorDialogNames();
            text  = this.messageServiceProvider.GetErrorMessage(errorCode, errorMessage,RFIDWebService.vendorName);
        }
        
        var popupTemplate =
        '<div class="modal" id="rfidErrorMessage_dialog" tabindex="-1" role="dialog" aria-labelledby="rfidErrorMessage_label" aria-hidden="true">' +
        '  <div class="modal-dialog">' +
        '    <div class="modal-content">' +
        '      <div class="modal-header">' +
        '        <button type="button" class="rfidErrorMessage_close closebtn" data-dismiss="modal" aria-hidden="true">&times;</button>' +
        '        <h3 id="rfidErrorMessage_title">' + messages.title + '</h3>' +
        '      </div>' +
        '      <div class="modal-body">' +
        '      <p><div id="rfidErrorMessage_message">' + text + '</div><p>' +
        '      <div class="modal-footer">' +
        '        <button type="button" class="btn btn-small rfidErrorMessage_close" data-dismiss="modal">' + messages.actionClose + '</button>' +
        '      </div>' +
        '    </div>' +
        '  </div>' +
        '</div>';

        $(popupTemplate).modal();
        $(popupTemplate).show();
    },
    
    // Show an error message dialog
    DisplayRFIDServiceStatus: function () {
        var messages = {
                        title:                  "RFID WebService Information",
                        status:                 "Status", 
                        statusOk:               "Service ready",
                        statusError:            "Initialization error",
                        statusNoService:        "No RFID WebService Information available.",
                        errorCode:              "Error code", 
                        errorMessage:           "Error message",
                        vendorName:             "Vendor name",
                        readerModel:            "Reader model",
                        serviceVersion:         "Service version",
                        countryId:              "Country code",
                        libraryId:              "Library code",
                        backwardCompatibility:  "Compatibility with version",
                        actionClose:            "Close"
                    };
        if ( this.messageServiceProvider ) {
            messages = this.messageServiceProvider.GetRFIDStatusDialogNames();
        }
        text = '';
        var data = JSON.parse(window.sessionStorage.getItem('RFIDWebServiceStatusInfo'));
        if ( data ) {
            text += '<table>';
            if ( data.requestSuccess && data.requestSuccess == true ) {
                text += '<tr><td>' + messages.status + ': </td><td>' + messages.statusOk + '</td></tr>';
                if ( data.responseData ) {
                    if ( data.responseData.vendorName ) {
                        text += '<tr><td>' + messages.vendorName + ': </td><td>' + data.responseData.vendorName + '</td></tr>';
                    }
                    if ( data.responseData.readerModel ) {
                        text += '<tr><td>' + messages.readerModel + ': </td><td>' + data.responseData.readerModel + '</td></tr>';
                    }
                    if ( data.responseData.serviceVersion ) {
                        text += '<tr><td>' + messages.serviceVersion + ': </td><td>' + data.responseData.serviceVersion + '</td></tr>';
                    }
                    if ( data.responseData.countryId ) {
                        text += '<tr><td>' + messages.countryId + ': </td><td>' + data.responseData.countryId + '</td></tr>';
                    }
                    if ( data.responseData.libraryId ) {
                        text += '<tr><td>' + messages.libraryId + ': </td><td>' + data.responseData.libraryId + '</td></tr>';
                    }
                    if ( data.responseData.backwardCompatibility ) {
                        text += '<tr><td>' + messages.backwardCompatibility + ': </td><td>' + data.responseData.backwardCompatibility + '</td></tr>';
                    }
                }
            }
            else {
                text += '<tr><td>' + messages.status + ': </td><td>' + messages.statusError + '</td></tr>';
                if ( data.errorCode ) {
                    text += '<tr><td>' + messages.errorCode + ': </td><td>' + data.errorCode + '</td></tr>';
                }
                if ( data.errorMessage ) {
                    text += '<tr><td>' + messages.errorMessage + ': </td><td>' + data.errorMessage + '</td></tr>';
                }
            }
            text += '<table>';
        } else {
            text = messages.statusNoService;
        }
        
        var popupTemplate =
        '<div class="modal" id="rfidStatusMessage_dialog" tabindex="-1" role="dialog" aria-labelledby="rfidStatusMessage_label" aria-hidden="true">' +
        '  <div class="modal-dialog">' +
        '    <div class="modal-content">' +
        '      <div class="modal-header">' +
        '        <button type="button" class="rfidStatusMessage_close closebtn" data-dismiss="modal" aria-hidden="true">&times;</button>' +
        '        <h3 id="rfidStatusMessage_title">' + messages.title + '</h3>' +
        '      </div>' +
        '      <div class="modal-body">' +
        '      <p><div id="rfidStatusMessage_message">' + text + '</div><p>' +
        '      <div class="modal-footer">' +
        '        <button type="button" class="btn btn-small rfidStatusMessage_close" data-dismiss="modal">' + messages.actionClose + '</button>' +
        '      </div>' +
        '    </div>' +
        '  </div>' +
        '</div>';

        $(popupTemplate).modal();
        $(popupTemplate).show();
    }
};
