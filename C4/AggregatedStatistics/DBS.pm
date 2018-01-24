package C4::AggregatedStatistics::DBS;

use strict;
use warnings;
use CGI qw ( -utf8 );
use Data::Dumper;

use C4::Context;
use C4::Branch;
use C4::Auth;
use C4::Output;
use C4::Reports::Guided;
use Koha::DateUtils;



my $debug = 1;
my $dbh = C4::Context->dbh;

my $as_values = {};    # hash for storing all read records from table aggregated_statistics_values for one statistics_id, with aggregated_statistics_values.name as key
# general information / 1. ALLGEMEINE ANGABEN
$as_values->{'gen_dbs_id'} = { 'id' => '', 'name' => 'gen_dbs_id', 'value' => '', 'type' => 'text' };
$as_values->{'gen_population'} = { 'id' => '', 'name' => 'gen_population', 'value' => '', 'type' => 'int' };
$as_values->{'gen_libcount'} = { 'id' => '', 'name' => 'gen_libcount', 'value' => '', 'type' => 'int' };
$as_values->{'gen_branchcount'} = { 'id' => '', 'name' => 'gen_branchcount', 'value' => '', 'type' => 'int' };
$as_values->{'gen_buscount'} = { 'id' => '', 'name' => 'gen_buscount', 'value' => '', 'type' => 'int' };
$as_values->{'gen_extservlocation'} = { 'id' => '', 'name' => 'gen_extservlocation', 'value' => '', 'type' => 'int' };
$as_values->{'gen_publicarea'} = { 'id' => '', 'name' => 'gen_publicarea', 'value' => '', 'type' => 'float' };
$as_values->{'gen_openinghours_year'} = { 'id' => '', 'name' => 'gen_openinghours_year', 'value' => '', 'type' => 'float' };
$as_values->{'gen_openinghours_week'} = { 'id' => '', 'name' => 'gen_openinghours_week', 'value' => '', 'type' => 'float' };

