#!/usr/bin/perl -w

# Copyright 2021 (C) LMSCLoud GmbH
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

use C4::External::EKZ::EkzWsSerialOrder qw( readSerialOrdersFromEkzWsFortsetzungList readSerialOrderFromEkzWsFortsetzungDetail genKohaRecords );
use Koha::Logger;


binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );


my $lastRunDate;
my $todayDate;
my $yesterdayDate;

my $testMode = 0;    # 0 or 1 or 2
my $genKohaRecords = 1;    # 0 or 1
my $result;
my $fortsetzungDetailElement = '';    # for storing the FortsetzungDetailElement of the SOAP response body in DB table acquisition_import

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $startTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d",1900+$year,1+$mon,$mday,$hour,$min,$sec);
my $logger = Koha::Logger->get({ interface => 'C4::External::EKZ' });

$logger->info("ekzWsSerialOrder.pl START starttime:$startTime:");
$lastRunDate = C4::External::EKZ::lib::EkzWebServices::getLastRunDate('FortsetzungDetail', 'E');    # value for 'von' / 'from', required in european form dd.mm.yyyy XXXWH
if ( !defined($lastRunDate) || length($lastRunDate) == 0 ) {
    $lastRunDate = `date +%d.%m.%C%y`;    # this will result in an empty hit list, because !($lastRunDate <= $yesterdayDate)
    chomp($lastRunDate);
}
$todayDate = `date +%Y-%m-%d`;
chomp($todayDate);
$yesterdayDate = `date -d "1 day ago" +%d.%m.%C%y`;                                                  # value for 'bis' / 'until', required in european form dd.mm.yyyy
chomp($yesterdayDate);
$logger->info("ekzWsSerialOrder.pl modified lastRunDate:$lastRunDate: yesterdayDate:$yesterdayDate:");

if ( $testMode == 1 ) {
    # some libraries use different ekz Kundennummer for different branches, so we have to call the serial order synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        #my $selVonDatum = "01.08.2020";    # ekz ERROR: any real date results in empty hit list
        #my $selBisDatum = "31.12.2020";    # XXXWH ekz ERROR: any real date results in empty hit list
        my $selVonDatum = undef;    # ekz ERROR: any real date results in empty hit list
        my $selBisDatum = undef;    # XXXWH ekz ERROR: any real date results in empty hit list
        $logger->info("ekzWsSerialOrder.pl read fortsetzungList selVonDatum:$selVonDatum: selBisDatum:$selBisDatum: by calling readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,$selVonDatum,$selBisDatum)");
        my $serList = &readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,$selVonDatum,$selBisDatum);

        if ( $serList->{'fortsetzungStatusRecords'} && $serList->{'fortsetzungStatusRecords'}->{inProgress} && $serList->{'fortsetzungStatusRecords'}->{inProgress}->{fortsetzungVariante} ) {
            foreach my $fortsetzungVariante ( @{$serList->{'fortsetzungStatusRecords'}->{inProgress}->{fortsetzungVariante}} ) {
                $logger->info("ekzWsSerialOrder.pl loop fortsetzungVariante artikelArt:$fortsetzungVariante->{artikelArt}:");
                foreach my $fortsetzungRubrik ( @{$fortsetzungVariante->{fortsetzungRubrik}} ) {
                    $logger->info("ekzWsSerialOrder.pl loop fortsetzungRubrik rubrik:$fortsetzungRubrik->{rubrik}:");
                    foreach my $fortsetzungTitel ( @{$fortsetzungRubrik->{'fortsetzungTitel'}} ) {
                        $logger->info("ekzWsSerialOrder.pl loop fortsetzungTitel artikelnum:$fortsetzungTitel->{artikelnum}: artikelname:$fortsetzungTitel->{artikelname}: fortsetzungsAuftragsNummer:$fortsetzungTitel->{fortsetzungsAuftragsNummer}:");
                        
                        $logger->info("ekzWsSerialOrder.pl read serial order via fortsetzungsId:" . $fortsetzungTitel->{artikelnum} . ": by calling readSerialOrderFromEkzWsFortsetzungDetail($ekzCustomerNumber," . $fortsetzungTitel->{artikelnum} . ",undef,undef,undef,1,undef)");
                        $result = &readSerialOrderFromEkzWsFortsetzungDetail($ekzCustomerNumber,$fortsetzungTitel->{artikelnum},undef,undef,undef,1,undef);
                        $logger->debug("ekzWsSerialOrder.pl Dumper(\$result->{'fortsetzungRecords'}->[0]):" . Dumper($result->{'fortsetzungRecords'}->[0]) . ":");
                    }
                }
            }
        }
    }
}

