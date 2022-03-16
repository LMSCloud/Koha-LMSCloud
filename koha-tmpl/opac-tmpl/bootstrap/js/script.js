/* global enquire readCookie updateBasket delCookie */
enquire.register("screen and (max-width:608px)", {
    match : function() {
        if($("body.scrollto").length > 0){
            $("body.scrollto").animate({
                scrollTop: $(".maincontent").offset().top
            }, 10);
        }
    },
    unmatch : function() {
    }
});

enquire.register("screen and (min-width:768px)", {
    match : function() {
        facetMenu( "show" );
        furtherOfferingsMenu( "show" );
    },
    unmatch : function() {
        facetMenu( "hide" );
        furtherOfferingsMenu( "hide" );
    }
});

function furtherOfferingsMenu( action ){
    if( action == "show" ){
        $(".further-offerings-menu-collapse-toggle").unbind("click", furtherOfferingsHandler )
        $(".further-offerings-menu-collapse").show();
    } else {
        $(".further-offerings-menu-collapse-toggle").bind("click", furtherOfferingsHandler ).removeClass("further-offerings-menu-open");
        $(".further-offerings-menu-collapse").hide();
    }
}

var furtherOfferingsHandler = function(e){
    e.preventDefault();
    $(this).toggleClass("further-offerings-menu-open");
    $(".further-offerings-menu-collapse").toggle();
};

function facetMenu( action ){
    if( action == "show" ){
        $(".menu-collapse-toggle").unbind("click", facetHandler )
        $(".menu-collapse").show();
    } else {
        $(".menu-collapse-toggle").bind("click", facetHandler ).removeClass("menu-open");
        $(".menu-collapse").hide();
    }
}

var facetHandler = function(e){
    e.preventDefault();
    $(this).toggleClass("menu-open");
    $(".menu-collapse").toggle();
};

$(document).ready(function(){
    $(".close").click(function(){
        window.close();
    });
    $(".focus").focus();
    $(".js-show").show();
    $(".js-hide").hide();

    if( $(window).width() < 768 ){
        facetMenu("hide");
        furtherOfferingsMenu("hide");
    }

    // clear the basket when user logs out
    $("#logout").click(function(){
        var nameCookie = "bib_list";
        var valCookie = readCookie(nameCookie);
        if (valCookie) { // basket has contents
            updateBasket(0,null);
            delCookie(nameCookie);
            return true;
        } else {
            return true;
        }
    });
    $(".loginModal-trigger").on("click",function(e){
        e.preventDefault();
        $("#loginModal").modal("show");
    });
    $("#loginModal").on("shown.bs.modal", function(){
        $("#muserid").focus();
    });
    $(".link-collection-collapse-toggle").unbind("click");
    $(".link-collection-collapse-toggle").on("click",function(e){
        e.preventDefault();
        $(this).toggleClass("menu-open");
        $($(this).attr("href")).toggle();
    });
});

