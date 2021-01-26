#!/usr/bin/perl -w

# Copyright 2017-2021 (C) LMSCLoud GmbH
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
use Data::Dumper;

use C4::External::EKZ::lib::EkzWsConfig;
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::EkzWsDeliveryNote qw( readLSFromEkzWsLieferscheinList readLSFromEkzWsLieferscheinDetail genKohaRecords );
use Koha::Logger;


binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );


my $lastRunDate;
my $yesterdayDate;

my $testMode = 0;    # 0 or 1 or 2
my $genKohaRecords = 1;    # 0 or 1
my $result;
my $lieferscheinDetailElement = '';    # for storing the LieferscheinDetailElement of the SOAP response body

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $startTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d",1900+$year,1+$mon,$mday,$hour,$min,$sec);
my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ' });

$logger->info("ekzWsDeliveryNote.pl START starttime:$startTime:");

$lastRunDate = C4::External::EKZ::lib::EkzWebServices::getLastRunDate('LieferscheinDetail', 'E');    # value for 'von' / 'from', required in european form dd.mm.yyyy
if ( !defined($lastRunDate) || length($lastRunDate) == 0 ) {
    $lastRunDate = `date +%d.%m.%C%y`;    # this will result in an empty hit list, because !($lastRunDate <= $yesterdayDate)
    chomp($lastRunDate);
}
$yesterdayDate = `date -d "1 day ago" +%d.%m.%C%y`;                                                  # value for 'bis' / 'until', required in european form dd.mm.yyyy
chomp($yesterdayDate);
$logger->info("ekzWsDeliveryNote.pl modified lastRunDate:$lastRunDate: yesterdayDate:$yesterdayDate:");

if ( $testMode == 1 ) {
    # some libraries use different ekz Kundennummer for different branches, so we have to call the delivery note synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        my $von = "01.08.2016";
        $logger->info("ekzWsDeliveryNote.pl read lieferscheinList von:$von: by calling readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$von,undef,undef)");
        my $lsList = &readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$von,undef,undef);

        foreach my $lieferschein ( @{$lsList->{'lieferscheinRecords'}} ) {
            $logger->info("ekzWsDeliveryNote.pl read delivery note via id:" . $lieferschein->{id} . ": by calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber," . $lieferschein->{id} . ",undef,\\\$lieferscheinDetailElement)");
            my $result = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,$lieferschein->{id},undef,\$lieferscheinDetailElement);
            $logger->debug("ekzWsDeliveryNote.pl Dumper(\$result->{'lieferscheinRecords'}->[0]):" . Dumper($result->{'lieferscheinRecords'}->[0]) . ":");

            $logger->info("ekzWsDeliveryNote.pl read delivery note via lieferscheinnummer:" . $lieferschein->{nummer} . ": by calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef," . $lieferschein->{nummer} . ",\\\$lieferscheinDetailElement)");
            $result = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef,$lieferschein->{nummer},\$lieferscheinDetailElement);
            $logger->debug("ekzWsDeliveryNote.pl Dumper(\$result->{'lieferscheinRecords'}->[0]):" . Dumper($result->{'lieferscheinRecords'}->[0]) . ":");
        }
    }
}

if ( $testMode == 2 ) {
    my $res = 0;

    # some libraries use different ekz Kundennummer for different branches, so we have to call the delivery note synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        if ( $ekzCustomerNumber ne '1109403' ) {
            next;
        }

        my $von = "01.01.2020";
        $logger->info("ekzWsDeliveryNote.pl read lieferscheinList von:$von: by calling readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$von,undef,undef)");
        my $lsList = &readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$von,undef,undef);

        foreach my $lieferschein ( @{$lsList->{'lieferscheinRecords'}} ) {
            $logger->info("ekzWsDeliveryNote.pl lieferschein->{id}:" . $lieferschein->{id} . ": lieferschein->{nummer}:" . $lieferschein->{nummer} . ":");
            if ( $lieferschein->{id} ne '1883889' ) {
                next;
            }

            $logger->info("ekzWsDeliveryNote.pl read delivery note via id:" . $lieferschein->{id} . ": by calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber," . $lieferschein->{id} . ",\\\$lieferscheinDetailElement)");
            my $result = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,$lieferschein->{id},undef,\$lieferscheinDetailElement);    # read *complete* info (i.e. all titles) of the delivery note
            $logger->debug("ekzWsDeliveryNote.pl Dumper(\$result->{'lieferscheinRecords'}->[0]):" . Dumper($result->{'lieferscheinRecords'}->[0]) . ":");

#            $logger->info("ekzWsDeliveryNote.pl read delivery note via lieferscheinnummer:" . $lieferschein->{nummer} . ": by calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef," . $lieferschein->{nummer} . ",\\\$lieferscheinDetailElement)");
#            $result = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef,$lieferschein->{nummer},\$lieferscheinDetailElement);
#            $logger->debug("ekzWsDeliveryNote.pl Dumper(\$result->{'lieferscheinRecords'}->[0]):" . Dumper($result->{'lieferscheinRecords'}->[0]) . ":");

            if ( $genKohaRecords ) {
                if ( $result->{'lieferscheinCount'} > 0 ) {
                    if ( &genKohaRecords($ekzCustomerNumber, $result->{'messageID'}, $lieferscheinDetailElement,$result->{'lieferscheinRecords'}->[0]) ) {
                        $res = 1;
                    }
                }
            }
        }
    }
}

#generate the biblio, biblioitems, items, acquisition_import and acquisition_import_object records analogue to BestellInfo
if ( $testMode == 0 ) {
    my $res = 0;

    # some libraries use different ekz Kundennummer for different branches, so we have to call the delivery note synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWebServices->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        # read all new delivery notes since $lastRunDate until including yesterday
        $logger->info("ekzWsDeliveryNote.pl read delivery notes from lastRunDate:$lastRunDate to yesterdayDate:$yesterdayDate: by calling readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$lastRunDate,$yesterdayDate,undef)");
        my $lsList = &readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$lastRunDate,$yesterdayDate,undef);
        
        foreach my $lieferschein ( @{$lsList->{'lieferscheinRecords'}} ) {
            $logger->info("ekzWsDeliveryNote.pl read delivery note via lieferscheinnummer:" . $lieferschein->{nummer} . ": by calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef," . $lieferschein->{nummer} . ",\\\$lieferscheinDetailElement)");
            $result = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef,$lieferschein->{nummer},\$lieferscheinDetailElement);    # read *complete* info (i.e. all titles) of the delivery note

            $logger->debug("ekzWsDeliveryNote.pl Dumper(\$result->{'lieferscheinRecords'}->[0]):" . Dumper($result->{'lieferscheinRecords'}->[0]) . ":");
            if ( $genKohaRecords ) {
                if ( $result->{'lieferscheinCount'} > 0 ) {
                    if ( &genKohaRecords($ekzCustomerNumber, $result->{'messageID'}, $lieferscheinDetailElement,$result->{'lieferscheinRecords'}->[0]) ) {
                        $res = 1;
                    }
                }
            }
        }
    }
    if ( $res == 1 ) {
        C4::External::EKZ::lib::EkzWebServices::setLastRunDate('LieferscheinDetail', DateTime->now(time_zone => 'local'));
    }

}

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $endTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d",1900+$year,1+$mon,$mday,$hour,$min,$sec);
$logger->info("ekzWsDeliveryNote.pl END endTime:$endTime:");
