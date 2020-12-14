#!/usr/bin/perl -w

# Copyright 2017-2020 (C) LMSCLoud GmbH
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
use C4::External::EKZ::EkzWsStandingOrder qw( getCurrentYear readStoFromEkzWsStoList addReferenznummerToObjectItemNumber genKohaRecords );
use Koha::Logger;


binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );


my $currentYear;
my $lastRunDate;
my $todayDate;

my $testMode = 0;    # 0 or 1 or 2
my $addReferenznummer = 1;    # 0 or 1
my $genKohaRecords = 1;    # 0 or 1
my $result;
my $stoListElement = '';    # for storing the StoListElement of the SOAP response body

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $startTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d",1900+$year,1+$mon,$mday,$hour,$min,$sec);
my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ' });

$logger->info("ekzWsStandingOrder.pl START starttime:$startTime:");

$currentYear = &getCurrentYear();
$lastRunDate = C4::External::EKZ::lib::EkzWebServices::getLastRunDate('StoList', 'A');    # value for 'von' / 'from', required in american form yyyy-mm-dd
$todayDate = `date +%Y-%m-%d`;
chomp($todayDate);

$logger->info("ekzWsStandingOrder.pl currentYear:$currentYear: lastRunDate:$lastRunDate: todayDate:$todayDate:");

if ( $testMode == 1 ) {
    my $selYear = '2020';
    my $selStatusDatum = '2020-12-01';
    # some libraries use different ekz Kundennummer for different branches, so we have to call the standing order synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        # read all stoIDs of year $selYear
        $logger->info("ekzWsStandingOrder.pl read STO of year $selYear; calling readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,undef,false,false,false,undef,undef,undef,undef)");
        my $stoOfSelYear = &readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,undef,'false','false','false',undef,undef,undef,undef);
        $logger->info("ekzWsStandingOrder.pl count of standingOrderRecords:" . scalar @{$stoOfSelYear->{'standingOrderRecords'}} . ":");

        foreach my $sto (@{$stoOfSelYear->{'standingOrderRecords'}} ) {
            $logger->info("ekzWsStandingOrder.pl read StoId $sto->{stoID}: calling readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,$sto->{stoID},true,true,true,$selStatusDatum,'true','true',undef)");
            &readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,$sto->{stoID},'true','true','true',$selStatusDatum,'true','true',undef);
        }
    }
}


if ( $testMode == 2 ) {
    my $res = 0;

    my $selYear = '2020';
    my $selStatusDatum = '2020-12-01';
    # some libraries use different ekz Kundennummer for different branches, so we have to call the standing order synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        if ( $ekzCustomerNumber ne '1109403' ) {
            next;
        }
        # read all stoIDs of year $selYear
        $logger->info("ekzWsStandingOrder.pl read STO of year $selYear; calling readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,undef,false,false,false,undef,undef,undef,undef)");
        my $stoOfSelYear = &readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,undef,'false','false','false',undef,undef,undef,undef);
        $logger->info("ekzWsStandingOrder.pl count of standingOrderRecords:" . scalar @{$stoOfSelYear->{'standingOrderRecords'}} . ":");

        foreach my $sto (@{$stoOfSelYear->{'standingOrderRecords'}} ) {
            $logger->info("ekzWsStandingOrder.pl sto->{stoID}:" . $sto->{stoID} . ":");
            if ( $sto->{stoID} == 408 ) {
#            if ( $sto->{stoID} == 955 ) {

                $logger->info("ekzWsStandingOrder.pl read StoId:$sto->{stoID}: read complete info; calling readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,$sto->{stoID},true,true,true,undef,'true','true',\\\$stoListElement)");
                $result = &readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,$sto->{stoID},'true','true','true',undef,'true','true',\$stoListElement);      # read *complete* info (i.e. all titles, even without new status) of the standing order

                if ( $addReferenznummer ) {
                    if ( $result->{'standingOrderCount'} > 0 ) {
                        &addReferenznummerToObjectItemNumber($ekzCustomerNumber, $result->{'messageID'}, $stoListElement, $result->{'standingOrderRecords'}->[0], $selStatusDatum, $todayDate);
                    }
                }

                $logger->info("ekzWsStandingOrder.pl read StoId:$sto->{stoID}: state changes since lastRunDate:$selStatusDatum; calling readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,$sto->{stoID},true,true,true,$selStatusDatum,'true','true',undef)");
                $result = &readStoFromEkzWsStoList ($ekzCustomerNumber,$selYear,$sto->{stoID},'true','true','true',$selStatusDatum,'true','true',undef);       # read titles with modified state of the standig order 
                $logger->debug("ekzWsStandingOrder.pl Dumper(result->{'standingOrderRecords'}->[0]:" . Dumper($result->{'standingOrderRecords'}->[0]) . ":");

                if ( $genKohaRecords ) {
                    if ( $result->{'standingOrderCount'} > 0 ) {
                        if ( &genKohaRecords($ekzCustomerNumber, $result->{'messageID'}, $stoListElement, $result->{'standingOrderRecords'}->[0], $selStatusDatum, $todayDate) ) {
                            $res = 1;
                        }
                    }
                }

            }
        }
    }
}

