(function ($) {
    var display = $.fn.dataTable.Responsive.display;

    /**
     * Responsive display function: like childRowImmediate, but removes the
     * detail row of a table row once none of its columns is collapsed any more.
     *
     * Responsive 3 (up to at least 3.0.7) keeps the previously drawn detail row
     * when the renderer has nothing to show, so columns hidden after the table
     * is drawn, or columns shown again after the viewport widens, stay listed
     * under the row. Responsive 2 removed that row.
     *
     * @param {DataTables.Api} row - The row being displayed.
     * @param {boolean} update - Whether this is an update of an existing display.
     * @param {Function} render - Returns the detail content, or false if there is none.
     * @returns {boolean} Whether a detail row is shown.
     *
     * @example
     * responsive: {
     *     details: {
     *         type: "column",
     *         target: -1,
     *         display: $.fn.dataTable.Responsive.display.childRowImmediateOrNone,
     *     },
     * }
     */
    display.childRowImmediateOrNone = function (row, update, render) {
        var shown = display.childRowImmediate(row, update, render);
        if (shown === false) {
            row.child(false);
        }
        return shown;
    };
})(jQuery);
