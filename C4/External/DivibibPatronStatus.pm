package C4::External::DivibibPatronStatus;

# Copyright 2021 LMSCloud GmbH
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

use Clone 'clone';
use Net::IP;

use C4::Context;
use C4::Auth qw(&checkpw_hash);

use Koha::Patrons;
use Koha::AuthUtils qw(hash_password);

sub new {
    my $class = shift;
    my $borrowernumber = shift;
    my $password = shift;

    my $self = {};
    bless $self, $class;
    
    $self->{defaultResponse} = {
                              'status'   => -1, # wrong login-data (user or password)    # mandatory
                              'fsk'      => 0,                                           # mandatory
                              'cardid'   => '',                                          # mandatory
                              'userid'   => ''                                           # mandatory
                            };
                            
    $self->{patronResponse} = {
                              'status'   => -1, # wrong login-data (user or password)    # mandatory
                              'fsk'      => 0,                                           # mandatory
                              'cardid'   => '',                                          # mandatory
                              'userid'   => ''                                           # mandatory
                            };
    
    $self->{patron} = undef;
    if ( $borrowernumber && $password ) {
        my ($patron, $age, $checkpw);
        
        # Check the patron with the internal borrower number
        $patron = Koha::Patrons->find( $borrowernumber );
        if ( $patron ) {
            $checkpw = $patron->password;
            if (!($checkpw eq $password || &checkpw_hash($password,$checkpw)) ) {
                $self->{patronResponse}->{'status'} = -2; # wrong password
                $patron->update({ login_attempts => $patron->login_attempts + 1 });
                $patron = undef;
            }
            else {
                $self->{patronResponse}->{'status'} = 3; # online user access permitted
                $patron->update({ login_attempts => 0 });
                $patron->track_login if ( C4::Context->preference('TrackLastPatronActivity') );
            }
        }

        # if we did not find the patron by borrowernumber, we check with
        # users' barcode instead
        if (! $patron ) { 
            $patron = Koha::Patrons->find({ cardnumber => $borrowernumber} );
            if ( $patron ) {
                $checkpw = $patron->password;
                if (!($checkpw eq $password || &checkpw_hash($password,$checkpw)) ) {
                    $self->{patronResponse}->{'status'} = -2; # wrong password
                    $patron->update({ login_attempts => $patron->login_attempts + 1 });
                    $patron = undef;
                }
                else {
                    $self->{patronResponse}->{'status'} = 3; # online user access permitted
                    $patron->update({ login_attempts => 0 });
                    $patron->track_login if ( C4::Context->preference('TrackLastPatronActivity') );
                }
            }
        }

        # finally lets test the userid 
        if (! $patron ) { 
            $patron = Koha::Patrons->find({ userid => $borrowernumber} );
            if ( $patron ) {
                # read the encrypted password
                $checkpw = $patron->password;
                
                if ( $checkpw eq $password || &checkpw_hash($password,$checkpw) ) {
                    $self->{patronResponse}->{'status'} = 3; # online user access permitted
                    $patron->update({ login_attempts => 0 });
                    $patron->track_login if ( C4::Context->preference('TrackLastPatronActivity') );
                } else {
                    $self->{patronResponse}->{'status'} = -2; # wrong password
                    $patron->update({ login_attempts => $patron->login_attempts + 1 });
                    $patron = undef;
                }
            }
        }
        
        $self->{patron} = $patron;
    }
 
    return $self;   
}

sub getPatron {
    my $self = shift;
    return $self->{patron};
}

sub getPatronStatus {
    my $self   = shift;
    my $patron = shift;
    
    my $response = clone($self->{defaultResponse});
    
    if ( !$patron ) {
        $patron = $self->{patron};
        $response = clone($self->{patronResponse});
    } else {
        $response->{'status'} = 3; # online user access permitted
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
        my $age = $patron->get_age;
        
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
        
    }
    
    return $response;
}

1;

