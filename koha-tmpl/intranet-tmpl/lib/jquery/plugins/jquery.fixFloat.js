/* Source: http://www.webspeaks.in/2011/07/new-gmail-like-floating-toolbar-jquery.html
   Revision: http://jsfiddle.net/pasmalin/AyjeZ/
*/
(function ($, window) {
    "use strict";
    $.fn.fixFloat = function (options) {
        var options = options || {};
        var tbh = $(this);
        var defaults = {
            enabled: true,
            originalOffset: tbh.position().top
        };
        var originalOffset = typeof options.originalOffset === 'undefined'
            ? defaults.originalOffset
            : options.originalOffset;
        options = $.extend(defaults, options);

        if (tbh.css('position') !== 'absolute') {
            var tbhBis = tbh.clone();
            tbhBis.css({
                "display": tbh.css("display"),
                    "visibility": "hidden"
            });
            tbhBis.width(tbh.outerWidth(true));
            tbhBis.height(tbh.outerHeight(true));
            tbh.after(tbhBis);
            tbh.width(tbh.width());
            var tbl = tbh.find("th,td");
            if (tbl.length > 0) {
                tbl.each(function () {
                    var $elt = $(this);
                    $elt.width($elt.outerWidth(true));
                });
            }
            tbh.css({
                'position': 'absolute',
                    'top': originalOffset
            });
        }

        if (options.enabled) {
            $(window).scroll(function () {
                var offsetTop = tbh.offset().top;
                var s = parseInt($(window).scrollTop(), 10);
                var fixMe = (s > offsetTop);
                var repositionMe = (s < originalOffset);
                if (fixMe) {
                    tbh.css({
                        'position': 'fixed',
                            'top': '0',
                        'z-index': '1000'
                    });
                    tbh.addClass("floating");
                }
                if (repositionMe) {
                    tbh.css({
                        'position': 'absolute',
                            'top': originalOffset,
                        'z-index': '1'
                    });
                    tbh.removeClass("floating");
                }
            });
        }
    };
})(jQuery, window);
