[%- USE Branches -%]
[%- USE Koha -%]
[%- USE To -%]
[%- USE ItemTypes -%]
[%- USE AuthorisedValues -%]
[%- biblio = item.biblio -%]
[%- biblioitem = item.biblioitem -%]
[
  "[% FILTER escape_quotes = replace('"', '\"') ~%]
    <input type="checkbox" name="itemnumber" value="[% item.itemnumber | html %]"/>
  [%~ END %]",
  "[% FILTER remove_special_character = replace('[\t\r\n\f\b]', '') ~%][% FILTER escape_quotes ~%]
    <a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=[% biblio.biblionumber | uri %]" title="Go to record detail page">[% biblio.title | html %]</a>[% IF ( Koha.Preference( 'marcflavour' ) == 'UNIMARC' && biblio.author ) %] by[% END %] [% biblio.author | html %]
  [%~ END %][%~ END %]",
  "[% (biblioitem.publicationyear || biblio.copyrightdate) | html | escape_quotes %]",
  "[% biblioitem.publishercode | html | escape_quotes | $To %]",
  "[% AuthorisedValues.GetDescriptionByKohaField( kohafield => 'items.ccode', authorised_value => item.ccode ) | html | escape_quotes %]",
  "[% FILTER escape_quotes ~%]
    <a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber=[% biblio.biblionumber | uri %]#item[% item.itemnumber | uri %]" title="Go to item details">[% item.barcode | html %]</a>
  [%~ END %]",
  "[% item.itemcallnumber | html | escape_quotes %]",
  "[% Branches.GetName(item.homebranch) | html | escape_quotes %]",
  "[% Branches.GetName(item.holdingbranch) | html | escape_quotes %]",
  "[% AuthorisedValues.GetDescriptionByKohaField( frameworkcode => biblio.frameworkcode, kohafield => 'items.location', authorised_value => item.location) | html | escape_quotes %]",
  "[% ItemTypes.GetDescription(item.itype) | html | escape_quotes %]",
  "[% item.stocknumber | html | escape_quotes %]",
  "[% AuthorisedValues.GetDescriptionByKohaField( frameworkcode => biblio.frameworkcode, kohafield => 'items.notforloan', authorised_value => item.notforloan) | html |  escape_quotes %]",
  "[% AuthorisedValues.GetDescriptionByKohaField( kohafield => 'items.itemlost', authorised_value => item.itemlost ) || "" | html | escape_quotes %]",
  "[% AuthorisedValues.GetDescriptionByKohaField( kohafield => 'items.withdrawn', authorised_value => item.withdrawn ) || "" | html | escape_quotes  %]",
  "[% (item.issues || 0) | html %]",
  "[% FILTER escape_quotes ~%]
    <div class="btn-group dropup"><button type="button" class="btn btn-xs btn-default dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"> <i class="fa fa-pencil"></i> Edit <span class="caret"></span> </button> <ul class="dropdown-menu pull-right"> <li><a href="/cgi-bin/koha/cataloguing/additem.pl?op=edititem&biblionumber=[% item.biblionumber | uri %]&itemnumber=[% item.itemnumber | uri %]">Edit item</a></li> <li><a href="/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=[% item.biblionumber | html %]">Edit record</a></li> </ul> </div>
  [%~ END %]"
]
