package Koha::Manual;

use Modern::Perl;

use C4::Context;

sub _get_help_version {
    my $help_version = C4::Context->preference("Version");
    if ( $help_version =~ m|^(\d+)\.(\d{2}).*$| ) {
        my $version = $1;
        my $major = $2;
        unless ( $major % 2 ) { $major-- };
        $major = sprintf("%02d", $major);
        $help_version = "$version.$major";
    }
    return $help_version;
}

sub _get_base_url {
    my ( $preferred_language ) = @_;

    my @available_languages = qw( en ar cs es fr it pt_BR tz zh_TW );

    my ( $language ) = grep {
        my $preferred_short = substr $preferred_language, 0, 2;
        my $avail_short = substr $_, 0, 2;
        $preferred_short eq $avail_short ? $_ : ()
    } @available_languages;

    my $KohaManualLanguage = $language || C4::Context->preference('KohaManualLanguage') || 'en';
    my $KohaManualBaseURL = C4::Context->preference('KohaManualBaseURL') || 'https://koha-community.org/manual';
    if ( $KohaManualBaseURL =~ m|^/| ) {
        $KohaManualBaseURL = C4::Context->preference('staffClientBaseURL') . $KohaManualBaseURL;
    }
    return $KohaManualBaseURL . '/' . _get_help_version . '/' . $KohaManualLanguage . '/html'; # TODO html could be a KohaManualFormat with pdf, html, epub
}

