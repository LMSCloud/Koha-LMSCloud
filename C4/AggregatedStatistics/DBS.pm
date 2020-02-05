package C4::AggregatedStatistics::DBS;

# Copyright 2018-2019 (C) LMSCloud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.


use strict;
use warnings;
use CGI qw ( -utf8 );
use Data::Dumper;

use C4::Auth;
use C4::Output;

use C4::AggregatedStatistics::AggregatedStatisticsBase;
use parent qw(C4::AggregatedStatistics::AggregatedStatisticsBase);



my $debug = 0;
my @categories;
my @branchloop;
my $dbh = C4::Context->dbh;

my $as_values = {};    # hash for storing all read records from table aggregated_statistics_values for one statistics_id, with aggregated_statistics_values.name as key
# general information / 1. ALLGEMEINE ANGABEN
$as_values->{'gen_dbs_id'} = { 'id' => '', 'name' => 'gen_dbs_id', 'value' => '', 'type' => 'text' };                                                                                                           # DBS2017:0 (for cvs downloads)
$as_values->{'gen_population'} = { 'id' => '', 'name' => 'gen_population', 'value' => '', 'type' => 'int' };                                                                                                    # DBS2017:1
$as_values->{'gen_libcount'} = { 'id' => '', 'name' => 'gen_libcount', 'value' => '', 'type' => 'int' };                                                                                                        # DBS2017:2
$as_values->{'gen_branchcount'} = { 'id' => '', 'name' => 'gen_branchcount', 'value' => '', 'type' => 'int' };                                                                                                  # DBS2017:3
$as_values->{'gen_buscount'} = { 'id' => '', 'name' => 'gen_buscount', 'value' => '', 'type' => 'int' };                                                                                                        # DBS2017:4
$as_values->{'gen_extservlocation'} = { 'id' => '', 'name' => 'gen_extservlocation', 'value' => '', 'type' => 'int' };                                                                                          # DBS2017:5
$as_values->{'gen_publicarea'} = { 'id' => '', 'name' => 'gen_publicarea', 'value' => '', 'type' => 'float' };                                                                                                  # DBS2017:6
$as_values->{'gen_publicarea_central'} = { 'id' => '', 'name' => 'gen_publicarea_central', 'value' => '', 'type' => 'float' };                                                                                  # DBS2018:6.1 (new since DBS 2018)
$as_values->{'gen_openinghours_year'} = { 'id' => '', 'name' => 'gen_openinghours_year', 'value' => '', 'type' => 'float' };                                                                                    # DBS2017:7
$as_values->{'gen_openinghours_year_open_library'} = { 'id' => '', 'name' => 'gen_openinghours_year_open_library', 'value' => '', 'type' => 'float' };                                                          # DBS2019:7.1 (new since DBS 2019)
$as_values->{'gen_openinghours_week'} = { 'id' => '', 'name' => 'gen_openinghours_week', 'value' => '', 'type' => 'float' };                                                                                    # DBS2017:8
$as_values->{'gen_openinghours_week_open_library'} = { 'id' => '', 'name' => 'gen_openinghours_week_open_library', 'value' => '', 'type' => 'float' };                                                          # DBS2019:8.1 (new since DBS 2019)
# patron information / 2. BENUTZER
$as_values->{'pat_active'} = { 'id' => '', 'name' => 'pat_active', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['pat_active'] };                                                      # DBS2017:9
$as_values->{'pat_active_to_12'} = { 'id' => '', 'name' => 'pat_active_to_12', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['pat_active_to_12'] };                                    # DBS2017:10.1
$as_values->{'pat_active_from_60'} = { 'id' => '', 'name' => 'pat_active_from_60', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['pat_active_from_60'] };                              # DBS2017:10.2
$as_values->{'pat_new_registrations'} = { 'id' => '', 'name' => 'pat_new_registrations', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['pat_new_registrations'] };                     # DBS2017:11
$as_values->{'pat_visits'} = { 'id' => '', 'name' => 'pat_visits', 'value' => '', 'type' => 'int' };                                                                                                            # DBS2017:12
$as_values->{'pat_visits_virt'} = { 'id' => '', 'name' => 'pat_visits_virt', 'value' => '', 'type' => 'int' };    # input deactivated                                                                           # DBS2017:12.1

