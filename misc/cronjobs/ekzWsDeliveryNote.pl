#!/usr/bin/perl -w

# Copyright 2017 (C) LMSCLoud GmbH
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

use C4::External::EKZ::EkzWsDeliveryNote qw( readLSFromEkzWsLieferscheinList readLSFromEkzWsLieferscheinDetail genKohaRecords );


binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );



my $debugIt = 1;

my $lastRunDate;
my $yesterdayDate;

my $simpleTest=0;
my $genKohaRecords = 1;
my $result;
my $lieferscheinDetailElement = '';    # for storing the LieferscheinDetailElement of the SOAP response body

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $startTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d\n",1900+$year,1+$mon,$mday,$hour,$min,$sec);

print STDERR "ekzWsLieferschein Start:$startTime\n" if $debugIt;

$lastRunDate = C4::External::EKZ::lib::EkzWebServices::getLastRunDate('LieferscheinDetail', 'E');    # value for 'von' / 'from', required in european form dd.mm.yyyy
if ( !defined($lastRunDate) || length($lastRunDate) == 0 ) {
    $lastRunDate = `date +%d.%m.%C%y`;    # this will result in an empty hit list, because !($lastRunDate <= $yesterdayDate)
    chomp($lastRunDate);
}
$yesterdayDate = `date -d "1 day ago" +%d.%m.%C%y`;                                                  # value for 'bis' / 'until', required in european form dd.mm.yyyy
chomp($yesterdayDate);

if ( $simpleTest ) {
    # some libraries use different ekz Kundennummer for different branches, so we have to call the delivery note synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWebServices->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        my $von = "01.08.2016";
        print STDERR "ekzWsLieferschein read lieferscheinList von:$von; calling readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$von,undef,undef)\n" if $debugIt;
        my $lsListe = &readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$von,undef,undef);

        foreach my $lieferschein ( @{$lsListe->{'lieferscheinRecords'}} ) {
            print STDERR "ekzWsLieferschein read lieferschein via id:$lieferschein->{id}: calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,$lieferschein->{id},undef)\n" if $debugIt;
            my $lsListe = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,$lieferschein->{id},undef);
            print STDERR "ekzWsLieferschein read lieferschein via lieferscheinnummer:$lieferschein->{nummer}: calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef,$lieferschein->{nummer})\n" if $debugIt;
            $lsListe = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef,$lieferschein->{nummer});
        }
    }
}

#generate the biblio, biblioitems, items, acquisition_import and acquisition_import_object records analogue to BestellInfo
if ( $genKohaRecords ) {
    my $res = 0;

    # some libraries use different ekz Kundennummer for different branches, so we have to call the delivery note synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWebServices->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        # read all new delivery notes since $lastRunDate until including yesterday
        print STDERR "ekzWsLieferschein read delivery notes since:$lastRunDate to:$yesterdayDate; calling readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$lastRunDate,$yesterdayDate,undef)\n" if $debugIt;
        my $lsListe = &readLSFromEkzWsLieferscheinList ($ekzCustomerNumber,$lastRunDate,$yesterdayDate,undef);
        
        foreach my $lieferschein ( @{$lsListe->{'lieferscheinRecords'}} ) {
            print STDERR "ekzWsLieferschein read lieferschein via lieferscheinnummer:$lieferschein->{nummer}: calling readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef,$lieferschein->{nummer})\n" if $debugIt;
            $result = &readLSFromEkzWsLieferscheinDetail($ekzCustomerNumber,undef,$lieferschein->{nummer},\$lieferscheinDetailElement);    # read *complete* info (i.e. all titles) of the delivery note

print STDERR "Dumper(\$result->{'lieferscheinRecords'}->[0]):\n", Dumper($result->{'lieferscheinRecords'}->[0]) if $debugIt;
            if ( $result->{'lieferscheinCount'} > 0 ) {
                if ( &genKohaRecords($ekzCustomerNumber, $result->{'messageID'}, $lieferscheinDetailElement,$result->{'lieferscheinRecords'}->[0]) ) {
                    $res = 1;
                }
            }
        }
    }
    if ( $res == 1 ) {
        C4::External::EKZ::lib::EkzWebServices::setLastRunDate('LieferscheinDetail', DateTime->now(time_zone => 'local'));
    }

}

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $endTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d\n",1900+$year,1+$mon,$mday,$hour,$min,$sec);
print STDERR "ekzWsLieferschein End:$endTime\n" if $debugIt;
