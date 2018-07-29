#!/usr/bin/perl

# Copyright 2008 LibLime
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

use C4::Auth;    # checkauth, getborrowernumber.
use C4::Context;
use C4::Koha;
use C4::Circulation;
use C4::Output;
use C4::Members;
use C4::Members::Messaging;
use C4::Form::MessagingPreferences;
use Koha::SMS::Providers;

my $query = CGI->new();

unless ( C4::Context->preference('EnhancedMessagingPreferencesOPAC') and
         C4::Context->preference('EnhancedMessagingPreferences') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'opac-messaging.tt',
        query           => $query,
        type            => 'opac',
        authnotrequired => 0,
        debug           => 1,
    }
);

my $borrower = Koha::Patrons->find( $borrowernumber )->unblessed;
my $messaging_options = C4::Members::Messaging::GetMessagingOptions();

if ( defined $query->param('modify') && $query->param('modify') eq 'yes' ) {
    my $sms = $query->param('SMSnumber');
    my $sms_provider_id = $query->param('sms_provider_id');
    if ( defined $sms && ( $borrower->{'smsalertnumber'} // '' ) ne $sms
            or ( $borrower->{sms_provider_id} // '' ) ne $sms_provider_id ) {
        ModMember(
            borrowernumber  => $borrowernumber,
            smsalertnumber  => $sms,
            sms_provider_id => $sms_provider_id,
        );
        # FIXME will not be needed when ModMember will be replaced
        $borrower = Koha::Patrons->find( $borrowernumber )->unblessed;
    }

    C4::Form::MessagingPreferences::handle_form_action($query, { borrowernumber => $borrowernumber }, $template);
}

C4::Form::MessagingPreferences::set_form_values({ borrowernumber     => $borrower->{'borrowernumber'} }, $template);

$template->param( BORROWER_INFO         => $borrower,
                  messagingview         => 1,
                  SMSnumber => $borrower->{'smsalertnumber'},
                  SMSSendDriver                =>  C4::Context->preference("SMSSendDriver"),
                  TalkingTechItivaPhone        =>  C4::Context->preference("TalkingTechItivaPhoneNotification") );

if ( C4::Context->preference("SMSSendDriver") eq 'Email' ) {
    my @providers = Koha::SMS::Providers->search();
    $template->param( sms_providers => \@providers, sms_provider_id => $borrower->{'sms_provider_id'} );
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
