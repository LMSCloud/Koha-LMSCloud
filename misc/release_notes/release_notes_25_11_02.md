# RELEASE NOTES FOR KOHA 25.11.02
23 Feb 2026

Koha is the first free and open source software library automation
package (ILS). Development is sponsored by libraries of varying types
and sizes, volunteers, and support companies from around the world. The
website for the Koha project is:

- [Koha Community](https://koha-community.org)

Koha 25.11.02 can be downloaded from:

- [Download](https://download.koha-community.org/koha-25.11.02.tar.gz)

Installation instructions can be found at:

- [Koha Wiki](https://wiki.koha-community.org/wiki/Installation_Documentation)
- OR in the INSTALL files that come in the tarball

Koha 25.11.02 is a bugfix/maintenance release.

It includes 15 enhancements, 36 bugfixes.

**System requirements**

You can learn about the system components (like OS and database) needed for running Koha on the [community wiki](https://wiki.koha-community.org/wiki/System_requirements_and_recommendations).


#### Security bugs

- [41591](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41591) XSS vulnerability via file upload function for invoices

## Bugfixes

### About

#### Other bugs fixed

- [41102](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41102) Error 500 on the "About" page when biblioserver Zebra configuration is missing
  >This fixes the About Koha page when Zebra is not running or not correctly configured in the Koha instance's koha-conf.xml file. Instead of a 500 error when you access the page, there is now a message in the server information tab for Zebra's status, such as "Zebra server seems not to be available. Is it started?".

### Accessibility

#### Other bugs fixed

- [40726](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40726) Clicking off of a dropdown in the user menu branch switching closes the dropdown

### Acquisitions

#### Critical bugs fixed

- [41546](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41546) Cannot unarchive suggestions
  >This restores the 'Unarchive' action for archived suggestions.
  >
  >To restore an archived suggestion:
  >1. Go to Acquisitions > Suggestions
  >2. To show archived suggestions:
  >   2.1 From the sidebar 'Filter by section', select 
  >       'Include archived'
  >   2.2 Click the 'Go' button in the 'Organize by section'
  >3. For an archived suggestion ('Archived' shown under the 
  >   suggestion title):
  >   3.1 Select the dropdown list by the 'Edit' button
  >       on the far right
  >   3.2 Select the 'Unarchive' action.

### Architecture, internals, and plumbing

#### Critical bugs fixed

- [41327](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41327) `yarn css:build` generates several warnings

  **Sponsored by** *Athens County Public Libraries*
- [41329](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41329) yarn install generates 2 warnings regarding datatables-.net-vue3

#### Other bugs fixed

- [27115](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=27115) Restarting koha-common fails to restart SIP2 server
  >This fixes an issue when stopping and restarting SIP servers using `koha-sip` - it would sometimes not restart the SIP servers.
  >
  >This was because a restart could attempt the --start command while a previous SIP server was still running. This could result in the SIP server not restarting at all.
  >
  >The fix replaces `daemon --stop` with `start-stop-daemon --stop` in the code, to ensure that all the running SIP servers are actually stopped before restarting.
- [41142](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41142) Update jQuery-validate plugin to 1.21.0

  **Sponsored by** *Athens County Public Libraries*
- [41523](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41523) Bug 41409 update statement is not accurate
- [41545](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41545) JS warning "redeclaration of let filters_options"

### Cataloging

#### Critical bugs fixed

- [41481](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41481) XML validation error when launching the tag editor for MARC21 fields 006/008
  >This fixes an XML validation error ("Can't validate the xml data from (...)/marc21_field_00{6,8}.xml") when using the tag editor for MARC21 fields 006/008. The tag editor now works as expected for these fields.

#### Other bugs fixed

- [40777](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40777) 500 Error: Something went wrong when loading the table Should Exit Cleanly
  >This adds an "Audit" option on the toolbar for records in the staff interface. This implements the check for missing home and current library data (952$a and 952$b fields).
  >
  >If a record has data inconsistencies, then using the audit option is shown on the error message that is shown when accessing the record details page:
  >
  >        Something went wrong when loading the table.
  >        500: Internal server error
  >        Have a look at the "Audit" button in the toolbar
- [41047](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41047) Current library and home library sort by code instead of description
  >This patch fixes a problem where holdings were not sorting correctly by the branchname. With this patch the 'Current library' and 'Home library' columns now sort correctly on the description/library name instead of on the branchcode.
- [41081](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41081) Link from 856$u points to http://%20%20%20%20
  >If a 856$u for a record has just spaces instead of a URL, an invalid link was shown on the record page for the OPAC and staff interface (under 'Online resources').
  >
  >Example: a record with four spaces added "Online resources" information to a record's page, with an invalid link to http://%20%20%20%20

### Circulation

#### Critical bugs fixed

- [39584](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39584) Booking post-processing time cuts into circulation period

#### Other bugs fixed

- [39916](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=39916) The 'Place booking' modal should have cypress tests

### ERM

#### Critical bugs fixed

- [41520](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41520) Using additional fields on ERM agreements results in an error when loading the agreements table
  >This fixes the ERM agreements table, when additional fields are added for agreements.
  >
  >When loading the ERM agreements table, a 500 error was generated:
  >
  >   Something went wrong when loading the table.
  >   500: Internal Server Error
  >   Properties not allowed: record_table.
  >   Properties not allowed: record_table.
  >   Properties not allowed: record_table.

### Hold requests

#### Other bugs fixed

- [41416](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41416) Poor performance when clicking 'Update hold(s)' on request.pl for records with many holds

### I18N/L10N

#### Other bugs fixed

- [41623](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41623) Missing translation string in catalogue_detail.inc (again)

### ILL

#### Other bugs fixed

- [41237](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41237) OPAC created requests ignore library selection, always default to patron's library
  >This fixes a bug on the OPAC create ILL request form which was always setting the library to the patron's library, ignoring the library selection made on the form.

### Patrons

#### Other bugs fixed

- [41497](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41497) ul.patronbriefinfo inconsistent in coding structure
  >This patch fixes inconsistent HTML structures in the patronbriefinfo <ul>.

  **Sponsored by** *Athens County Public Libraries*

### Plugin architecture

#### Critical bugs fixed

- [41603](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41603) Plugin hook causing DB locks when cancelling holds

### Self checkout

#### Critical bugs fixed

- [41646](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41646) Self-checkin displaying too much whitespace due to incorrect HTML
  >This removes a large section of white space between the page header and the actual form on the OPAC self check-in page, which was positioned near the bottom of the page.

### Staff interface

#### Other bugs fixed

- [41484](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41484) Wording of 'On hold', 'Booked', and 'Recalled' in issues table can be confusing
  >This updates the wording of messages on a patron's checkouts tab (under the check out and details sections) to avoid confusion when another patron has placed a hold, booking, or recall. 
  >
  >Messages changed:
  >- Recalled => Item recalled by another patron
  >- Booked => Item booked for another patron
  >- On hold => Item on hold for another patron
- [41494](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41494) Rename "Koha administration" to "Administration" for consistency
  >Renames "Koha administration" to "Administration" on the staff interface and administration module home pages. This improves consistency, as everywhere else in the staff interface it is called administration, such as for breadcrumbs and browser page titles.

### System Administration

#### Other bugs fixed

- [38876](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=38876) Typo in UpdateNotForLoanStatusOnCheckout description
- [41190](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41190) "Default checkout, hold and return policy" needs a space in title
  >Adds a space to the circulation rules section heading for "Default checkout, hold and return policy" when a library is selected.
  >
  >Example:
  >- With a library selected, such as Centerville, the rule heading is missing a space "Default checkout, hold and return policyfor Centerville"
- [41540](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41540) staffShibOnly - update description for system preference
  >This updates the description for the `staffShibOnly` system preference and fixes grammar and spelling:
  >- "login" to "log in"
  >- "shibboleth" to "Shibboleth" (capitalized)

### Templates

#### Other bugs fixed

- [38739](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=38739) Templates not ending with include intranet-bottom.inc in staff interface
  >This update fixes inconsistencies in template markup which could cause duplicated page elements, JavaScript errors, and errors in HTML validation.
- [41351](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41351) Capitalization: Override Renew hold for another
  >This fixes the capitalization for a log viewer message: "Override Renew hold for another" to "Override renew hold for another".
- [41397](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41397) Terminology: Target item is not reservable
  >This fixes the terminology for a staff interface holds message: "Target item is not reservable" to "Target item cannot be placed on hold"
- [41398](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41398) Typo: Tagret item is not in the local hold group
  >This fixes a spelling error for a holds-related message in the staff interface: "Tagret item is not in the local hold group" to "Target item is not in the local hold group".

### Test Suite

#### Other bugs fixed

- [40446](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40446) DB config used by Cypress (mysql2) is not configurable

### Tools

#### Critical bugs fixed

- [41438](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41438) Batch hold tool: Suspended holds are unsuspended when making other changes to holds

  **Sponsored by** *Koha-Suomi Oy*

#### Other bugs fixed

- [40846](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40846) Job Status should not be Failed if a record import result in a item update
- [41334](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41334) Move modified_holds tables column settings under Tools section
  >This moves the location of the modified_holds table on the table settings  page from Circulation > holds to Tools > batch_hold_modification, as this table relates to the batch modification of holds (added to Koha 25.11 by bug 36135).

  **Sponsored by** *Koha-Suomi Oy*

## Enhancements 

### Accessibility

#### Enhancements

- [38643](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=38643) Advanced Search input fields need placeholders
  >OPAC accessibility improvement: Added dynamic placeholder text to advanced search fields to provide clearer visual guidance and improve usability for users with cognitive accessibility needs.

### Architecture, internals, and plumbing

#### Enhancements

- [32370](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=32370) Provide a generic set of tools for JSON fields

### Circulation

#### Enhancements

- [16131](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=16131) Error messages for library transfers show with bullet points
  >When transferring items (Circulation > Transfers > Transfer), any error messages are shown as a bulleted list in one alert box.
  >
  >If there is only one error, it looks a bit odd having a bulleted list with only one item. 
  >
  >With this enhancement, each error message is now shown in its own alert box.

  **Sponsored by** *Catalyst*

### Database

#### Enhancements

- [41409](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41409) Streetnumber has a different data type in borrower_modifications
  >The database data types for these fields are tinytext in the borrowers table and varchar(10) in the borrower_modifications table:
  >
  >- streetnumber (a patron's main address street number field)
  >- B_streetnumber (a patron's alternate address street number field)
  >
  >This enhancement updates the borrower_modifications table so that the fields are now tinytext, consistent with the borrowers table.

  **Sponsored by** *Cheshire Libraries Shared Services*

### ILL

#### Enhancements

- [41009](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41009) When editing an ILL request, the user is returned to the list
  >This enhancement will return a user to the ill request page instead of the list of requests after saving an edit.
- [41054](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41054) Standard ILL form should consider eISSN field
  >This adds the 'eISSN' field to the ILL Standard forms where ISSN is also present.

### MARC Bibliographic data support

#### Enhancements

- [41000](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41000) Update label on record detail pages for 041$d - "Spoken language" to "Sung or spoken language"
  >This enhancement updates the label on detail pages in the staff interface
  >and OPAC for records with a 041$d (MARC21) - Language code of sung or spoken text.
  >
  >It is now labelled as "Sung or spoken language", instead of "Spoken language" --better matching the MARC21 definition.
  >
  >For music libraries, this also more accurately reflects the information for the record.

### Notices

#### Enhancements

- [40719](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40719) Explicit turn off RELATIVE file paths for plugins for user-entered templates

### Patrons

#### Enhancements

- [40794](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40794) Add an id to the div containing payments tabs
  >An id="account-tabs" attribute has been added to the account/payment tab navigation (Transactions, Make a payment, Create manual invoice, Create manual credit). This allows for easier customization and targeting with CSS/JS without conflicting with the global toptabs navigation.
- [41411](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41411) Streetnumber field is limited to 10 characters despite being tinytext
  >The input form for a patron's main and alternative address street number fields are limited to 10 characters, even though the underlying database field can have up to 255 characters.
  >
  >This enhancement removes this 10-character limit, which makes it more useful where house names are used instead of house numbers.

### REST API

#### Enhancements

- [28701](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=28701) primary_contact_method not part of the REST API spec
- [29668](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=29668) Add API route to create a basket

### System Administration

#### Enhancements

- [28495](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=28495) Add hint about whitespace usage upon library creation
- [41332](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41332) Add new option for Greek (el) to the 'KohaManualLanguage' System Preference
  >This enhancement adds 'Greek' to the list of languages
  >for the KohaManualLanguage system preference.

### Test Suite

#### Enhancements

- [41362](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41362) Allow Cypress tests to use KOHA_USER and KOHA_PASS as override

## Documentation

The Koha manual is maintained in Sphinx. The home page for Koha
documentation is

- [Koha Documentation](https://koha-community.org/documentation/)
As of the date of these release notes, the Koha manual is available in the following languages:

- [English (USA)](https://koha-community.org/manual/25.11/en/html/)
- [French](https://koha-community.org/manual/25.11/fr/html/) (75%)
- [German](https://koha-community.org/manual/25.11/de/html/) (90%)
- [Greek](https://koha-community.org/manual/25.11/el/html/) (94%)
- [Hindi](https://koha-community.org/manual/25.11/hi/html/) (64%)

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
- French (99%)
- French (Canada) (97%)
- German (99%)
- Greek (64%)
- Hindi (93%)
- Italian (79%)
- Norwegian Bokmål (69%)
- Persian (fa_ARAB) (91%)
- Polish (99%)
- Portuguese (Brazil) (99%)
- Portuguese (Portugal) (86%)
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

The release team for Koha 25.11.02 is


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
new features in Koha 25.11.02
<div style="column-count: 2;">

- Athens County Public Libraries
- [Catalyst](https://www.catalyst.net.nz/products/library-management-koha)
- Cheshire Libraries Shared Services
- [Koha-Suomi Oy](https://koha-suomi.fi)
</div>

We thank the following individuals who contributed patches to Koha 25.11.02
<div style="column-count: 2;">

- Aleisha Amohia (1)
- Pedro Amorim (7)
- Tomás Cohen Arazi (8)
- Matt Blenkinsop (3)
- Nick Clemens (3)
- David Cook (3)
- Paul Derscheid (2)
- Jonathan Druart (22)
- Laura Escamilla (4)
- Lucas Gass (5)
- Victor Grousset (1)
- Kyle M Hall (2)
- Owen Leonard (6)
- Julian Maurice (1)
- Mia (1)
- David Nind (1)
- Photonyx (1)
- Martin Renvoize (10)
- Alexis Ripetti (1)
- Marcel de Rooy (2)
- Caroline Cyr La Rose (2)
- Andreas Roussos (2)
- Emmi Takkinen (2)
- Lari Taskula (2)
- Mercury WallacE (1)
- Hammat Wele (1)
- Samuel Young (1)
- Jessica Zairo (3)
- Chloe Zermatten (7)
</div>

We thank the following libraries, companies, and other institutions who contributed
patches to Koha 25.11.02
<div style="column-count: 2;">

- Athens County Public Libraries (6)
- [BibLibre](https://www.biblibre.com) (1)
- [ByWater Solutions](https://bywatersolutions.com) (17)
- [Catalyst](https://www.catalyst.net.nz/products/library-management-koha) (2)
- coffee.geek.nz (1)
- [Dataly Tech](https://dataly.gr) (2)
- David Nind (1)
- [Hypernova Oy](https://www.hypernova.fi) (2)
- Independant Individuals (2)
- Koha Community Developers (23)
- [Koha-Suomi Oy](https://koha-suomi.fi) (2)
- [LMSCloud](https://www.lmscloud.de) (2)
- [OpenFifth](https://openfifth.co.uk) (27)
- [Prosentient Systems](https://www.prosentient.com.au) (3)
- Rijksmuseum, Netherlands (2)
- [Solutions inLibro inc](https://inlibro.com) (4)
- [Theke Solutions](https://theke.io) (8)
</div>

We also especially thank the following individuals who tested patches
for Koha
<div style="column-count: 2;">

- Tomás Cohen Arazi (3)
- Andrew Auld (1)
- Richard Bridgen (4)
- Nick Clemens (10)
- David Cook (3)
- Paul Derscheid (11)
- Roman Dolny (2)
- Jonathan Druart (7)
- Laura Escamilla (7)
- Katrin Fischer (2)
- Andrew Fuerste-Henry (10)
- Lucas Gass (92)
- Stephen Graham (2)
- Victor Grousset (18)
- Kyle M Hall (3)
- Jan Kissig (3)
- Kristi Krueger (7)
- Brendan Lawlor (1)
- Owen Leonard (19)
- Ludovic (1)
- Manvi (1)
- David Nind (34)
- noah (2)
- Jacob O'Mara (71)
- Lawrence O'Regan-Lloyd (1)
- Martin Renvoize (6)
- Marcel de Rooy (6)
- Caroline Cyr La Rose (1)
- Lisette Scheer (1)
- Emmi Takkinen (1)
- Chloe Zermatten (27)
</div>





We regret any omissions.  If a contributor has been inadvertently missed,
please send a patch against these release notes to koha-devel@lists.koha-community.org.

## Revision control notes

The Koha project uses Git for version control.  The current development
version of Koha can be retrieved by checking out the main branch of:

- [Koha Git Repository](https://git.koha-community.org/koha-community/koha)

The branch for this version of Koha and future bugfixes in this release
line is 25.11.x.

## Bugs and feature requests

Bug reports and feature requests can be filed at the Koha bug
tracker at:

- [Koha Bugzilla](https://bugs.koha-community.org)

He rau ringa e oti ai.
(Many hands finish the work)

Autogenerated release notes updated last on 23 Feb 2026 16:46:59.
