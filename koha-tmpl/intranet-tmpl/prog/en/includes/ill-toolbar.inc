[% USE Koha %]
[% IF Koha.Preference('ILLModule ') && CAN_user_ill %]
    <div id="toolbar" class="btn-toolbar">
        [% IF backends_available %]
          [% IF backends.size > 1 %]
            <div class="dropdown btn-group">
                <button class="btn btn-default dropdown-toggle" type="button" id="ill-backend-dropdown" data-toggle="dropdown" aria-haspopup="true" aria-expanded="true">
                    <i class="fa fa-plus"></i> New ILL request <span class="caret"></span>
                </button>
                <ul class="dropdown-menu" aria-labelledby="ill-backend-dropdown">
                    [% FOREACH backend IN backends %]
                        <li><a id="[% backend %]BackendNameInDropDown" href="/cgi-bin/koha/ill/ill-requests.pl?method=create&amp;backend=[% backend | uri %]">[% backend | html %]</a></li>
                    [% END %]
                </ul>
            </div>
          [% ELSE %]
            <a id="ill-new" class="btn btn-default" href="/cgi-bin/koha/ill/ill-requests.pl?method=create&amp;backend=[% backends.0 | html %]">
                <i class="fa fa-plus"></i> New ILL request
            </a>
          [% END %]
        [% ELSE %]
            <a id="ill-new" class="btn btn-default disabled" href="">
                <i class="fa fa-plus"></i> New ILL request
            </a>
        [% END %]
        <a id="ill-list_closed" class="btn btn-sm btn-default btn-group" href="/cgi-bin/koha/ill/ill-requests.pl?method=illlist&infilter=status,-in,COMP&hitname=Details for all completed requests">
            <i class="fa fa-list"></i> List completed requests
        </a>
        <a id="ill-list_all" class="btn btn-sm btn-default btn-group" href="/cgi-bin/koha/ill/ill-requests.pl?method=illlist&hitname=Details for all requests">
            <i class="fa fa-list"></i> List all requests
        </a>
        <a id="ill-list_open" class="btn btn-sm btn-default btn-group" href="/cgi-bin/koha/ill/ill-requests.pl?method=illlist&infilter=status,-not_in,COMP,QUEUED&hitname=Details for all open requests">
            <i class="fa fa-list"></i> List open requests
        </a>
        [% IF Koha.Preference('ILLALVSources') %]
          <a id="ill-list_open_ILLALV" class="btn btn-sm btn-default btn-group" href="/cgi-bin/koha/ill/ill-requests.pl?method=illlist&backend=ILLALV&amp;infilter=status,-not_in,COMP,QUEUED&hitname=Details for all open requests (ALV)">
              <i class="fa fa-list"></i> List open ALV requests
          </a>
        [% END %]
        [% IF Koha.Preference('ILLZKSHADeliverySlipCode') %]
          <a id="ill-list_open_ILLZKSHA" class="btn btn-sm btn-default btn-group" href="/cgi-bin/koha/ill/ill-requests.pl?method=illlist&backend=ILLZKSHA&amp;infilter=status,-not_in,COMP,QUEUED&hitname=Details for all open requests (RLV-active)">
              <i class="fa fa-list"></i> List open ZKSHA requests
          </a>
        [% END %]
        [% IF Koha.Preference('ILLZKSHPNotDeliveredLettercode') %]
          <a id="ill-list_open_ILLZKSHP" class="btn btn-sm btn-default btn-group" href="/cgi-bin/koha/ill/ill-requests.pl?method=illlist&backend=ILLZKSHP&amp;infilter=status,-not_in,COMP,QUEUED&hitname=Details for all open requests (RLV-passive)">
              <i class="fa fa-list"></i> List open ZKSHP requests
          </a>
        [% END %]
    </div>
[% END %]




