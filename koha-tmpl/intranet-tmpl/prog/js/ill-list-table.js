$(document).ready(function() {
    /*
     * Deleted in 22.11

    var mypatrons;    // introduced for efficiency reasons in method illlist
    var mybranches;    // introduced for efficiency reasons in method illlist
    var mybackendcapabilities;    // introduced for efficiency reasons in method illlist


    // Illlist Datatable setup

    var table;

    // Filters that are active
    var activeFilters = {};

    // Get any prefilters, e.g. "backend=ILLALV" (or e.g. "borrowernumber=1215")
    var prefilters = $('table#ill-requests').data('prefilters');
    // Get any infilter, e.g. "status,-not_in,COMP,QUEUED"
    var infilter = $('table#ill-requests').data('infilter');

    // Fields we need to expand (flatten)
    var expand = [
        'metadata',
        'patron',
        'library'
    ];

    // Expanded fields
    // This is auto populated
    var expanded = {};

    // Filterable columns
    var filterable = {
        status: {
            prep: function(tableData, oData) {
                var uniques = {};
                tableData.forEach(function(row) {
                    var resolvedName;
                    if (row.status_alias) {
                        resolvedName = row.status_alias.lib;
                    } else {
                        resolvedName = getStatusName(
                            row.capabilities[row.status].name,
                            row
                        );
                    }
                    uniques[resolvedName] = 1
                });
                Object.keys(uniques).sort().forEach(function(unique) {
                    $('#illfilter_status').append(
                        '<option value="' + unique  +
                        '">' + unique +  '</option>'
                    );
                });
            },
            listener: function() {
                var me = 'status';
                $('#illfilter_status').change(function() {
                    var sel = $('#illfilter_status option:selected').val();
                    if (sel && sel.length > 0) {
                        activeFilters[me] = function() {
                            table.api().column(14).search(sel);
                        }
                        $('#illfilter_status_selected').val(sel);
                    } else {
                        if (activeFilters.hasOwnProperty(me)) {
                            delete activeFilters[me];
                            $('#illfilter_status_selected').val('');
                        }
                    }
                });
            },
            clear: function() {
                $('#illfilter_status').val('');
                $('#illfilter_status_selected').val($('#illfilter_status').val());
            },
            refresh: function () {
                var selectedValue = $('#illfilter_status_selected').val();
                $("#illfilter_status option[value='" + selectedValue + "']").prop('selected', true);
                $('#illfilter_status').change();
            }
        },
        pickupBranch: {
            prep: function(tableData, oData) {
                var uniques = {};
                tableData.forEach(function(row) {
                    uniques[row.library_branchname] = 1
                });
                Object.keys(uniques).sort().forEach(function(unique) {
                    $('#illfilter_branchname').append(
                        '<option value="' + unique  +
                        '">' + unique +  '</option>'
                    );
                });
            },
            listener: function() {
                var me = 'pickupBranch';
                $('#illfilter_branchname').change(function() {
                    var sel = $('#illfilter_branchname option:selected').val();
                    if (sel && sel.length > 0) {
                        activeFilters[me] = function() {
                            table.api().column(13).search(sel);
                        }
                        $('#illfilter_branchname_selected').val(sel);
                    } else {
                        if (activeFilters.hasOwnProperty(me)) {
                            delete activeFilters[me];
                            $('#illfilter_branchname_selected').val('');
                        }
                    }
                });
            },
            clear: function() {
                $('#illfilter_branchname').val('');
                $('#illfilter_branchname_selected').val($('#illfilter_branchname').val());
            },
            refresh: function () {
                var selectedValue = $('#illfilter_branchname_selected').val();
                $("#illfilter_branchname option[value='" + selectedValue + "']").prop('selected', true);
                $('#illfilter_branchname').change();
            }
        },
        patron: {
            listener: function() {
                var me = 'patron';
                $('#illfilter_patron').change(function() {
                    var val = $('#illfilter_patron').val();
                    if (val && val.length > 0) {
                        activeFilters[me] = function() {
                            table.api().column(11).search(val);
                        }
                    } else {
                        if (activeFilters.hasOwnProperty(me)) {
                            delete activeFilters[me];
                        }
                    }
                });
            },
            clear: function() {
                $('#illfilter_patron').val('');
            },
            refresh: function () {
                $('#illfilter_patron').change();
            }
        },
        keyword: {
            listener: function () {
                var me = 'keyword';
                $('#illfilter_keyword').change(function () {
                    var val = $('#illfilter_keyword').val();
                    if (val && val.length > 0) {
                        activeFilters[me] = function () {
                            table.api().search(val);
                        }
                    } else {
                        if (activeFilters.hasOwnProperty(me)) {
                            delete activeFilters[me];
                        }
                    }
                });
            },
            clear: function () {
                $('#illfilter_keyword').val('');
            },
            refresh: function () {
                $('#illfilter_keyword').change();
            }
        },
        dateModified: {
            clear: function() {
                $('#illfilter_datemodified_start, #illfilter_datemodified_end').val('');
            }
        },
        datePlaced: {
            clear: function() {
                $('#illfilter_dateplaced_start, #illfilter_dateplaced_end').val('');
            }
        }

    }; //END Filterable columns

    // Expand any fields we're expanding
    var expandExpand = function(row) {
        expand.forEach(function(thisExpand) {
            if (row.hasOwnProperty(thisExpand)) {
                if (!expanded.hasOwnProperty(thisExpand)) {
                    expanded[thisExpand] = [];
                }
                var expandObj = row[thisExpand];
                Object.keys(expandObj).forEach(
                    function(thisExpandCol) {
                        var expColName = thisExpand + '_' + thisExpandCol.replace(/\s/g,'_');
                        // Keep a list of fields that have been expanded
                        // so we can create toggle links for them
                        if (expanded[thisExpand].indexOf(expColName) == -1) {
                            expanded[thisExpand].push(expColName);
                        }
                        expandObj[expColName] =
                            expandObj[thisExpandCol];
                        delete expandObj[thisExpandCol];
                    }
                );
                $.extend(true, row, expandObj);
                delete row[thisExpand];
            }
        });
    };
    //END Expand

    // Strip the expand prefix if it exists, we do this for display
    var stripPrefix = function(value) {
        expand.forEach(function(thisExpand) {
            var regex = new RegExp(thisExpand + '_', 'g');
            value = value.replace(regex, '');
        });
        return value;
    };

    // Our 'render' function for orderid
    var createOrderId = function(data, type, row) {
        return row.id_prefix + row.orderid;
    };

    // Our 'render' function for borrowerlink
    var createPatronLink = function(data, type, row) {
        var patronLink = '';
        if ( row && row.borrowernumber ) {
            patronLink = '<a title="' + ill_borrower_details + '" ' +
                'href="/cgi-bin/koha/members/moremember.pl?' +
                'borrowernumber='+row.borrowernumber+'">';
            if ( row.patron_firstname && row.patron_firstname.length ) {
                patronLink = patronLink + row.patron_firstname.escapeHtml() + ' ';
            }
            if ( row.patron_surname && row.patron_surname.length ) {
                patronLink = patronLink + row.patron_surname.escapeHtml() + ' ';
            }
            patronLink = patronLink + '(';
            if ( row.patron_cardnumber && row.patron_cardnumber.length ) {
                patronLink = patronLink + row.patron_cardnumber.escapeHtml();
            } else {
                patronLink = patronLink + 'N/A';
            }
            patronLink = patronLink + ')' + '</a>';
        } else {
            if ( row.patron_cardnumber ) {
                patronLink = row.patron_cardnumber;
            }
            if ( row.patron_surname ) {
                if ( patronLink.length ) {
                    patronLink = patronLink + ' ';
                }
                patronLink = patronLink + row.patron_surname;
            }
        }
        return patronLink;
    };

    // Our 'render' function for biblio_id
    var createBiblioLink = function(data, type, row) {
        var ret = '';
        var textToDisplay = '';
        if ( row && row.metadata_title && row.metadata_title.length > 0 ) {
            textToDisplay = row.metadata_title.escapeHtml();
        }
        if ( ! textToDisplay && row && row.biblio_id && row.biblio_id.length > 0 ) {
            textToDisplay = row.biblio_id.escapeHtml();
        }
        if ( row.biblio_id  && row.status !== 'COMP' ) {
            ret = '<a title="' + ill_biblio_details + '" ' +
                'href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=' +
                row.biblio_id + '">' +
                textToDisplay +
                '</a>';
        } else {
            ret = textToDisplay;
        } 
        return ret;
    };

    // Our 'render' function for title
    var createTitle = function(data, type, row) {
        return (
            row.hasOwnProperty('metadata_container_title') &&
            row.metadata_container_title
        ) ? row.metadata_container_title : row.metadata_title;
    };

    // Render function for request ID
    var createRequestId = function(data, type, row) {
        return row.id_prefix + row.illrequest_id;
    };

    // Render function for type
    var createType = function(data, type, row) {
        if (!row.hasOwnProperty('metadata_type') || !row.metadata_type) {
            if (row.hasOwnProperty('medium') && row.medium) {
                row.metadata_type = row.medium;
            } else {
                row.metadata_type = null;
            }
        }
        // using translations of illrequest.medium via ill-list-table-strings.inc
        if ( row.metadata_type ) {
            row.metadata_type = mediumTypeToDesignation(row.metadata_type,row.metadata_type);
        }
        return row.metadata_type;
    };

    // Render function for request status
    var createStatus = function(data, type, row, meta) {
        if (row.status_alias) {
            return row.status_alias.lib
                ? row.status_alias.lib
                : row.status_alias.authorised_value;
        } else {
            var status_name = 'undef';
            if ( row.status ) {
                status_name = row.capabilities[row.status].name;
            }
            return getStatusName(status_name, row);
        }
    };

    var getStatusName = function(origName, row) {
        switch( origName ) {
            case "New request":
                return ill_statuses.new;
            case "Requested":
                return ill_statuses.req;
            case "Requested from partners":
                var statStr = ill_statuses.genreq;
                if (
                    row.hasOwnProperty('requested_partners') &&
                    row.requested_partners &&
                    row.requested_partners.length > 0
                ) {
                    statStr += ' (' + row.requested_partners + ')';
                }
                return statStr;
            case "Request reverted":
                return ill_statuses.rev;
            case "Queued request":
                return ill_statuses.que;
            case "Cancellation requested":
                return ill_statuses.canc;
            case "Completed":
                return ill_statuses.comp;
            case "Delete request":
                return ill_statuses.del;
            default:
                return origName;
        }
    };

    // Render function for backend designation
    var createBackendDesignation = function(data, type, row, meta) {
        var backend_designation = backendNameToDesignation(row.backend);
        return backend_designation;
    };

    // Render function for creating a row's action link
    var createActionLink = function(data, type, row) {
        return '<a class="btn btn-default btn-sm" ' +
            'href="/cgi-bin/koha/ill/ill-requests.pl?' +
            'method=illview&amp;illrequest_id=' +
            row.illrequest_id +
            '">' + ill_manage + '</a>';
    };

    // Render function for Checked by
    var createCheckedBy = function(data, type, row) {
        var res = '';
        if ( row.metadata_checkedBy ) {
            res = row.metadata_checkedBy;
        }
        return res;
    };

    // Render function for ISIL
    var createIsil = function(data, type, row) {
        var res = '';
        if ( row.metadata_isil ) {
            res = row.metadata_isil;
        }
        return res;
    };

    // Columns that require special treatment
    var specialCols = {
        action: {
            func: createActionLink,
            skipSanitize: true
        },
        illrequest_id: {
            func: createRequestId
        },
        status: {
            func: createStatus
        },
        biblio_id: {
            name: ill_columns.biblio_id,
            func: createBiblioLink,
            skipSanitize: true
        },
        metadata_title: {
            func: createTitle
        },
        metadata_type: {
            name: ill_columns.type,
            func: createType
        },
        updated: {
            name: ill_columns.updated
        },
        patron: {
            skipSanitize: true,
            func: createPatronLink
        },
        orderid: {
            func: createOrderId
        },
        backend: {
            func: createBackendDesignation
        },
        metadata_checkedBy: {
            name: _("ILL order last checked by"),
            func: createCheckedBy
        },
        metadata_isil: {
            name: _("ISIL"),
            func: createIsil
        }
    };

    */
    // Display the modal containing request supplier metadata
    $('#ill-request-display-log').on('click', function(e) {
        e.preventDefault();
        $('#requestLog').modal({show:true});
    });

    // Toggle request attributes in Illview
    $('#toggle_requestattributes').on('click', function(e) {
        e.preventDefault();
        $('#requestattributes').toggleClass('content_hidden');
    });

    // Toggle new comment form in Illview
    $('#toggle_addcomment').on('click', function(e) {
        e.preventDefault();
        $('#addcomment').toggleClass('content_hidden');
    });

    // Filter partner list
    // Record the list of all options
    var ill_partner_options = $('#partners > option');
    $('#partner_filter').keyup(function() {
        var needle = $('#partner_filter').val();
        var regex = new RegExp(needle, 'i');
        var filtered = [];
        ill_partner_options.each(function() {
            if (
                needle.length == 0 ||
                $(this).is(':selected') ||
                $(this).text().match(regex)
            ) {
                filtered.push($(this));
            }
        });
        $('#partners').empty().append(filtered);
    });

    // Display the modal containing request supplier metadata
    $('#ill-request-display-metadata').on('click', function(e) {
        e.preventDefault();
        $('#dataPreview').modal({show:true});
    });

    function display_extended_attribute(row, type) {
        var arr = $.grep(row.extended_attributes, ( x => x.type === type ));
        if (arr.length > 0) {
            return escape_str(arr[0].value);
        }

        return '';
    }

    /*
     * Deleted in 22.11
     * 
    // Get our data from the API and process it prior to passing
    // it to datatables
    var filterParam = prefilters ? '&' + prefilters : '';
    filterParam += infilter ? '&infilter=' + infilter : '';

    // Only fire the request if we're on an appropriate page
    if (
        (
            // ILL list requests page
            window.location.href.match(/ill\/ill-requests\.pl/) &&
            query_type_js === 'illlist'    // LMSCloud: call ajax only if method = illlist (the ajax search is not required in other cases but speed is extremly slowed down)
        ) ||
        // Patron profile page
        window.location.href.match(/members\/ill-requests\.pl/)
    ) {
        var restApiUrl = '/api/v1/illrequests?embed=metadata,patron,capabilities,library,status_alias,comments,requested_partners' + filterParam;
        var ajax = $.ajax(
            restApiUrl
        ).done(function() {
            var dataAll = JSON.parse(ajax.responseText);
            var data = dataAll[0];    // all illrequests fields and some illrequestattributes fields
            mypatrons = dataAll[1];    // all required patrons
            mybranches = dataAll[2];    // all required branches
            mybackendcapabilities = dataAll[3];    // all required backend capabilities

            // links from illrequests to patrons, branches, backend capabilities
            $.each(data, function(k, row) {
                var illrequests_borrowernumber = row.borrowernumber;
                if ( !illrequests_borrowernumber || !mypatrons[illrequests_borrowernumber] ) {
                    var patronObj = {
                        patron_id: '',
                        firstname: '',
                        surname: '',
                        cardnumber: ''
                    };
                    mypatrons[illrequests_borrowernumber] = patronObj;
                }
                row.patron = mypatrons[illrequests_borrowernumber];

                var illrequests_branchcode = row.branchcode;
                if ( !illrequests_branchcode || !mybranches[illrequests_branchcode] ) {
                    if ( illrequests_branchcode ) {
                        mybranches[illrequests_branchcode].branchname = illrequests_branchcode;
                    } else {
                        mybranches[illrequests_branchcode].branchname = 'branchcode not set';
                    }
                }
                row.library = mybranches[illrequests_branchcode];

                var illrequests_backend = row.backend;
                if ( !illrequests_backend || !mybackendcapabilities[illrequests_backend] ) {
                    row.capabilities = undefined;
                } else {
                    row.capabilities = mybackendcapabilities[illrequests_backend];
                }

            });

            // Make a copy, we'll be removing columns next and need
            // to be able to refer to data that has been removed
            var dataCopy = $.extend(true, [], data);
            // Expand columns that need it and create an array
            // of all column names
            $.each(dataCopy, function(k, row) {
                expandExpand(row);
            });
    */
    
    // At the moment, the only prefilter possible is borrowernumber
    // see ill/ill-requests.pl and members/ill-requests.pl
    let additional_prefilters = {};
    if(prefilters){
        let prefilters_array = prefilters.split("&");
        prefilters_array.forEach((prefilter) => {
            let prefilter_split = prefilter.split("=");
            additional_prefilters[prefilter_split[0]] = prefilter_split[1]
        });
    }

    let borrower_prefilter = additional_prefilters['borrowernumber'] || null;

    let additional_filters = {
        "me.backend": function(){
            let backend = $("#illfilter_backend").val();
            if (!backend) return "";
            return { "=": backend  }
        },
        "me.branchcode": function(){
            let branchcode = $("#illfilter_branchname").val();
            if (!branchcode) return "";
            return { "=": branchcode }
        },
        "me.borrowernumber": function(){
            return borrower_prefilter ? { "=": borrower_prefilter } : "";
        },
        "-or": function(){
            let patron = $("#illfilter_patron").val();
            let status = $("#illfilter_status").val();
            let filters = [];
            let patron_sub_or = [];
            let status_sub_or = [];
            let subquery_and = [];

            if (!patron && !status) return "";

            if(patron){
                const patron_search_fields = "me.borrowernumber,patron.cardnumber,patron.firstname,patron.surname";
                patron_search_fields.split(',').forEach(function(attr){
                    let operator = "=";
                    let patron_data = patron;
                    if ( attr != "me.borrowernumber" && attr != "patron.cardnumber") {
                        operator = "like";
                        patron_data = "%" + patron + "%";
                    }
                    patron_sub_or.push({
                        [attr]:{[operator]: patron_data }
                    });
                });
                subquery_and.push(patron_sub_or);
            }

            if(status){
                const status_search_fields = "me.status,me.status_av";
                status_search_fields.split(',').forEach(function(attr){
                    status_sub_or.push({
                        [attr]:{"=": status }
                    });
                });
                subquery_and.push(status_sub_or);
            }

            filters.push({"-and": subquery_and});

            return filters;
        },
        "me.placed": function(){
            if ( Object.keys(additional_prefilters).length ) return "";
            let placed_start = $('#illfilter_dateplaced_start').get(0)._flatpickr.selectedDates[0];
            let placed_end = $('#illfilter_dateplaced_end').get(0)._flatpickr.selectedDates[0];
            if (!placed_start && !placed_end) return "";
            return {
                ...(placed_start && {">=": placed_start}),
                ...(placed_end && {"<=": placed_end})
            }
        },
        "me.updated": function(){
            if (Object.keys(additional_prefilters).length) return "";
            let updated_start = $('#illfilter_datemodified_start').get(0)._flatpickr.selectedDates[0];
            let updated_end = $('#illfilter_datemodified_end').get(0)._flatpickr.selectedDates[0];
            if (!updated_start && !updated_end) return "";
            // set selected datetime hours and minutes to the end of the day
            // to grab any request updated during that day
            let updated_end_value = new Date(updated_end);
            updated_end_value.setHours(updated_end_value.getHours()+23);
            updated_end_value.setMinutes(updated_end_value.getMinutes()+59);
            return {
                ...(updated_start && {">=": updated_start}),
                ...(updated_end && {"<=": updated_end_value})
            }
        },
        "-and": function(){
            let keyword = $("#illfilter_keyword").val();
            if (!keyword) return "";

            let filters = [];
            let subquery_and = [];

            const search_fields = "me.illrequest_id,me.borrowernumber,me.biblio_id,me.due_date,me.branchcode,library.name,me.status,me.status_alias,me.placed,me.replied,me.updated,me.completed,me.medium,me.accessurl,me.cost,me.price_paid,me.notesopac,me.notesstaff,me.orderid,me.backend,patron.firstname,patron.surname";
            let sub_or = [];
            search_fields.split(',').forEach(function(attr){
                sub_or.push({
                        [attr]:{"like":"%" + keyword + "%"}
                });
            });
            subquery_and.push(sub_or);
            filters.push({"-and": subquery_and});

            const extended_attributes = "title,type,author,article_title,pages,issue,volume,year";
            let extended_sub_or = [];
            subquery_and = [];
            extended_sub_or.push({
                "extended_attributes.type": extended_attributes.split(','),
                "extended_attributes.value":{"like":"%" + keyword + "%"}
            });
            subquery_and.push(extended_sub_or);

    /*
     * Deleted in 22.11
            // Initialise the datatable
            table = KohaTable("ill-requests", {
                'aoColumnDefs': [
                    { // Last column shouldn't be sortable or searchable
                        'aTargets': [ 'actions' ],
                        'bSortable': false,
                        'bSearchable': false
                    },
                    { // When sorting 'placed', we want to use the
                        // unformatted column
                        'aTargets': [ 'placed_formatted'],
                        'iDataSort': 15
                    },
                    { // When sorting 'updated', we want to use the
                        // unformatted column
                        'aTargets': [ 'updated_formatted'],
                        'iDataSort': 17
                    },
                    { // When sorting 'completed', we want to use the
                        // unformatted column
                        'aTargets': [ 'completed_formatted'],
                        'iDataSort': 20
                    }
                ],
                'aaSorting': [[ 17, 'desc' ]], // Default sort, updated descending
                'processing': true, // Display a message when manipulating
                'sPaginationType': "full_numbers", // Pagination display
                'deferRender': true, // Improve performance on big datasets
                'data': dataCopy,
                "dom": '<"top pager"<"table_entries"ilp><"table_controls"B>>tr<"bottom pager"ip>',
                'columns': colData,
                'originalData': data, // Enable render functions to access
                                        // our original data
                'initComplete': function() {

                    // Prepare any filter elements that need it
                    for (var el in filterable) {
                        if (filterable.hasOwnProperty(el)) {
                            if (filterable[el].hasOwnProperty('prep')) {
                                filterable[el].prep(dataCopy, data);
                            }
                            if (filterable[el].hasOwnProperty('listener')) {
                                filterable[el].listener();
                            }
                        }
                    }
        */
            filters.push({"-and": subquery_and});
            return filters;
        }
    };

    let table_id = "#ill-requests";
    if (borrower_prefilter) {
        table_id += "-patron-" + borrower_prefilter;
    }

    var ill_requests_table = $(table_id).kohaTable({
        "ajax": {
            "url": '/api/v1/ill/requests'
        },
        "embed": [
            '+strings',
            'biblio',
            'comments+count',
            'extended_attributes',
            'library',
            'id_prefix',
            'patron'
        ],
        "stateSave": true, // remember state on page reload
        "columns": [
            {
                "data": "ill_request_id",
                "searchable": true,
                "orderable": true,
                "render": function( data, type, row, meta ) {
                    return '<a href="/cgi-bin/koha/ill/ill-requests.pl?' +
                            'method=illview&amp;illrequest_id=' +
                            encodeURIComponent(data) +
                            '">' + escape_str(row.id_prefix) + escape_str(data) + '</a>';
                }
            },
            {
                "data": "", // author
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'author');
                }
            },
            {
                "data": "", // title
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'title');
                }
            },
            {
                "data": "", // article_title
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'article_title');
                }
    /*
     * Deleted in 22.11
            }, columns_settings);

            // Custom date range filtering
            $.fn.dataTable.ext.search.push(function(settings, data, dataIndex) {
                var placedStart = $('#illfilter_dateplaced_start').datepicker('getDate');
                var placedEnd = $('#illfilter_dateplaced_end').datepicker('getDate');
                var modifiedStart = $('#illfilter_datemodified_start').datepicker('getDate');
                var modifiedEnd = $('#illfilter_datemodified_end').datepicker('getDate');
                var rowPlaced = data[15] ? new Date(data[15]) : null;
                var rowModified = data[17] ? new Date(data[17]) : null;
                var placedPassed = true;
                var modifiedPassed = true;
                if (placedStart && rowPlaced && rowPlaced < placedStart) {
                    placedPassed = false
                };
                if (placedEnd && rowPlaced && rowPlaced.getTime() > placedEnd.getTime() + 86399999) {    // adding 24h-0.001s ~ 24*60*60*1000-1 = 86399999 to placedEnd date 00:00:00.000
                    placedPassed = false;
                }
                if (modifiedStart && rowModified && rowModified < modifiedStart) {
                    modifiedPassed = false
                };
                if (modifiedEnd && rowModified && rowModified.getTime() > modifiedEnd.getTime() + 86399999) {    // adding 24h-0.001s ~ 24*60*60*1000-1 = 86399999 to modifiedEnd date 00:00:00.000
                    modifiedPassed = false;
    */
            },
            {
                "data": "", // issue
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'issue');
                }
            },
            {
                "data": "", // volume
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'volume');
                }
            },
            {
                "data": "",  // year
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'year');
                }
            },
            {
                "data": "", // pages
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'pages');
                }
            },
            {
                "data": "", // type
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'type');
                }
            },
            {
                "data": "ill_backend_request_id",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "patron.firstname:patron.surname:patron.cardnumber",
                "render": function(data, type, row, meta) {
                    return (row.patron) ? $patron_to_html( row.patron, { display_cardnumber: true, url: true } ) : ''; }                    },
            {
                "data": "biblio_id",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    if ( data === null ) {
                        return "";
                    }
                    return $biblio_to_html(row.biblio, { biblio_id_only: 1, link: 1 });
                }
            },
            {
                "data": "library.name",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "status",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    let status_label = row._strings.status_av ?
                        row._strings.status_av.str ?
                            row._strings.status_av.str :
                            row._strings.status_av.code :
                        row._strings.status.str
                    return escape_str(status_label);
                }
            },
            {
                "data": "requested_date",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return $date(data);
                }
            },
            {
                "data": "timestamp",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return $date(data);
                }
            },
            {
                "data": "replied_date",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return $date(data);
                }
            },
            {
                "data": "completed_date",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return $date(data);
                }
            },
            {
                "data": "access_url",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "cost",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "paid_price",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "comments_count",
                "orderable": true,
                "searchable": false,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "opac_notes",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "staff_notes",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "ill_backend_id",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "ill_request_id",
                "orderable": false,
                "searchable": false,
                "render": function( data, type, row, meta ) {
                    return '<a class="btn btn-default btn-sm" ' +
                            'href="/cgi-bin/koha/ill/ill-requests.pl?' +
                            'method=illview&amp;illrequest_id=' +
                            encodeURIComponent(data) +
                            '">' + ill_manage + '</a>';
                }
            }
        ]
    }, table_settings, null, additional_filters);

    $("#illfilter_form").on('submit', filter);

    function redrawTable() {
        let table_dt = ill_requests_table.DataTable();
        table_dt.draw();
    }

    /*
     * Deleted in 22.11
            refreshFilterSearch(dataCopy, data);
            $('#illfilter_form').submit();
    */
    
    function filter() {
        redrawTable();
        return false;
    }

    function clearSearch() {
        let filters = [
            "illfilter_backend",
            "illfilter_branchname",
            "illfilter_patron",
            "illfilter_keyword",
        ];
        filters.forEach((filter) => {
            $("#"+filter).val("");
        });

        //Clear flatpickr date filters
        $('#illfilter_form > fieldset > ol > li:nth-child(4) > span > a').click();
        $('#illfilter_form > fieldset > ol > li:nth-child(5) > span > a').click();
        $('#illfilter_form > fieldset > ol > li:nth-child(6) > span > a').click();
        $('#illfilter_form > fieldset > ol > li:nth-child(7) > span > a').click();

        disableStatusFilter();

        redrawTable();
    }

    function populateStatusFilter(backend) {
        $.ajax({
            type: "GET",
            url: "/api/v1/ill/backends/"+backend,
            headers: {
                'x-koha-embed': 'statuses+strings'
            },
            success: function(response){
                let statuses = response.statuses
                $('#illfilter_status').append(
                    '<option value="">'+ill_all_statuses+'</option>'
                );
                statuses.sort((a, b) => a.str.localeCompare(b.str)).forEach(function(status) {
                    $('#illfilter_status').append(
                        '<option value="' + status.code  +
                        '">' + status.str +  '</option>'
                    );
                });
            }
        });
    }

    /*
     * Deleted in 22.11
    var refreshFilterSearch = function(dataCopy, data) {
        for (var filter in filterable) {
            if ( filterable.hasOwnProperty(filter) ) {
                if ( filterable[filter].hasOwnProperty('refresh') ) {
                    filterable[filter].refresh();
                }
            }
        }
    };

    // Apply any search filters, or clear any previous
    // ones
    $('#illfilter_form').submit(function(event) {
        event.preventDefault();
        table.api().search('').columns().search('');
        for (var active in activeFilters) {
            if (activeFilters.hasOwnProperty(active)) {
                activeFilters[active]();
            }
        });
    }
    */
    
    function populateBackendFilter() {
        $.ajax({
            type: "GET",
            url: "/api/v1/ill/backends",
            success: function(backends){
                backends.sort((a, b) => a.ill_backend_id.localeCompare(b.ill_backend_id)).forEach(function(backend) {
                    $('#illfilter_backend').append(
                        '<option value="' + backend.ill_backend_id  +
                        '">' + backend.ill_backend_id +  '</option>'
                    );
                });
            }
        });
    }

    function disableStatusFilter() {
        $('#illfilter_status').children().remove();
        $("#illfilter_status").attr('title', ill_manage_select_backend_first);
        $('#illfilter_status').prop("disabled", true);
    }

    function enableStatusFilter() {
        $('#illfilter_status').children().remove();
        $("#illfilter_status").attr('title', '');
        $('#illfilter_status').prop("disabled", false);
    }

    $('#illfilter_backend').change(function() {
        var selected_backend = $('#illfilter_backend option:selected').val();
        if (selected_backend && selected_backend.length > 0) {
            populateStatusFilter(selected_backend);
            enableStatusFilter();
        } else {
            disableStatusFilter();
        }
    });

    disableStatusFilter();
    populateBackendFilter();

    // Clear all filters
    $('#clear_search').click(function() {
        clearSearch();
    });

});