#generate the biblio, biblioitems, items, acquisition_import and acquisition_import_object records as in BestellInfo
if ( $testMode == 0 ) {
    my $res = 0;

    # some libraries use different ekz Kundennummer for different branches, so we have to call the standing order synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        # read all stoIDs of current year
        $logger->info("ekzWsStandingOrder.pl read STO of year:$currentYear: by calling readStoFromEkzWsStoList ($ekzCustomerNumber,$currentYear,undef,false,false,false,undef,undef,undef,undef)");
        my $stoOfYear = &readStoFromEkzWsStoList ($ekzCustomerNumber,$currentYear,undef,'false','false','false',undef,undef,undef,undef);
        
        foreach my $sto ( @{$stoOfYear->{'standingOrderRecords'}} ) {
            $logger->info("ekzWsStandingOrder.pl read StoId:$sto->{stoID}: read complete info; calling readStoFromEkzWsStoList ($ekzCustomerNumber,$currentYear,$sto->{stoID},true,true,true,undef,'true','true',\\\$stoListElement)");
            $result = &readStoFromEkzWsStoList ($ekzCustomerNumber,$currentYear,$sto->{stoID},'true','true','true',undef,'true','true',\$stoListElement);    # read *complete* info (i.e. all titles, even without new status) of the standing order

            if ( $addReferenznummer ) {
                if ( $result->{'standingOrderCount'} > 0 ) {
                    &addReferenznummerToObjectItemNumber($ekzCustomerNumber, $result->{'messageID'}, $stoListElement, $result->{'standingOrderRecords'}->[0], $lastRunDate, $todayDate);
                }
            }
            $logger->info("ekzWsStandingOrder.pl read StoId:" . $sto->{stoID} . ": state changes since lastRunDate:$lastRunDate: by calling readStoFromEkzWsStoList ($ekzCustomerNumber,$currentYear," . $sto->{stoID} . ",true,true,true,$lastRunDate,true,true,undef)");
            $result = &readStoFromEkzWsStoList ($ekzCustomerNumber,$currentYear,$sto->{stoID},'true','true','true',$lastRunDate,'true','true',undef);        # read titles with modified state of the standig order 
            $logger->debug("ekzWsStandingOrder.pl Dumper(result->{'standingOrderRecords'}->[0]:" . Dumper($result->{'standingOrderRecords'}->[0]) . ":");

            if ( $genKohaRecords ) {
                if ( $result->{'standingOrderCount'} > 0 ) {
                    if ( &genKohaRecords($ekzCustomerNumber, $result->{'messageID'}, $stoListElement, $result->{'standingOrderRecords'}->[0], $lastRunDate, $todayDate) ) {
                        $res = 1;
                    }
                }
            }
        }
    }
    if ( $res == 1 ) {
        C4::External::EKZ::lib::EkzWebServices::setLastRunDate('StoList', DateTime->now(time_zone => 'local'));
    }
}

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $endTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d",1900+$year,1+$mon,$mday,$hour,$min,$sec);
$logger->info("ekzWsStandingOrder.pl END endTime:$endTime:");

