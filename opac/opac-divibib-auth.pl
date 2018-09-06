#!/usr/bin/perl

# Copyright 2017 LMSCloud GmbH
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

=cut

use strict;
use warnings;

use DateTime;

use Data::Dumper;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Members;
use Koha::AuthUtils qw(hash_password);
use C4::Auth qw(&checkpw_hash);
use C4::Log qw( logaction );

my $query = new CGI;

my $dbh = C4::Context->dbh;



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
unless (C4::Context->preference('DivibibEnabled')) {
    print $query->header(status => '403 Forbidden - Divibib Onleihe integration in OPAC is not enabled');
    exit;
}


# the two request parameters are sno (userid) and pwd (password)
my $borrowernumber = $query->param("sno") || '';
my $password       = $query->param("pwd") || '';


my ($borrower, $age, $checkpw);

# initialize a default response structure
my $response = {
		'status'   => -1, # wrong login-data (user or password)    # mandatory
		'fsk'      => 0,                                           # mandatory
		'cardid'   => '',                                          # mandatory
		'userid'   => ''                                           # mandatory
		};

# Check the borrower with the internal borrower number
$borrower = &GetMemberDetails($borrowernumber);
if ( $borrower ) {
    $checkpw = $borrower->{'password'};
    if (!($checkpw eq $password || &checkpw_hash($password,$checkpw)) ) {
        $borrower = undef;
    }
}

# if we did not find the borrower by borrower number, we check with
# users' barcode instead
if (! $borrower ) { 
	$borrower = &GetMemberDetails('',$borrowernumber);
	if ( $borrower ) {
        $checkpw = $borrower->{'password'};
        if (!($checkpw eq $password || &checkpw_hash($password,$checkpw)) ) {
            $borrower = undef;
        }
    }
}

# finally let test the userid 
if (! $borrower ) { 
    $borrower = &GetMember( userid => $borrowernumber );
    if ( $borrower ) {
        # we need to read the member details, thats why we read the member record again
        $borrower = &GetMemberDetails($borrower->{'borrowernumber'});
    }
}

# if the borrower was found
if ( $borrower ) { 
	
	# we read the age to return the appropriate age level 
	# which is used by onleihe to provide appropriate material
	$age = &GetAge($borrower->{'dateofbirth'});
	
	# read the encrypted password
	$checkpw = $borrower->{'password'};
	
	# we check the password 
	# Due to the fact that there are two different uses of the authentication interface
	# we implement two password checks
	# If the user logs in to the onleihe user interface he needs two provide username and password 
	# for that case we use the second check
	# The first check is used for NCIP service inegration from Koha to the onleihe where we
	# use the saved encrypted password to authenticate user activities on behalf of the user
	# automatically. Since the onleihe is sending the passowrd back to us to authenticate/authorize
	# onleihe actions, we use that hack to prevent that we need to request each time a password
	# from a logged in opac user.
	if ( $checkpw eq $password || &checkpw_hash($password,$checkpw) ) {
		$response->{'status'} = 3; # online user access permitted
		
		my $amountlimit = C4::Context->preference("noissuescharge");
		my ($balance, $non_issue_charges, $other_charges) =
			C4::Members::GetMemberAccountBalance( $borrower->{'borrowernumber'} );
			
		my ($blocktype, $count) = C4::Members::IsMemberBlocked($borrower->{'borrowernumber'});
		if ($blocktype == -1) {
			## patron has outstanding overdue loans
			if ( C4::Context->preference("OverduesBlockCirc") eq 'block'){
				$response->{'status'} = 1; # patron debarred, no access
			}
			elsif ( C4::Context->preference("OverduesBlockCirc") eq 'confirmation'){
				$response->{'status'} = 1; # patron debarred, no access
			}
		} elsif($blocktype == 1) {
			# patron has accrued fine days or has a restriction. $count is a date
			if ($count eq '9999-12-31') {
				$response->{'status'} = 1; # patron debarred, no access
			}
		}


		if ( $borrower->{'is_expired'} ) {
			$response->{'status'} = -3; # account expired
		}
		elsif ( $borrower->{'flags'}->{'DBARRED'} ) {
			$response->{'status'} = 1; # patron debarred, no access
		}
		elsif ( $borrower->{'flags'}->{'GNA'} ) {
			$response->{'status'} = 1; # patron has no valid address, no access
		}
		elsif ( $borrower->{flags}->{LOST} ) {
			$response->{'status'} = 1; # account expired (due to a lost card)
		}
		elsif ( $non_issue_charges > $amountlimit ) {
			$response->{'status'} = 4; # user debarred due to too much fines
		}
	
	    # determine the the correct age level
	    if ( $age > 0 && $age < 6 ) {
		    $response->{'fsk'} = 0;
	    }
	    elsif ( $age >= 6 && $age < 12 ) {
		    $response->{'fsk'} = 6;
	    }
	    elsif ( $age >= 12 && $age < 16 ) {
		    $response->{'fsk'} = 12;
	    }
	    elsif ( $age >= 16 && $age < 18 ) {
		    $response->{'fsk'} = 16;
	    }
	    else {
		    $response->{'fsk'} = 18;
	    }
	    
	    $response->{'cardid'} = $borrower->{'cardnumber'};
	    $response->{'userid'} = $borrower->{'borrowernumber'};
	}
	else {
		$response->{'status'} = -2; # wrong password
	}
	if ( C4::Context->preference("DivibibLog") ) {
        my $dumper = Data::Dumper->new( [{ request_userid => $borrowernumber, requester_ip => $ENV{'REMOTE_ADDR'}, response => $response }]);
        logaction(  "DIVIBIB", 
                    "AUTHENTICATION", 
                    $borrower->{'borrowernumber'}, 
                    $dumper->Terse(1)->Dump
                );
    }
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
my $output = sprintf("%s%s%s%s%s%s%s%s", $output_header, $output_response_tag_start, $output_status_tag, $output_fsk_tag, $output_cardid_tag, $output_userid_tag, $output_response_tag_end);

# send the response
&output_divibib_xml( $query, $output );

