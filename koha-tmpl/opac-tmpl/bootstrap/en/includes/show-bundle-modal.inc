[% INCLUDE 'js-biblio-format.inc' %]
<script>
    String.prototype.escapeHtml = function() {
        return this.replace(/[&<>]/g, function(c) {
            return HtmlCharsToEscape[c] || c;
        });
    };
    function escape_str(s){
        return s != null ? s.escapeHtml() : "";
    }
    $(".show_bundle_items_link").click(function(){
        showBundleItems($(this).data("itemnumber"));
    });
    var bundleItemlistModalPopupTemplate = $(
        '<div id="bundleItemlistModal" class="modal">' +
        '  <div class="modal-dialog modal-lg" role="document">' +
        '    <div class="modal-content">' +
        '      <div class="modal-header">' +
        '        <h3>Media bundle</h3>' +
        '        <button type="button" class="bundleItemlistModal_close closebtn" data-dismiss="modal" aria-hidden="true">&times;</button>' +
        '      </div>' +
        '      <div class="modal-body">' +
        '        <div id="bundleitemslistnotfound" style="display:none">' +
                     _("The media bundle as currently no media items assigned to it.") + 
        '        </div>' + 
        '        <table id="bundleitemslisttable" class="table table-bordered table-striped" width="100%">' +
        '        </table>' +
        '      </div>' +
        '      <div class="modal-footer">' +
        '        <button type="button" class="btn btn-small btn-default bundleItemlistModal_close" data-dismiss="modal" rel="modal:close">' + _('Close') + '</button>' +
        '      </div>' +
        '    </div>' +
        '  </div>' +
        '</div>');
    $('body').append(bundleItemlistModalPopupTemplate);
    
    var bundleitemslisttable;
        
    function showBundleItems (itemnumber) {
        var rows = new Array();
        $.ajax({
            url: "/api/v1/public/items/" + itemnumber + "/bundled_items",
            type: "GET",
            headers: { 'x-koha-embed': "biblio", "Accept": "application/json" },
            data: { 
                "_page": 1, 
                "_per_page": 1000, 
                "_match": "contains",
                "_order_by": "+biblio.title"
            },
            success: function (data) {
                if ( Array.isArray(data) && data.length > 0 ) {
                    for (let i = 0; i < data.length; i++) {
                        var tableRow = [];
                        tableRow[0] = $biblio_to_html(data[i].biblio, { link: 1 });
                        tableRow[1] = data[i].biblio.author;
                        tableRow[2] = data[i].biblio.copyright_date
                        tableRow[3] = data[i].external_id;
                        tableRow[4] = data[i].callnumber;
                        rows.push(tableRow);
                    }
                }
                $('#bundleItemlistModal').show();
                $('#bundleItemlistModal').modal();
                
                if (! $.fn.DataTable.isDataTable('#bundleitemslisttable') ) {
                    bundleitemslisttable = $('#bundleitemslisttable').dataTable($.extend(true, {}, dataTablesDefaults, {
                        "searching": true,
                        "paging": false,
                        "data": rows,
                        "responsive": {
                            "details": false
                        },
                        "columnDefs": [
                            {
                                targets: [0],
                                "width": '50%',
                                responsivePriority: 1,
                                "title": _("Title"),
                                "searchable": true,
                                "orderable": true,
                            },
                            {
                                targets: [1],
                                responsivePriority: 2,
                                "title": _("Author"),
                                "searchable": true,
                                "orderable": true,
                            },
                            {
                                targets: [2],
                                responsivePriority: 5,
                                "title": _("Year"),
                                "searchable": true,
                                "orderable": true,
                            },
                            {
                                targets: [3],
                                responsivePriority: 3,
                                "title": _("Barcode"),
                                "searchable": true,
                                "orderable": true,
                            },
                            {
                                targets: [4],
                                responsivePriority: 4,
                                "title": _("Callnumber"),
                                "searchable": true,
                                "orderable": true,
                            }
                        ]
                    }));
                } else {
                    var tableAPI = bundleitemslisttable.DataTable();
                    tableAPI.clear();
                    tableAPI.rows.add( rows ).draw();
                }
                if ( rows.length > 0 ) {
                    $('#bundleitemslistnotfound').hide();
                    $('#bundleitemslisttable').show();
                } else {
                    $('#bundleitemslistnotfound').show();
                    $('#bundleitemslisttable').hide();
                }
            }
        });
    }
</script>
