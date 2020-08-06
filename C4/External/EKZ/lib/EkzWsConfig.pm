package C4::External::EKZ::lib::EkzWsConfig;

# Copyright 2020 (C) LMSCLoud GmbH
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

use utf8;
use Carp;
use Data::Dumper;

use C4::Context;

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

    $self->{'logger'} = Koha::Logger->get({ interface => 'C4::External::EKZ::lib::EkzWsConfig' });

    ## Get credentials of customer specific login at ekz for the other ekz web services from system preferences.
    ## Some libraries use different ekz Kundennummer for different branches; in this case the system preferences contain '|'-separated lists.
    my $ekzWebServicesCustomerNumber = C4::Context->preference('ekzWebServicesCustomerNumber');
    my $ekzWebServicesPassword = C4::Context->preference('ekzWebServicesPassword');
    my $ekzWebServicesUserName = C4::Context->preference('ekzWebServicesUserName');
    my $ekzProcessingNoticesEmailAddress = C4::Context->preference('ekzProcessingNoticesEmailAddress');
    my $ekzWebServicesDefaultBranch = C4::Context->preference('ekzWebServicesDefaultBranch');
    # for coupling to Koha acquisition (optional)
    my $ekzAqbooksellersId = C4::Context->preference('ekzAqbooksellersId');    # if empty then coupling to Koha acquisition is switched off
    my $ekzAqbudgetperiodsDescription = C4::Context->preference('ekzAqbudgetperiodsDescription');
    my $ekzAqbudgetsCode = C4::Context->preference('ekzAqbudgetsCode');

    if ( !defined($ekzWebServicesCustomerNumber) ) {
        my $mess = "ekzWebServicesCustomerNumber value not defined in system preferences";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    } else {
        $self->{'logger'}->debug("new() ekzWebServicesCustomerNumber:$ekzWebServicesCustomerNumber:");
    }
    if ( !defined($ekzWebServicesPassword) ) {
        my $mess = "ekzWebServicesPassword value not defined in system preferences";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    }
    if ( !defined($ekzWebServicesUserName) ) {
        my $mess = "ekzWebServicesUserName value not defined in system preferences";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    }
    if ( !defined($ekzProcessingNoticesEmailAddress) ) {
        my $mess = "ekzProcessingNoticesEmailAddress value not defined in system preferences";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    }
    if ( !defined($ekzWebServicesDefaultBranch) ) {
        my $mess = "ekzWebServicesDefaultBranch value not defined in system preferences";
        $self->{'logger'}->warn("new() $mess");
        carp "EkzWebServices::new(): " . $mess;
    }

    my @ekzWebServicesCustomerNumbers = split( /\|/, $ekzWebServicesCustomerNumber );
    my @ekzWebServicesPasswords = split( /\|/, $ekzWebServicesPassword );
    my @ekzWebServicesUserNames = split( /\|/, $ekzWebServicesUserName );
    my @ekzProcessingNoticesEmailAddresses = split( /\|/, $ekzProcessingNoticesEmailAddress );
    my @ekzWebServicesDefaultBranches = split( /\|/, $ekzWebServicesDefaultBranch );
    my @ekzAqbooksellersIds = split( /\|/, $ekzAqbooksellersId );
    my @ekzAqbudgetperiodsDescriptions = split( /\|/, $ekzAqbudgetperiodsDescription );
    my @ekzAqbudgetsCodes = split( /\|/, $ekzAqbudgetsCode );

    if ( defined($ekzProcessingNoticesEmailAddresses[0]) ){
        $self->{'fallBackEkzProcessingNoticesEmailAddress'} = $ekzProcessingNoticesEmailAddresses[0];
    } else {
        $self->{'fallBackEkzProcessingNoticesEmailAddress'} = '';
    }

    if ( defined($ekzWebServicesDefaultBranches[0]) ){
        $self->{'fallBackEkzWebServicesDefaultBranch'} = $ekzWebServicesDefaultBranches[0];
    } else {
        $self->{'fallBackEkzWebServicesDefaultBranch'} = '';
    }

    if ( defined($ekzAqbooksellersIds[0]) ){
        $self->{'fallBackEkzAqbooksellersId'} = $ekzAqbooksellersIds[0];
    } else {
        $self->{'fallBackEkzAqbooksellersId'} = '';    # undef and '' signals that coupling to Koha acquisition is switched off
    }

    my $ekzWebServicesCustomerNumbersCnt = scalar @ekzWebServicesCustomerNumbers;
    $self->{'logger'}->debug("new() ekzWebServicesCustomerNumbersCnt:$ekzWebServicesCustomerNumbersCnt:");
    $self->{'logger'}->trace("new() Dumper(ekzWebServicesCustomerNumbers):" . Dumper(@ekzWebServicesCustomerNumbers) . ":");

    for ( my $i = 0; $i < $ekzWebServicesCustomerNumbersCnt; $i += 1 ) {
        if ( defined($ekzWebServicesCustomerNumbers[$i]) && length($ekzWebServicesCustomerNumbers[$i]) ) {
            $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzKundenNr'} = $ekzWebServicesCustomerNumbers[$i];
            if ( defined($ekzWebServicesPasswords[$i]) && length($ekzWebServicesPasswords[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzPasswort'} = $ekzWebServicesPasswords[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzPasswort'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzPasswort'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzPasswort'} : 'UNDEFINED';
            }
            if ( defined($ekzWebServicesUserNames[$i]) && length($ekzWebServicesUserNames[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzLmsNutzer'} = $ekzWebServicesUserNames[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzLmsNutzer'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzLmsNutzer'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzLmsNutzer'} : 'UNDEFINED';
            }
            if ( defined($ekzProcessingNoticesEmailAddresses[$i]) && length($ekzProcessingNoticesEmailAddresses[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzProcessingNoticesEmailAddress'} = $ekzProcessingNoticesEmailAddresses[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzProcessingNoticesEmailAddress'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzProcessingNoticesEmailAddress'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzProcessingNoticesEmailAddress'} : 'UNDEFINED';
            }
            if ( defined($ekzWebServicesDefaultBranches[$i]) && length($ekzWebServicesDefaultBranches[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzWebServicesDefaultBranch'} = $ekzWebServicesDefaultBranches[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzWebServicesDefaultBranch'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzWebServicesDefaultBranch'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzWebServicesDefaultBranch'} : 'UNDEFINED';
            }
            if ( defined($ekzAqbooksellersIds[$i]) && length($ekzAqbooksellersIds[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzAqbooksellersId'} = $ekzAqbooksellersIds[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzAqbooksellersId'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzAqbooksellersId'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzAqbooksellersId'} : '';    # undef and '' signals that coupling to Koha acquisition is switched off
            }
            if ( defined($ekzAqbudgetperiodsDescriptions[$i]) && length($ekzAqbudgetperiodsDescriptions[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzAqbudgetperiodsDescription'} = $ekzAqbudgetperiodsDescriptions[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzAqbudgetperiodsDescription'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzAqbudgetperiodsDescription'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzAqbudgetperiodsDescription'} : '';
            }
            if ( defined($ekzAqbudgetsCodes[$i]) && length($ekzAqbudgetsCodes[$i]) ) {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzAqbudgetsCode'} = $ekzAqbudgetsCodes[$i];
            } else {
                $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}->{'ekzAqbudgetsCode'} = defined($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzAqbudgetsCode'}) ? $self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[0]}->{'ekzAqbudgetsCode'} : '';
            }
        }
        $self->{'logger'}->trace("new() Dumper(self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}):" . Dumper($self->{'ekzCustomerBranch'}->{$ekzWebServicesCustomerNumbers[$i]}) . ":");
    }

	return $self;
}

sub getEkzKundenNr {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzKundenNr'}) ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzKundenNr'};
        }
    }
    $self->{'logger'}->trace("getEkzKundenNr(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzPasswort {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzPasswort'}) ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzPasswort'};
        }
    }
    $self->{'logger'}->trace("getEkzPasswort(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzLmsNutzer {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = 'UNDEFINED';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzLmsNutzer'}) ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzLmsNutzer'};
        }
    }
    $self->{'logger'}->trace("getEkzLmsNutzer(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzProcessingNoticesEmailAddress {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = $self->{'fallBackEkzProcessingNoticesEmailAddress'};

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzProcessingNoticesEmailAddress'}) && $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzProcessingNoticesEmailAddress'} ne 'UNDEFINED' ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzProcessingNoticesEmailAddress'};
        }
    }
    $self->{'logger'}->trace("getEkzProcessingNoticesEmailAddress(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzWebServicesDefaultBranch {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = $self->{'fallBackEkzWebServicesDefaultBranch'};

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzWebServicesDefaultBranch'}) && $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzWebServicesDefaultBranch'} ne 'UNDEFINED' ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzWebServicesDefaultBranch'};
        }
    }
    $self->{'logger'}->trace("getEkzWebServicesDefaultBranch(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzAqbooksellersId {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = $self->{'fallBackEkzAqbooksellersId'};
    $self->{'logger'}->trace("getEkzAqbooksellersId(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") START");

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbooksellersId'}) && $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbooksellersId'} ne 'UNDEFINED' ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbooksellersId'};
        }
    }
    $self->{'logger'}->trace("getEkzAqbooksellersId(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzAqbudgetperiodsDescription {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = '';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbudgetperiodsDescription'}) && $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbudgetperiodsDescription'} ne 'UNDEFINED' ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbudgetperiodsDescription'};
        }
    }
    $self->{'logger'}->trace("getEkzAqbudgetperiodsDescription(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzAqbudgetsCode {
	my $self = shift;
    my $ekzCustomerNumber = shift;
    my $ret = '';

    if ( defined($ekzCustomerNumber) && length($ekzCustomerNumber) ) {
        if ( defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}) && defined($self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbudgetsCode'}) && $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbudgetsCode'} ne 'UNDEFINED' ) {
            $ret = $self->{'ekzCustomerBranch'}->{$ekzCustomerNumber}->{'ekzAqbudgetsCode'};
        }
    }
    $self->{'logger'}->trace("getEkzAqbudgetsCode(ekzCustomerNumber:" . (defined($ekzCustomerNumber) ? $ekzCustomerNumber : 'undef') . ") returns ret:$ret:");
    return $ret;
}

sub getEkzCustomerNumbers {
	my $self = shift;

    my @ekzWebServicesCustomerNumbers = keys %{$self->{'ekzCustomerBranch'}};

    return @ekzWebServicesCustomerNumbers;
}

1;