our $mapping = {
    'about'                                    => '/plugins.html#about-koha',
    'acqui/acqui-home'                         => '/acquisitions.html',
    'acqui/addorderiso2709'                    => '/acquisitions.html#create-a-basket',
    'acqui/basket'                             => '/acquisitions.html#create-a-basket',
    'acqui/basketgroup'                        => '/acquisitions.html#create-a-basket-group',
    'acqui/basketheader'                       => '/acquisitions.html#create-a-basket',
    'acqui/booksellers'                        => '/acquisitions.html#acquisition-searches',
    'acqui/edifactmsgs'                        => '/acquisitions.html#edifact-messages',
    'acqui/histsearch'                         => '/acquisitions.html#acquisition-searches',
    'acqui/invoice'                            => '/acquisitions.html#invoices',
    'acqui/invoices'                           => '/acquisitions.html#invoices',
    'acqui/lateorders'                         => '/acquisitions.html#claims-late-orders',
    'acqui/neworderbiblio'                     => '/acquisitions.html#create-a-basket',
    'acqui/neworderempty'                      => '/acquisitions.html#create-a-basket',
    'acqui/newordersubscription'               => '/acquisitions.html#create-a-basket',
    'acqui/newordersuggestion'                 => '/acquisitions.html#create-a-basket',
    'acqui/orderreceive'                       => '/acquisitions.html#receiving-orders',
    'acqui/parcel'                             => '/acquisitions.html#receiving-orders',
    'acqui/parcels'                            => '/acquisitions.html#receiving-orders',
    'acqui/supplier'                           => '/acquisitions.html#vendors',
    'acqui/uncertainprice'                     => '/acquisitions.html#create-a-basket',
    'acqui/z3950_search'                       => '/acquisitions.html#create-a-basket',
    'admin/additional-fields'                  => '/administration.html#additional-fields',
    'admin/admin-home'                         => '/administration.html',
    'admin/aqbudgetperiods'                    => '/administration.html#budgets',
    'admin/aqbudgets'                          => '/administration.html#funds',
    'admin/aqcontract'                         => '/acquisitions.html#vendor-contracts',
    'admin/aqplan'                             => '/administration.html#budget-planning',
    'admin/audio_alerts'                       => '/administration.html#audio-alerts',
    'admin/auth_subfields_structure'           => '/administration.html#authority-types',
    'admin/auth_tag_structure'                 => '/administration.html#authority-types',
    'admin/authorised_values'                  => '/administration.html#authorized-values',
    'admin/authtypes'                          => '/administration.html#authority-types',
    'admin/background_jobs'                    => '/administration.html#managing-jobs',
    'admin/biblio_framework'                   => '/administration.html#marc-bibliographic-frameworks',
    'admin/branch_transfer_limits'             => '/administration.html#library-transfer-limits',
    'admin/branches'                           => '/administration.html#libraries-&-groups',
    'admin/categories'                         => '/administration.html#patron-categories',
    'admin/checkmarc'                          => '/administration.html#marc-bibliographic-framework-test',
    'admin/cities'                             => '/administration.html#cities-and-towns',
    'admin/classsources'                       => '/administration.html#classification-sources',
    'admin/columns_settings'                   => '/administration.html#table-settings',
    'admin/curbside_pickup'                    => '/administration.html#curbside-pickup',
    'admin/currency'                           => '/administration.html#currencies-and-exchange-rates',
    'admin/credit_types'                       => '/administration.html#credit-types',
    'admin/debit_types'                        => '/administration.html#debit-types',
    'admin/didyoumean'                         => '/administration.html#did-you-mean',
    'admin/edi_accounts'                       => '/administration.html#edi-accounts',
    'admin/edi_ean_accounts'                   => '/administration.html#library-eans',
    'admin/identity_providers'                 => '/administration.html#identity-providers-label',
    'admin/item_circulation_alerts'            => '/administration.html#item-circulation-alerts',
    'admin/items_search_fields'                => '/administration.html#item-search-fields',
    'admin/itemtypes'                          => '/administration.html#item-types',
    'admin/koha2marclinks'                     => '/administration.html#koha-to-marc-mapping',
    'admin/library_groups'                     => '/administration.html#library-groups',
    'admin/marc_subfields_structure'           => '/administration.html#marc-bibliographic-frameworks',
    'admin/marc-overlay-rules'                 => '/administration.html#record-overlay-rules',
    'admin/marctagstructure'                   => '/administration.html#marc-bibliographic-frameworks',
    'admin/matching-rules'                     => '/administration.html#record-matching-rules',
    'admin/oai_set_mappings'                   => '/administration.html#oai-sets-configuration',
    'admin/oai_sets'                           => '/administration.html#oai-sets-configuration',
    'admin/patron-attr-types'                  => '/administration.html#patron-attribute-types',
    'admin/preferences'                        => '/globalpreferences.html',
    'admin/preferences#accounting'             => '/accountspreferences.html',
    'admin/preferences#acquisitions'           => '/acquisitionspreferences.html',
    'admin/preferences#admin'                  => '/administrationpreferences.html',
    'admin/preferences#authorities'            => '/authoritiespreferences.html',
    'admin/preferences#cataloguing'            => '/catalogingpreferences.html',
    'admin/preferences#circulation'            => '/circulationpreferences.html',
    'admin/preferences#enhanced_content'       => '/enhancedcontentpreferences.html',
    'admin/preferences#i18n_l10n'              => '/i18npreferences.html',
    'admin/preferences#logs'                   => '/logspreferences.html',
    'admin/preferences#opac'                   => '/opacpreferences.html',
    'admin/preferences#patrons'                => '/patronspreferences.html',
    'admin/preferences#searching'              => '/searchingpreferences.html',
    'admin/preferences#serials'                => '/serialspreferences.html',
    'admin/preferences#staff_interface'        => '/staffclientpreferences.html',
    'admin/preferences#staff_interface'        => '/staffclientpreferences.html',
    'admin/preferences#tools'                  => '/toolspreferences.html',
    'admin/preferences#web_services'           => '/webservicespreferences.html',
    'admin/smart-rules'                        => '/administration.html#circulation-and-fine-rules',
    'admin/smtp_servers'                       => '/administration.html#smtp-servers',
    'admin/restrictions'                       => '/administration.html#patron-restrictions',
    'admin/share_content'                      => '/administration.html#share-content-with-mana-kb',
    'admin/sms_providers'                      => '/administration.html#sms-cellular-providers',
    'admin/systempreferences'                  => '/localusepreferences.html',
    'admin/transport-cost-matrix'              => '/administration.html#transport-cost-matrix',
    'admin/z3950servers'                       => '/administration.html#z39.50/sru-servers',
    'admin/usage_statistics'                   => '/administration.html#share-your-usage-statistics',
    'authorities/authorities-home'             => '/cataloging.html#authorities',
    'authorities/authorities'                  => '/cataloging.html#authorities',
    'authorities/detail'                       => '/cataloging.html#authorities',
    'authorities/merge'                        => '/cataloging.html#merging-authorities',
    'catalogue/detail'                         => '/cataloging.html#bibliographic-records',
    'catalogue/issuehistory'                   => '/cataloging.html#item-specific-circulation-history',
    'catalogue/itemsearch'                     => '/searching.html#item-searching',
    'catalogue/moredetail'                     => '/cataloging.html#item-records',
    'catalogue/search-history'                 => '/plugins.html#search-history',
    'catalogue/search'                         => '/searching.html',
    'cataloguing/cataloging-home'              => '/cataloging.html',
    'cataloguing/addbiblio'                    => '/cataloging.html#bibliographic-records',
    'cataloguing/addbooks'                     => '/cataloging.html',
    'cataloguing/additem'                      => '/cataloging.html#item-records',
    'cataloguing/cataloging-home.pl'           => '/cataloging.html',
    'cataloguing/linkitem'                     => '/cataloging.html#adding-analytic-records',
    'cataloguing/merge'                        => '/cataloging.html#merging-records',
    'cataloguing/moveitem'                     => '/cataloging.html#moving-items',
    'circ/article-requests'                    => '/circulation.html#article-requests',
    'circ/branchoverdues'                      => '/circulation.html#overdues-with-fines',
    'circ/branchtransfers'                     => '/circulation.html#transfers',
    'circ/circulation-home'                    => '/circulation.html',
    'circ/circulation'                         => '/circulation.html#check-out-(issuing)',
    'circ/offline'                             => '/circulation.html#offline-circulation-in-koha',
    'circ/on-site_checkouts'                   => '/circulation.html#pending-on-site-checkouts',
    'circ/overdue'                             => '/circulation.html#overdues',
    'circ/pendingreserves'                     => '/circulation.html#holds-to-pull',
    'circ/renew'                               => '/circulation.html#renewing',
    'circ/reserveratios'                       => '/circulation.html#hold-ratios',
    'circ/returns'                             => '/circulation.html#check-in-returning',
    'circ/set-library'                         => '/circulation.html#set-library',
    'circ/transferstoreceive'                  => '/circulation.html#transfers-to-receive',
    'circ/view_holdsqueue'                     => '/circulation.html#holds-queue',
    'circ/waitingreserves'                     => '/circulation.html#holds-awaiting-pickup',
    'course_reserves/add_items'                => '/course_reserves.html',
    'course_reserves/course-details'           => '/course_reserves.html',
    'course_reserves/course-reserves'          => '/course_reserves.html',
    'course_reserves/course'                   => '/course_reserves.html#adding-courses',
    'erm/erm'                                  => '/erm.html',
    'erm/agreements'                           => '/erm.html#agreements',
    'erm/agreements/'                          => '/erm.html#search-and-view-an-agreement-record',
    'erm/agreements/add'                       => '/erm.html#create-an-agreement-record',
    'erm/agreements/edit/'                     => '/erm.html#create-an-agreement-record',
    'erm/licenses'                             => '/erm.html#licenses',
    'erm/licenses/'                            => '/erm.html#search-and-view-a-license-record',
    'erm/licenses/add'                         => '/erm.html#create-a-license-record',
    'erm/licenses/edit'                        => '/erm.html#create-a-license-record',
    'erm/eholdings/local/packages'             => '/erm.html#local',
    'erm/eholdings/local/packages/'            => '/erm.html#local',
    'erm/eholdings/local/packages/add'         => '/erm.html#local',
    'erm/eholdings/local/packages/edit/'       => '/erm.html#local',
    'erm/eholdings/local/titles'               => '/erm.html#titles-1',
    'erm/eholdings/local/titles/'              => '/erm.html#titles-1',
    'erm/eholdings/local/titles/add'           => '/erm.html#titles-1',
    'erm/eholdings/local/titles/edit/'         => '/erm.html#titles-1',
    'erm/eholdings/local/titles/import'        => '/erm.html#import-a-new-local-title-record-from-a-list',
    'erm/eholdings/local/resources/'           => '/erm.html#eholdings',
    'erm/eholdings/ebsco/packages'             => '/erm.html#packages',
    'erm/eholdings/ebsco/packages/'            => '/erm.html#packages',
    'erm/eholdings/ebsco/packages/add'         => '/erm.html#packages',
    'erm/eholdings/ebsco/packages/edit/'       => '/erm.html#packages',
    'erm/eholdings/ebsco/titles'               => '/erm.html#titles',
    'erm/eholdings/ebsco/titles/'              => '/erm.html#titles',
    'erm/eholdings/ebsco/titles/add'           => '/erm.html#titles',
    'erm/eholdings/ebsco/titles/edit/'         => '/erm.html#titles',
    'erm/eholdings/ebsco/resources/'           => '/erm.html#ebsco',
    'ill/ill-requests'                         => '/ILL_requests.html',
    'labels/barcode-print'                     => '/cataloging.html#barcode-generator',
    'labels/label-edit-batch'                  => '/cataloging.html#label-batches-label',
    'labels/label-edit-layout'                 => '/cataloging.html#label-layouts-label',
    'labels/label-edit-profile'                => '/cataloging.html#label-profiles-label',
    'labels/label-edit-range'                  => '/cataloging.html#barcode-range',
    'labels/label-edit-template'               => '/cataloging.html#label-templates-label',
    'labels/label-home'                        => '/cataloging.html#label-creator-label',
    'labels/label-manage'                      => '/cataloging.html#label-creator-label',
    'labels/spinelabel-home'                   => '/cataloging.html#quick-spine-label-creator',
    'mainpage'                                 => '/',
    'members/apikeys'                          => '/webservices.html#api-key-management-interface-for-patrons',
    'members/boraccount'                       => '/patrons.html#fines',
    'members/discharge'                        => '/patrons.html#patron-discharges',
    'members/files'                            => '/patrons.html#files',
    'members/mancredit'                        => '/patrons.html#creating-manual-credits',
    'members/maninvoice'                       => '/patrons.html#creating-manual-invoices',
    'members/member-flags'                     => '/patrons.html#patron-permissions',
    'members/member-password'                  => '/patrons.html#editing-patrons',
    'members/member'                           => '/patrons.html#patron-search',
    'members/memberentry'                      => '/patrons.html#add-a-new-patron',
    'members/members-home'                     => '/patrons.html',
    'members/members-update'                   => '/patrons.html#managing-patron-self-edits',
    'members/moremember'                       => '/patrons.html#patron-information',
    'members/notices'                          => '/patrons.html#notices',
    'members/pay'                              => '/patrons.html#pay/reverse-fines',
    'members/paycollect'                       => '/patrons.html#pay/reverse-fines',
    'members/purchase-suggestions'             => '/patrons.html#purchase-suggestions',
    'members/readingrec'                       => '/patrons.html#circulation-history',
    'members/routing-lists'                    => '/patrons.html#routing-lists',
    'members/statistics'                       => '/patrons.html#statistics',
    'offline_circ/list'                        => '/circulation.html#offline-circulation-utilities',
    'offline_circ/process_koc'                 => '/circulation.html#upload-offline-circ-file',
    'patron_lists/lists'                       => '/tools.html#patron-lists',
    'patroncards/edit-batch'                   => '/tools.html#batches',
    'patroncards/edit-layout'                  => '/tools.html#layouts',
    'patroncards/edit-profile'                 => '/tools.html#profiles',
    'patroncards/edit-template'                => '/tools.html#templates',
    'patroncards/home'                         => '/tools.html#patron-card-creator',
    'patroncards/image-manage'                 => '/tools.html#manage-images',
    'patroncards/manage'                       => '/tools.html#patron-card-creator',
    'plugins/plugins-home'                     => '/plugins.html',
    'plugins/plugins-upload'                   => '/plugins.html',
    'reports/acquisitions_stats'               => '/reports.html#acquisitions-statistics',
    'reports/bor_issues_top'                   => '/reports.html#patrons-with-the-most-checkouts',
    'reports/borrowers_out'                    => '/reports.html#patrons-with-no-checkouts',
    'reports/borrowers_stats'                  => '/reports.html#patron-statistics',
    'reports/cat_issues_top'                   => '/reports.html#most-circulated-items',
    'reports/catalogue_out'                    => '/reports.html#items-with-no-checkouts',
    'reports/catalogue_stats'                  => '/reports.html#catalog-statistics',
    'reports/dictionary'                       => '/reports.html#report-dictionary',
    'reports/guided_reports'                   => '/reports.html#custom-reports',
    'reports/issues_avg_stats'                 => '/reports.html#average-loan-time',
    'reports/issues_stats'                     => '/reports.html#circulation-statistics',
    'reports/itemslost'                        => '/reports.html#lost-items',
    'reports/manager'                          => '/reports.html#catalog-by-item-type',
    'reports/reports-home'                     => '/reports.html',
    'reports/reserves_stats'                   => '/reports.html#holds-statistics',
    'reports/serials_stats'                    => '/reports.html#serials-statistics',
    'reserve/request'                          => '/circulation.html#holds',
    'reviews/reviewswaiting'                   => '/tools.html#comments',
    'rotating_collections/rotatingCollections' => '/tools.html#rotating-collections',
    'serials/checkexpiration'                  => '/serials.html#check-serial-expiration',
    'serials/claims'                           => '/serials.html#claim-late-serials',
    'serials/routing'                          => '/serials.html#create-a-routing-list',
    'serials/serials-collection'               => '/serials.html',
    'serials/serials-edit'                     => '/serials.html#receive-issues',
    'serials/serials-home'                     => '/serials.html',
    'serials/subscription-add'                 => '/serials.html#add-a-subscription',
    'serials/subscription-detail'              => '/serials.html',
    'serials/subscription-frequencies'         => '/serials.html#manage-serial-frequencies',
    'serials/subscription-numberpatterns'      => '/serials.html#manage-serial-numbering-patterns',
    'suggestion/suggestion'                    => '/acquisitions.html#managing-suggestions',
    'tags/list'                                => '/tools.html#tag-moderation',
    'tags/review'                              => '/tools.html#tag-moderation',
    'tools/access_files'                       => '/tools.html#access-files',
    'tools/automatic_item_modification_by_age' => '/cataloging.html#automatic-item-editing-by-age',
    'tools/batchMod'                           => '/cataloging.html#batch-editing-items',
    'tools/batch_extend_due_dates'             => '/tools.html#batch-extend-due-dates',
    'tools/batch_delete_records'               => '/cataloging.html#batch-deleting-records',
    'tools/batch_record_modification'          => '/cataloging.html#batch-record-modification',
    'tools/cleanborrowers'                     => '/tools.html#patrons-anonymize-bulk-delete',
    'tools/csv-profiles'                       => '/tools.html#csv-profiles',
    'tools/export'                             => '/cataloging.html#exporting-data',
    'tools/holidays'                           => '/tools.html#calendar',
    'tools/import_borrowers'                   => '/tools.html#patron-import',
    'tools/inventory'                          => '/cataloging.html#inventory',
    'tools/additional-contents'                => '/tools.html#news', # FIXME Needs a change to the manual
    'tools/letter'                             => '/tools.html#notices-slips',
    'tools/manage-marc-import'                 => '/cataloging.html#managing-staged-records',
    'tools/marc_modification_templates'        => '/cataloging.html#marc-modification-templates',
    'tools/modborrowers'                       => '/tools.html#batch-patron-modification',
    'tools/overduerules'                       => '/tools.html#overdue-notice-status-triggers',
    'tools/picture-upload'                     => '/tools.html#upload-patron-images',
    'tools/quotes-upload'                      => '/tools.html#import-quotes',
    'tools/quotes'                             => '/tools.html#quote-of-the-day-(qotd)-editor',
    'tools/scheduler'                          => '/tools.html#task-scheduler',
    'tools/stage-marc-import'                  => '/cataloging.html#staging-records-for-import',
    'tools/tools-home'                         => '/tools.html',
    'tools/upload-cover-image'                 => '/cataloging.html#adding-cover-images',
    'tools/viewlog'                            => '/tools.html#log-viewer',
    'virtualshelves/shelves'                   => '/lists.html#lists',
};

sub get_url {
    my ( $url, $preferred_language ) = @_;
    my $file;
    if ($url =~ /koha\/(.*)\.pl/ || $url =~ '/koha/(erm.*)') {
        $file = $1;
    } else {
        $file = 'mainpage';
    }
    $file =~ s/[^a-zA-Z0-9_\-\/]*//g;

    if ( $file =~ m|^erm| ) {
        $file =~ s|\d*$||;
    }

    my $view;
    if ($url =~ /(?:\?|\&)tab=(?<value>[\w+,.-]*)/) {
        $view = $file . '#' . $+{value};
    }

    my $base_url = _get_base_url( $preferred_language );
    return $base_url
      . (
          exists $mapping->{$view} ? $mapping->{$view}
        : exists $mapping->{$file} ? $mapping->{$file}
        :                            $mapping->{mainpage}
      );
}

1;
