$(document).ready(function() {

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
        return escape_str(get_extended_attribute(row, type));
    }

    function get_extended_attribute(row, type) {
        var ret = '';
        var arr = $.grep(row.extended_attributes, ( x => x.type === type ));
        if (arr.length > 0) {
            ret = arr[0].value;
        }

        return ret;
    }


    // standard Koha:
    // At the moment, the only prefilter possible is borrowernumber
    // LMSCloud Koha:
    // LMSCloud added prefilter 'backend' around year 2019
    // see ill/ill-requests.pl and members/ill-requests.pl
    // Get any prefilters, e.g. "backend=ILLALV" (or e.g. "borrowernumber=1215")
    let additional_prefilters = {};
    if(prefilters){
        let prefilters_array = prefilters.split("&");
        prefilters_array.forEach((prefilter) => {
            let prefilter_split = prefilter.split("=");
            additional_prefilters[prefilter_split[0]] = prefilter_split[1]
        });
    }

    // The so called 'infilter' supports SQL patterns: "AND ... IN ( ... )"  and  "AND ... NOT IN ( ... )"
    // Get any infilter, e.g. "status,-not_in,COMP,QUEUED"
    let additional_infilter = {};
    if(infilter){
        let infilter_array = infilter.split(";");
        infilter_array.forEach((infilt) => {
            let infilt_split = infilt.split(",");
            let len = infilt_split.length;
            let valslist  = new String;
            for ( let i=2; i < len; i += 1 ) {
                if ( valslist.length > 0 ) {
                    valslist += ",";
                }
                valslist += infilt_split[i];
            }
            additional_infilter[infilt_split[0]] = [ infilt_split[1],valslist ];
        });
    }

    let borrower_prefilter = additional_prefilters['borrowernumber'] || null;

    // Here we create the filter / select argument for calling function kohaTable() of datatables.js
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

            // only in standard Koha, but not in LMSCloud Koha:
            //if (!patron && !status) return "";

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

            // added by LMSCloud: add additional_prefilters
            let additional_prefilter_sub_and = [];
            for (let additional_prefilter_key in additional_prefilters) {
                additional_prefilter_sub_and.push({
                        ["me." + additional_prefilter_key]:{"=":additional_prefilters[additional_prefilter_key]}
                });
            }
            if (additional_prefilter_sub_and.length > 0 ) {
                subquery_and.push({"-and": additional_prefilter_sub_and});
            }

            // added by LMSCloud: add infilter, supporting SQL patterns: "AND ... IN ( ... )"  and  "AND ... NOT IN ( ... )"
            // As the standard Koha developers made no provisions for the SQL 'IN (...)'or 'NOT IN (...)' construct in datatables.js function build_query(col, value){...},
            // LMSCloud reduces infilter 'field,-in,A,B,C,...' to [field]:{"=":"A"} and 'field,-not_in,A,B,C,...' to [field]:{"!=":"A"}. (i.e. ",B,C" are ignored! )
            // Reasons:
            //   This is sufficient for our specific application until now, because currently only 1 value is required for the IN-clause.
            //   (Otherwise we could build 'or' subqueries, but at the moment we avoid the resulting performance penalties.)
            //   We do not want to spend effort in extending build_query() based on the fear that
            //   in the next Koha version the datatables.js implementation is again reworked from scratch.
            let additional_infilter_sub = [];
            for (let additional_infilt_key in additional_infilter) {
                let vals = additional_infilter[additional_infilt_key][1].split(",");
                if ( vals[0] ) {
                    if ( additional_infilter[additional_infilt_key][0] === "-not_in" ) {
                        additional_infilter_sub.push({
                            ["me." + additional_infilt_key]:{"!=":vals[0]}
                        });
                    }
                    if ( additional_infilter[additional_infilt_key][0] === "-in" ) {
                        additional_infilter_sub.push({
                            ["me." + additional_infilt_key]:{"=":vals[0]}
                        });
                    }
                }
            }
            if (additional_infilter_sub.length > 0 ) {
                subquery_and.push({"-and": additional_infilter_sub});
            }

            filters.push({"-and": subquery_and});

            return filters;
        },
        "me.placed": function(){
            //if ( Object.keys(additional_prefilters).length ) return "";    # This is used in standard Koha to suppress selection for 'placed' if selecting by borrowernumber. LMSCloud had to replace that by:
            if (borrower_prefilter) return "";
            let placed_start = $('#illfilter_dateplaced_start').get(0)._flatpickr.selectedDates[0];
            let placed_end = $('#illfilter_dateplaced_end').get(0)._flatpickr.selectedDates[0];
            if (!placed_start && !placed_end) return "";
            if (placed_end) placed_end.setHours(23,59,59,999);    // correction by LMSCloud
            return {
                ...(placed_start && {">=": placed_start}),
                ...(placed_end && {"<=": placed_end})
            }
        },
        "me.updated": function(){
            //if (Object.keys(additional_prefilters).length) return "";    # This is used in standard Koha to suppress selection for 'updated' if selecting by borrowernumber. LMSCloud had to replace that by:
            if (borrower_prefilter) return "";
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

            // standard Koha:
            //const extended_attributes = "title,type,author,article_title,pages,issue,volume,year";
            // LMSCloud Koha:
            const extended_attributes = "title,type,author,article_title,pages,issue,volume,year,Titel,Verfasser,ochk_Bearbeiter,ochk_BearbeitetAm,illPartnerLibraryIsil,sendingIllLibraryIsil,BestelltVonSigel,BestelltBeiSigel";
            let extended_sub_or = [];
            subquery_and = [];
            extended_sub_or.push({
                "extended_attributes.type": extended_attributes.split(','),
                "extended_attributes.value":{"like":"%" + keyword + "%"}
            });
            subquery_and.push(extended_sub_or);
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
        "order": [[ 16, "desc" ]],    // LMSCloud: default sort is illrequests.updated descending (called 'timestamp' here)
        "embed": [
            '+strings',
            'biblio',
            'comments+count',
            'extended_attributes',
            'library',
            'id_prefix',
            'patron'
        ],
        "order": [[0, 'desc']],
        "stateSave": true, // remember state on page reload
        "columns": [
            {
                "data": "ill_request_id",    // according to to_api_mapping this is illrequests.illrequest_id
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
                "data": "", // author (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'author');
                }
            },
            {
                "data": "", // title (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'title');
                }
            },
            {
                "data": "", // article_title (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'article_title');
                }
            },
            {
                "data": "", // issue (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'issue');
                }
            },
            {
                "data": "", // volume (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'volume');
                }
            },
            {
                "data": "",  // year (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'year');
                }
            },
            {
                "data": "", // pages (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'pages');
                }
            },
            {
                "data": "", // type (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    // standard Koha:
                    //return display_extended_attribute(row, 'type');
                    // LMSCloud Koha:
                    let metadataType = get_extended_attribute(row, 'type');
                    return escape_str(mediumTypeToDesignation(row.medium,metadataType));
                }
            },

            {
                "data": "",  // ISIL (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    let isil = get_extended_attribute(row, 'isil');
                    if ( isil.length < 1 ) {
                        isil = get_extended_attribute(row, 'isilFallback');
                        if ( isil.length > 0 ) isil += '.';    // mark it as second choice
                    }
                    return escape_str(isil);
                }
            },

            {
                "data": "ill_backend_request_id",    // according to to_api_mapping this is illrequests.orderid
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                // standard Koha:
                //"data": "patron.firstname:patron.surname:patron.cardnumber",
                // LMSCloud Koha:
                "data": "patron.surname:patron.firstname:patron.cardnumber",
                "render": function(data, type, row, meta) {
                    return (row.patron) ? $patron_to_html( row.patron, { display_cardnumber: true, url: true } ) : ''; }                    },
            {
                "data": "biblio_id",
                "orderable": true,
                "render": function(data, type, row, meta) {
                    if ( data === null ) {
                        return "";
                    }
                    return $biblio_to_html(row.biblio, { biblio_id_only: 0, link: 1 });
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
                    let status_label = row._strings.status_av ?    // according to to_api_mapping status_av is illrequests.status_alias
                        row._strings.status_av.str ?
                            row._strings.status_av.str :
                            row._strings.status_av.code :
                        // standard Koha:
                        //row._strings.status.str
                        // LMSCloud Koha:
                        translateStatusName(row._strings.status.str);
                    return escape_str(status_label);
                }
            },
            {
                "data": "requested_date",    // according to to_api_mapping this is illrequests.placed
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return $date(data);
                }
            },
            {
                "data": "timestamp",    // according to to_api_mapping this is illrequests.updated
                "orderable": true,
                "render": function(data, type, row, meta) {
                    // standard Koha:
                    //return $date(data);
                    // LMSCloud Koha:
                    return $datetime(data);
                }
            },
            {
                "data": "replied_date",    // according to to_api_mapping this is illrequests.replied
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return $date(data);
                }
            },
            {
                "data": "completed_date",    // according to to_api_mapping this is illrequests.completed
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return $date(data);
                }
            },
            {
                "data": "access_url",    // according to to_api_mapping this is illrequests.accessurl
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
                "data": "paid_price",    // according to to_api_mapping this is illrequests.price_paid
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "comments_count",    // constructed in api?
                "orderable": true,
                "searchable": false,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "opac_notes",    // according to to_api_mapping this is illrequests.notesopac
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "staff_notes",    // according to to_api_mapping this is illrequests.notesstaff
                "orderable": true,
                "render": function(data, type, row, meta) {
                    return escape_str(data);
                }
            },
            {
                "data": "ill_backend_id",    // according to to_api_mapping this is illrequests.backend
                "orderable": true,
                "render": function(data, type, row, meta) {
                    // standard Koha:
                    //return escape_str(data);
                    // LMSCloud Koha:
                    return escape_str(backendNameToDesignation(row.ill_backend_id));
                }
            },
            {
                "data": "", // checkedBy (derived from illrequestattributes)
                "orderable": false,
                "render": function(data, type, row, meta) {
                    return display_extended_attribute(row, 'checkedBy');
                }
            },
            {
                "data": "ill_request_id",    // according to to_api_mapping this is illrequests.illrequest_id, used here for the 'action' link (illview)
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
                let statuses = response.statuses;
                // LMSCloud Koha:
                statuses.forEach(function(status) {
                    status.str = translateStatusName(status.str);
                });

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

    function populateBackendFilter() {
        $.ajax({
            type: "GET",
            url: "/api/v1/ill/backends",
            success: function(backends){
                backends.sort((a, b) => a.ill_backend_id.localeCompare(b.ill_backend_id)).forEach(function(backend) {
                    $('#illfilter_backend').append(
                        '<option value="' + backend.ill_backend_id  +
                        // standard Koha:
                        //'">' + backend.ill_backend_id +  '</option>'
                        // LMSCloud Koha:
                        '">' + backendNameToDesignation(backend.ill_backend_id) +  '</option>'
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
