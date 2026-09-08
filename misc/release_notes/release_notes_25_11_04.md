# RELEASE NOTES FOR KOHA 25.11.04
22 Apr 2026

Koha is the first free and open source software library automation
package (ILS). Development is sponsored by libraries of varying types
and sizes, volunteers, and support companies from around the world. The
website for the Koha project is:

- [Koha Community](https://koha-community.org)

Koha 25.11.04 can be downloaded from:

- [Download](https://download.koha-community.org/koha-25.11.04.tar.gz)

Installation instructions can be found at:

- [Koha Wiki](https://wiki.koha-community.org/wiki/Installation_Documentation)
- OR in the INSTALL files that come in the tarball

Koha 25.11.04 is a bugfix/maintenance release.

It includes 21 enhancements, 60 bugfixes.

**System requirements**

You can learn about the system components (like OS and database) needed for running Koha on the [community wiki](https://wiki.koha-community.org/wiki/System_requirements_and_recommendations).


#### Security bugs

- [34000](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=34000) Don't allow auto-generated cardnumbers to be re-used, it may give access of services to the next patron created
- [42136](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42136) User-entered Template::Toolkit allows information disclosure
- [42252](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42252) Stored XSS when deleting a list or removing a list share
- [42253](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42253) Stored XSS in advanced editor in Macro name
- [42254](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42254) DOM XSS via tag search
- [42366](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42366) debug_mode 0 and debug_mode 1 enable debug mode

## Bugfixes

### Architecture, internals, and plumbing

#### Critical bugs fixed

- [38384](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=38384) General fix for plugins breaking database transactions
- [41857](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41857) Suggestions table actions broken (Update manager and Delete selected)
  >This fixes errors that are generated when selecting a suggestion in the staff interface and:
  >- Updating the manager for the suggestion (Update manager > [select manager] > Submit)
  >- Deleting the suggestion (Delete selected > Submit)
  >
  >(Related to changes made by Bug 39721 - Remove GetSuggestion from C4/Suggestions.pm, added in Koha 26.05.)
- [42071](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42071) Suggestion does not load when viewing the suggestion
  >This fixes suggestion details not showing when you click the title in the staff interface suggestions management table.
  >
  >(Related to changes made by Bug 41857 - Suggestions table actions broken (Update manager and Delete selected), added in Koha 26.05.)
- [42098](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42098) EDIFACT edi_cron.pl runs disabled plugins due to bug in Koha::Plugins::Handler::run
  >Closes a loophole in our plugin handler that meant that some plugin methods may have run even when the plugin was marked as disabled.
- [42353](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42353) Tell which version of node to use

#### Other bugs fixed

- [30803](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=30803) output_error should not assume a 404 status
  >This change fixes the output_error function so that it requires a numeric input.
- [39606](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39606) Cover change from bug 39294 with a Cypress test
  >This adds Cyress tests for staging MARC records for import.
- [41036](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41036) Koha::ImportBatch is not logging errors
- [41587](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41587) node audit identified several vulnerable node dependencies
  >Fix node dependency security vulnerabilities by upgrading packages and adding yarn resolutions. The following packages were updated:
  >
  >Direct dependency upgrades:
  >- gulp-exec from ^4.0.0 to ^5.0.0 (fixes lodash.template HIGH vulnerability)
  >- lodash from ^4.17.12 to ^4.17.23 (MODERATE)
  >- minimatch from ^3.0.2 to ^3.1.4 (HIGH)
  >
  >Yarn resolutions added to pin secure versions of transitive dependencies:
  >- form-data ^2.5.4 (CRITICAL)
  >- fast-xml-parser ^4.5.4 (CRITICAL)
  >- braces ^3.0.3 (HIGH)
  >- qs ^6.14.1 (HIGH)
  >- serialize-javascript ^7.0.3 (HIGH)
  >- micromatch ^4.0.8 (MODERATE)
  >- @cypress/request ^3.0.0 (MODERATE)
  >- js-yaml ^4.1.1 (MODERATE)
  >- undici ^6.23.0 (MODERATE)
  >
  >This brings in upstream security fixes for critical, high, and moderate severity vulnerabilities reported by yarn audit. No functional changes are expected in Koha beyond those provided by the updated dependencies.
- [41599](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41599) reports/acquisitions_stats.pl calls output_error incorrectly
  >Fixes acquisitions_stats.pl so it returns a 403 code if a user tries to send a malicious payload.
- [41864](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41864) (Bug 40966 follow-up) Simple OPAC search generates warnings: Odd number of elements in anonymous hash

  **Sponsored by** *Ignatianum University in Cracow*
- [41916](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41916) SIP2 module cypress tests failing
  >26.05.00

### Cataloging

#### Other bugs fixed

- [40306](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40306) Use GET in form of value_builder/unimarc_field_4XX.pl
  >This fixes searching for terms when using the unimarc_field_4XX.pl value builder. The 'Start search' button now works, instead of doing nothing. (UNIMARC instances.) (This is related to the CSRF changes added in Koha 24.05 to improve form security.)
- [40711](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40711) Fix value builder for 181 in UNIMARC
  >Fixes the value builder for UNIMARC 181$c and 181$2:
  >- 181$c: now inserts the correct codes from the dropdown list (previously, it would populate the field with incorrect values - choosing cri would not add a value, crm would insert an a as the value)
  >- 181$2: now uses the correct HTML body ID (previously it was cat_unimarc_field_182-2, now it is cat_unimarc_field_181-2)
- [41417](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41417) 500 error when creating new authorized values from additem.pl

### Circulation

#### Other bugs fixed

- [41058](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41058) Using Show Checkouts button when LoadCheckoutsTableDelay is set causes collision/error. loadIssuesTableDelayTimeoutId  not assigned
  >This fixes an error message when viewing the checkouts table for patrons, under the patron's check out section in the staff interface, where:
  >- the LoadCheckoutsTableDelay system preference is set (greater than zero)
  >- "Always show checkouts automatically" is selected
  >
  >Clicking "Show checkouts" when "Checkouts table will show automatically in X seconds..." is shown resulted in a pop-error message, after the table with the list of checkouts was shown:
  >  Something went wrong when loading the table
  >  200: OK.
- [41131](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41131) Libaray transfer limits basic editor allows one to prevent transfers from a library to itself and block related holds
- [41518](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41518) "Scheduled for automatic renewal" displays even if patron does not allow automatic renewals
  >This change makes the "Scheduled for automatic renewal" text only appear in the renew column of checkouts table in the staff interface and OPAC when the item will actually be considered for automatic renewal.
  >
  >The text was showing, even if the item would not automatically be renewed due to automatic renewals being disallowed at the patron level.
  >
  >This now matches the criteria that misc/cronjobs/automatic_renewals.pl uses for processing automatic renewals.
- [41886](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41886) Biblio::check_booking counts checkouts on non-bookable items causing false clashes

  **Sponsored by** *Büchereizentrale Schleswig-Holstein*
- [41887](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41887) Booking::store runs clash detection on terminal status transition causing 500 on checkout

  **Sponsored by** *Büchereizentrale Schleswig-Holstein*

### Command-line Utilities

#### Critical bugs fixed

- [28528](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=28528) bulkmarcimport delete option doesn't delete biblio_metadata

  **Sponsored by** *Ignatianum University in Cracow*

#### Other bugs fixed

- [41097](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41097) Deduping authorities script (dedup_authorities.pl) can die on duplicated ids
  >This fixes the deduping authorities maintenance script (misc/maintenance/dedup_authorities.pl) so that it now works and displays the output from the merging of authority records as expected. 
  >
  >Previously, it seemed to generate duplicate IDs, for example:
  >
  >Before
  >------
  >
  >Processing authority 1660 (531/650 81.69%)
  >    Merging 1660,1662 into 1660.
  >    Updated 0 biblios
  >    Deleting 1662
  >    Merge done.
  >
  >After
  >-----
  >
  >Processing authority 1660 (532/650 81.85%)
  >    Merging 1662 into 1660.
  >    Updated 0 biblios
  >    Deleting 1662
  >    Merge done.
- [41316](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41316) Using patron-homelibrary option for overdue notices does not change which rules are used

### Fines and fees

#### Critical bugs fixed

- [29923](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=29923) Do not generate overpayment refund from writeoff of fine
- [41761](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41761) Updating accountlines note sets accountlines.date to current date

### Installation and upgrade (command-line installer)

#### Critical bugs fixed

- [41337](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41337) koha-create --request-db and --populate-db creates log files owned by root (intranet-error.log, opac-error.log)
  >This fixes the UNIX user/group ownership of the log files `intranet-error.log` and `opac-error.log` inside `/var/log/koha/<instance>/`.
  >Previously, running `koha-create --request-db` followed by `koha-create --populate-db` would result in the two log files being owned by root/root.
  >The correct ownership is now applied, meaning the log files will be owned by the <instance>-koha/<instance>-koha UNIX user/group.

### Notices

#### Other bugs fixed

- [39749](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39749) RestrictPatronsWithFailedNotices should not trigger for DUPLICATE_MESSAGE failures
- [41393](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41393) Advance notices should set the reply to address

### OPAC

#### Other bugs fixed

- [41558](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41558) Broken links to tab on opac-user
  >This fixes and standardizes links to tabs for the patron summary section in the OPAC (such as Checked out, Overdue, Charges, Holds, and so on).
  >
  >In the past, we have used several different ways (some that work, some that don't) to construct the links to the tabs.
  >
  >Now, to directly link to a tab in the summary section, add ?tab=opac-user-* to the URL when you are in the summary section (where * = tab name from the anchor when you hover over the tab, for example checkouts (for Checked out), overdues (for Overdue), fines (for Overdue), recalls (for Recalls)).
- [41970](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41970) PA_CLASS does not show in fieldset ID on opac-memberentry.pl

### Patrons

#### Critical bugs fixed

- [42423](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42423) Submit button in patron search from header never submits
  >This fixes the patron search in the staff interface header. 
  >
  >If the search you enter didn't show any autocomplete results, clicking the arrow to search didn't do anything.
  >
  >Now, it will use the search you entered and show any results.

#### Other bugs fixed

- [41675](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41675) Username value is ignored in Patron quick-add form
- [41904](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41904) "Use of uninitialized value..." warning in del_message.pl

  **Sponsored by** *Ignatianum University in Cracow*
- [41986](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41986) Names in "Contact information" need more clarity
  >This changes the "Contact information" section on the patron details page (moremember.pl) to:
  >- show the "Middle name" field (where it exists)
  >- show the "Preferred name" field at the top (where it differs from the "First name").

### Reports

#### Other bugs fixed

- [41715](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41715) Argument "YYYY-MM-DD" isn't numeric in numeric lt (<)... warnings in issues_stats.pl
  >Removes the cause of "[WARN] Argument "YYYY-MM-DD" isn't numeric in numeric lt (<) at /kohadevbox/koha/reports/issues_stats.pl line 224." warnings from the plack-intranet-error.log when using the from and to date filter in the circulation statistics report in the staff interface.
  >
  >This was happening because a numerical comparison was used to compare the dates, instead of a string comparison.

  **Sponsored by** *Ignatianum University in Cracow*

### SIP2

#### Other bugs fixed

- [36752](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36752) Remove TODO about missing summary info in the SIP2 code
- [41811](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41811) SIP server will inadvertently remove non-alphanumeric characters from the end of a message
- [41818](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41818) SIP2 message in AF field should be stripped of newlines and carriage returns

### Searching

#### Other bugs fixed

- [41444](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41444) Fetch transfers directly for search results
- [41496](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41496) Item search copy sharable link not working

  **Sponsored by** *Lund University Library*

### Self checkout

#### Other bugs fixed

- [41645](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41645) Make self-checkout use responsive CSS
  >This change fixes the self check-out (SCO) so that it works with responsive CSS, which makes it more mobile friendly. This is especially useful when providing SCO on a tablet.
- [41647](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41647) Make self-checkin use responsive CSS
  >This change fixes the self check-in (SCI) so that it works with responsive CSS, which makes it more mobile friendly. This is especially useful when providing SCI on a tablet.

### Staff interface

#### Other bugs fixed

- [39055](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39055) Unauthenticated are not redirected properly in reports module after login
  >This change fixes the login so that pages that use "op" still work following a login prompt.
- [41958](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41958) Rename BibTex to BibTeX (with a capital X) for the staff interface cart and list download options (to match the OPAC)
  >This renames BibTex to BibTeX (with a capital X) for the staff interface cart and list download options (to match the OPAC).
- [41976](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41976) [Vue] LinkWrapper.vue isn't scoped properly
- [41989](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41989) addbook shows the translated interface
  >Fixes an issue with templates that meant incorrect translations could be shown on the addbook page.

### System Administration

#### Other bugs fixed

- [41360](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41360) Transport cost matrix assumes all transfers are disabled upon first use
  >This adds three new toolbar buttons to make batch modifications to the transport cost matrix table easier (when UseTransportCostMatrix is enabeld):
  >
  >* Enable all cells
  >* Disable empty cells
  >* Populate empty cells, with selectable values from 0 to 100

### Templates

#### Other bugs fixed

- [40568](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40568) Various corrections to recalls templates
  >This makes some minor changes to recalls templates:
  >- Fixes the date sorting on the recalls queue page
  >- Hides "Show old recalls" if there are no recalls in a patron's recalls history, and adds the "page-section" div (white background)

  **Sponsored by** *Athens County Public Libraries*
- [40787](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40787) Plugins buttons misaligned when search box is enabled
- [41807](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41807) Fix automatic tab selection on basket groups page
  >This patch fixes a bug which prevented the expected tab from being activated when the user takes certain actions like closing or deleting a basket group.

  **Sponsored by** *Athens County Public Libraries*
- [41838](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41838) Fix automatic tab selection on MARC subfield edit pages

  **Sponsored by** *Athens County Public Libraries*
- [42014](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=42014) Patron lists tab shows blank content when no patron lists exist

### Test Suite

#### Other bugs fixed

- [41384](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41384) SIP2/Accounts.ts  is failing randomly
- [41616](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41616) Warnings on authority_hooks.t
- [41830](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41830) Acquisitions/Vendors_spec.ts is failing randomly

## Enhancements 

### About

#### Enhancements

- [41319](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41319) Link content of 'Contributing companies and institutions' to bug sponsors
  >This enhancement automates the generation of contributing companies and institutions on the about page (About Koha > Koha team), and (where known):
  >- Links to their website 
  >- Includes the country

### Architecture, internals, and plumbing

#### Enhancements

- [39721](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39721) Remove GetSuggestion from C4/Suggestions.pm

### Cataloging

#### Enhancements

- [41170](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41170) Highlight previously edited item on add items page
  >This patch adds highlighting of the most recently edited/added item on the 'add items page'
  >The feature allows catalogers to identify recent item and confirm their edits or compare to other items in the catalog.

### Circulation

#### Enhancements

- [37707](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=37707) Lead/Trail times should work in combination
- [41134](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41134) Add table settings to transfers
  >This enhancement adds standard table settings to the transfers table (Circulation > Transfers > Transfer). This includes options to change the columns shown, export data, and to configure the default table settings.

  **Sponsored by** *Athens County Public Libraries*
- [41338](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41338) Hold found dialog does not show item home and check-in libraries

### Command-line Utilities

#### Enhancements

- [38549](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=38549) Make create_superlibrarian.pl script accept a name parameter
  >This enhancement enables the user to supply a surname parameter when creating a superlibrarian user via the commandline script create_superlibrarian.pl. Koha patrons MUST have a name, so if no surname is provided, the userid will be used for the surname instead.

  **Sponsored by** *Catalyst*

### Continuous Integration

#### Enhancements

- [41368](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41368) Tools/ManageMarcImport_spec.ts is failing
  >26.05.00

### Database

#### Enhancements

- [41409](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41409) Streetnumber has a different data type in borrower_modifications
  >The database data types for these fields are tinytext in the borrowers table and varchar(10) in the borrower_modifications table:
  >
  >- streetnumber (a patron's main address street number field)
  >- B_streetnumber (a patron's alternate address street number field)
  >
  >This enhancement updates the borrower_modifications table so that the fields are now tinytext, consistent with the borrowers table.

### I18N/L10N

#### Enhancements

- [39580](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39580) Make Elasticsearch process_error error string translatable

### ILL

#### Enhancements

- [40105](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40105) Patrons cannot add notes when creating an ILL

### OPAC

#### Enhancements

- [25314](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=25314) Make OPAC facets collapse
  >This enhancement modifies the OPAC catalog search results page's facets menu, adding the ability to click on a facet heading to collapse it.

  **Sponsored by** *Athens County Public Libraries*

### Patrons

#### Enhancements

- [21555](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=21555) Merging Patrons allows for all patrons to be selected

  **Sponsored by** *Cape Libraries Automated Materials Sharing*

### Plugin architecture

#### Enhancements

- [36542](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36542) In C4/AddBiblio, plugin hook after_biblio_action is triggered before the record is actually saved
- [39522](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39522) Add hooks to allow 'Valuebuilder' plugins to be installable

  **Sponsored by** *OpenFifth*

### Reports

#### Enhancements

- [40896](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40896) Run report button should be disabled after click
  >The "Run report" buttons in the guided reports interface are now disabled upon click and display a spinner icon, preventing accidental duplicate submissions that could overload the system. This improvement uses a new reusable throttled button component that automatically re-enables after a configurable timeout and correctly handles browser back-forward cache navigation. The component wraps icons in semantic containers for accessibility (aria-busy) and is designed to be reused across other parts of the staff interface.

### Serials

#### Enhancements

- [41330](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41330) Brace are not escaped in serials number management
  >Brace in numbering patterns in serials are not breaking anymore the reception of serials

### Staff interface

#### Enhancements

- [24949](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=24949) Provide password visibility toggle / icon to unmask password on staff login screen

  **Sponsored by** *Athens County Public Libraries*
- [41692](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41692) "See all charges" link in the guarantor details does not activate Guarantees charges tab
- [41885](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41885) Rename iso2709 to MARC for the staff interface download options for the cart and lists (to match the OPAC)
  >This enhancement renames iso2709 to MARC for staff interface cart and lists download options. This now matches the OPAC.

## New system preferences

- autoMemberNumValue

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
- Chinese (Simplified Han script) (81%)
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
- Hindi (92%)
- Italian (80%)
- Norwegian Bokmål (69%)
- Persian (fa_ARAB) (91%)
- Polish (99%)
- Portuguese (Brazil) (99%)
- Portuguese (Portugal) (87%)
- Russian (91%)
- Slovak (58%)
- Spanish (96%)
- Swedish (88%)
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

The release team for Koha 25.11.04 is


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
new features in Koha 25.11.04
<div style="column-count: 2;">

- Athens County Public Libraries
- [Büchereizentrale Schleswig-Holstein](https://www.bz-sh.de)
- [Cape Libraries Automated Materials Sharing](https://info.clamsnet.org)
- [Catalyst](https://www.catalyst.net.nz/products/library-management-koha)
- Ignatianum University in Cracow
- Lund University Library
- [OpenFifth](https://openfifth.co.uk)
</div>

We thank the following individuals who contributed patches to Koha 25.11.04
<div style="column-count: 2;">

- Aleisha Amohia (1)
- Pedro Amorim (6)
- Tomás Cohen Arazi (1)
- Kevin Carnes (1)
- Nick Clemens (11)
- David Cook (16)
- Jake Deery (3)
- Paul Derscheid (14)
- Roman Dolny (3)
- Jonathan Druart (16)
- Katrin Fischer (1)
- Lucas Gass (4)
- grgurmg (1)
- Kyle M Hall (8)
- Janusz Kaczmarek (1)
- Brendan Lawlor (1)
- Owen Leonard (9)
- David Nind (2)
- Jacob O'Mara (8)
- Eric Phetteplace (1)
- Martin Renvoize (18)
- Marcel de Rooy (5)
- Andreas Roussos (1)
- Lisette Scheer (1)
- Slava Shishkin (1)
- Fridolin Somers (1)
- Arthur Suzuki (1)
- Lari Taskula (2)
- Petro Vashchuk (1)
- Shi Yao Wang (1)
- Hammat Wele (2)
- Baptiste Wojtkowski (6)
</div>

We thank the following libraries, companies, and other institutions who contributed
patches to Koha 25.11.04
<div style="column-count: 2;">

- Athens County Public Libraries (9)
- [BibLibre](https://www.biblibre.com) (8)
- [Bibliotheksservice-Zentrum Baden-Württemberg (BSZ)](https://bsz-bw.de) (1)
- [ByWater Solutions](https://bywatersolutions.com) (24)
- [Cape Libraries Automated Materials Sharing](https://info.clamsnet.org) (1)
- [Catalyst](https://www.catalyst.net.nz/products/library-management-koha) (1)
- [Dataly Tech](https://dataly.gr) (1)
- David Nind (2)
- [Hypernova Oy](https://www.hypernova.fi) (2)
- Independant Individuals (5)
- [Jezuici](https://jezuici.pl/) (3)
- Koha Community Developers (16)
- [LMSCloud](https://www.lmscloud.de) (14)
- Lund University Library (1)
- [OpenFifth](https://openfifth.co.uk) (35)
- [Prosentient Systems](https://www.prosentient.com.au) (16)
- Rijksmuseum, Netherlands (5)
- [Solutions inLibro inc](https://inlibro.com) (3)
- [Theke Solutions](https://theke.io) (1)
</div>

We also especially thank the following individuals who tested patches
for Koha
<div style="column-count: 2;">

- Pedro Amorim (2)
- Tomás Cohen Arazi (6)
- Matt Blenkinsop (3)
- Nick Clemens (9)
- David Cook (6)
- Ben Daeuber (1)
- Benjamin Daeuber (1)
- Jake Deery (1)
- Paul Derscheid (10)
- Roman Dolny (7)
- Jonathan Druart (21)
- Marion Durand (1)
- Laura Escamilla (4)
- Katrin Fischer (11)
- Andrew Fuerste-Henry (16)
- Lucas Gass (111)
- Mike Grgurev (1)
- Kyle M Hall (20)
- Juliet Heltibridle (1)
- Janusz Kaczmarek (1)
- Jan Kissig (1)
- Emily Lamancusa (1)
- Brendan Lawlor (8)
- Owen Leonard (11)
- Gretchen Maxeiner (1)
- Mikko (1)
- David Nind (38)
- Jacob O'Mara (127)
- Nic Olsson (1)
- Martin Renvoize (27)
- Phil Ringnalda (2)
- Marcel de Rooy (25)
- Lisette Scheer (2)
- Catherine Small (5)
- Emmi Takkinen (1)
- Baptiste Wojtkowski (2)
- Chloe Zermatten (15)
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

Autogenerated release notes updated last on 22 Apr 2026 16:12:41.
