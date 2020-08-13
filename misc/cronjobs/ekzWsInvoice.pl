#!/usr/bin/perl -w

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
use Data::Dumper;

use C4::External::EKZ::lib::EkzWsConfig;
use C4::External::EKZ::lib::EkzWebServices;
use C4::External::EKZ::EkzWsInvoice qw( readReFromEkzWsRechnungList readReFromEkzWsRechnungDetail genKohaRecords );


binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );



my $debugIt = 1;

my $lastRunDate;
my $yesterdayDate;

my $testMode = 0;    # 0 or 1
my $genKohaRecords = 1;    # 0 or 1
my $result;
my $rechnungDetailElement = '';    # for storing the RechnungDetailElement of the SOAP response body

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $startTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d\n",1900+$year,1+$mon,$mday,$hour,$min,$sec);

print STDERR "ekzWsInvoice Start:$startTime\n" if $debugIt;

$lastRunDate = C4::External::EKZ::lib::EkzWebServices::getLastRunDate('RechnungDetail', 'E');
print STDERR "ekzWsInvoice syspref lastRunDate:$lastRunDate:\n" if $debugIt;
if ( !defined($lastRunDate) || length($lastRunDate) == 0 ) {
    $lastRunDate = `date +%d.%m.%C%y`;    # this will result in an empty hit list, because !($lastRunDate <= $yesterdayDate)
    chomp($lastRunDate);
}
$yesterdayDate = `date -d "1 day ago" +%d.%m.%C%y`;                                                  # value for 'bis' / 'until', required in european form dd.mm.yyyy
chomp($yesterdayDate);
print STDERR "ekzWsInvoice modified lastRunDate:$lastRunDate: yesterdayDate:$yesterdayDate:\n" if $debugIt;

if ( $testMode == 1 ) {
    # some libraries use different ekz Kundennummer for different branches, so we have to call the invoice synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        my $von = "01.08.2016";
        print STDERR "ekzWsInvoice read RechnungList von:$von; calling readReFromEkzWsRechnungList ($ekzCustomerNumber,$von,undef,undef)\n" if $debugIt;
        my $lsListe = &readReFromEkzWsRechnungList ($ekzCustomerNumber,$von,undef,undef);

        foreach my $rechnung ( @{$lsListe->{'rechnungRecords'}} ) {
            print STDERR "ekzWsInvoice read rechnung via id:$rechnung->{id}: and nummer:$rechnung->{nummer}: calling readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},$rechnung->{nummer},\\\$rechnungDetailElement)\n" if $debugIt;
            my $lsListe = &readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},$rechnung->{nummer},\$rechnungDetailElement);

            #print STDERR "ekzWsInvoice read rechnung via id:$rechnung->{id}: calling readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},undef,\\\$rechnungDetailElement)\n" if $debugIt;
            #$lsListe = &readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},undef,\$rechnungDetailElement);

            #print STDERR "ekzWsInvoice read rechnung via nummer:$rechnung->{nummer}: calling readReFromEkzWsRechnungDetail($ekzCustomerNumber,undef,$rechnung->{nummer},\\\$rechnungDetailElement)\n" if $debugIt;
            #$lsListe = &readReFromEkzWsRechnungDetail($ekzCustomerNumber,undef,$rechnung->{nummer},\$rechnungDetailElement);
        }
    }
}

if ( $testMode == 2 ) {
    my $res = 0;
    my $ekzCustomerNumber = 1112310;    # friedrich_flensburg
    #my $ekzCustomerNumber = 1112313;    # rita_rendsburg
    my $rechnung;
    
    $rechnung->{id} = '1710434';    # friedrich_flensburg, Rechnung über 85.84 €, 4 Auftragspositionen
    #$rechnung->{id} = '1710428';    # an rita_rendsburg, Rechnung über 476.12 €, 25 Auftragspositionen
    #$rechnung->{id} = '1710429';    # an rita_rendsburg, Rechnung über 66.70 €, 22 Auftragspositionen

            print STDERR "ekzWsInvoice read rechnung via id:$rechnung->{id}: calling readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},undef,\\\$rechnungDetailElement)\n" if $debugIt;
            $result = &readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},undef,\$rechnungDetailElement);    # read *complete* info (i.e. all titles) of the invoice

            if ( $genKohaRecords ) {
print STDERR "Dumper(\$result->{'rechnungRecords'}->[0]):\n", Dumper($result->{'rechnungRecords'}->[0]) if $debugIt;
                if ( $result->{'rechnungCount'} > 0 ) {
                    if ( &genKohaRecords($ekzCustomerNumber, $result->{'messageID'}, $rechnungDetailElement,$result->{'rechnungRecords'}->[0]) ) {
                        $res = 1;
                    }
                }
            }

}

#generate the biblio, biblioitems, items, acquisition_import and acquisition_import_object records analogue to BestellInfo
if ( $testMode == 0 ) {
    my $res = 0;

    # some libraries use different ekz Kundennummer for different branches, so we have to call the invoice synchronization for each of these.
    my @ekzCustomerNumbers = C4::External::EKZ::lib::EkzWsConfig->new()->getEkzCustomerNumbers();
    print STDERR "ekzWsInvoice is trying to call readReFromEkzWsRechnungList ekzCustomerNumbers:", @ekzCustomerNumbers, ":\n" if $debugIt;
    foreach my $ekzCustomerNumber (sort @ekzCustomerNumbers) {
        # read all new invoices since $lastRunDate until including yesterday
        print STDERR "ekzWsInvoice read invoices since:$lastRunDate to:$yesterdayDate; calling readReFromEkzWsRechnungList ($ekzCustomerNumber,$lastRunDate,$yesterdayDate,undef)\n" if $debugIt;
        my $lsListe = &readReFromEkzWsRechnungList ($ekzCustomerNumber,$lastRunDate,$yesterdayDate,undef);
        
        foreach my $rechnung ( @{$lsListe->{'rechnungRecords'}} ) {
if ( $rechnung->{id} ne '1710434' ) {
    next;
}
            print STDERR "ekzWsInvoice read rechnung via id:$rechnung->{id}: calling readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},undef,\\\$rechnungDetailElement)\n" if $debugIt;
            $result = &readReFromEkzWsRechnungDetail($ekzCustomerNumber,$rechnung->{id},undef,\$rechnungDetailElement);    # read *complete* info (i.e. all titles) of the invoice

            if ( $genKohaRecords ) {
print STDERR "Dumper(\$result->{'rechnungRecords'}->[0]):\n", Dumper($result->{'rechnungRecords'}->[0]) if $debugIt;
                if ( $result->{'rechnungCount'} > 0 ) {
                    if ( &genKohaRecords($ekzCustomerNumber, $result->{'messageID'}, $rechnungDetailElement,$result->{'rechnungRecords'}->[0]) ) {
                        $res = 1;
                    }
                }
            }
        }
    }
    if ( $res == 1 ) {
        C4::External::EKZ::lib::EkzWebServices::setLastRunDate('RechnungDetail', DateTime->now(time_zone => 'local'));
    }

}

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $endTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d\n",1900+$year,1+$mon,$mday,$hour,$min,$sec);
print STDERR "ekzWsInvoice End:$endTime\n" if $debugIt;
