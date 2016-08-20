#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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
It's a simple HTTP POST with two parameters is been sent (userid and password) and an XML response strcutre expected
which tells whether the authentication call was successful or not. Using the authentication interface, the onleihe 
validates user logins against the origin ILS system.

=cut

use strict;
use warnings;

use DateTime;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Members;
use Koha::AuthUtils qw(hash_password);
use C4::Auth qw(&checkpw_hash);

my $query = new CGI;

my $dbh = C4::Context->dbh;


# open the xml response template
my ( $template, $loggedinuser, $templatename) = get_template_and_user(
    {
        template_name   => "opac-divibib-auth.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 1
    }
);

# the two parameters are sno (userid) and pwd (password)
my $borrowernumber = $query->param("sno") || '';
my $password       = $query->param("pwd") || '';
my $trace          = $query->param("trace") || 0;


my ($borrower, $age, $checkpw);

# initialize a default response structure
my $response = {
		'status'   => -1, # wrong login-data (user or password)
		'fsk'      => 0,
		'cardid'   => '',
		'userid'   => '',
		'library'  => '',
		'trace'    => ''
		};

# let's check with the userid 
$borrower = &GetMember( userid => $borrowernumber );
if ( $borrower ) {
	# we need to read the member details, thats why we read the member record again
	$borrower = &GetMemberDetails($borrower->{'borrowernumber'});
}

# we did not find the borrower by userid
# let's check whether the borrower number is used instead
if (! $borrower ) { 
	$borrower = &GetMemberDetails($borrowernumber);
}

# we did not find the borrower by userid and also not by borrowernumber
# let's check whether the barcode is used instead
if (! $borrower ) { 
	$borrower = &GetMemberDetails('',$borrowernumber);
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
	# The first check is used for NCIP service inegration from Koha to teh onleihe where we
	# use the saved encrypted password to authenticate user activities on behalf of the user
	# automatically. Since the onleihe is sending the passowrd back to us to authenticate/authorize
	# onleihe actions, we use that hack to prevent that wer need to request each time a password
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
	}
	else {
		$response->{'status'} = -2; # wrong password
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
	
	# fill the response strucre
	$response->{'cardid'} = $borrower->{'cardnumber'};
	$response->{'userid'} = $borrower->{'borrowernumber'};
}

# use the following for tracing purposes
if ( $trace )  {
	if ( $borrower ) {
		$response->{'trace'} = "Borrower found: $borrowernumber, Password: $password, Age: $age, Checkpw: $checkpw, Hashpw: " . Koha::AuthUtils::hash_password($password, $checkpw);
	}
	else {
		$response->{'trace'} = "Borrower not found";
	}
}

# return the response structure
$template->param(
	response => $response
);

# output needs to be of type text/xml
output_with_http_headers $query, '', $template->output, 'xml', undef, { force_no_caching => 1 };
