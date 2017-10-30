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

use C4::External::EKZ::EkzWsStandingOrder qw( getCurrentYear readStoFromEkzWsStoList genKohaRecords );


binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );



my $debugIt = 1;

my $currentYear;
my $lastRunDate;
my $todayDate;

my $simpleTest = 0;
my $genKohaRecords = 1;
my $result;
my $stoListElement = '';    # for storing the StoListElement of the SOAP response body

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $startTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d\n",1900+$year,1+$mon,$mday,$hour,$min,$sec);

print STDERR "ekzWsStoList Start:$startTime\n" if $debugIt;

$currentYear = &getCurrentYear();
$lastRunDate = C4::External::EKZ::lib::EkzWebServices::getLastRunDate('StoList', 'A');    # value for 'von' / 'from', required in american form yyyy-mm-dd
$todayDate = `date +%Y-%m-%d`;
chomp($todayDate);

print STDERR "ekzWsStoList currentYear:$currentYear: lastRunDate:$lastRunDate: todayDate:$todayDate:\n" if $debugIt;

if ( $simpleTest ) {
    print STDERR "ekzWsStoList read STO of year 2017; calling readStoFromEkzWsStoList (2017,undef,false,false,false,undef,undef)\n" if $debugIt;
    # read all stoIDs of 2017
    my $stoOf2017 = &readStoFromEkzWsStoList ('2017',undef,'false','false','false',undef,undef);
    
    foreach my $sto ( @{$stoOf2017->{'standingOrderRecords'}} ) {
        print STDERR "ekzWsStoList read StoId $sto->{stoID}: calling readStoFromEkzWsStoList (2017,$sto->{stoID},true,true,true,'2017-09-01','true')\n" if $debugIt;
        &readStoFromEkzWsStoList ('2017',$sto->{stoID},'true','true','true','2017-09-01','true');
    }
}

#generate the biblio, biblioitems, items, acquisition_import and acquisition_import_object records as in BestellInfo
if ( $genKohaRecords ) {
    my $res = 0;

    # read all stoIDs of current year
    print STDERR "ekzWsStoList read STO of year:$currentYear; calling readStoFromEkzWsStoList ($currentYear,undef,false,false,false,undef,undef)\n" if $debugIt;
    my $stoOfYear = &readStoFromEkzWsStoList ($currentYear,undef,'false','false','false',undef,undef,undef);
    
    foreach my $sto ( @{$stoOfYear->{'standingOrderRecords'}} ) {
        print STDERR "ekzWsStoList read StoId:$sto->{stoID}: state changes since lastRunDate:$lastRunDate; calling readStoFromEkzWsStoList ($currentYear,$sto->{stoID},true,true,true,$lastRunDate,'true',\\\$stoListElement)\n" if $debugIt;
        $result = &readStoFromEkzWsStoList ($currentYear,$sto->{stoID},'true','true','true',undef,'true',\$stoListElement);    # read *complete* info (i.e. all titles, even without new status) of the standing order
        $result = &readStoFromEkzWsStoList ($currentYear,$sto->{stoID},'true','true','true',$lastRunDate,'true',undef);        # read titles with modified state of the standig order 
print STDERR Dumper($result->{'standingOrderRecords'}->[0]) if $debugIt;

        if ( $result->{'standingOrderCount'} > 0 ) {
            if ( &genKohaRecords($result->{'messageID'}, $stoListElement, $result->{'standingOrderRecords'}->[0], $lastRunDate, $todayDate) ) {
                $res = 1;
            }
        }
    }
    if ( $res == 1 ) {
        C4::External::EKZ::lib::EkzWebServices::setLastRunDate('StoList', DateTime->now(time_zone => 'local'));
    }
}

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $endTime = sprintf("%04d-%02d-%02d at %02d:%02d:%02d\n",1900+$year,1+$mon,$mday,$hour,$min,$sec);
print STDERR "ekzWsStoList End:$endTime\n" if $debugIt;