if ( $testMode == 2 ) {
    my $res = 0;

    # some libraries use different ekz Kundennummer for different branches, so we have to call the serial order synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        if ( $ekzCustomerNumber ne '1109403' ) {
            next;
        }
        #my $selVonDatum = "01.08.2020";    # XXXWH ekz ERROR: any real date results in empty hit list
        #my $selBisDatum = "31.12.2020";    # XXXWH ekz ERROR: any real date results in empty hit list
        my $selVonDatum = undef;    # XXXWH ekz ERROR: any real date results in empty hit list
        my $selBisDatum = undef;    # XXXWH ekz ERROR: any real date results in empty hit list

        $logger->info("ekzWsSerialOrder.pl read fortsetzungList selVonDatum:$selVonDatum: selBisDatum:$selBisDatum: by calling readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,$selVonDatum,$selBisDatum)");
        my $serList = &readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,$selVonDatum,$selBisDatum);

        if ( $serList->{'fortsetzungStatusRecords'} && $serList->{'fortsetzungStatusRecords'}->{inProgress} && $serList->{'fortsetzungStatusRecords'}->{inProgress}->{fortsetzungVariante} ) {
            foreach my $fortsetzungVariante ( @{$serList->{'fortsetzungStatusRecords'}->{inProgress}->{fortsetzungVariante}} ) {
                $logger->info("ekzWsSerialOrder.pl loop fortsetzungVariante artikelArt:$fortsetzungVariante->{artikelArt}:");
                foreach my $fortsetzungRubrik ( @{$fortsetzungVariante->{fortsetzungRubrik}} ) {
                    $logger->info("ekzWsSerialOrder.pl loop fortsetzungRubrik rubrik:$fortsetzungRubrik->{rubrik}:");

                    foreach my $fortsetzungTitel ( @{$fortsetzungRubrik->{'fortsetzungTitel'}} ) {
                        $logger->info("ekzWsSerialOrder.pl loop fortsetzungTitel artikelnum:$fortsetzungTitel->{artikelnum}: artikelname:$fortsetzungTitel->{artikelname}: fortsetzungsAuftragsNummer:$fortsetzungTitel->{fortsetzungsAuftragsNummer}:");
                        #if ( $fortsetzungTitel->{artikelnum} ne '0587490' ) {    # 'kompletterWerksName' => 'ENTENHAUSEN-EDTION DONALD' 'herausgeber' => 'EGMONT VERL.GES'
                        if ( $fortsetzungTitel->{artikelnum} ne '0513230' ) {    # 'kompletterWerksName' => 'BILDERMAUS' 'herausgeber' => 'LOEWE'
                            next;
                        }

                        $logger->info("ekzWsSerialOrder.pl read serial order via fortsetzungsId:" . $fortsetzungTitel->{artikelnum} . ": by calling readSerialOrderFromEkzWsFortsetzungDetail($ekzCustomerNumber," . $fortsetzungTitel->{artikelnum} . ",undef,undef,undef,1,\\\$fortsetzungDetailElement)");
                        $result = &readSerialOrderFromEkzWsFortsetzungDetail($ekzCustomerNumber,$fortsetzungTitel->{artikelnum},undef,undef,undef,1,\$fortsetzungDetailElement);    # read complete info (i.e. all titles) of the serial order
                        $logger->debug("ekzWsSerialOrder.pl Dumper(\$result->{'fortsetzungRecords'}->[0]):" . Dumper($result->{'fortsetzungRecords'}->[0]) . ":");

                        if ( $genKohaRecords ) {
                            if ( $result->{fortsetzungRecords}->[0] &&
                                 $result->{fortsetzungRecords}->[0]->{fortsetzungDetailStatusRecords} &&
                                 $result->{fortsetzungRecords}->[0]->{fortsetzungDetailStatusRecords}->{alreadyPlanned} &&
                                 $result->{fortsetzungRecords}->[0]->{fortsetzungDetailStatusRecords}->{alreadyPlanned}->{fortsetzungDetailStatus} ) {

                                # XXXWH ekz ERROR: at the moment there is no statusdatum sent, so we can not compare with $lastRunDate => use undef instead
                                #if ( &genKohaRecords($ekzCustomerNumber, $result->{fortsetzungRecords}->[0]->{messageID}, $fortsetzungDetailElement, $result->{fortsetzungRecords}->[0], $lastRunDate, $todayDate) ) {
                                if ( &genKohaRecords($ekzCustomerNumber, $result->{fortsetzungRecords}->[0]->{messageID}, $fortsetzungDetailElement, $result->{fortsetzungRecords}->[0], undef, $todayDate) ) {
                                    $res = 1;
                                }
                            }
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

    # some libraries use different ekz Kundennummer for different branches, so we have to call the serial order synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        # read all serial orders ordered since lastRunDate
        # XXXWH 'von' selection results in empty list $logger->info("ekzWsSerialOrder.pl read fortsetzungList since lastRunDate:$lastRunDate: by calling readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,$lastRunDate,undef)");
        # XXXWH 'von' selection results in empty list my $serList = &readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,$lastRunDate,undef);

        # XXXWH ekz ERROR: any real date in von/bis-Selection results in empty hit list, so we use undef
        $logger->info("ekzWsSerialOrder.pl read fortsetzungList NOT since lastRunDate:$lastRunDate BUT ALL: by calling readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,undef,undef)");
        my $serList = &readSerialOrdersFromEkzWsFortsetzungList ($ekzCustomerNumber,undef,undef);

        if ( $serList->{'fortsetzungStatusRecords'} && $serList->{'fortsetzungStatusRecords'}->{inProgress} && $serList->{'fortsetzungStatusRecords'}->{inProgress}->{fortsetzungVariante} ) {
            foreach my $fortsetzungVariante ( @{$serList->{'fortsetzungStatusRecords'}->{inProgress}->{fortsetzungVariante}} ) {
                $logger->info("ekzWsSerialOrder.pl loop fortsetzungVariante artikelArt:$fortsetzungVariante->{artikelArt}:");
                foreach my $fortsetzungRubrik ( @{$fortsetzungVariante->{fortsetzungRubrik}} ) {
                    $logger->info("ekzWsSerialOrder.pl loop fortsetzungRubrik rubrik:$fortsetzungRubrik->{rubrik}:");
                    foreach my $fortsetzungTitel ( @{$fortsetzungRubrik->{'fortsetzungTitel'}} ) {
                        $logger->info("ekzWsSerialOrder.pl loop fortsetzungTitel artikelnum:$fortsetzungTitel->{artikelnum}: artikelname:$fortsetzungTitel->{artikelname}: fortsetzungsAuftragsNummer:$fortsetzungTitel->{fortsetzungsAuftragsNummer}:");

                        $logger->info("ekzWsSerialOrder.pl read serial order via fortsetzungsId:" . $fortsetzungTitel->{artikelnum} . ": by calling readSerialOrderFromEkzWsFortsetzungDetail($ekzCustomerNumber," . $fortsetzungTitel->{artikelnum} . ",undef,undef,undef,1,\\\$fortsetzungDetailElement)");
                        $result = &readSerialOrderFromEkzWsFortsetzungDetail($ekzCustomerNumber,$fortsetzungTitel->{artikelnum},undef,undef,undef,1,\$fortsetzungDetailElement);    # read complete info (i.e. all titles) of the serial order
                        $logger->debug("ekzWsSerialOrder.pl Dumper(\$result->{'fortsetzungRecords'}->[0]):" . Dumper($result->{'fortsetzungRecords'}->[0]) . ":");

                        if ( $genKohaRecords ) {
                            if ( $result->{'fortsetzungCount'} > 0 &&
                                 $result->{fortsetzungRecords}->[0] &&
                                 $result->{fortsetzungRecords}->[0]->{fortsetzungDetailStatusRecords} &&
                                 $result->{fortsetzungRecords}->[0]->{fortsetzungDetailStatusRecords}->{alreadyPlanned} &&
                                 $result->{fortsetzungRecords}->[0]->{fortsetzungDetailStatusRecords}->{alreadyPlanned}->{fortsetzungDetailStatus} ) {

                                # XXXWH ekz ERROR: at the moment there is no statusdatum sent, so we can not compare with $lastRunDate => use undef instead
                                #if ( &genKohaRecords($ekzCustomerNumber, $result->{fortsetzungRecords}->[0]->{messageID}, $fortsetzungDetailElement, $result->{fortsetzungRecords}->[0], $lastRunDate, $todayDate) ) {
                                if ( &genKohaRecords($ekzCustomerNumber, $result->{fortsetzungRecords}->[0]->{messageID}, $fortsetzungDetailElement, $result->{fortsetzungRecords}->[0], undef, $todayDate) ) {
                                    $res = 1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if ( $res == 1 ) {
        C4::External::EKZ::lib::EkzWebServices::setLastRunDate('FortsetzungDetail', DateTime->now(time_zone => 'local'));
    }
}

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $endTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d",1900+$year,1+$mon,$mday,$hour,$min,$sec);
$logger->info("ekzWsSerialOrder.pl END endTime:$endTime:");
