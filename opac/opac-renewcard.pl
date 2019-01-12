#!/usr/bin/perl
# This script lets the users change the passwords by themselves.
#
# Copyright 2019 (C) LMSCLoud GmbH
#
# This file is part of the extensions and enhacments made to koha by Universidad ORT Uruguay
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

use Modern::Perl;
use Locale::Currency::Format 1.28;
use strict;

use CGI qw ( -utf8 );

use C4::Auth;
use C4::Context;
use C4::Output;
use Koha::Patrons;

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-renewcard.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        debug           => 1,
    }
);

my $borrower;
my $errors = [];
my $opacRenewCardDisplay = 1;
my $opacRenewCardPermitted = 0;
my $card_renewed = 0;
my $enrolment_fee = 0.0;
my $enrolment_period = undef;

# get borrower information ....
my $patron = Koha::Patrons->find( $borrowernumber );

if ( !$patron ) {
    $opacRenewCardDisplay = 0;
} else {
    $borrower = $patron->unblessed;
    my $category = $patron->category();
    if ( $category ) {
        $enrolment_fee = $category->enrolmentfee();
        $enrolment_period = $category->enrolmentperiod();
    }

    # Check if the borrower's category is permitted for card renewal in OPAC (via C4::Context->preference("OpacRenewCardPatronCategories")),
    # check if the lead time before card expiry is not exceeded (via C4::Context->preference("OpacRenewCardLeadTime")),
    # check if enrolment period is valid (i.e. no renewals based on fixed categories.enrolmentperioddate).
    $errors = $patron->opac_account_renewal_permitted();

    if ( @$errors == 0 ) {    # all checks passed, no error
        if ( $query->param('submitState') eq 'submitted' &&
             ( $query->param('enrolment_fee_accepted') || $enrolment_fee == 0.0 )
           ) {
            # Patron has checked agreement text and submitted renewal.
            my $dateexpiry = $patron->renew_account();    # same re-reregistration function as in staff interface
            $patron = Koha::Patrons->find( $borrowernumber );
            $borrower = $patron->unblessed;

            if ( $dateexpiry ) {
                $card_renewed = 1;
            }
            else {
                $errors->[0] = 'CardRenewalFailed';
            }
        } 
        else {
            # Called empty; display library card data and ask if the card should be renewed.
            $opacRenewCardPermitted = 1;
        }
    }
}

$template->param(
    renewcardview => 1,
    BORROWER_INFO => $borrower,
    enrolment_fee => $enrolment_fee,
    enrolment_period => $enrolment_period,
    opacRenewCardDisplay => $opacRenewCardDisplay,
    opacRenewCardPermitted => $opacRenewCardPermitted,
    opacRenewCardConfirmationText => C4::Context->preference("OpacRenewCardConfirmationText"),
    card_renewed => $card_renewed,
    errors => $errors
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
