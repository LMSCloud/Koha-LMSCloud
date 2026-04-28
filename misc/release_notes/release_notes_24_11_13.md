# RELEASE NOTES FOR KOHA 24.11.13
23 Feb 2026

Koha is the first free and open source software library automation
package (ILS). Development is sponsored by libraries of varying types
and sizes, volunteers, and support companies from around the world. The
website for the Koha project is:

- [Koha Community](https://koha-community.org)

Koha 24.11.13 can be downloaded from:

- [Download](https://download.koha-community.org/koha-24.11.13.tar.gz)

Installation instructions can be found at:

- [Koha Wiki](https://wiki.koha-community.org/wiki/Installation_Documentation)
- OR in the INSTALL files that come in the tarball

Koha 24.11.13 is a bugfix/maintenance release with 1 security patch.

It includes 1 enhancements, 3 bugfixes (1 security).

**System requirements**

You can learn about the system components (like OS and database) needed for running Koha on the [community wiki](https://wiki.koha-community.org/wiki/System_requirements_and_recommendations).


#### Security bugs

- [41591](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41591) XSS vulnerability via file upload function for invoices

## Bugfixes

### ERM

#### Other bugs fixed

- [41001](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=41001) Dismissing the "Run now" modal breaks functionality

### REST API

#### Other bugs fixed

- [40219](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40219) Welcome Email Sent on Failed Patron Registration via API
  >This fixes patron registrations using the API - a welcome email notice was sent even if there were validation failures.

## Enhancements 

### Plugin architecture

#### Enhancements

- [40827](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40827) Update plugin wrapper to include context for method="report"
  >This enhancement updates the plugin wrapper to include the reports menu and have the breadcrumbs list reports instead of admin or tools when method="report"

## Documentation

The Koha manual is maintained in Sphinx. The home page for Koha
documentation is

- [Koha Documentation](https://koha-community.org/documentation/)
As of the date of these release notes, the Koha manual is available in the following languages:

- [English (USA)](https://koha-community.org/manual/24.11/en/html/)
- [French](https://koha-community.org/manual/24.11/fr/html/) (75%)
- [German](https://koha-community.org/manual/24.11/de/html/) (90%)
- [Greek](https://koha-community.org/manual/24.11/el/html/) (94%)
- [Hindi](https://koha-community.org/manual/24.11/hi/html/) (64%)

The Git repository for the Koha manual can be found at

- [Koha Git Repository](https://gitlab.com/koha-community/koha-manual)

## Translations

Complete or near-complete translations of the OPAC and staff
interface are available in this release for the following languages:
<div style="column-count: 2;">

- Arabic (ar_ARAB) (95%)
- Armenian (hy_ARMN) (100%)
- Bulgarian (bg_CYRL) (100%)
- Chinese (Simplified Han script) (86%)
- Chinese (Traditional Han script) (99%)
- Czech (68%)
- Dutch (88%)
- English (100%)
- English (New Zealand) (63%)
- English (USA)
- Finnish (99%)
- French (100%)
- French (Canada) (99%)
- German (100%)
- Greek (67%)
- Hindi (97%)
- Italian (82%)
- Norwegian Bokmål (73%)
- Persian (fa_ARAB) (96%)
- Polish (99%)
- Portuguese (Brazil) (99%)
- Portuguese (Portugal) (88%)
- Russian (94%)
- Slovak (61%)
- Spanish (99%)
- Swedish (88%)
- Telugu (67%)
- Tetum (52%)
- Turkish (83%)
- Ukrainian (76%)
- Western Armenian (hyw_ARMN) (62%)
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

The release team for Koha 24.11.13 is


- Release Manager: Lucas Gass

- QA Manager: Martin Renvoize

- QA Team:
  - Andrew Fuerste-Henry
  - Andrii Nugged
  - Baptiste Wojtkowski
  - Brendan Lawlor
  - David Cook
  - Emily Lamancusa
  - Jonathan Druart
  - Julian Maurice
  - Kyle Hall
  - Laura Escamilla
  - Lisette Scheer
  - Marcel de Rooy
  - Nick Clemens
  - Paul Derscheid
  - Petro V
  - Tomás Cohen Arazi
  - Victor Grousset

- Documentation Manager: David Nind

- Documentation Team:
  - Aude Charillon
  - Caroline Cyr La Rose
  - Donna Bachowski
  - Heather Hernandez
  - Kristi Krueger
  - Philip Orr

- Translation Manager: Jonathan Druart


- Wiki curators: 
  - George Williams
  - Thomas Dukleth

- Release Maintainers:
  - 25.05 -- Paul Derscheid
  - 24.11 -- Fridolin Somers
  - 24.05 -- Jesse Maseto
  - 22.11 -- Catalyst IT (Wainui, Alex, Aleisha)

- Release Maintainer assistants:
  - 25.05 -- Martin Renvoize
  - 24.11 -- Baptiste Wojtkowski
  - 24.05 -- Laura Escamilla

## Credits



We thank the following individuals who contributed patches to Koha 24.11.13
<div style="column-count: 2;">

- Pedro Amorim (3)
- David Cook (1)
- Jonathan Druart (1)
- Martin Renvoize (1)
- Lisette Scheer (1)
- Leo Stoyanov (1)
</div>

We thank the following libraries, companies, and other institutions who contributed
patches to Koha 24.11.13
<div style="column-count: 2;">

- [ByWater Solutions](https://bywatersolutions.com) (2)
- Koha Community Developers (1)
- [OpenFifth](https://openfifth.co.uk) (4)
- [Prosentient Systems](https://www.prosentient.com.au) (1)
</div>

We also especially thank the following individuals who tested patches
for Koha
<div style="column-count: 2;">

- Christopher Brannon (1)
- David Cook (1)
- Jonathan Druart (4)
- Laura Escamilla (6)
- Jan Kissig (1)
- Martin Renvoize (1)
- Marcel de Rooy (2)
- Fridolin Somers (2)
- Baptiste Wojtkowski (6)
</div>





We regret any omissions.  If a contributor has been inadvertently missed,
please send a patch against these release notes to koha-devel@lists.koha-community.org.

## Revision control notes

The Koha project uses Git for version control.  The current development
version of Koha can be retrieved by checking out the main branch of:

- [Koha Git Repository](https://git.koha-community.org/koha-community/koha)

The branch for this version of Koha and future bugfixes in this release
line is 24.11.x.

## Bugs and feature requests

Bug reports and feature requests can be filed at the Koha bug
tracker at:

- [Koha Bugzilla](https://bugs.koha-community.org)

He rau ringa e oti ai.
(Many hands finish the work)

Autogenerated release notes updated last on 23 Feb 2026 13:52:37.