<script type= "text/javascript">

    function backendNameToDesignation (backend_name) {
        var backend_designation = '';
        if ( backend_name ) {
            switch( backend_name ) {
                case "ILLALV":
                    backend_designation =  ill_backend.ILLALV;
                break;
                case "ILLSLNPA":
                    backend_designation =  ill_backend.ILLSLNPA;
                break;
                case "ILLSLNPKoha":
                    backend_designation =  ill_backend.ILLSLNPKoha;
                break;
                case "ILLZKSHA":
                    backend_designation =  ill_backend.ILLZKSHA;
                break;
                case "ILLZKSHP":
                    backend_designation =  ill_backend.ILLZKSHP;
                break;
                case "PFL":
                    backend_designation =  ill_backend.PFL;
                break;
                default:
                    backend_designation = backend_name;
            }
        }
        return backend_designation;
    };

    function updateBackendNamesInDropDown() {
        [% IF backends_available %]
            [% FOREACH backend IN backends %]
                var linkForCreateIllRequest = document.getElementById('[% backend %]BackendNameInDropDown');
                if ( linkForCreateIllRequest ) {
                    linkForCreateIllRequest.innerText = backendNameToDesignation ('[% backend %]');
                }
            [% END %]
        [% END %]
    };

    function mediumTypeToDesignation (medium, metadata_type) {
        var mediumType_designation = '';
        var mediumtype = metadata_type;
        if ( ! mediumtype ) {
            mediumtype = medium;
        }
        if ( mediumtype ) {
            switch( mediumtype ) {
                case "Book":
                    mediumType_designation =  ill_medium.Book;
                break;
                case "Article":
                    mediumType_designation =  ill_medium.Article;
                break;
                case "Journal":
                    mediumType_designation =  ill_medium.Journal;
                break;
                case "Other":
                    mediumType_designation =  ill_medium.Other;
                break;
                default:
                    mediumType_designation = mediumtype;
            }
        }
        return mediumType_designation;
    };

    function updateRequestType() {
        var requestTypeElement = document.getElementById('Request_type');
        [% type = request.get_type %]
        [% IF type %]
            var requestTypeText = '';
            if ( requestTypeElement ) {
                requestTypeText = '[% type | html %]';
                if ( requestTypeText ) {
                    requestTypeElement.innerText = requestTypeElement.innerText.replace(requestTypeText,mediumTypeToDesignation ('[% type %]', '[% type %]'));
                }
            }
        [% END %]
    };

    function updateDetailsFromSupplier() {
        var supplierDetailsHeader = document.getElementById('MetaDataSupplierDetailsHeader');
        var supplierDetailsHeaderText = '';
        if ( supplierDetailsHeader ) {
            supplierDetailsHeaderText = supplierDetailsHeader.innerText;
            if ( supplierDetailsHeaderText ) {
                supplierDetailsHeader.innerText = supplierDetailsHeaderText.replace('[% request.backend %]',backendNameToDesignation ('[% request.backend %]'));
            }
        }
        [% FOREACH requestmetadata IN request.metadata %]
            var labeltext = 'undef_labeltext';
            var requestmetadatakey = '[% requestmetadata.key %]';
            if ( requestmetadatakey ) {
                var labelId = 'labelForMetaData'.concat(requestmetadatakey);
                var labelHavingLabelId = document.getElementById(labelId);
                if ( labelHavingLabelId ) {
                    switch( requestmetadatakey ) {
                        case "author":
                            labeltext =  _("Author");
                        break;
                        case "ISBN":
                            labeltext =  _("ISBN");
                        break;
                        case "Order ID":
                            labeltext =  _("Order ID");
                        break;
                        case "ordererRemark":
                            labeltext =  _("Remark");
                        break;
                        case "title":
                            labeltext =  _("Title");
                        break;
                        case "checkedBy":
                            labeltext =  _("Checked by");
                        break;
                        case "isil":
                            labeltext =  _("ISIL");
                        break;
                        default:
                            labeltext =  requestmetadatakey;
                        break;
                    }
                    labelHavingLabelId.innerText = labeltext;
                }
            }
        [% END %]
    };

    function updateHitHeaderText() {
        var hitheader = document.getElementById('hitheader');
        var origHitheaderText = '';
        if ( hitheader ) {
            origHitheaderText = hitheader.innerText;
        }
        var newHitheaderText = 'undef';

        if ( hitheader && origHitheaderText ) {
            switch ( origHitheaderText ) {
                case 'Details for all completed requests':
                    newHitheaderText = _("Details for all completed requests");
                break;
                case 'Details for all requests':
                    newHitheaderText = _("Details for all requests");
                break;
                case 'Details for all open requests':
                    newHitheaderText = _("Details for all open requests");
                break;
                case 'Details for all open requests (ALV)':
                    newHitheaderText = _("Details for all open requests (ALV)");
                break;
                case 'Details for all open requests (RLV-active)':
                    newHitheaderText = _("Details for all open requests (RLV-active)");
                break;
                case 'Details for all open requests (RLV-passive)':
                    newHitheaderText = _("Details for all open requests (RLV-passive)");
                break;
                default:
                    newHitheaderText = origHitheaderText;
                break;
            }
            hitheader.innerText = newHitheaderText;
        }
    };

</script>
