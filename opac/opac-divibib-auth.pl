#!/usr/bin/perl

# Copyright 2017,2021 LMSCloud GmbH
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


=head1 opac-divibib-auth.pl

This program implements the Authentication interface of the German onleihe, a paid service of the divibib GmbH.
It's a simple HTTP POST request with two parameters sent (userid and password) and an XML response structure expected
which tells whether the authentication call was successful or not. Using the authentication interface, the onleihe 
validates user logins against the origin ILS system.

Returns the follwoing response:

<?xml version=”1.0” encoding=”UTF-8”?>
<response>
    <status>[status]</status>
    <fsk>[fsk]</fsk>
    <cardid>[cardid]</cardid>
    <userid>[userid]</userid>
</response>

status can be one of the following:
-4  => user is not permitted to loan digital documents
-3  => the user account is expired
-2  => wrong password
-1  => wrong credentials
 0  => user account deleted
 1  => user debarred
 2  => test user
 3  => valid user account 
 4  => user debarred due to blocking fines

the return value for fsk specifies an age level which can be
0, 6, 12, 16 or 18

=cut

use strict;
use warnings;

use DateTime;

use Data::Dumper;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Log qw( logaction );
use C4::Stats qw( UpdateStats );
use C4::External::DivibibPatronStatus;

my $query = new CGI;

# Generate the CGI response (text/xml in this case) without using template toolkit
# in order to avoid errors caused by translation of templates containing a xml prolog.
sub output_divibib_xml {
    my ( $query, $data ) = @_;

    my $options = {
        type              => 'text/xml',
        status            => '200 OK',
        charset           => 'UTF-8',
        Pragma            => 'no-cache',
        'Cache-Control'   => 'no-cache, no-store, max-age=0',
        'X-Frame-Options' => 'SAMEORIGIN',
    };
    $options->{expires} = 'now';

    $data =~ s/\&amp\;amp\; /\&amp\; /g;
    binmode(STDOUT, ":utf8");
    print $query->header($options), $data;
}


# check if divibib communication is enabled at all; if not: deny access
unless (C4::Context->preference('DivibibEnabled') || C4::Context->preference('DivibibAuthEnabled')) {
    print $query->header(status => '403 Forbidden - Divibib Onleihe integration in OPAC is not enabled');
    exit;
}


# the two request parameters are sno (userid) and pwd (password)
my $borrowernumber = $query->param("sno") || '';
my $password       = $query->param("pwd") || '';

# initialize a default response structure
my $response = {
		'status'   => -1, # wrong login-data (user or password)    # mandatory
		'fsk'      => 0,                                           # mandatory
		'cardid'   => '',                                          # mandatory
		'userid'   => ''                                           # mandatory
		};

my $patronStatus = C4::External::DivibibPatronStatus->new($borrowernumber,$password);
my $patron = $patronStatus->getPatron();

# if the borrower was found
if ( $patron ) { 
	
	$response =  $patronStatus->getPatronStatus();
	
	if ( C4::Context->preference("DivibibLog") ) {
        my $dumper = Data::Dumper->new( [{ request_userid => $borrowernumber, requester_ip => $ENV{'REMOTE_ADDR'}, response => $response }]);
        logaction(  "DIVIBIB", 
                    "AUTHENTICATION", 
                    $patron->borrowernumber, 
                    $dumper->Indent(0)->Terse(1)->Dump,
                    'opac'
                );
    }
    
    # also log to table statistics (required since DBS 2019)
    my $dumper = Data::Dumper->new( [{ request_userid => $borrowernumber, requester_ip => $ENV{'REMOTE_ADDR'}, response => $response }]);
    UpdateStats(
        {
            branch         => $patron->branchcode,
            type           => 'auth-ext',
            borrowernumber => $patron->borrowernumber,
            other          => $dumper->Indent(0)->Terse(1)->Dump
        }
    );
    
}

# In order to avoid errors caused by translation of templates containing a xml prolog, we do not use a template here but
# build and output the xml response directly.

# build the components of the response
my $output_header = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n";
my $output_response_tag_start = "<response>\n";
my $output_status_tag = sprintf("<status>%s</status>\n",$response->{'status'});
my $output_fsk_tag = sprintf("<fsk>%s</fsk>\n",$response->{'fsk'});
my $output_cardid_tag = sprintf("<cardid>%s</cardid>\n",$response->{'cardid'});
my $output_userid_tag = sprintf("<userid>%s</userid>\n",$response->{'userid'});
my $output_response_tag_end = "</response>\n";

    
# finally build the response from its components
my $output = sprintf("%s%s%s%s%s%s%s", $output_header, $output_response_tag_start, $output_status_tag, $output_fsk_tag, $output_cardid_tag, $output_userid_tag, $output_response_tag_end);

# send the response
&output_divibib_xml( $query, $output );