# media offers and usage / 3. MEDIENANGEBOTE UND NUTZUNG
$as_values->{'med_tot_phys_stock'} = { 'id' => '', 'name' => 'med_tot_phys_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_tot_phys_stock'] };                              # DBS2017:13
$as_values->{'med_tot_issues'} = { 'id' => '', 'name' => 'med_tot_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_tot_issues'] };                                          # DBS2017:14
$as_values->{'med_phys_issues'} = { 'id' => '', 'name' => 'med_phys_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_phys_issues'] };                                       # DBS2017:14.1
$as_values->{'med_openaccess_stock'} = { 'id' => '', 'name' => 'med_openaccess_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_openaccess_stock'] };                        # DBS2017:15
$as_values->{'med_openaccess_issues'} = { 'id' => '', 'name' => 'med_openaccess_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_openaccess_issues'] };                     # DBS2017:16
$as_values->{'med_stack_stock'} = { 'id' => '', 'name' => 'med_stack_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_stack_stock'] };                                       # DBS2017:17
$as_values->{'med_print_stock'} = { 'id' => '', 'name' => 'med_print_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_print_stock'] };                                       # DBS2017:18
$as_values->{'med_print_issues'} = { 'id' => '', 'name' => 'med_print_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_print_issues'] };                                    # DBS2017:19
#$as_values->{'med_nonfiction_stock'} = { 'id' => '', 'name' => 'med_nonfiction_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonfiction_stock'] };                        # DBS2017:20 (dropped since DBS 2019)
#$as_values->{'med_nonfiction_issues'} = { 'id' => '', 'name' => 'med_nonfiction_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonfiction_issues'] };                     # DBS2017:21 (dropped since DBS 2019)
#$as_values->{'med_fiction_stock'} = { 'id' => '', 'name' => 'med_fiction_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_fiction_stock'] };                                 # DBS2017:22 (dropped since DBS 2019)
#$as_values->{'med_fiction_issues'} = { 'id' => '', 'name' => 'med_fiction_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_fiction_issues'] };                              # DBS2017:23 (dropped since DBS 2019)
$as_values->{'med_juvenile_stock'} = { 'id' => '', 'name' => 'med_juvenile_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_juvenile_stock'] };                              # DBS2017:24
$as_values->{'med_juvenile_issues'} = { 'id' => '', 'name' => 'med_juvenile_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_juvenile_issues'] };                           # DBS2017:25
#$as_values->{'med_printissue_stock'} = { 'id' => '', 'name' => 'med_printissue_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_printissue_stock'] };                        # DBS2017:26 (dropped since DBS 2019)
#$as_values->{'med_printissue_issues'} = { 'id' => '', 'name' => 'med_printissue_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_printissue_issues'] };                     # DBS2017:27 (dropped since DBS 2019)
$as_values->{'med_nonbook_tot_stock'} = { 'id' => '', 'name' => 'med_nonbook_tot_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonbook_tot_stock'] };                     # DBS2017:28
$as_values->{'med_nonbook_tot_issues'} = { 'id' => '', 'name' => 'med_nonbook_tot_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonbook_tot_issues'] };                  # DBS2017:29
#$as_values->{'med_nonbook_anadig_stock'} = { 'id' => '', 'name' => 'med_nonbook_anadig_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonbook_anadig_stock'] };            # DBS2017:30 (dropped since DBS 2019)
#$as_values->{'med_nonbook_anadig_issues'} = { 'id' => '', 'name' => 'med_nonbook_anadig_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonbook_anadig_issues'] };         # DBS2017:31 (dropped since DBS 2019)
#$as_values->{'med_nonbook_other_stock'} = { 'id' => '', 'name' => 'med_nonbook_other_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonbook_other_stock'] };               # DBS2017:32 (dropped since DBS 2019)
#$as_values->{'med_nonbook_other_issues'} = { 'id' => '', 'name' => 'med_nonbook_other_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_nonbook_other_issues'] };            # DBS2017:33 (dropped since DBS 2019)
$as_values->{'med_virtsupply_stock'} = { 'id' => '', 'name' => 'med_virtsupply_stock', 'value' => '', 'type' => 'int' };                                                                                        # DBS2017:34
$as_values->{'med_virtconsort_stock'} = { 'id' => '', 'name' => 'med_virtconsort_stock', 'value' => '', 'type' => 'int' };                                                                                      # DBS2017:34.1
$as_values->{'med_consort_libcount'} = { 'id' => '', 'name' => 'med_consort_libcount', 'value' => '', 'type' => 'int' };                                                                                        # DBS2017:34.2
$as_values->{'med_virtsupply_issues'} = { 'id' => '', 'name' => 'med_virtsupply_issues', 'value' => '', 'type' => 'int' };                                                                                      # DBS2017:35
$as_values->{'med_access_units'} = { 'id' => '', 'name' => 'med_access_units', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_access_units'] };                                    # DBS2017:36
#$as_values->{'med_withdrawal_units'} = { 'id' => '', 'name' => 'med_withdrawal_units', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_withdrawal_units'] };                        # DBS2017:37 (dropped since DBS 2019)
$as_values->{'med_database_cnt'} = { 'id' => '', 'name' => 'med_database_cnt', 'value' => '', 'type' => 'int' };                                                                                                # DBS2017:38
$as_values->{'med_database_login_cnt'} = { 'id' => '', 'name' => 'med_database_login_cnt', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_database_login_cnt'] };                  # DBS2019:38.1 (new since DBS 2019)
$as_values->{'med_database_authsso_yn'} = { 'id' => '', 'name' => 'med_database_authsso_yn', 'value' => '', 'type' => 'bool' };                                                                                 # DBS2019:38.2 (new since DBS 2019, always true with Divibib)
$as_values->{'med_subscription_print'} = { 'id' => '', 'name' => 'med_subscription_print', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['med_subscription_print'] };                  # DBS2017:39
$as_values->{'med_subscription_elect'} = { 'id' => '', 'name' => 'med_subscription_elect', 'value' => '', 'type' => 'int' };                                                                                    # DBS2017:40
#$as_values->{'med_blockcollection_rcvd'} = { 'id' => '', 'name' => 'med_blockcollection_rcvd', 'value' => '', 'type' => 'int' };                                                                                # DBS2017:41  (dropped since DBS 2019)
$as_values->{'med_blockcollection_used_yn'} = { 'id' => '', 'name' => 'med_blockcollection_used_yn', 'value' => '', 'type' => 'bool' };                                                                         # DBS2019:41.1 (new since DBS 2019) 
#$as_values->{'med_blockcollection_lent'} = { 'id' => '', 'name' => 'med_blockcollection_lent', 'value' => '', 'type' => 'int' };                                                                                # DBS2017:42 (dropped since DBS 2019)
$as_values->{'med_ILL_borrowing_orders'} = { 'id' => '', 'name' => 'med_ILL_borrowing_orders', 'value' => '', 'type' => 'int' };                                                                                # DBS2017:43
$as_values->{'med_ILL_lending_orders'} = { 'id' => '', 'name' => 'med_ILL_lending_orders', 'value' => '', 'type' => 'int' };                                                                                    # DBS2017:44
#$as_values->{'med_document_delivery'} = { 'id' => '', 'name' => 'med_document_delivery', 'value' => '', 'type' => 'int' };                                                                                      # DBS2017:45 (dropped since DBS 2019)

# finance / 4. FINANZEN
$as_values->{'fin_current_expenses_tot'} = { 'id' => '', 'name' => 'fin_current_expenses_tot', 'value' => '', 'type' => 'float' };                                                                              # DBS2017:49
$as_values->{'fin_cur_exp_acquisitions'} = { 'id' => '', 'name' => 'fin_cur_exp_acquisitions', 'value' => '', 'type' => 'float' };                                                                              # DBS2017:50
$as_values->{'fin_cur_exp_acq_licences'} = { 'id' => '', 'name' => 'fin_cur_exp_acq_licences', 'value' => '', 'type' => 'float' };                                                                              # DBS2017:50.1
$as_values->{'fin_cur_exp_staff'} = { 'id' => '', 'name' => 'fin_cur_exp_staff', 'value' => '', 'type' => 'float' };                                                                                            # DBS2017:51
$as_values->{'fin_cur_exp_other'} = { 'id' => '', 'name' => 'fin_cur_exp_other', 'value' => '', 'type' => 'float' };                                                                                            # DBS2017:52
$as_values->{'fin_singulary_investments'} = { 'id' => '', 'name' => 'fin_singulary_investments', 'value' => '', 'type' => 'float' };                                                                            # DBS2017:53
$as_values->{'fin_expenses_tot'} = { 'id' => '', 'name' => 'fin_expenses_tot', 'value' => '', 'type' => 'float' };                                                                                              # DBS2017:54
#$as_values->{'fin_costunit_funds_tot'} = { 'id' => '', 'name' => 'fin_costunit_funds_tot', 'value' => '', 'type' => 'float' };                                                                                  # DBS2017:54.1 (not used since DBS 2018)
$as_values->{'fin_costunit_expenses'} = { 'id' => '', 'name' => 'fin_costunit_expenses', 'value' => '', 'type' => 'float' };                                                                                    # DBS2017:55
$as_values->{'fin_external_funds_tot'} = { 'id' => '', 'name' => 'fin_external_funds_tot', 'value' => '', 'type' => 'float' };                                                                                  # DBS2017:56
$as_values->{'fin_ext_funds_EU'} = { 'id' => '', 'name' => 'fin_ext_funds_EU', 'value' => '', 'type' => 'float' };                                                                                              # DBS2017:57
$as_values->{'fin_ext_funds_national'} = { 'id' => '', 'name' => 'fin_ext_funds_national', 'value' => '', 'type' => 'float' };                                                                                  # DBS2017:58
$as_values->{'fin_ext_funds_fedstate'} = { 'id' => '', 'name' => 'fin_ext_funds_fedstate', 'value' => '', 'type' => 'float' };                                                                                  # DBS2017:59
$as_values->{'fin_ext_funds_communal'} = { 'id' => '', 'name' => 'fin_ext_funds_communal', 'value' => '', 'type' => 'float' };                                                                                  # DBS2017:60
$as_values->{'fin_ext_funds_church'} = { 'id' => '', 'name' => 'fin_ext_funds_church', 'value' => '', 'type' => 'float' };                                                                                      # DBS2017:61
$as_values->{'fin_ext_funds_other'} = { 'id' => '', 'name' => 'fin_ext_funds_other', 'value' => '', 'type' => 'float' };                                                                                        # DBS2017:62
$as_values->{'fin_lib_revenue'} = { 'id' => '', 'name' => 'fin_lib_revenue', 'value' => '', 'type' => 'float' };                                                                                                # DBS2017:63
$as_values->{'fin_user_charge_yn'} = { 'id' => '', 'name' => 'fin_user_charge_yn', 'value' => '', 'type' => 'bool' };                                                                                           # DBS2017:65

# staff capacity / 5. PERSONALKAPAZITÄT
$as_values->{'stf_staff_scheme_appointments'} = { 'id' => '', 'name' => 'stf_staff_scheme_appointments', 'value' => '', 'type' => 'int' };                                                                      # DBS2017:66
$as_values->{'stf_staff_cnt'} = { 'id' => '', 'name' => 'stf_staff_cnt', 'value' => '', 'type' => 'int' };                                                                                                      # DBS2017:67
$as_values->{'stf_capacity_FTE'} = { 'id' => '', 'name' => 'stf_capacity_FTE', 'value' => '', 'type' => 'float' };                                                                                              # DBS2017:68
$as_values->{'stf_cap_FTE_librarians'} = { 'id' => '', 'name' => 'stf_cap_FTE_librarians', 'value' => '', 'type' => 'float' };                                                                                  # DBS2017:69
$as_values->{'stf_cap_FTE_assistants'} = { 'id' => '', 'name' => 'stf_cap_FTE_assistants', 'value' => '', 'type' => 'float' };                                                                                  # DBS2017:70
$as_values->{'stf_cap_FTE_promotional'} = { 'id' => '', 'name' => 'stf_cap_FTE_promotional', 'value' => '', 'type' => 'float' };                                                                                # DBS2017:72
$as_values->{'stf_cap_FTE_others'} = { 'id' => '', 'name' => 'stf_cap_FTE_others', 'value' => '', 'type' => 'float' };                                                                                          # DBS2017:74
$as_values->{'stf_honorary_cnt'} = { 'id' => '', 'name' => 'stf_honorary_cnt', 'value' => '', 'type' => 'int' };                                                                                                # DBS2017:75
$as_values->{'stf_cap_FTE_honorary'} = { 'id' => '', 'name' => 'stf_cap_FTE_honorary', 'value' => '', 'type' => 'float' };                                                                                      # DBS2017:76
$as_values->{'stf_apprentices_cnt'} = { 'id' => '', 'name' => 'stf_apprentices_cnt', 'value' => '', 'type' => 'int' };                                                                                          # DBS2017:77
$as_values->{'stf_advanced_training_hrs'} = { 'id' => '', 'name' => 'stf_advanced_training_hrs', 'value' => '', 'type' => 'float' };                                                                            # DBS2017:78

# services / 6. SERVICES / DIENSTLEISTUNGEN
#$as_values->{'srv_patron_recherches'} = { 'id' => '', 'name' => 'srv_patron_recherches', 'value' => '', 'type' => 'int' };                                                                                      # DBS2017:79 (dropped since DBS 2019)
$as_values->{'srv_patron_workplaces'} = { 'id' => '', 'name' => 'srv_patron_workplaces', 'value' => '', 'type' => 'int' };                                                                                      # DBS2017:80
$as_values->{'srv_pat_workplc_inclopac'} = { 'id' => '', 'name' => 'srv_pat_workplc_inclopac', 'value' => '', 'type' => 'int' };                                                                                # DBS2017:81
$as_values->{'srv_pat_workplc_web'} = { 'id' => '', 'name' => 'srv_pat_workplc_web', 'value' => '', 'type' => 'int' };                                                                                          # DBS2017:82
$as_values->{'srv_libhomepage_yn'} = { 'id' => '', 'name' => 'srv_libhomepage_yn', 'value' => '', 'type' => 'bool' };                                                                                           # DBS2017:83
$as_values->{'srv_webopac_yn'} = { 'id' => '', 'name' => 'srv_webopac_yn', 'value' => '', 'type' => 'bool' };                                                                                                   # DBS2017:85
$as_values->{'srv_interactive_yn'} = { 'id' => '', 'name' => 'srv_interactive_yn', 'value' => '', 'type' => 'bool' };                                                                                           # DBS2017:86
$as_values->{'srv_socialweb_yn'} = { 'id' => '', 'name' => 'srv_socialweb_yn', 'value' => '', 'type' => 'bool' };                                                                                               # DBS2017:87
$as_values->{'srv_emailquery_yn'} = { 'id' => '', 'name' => 'srv_emailquery_yn', 'value' => '', 'type' => 'bool' };                                                                                             # DBS2017:88
$as_values->{'srv_virtualstock_yn'} = { 'id' => '', 'name' => 'srv_virtualstock_yn', 'value' => '', 'type' => 'bool' };                                                                                         # DBS2017:89
$as_values->{'srv_activeinfo_yn'} = { 'id' => '', 'name' => 'srv_activeinfo_yn', 'value' => '', 'type' => 'bool' };                                                                                             # DBS2017:90
$as_values->{'srv_publicwlan_yn'} = { 'id' => '', 'name' => 'srv_publicwlan_yn', 'value' => '', 'type' => 'bool' };                                                                                             # DBS2017:91
$as_values->{'srv_socialwork_yn'} = { 'id' => '', 'name' => 'srv_socialwork_yn', 'value' => '', 'type' => 'bool' };                                                                                             # DBS2017:92
$as_values->{'srv_events_tot'} = { 'id' => '', 'name' => 'srv_events_tot', 'value' => '', 'type' => 'int' };                                                                                                    # DBS2017:94
$as_values->{'srv_events_tot_visits'} = { 'id' => '', 'name' => 'srv_events_tot_visits', 'value' => '', 'type' => 'int' };                                                                                      # DBS2018:94.1 DBS2019:99.1 (new since DBS 2018) (99.1 since DBS 2019)
$as_values->{'srv_evt_libintro'} = { 'id' => '', 'name' => 'srv_evt_libintro', 'value' => '', 'type' => 'int' };                                                                                                # DBS2017:95
$as_values->{'srv_evt_juvenile'} = { 'id' => '', 'name' => 'srv_evt_juvenile', 'value' => '', 'type' => 'int' };                                                                                                # DBS2017:96
$as_values->{'srv_evt_adult'} = { 'id' => '', 'name' => 'srv_evt_adult', 'value' => '', 'type' => 'int' };                                                                                                      # DBS2017:97
$as_values->{'srv_evt_exhibition'} = { 'id' => '', 'name' => 'srv_evt_exhibition', 'value' => '', 'type' => 'int' };                                                                                            # DBS2017:98
$as_values->{'srv_evt_other'} = { 'id' => '', 'name' => 'srv_evt_other', 'value' => '', 'type' => 'int' };                                                                                                      # DBS2017:99
$as_values->{'srv_school_libs'} = { 'id' => '', 'name' => 'srv_school_libs', 'value' => '', 'type' => 'int' };                                                                                                  # DBS2017:100
$as_values->{'srv_admin_libs'} = { 'id' => '', 'name' => 'srv_admin_libs', 'value' => '', 'type' => 'int' };                                                                                                    # DBS2017:101
$as_values->{'srv_contracts'} = { 'id' => '', 'name' => 'srv_contracts', 'value' => '', 'type' => 'int' };                                                                                                      # DBS2017:102
$as_values->{'srv_rfidcheckio_yn'} = { 'id' => '', 'name' => 'srv_rfidcheckio_yn', 'value' => '', 'type' => 'bool' };                                                                                           # DBS2017:103
$as_values->{'srv_mobiledevices_yn'} = { 'id' => '', 'name' => 'srv_mobiledevices_yn', 'value' => '', 'type' => 'bool' };                                                                                       # DBS2017:104
$as_values->{'srv_remarks'} = { 'id' => '', 'name' => 'srv_remarks', 'value' => '', 'type' => 'text' };                                                                                                         # DBS2017:199

# patients' libraries / PATIENTENBIBLIOTHEKEN
$as_values->{'ptl_clinical_network_yn'} = { 'id' => '', 'name' => 'ptl_clinical_network_yn', 'value' => '', 'type' => 'bool' };                                                                                 # DBS2017:200
$as_values->{'ptl_clinet_clinics'} = { 'id' => '', 'name' => 'ptl_clinet_clinics', 'value' => '', 'type' => 'int' };                                                                                            # DBS2017:201
$as_values->{'ptl_clinet_patientslibs'} = { 'id' => '', 'name' => 'ptl_clinet_patientslibs', 'value' => '', 'type' => 'int' };                                                                                  # DBS2017:202
$as_values->{'ptl_clinic_beds'} = { 'id' => '', 'name' => 'ptl_clinic_beds', 'value' => '', 'type' => 'int' };                                                                                                  # DBS2017:203
$as_values->{'ptl_outpatients'} = { 'id' => '', 'name' => 'ptl_outpatients', 'value' => '', 'type' => 'int' };                                                                                                  # DBS2017:204
$as_values->{'ptl_trolley_service_yn'} = { 'id' => '', 'name' => 'ptl_trolley_service_yn', 'value' => '', 'type' => 'bool' };                                                                                   # DBS2017:205
$as_values->{'ptl_trolley_service_hrs'} = { 'id' => '', 'name' => 'ptl_trolley_service_hrs', 'value' => '', 'type' => 'float' };                                                                                # DBS2017:206
$as_values->{'ptl_laptop_service_yn'} = { 'id' => '', 'name' => 'ptl_laptop_service_yn', 'value' => '', 'type' => 'bool' };                                                                                     # DBS2017:207
$as_values->{'ptl_mediaplayer_service_yn'} = { 'id' => '', 'name' => 'ptl_mediaplayer_service_yn', 'value' => '', 'type' => 'bool' };                                                                           # DBS2017:208
$as_values->{'ptl_medical_lib_yn'} = { 'id' => '', 'name' => 'ptl_medical_lib_yn', 'value' => '', 'type' => 'bool' };                                                                                           # DBS2017:209
$as_values->{'ptl_combined_lib_yn'} = { 'id' => '', 'name' => 'ptl_combined_lib_yn', 'value' => '', 'type' => 'bool' };                                                                                         # DBS2017:210

# mobile libraries / FAHRBIBLIOTHEKEN
$as_values->{'mol_vehicles'} = { 'id' => '', 'name' => 'mol_vehicles', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mol_vehicles'] };                                                # DBS2017:300
$as_values->{'mol_multiple_communes_yn'} = { 'id' => '', 'name' => 'mol_multiple_communes_yn', 'value' => '', 'type' => 'bool' };                                                                               # DBS2017:301
$as_values->{'mol_stop_stations'} = { 'id' => '', 'name' => 'mol_stop_stations', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mol_stop_stations'] };                                 # DBS2017:302
$as_values->{'mol_cycle_days'} = { 'id' => '', 'name' => 'mol_cycle_days', 'value' => '', 'type' => 'int' };                                                                                                    # DBS2017:303
$as_values->{'mol_openinghours_week'} = { 'id' => '', 'name' => 'mol_openinghours_week', 'value' => '', 'type' => 'float' };                                                                                    # DBS2017:304
$as_values->{'mol_stock_media_units'} = { 'id' => '', 'name' => 'mol_stock_media_units', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mol_stock_media_units'] };                     # DBS2017:305
$as_values->{'mol_media_unit_issues'} = { 'id' => '', 'name' => 'mol_media_unit_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mol_media_unit_issues'] };                     # DBS2017:307

# music libraries / MUSIKBIBLIOTHEKEN
$as_values->{'mus_sheetmusic_stock'} = { 'id' => '', 'name' => 'mus_sheetmusic_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_sheetmusic_stock'] };                        # DBS2017:400
$as_values->{'mus_sheetmusic_issues'} = { 'id' => '', 'name' => 'mus_sheetmusic_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_sheetmusic_issues'] };                     # DBS2017:401
$as_values->{'mus_secondarylit_stock'} = { 'id' => '', 'name' => 'mus_secondarylit_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_secondarylit_stock'] };                  # DBS2017:402
$as_values->{'mus_secondarylit_issues'} = { 'id' => '', 'name' => 'mus_secondarylit_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_secondarylit_issues'] };               # DBS2017:403
$as_values->{'mus_cd_stock'} = { 'id' => '', 'name' => 'mus_cd_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_cd_stock'] };                                                # DBS2017:404
$as_values->{'mus_cd_issues'} = { 'id' => '', 'name' => 'mus_cd_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_cd_issues'] };                                             # DBS2017:405
$as_values->{'mus_cassette_stock'} = { 'id' => '', 'name' => 'mus_cassette_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_cassette_stock'] };                              # DBS2017:406
$as_values->{'mus_cassette_issues'} = { 'id' => '', 'name' => 'mus_cassette_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_cassette_issues'] };                           # DBS2017:407
$as_values->{'mus_record_stock'} = { 'id' => '', 'name' => 'mus_record_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_record_stock'] };                                    # DBS2017:408
$as_values->{'mus_record_issues'} = { 'id' => '', 'name' => 'mus_record_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_record_issues'] };                                 # DBS2017:409
$as_values->{'mus_VHS_stock'} = { 'id' => '', 'name' => 'mus_VHS_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_VHS_stock'] };                                             # DBS2017:410
$as_values->{'mus_VHS_issues'} = { 'id' => '', 'name' => 'mus_VHS_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_VHS_issues'] };                                          # DBS2017:411
$as_values->{'mus_DVD_stock'} = { 'id' => '', 'name' => 'mus_DVD_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_DVD_stock'] };                                             # DBS2017:412
$as_values->{'mus_DVD_issues'} = { 'id' => '', 'name' => 'mus_DVD_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_DVD_issues'] };                                          # DBS2017:413
$as_values->{'mus_periodicals_stock'} = { 'id' => '', 'name' => 'mus_periodicals_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_periodicals_stock'] };                     # DBS2017:414
$as_values->{'mus_periodicals_issues'} = { 'id' => '', 'name' => 'mus_periodicals_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_periodicals_issues'] };                  # DBS2017:415
$as_values->{'mus_other_stock'} = { 'id' => '', 'name' => 'mus_other_stock', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_other_stock'] };                                       # DBS2017:416
$as_values->{'mus_other_issues'} = { 'id' => '', 'name' => 'mus_other_issues', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_other_issues'] };                                    # DBS2017:417
$as_values->{'mus_stock_tot'} = { 'id' => '', 'name' => 'mus_stock_tot', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_stock_tot'] };                                             # DBS2017:418
$as_values->{'mus_issues_tot'} = { 'id' => '', 'name' => 'mus_issues_tot', 'value' => '', 'type' => 'int', 'calc' => \&func_call_sql, 'param' => ['mus_issues_tot'] };                                          # DBS2017:419
$as_values->{'mus_audioplaybacks'} = { 'id' => '', 'name' => 'mus_audioplaybacks', 'value' => '', 'type' => 'int' };                                                                                            # DBS2017:420
$as_values->{'mus_acq_expenses'} = { 'id' => '', 'name' => 'mus_acq_expenses', 'value' => '', 'type' => 'float' };                                                                                              # DBS2017:421


my $dbs_sql_statements = {};    # hash for storing the sql statements for calculating DBS values based on standard Koha DB tables
# DBS2017:9
$dbs_sql_statements->{'pat_active'} = q{
    select count(*) as res from borrowers
    where dateexpiry >=  (@startdatum := ?)
      and dateenrolled <=  (@enddatum := ?)
      and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
          )
};
# DBS2017:10.1
$dbs_sql_statements->{'pat_active_to_12'} = q{
    select count(*) as res from borrowers
    where dateexpiry >=  (@startdatum := ?)
      and dateenrolled <=  (@enddatum := ?)
      and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
          )
      and DATE_ADD(dateofbirth, INTERVAL 12 YEAR) > @startdatum
};
# DBS2017:10.2
$dbs_sql_statements->{'pat_active_from_60'} = q{
    select count(*) as res from borrowers
    where dateexpiry >=  (@startdatum := ?)
      and dateenrolled <=  (@enddatum := ?)
      and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 :=?) COLLATE utf8mb4_unicode_ci = '1' and branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
          )
      and DATE_ADD(dateofbirth, INTERVAL 60 YEAR) <= @enddatum
};
# DBS2017:11
$dbs_sql_statements->{'pat_new_registrations'} = q{
    select count(*) as res from borrowers
    where dateenrolled >= (@startdatum := ?) and dateenrolled <= (@enddatum := ?)
      and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
          )
};
# DBS2017:13
$dbs_sql_statements->{'med_tot_phys_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:14
$dbs_sql_statements->{'med_tot_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:14.1
$dbs_sql_statements->{'med_phys_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:15
$dbs_sql_statements->{'med_openaccess_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:16
$dbs_sql_statements->{'med_openaccess_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:17
$dbs_sql_statements->{'med_stack_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:18
$dbs_sql_statements->{'med_print_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_B_M', 'F_M_P' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_B_M', 'F_M_P' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:19
$dbs_sql_statements->{'med_print_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_B_M', 'F_M_P' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_B_M', 'F_M_P' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:20
$dbs_sql_statements->{'med_nonfiction_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier IN ( 'F_B_N', 'F_B_M' )
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier IN ( 'F_B_N', 'F_B_M' )
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:21
$dbs_sql_statements->{'med_nonfiction_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_M' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_M' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:22
$dbs_sql_statements->{'med_fiction_stock'} = q{
select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier = 'F_B_F' 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier = 'F_B_F' 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:23
$dbs_sql_statements->{'med_fiction_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_F' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_F' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:24
$dbs_sql_statements->{'med_juvenile_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier = 'F_B_J' 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier = 'F_B_J' 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:25
$dbs_sql_statements->{'med_juvenile_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_J' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_J' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:26
$dbs_sql_statements->{'med_printissue_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier IN ( 'F_B_P', 'F_M_P' )
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier IN ( 'F_B_P', 'F_M_P' )
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:27
$dbs_sql_statements->{'med_printissue_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_P', 'F_M_P' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_P', 'F_M_P' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:28
$dbs_sql_statements->{'med_nonbook_tot_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier IN ( 'F_N_A', 'F_N_O', 'F_B_W', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O', 'F_M_B' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier IN ( 'F_N_A', 'F_N_O', 'F_B_W', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O', 'F_M_B' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:29
$dbs_sql_statements->{'med_nonbook_tot_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_N_A', 'F_N_O', 'F_B_W', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O', 'F_M_B' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_N_A', 'F_N_O', 'F_B_W', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O', 'F_M_B' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:30
$dbs_sql_statements->{'med_nonbook_anadig_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier IN ( 'F_N_A', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O' )
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier IN ( 'F_N_A', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O' )
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:31
$dbs_sql_statements->{'med_nonbook_anadig_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_N_A', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_N_A', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_O' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:32
$dbs_sql_statements->{'med_nonbook_other_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier IN ( 'F_N_O', 'F_B_W', 'F_M_B' )
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier IN ( 'F_N_O', 'F_B_W', 'F_M_B' )
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:33
$dbs_sql_statements->{'med_nonbook_other_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_N_O', 'F_B_W', 'F_M_B' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_N_O', 'F_B_W', 'F_M_B' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:36
$dbs_sql_statements->{'med_access_units'} = q{
    select sum(cnt) as res from
    (   select count(*) as cnt from items
        where ( dateaccessioned >= (@startdatum := ?) ) 
          and ( dateaccessioned <= (@enddatum := ?) )
          and ( coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( dateaccessioned >= @startdatum )
          and ( dateaccessioned <= @enddatum )
          and ( coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:37
$dbs_sql_statements->{'med_withdrawal_units'} = q{
    select sum(cnt) as res from
    (   select count(*) as cnt from items
        where ( withdrawn != 0 ) 
          and ( date(withdrawn_on) >= (@startdatum := ?) ) 
          and ( date(withdrawn_on) <= (@enddatum := ?) )
          and ( coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems
        where ( date(timestamp) >= (@startdatum) ) 
          and ( date(timestamp) <= (@enddatum) )
          and ( coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
          and ( ((@branchgroupSelect0or1) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2019:38.1
$dbs_sql_statements->{'med_database_login_cnt'} = q{
    select sum(cnt) as res from
    (   select count(*) as cnt from statistics s 
        where ( date(s.datetime) >= (@startdatum := ?) ) 
          and ( date(s.datetime) <= (@enddatum := ?) )
          and s.type = 'auth-ext'
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:39
$dbs_sql_statements->{'med_subscription_print'} = q{
    select sum(cnt) as res from
    (   select count(*) as cnt from subscription s, subscriptionhistory h
        where ( s.subscriptionid = h.subscriptionid ) 
          and ( s.enddate >= (@startdatum := ?) ) 
          and ( h.histstartdate <= (@enddatum := ?) )
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:300
$dbs_sql_statements->{'mol_vehicles'} = q{
    select sum(cnt) as res from 
    (   select count(distinct mobilebranch) as cnt, 
            (@startdatum := ?) as startdatum, 
            (@enddatum := ?) as enddatum
        from branches 
        where mobilebranch > '' 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:302
$dbs_sql_statements->{'mol_stop_stations'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt, 
            (@startdatum := ?) as startdatum, 
            (@enddatum := ?) as enddatum 
        from branches 
        where mobilebranch > '' 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
    ) x
};
# DBS2017:305
$dbs_sql_statements->{'mol_stock_media_units'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
          and ( exists ( select branchcode from branches where branches.branchcode = items.homebranch and ( branches.mobilebranch > '' or branches.branchcode in (select distinct mobilebranch from branches b where b.mobilebranch > '' ) ) ) ) 
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
          and ( exists ( select branchcode from branches where branches.branchcode = deleteditems.homebranch and ( branches.mobilebranch > '' or branches.branchcode in (select distinct mobilebranch from branches b where b.mobilebranch > '' ) ) ) ) 
    ) x
};
# DBS2017:307
$dbs_sql_statements->{'mol_media_unit_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_N', 'F_B_F', 'F_B_J', 'F_B_P', 'F_N_A', 'F_N_O', 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_N', 'M_B_F', 'M_B_J', 'M_B_P', 'M_N_A', 'M_N_O', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode, s.mobilebranch
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where ( sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode) ) 
      and ( br.mobilebranch > '' or br.branchcode in (select distinct b.mobilebranch from branches b where b.mobilebranch > '' ) )
};
# DBS2017:400
$dbs_sql_statements->{'mus_sheetmusic_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_B_W', 'M_B_W' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_B_W', 'M_B_W' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:401
$dbs_sql_statements->{'mus_sheetmusic_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_W', 'M_B_W' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_W', 'M_B_W' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:402
$dbs_sql_statements->{'mus_secondarylit_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_B_M', 'M_B_M' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_B_M', 'M_B_M' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:403
$dbs_sql_statements->{'mus_secondarylit_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_M', 'M_B_M' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_M', 'M_B_M' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:404
$dbs_sql_statements->{'mus_cd_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_M_C', 'M_M_C' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_M_C', 'M_M_C' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:405
$dbs_sql_statements->{'mus_cd_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_C', 'M_M_C' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_C', 'M_M_C' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:406
$dbs_sql_statements->{'mus_cassette_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_M_K', 'M_M_K' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_M_K', 'M_M_K' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:407
$dbs_sql_statements->{'mus_cassette_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_K', 'M_M_K' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_K', 'M_M_K' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:408
$dbs_sql_statements->{'mus_record_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_M_R', 'M_M_R' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_M_R', 'M_M_R' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:409
$dbs_sql_statements->{'mus_record_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_R', 'M_M_R' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_R', 'M_M_R' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:410
$dbs_sql_statements->{'mus_VHS_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_M_V', 'M_M_V' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_M_V', 'M_M_V' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:411
$dbs_sql_statements->{'mus_VHS_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_V', 'M_M_V' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_V', 'M_M_V' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:412
$dbs_sql_statements->{'mus_DVD_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_M_D', 'M_M_D' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_M_D', 'M_M_D' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:413
$dbs_sql_statements->{'mus_DVD_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_D', 'M_M_D' ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_D', 'M_M_D' ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:414
$dbs_sql_statements->{'mus_periodicals_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_M_P', 'M_M_P' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_M_P', 'M_M_P' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:415
$dbs_sql_statements->{'mus_periodicals_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_P', 'M_M_P'  ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_P', 'M_M_P'  ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:416
$dbs_sql_statements->{'mus_other_stock'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_M_O', 'F_M_B', 'M_M_O', 'M_M_B' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_M_O', 'F_M_B', 'M_M_O', 'M_M_B' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:417
$dbs_sql_statements->{'mus_other_issues'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_O', 'F_M_B', 'M_M_O', 'M_M_B'  ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_M_O', 'F_M_B', 'M_M_O', 'M_M_B'  ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};
# DBS2017:418
$dbs_sql_statements->{'mus_stock_tot'} = q{
    select sum(cnt) as res from 
    (   select count(*) as cnt from items 
        where ( itemlost = 0 or date(itemlost_on) >= (@startdatum := ?) ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= (@enddatum := ?) 
          and coded_location_qualifier in ( 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and ( ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
                or
                ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and homebranch = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        union all
        select count(*) as cnt from deleteditems 
        where ( itemlost = 0 or date(itemlost_on) >= @startdatum ) 
          and ( withdrawn = 0 or date(withdrawn_on) >= @startdatum ) 
          and dateaccessioned <= @enddatum 
          and coded_location_qualifier in ( 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B' ) 
          and date(timestamp) >= @startdatum
          and ( (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch IN (select branchcode from library_groups where parent_id = @branchgroupSel COLLATE utf8mb4_unicode_ci))
                or
                (@branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci = '1' and homebranch = @branchcodeSel COLLATE utf8mb4_unicode_ci)
                or
                (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
              )
        ) x
};
# DBS2017:419
$dbs_sql_statements->{'mus_issues_tot'} = q{
    select IFNULL(sum(sums.cnt),0) as res
    from
    (   select s.branch, i.homebranch, count(*) as cnt 
        from   statistics s
               join items i on ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B'  ) )
        where  ( date(s.datetime) >= (@startdatum := ? ) ) 
           and ( date(s.datetime) <= (@enddatum := ? ) )
           and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
        union all
        select s.branch, i.homebranch, count(*) as cnt 
        from  statistics s
              join deleteditems i ON ( i.itemnumber = s.itemnumber and i.coded_location_qualifier IN ( 'F_B_W', 'F_B_M', 'F_M_C', 'F_M_K', 'F_M_R', 'F_M_V', 'F_M_D', 'F_M_P', 'F_M_O', 'F_M_B', 'M_B_W', 'M_B_M', 'M_M_C', 'M_M_K', 'M_M_R', 'M_M_V', 'M_M_D', 'M_M_P', 'M_M_O', 'M_M_B'  ) )
        where ( date(s.datetime) >= ( @startdatum ) ) 
          and ( date(s.datetime) <= ( @enddatum ) )
          and s.type in ('issue', 'renew')
        group by s.branch, i.homebranch
    )   as sums,
    (   select s.branchcode 
        from   branches s
        where 
            ((@branchgroupSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode IN (select branchcode from library_groups where parent_id = (@branchgroupSel := ?) COLLATE utf8mb4_unicode_ci))
            or
            ((@branchcodeSelect0or1 := ?) COLLATE utf8mb4_unicode_ci = '1' and s.branchcode = (@branchcodeSel := ?) COLLATE utf8mb4_unicode_ci)
            or
            (@branchgroupSelect0or1 COLLATE utf8mb4_unicode_ci != '1' and @branchcodeSelect0or1 COLLATE utf8mb4_unicode_ci != '1')
    ) as br
    where sums.branch = br.branchcode OR ( (sums.branch IS NULL or sums.branch = 'OPACRenew' ) AND sums.homebranch = br.branchcode)
};



sub new {
    my $class = shift;
    my $input = shift;
    my $statisticstypedesignation = shift;

    my $self  = {};
    bless $self, $class;
    #print STDERR "C4::AggregatedStatistics::DBS::new Dumper(input):", Dumper($input), ":\n" if $debug;

    $self = $self->SUPER::new($input);
    $self->{'statisticstypedesignation'} = $statisticstypedesignation;
    bless $self, $class;
    #print STDERR "C4::AggregatedStatistics::DBS::new Dumper(input)2:", Dumper($input), ":\n" if $debug;

    $self->{'selectedgroup'}  = $input->param('selectedgroup') || '*';    # default, in case it can not be read from table aggregated_statistics_parameters
    $self->{'selectedbranch'} = $input->param('selectedbranch') || '*';   # default, in case it can not be read from table aggregated_statistics_parameters

print STDERR "DBS::new self->{'id'}:$self->{'id'}:\n" if $debug;
print STDERR "DBS::new self->{'statisticstype'}:$self->{'statisticstype'}:\n" if $debug;
print STDERR "DBS::new self->{'statisticstypedesignation'}:$self->{'statisticstypedesignation'}:\n" if $debug;
print STDERR "DBS::new self->{'name'}:$self->{'name'}:\n" if $debug;
print STDERR "DBS::new self->{'startdate'}:$self->{'startdate'}:\n" if $debug;

    return $self;
}

sub getadditionalparameters {
    my $self = shift;

    my $additionalparameters = {
        categories => $self->{'categories'},
        branchloop => $self->{'branchloop'},
        selectedgroup => $self->{'selectedgroup'},
        selectedbranch => $self->{'selectedbranch'}
    };

    return $additionalparameters;
}



# 1. section: functions required for aggregated-statistics-parameters-DBS.inc

# prepare the form part for adding / editing / copying aggregated_statistics_parameter records
# ( the form is contained in aggregated_statistics.tt, the form part in aggregated-statistics-parameters-DBS.inc )
sub add_form {
    my $self = shift;
    my ($input) = @_;

    #print STDERR "C4::AggregatedStatistics::DBS::add_form Dumper(input):", Dumper($input), ":\n" if $debug;
    print STDERR "C4::AggregatedStatistics::DBS::add_form input->param('statisticstype')", scalar $input->param('statisticstype'), ": input->param('name')", scalar $input->param('name'), ":\n" if $debug;
    print STDERR "C4::AggregatedStatistics::DBS::add_form self->{'id'}:$self->{'id'}: self->{'statisticstype'}:$self->{'statisticstype'}: self->{'name'}:$self->{'name'}: self->{'startdate'}:$self->{'startdate'}: self->{'enddate'}:$self->{'enddate'}:\n" if $debug;
    print STDERR "C4::AggregatedStatistics::DBSClass::add_form input->param('selectedgroup')", scalar $input->param('selectedgroup'), ": input->param('selectedbranch')", scalar $input->param('selectedbranch'), ":\n" if $debug;

    my $found = $self->SUPER::readbyname($input);

    $self->{'selectedgroup'}  = $input->param('selectedgroup') || '*';    # default, in case it can not be read from table aggregated_statistics_parameters
    $self->{'selectedbranch'} = $input->param('selectedbranch') || '*';   # default, in case it can not be read from table aggregated_statistics_parameters

    my $aggregated_statistics_id = $self->{'id'};
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
                $self->{'selectedgroup'} = $rsHit->get_column('value');
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
                $self->{'selectedbranch'} = $rsHit->get_column('value');
            }
        }
    }

    &read_categories_and_branches();    # sets variables @categories and @branchloop, which are required for the HTML form part added by aggregated-statistics-parameters-DBS.inc
    $self->{'categories'} = \@categories;
    $self->{'branchloop'} = \@branchloop;

    return $found;
}

# evaluate the form part for adding / editing / copying aggregated_statistics_parameter records
# ( the form is contained in aggregated_statistics.tt, the form part in aggregated-statistics-parameters-DBS.inc )
sub add_validate {
    my $self = shift;
    my ($input) = @_;
    my $res;


print STDERR "C4::AggregatedStatistics::DBS::add_validate self->id:",$self->{'id'},"\n" if $debug;
#print STDERR "C4::AggregatedStatistics::DBS::add_validate Dumper(input):", Dumper($input), ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::add_validate input->param(selectedgroup):", scalar $input->param('selectedgroup'), ": input->param(selectedbranch):", scalar $input->param('selectedbranch'), ":\n" if $debug;

    my $old_id = $self->{'id'};
    my $aggregatedStatistics = $self->SUPER::add_validate($input);

    $self->{'selectedgroup'} = $input->param('selectedgroup');
    $self->{'selectedbranch'} = $input->param('selectedbranch');

    my $selectedgroup = $self->{'selectedgroup'};
    my $selectedbranch = $self->{'selectedbranch'};
    $selectedgroup = '' if ( !defined($selectedgroup) or $selectedgroup eq '*' );
    $selectedbranch = '' if ( !defined($selectedbranch) or $selectedbranch eq '*' );
    
    my $new_id = $self->{'id'};
    if ( defined($new_id) && length($new_id) > 0 ) {

        # insert / update aggregated_statistics_parameters record set according to the new / updated aggregated_statistics record
        my $selParam = { 
            statistics_id => $new_id
        };
        $res = C4::AggregatedStatistics::DelAggregatedStatisticsParameters($selParam);    # delete all entries from aggregated_statistics_parameters where statistics_id = $id

        my $insParam = { 
            statistics_id => $new_id,
            name => 'branchgroup',
            value => $selectedgroup
        };
        $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );

        $insParam = { 
            statistics_id => $new_id,
            name => 'branchcode',
            value => $selectedbranch
        };
        $res = C4::AggregatedStatistics::UpdAggregatedStatisticsParameters( $insParam );


        # copy aggregated_statistics_values record set and recalculate it according to the new copied aggregated_statistics record
        if ( $self->{'op'} eq 'copy_validate' ) {
            # copy aggregated_statistics_values records having statistics_id = $old_id to the new statistics_id = $new_id ...
            $self->copy_ag_values($old_id);
            # ... and recalculate the values according to the parameters as well as to startdate and enddate
            $self->recalculate_ag_values($self->{'startdateDB'}, $self->{'enddateDB'});
        }
    }
    return $aggregatedStatistics;
}

#  copy all records from aggregated_statistics_values where statistics_id = $id_source to records with statistics_id = $self->{'id'}
sub copy_ag_values {
    my $self = shift;
    my $id_source = shift;
    my $id_target = $self->{'id'};
    my $res;

print STDERR "C4::AggregatedStatistics::DBS::copy_ag_values id_source:$id_source:  id_target:$id_target:\n" if $debug;

    if ( defined($id_source) && length($id_source) > 0 && defined($id_target) && length($id_target) > 0 && $id_source ne $id_target) {
        my $selParam = { 
            statistics_id => $id_target
        };
        $res = C4::AggregatedStatistics::DelAggregatedStatisticsValues($selParam);    # delete all entries from aggregated_statistics_parameters where statistics_id = $id_target

        my $aggregatedStatisticsValues = C4::AggregatedStatistics::GetAggregatedStatisticsValues(
            {
                statistics_id => $id_source,
            }
        );
print STDERR "C4::AggregatedStatistics::DBS::copy_ag_values  count aggregatedStatisticsValues:", $aggregatedStatisticsValues->_resultset()+0, ":\n" if $debug;
        if ($aggregatedStatisticsValues && $aggregatedStatisticsValues->_resultset() && $aggregatedStatisticsValues->_resultset()->all()) {
            foreach my $rsHit ($aggregatedStatisticsValues->_resultset()->all()) {
print STDERR "C4::AggregatedStatistics::DBS::copy_ag_values  rsHit statistics_id:", $rsHit->get_column('statistics_id'), ": name:", $rsHit->get_column('name'), ": value:", $rsHit->get_column('value'), ":\n" if $debug;
                C4::AggregatedStatistics::UpdAggregatedStatisticsValues(
                    {
                        statistics_id => $id_target,
                        name => $rsHit->get_column('name'),
                        value => $rsHit->get_column('value'),
                        type => $rsHit->get_column('type'),
                    }
                );
            }
        }
    }
}

# Calculate DBS values from Koha fields and update table aggregated_statistics_values accordingly.
sub recalculate_ag_values {
    my $self = shift;
    my ($startdateDB, $enddateDB) = @_;
    my $res;

print STDERR "C4::AggregatedStatistics::DBS::recalculate_ag_values startdateDB:$startdateDB: enddateDB:$enddateDB: self->id:$self->{'id'}:\n" if $debug;

    my ($branchgroupSel, $branchgroup, $branchcodeSel, $branchcode) = $self->get_branchgroup_branchcode_selection();

    # calculate DBS statistics values where possible
    foreach my $name (keys %{$as_values}) {
        if ( defined($as_values->{$name}->{'calc'}) ) {
            $res = &{$as_values->{$name}->{'calc'}}($name, $as_values->{$name}->{'param'}, $startdateDB, $enddateDB, $branchgroupSel, $branchgroup, $branchcodeSel, $branchcode);

print STDERR "C4::AggregatedStatistics::DBS::recalculate_ag_values loop self->id:$self->{'id'}: name:$name: res:$res:\n" if $debug;
            C4::AggregatedStatistics::UpdAggregatedStatisticsValues(
                {
                    statistics_id => $self->{'id'},
                    name => $name,
                    value => $res,
                    type => $as_values->{$name}->{'type'},
                }
            );
        }
    }
}

sub get_branchgroup_branchcode_selection {
    my $self = shift;

    my $branchgroupSel = 0;    # default: no selection for branchgroup
    my $branchgroup = $self->readAggregatedStatisticsParametersValue('branchgroup');
    if ( !defined($branchgroup) || length($branchgroup) == 0 || $branchgroup eq '*' ) {
        $branchgroup = '';
    } else {
        $branchgroupSel = 1;
    }
    my $branchcodeSel = 0;    # default: no selection for branchcode
    my $branchcode = $self->readAggregatedStatisticsParametersValue('branchcode');
    if ( !defined($branchcode) || length($branchcode) == 0 || $branchcode eq '*' ) {
        $branchcode = '';
    } else {
        $branchcodeSel = 1;
        $branchgroupSel = 0;    # of course the finer selection 'branchcode' has to be used, if existing, in favour of 'branchgroup'
    }
    return ($branchgroupSel, $branchgroup, $branchcodeSel, $branchcode);
}

sub read_categories_and_branches {

    # read library categories into variable @categories
    @categories = ();
    for my $category ( Koha::Library::Groups->get_search_groups( { interface => 'staff' } ) ) {    # fields used in template: category.id and category.categoryname
        push @categories, { categorycode => $category->id, categoryname => $category->title };
        print STDERR "C4::AggregatedStatistics::DBS::read_categories_and_branches category->unblessed categorycode:", $category->description,  ": categoryname:", $category->title, ":\n" if $debug;
    }

    # read branch information into variable @branchloop
    my $branches = { map { $_->branchcode => $_->unblessed } Koha::Libraries->search };
    @branchloop = ();
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

sub supports {
    my $self = shift;
    my $method = shift;
    my $ret = 0;

    if ( $method eq 'eval_form' ) {
        $ret = 1;
    } elsif ( $method eq 'dcv_calc' ) {
        $ret = 1;
    } elsif ( $method eq 'dcv_save' ) {
        $ret = 1;
    } elsif ( $method eq 'dcv_del' ) {
        $ret = 1;
    }
    return $ret;
}

# prepare the form for evaluating / editing the specific statistics DBS
sub eval_form {
    my $self = shift;
    my ($script_name, $input) = @_;
    my $res;
print STDERR "C4::AggregatedStatistics::DBS::eval_form Start self->statisticstype:$self->{'statisticstype'}: statisticstypedesignation:$self->{'statisticstypedesignation'}: id:$self->{'id'}: name:$self->{'name'}: startdate:$self->{'startdate'}: enddate:$self->{'enddate'}:\n" if $debug;

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

    my $branchgroup = $self->readAggregatedStatisticsParametersValue('branchgroup');
    my $branchcode = $self->readAggregatedStatisticsParametersValue('branchcode');

    $self->{'selectedgroup'}  = $branchgroup || '*';
    $self->{'selectedbranch'} = $branchcode || '*';

    my $group = Koha::Library::Groups->find( $branchgroup );
    $group = $group->unblessed if ( $group );
print STDERR "C4::AggregatedStatistics::DBS::eval_form Dumper(category):", Dumper($group), ":\n" if $debug;
    my $selectedgroupname = ($group && $group->{title}) ? $group->{title} : '*';
    my $library = Koha::Libraries->find($branchcode);
    my $selectedbranchname = ($library && $library->branchname) ? $library->branchname : '';
print STDERR "C4::AggregatedStatistics::DBS::eval_form branchcode:$branchcode: selectedbranchname:$selectedbranchname:\n" if $debug;

    # basic fields
    $template->param(
    	script_name => $script_name,
    	action => $script_name,
        id => $self->{'id'},
        statisticstype => $self->{'statisticstype'},
        statisticstypedesignation => $self->{'statisticstypedesignation'},
    	name => $self->{'name'},
    	description => $self->{'description'},
    	startdate => $self->{'startdate'},
    	enddate => $self->{'enddate'},
    	selectedgroup => $self->{'selectedgroup'},
    	selectedbranch => $self->{'selectedbranch'},
        selectedgroupname => $selectedgroupname,
        selectedbranchname => $selectedbranchname
    );

    # DBS list fields
    my $st = {};
    if ( $self->{'op'} eq 'dcv_calc' ) {
        # set values from input
        foreach my $name (keys %{$as_values}) {
            $as_values->{$name}->{'value'} = $input->param('st_' . $name);
            if ( $as_values->{$name}->{'type'} eq 'float' ) {
                # The float values in $input->param('st_' . $name) have been formatted by javascript for display in the HTML page, but we need them in database form again (i.e without thousands separator, with decimal separator '.').
                my $thousands_sep = ' ';    # default, correct if Koha.Preference("CurrencyFormat") == 'FR'  (i.e. european format like "1 234 567,89")
                if ( substr($as_values->{$name}->{'value'},-3,1) eq '.' ) {    # american format, like "1,234,567.89"
                    $thousands_sep = ',';
                }
                $as_values->{$name}->{'value'} =~ s/$thousands_sep//g;    # get rid of the thousands separator
                $as_values->{$name}->{'value'} =~ tr/,/./;      # decimal separator in DB is '.'
            }
            $st->{$name} = $as_values->{$name}->{'value'};
        }
    } else {
        # set values from table aggregated_statistics_values
        my $dbs_values = $self->dcv_read();
print STDERR "C4::AggregatedStatistics::DBS::eval_form ref(\$dbs_values):",ref($dbs_values), ": statisticstypedesignation:",$self->{'statisticstypedesignation'},": id:",$self->{'id'},": name:",$self->{'name'},": startdate:",$self->{'startdate'},": enddate:",$self->{'enddate'},":\n" if $debug;
        if ( ref($dbs_values) eq 'HASH' ) {
            foreach my $name (keys %{$dbs_values}) {
                if ( $dbs_values->{$name}->{'type'} eq 'bool' ) {
print STDERR "C4::AggregatedStatistics::DBS::eval_form \$dbs_values->{", $name, "}->{'value'}:", $dbs_values->{$name}->{'value'}, ":\n" if $debug;
                    if ( !defined($dbs_values->{$name}->{'value'}) || $dbs_values->{$name}->{'value'} + 0 == 0 ) {
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

# Calculate DBS values from Koha fields and prepare them for display in HTML form.
sub dcv_calc {
    my $self = shift;
    my $input = shift;

print STDERR "C4::AggregatedStatistics::DBS::dcv_calc Start self->id:", $self->{'id'}, ": self->statisticstype:", $self->{'statisticstype'}, ": self->statisticstypedesignation:", $self->{'statisticstypedesignation'}, ": self->name:", $self->{'name'}, ":\n" if $debug;
print STDERR "C4::AggregatedStatistics::DBS::dcv_calc Start ref(\$input):", ref($input), ": input:", $input, ":\n" if $debug;

    my ($branchgroupSel, $branchgroup, $branchcodeSel, $branchcode) = $self->get_branchgroup_branchcode_selection();

    # calculate DBS statistics values where possible
    foreach my $name (keys %{$as_values}) {
        if ( defined($as_values->{$name}->{'calc'}) ) {
            $input->{'param'}->{'st_' . $name}->[0] = &{$as_values->{$name}->{'calc'}}($name, $as_values->{$name}->{'param'}, $self->{'startdate'}, $self->{'enddate'}, $branchgroupSel, $branchgroup, $branchcodeSel, $branchcode);
        }
    }
}

sub dcv_save {
    my $self = shift;
    my $input = shift;
    my $res;
print STDERR "C4::AggregatedStatistics::DBS::dcv_save Start self->id:", $self->{'id'}, ": self->statisticstype:", $self->{'statisticstype'}, ": self->statisticstypedesignation:", $self->{'statisticstypedesignation'}, ": self->name:", $self->{'name'}, ":\n" if $debug;

print STDERR "C4::AggregatedStatistics::DBS::dcv_save Start ref(\$input):", ref($input), ": input:", $input, ":\n" if $debug;

    # store or delete it in database
    foreach my $name (keys %{$as_values}) {
        my $value = $input->param('st_' . $name);
print STDERR "C4::AggregatedStatistics::DBS::dcv_save loop self->id:", $self->{'id'}, ": name:$name: value:$value:\n" if $debug;
        $self->saveAggregatedStatisticsValue($name, $as_values->{$name}->{'type'}, $value);
    }

    # read it from database into hash $as_values
    $self->dcv_read();
}

# read corresponding aggregated_statistics_values records
sub dcv_read {
    my $self = shift;
    my $hit = {};
print STDERR "C4::AggregatedStatistics::DBS::dcv_read Start self->id:",$self->{'id'},":\n" if $debug;
    foreach my $name (keys %{$as_values}) {
        $self->readAggregatedStatisticsValue($name,$as_values->{$name}->{'type'},\$hit);
        $as_values->{$name}->{'id'} = $hit->{'statistics_id'};
        #already set: $as_values->{$name}->{'name'} = $hit->{'name'};
        $as_values->{$name}->{'value'} = $hit->{'value'};
        #already set: $as_values->{$name}->{'type'} = $hit->{'type'};
    }
    return $as_values;
}

sub dcv_del {
    my $self = shift;
print STDERR "C4::AggregatedStatistics::DBS::dcv_del Start self->id:",$self->{'id'},":\n" if $debug;

    # delete all records from aggregated_statistics_values having this statistics_id
    my $name = undef;
    $self->delAggregatedStatisticsValue($name);

    # read it from database into hash $as_values
    $self->dcv_read();
}

sub func_call_sql {
    my ($name, $param, $startdate, $enddate, $branchgroupSel, $branchgroup, $branchcodeSel, $branchcode) = @_;
    my $res = 0;

print STDERR "C4::AggregatedStatistics::DBS::func_call_sql Start name:$name: startdate:$startdate: enddate:$enddate: branchgroupSel:$branchgroupSel: branchgroup:$branchgroup: branchcodeSel:$branchcodeSel: branchcode:$branchcode:\n" if $debug;

print STDERR "C4::AggregatedStatistics::DBS::func_call_sql Start sql statement:", $dbs_sql_statements->{$name}, ":\n" if $debug;

    my $sth = $dbh->prepare($dbs_sql_statements->{$name});
    $sth->execute($startdate, $enddate, $branchgroupSel, $branchgroup, $branchcodeSel, $branchcode);

    unless ($sth) {
        die "execute_query failed to return sth for sql statement: $dbs_sql_statements->{$name}";
    } else {
        my $row = $sth->fetchrow_arrayref();
        $res = $row->[0];
print STDERR "C4::AggregatedStatistics::DBS::func_call_sql res:$res:\n" if $debug;
    }

    return $res;

}



1;
