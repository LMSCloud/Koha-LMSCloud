<!-- ill-list-table-strings.inc -->
<script>
    var ill_manage = _("Manage request");
    var ill_manage_select_backend_first = _("Select a backend first");
    var ill_all_statuses = _("All statuses");

    var ill_statuses = {
        new: _("New request"),
        req: _("Requested"),
        genreq: _("Requested from partners"),
        rev: _("Reverted"),
        que: _("Queued request"),
        canc: _("Cancellation requested"),
        comp: _("Completed"),
        del: _("Delete request")
    };

    var ill_columns = {
        biblio_id: _("Bibliographic record ID"),
        updated: _("Updated on"),
        type: _("Type")
    };

    var ill_medium = {
        Book: _("Book"),
        Article: _("Article"),
        Journal: _("Journal"),
        Other: _("Other")
    };

    var ill_backend = {
        ILLALV: _("ALV"),
        ILLSLNPA: _("SLNP-active"),
        ILLSLNPKoha: _("SLNP-passive"),
        ILLZKSHA: _("RLV-active"),
        ILLZKSHP: _("RLV-passive"),
        PFL: _("PFL")
    };

    function translateStatusName (origName) {
        let ret = origName;
        switch( origName ) {
            case "New request":
                ret = ill_statuses.new;
            break;
            case "Requested":
                ret = ill_statuses.req;
            break;
            case "Requested from partners":
                ret = ill_statuses.genreq;
            break;
            case "Request reverted":
                ret = ill_statuses.rev;
            break;
            case "Queued request":
                ret = ill_statuses.que;
            break;
            case "Cancellation requested":
                ret = ill_statuses.canc;
            break;
            case "Completed":
                ret = ill_statuses.comp;
            break;
            case "Delete request":
                ret = ill_statuses.del;
            break;
        }

        return ret;
    };
</script>
<!-- / ill-list-table-strings.inc -->
