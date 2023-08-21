#!/usr/bin/perl

# Copyright 2016 LMSCLoud GmbH
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

use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use C4::Auth qw( get_template_and_user get_session );
use Koha::DateUtils qw( output_pref );
use DateTime;
use C4::CashRegisterManagement;
use Locale::Currency::Format;

##########################################################
#
# Initialize seesion and parameters
#
##########################################################
my $query = CGI->new();
my $view = "reports/fines_overviews.tt";
my $printview = 0;
if ( $query->param('printview') && $query->param('printview') eq 'print' ) {
    $view = "circ/cash-register-fines-overview.tt";
    $printview = 1;
}
my ( $template, $loggedinuser, $cookie ) = get_template_and_user({
    template_name   => $view,
    query           => $query,
    type            => "intranet",
    debug           => 1,
    authnotrequired => 0,
    flagsrequired   => { reports => '*' },
});
my $sessionID = $query->cookie("CGISESSID");
my $session = get_session($sessionID);
my $branch = $session->param('branch');

my $status = '';
my $debug = '';


##########################################################
#
# Read fines overview parameter
#
##########################################################
my $journalfrom = $query->param('journalfrom');
my $journalto = $query->param('journalto');
my $finesstats;


my $finestype = $query->param('finestype');
my $reportbranch = $query->param('reportbranch');

$finestype = 'finesoverview' if (! $finestype );

my $cash_management = C4::CashRegisterManagement->new($branch,$loggedinuser);
($finesstats,$journalfrom,$journalto) = $cash_management->getFinesOverview(
        { 
            branchcode => $reportbranch,
            from => $journalfrom,
            to => $journalto,
            type => $finestype,
            cash_register_id => undef
        }
    );

$template->param( reportbranch => $reportbranch );


$template->param(
    sessionbranch => $branch,
    journalfrom => $journalfrom,
    journalto => $journalto,
    finesstats => $finesstats,
    debug => $debug,
    currency_format => $cash_management->getCurrencyFormatterData(),
    printview => $printview,
    datetimenow => output_pref({dt => DateTime->now, dateonly => 0}),
);

output_html_with_http_headers $query, $cookie, $template->output;

exit 0;