# patron information / 2. BENUTZER
$as_values->{'pat_active'} = { 'id' => '', 'name' => 'pat_active', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_pat_active'] };                                               # DBS2017:9
$as_values->{'pat_active_to_12'} = { 'id' => '', 'name' => 'pat_active_to_12', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_pat_active_to_12'] };                             # DBS2017:10.1
$as_values->{'pat_active_from_60'} = { 'id' => '', 'name' => 'pat_active_from_60', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_pat_active_from_60'] };                       # DBS2017:10.2
$as_values->{'pat_new_registrations'} = { 'id' => '', 'name' => 'pat_new_registrations', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_pat_new_registrations'] };              # DBS2017:11
$as_values->{'pat_visits'} = { 'id' => '', 'name' => 'pat_visits', 'value' => '', 'type' => 'int' };
$as_values->{'pat_visits_virt'} = { 'id' => '', 'name' => 'pat_visits_virt', 'value' => '', 'type' => 'int' };    # input deactivated

# media offers and usage / 3. MEDIENANGEBOTE UND NUTZUNG
$as_values->{'med_tot_phys_stock'} = { 'id' => '', 'name' => 'med_tot_phys_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_tot_phys_stock'] };                       # DBS2017:13
$as_values->{'med_tot_issues'} = { 'id' => '', 'name' => 'med_tot_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_tot_issues'] };                                   # DBS2017:14
$as_values->{'med_phys_issues'} = { 'id' => '', 'name' => 'med_phys_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_phys_issues'] };                                # DBS2017:14.1
$as_values->{'med_openaccess_stock'} = { 'id' => '', 'name' => 'med_openaccess_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_openaccess_stock'] };                 # DBS2017:15
$as_values->{'med_openaccess_issues'} = { 'id' => '', 'name' => 'med_openaccess_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_openaccess_issues'] };              # DBS2017:16
$as_values->{'med_stack_stock'} = { 'id' => '', 'name' => 'med_stack_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_stack_stock'] };                                # DBS2017:17
$as_values->{'med_print_stock'} = { 'id' => '', 'name' => 'med_print_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_print_stock'] };                                # DBS2017:18
$as_values->{'med_print_issues'} = { 'id' => '', 'name' => 'med_print_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_print_issues'] };                             # DBS2017:19
$as_values->{'med_nonfiction_stock'} = { 'id' => '', 'name' => 'med_nonfiction_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonfiction_stock'] };                 # DBS2017:20
$as_values->{'med_nonfiction_issues'} = { 'id' => '', 'name' => 'med_nonfiction_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonfiction_issues'] };              # DBS2017:21
$as_values->{'med_fiction_stock'} = { 'id' => '', 'name' => 'med_fiction_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_fiction_stock'] };                          # DBS2017:22
$as_values->{'med_fiction_issues'} = { 'id' => '', 'name' => 'med_fiction_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_fiction_issues'] };                       # DBS2017:23
$as_values->{'med_juvenile_stock'} = { 'id' => '', 'name' => 'med_juvenile_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_juvenile_stock'] };                       # DBS2017:24
$as_values->{'med_juvenile_issues'} = { 'id' => '', 'name' => 'med_juvenile_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_juvenile_issues'] };                    # DBS2017:25
$as_values->{'med_printissue_stock'} = { 'id' => '', 'name' => 'med_printissue_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_printissue_stock'] };                 # DBS2017:26
$as_values->{'med_printissue_issues'} = { 'id' => '', 'name' => 'med_printissue_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_printissue_issues'] };              # DBS2017:27
$as_values->{'med_nonbook_tot_stock'} = { 'id' => '', 'name' => 'med_nonbook_tot_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonbook_tot_stock'] };              # DBS2017:28
$as_values->{'med_nonbook_tot_issues'} = { 'id' => '', 'name' => 'med_nonbook_tot_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonbook_tot_issues'] };           # DBS2017:29
$as_values->{'med_nonbook_anadig_stock'} = { 'id' => '', 'name' => 'med_nonbook_anadig_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonbook_anadig_stock'] };     # DBS2017:30
$as_values->{'med_nonbook_anadig_issues'} = { 'id' => '', 'name' => 'med_nonbook_anadig_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonbook_anadig_issues'] };  # DBS2017:31
$as_values->{'med_nonbook_other_stock'} = { 'id' => '', 'name' => 'med_nonbook_other_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonbook_other_stock'] };        # DBS2017:32
$as_values->{'med_nonbook_other_issues'} = { 'id' => '', 'name' => 'med_nonbook_other_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_nonbook_other_issues'] };     # DBS2017:33
$as_values->{'med_virtsupply_stock'} = { 'id' => '', 'name' => 'med_virtsupply_stock', 'value' => '', 'type' => 'int' };
$as_values->{'med_virtconsort_stock'} = { 'id' => '', 'name' => 'med_virtconsort_stock', 'value' => '', 'type' => 'int' };
$as_values->{'med_consort_libcount'} = { 'id' => '', 'name' => 'med_consort_libcount', 'value' => '', 'type' => 'int' };
$as_values->{'med_virtsupply_issues'} = { 'id' => '', 'name' => 'med_virtsupply_issues', 'value' => '', 'type' => 'int' };
$as_values->{'med_access_units'} = { 'id' => '', 'name' => 'med_access_units', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_access_units'] };                             # DBS2017:36
$as_values->{'med_withdrawal_units'} = { 'id' => '', 'name' => 'med_withdrawal_units', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_withdrawal_units'] };                 # DBS2017:37
$as_values->{'med_database_cnt'} = { 'id' => '', 'name' => 'med_database_cnt', 'value' => '', 'type' => 'int' };
$as_values->{'med_subscription_print'} = { 'id' => '', 'name' => 'med_subscription_print', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_med_subscription_print'] };           # DBS2017:39
$as_values->{'med_subscription_elect'} = { 'id' => '', 'name' => 'med_subscription_elect', 'value' => '', 'type' => 'int' };
$as_values->{'med_blockcollection_rcvd'} = { 'id' => '', 'name' => 'med_blockcollection_rcvd', 'value' => '', 'type' => 'int' };
$as_values->{'med_blockcollection_lent'} = { 'id' => '', 'name' => 'med_blockcollection_lent', 'value' => '', 'type' => 'int' };
$as_values->{'med_ILL_borrowing_orders'} = { 'id' => '', 'name' => 'med_ILL_borrowing_orders', 'value' => '', 'type' => 'int' };
$as_values->{'med_ILL_lending_orders'} = { 'id' => '', 'name' => 'med_ILL_lending_orders', 'value' => '', 'type' => 'int' };
$as_values->{'med_document_delivery'} = { 'id' => '', 'name' => 'med_document_delivery', 'value' => '', 'type' => 'int' };

# finance / 4. FINANZEN
$as_values->{'fin_current_expenses_tot'} = { 'id' => '', 'name' => 'fin_current_expenses_tot', 'value' => '', 'type' => 'float' };
$as_values->{'fin_cur_exp_acquisitions'} = { 'id' => '', 'name' => 'fin_cur_exp_acquisitions', 'value' => '', 'type' => 'float' };
$as_values->{'fin_cur_exp_acq_licences'} = { 'id' => '', 'name' => 'fin_cur_exp_acq_licences', 'value' => '', 'type' => 'float' };
$as_values->{'fin_cur_exp_staff'} = { 'id' => '', 'name' => 'fin_cur_exp_staff', 'value' => '', 'type' => 'float' };
$as_values->{'fin_cur_exp_other'} = { 'id' => '', 'name' => 'fin_cur_exp_other', 'value' => '', 'type' => 'float' };
$as_values->{'fin_singulary_investments'} = { 'id' => '', 'name' => 'fin_singulary_investments', 'value' => '', 'type' => 'float' };
$as_values->{'fin_expenses_tot'} = { 'id' => '', 'name' => 'fin_expenses_tot', 'value' => '', 'type' => 'float' };
$as_values->{'fin_costunit_funds_tot'} = { 'id' => '', 'name' => 'fin_costunit_funds_tot', 'value' => '', 'type' => 'float' };
$as_values->{'fin_costunit_expenses'} = { 'id' => '', 'name' => 'fin_costunit_expenses', 'value' => '', 'type' => 'float' };
$as_values->{'fin_external_funds_tot'} = { 'id' => '', 'name' => 'fin_external_funds_tot', 'value' => '', 'type' => 'float' };
$as_values->{'fin_ext_funds_EU'} = { 'id' => '', 'name' => 'fin_ext_funds_EU', 'value' => '', 'type' => 'float' };
$as_values->{'fin_ext_funds_national'} = { 'id' => '', 'name' => 'fin_ext_funds_national', 'value' => '', 'type' => 'float' };
$as_values->{'fin_ext_funds_fedstate'} = { 'id' => '', 'name' => 'fin_ext_funds_fedstate', 'value' => '', 'type' => 'float' };
$as_values->{'fin_ext_funds_communal'} = { 'id' => '', 'name' => 'fin_ext_funds_communal', 'value' => '', 'type' => 'float' };
$as_values->{'fin_ext_funds_church'} = { 'id' => '', 'name' => 'fin_ext_funds_church', 'value' => '', 'type' => 'float' };
$as_values->{'fin_ext_funds_other'} = { 'id' => '', 'name' => 'fin_ext_funds_other', 'value' => '', 'type' => 'float' };
$as_values->{'fin_lib_revenue'} = { 'id' => '', 'name' => 'fin_lib_revenue', 'value' => '', 'type' => 'float' };
$as_values->{'fin_user_charge_yn'} = { 'id' => '', 'name' => 'fin_user_charge_yn', 'value' => '', 'type' => 'bool' };

# staff capacity / 5. PERSONALKAPAZITÄT
$as_values->{'stf_staff_scheme_appointments'} = { 'id' => '', 'name' => 'stf_staff_scheme_appointments', 'value' => '', 'type' => 'int' };
$as_values->{'stf_staff_cnt'} = { 'id' => '', 'name' => 'stf_staff_cnt', 'value' => '', 'type' => 'int' };
$as_values->{'stf_capacity_FTE'} = { 'id' => '', 'name' => 'stf_capacity_FTE', 'value' => '', 'type' => 'float' };
$as_values->{'stf_cap_FTE_librarians'} = { 'id' => '', 'name' => 'stf_cap_FTE_librarians', 'value' => '', 'type' => 'float' };
$as_values->{'stf_cap_FTE_assistants'} = { 'id' => '', 'name' => 'stf_cap_FTE_assistants', 'value' => '', 'type' => 'float' };
$as_values->{'stf_cap_FTE_promotional'} = { 'id' => '', 'name' => 'stf_cap_FTE_promotional', 'value' => '', 'type' => 'float' };
$as_values->{'stf_cap_FTE_others'} = { 'id' => '', 'name' => 'stf_cap_FTE_others', 'value' => '', 'type' => 'float' };
$as_values->{'stf_honorary_cnt'} = { 'id' => '', 'name' => 'stf_honorary_cnt', 'value' => '', 'type' => 'int' };
$as_values->{'stf_cap_FTE_honorary'} = { 'id' => '', 'name' => 'stf_cap_FTE_honorary', 'value' => '', 'type' => 'float' };
$as_values->{'stf_apprentices_cnt'} = { 'id' => '', 'name' => 'stf_apprentices_cnt', 'value' => '', 'type' => 'int' };
$as_values->{'stf_advanced_training_hrs'} = { 'id' => '', 'name' => 'stf_advanced_training_hrs', 'value' => '', 'type' => 'float' };

# services / 6. SERVICES / DIENSTLEISTUNGEN
$as_values->{'srv_patron_recherches'} = { 'id' => '', 'name' => 'srv_patron_recherches', 'value' => '', 'type' => 'int' };
$as_values->{'srv_patron_workplaces'} = { 'id' => '', 'name' => 'srv_patron_workplaces', 'value' => '', 'type' => 'int' };
$as_values->{'srv_pat_workplc_inclopac'} = { 'id' => '', 'name' => 'srv_pat_workplc_inclopac', 'value' => '', 'type' => 'int' };
$as_values->{'srv_pat_workplc_web'} = { 'id' => '', 'name' => 'srv_pat_workplc_web', 'value' => '', 'type' => 'int' };
$as_values->{'srv_libhomepage_yn'} = { 'id' => '', 'name' => 'srv_libhomepage_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_webopac_yn'} = { 'id' => '', 'name' => 'srv_webopac_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_interactive_yn'} = { 'id' => '', 'name' => 'srv_interactive_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_socialweb_yn'} = { 'id' => '', 'name' => 'srv_socialweb_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_emailquery_yn'} = { 'id' => '', 'name' => 'srv_emailquery_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_virtualstock_yn'} = { 'id' => '', 'name' => 'srv_virtualstock_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_activeinfo_yn'} = { 'id' => '', 'name' => 'srv_activeinfo_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_publicwlan_yn'} = { 'id' => '', 'name' => 'srv_publicwlan_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_socialwork_yn'} = { 'id' => '', 'name' => 'srv_socialwork_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_events_tot'} = { 'id' => '', 'name' => 'srv_events_tot', 'value' => '', 'type' => 'int' };
$as_values->{'srv_evt_libintro'} = { 'id' => '', 'name' => 'srv_evt_libintro', 'value' => '', 'type' => 'int' };
$as_values->{'srv_evt_juvenile'} = { 'id' => '', 'name' => 'srv_evt_juvenile', 'value' => '', 'type' => 'int' };
$as_values->{'srv_evt_adult'} = { 'id' => '', 'name' => 'srv_evt_adult', 'value' => '', 'type' => 'int' };
$as_values->{'srv_evt_exhibition'} = { 'id' => '', 'name' => 'srv_evt_exhibition', 'value' => '', 'type' => 'int' };
$as_values->{'srv_evt_other'} = { 'id' => '', 'name' => 'srv_evt_other', 'value' => '', 'type' => 'int' };
$as_values->{'srv_school_libs'} = { 'id' => '', 'name' => 'srv_school_libs', 'value' => '', 'type' => 'int' };
$as_values->{'srv_admin_libs'} = { 'id' => '', 'name' => 'srv_admin_libs', 'value' => '', 'type' => 'int' };
$as_values->{'srv_contracts'} = { 'id' => '', 'name' => 'srv_contracts', 'value' => '', 'type' => 'int' };
$as_values->{'srv_rfidcheckio_yn'} = { 'id' => '', 'name' => 'srv_rfidcheckio_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_mobiledevices_yn'} = { 'id' => '', 'name' => 'srv_mobiledevices_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'srv_remarks'} = { 'id' => '', 'name' => 'srv_remarks', 'value' => '', 'type' => 'text' };

# patients' libraries / PATIENTENBIBLIOTHEKEN
$as_values->{'ptl_clinical_network_yn'} = { 'id' => '', 'name' => 'ptl_clinical_network_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'ptl_clinet_clinics'} = { 'id' => '', 'name' => 'ptl_clinet_clinics', 'value' => '', 'type' => 'int' };
$as_values->{'ptl_clinet_patientslibs'} = { 'id' => '', 'name' => 'ptl_clinet_patientslibs', 'value' => '', 'type' => 'int' };
$as_values->{'ptl_clinic_beds'} = { 'id' => '', 'name' => 'ptl_clinic_beds', 'value' => '', 'type' => 'int' };
$as_values->{'ptl_outpatients'} = { 'id' => '', 'name' => 'ptl_outpatients', 'value' => '', 'type' => 'int' };
$as_values->{'ptl_trolley_service_yn'} = { 'id' => '', 'name' => 'ptl_trolley_service_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'ptl_trolley_service_hrs'} = { 'id' => '', 'name' => 'ptl_trolley_service_hrs', 'value' => '', 'type' => 'float' };
$as_values->{'ptl_laptop_service_yn'} = { 'id' => '', 'name' => 'ptl_laptop_service_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'ptl_mediaplayer_service_yn'} = { 'id' => '', 'name' => 'ptl_mediaplayer_service_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'ptl_medical_lib_yn'} = { 'id' => '', 'name' => 'ptl_medical_lib_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'ptl_combined_lib_yn'} = { 'id' => '', 'name' => 'ptl_combined_lib_yn', 'value' => '', 'type' => 'bool' };

# mobile libraries / FAHRBIBLIOTHEKEN
$as_values->{'mol_vehicles'} = { 'id' => '', 'name' => 'mol_vehicles', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_mol_vehicles'] };                                         # DBS2017:300
$as_values->{'mol_multiple_communes_yn'} = { 'id' => '', 'name' => 'mol_multiple_communes_yn', 'value' => '', 'type' => 'bool' };
$as_values->{'mol_stop_stations'} = { 'id' => '', 'name' => 'mol_stop_stations', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_mol_stop_stations'] };                          # DBS2017:302
$as_values->{'mol_cycle_days'} = { 'id' => '', 'name' => 'mol_cycle_days', 'value' => '', 'type' => 'int' };
$as_values->{'mol_openinghours_week'} = { 'id' => '', 'name' => 'mol_openinghours_week', 'value' => '', 'type' => 'float' };
$as_values->{'mol_stock_media_units'} = { 'id' => '', 'name' => 'mol_stock_media_units', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_mol_stock_media_units'] };              # DBS2017:305
$as_values->{'mol_media_unit_issues'} = { 'id' => '', 'name' => 'mol_media_unit_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_report, 'param' => ['DBS_mol_media_unit_issues'] };              # DBS2017:306

# music libraries / MUSIKBIBLIOTHEKEN
$as_values->{'mus_sheetmusic_stock'} = { 'id' => '', 'name' => 'mus_sheetmusic_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_sheetmusic_issues'} = { 'id' => '', 'name' => 'mus_sheetmusic_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_secondarylit_stock'} = { 'id' => '', 'name' => 'mus_secondarylit_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_secondarylit_issues'} = { 'id' => '', 'name' => 'mus_secondarylit_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_cd_stock'} = { 'id' => '', 'name' => 'mus_cd_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_cd_issues'} = { 'id' => '', 'name' => 'mus_cd_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_cassette_stock'} = { 'id' => '', 'name' => 'mus_cassette_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_cassette_issues'} = { 'id' => '', 'name' => 'mus_cassette_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_record_stock'} = { 'id' => '', 'name' => 'mus_record_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_record_issues'} = { 'id' => '', 'name' => 'mus_record_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_VHS_stock'} = { 'id' => '', 'name' => 'mus_VHS_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_VHS_issues'} = { 'id' => '', 'name' => 'mus_VHS_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_DVD_stock'} = { 'id' => '', 'name' => 'mus_DVD_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_DVD_issues'} = { 'id' => '', 'name' => 'mus_DVD_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_periodicals_stock'} = { 'id' => '', 'name' => 'mus_periodicals_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_periodicals_issues'} = { 'id' => '', 'name' => 'mus_periodicals_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_other_stock'} = { 'id' => '', 'name' => 'mus_other_stock', 'value' => '', 'type' => 'int' };
$as_values->{'mus_other_issues'} = { 'id' => '', 'name' => 'mus_other_issues', 'value' => '', 'type' => 'int' };
$as_values->{'mus_stock_tot'} = { 'id' => '', 'name' => 'mus_stock_tot', 'value' => '', 'type' => 'int' };
$as_values->{'mus_issues_tot'} = { 'id' => '', 'name' => 'mus_issues_tot', 'value' => '', 'type' => 'int' };
$as_values->{'mus_audioplaybacks'} = { 'id' => '', 'name' => 'mus_audioplaybacks', 'value' => '', 'type' => 'int' };
$as_values->{'mus_acq_expenses'} = { 'id' => '', 'name' => 'mus_acq_expenses', 'value' => '', 'type' => 'float' };


my @categories;
my @branchloop;

# 1. section: functions required for aggregated-statistics-parameters-DBS.inc

# prepare the form part for adding / editing / copying aggregated_statistics_parameter records
# ( the form is contained in aggregated_statistics.tt, the form part in aggregated-statistics-parameters-DBS.inc )
sub add_form_parameters {
    my ($template, $input, $aggregated_statistics_id) = @_;

    print STDERR "C4::AggregatedStatistics::DBS::add_form_parameters NOW IT IS USED!\n" if $debug;
    print STDERR "C4::AggregatedStatistics::DBS::add_form_parameters Dumper(input):", Dumper($input), ":\n" if $debug;
    print STDERR "C4::AggregatedStatistics::DBS::add_form_parameters input->param('selectedgroup')", scalar $input->param('selectedgroup'), ": input->param('selectedbranch')", scalar $input->param('selectedbranch'), ":\n" if $debug;

    my $selectedgroup  = $input->param('selectedgroup') || '*';
    my $selectedbranch = $input->param('selectedbranch') || '*';

    if ( defined($aggregated_statistics_id) && length($aggregated_statistics_id) > 0 ) {
        my $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters(
            {
                statistics_id => $aggregated_statistics_id,
                name => 'branchgroup',
            }
        );
print STDERR "C4::AggregatedStatistics::DBS::add_form_parameters sel:name='branchgroup'   count aggregatedStatisticsParameters:", $aggregatedStatisticsParameters->_resultset()+0, ":\n" if $debug;
        if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset() && $aggregatedStatisticsParameters->_resultset()->first()) {
            my $rsHit = $aggregatedStatisticsParameters->_resultset()->first();
            if ( length($rsHit->get_column('value')) > 0 ) {
                $selectedgroup = $rsHit->get_column('value');
            }
        }

        $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters(
            {
                statistics_id => $aggregated_statistics_id,
                name => 'branchcode',
            }
        );
print STDERR "C4::AggregatedStatistics::DBS::add_form_parameters sel:name='branchcode'   count aggregatedStatisticsParameters:", $aggregatedStatisticsParameters->_resultset()+0, ":\n" if $debug;
        if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset() && $aggregatedStatisticsParameters->_resultset()->first()) {
            my $rsHit = $aggregatedStatisticsParameters->_resultset()->first();
            if ( length($rsHit->get_column('value')) > 0 ) {
                $selectedbranch = $rsHit->get_column('value');
            }
        }
    }

    &read_categories_and_branches();    # sets variables @categories and @branchloop;

    # set template paramater
    $template->param(
                        categories => \@categories,
                        branchloop => \@branchloop,
                        selectedgroup => $selectedgroup,
                        selectedbranch => $selectedbranch
                        
    );

}

# evaluate the form part for adding / editing / copying aggregated_statistics_parameter records
# ( the form is contained in aggregated_statistics.tt, the form part in aggregated-statistics-parameters-DBS.inc )
sub add_validate_parameters {
    my ($input, $aggregated_statistics_id) = @_;
    my $res;


print STDERR "C4::AggregatedStatistics::DBS::add_validate_parameters NOW IT IS USED! aggregated_statistics_id:$aggregated_statistics_id\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::add_validate_parameters Dumper(input):", Dumper($input), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::add_validate_parameters input->param(selectedgroup):", scalar $input->param('selectedgroup'), ": input->param(selectedbranch):", scalar $input->param('selectedbranch'), ":\n" if $debug;

    my $selectedgroup = $input->param('selectedgroup');
    $selectedgroup = '' if ( !defined($selectedgroup) or $selectedgroup eq '*' );
    my $selectedbranch = $input->param('selectedbranch');
    $selectedbranch = '' if ( !defined($selectedbranch) or $selectedbranch eq '*' );
    

    if ( length($aggregated_statistics_id) > 0 ) {
        my $selParam = { 
            statistics_id => $aggregated_statistics_id
        };
        $res = C4::AggregatedStatistics::DelAggregatedStatisticsParameters($selParam);    # delete all entries from aggregated_statistics_parameters where statistics_id = $id

        my $insParam = { 
            statistics_id => $aggregated_statistics_id,
            name => 'branchgroup',
            value => $selectedgroup
        };
        $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );

        $insParam = { 
            statistics_id => $aggregated_statistics_id,
            name => 'branchcode',
            value => $selectedbranch
        };
        $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );
    }
}

sub read_categories_and_branches {

    # read library categories into variable @categories
    for my $category ( Koha::LibraryCategories->search ) {    # fields used in template: category.categorycode and category.categoryname
        push @categories, $category->unblessed();
        print STDERR "C4::AggregatedStatistics::DBS::read_categories_and_branches category->unblessed categorycode:", $category->unblessed->{'categorycode'},  ": categoryname:", $category->unblessed->{'categoryname'}, ":\n" if $debug;
    }

    # read branch information into variable @branchloop
    my $branches = GetBranches();
    for my $loopbranch (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %$branches) {
        push @branchloop, {
            value      => $loopbranch,
            selected   => 0,
            branchname => $branches->{$loopbranch}->{'branchname'},
            branchcode => $branches->{$loopbranch}->{'branchcode'},
            category   => $branches->{$loopbranch}->{'category'}
        };
    }
}


# 2. section: functions required for aggregated_statistics_DBS.tt

sub eval_form {
    my ($script_name, $input, $aggregated_statistics_id, $input_st) = @_;
    my $res;
print STDERR "C4::AggregatedStatistics::DBS::eval_form Start statisticstype:$input->param('statisticstype'): statisticstypedesignation:$input->param('statisticstypedesignation'): name:$input->param('name'): startdate:$input->param('startdate'): enddate:$input->param('enddate'):\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::eval_form Start aggregated_statistics_id:$aggregated_statistics_id: input_st:", $input_st, ": statisticstype:", scalar $input->param('statisticstype'), ": statisticstypedesignation:", scalar $input->param('statisticstypedesignation'), ": name:", scalar $input->param('name'), ": startdate:", scalar $input->param('startdate') ,": enddate:", scalar $input->param('enddate'), ":\n" if $debug;

    our ( $template, $borrowernumber, $cookie, $staffflags ) = get_template_and_user(
        {
            template_name   => 'reports/aggregated_statistics_DBS.tt',
            query           => $input,
            type            => 'intranet',
            authnotrequired => 0,
            flagsrequired   => { },
            debug           => 1,
        }
    );

    my $branchgroup = readAggregatedStatisticsParametersValue($aggregated_statistics_id, 'branchgroup');
    my $branchcode = readAggregatedStatisticsParametersValue($aggregated_statistics_id, 'branchcode');

    my $selectedgroup  = $branchgroup || '*';
    my $selectedbranch = $branchcode || '*';

    my $category = Koha::LibraryCategories->search( { 'categorycode' => $branchgroup } )->_resultset->first;
print STDERR "C4::AggregatedStatistics::DBS::eval_form Dumper(category):", Dumper($category), ":\n" if $debug;
    my $selectedgroupname = ($category && $category->{'_column_data'} && $category->{'_column_data'}->{'categoryname'}) ? $category->{'_column_data'}->{'categoryname'} : '*';
    my $selectedbranchname = GetBranchName($branchcode);
print STDERR "C4::AggregatedStatistics::DBS::eval_form branchcode:$branchcode: selectedbranchname:$selectedbranchname:\n" if $debug;

    # basic fields
    $template->param(
    	script_name => $script_name,
    	action => $script_name,
        #searchfield => $searchfield,
        id => scalar $input->param('id'),
        #id => 4711,
        statisticstype => scalar $input->param('statisticstype'),
        statisticstypedesignation => scalar $input->param('statisticstypedesignation'),
    	name => scalar $input->param('name'),
    	description => scalar $input->param('description'),
    	startdate => scalar $input->param('startdate'),
    	enddate => scalar $input->param('enddate'),
    	selectedgroup => $selectedgroup,
    	selectedbranch => $selectedbranch,
        selectedgroupname => $selectedgroupname,
        selectedbranchname => $selectedbranchname
    );

    # DBS list fields
    my $st = {};
    if ( defined($input_st) ) {
        # set values from input_st
        foreach my $name (keys %{$as_values}) {
            $as_values->{$name}->{'value'} = $input_st->param('st_' . $name);
            if ( $as_values->{$name}->{'type'} eq 'float' ) {
                $as_values->{$name}->{'value'} =~ tr/,/./;      # decimal separator for float is '.'
            }
            $st->{$name} = $as_values->{$name}->{'value'};
    }
    } else {
        my $dbs_values = dbs_read($aggregated_statistics_id);
print STDERR "C4::AggregatedStatistics::DBS::eval_form ref(\$dbs_values):",ref($dbs_values), ": statisticstypedesignation:",$input->param('statisticstypedesignation'),": name:",$input->param('name'),": startdate:",$input->param('startdate'),": enddate:",$input->param('enddate'),":\n" if $debug;
        if ( ref($dbs_values) eq 'HASH' ) {
            foreach my $name (keys %{$dbs_values}) {
                if ( $dbs_values->{$name}->{'type'} eq 'bool' ) {
print STDERR "C4::AggregatedStatistics::DBS::eval_form \$dbs_values->{", $name, "}->{'value'}:", $dbs_values->{$name}->{'value'}, ":\n" if $debug;
                    if ( $dbs_values->{$name}->{'value'} + 0 == 0 ) {
                        $st->{$name} = '0';
                    } else {
                        $st->{$name} = '1';
                    }
                } else {
                    $st->{$name} = $dbs_values->{$name}->{'value'};
                }
            }
        }
    }
    $template->param(
        st => $st,
    );

    output_html_with_http_headers $input, $cookie, $template->output;
}

sub dbs_calc {
    my ($script_name, $input, $aggregated_statistics_id) = @_;
    my $res;
print STDERR "C4::AggregatedStatistics::DBS::dbs_calc Start aggregated_statistics_id:", $aggregated_statistics_id, ": statisticstype:". scalar $input->param('statisticstype'), ": statisticstypedesignation:", scalar $input->param('statisticstypedesignation'), ": name:", scalar $input->param('name'), ": st_gen_population:", scalar $input->param('st_gen_population'), ": st_gen_libcount:", scalar $input->param('st_gen_libcount'), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::dbs_calc Start ref(\$input):", ref($input), ": input:", $input, ":\n" if $debug;

    # calculate DBS statistics values where possible
    foreach my $name (keys %{$as_values}) {
        if ( defined($as_values->{$name}->{'calc'}) ) {
            &{$as_values->{$name}->{'calc'}}($input, $aggregated_statistics_id, $name, $as_values->{$name}->{'param'});
        }
    }
}

sub dbs_save {
    my ($script_name, $input, $aggregated_statistics_id) = @_;
    my $res;
print STDERR "C4::AggregatedStatistics::DBS::dbs_save Start aggregated_statistics_id:", $aggregated_statistics_id, ": statisticstype:". scalar $input->param('statisticstype'), ": statisticstypedesignation:", scalar $input->param('statisticstypedesignation'), ": name:", scalar $input->param('name'), ": st_gen_population:", scalar $input->param('st_gen_population'), ": st_gen_libcount:", scalar $input->param('st_gen_libcount'), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::dbs_save Start ref(\$input):", ref($input), ": input:", $input, ":\n" if $debug;

    # store or delete it in database
    foreach my $name (keys %{$as_values}) {
print STDERR "C4::AggregatedStatistics::DBS::dbs_save loop aggregated_statistics_id:$aggregated_statistics_id: name:$name:\n" if $debug;
        saveAggregatedStatisticsValue($input, $aggregated_statistics_id, $name, $as_values->{$name}->{'type'});
    }

    # read it from database into hash $as_values
    dbs_read($aggregated_statistics_id);
}

sub saveAggregatedStatisticsValue {
    my ($input, $aggregated_statistics_id, $name, $type) = @_;
print STDERR "C4::AggregatedStatistics::DBS::saveAggregatedStatisticsValue Start ref(\$input):", ref($input), ": input:", $input, ":\n" if $debug;
    my $value = $input->param('st_' . $name);
print STDERR "C4::AggregatedStatistics::DBS::saveAggregatedStatisticsValue Start name:", $name, ": value:", $value, ": type:", $type, ":\n" if $debug;

    if ( defined( $aggregated_statistics_id ) ) {    # this should always be the case / only for safety's sake
        if ( !defined($value) && $type eq 'bool' ) {
            $value = '0';
        }
        if ( defined($value) ) {
            my %param;
            $param{'statistics_id'} = $aggregated_statistics_id;
            $param{'name'} = $name;
            if ( $type eq 'float' ) {
                $value =~ tr/,/./;      # decimal separator in DB is '.'
            }
            $param{'value'} = $value;
            $param{'type'} = $type;
            
            my $aggregatedStatisticsValues = C4::AggregatedStatistics::UpdAggregatedStatisticsValues(\%param);
        } else {
            if ( defined($name) ) {
                # delete the record
                my %param;
                $param{'statistics_id'} = $aggregated_statistics_id;
                $param{'name'} = $name;

                my $aggregatedStatisticsValues = C4::AggregatedStatistics::DelAggregatedStatisticsValues(\%param);
            }
        }
    }
}

sub dbs_read {
    my ($aggregated_statistics_id) = @_;
    my $hit = {};
print STDERR "C4::AggregatedStatistics::DBS::dbs_read Start aggregated_statistics_id:$aggregated_statistics_id:\n" if $debug;
    foreach my $name (keys %{$as_values}) {
        readAggregatedStatisticsValue($aggregated_statistics_id, $name,\$hit);
        $as_values->{$name}->{'id'} = $hit->{'statistics_id'};
        #already set: $as_values->{$name}->{'name'} = $hit->{'name'};
        $as_values->{$name}->{'value'} = $hit->{'value'};
        #already set: $as_values->{$name}->{'type'} = $hit->{'type'};
    }
    return $as_values;
}

sub readAggregatedStatisticsValue {
    my ($aggregated_statistics_id, $name, $hit) = @_;
print STDERR "C4::AggregatedStatistics::DBS::readAggregatedStatisticsValue Start aggregated_statistics_id:", $aggregated_statistics_id, ": name:", $name, ":\n" if $debug;
    my %param;

    if ( defined( $aggregated_statistics_id ) ) {    # this should always be the case / only for safety's sake
        if ( defined($name) ) {    # this should always be the case / only for safety's sake
            $param{'statistics_id'} = $aggregated_statistics_id;
            $param{'name'} = $name;
            
            my $aggregatedStatisticsValuesRS = C4::AggregatedStatistics::GetAggregatedStatisticsValues(\%param);
            if ( defined($aggregatedStatisticsValuesRS->_resultset()->first()) ) {
                $param{'value'} = $aggregatedStatisticsValuesRS->_resultset()->first()->get_column('value');
                $param{'type'} = $as_values->{$name}->{'type'};
            }
        }
    }
    $$hit = \%param;
}

sub dbs_del {
    my ($script_name, $input, $aggregated_statistics_id) = @_;
    my $res;
print STDERR "C4::AggregatedStatistics::DBS::dbs_del Start aggregated_statistics_id:", $aggregated_statistics_id, ": statisticstype:". scalar $input->param('statisticstype'), ": statisticstypedesignation:", scalar $input->param('statisticstypedesignation'), ": name:", scalar $input->param('name'), ": st_gen_population:", scalar $input->param('st_gen_population'), ": st_gen_libcount:", scalar $input->param('st_gen_libcount'), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::dbs_del Start ref(\$input):", ref($input), ": input:", $input, ":\n" if $debug;

    # delete all records from aggregated_statistics_values having this aggregated_statistics_id
    delAggregatedStatisticsValue($aggregated_statistics_id, undef);

    # read it from database into hash $as_values
    dbs_read($aggregated_statistics_id);
}

sub delAggregatedStatisticsValue {
    my ($aggregated_statistics_id, $name) = @_;
print STDERR "C4::AggregatedStatistics::DBS::delAggregatedStatisticsValue Start aggregated_statistics_id:", $aggregated_statistics_id, ": name:", $name, ":\n" if $debug;
    my %param;

    if ( defined( $aggregated_statistics_id ) ) {    # this should always be the case / only for safety's sake
        $param{'statistics_id'} = $aggregated_statistics_id;
        if ( defined($name) ) {
            $param{'name'} = $name;
        }
        my $aggregatedStatisticsValuesRS = C4::AggregatedStatistics::DelAggregatedStatisticsValues(\%param);
    }
}

sub readAggregatedStatisticsParametersValue {
    my ($aggregated_statistics_id, $name) = @_;
print STDERR "C4::AggregatedStatistics::DBS::readAggregatedStatisticsParametersValue Start aggregated_statistics_id:", $aggregated_statistics_id, ": name:", $name, ":\n" if $debug;
    my %param;
    my $value;

    if ( defined($aggregated_statistics_id) && length($aggregated_statistics_id) > 0 ) {
        if ( defined($name) ) {    # this should always be the case / only for safety's sake
            $param{'statistics_id'} = $aggregated_statistics_id;
            $param{'name'} = $name;

            my $aggregatedStatisticsParameters = C4::AggregatedStatistics::GetAggregatedStatisticsParameters(\%param);
print STDERR "C4::AggregatedStatistics::DBS::readAggregatedStatisticsParametersValue statistics_id:$aggregated_statistics_id: name:$name:   count aggregatedStatisticsParameters:", $aggregatedStatisticsParameters->_resultset()+0, ":\n" if $debug;
            if ($aggregatedStatisticsParameters && $aggregatedStatisticsParameters->_resultset() && $aggregatedStatisticsParameters->_resultset()->first()) {
                my $rsHit = $aggregatedStatisticsParameters->_resultset()->first();
                if ( length($rsHit->get_column('value')) > 0 ) {
                    $value = $rsHit->get_column('value');
                }
            }
        }
    }
    return $value;
}

sub func_call_report {
    my ($input, $aggregated_statistics_id, $name, $param) = @_;
#print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start ref(\$input):", ref($input), ": input:", $input, ":\n" if $debug;
#print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start Dumper(input):", Dumper($input), ":\n" if $debug;
    my $value = $input->param('st_' . $name);
print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start name:", $name, ": value:", $value, ":\n" if $debug;

#print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start Dumper(input->{'param'}):", Dumper($input->{'param'}), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start Dumper(input->{'param'}->{'st_' . $name}):", Dumper($input->{'param'}->{'st_' . $name}), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start Dumper(input->{'param'}->{'st_' . $name}->[0]):", Dumper($input->{'param'}->{'st_' . $name}->[0]), ":\n" if $debug;

print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start input->param('startdate'):", scalar $input->param('startdate'), ": input->param('enddate'):", scalar $input->param('enddate'), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::func_call_report Start \$param->[0]:", $param->[0], ":\n" if $debug;

    my $reportname = 'Schmarrn';
    if ( defined($param) && ref($param) eq 'ARRAY' && defined($param->[0]) ) {
        $reportname = $param->[0];
    }
    my $branchgroupSel = 0;    # default: no selection for branchgroup
    my $branchgroup = readAggregatedStatisticsParametersValue($aggregated_statistics_id, 'branchgroup');
    if ( !defined($branchgroup) || length($branchgroup) == 0 || $branchgroup eq '*' ) {
        $branchgroup = '';
    } else {
        $branchgroupSel = 1;
    }
    my $branchcodeSel = 0;    # default: no selection for branchcode
    my $branchcode = readAggregatedStatisticsParametersValue($aggregated_statistics_id, 'branchcode');
    if ( !defined($branchcode) || length($branchcode) == 0 || $branchcode eq '*' ) {
        $branchcode = '';
    } else {
        $branchcodeSel = 1;
        $branchgroupSel = 0;    # of course the finer selection 'branchcode' has to be used, if existing, in favour of 'branchgroup'
    }

    my $res = run_this_report(undef,$reportname,0,1,scalar $input->param('startdate'), scalar $input->param('enddate'), $branchgroupSel, $branchgroup, $branchcodeSel, $branchcode);    # select report by name

    $input->{'param'}->{'st_' . $name}->[0] = $res;

}

sub run_this_report {
    # execute a report saved in saved_sql
    my ($report_id, $report_name, $offset, $limit, @sql_params) = @_;
    my $res = 0;

print STDERR "C4::AggregatedStatistics::DBS::run_this_report Start \$report_id:", $report_id, ": \$report_name:", $report_name, ": \@sql_params:", @sql_params, ":\n" if $debug;
    my ( $sql, $original_sql, $type, $name, $notes );
    my $report;
    if ( defined($report_id) ) {
        $report = get_saved_report($report_id);
    } elsif ( defined($report_name) ) {
        $report = get_saved_report({ 'name' => $report_name });
    }
    if ($report) {
        $sql   = $original_sql = $report->{savedsql};
        $name  = $report->{report_name};
        $notes = $report->{notes};
print STDERR "C4::AggregatedStatistics::DBS::run_this_report Start \$sql:", $sql, ":\n" if $debug;

        my @rows = ();
        {
            # OK, we have parameters, or there are none, we run the report
            # if there were parameters, replace before running
            # split on ??. Each odd (2,4,6,...) entry should be a parameter to fill
            my @split = split /<<|>>/,$sql;
            my @tmpl_parameters;
            for(my $i=0;$i<$#split/2;$i++) {
                my $quoted = $sql_params[$i];
                # if there are special regexp chars, we must \ them
                $split[$i*2+1] =~ s/(\||\?|\.|\*|\(|\)|\%)/\\$1/g;
                if ($split[$i*2+1] =~ /\|\s*date\s*$/) {
                    $quoted = output_pref({ dt => dt_from_string($quoted), dateformat => 'iso', dateonly => 1 }) if $quoted;
                }
                $quoted = C4::Context->dbh->quote($quoted);
                $sql =~ s/<<$split[$i*2+1]>>/$quoted/;
            }
            $sql =~ s/[\r\n]/  /gm;
print STDERR "C4::AggregatedStatistics::DBS::run_this_report prepared sql:", $sql, ":\n" if $debug;
            my ($sth, $errors) = execute_query($sql, $offset, $limit);
            my $total = nb_rows($sql) || 0;
            unless ($sth) {
                die "execute_query failed to return sth for report $report_id: $sql";
            } else {
                my $row = $sth->fetchrow_arrayref();
                $res = $row->[0];
print STDERR "C4::AggregatedStatistics::DBS::run_this_report res:$res:\n" if $debug;
            }
        }
    }
    return $res;
}
    
1;
