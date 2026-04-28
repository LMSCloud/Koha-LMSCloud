# RELEASE NOTES FOR KOHA 25.11.03
07 Apr 2026

Koha is the first free and open source software library automation
package (ILS). Development is sponsored by libraries of varying types
and sizes, volunteers, and support companies from around the world. The
website for the Koha project is:

- [Koha Community](https://koha-community.org)

Koha 25.11.03 can be downloaded from:

- [Download](https://download.koha-community.org/koha-25.11.03.tar.gz)

Installation instructions can be found at:

- [Koha Wiki](https://wiki.koha-community.org/wiki/Installation_Documentation)
- OR in the INSTALL files that come in the tarball

Koha 25.11.03 is a bugfix/maintenance release.

It includes 13 enhancements, 68 bugfixes.

**System requirements**

You can learn about the system components (like OS and database) needed for running Koha on the [community wiki](https://wiki.koha-community.org/wiki/System_requirements_and_recommendations).


#### Security bugs

- [41261](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41261) XSS vulnerability in opac/unAPI
  >This change validates the inputs to "unapi" so that any invalid inputs will result in a 400 error or a response containing valid options for follow-up requests.
- [41594](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41594) Can access invoice-files.pl even when AcqEnableFiles is disabled
- [42048](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42048) Reflected XSS in patron search saved link

## Bugfixes

### Acquisitions

#### Other bugs fixed

- [41420](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41420) Syntax error in referrer in parcel.tt
  >This fixes the URL for the "Cancel order and catalog record" link when receiving an order for an invoice - the referrer section of the URL was missing.

### Architecture, internals, and plumbing

#### Critical bugs fixed

- [38426](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=38426) Node.js v18 EOL around 25.05 release time
- [41617](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41617) CSV export from item search results - incorrect spaces after comma separator causes issues
  >This fixes the CSV export from item search results in the staff interface (Search > Item search> Export select results (X) to CSV).
  >
  >It removes extra spaces after the comma separator, which causes issues when using the CSV file with some applications (such as Microsoft Excel).

#### Other bugs fixed

- [35423](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35423) AuthoritiesMarc: Warnings substr outside of string and Use of uninitialized value $type in string eq
- [41043](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41043) Use op 'add_form' and 'edit_form' instead of 'add' and 'edit'
- [41076](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41076) Perltidy config needs to be refined to not cause changes with perltidy 20250105
  >26.05.00
- [41268](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41268) Circulation rules script has many  conditionals
- [41287](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41287) Using locale sorting may have a negative impact on search speeds
  >This improves the performance for showing facets when using Elasticsearch, by adding another option "simple alphabetical" to sort facets to the FacetOrder system preference.
  >
  >This improves performance for English language libraries and will display the facets correctly in most cases, unless there are Unicode characters.
  >
  >(Technical note: 'stringwise' is basic alphanumeric sorting character by character - diacritics are largely ignored.)
- [41557](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41557) LoginFirstname, LoginSurname and emailaddress sent to template but never used
- [41560](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41560) Useless (and confusing) id attribute on a couple of script tag
  >Removes the id attribute from the script tag (<script id="js">) for two pages in the staff interface, as they are not needed.
  >
  >The two pages changed:
  >- 'Checkout history' section for a record
  >- 'Circulation history' for a patron
- [41561](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41561) "tab" variable in admin/aqbudgetperiods.pl,tt is not used and should be removed
- [41701](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41701) Fix definition of OAI-PMH:DeletedRecord preference in sysprefs.sql

  **Sponsored by** *Athens County Public Libraries*
- [41747](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41747) xt/js_tidy is failing on ill js files

### Authentication

#### Other bugs fixed

- [33782](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=33782) OAuth2/OIDC identity providers code is not covered by unit tests

### Cataloging

#### Other bugs fixed

- [34879](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=34879) ./catalogue/getitem-ajax.pl appears to be unused
- [41475](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41475) 500 error when placing a hold on records with multiple 773 entries
- [41588](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41588) Link from 856$u breaks with leading or trailing spaces
  >If a 856$u for a record had spaces before or after the URL, the link shown on the record page on the OPAC and staff interface (under 'Online resources') did not work.
  >
  >Depending on the browser, either nothing happened, or an error was shown that the site wasn't reachable.
  >
  >Examples that previously caused links not to work (without the quotes):
  >- " koha-community.org"
  >- "koha-community.org "
  >- " koha-community.org "

### Circulation

#### Other bugs fixed

- [40134](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40134) Fix and optimise 'Any item' functionality of bookings
- [41035](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41035) bundle_remove click handler in returns.tt has invalid path component "item"
- [41055](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41055) Missing accesskey attribute for print button (shortcut P)

  **Sponsored by** *Koha-Suomi Oy*
- [41457](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41457) Hold history table does not deal with column visibility correctly

### Command-line Utilities

#### Critical bugs fixed

- [41315](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41315) Using patron-homelibrary option for overdue notices may not send notices to all branches

### ERM

#### Other bugs fixed

- [41120](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41120) Click on New data provider breaks functionality
  >This fixes adding a new data provider after creating a new data provider (ERM > eUsage > Data providers > New data provider).
  >
  >If you created a new data provider, clicked close after the information about the provider was shown, then went to add another new data provider - nothing happened: you got an empty page, and there was an error in the browser developer tools console.

### Hold requests

#### Critical bugs fixed

- [41781](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41781) Holds queue builder ( build_holds_queue.pl ) fails if HoldsQueueParallelLoopsCount is greater than 1

### I18N/L10N

#### Other bugs fixed

- [41689](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41689) "Staff note" and "OPAC" message types in patron files untranslatable

### ILL

#### Other bugs fixed

- [41204](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41204) OpenURL ILL no longer defaults to Standard if FreeForm
- [41465](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41465) Unauthenticated request does not display 'type' correctly
- [41478](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41478) AutoILLBackendPriority - Unauthenticated request shows backend form if wrong captcha
- [41512](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41512) ILLCheckAvailability stage table doesn't render
  >This fixes creating ILL requests when the ILLCheckAvailability system preference is used - the checking for availability was not completed and the table was not shown.

### Notices

#### Other bugs fixed

- [28308](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=28308) Select 'Days in advance' = 0 for Advance notice effectively disables PREDUE notices
- [39781](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39781) Cannot limit by library when creating custom patron email sent via patron details page
  >This patch updates the Add Message interface in the patron record such that the dropdown for selecting a notice template when sending email or SMS messages will only list notices for all libraries or for the user's logged-in library. Messages using a template for a specific library will now enqueue successfully.
- [40960](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40960) Only generate a notice for patrons about holds filled if they have set messaging preferences
  >Currently, if a patron has not set any messaging preferences for notifying them about holds filled, a print notice is still generated.
  >
  >With this change, a notice is now only generated for a patron if their messaging preferences for 'Hold filled' are set. This matches the behavor for overdue and hold reminder notices.
- [42083](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42083) Email and SMS messages from patron record should have distinct permissions
  >This patch removes the 'send_messages_to_borrowers' permission and replaces it with 'send_messages_to_borrowers_email' and 'send_messages_to_borrowers_sms,' allowing users to be limited to sending either email or SMS messages from a patron record. At update, users who previously had 'send_messages_to_borrowers' permission will be given only 'send_messages_to_borrowers_email,' as SMS messages are a new functionality on 26.05 and not something to which users previously had access.

### OPAC

#### Other bugs fixed

- [23308](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=23308) Contents of "OpacMaintenanceNotice" HTML escaped on display
- [40822](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40822) Custom cover images not displayed in search results

### Patrons

#### Other bugs fixed

- [29768](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=29768) hidepatronname hides guarantor name on borrower edit screen
  >If the `hidepatronname` system preference was set to "Don't show" it hid the guarantor's name when:
  >- editing the guarantee's patron record (it shows the guarantor patron's card number)
  >- viewing the guarantee patron's details page
  >
  >With this change, you can now see the guarantor's name in these areas.
  >
  >As this information is viewable by clicking the card number, it doesn't make much sense to hide the patron name for guarantors and guarantees.

  **Sponsored by** *Koha-Suomi Oy*
- [36360](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36360) Link ILL requests to surviving patron record when patrons are merged
- [41040](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41040) Empty patron search from the header should not trigger a patron search
  >This fixes the "Search patrons" option in the staff interface menu bar. Currently, clicking "Search patrons" and then the arrow (without entering a value) automatically performs a search.
  >
  >With this change, a patron search is now no longer automatic. If you don't enter anything, or don't select any options, you are now prompted (using a tooltip) to enter a patron name or card number.
  >
  >NOTE: This is a change in behavour from what you may be used to.
- [41752](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41752) Guarantor first name and guarantor surname mislabeled in system preferences

### Plugin architecture

#### Critical bugs fixed

- [41684](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41684) notices_content hook is not checking if individual plugins are enabled and is reloading plugins

### REST API

#### Other bugs fixed

- [41700](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41700) Checkouts note_date has incorrect format in swagger definitions

### SIP2

#### Other bugs fixed

- [41458](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41458) SIP passes UID instead of GID to Net::Server causing error
  >This fixes an error that may occur when starting the SIP server: "...Couldn't become gid "<uid>": Operation not permitted...". Koha was passing an incorrect value to the Net::Server "group" parameter.

### Searching - Elasticsearch

#### Critical bugs fixed

- [40966](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40966) 'whole_record' and 'weighted_fields' not passed around

### Serials

#### Other bugs fixed

- [36136](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36136) Flatpickr allows selecting date from the past on copied serial subscriptions
- [36466](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36466) Incorrect date value stored when "Published on" or "Expected on" are empty
  >Editing a serial and removing the dates in the "Published on" and "Expected on" fields generated a 500 error (Serials > [selected serial] > Serial collection).
  >
  >This fixes the error and:
  >- Sets the data in the database to NULL
  >- Shows the dates as "Unknown" in the serial collection table for the "Date published" and "Date received" columns
  >- Changes any existing 0000-00-00 dates in the database to NULL (for existing installations)

### Staff interface

#### Critical bugs fixed

- [41798](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41798) Cannot enable 'passive' mode in File Transports for FTP

#### Other bugs fixed

- [41422](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41422) New FilterSearchResultsByLoggedInBranch doesn't fully translate
  >This fixes the translatability of the text shown when the FilterSearchResultsByLoggedInBranch system preference is enabled, and also the check and what is shown only works when not translated.
- [41679](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41679) Stock rotation repatriation modal can conflict with holds modal

### System Administration

#### Critical bugs fixed

- [41431](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41431) Circulation rule notes dropping when editing rule
  >This fixes editing circulation and fine rules with notes - notes are now correctly shown when editing, and are not lost when saving the rule.
  >
  >Previously, if you edited a rule with a note, it was not displayed in the edit field and was removed when the rule was saved.

  **Sponsored by** *Koha-Suomi Oy*

#### Other bugs fixed

- [19690](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=19690) Smart rules: Term "If any unavailable" is confusing

### Task Scheduler

#### Other bugs fixed

- [37402](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=37402) Task scheduling fails if you don't use the correct time format

### Templates

#### Other bugs fixed

- [32285](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=32285) Punctuation: Completeness of the reproduction code␠:, ...
  >This removes spaces before the colons for the unimarc_field_325h.pl and unimarc_field_325j.pl value builder form field labels.
- [32288](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=32288) Capitalization: RDA Carrier, etc.

  **Sponsored by** *Athens County Public Libraries*
- [40703](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40703) Replace data-toggle by data-bs-toggle
- [41340](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41340) Better translatability on 'batch_item_record_modification.inc'
- [41347](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41347) Terminology: Item had a reserve waiting
  >This fixes the terminology for two log viewer messages:
  >- "Item had a reserve waiting" to "Hold waiting on item"
  >- "Item was reserved" to "Hold placed on item"
- [41586](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41586) Spacing problem in display of patron names

  **Sponsored by** *Athens County Public Libraries*
- [41764](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41764) ISSN hidden input missing from Z39.50 search form navigation
  >This fixes the Acquisitions and Cataloging Z39.50 search forms so that the pagination works when searching using the ISSN input field.
  >
  >When you click the next page of results, or got to a specific result page, the search now works as expected - it remembers the ISSN you were searching for, with "You searched for: ISSN: XXXX" shown above the search results, and search results shown.
  >
  >Previously, the ISSN was not remembered, and "Nothing found. Try another search." was shown, and no further search results were shown.

  **Sponsored by** *Athens County Public Libraries*

### Test Suite

#### Critical bugs fixed

- [41682](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41682) Syspref discrepancies between new and upgraded installs
  >This fixes several system preferences discrepancies and adds tests, including:
  >
  >* Setting options to NULL when options=""
  >* Fixing the explanation when different
  >* Fixing the wrong order (some rows had options=explanation)
  >* Fixing the wrong type "Yes/No" => "YesNo"
  >* Removed StaffLoginBranchBasedOnIP: both StaffLoginLibraryBasedOnIP and StaffLoginBranchBasedOnIP are in the database for upgraded installs
  >* Adding a description for ApiKeyLog
  >* Fixing 'integer' vs. 'Integer' inconsistency
  >* Fixing 'cancelation' typo
  >* Improving the tests:
  >  * Compare sysprefs.sql and the database content for options, explanation and type
  >  * Catch type not defined
  >  * Catch incorrect YesNo values (must be 0 or 1)
  >
  >An example where discrepancies have crept in during upgrades includes warnings in the About Koha > System information - the system preferences had no value (either 1 or 0) in the 'value' field:
  >* Warning System preference 'ILLHistoryCheck' must be '0' or '1', but is ''.
  >* Warning System preference 'ILLOpacUnauthenticatedRequest' must be '0' or '1', but is ''.
  >* Warning System preference 'SeparateHoldingsByGroup' must be '0' or '1', but is ''.

#### Other bugs fixed

- [39745](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39745) Wrong system preference 'language' in test suite
  >This fixes several tests so that the correct system preference names are used:
  >- language => StaffInterfaceLanguages (name changed in bug 27490) 
  >- opaclanguages => OPACLanguages (name now uses the correct case)
- [40946](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40946) "Aborted connection 42 to db" from Koha/Z3950Responder/ZebraSession.t
- [40947](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40947) "Aborted connection 42 to db" from t/db_dependent/www/search_utf8.t
- [41449](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41449) Reserves.t may fail when on shelf holds are restricted
- [41710](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41710) SearchEngine/Elasticsearch/Search.t does not rollback properly

### Tools

#### Other bugs fixed

- [41163](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41163) Circulation logs record issuing branch in database but show logged-in branch in log viewer

## Enhancements 

### Cataloging

#### Enhancements

- [40031](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40031) Creation of a new MARC modification template should redirect to have the template ID in the URL
  >This updates the URL when adding a new MARC modification template (Cataloging > Batch editing > MARC modification templates). It adds the template ID to the URL so that you can directly link to the template.
  >
  >Previously, you had to click `Edit actions` from the list of templates, and couldn't directly link to the template to see the actions:
  >- Previous URL after adding a template:
  >   STAFF-INTERFACE-URL/cgi-bin/koha/tools/marc_modification_templates.pl
  >- New URL after adding a template: 
  >   STAFF-INTERFACE-URL/cgi-bin/koha/tools/marc_modification_templates.pl?template_id=(template_id)&op=select_template
- [40154](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40154) Deleting an item does not warn about an item level hold

  **Sponsored by** *Koha-Suomi Oy*

### Circulation

#### Enhancements

- [41539](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41539) Include item barcode in waiting hold message on patron record
  >This enhancement adds the item barcode to the holds waiting information on a patron's check out and details page.
  >
  >This makes it easier for circulation staff to copy the barcode to check the item out when a patron picks it up (where this is the library workflow and a self-service option is not available.
  >
  >Before: Title (Item type), Author. Hold place on DD-MM-YY
  >After:  Title (Item type), Author. (Barcode) Hold place on DD-MM-YY

### Hold requests

#### Enhancements

- [40769](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40769) Highlight hold fees when placing a hold from the staff interface
  >This enhancement adds hold fee information display in the staff interface's hold
  >request interface, bringing it to feature parity with the OPAC.
  > 
  >The OPAC already shows patrons the fee that will be charged for placing
  >a hold, but the staff interface did not display this information when staff
  >place holds on behalf of patrons. This creates a transparency gap where
  >staff cannot inform patrons about potential charges.

### ILL

#### Enhancements

- [41281](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41281) ILL request metadata doesn't show if falsy

### OPAC

#### Enhancements

- [41655](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41655) Local OPAC covers are not displayed in OPAC lists
  >This fixes a regression where the local cover images were no longer displayed in lists in the OPAC and staff interface. With this fix, the local cover images are back in the lists in both interfaces.

### SIP2

#### Enhancements

- [41214](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41214) Cash register should only show if UseCashRegisters sys pref is enabled
  >This change turns the display of the 'cash register' field in SIP2 accounts to become conditional depending on whether the UseCashRegisters sys pref is enabled or not.
  >For developers: This changes the hideIn option for VueJS framework resources, now allowing it to be a callback function which is checked in real-time, dictating whether a field is displayed or not.

### Staff interface

#### Enhancements

- [40933](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40933) Add SMS support under Add message feature
  >This new feature allows staff with appropriate permissions, `send_messages_to_borrowers`, to send SMS messages patrons from the patron details pages.
  >
  >Notice templates can be defined, and used for defaults, using the `Patrons (custom message)` module.
- [41206](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41206) Add collection to transfers to receive

### Templates

#### Enhancements

- [39715](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39715) Do not quote DataTables options
  >This patch updates templates so that the options passed to DataTables, via KohaTable, are not quoted. The quotes are not necessary, and are not consistent with official DataTables documentation. This establishes a standard for us to follow in the future.

  **Sponsored by** *Athens County Public Libraries*
- [41350](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41350) Terminology: Biblio was already issued
  >This changes the log viewer message "Biblio was already issued" to "An item from this bibliographic record is already checked out."
  >
  >This action is recorded in the logs when `AllowMultipleIssuesOnABiblio` is set to "Don't allow" and staff confirm a check-out where a patron has already checked out another item for the record.

  **Sponsored by** *Athens County Public Libraries*
- [41677](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41677) Use template wrapper for tabs: OAI repositories

  **Sponsored by** *Athens County Public Libraries*

### Tools

#### Enhancements

- [40905](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40905) Past unique holidays not shown when enabling Show past checkbox

## Documentation

The Koha manual is maintained in Sphinx. The home page for Koha
documentation is

- [Koha Documentation](https://koha-community.org/documentation/)
As of the date of these release notes, the Koha manual is available in the following languages:

- [English (USA)](https://koha-community.org/manual/25.11/en/html/)
- [French](https://koha-community.org/manual/25.11/fr/html/) (80%)
- [German](https://koha-community.org/manual/25.11/de/html/) (89%)
- [Greek](https://koha-community.org/manual/25.11/el/html/) (93%)
- [Hindi](https://koha-community.org/manual/25.11/hi/html/) (63%)

The Git repository for the Koha manual can be found at

- [Koha Git Repository](https://gitlab.com/koha-community/koha-manual)

## Translations

Complete or near-complete translations of the OPAC and staff
interface are available in this release for the following languages:
<div style="column-count: 2;">

- Arabic (ar_ARAB) (90%)
- Armenian (hy_ARMN) (100%)
- Bulgarian (bg_CYRL) (100%)
- Chinese (Simplified Han script) (82%)
- Chinese (Traditional Han script) (95%)
- Czech (66%)
- Dutch (85%)
- English (100%)
- English (New Zealand) (60%)
- English (USA)
- Finnish (99%)
- French (100%)
- French (Canada) (97%)
- German (99%)
- Greek (64%)
- Hindi (93%)
- Italian (80%)
- Norwegian Bokmål (69%)
- Persian (fa_ARAB) (91%)
- Polish (99%)
- Portuguese (Brazil) (99%)
- Portuguese (Portugal) (86%)
- Russian (91%)
- Slovak (58%)
- Spanish (96%)
- Swedish (89%)
- Telugu (64%)
- Turkish (79%)
- Ukrainian (73%)
- Western Armenian (hyw_ARMN) (59%)
</div>

Partial translations are available for various other languages.

The Koha team welcomes additional translations; please see

- [Koha Translation Info](https://wiki.koha-community.org/wiki/Translating_Koha)

For information about translating Koha, and join the koha-translate 
list to volunteer:

- [Koha Translate List](https://lists.koha-community.org/cgi-bin/mailman/listinfo/koha-translate)

The most up-to-date translations can be found at:

- [Koha Translation](https://translate.koha-community.org/)

## Release Team

The release team for Koha 25.11.03 is


- Release Manager: Lucas Gass

- QA Manager: Martin Renvoize

- QA Team:
  - Marcel de Rooy
  - Martin Renvoize
  - Jonathan Druart
  - Laura Escamilla
  - Lucas Gass
  - Tomás Cohen Arazi
  - Lisette Scheer
  - Nick Clemens
  - Paul Derscheid
  - Emily Lamancusa
  - David Cook
  - Matt Blenkinsop
  - Andrew Fuerste-Henry
  - Brendan Lawlor
  - Pedro Amorim
  - Kyle M Hall
  - Aleisha Amohia
  - David Nind
  - Baptiste Wojtkowski
  - Jan Kissig
  - Katrin Fischer
  - Thomas Klausner
  - Julian Maurice
  - Owen Leonard

- Documentation Manager: David Nind

- Documentation Team:
  - Philip Orr
  - Aude Charillon
  - Caroline Cyr La Rose

- Translation Manager: Jonathan Druart


- Wiki curators: 
  - George Williams
  - Thomas Dukleth

- Release Maintainers:
  - 25.11 -- Jacob O'Mara
  - 25.05 -- Laura Escamilla
  - 24.11 -- Fridolin Somers
  - 22.11 -- Wainui Witika-Park (Catalyst IT)

- Release Maintainer assistants:
  - 25.11 -- Chloé Zermatten
  - 24.11 -- Baptiste Wojtkowski
  - 22.11 -- Alex Buckley & Aleisha Amohia

## Credits

We thank the following libraries, companies, and other institutions who are known to have sponsored
new features in Koha 25.11.03
<div style="column-count: 2;">

- Athens County Public Libraries
- [Koha-Suomi Oy](https://koha-suomi.fi)
</div>

We thank the following individuals who contributed patches to Koha 25.11.03
<div style="column-count: 2;">

- Pedro Amorim (12)
- Tomás Cohen Arazi (10)
- Matt Blenkinsop (2)
- Connor Cameron-Jones (1)
- Nick Clemens (11)
- David Cook (4)
- Paul Derscheid (2)
- Jonathan Druart (22)
- Andrew Fuerste-Henry (9)
- Lucas Gass (5)
- Ayoub Glizi-Vicioso (1)
- Raguram Gopinath (1)
- Kyle M Hall (6)
- Olli Kautonen (1)
- Aya Khallaf (1)
- Jan Kissig (1)
- Owen Leonard (11)
- David Nind (2)
- Jacob O'Mara (7)
- Photonyx (1)
- Martin Renvoize (12)
- Marcel de Rooy (2)
- Slava Shishkin (3)
- Fridolin Somers (3)
- Adam Styles (1)
- Emmi Takkinen (2)
- Lari Taskula (2)
- Hammat Wele (5)
- Baptiste Wojtkowski (3)
- Chloe Zermatten (1)
</div>

We thank the following libraries, companies, and other institutions who contributed
patches to Koha 25.11.03
<div style="column-count: 2;">

- Athens County Public Libraries (11)
- [BibLibre](https://www.biblibre.com) (6)
- [ByWater Solutions](https://bywatersolutions.com) (31)
- David Nind (2)
- esa.edu.au (1)
- [Hypernova Oy](https://www.hypernova.fi) (2)
- Independant Individuals (7)
- Koha Community Developers (22)
- [Koha-Suomi Oy](https://koha-suomi.fi) (2)
- [LMSCloud](https://www.lmscloud.de) (2)
- myy.haaga-helia.fi (1)
- [OpenFifth](https://openfifth.co.uk) (34)
- [Prosentient Systems](https://www.prosentient.com.au) (4)
- Rijksmuseum, Netherlands (2)
- [Solutions inLibro inc](https://inlibro.com) (6)
- [Theke Solutions](https://theke.io) (10)
- Wildau University of Technology (1)
</div>

We also especially thank the following individuals who tested patches
for Koha
<div style="column-count: 2;">

- Pedro Amorim (2)
- Tomás Cohen Arazi (4)
- Charlie Arthur (1)
- Matt Blenkinsop (2)
- Richard Bridgen (4)
- Connor Cameron-Jones (1)
- Nick Clemens (5)
- Ben Daeuber (4)
- Paul Derscheid (5)
- Roman Dolny (3)
- Jonathan Druart (13)
- Laura Escamilla (6)
- Katrin Fischer (7)
- Andrew Fuerste-Henry (8)
- Lucas Gass (119)
- Ayoub Glizi-Vicioso (1)
- Kyle M Hall (26)
- Harrison Hawkins (1)
- Juliet Heltibridle (5)
- Olli Kautonen (1)
- Jan Kissig (2)
- Kristi Krueger (4)
- Brendan Lawlor (1)
- Owen Leonard (17)
- Manvi (1)
- David Nind (46)
- Jacob O'Mara (109)
- Leo O’Neill (1)
- Eric Phetteplace (1)
- Martin Renvoize (14)
- Marcel de Rooy (9)
- Lisette Scheer (5)
- Emmi Takkinen (2)
- Baptiste Wojtkowski (1)
- Chloe Zermatten (27)
- Anneli Österman (1)
</div>





We regret any omissions.  If a contributor has been inadvertently missed,
please send a patch against these release notes to koha-devel@lists.koha-community.org.

## Revision control notes

The Koha project uses Git for version control.  The current development
version of Koha can be retrieved by checking out the main branch of:

- [Koha Git Repository](https://git.koha-community.org/koha-community/koha)

The branch for this version of Koha and future bugfixes in this release
line is 25.11.x-security.

## Bugs and feature requests

Bug reports and feature requests can be filed at the Koha bug
tracker at:

- [Koha Bugzilla](https://bugs.koha-community.org)

He rau ringa e oti ai.
(Many hands finish the work)

Autogenerated release notes updated last on 07 Apr 2026 14:28:57.
