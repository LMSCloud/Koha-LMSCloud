#!/usr/bin/perl

# Copyright ByWater Solutions 2015
# parts Copyright 2019-2020 (C) LMSCLoud GmbH
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


use Modern::Perl;
use utf8;
use Data::Dumper;

use CGI;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI;
use Digest;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use JSON;
use Encode;
use CGI::Carp;
use SOAP::Lite;

use C4::Auth;
use C4::Output;
use C4::Context;
use Koha::Acquisition::Currencies;
use Koha::Database;
use Koha::Plugins::Handler;
use Koha::Patrons;
use C4::Epayment::GiroSolution;
use C4::Epayment::PmPaymentPaypage;
use C4::Epayment::EPayBLPaypage;

my $cgi = CGI->new;
my $payment_method = $cgi->param('payment_method');
my @accountlines   = $cgi->multi_param('accountline');

my $use_plugin = Koha::Plugins::Handler->run(
    {   class  => $payment_method,
        method => 'opac_online_payment',
        cgi    => $cgi,
    }
);

unless ( $use_plugin ) {
    print $cgi->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $key = 'dsTFshg5678DGHMO';    # dummy for wrong HMAC digest
sub genHmacMd5 {
    my ($key, $str) = @_;
    my $hmac_md5 = Digest->HMAC_MD5($key);
    $hmac_md5->add($str);
    my $hashval = $hmac_md5->hexdigest();

    return $hashval;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-account-pay-error.tt",
        query           => $cgi,
        type            => "opac",
        debug           => 1,
    }
);

my $logger = Koha::Logger->get({ interface => 'epayment' });    # logger common to all e-payment methods
$logger->debug("opac-account-pay.pl: START payment_method:$payment_method: borrowernumber:$borrowernumber: accountlines:" . Dumper(@accountlines) . ":");

# get borrower information
my $patron = Koha::Patrons->find( $borrowernumber );

my $amount_to_pay =
  Koha::Database->new()->schema()->resultset('Accountline')->search( { accountlines_id => { -in => \@accountlines } } )
  ->get_column('amountoutstanding')->sum();
$amount_to_pay = sprintf( "%.2f", $amount_to_pay );

my $active_currency = Koha::Acquisition::Currencies->get_active;

my $error = 0;

Koha::Plugins::Handler->run(
    {
        class  => $payment_method,
        method => 'opac_online_payment_begin',
        cgi    => $cgi,
    }
);
