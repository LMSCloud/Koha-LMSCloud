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
use Koha::Patrons;
use Koha::AuthUtils qw(hash_password);
use C4::Auth qw(&checkpw_hash);
use C4::Log qw( logaction );
use C4::Stats qw( UpdateStats );
use Net::IP;

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


my ($patron, $age, $checkpw);

# initialize a default response structure
my $response = {
		'status'   => -1, # wrong login-data (user or password)    # mandatory
		'fsk'      => 0,                                           # mandatory
		'cardid'   => '',                                          # mandatory
		'userid'   => ''                                           # mandatory
		};

# Check the patron with the internal borrower number
$patron = Koha::Patrons->find( $borrowernumber );
if ( $patron ) {
    $checkpw = $patron->password;
    if (!($checkpw eq $password || &checkpw_hash($password,$checkpw)) ) {
        $patron = undef;
    }
}

# if we did not find the patron by borrowernumber, we check with
# users' barcode instead
if (! $patron ) { 
	$patron = Koha::Patrons->find({ cardnumber => $borrowernumber} );
	if ( $patron ) {
        $checkpw = $patron->password;
        if (!($checkpw eq $password || &checkpw_hash($password,$checkpw)) ) {
            $patron = undef;
        }
    }
}

# finally lets test the userid 
if (! $patron ) { 
    $patron = Koha::Patrons->find({ userid => $borrowernumber} );
}

# if the borrower was found
if ( $patron ) { 
	
	my $restrictedGroup = 0;
	
	# There is an opportunity to restrict access to Divibib resources by user groups
	# The system preferences "DivibibAuthDisabledForGroups" can be set to a value like the
	# following: CATEGORYCODE1,CATEGORYCODE2,...
	# or the following: CATEGORYCODE1,CATEGORYCODE2,...@IP1,IP2,IPRANGE1
	# IP is somthing like 223.12.114.18
	# IPRANGE is somthing like 172.16.251.0/29
	# Example: PT,JE@172.16.251.0/29
	# Multiple of these statements can be set with "DivibibAuthDisabledForGroups" using separator '|'
	# Example: PT,JE@172.16.251.0/29|EW,IT@172.16.251.12,172.16.251.13
	
	if ( C4::Context->preference("DivibibAuthDisabledForGroups") ) {
	    my @groupdevs = split(/\|/, C4::Context->preference("DivibibAuthDisabledForGroups"));
	    
	    CATEGORYCHECK: foreach my $groupdev(@groupdevs) {
            $groupdev =~ s/^\s+// if ($groupdev);
            $groupdev =~ s/\s+$// if ($groupdev);
            if ( $groupdev ) {
                my @groupAndIpVal =  split(/@/,$groupdev,2);

                if ( $groupAndIpVal[1] ) {
                    my @ips = split(/,/,$groupAndIpVal[1]);
                    
                    my $checkip = new Net::IP($ENV{'REMOTE_ADDR'});
                    last CATEGORYCHECK if(! $checkip);
                    
                    my $ipcheck = 0;
                    my $ipchecked = 0;
                    foreach my $ip(@ips) {
                        $ip =~ s/^\s+// if ($ip);
                        $ip =~ s/\s+$// if ($ip);
                        
                        if ( $ip) {
                            $ipchecked = 1;
                            my $iprange = new Net::IP($ip);
                            if ( $iprange ) {
                                my $res = $iprange->overlaps($checkip);
                                if ( $res == $IP_B_IN_A_OVERLAP || $res == $IP_IDENTICAL ) {
                                   $ipcheck = 1;
                                }
                            }
                        }
                    }
                    
                    if ( $ipcheck == 0 && $ipchecked == 1  ) {
                        next CATEGORYCHECK;
                    }
                }
                
                if ( $groupAndIpVal[0] ) {
                    my @groups = split(/,/,$groupAndIpVal[0]);
                    foreach my $group(@groups) {
                        $group =~ s/^\s+// if ($group);
                        $group =~ s/\s+$// if ($group);
                        
                        if ( $group && lc($group) eq lc($patron->categorycode) ) {
                            $restrictedGroup = 1;
                            last CATEGORYCHECK;
                        }
                    }
                }
            }
        }
    }
	
	# we read the age to return the appropriate age level 
	# which is used by onleihe to provide appropriate material
	$age = $patron->get_age;
	
	# read the encrypted password
	$checkpw = $patron->password;
	
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
		my $non_issue_charges =
			$patron->account->non_issues_charges;

		my $num_overdues = $patron->has_overdues;
		
		if ( $restrictedGroup ) {
		    $response->{'status'} = -4; # patron category blocked for online materials lending
		}
		elsif ( $num_overdues && ( C4::Context->preference("OverduesBlockCirc") eq 'block' || C4::Context->preference("OverduesBlockCirc") eq 'confirmation' ) ) {
            $response->{'status'} = 1; # patron blocked due to overdues
		}
		elsif ( my $debarred_date = $patron->is_debarred ) {
            # patron has accrued fine days or has a restriction. $count is a date
            $response->{'status'} = 1; # patron debarred, no access
        }
		elsif ( $patron->is_expired ) {
			$response->{'status'} = -3; # account expired
		}
		elsif ( $patron->gonenoaddress && $patron->gonenoaddress == 1 ) {
			$response->{'status'} = 1; # patron has no valid address, no access
		}
		elsif ( $patron->lost && $patron->lost == 1 ) {
			$response->{'status'} = 1; # account expired (due to a lost card)
		}
		elsif ( $non_issue_charges > $amountlimit ) {
			$response->{'status'} = 4; # user debarred due to too much fines
		}
		elsif ( $patron->account_locked ) {
            $response->{'status'} = 1; # patron blocked because he/she/it has reached the maximum number of login attempts
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
	    
	    $response->{'cardid'} = $patron->cardnumber;
	    $response->{'userid'} = $patron->borrowernumber;
	    
	    $patron->update({ login_attempts => 0 });
	    $patron->track_login if ( C4::Context->preference('TrackLastPatronActivity') );
	}
	else {
		$response->{'status'} = -2; # wrong password
		$patron->update({ login_attempts => $patron->login_attempts + 1 });
	}
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

