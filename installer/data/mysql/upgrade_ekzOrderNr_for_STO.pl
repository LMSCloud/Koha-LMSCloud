#!/usr/bin/perl

# Copyright 2020 (C) LMSCLoud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


# As we have learned from ekz, the stoID is not a unique identifier for a standing order.
# Only the combination of ekzKundenNr (ekz customer number) and stoID is unique.
# There are Koha instances that have differing ekz customer numbers for their libraries (e.g. sb_tuebingen).
# That is the reason that we have to replace the old format of the automatically generated pseudo ekz order number from
# stoID<ekz standing order id>
# to 
# sto.<ekz customer number>.ID<ekz standing order id>
# The automatically generated pseudo ekz order number is also part of the designations
# of Koha acquisition baskets and basket groups.
# This script updates tables acquisition_import, aqbasket and aqbasketgroups accordingly.

use strict;
use warnings;
use Data::Dumper;

# CPAN modules
use DBI;
use C4::Context;

binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );


my $debug = 1;
my $rollItBack = 0;


my $dbh = C4::Context->dbh;
$|=1; # flushes output
local $dbh->{RaiseError} = 1;
if ( $rollItBack ) {
    $dbh->{AutoCommit} = 0;
    #$dbh->begin_work; Already in a transaction at ./mytest.pl line 35.
}


sub read_systempreferences {
    my ( $selVariable ) = @_;
    my $retValue;
	print "upgrade_ekzOrderNr_for_STO::read_systempreferences START selVariable:$selVariable:\n" if $debug;

    my $sth = $dbh->prepare(q{
        SELECT value
        FROM systempreferences
        WHERE  variable = ?;
    });
    $sth->execute($selVariable);

    if ( my ($value ) = $sth->fetchrow ) {
        #my @content = split(/\|/,$value);
        #$retValue = $content[0];
        $retValue = $value;
    }

    #print "upgrade_ekzOrderNr_for_STO::read_systempreferences() END; selVariable:$selVariable: retValue:" . Dumper($retValue) . ":\n" if $debug;
    print "upgrade_ekzOrderNr_for_STO::read_systempreferences() END; selVariable:$selVariable: retValue:$retValue:\n" if $debug;

    return $retValue;
}


sub modify_acquisition_import {
    my ( $ekzKundenNr ) = @_;
    my $modifiedCount = 0;
	print "upgrade_ekzOrderNr_for_STO::modify_acquisition_import START ekzKundenNr:$ekzKundenNr:\n" if $debug;

    my $sthSel = $dbh->prepare(q{
        SELECT id, object_type, object_number, object_date, rec_type, object_item_number, processingstate, processingtime
        FROM acquisition_import
        WHERE object_number LIKE 'stoID%'
           OR object_item_number LIKE 'stoID%';
    });
    $sthSel->execute();

    while ( my ($id, $object_type, $object_number, $object_date, $rec_type, $object_item_number, $processingstate, $processingtime ) = $sthSel->fetchrow ) {
	    print "upgrade_ekzOrderNr_for_STO::modify_acquisition_import id:$id: object_type:$object_type: object_number:$object_number: object_date:$object_date: rec_type:$rec_type: object_item_number:$object_item_number: processingstate:$processingstate: processingtime:$processingtime:\n" if $debug;
	    print "upgrade_ekzOrderNr_for_STO::modify_acquisition_import object_number:$object_number: object_item_number:$object_item_number:\n" if $debug;
        my $new_object_number = $object_number;
        my $new_object_item_number = $object_item_number;

        if ($object_number =~ /^stoID(.*)$/ ) {
            my $stoid = $1;
            $new_object_number = 'sto.' . $ekzKundenNr . '.ID' . $stoid;
        }
        print "upgrade_ekzOrderNr_for_STO::modify_acquisition_import object_number:$object_number -> $new_object_number:\n" if $debug;

        if ( defined($new_object_item_number) ) {
            if ($object_item_number =~ /^stoID(.*)$/ ) {
                my $stoidplus = $1;
                $new_object_item_number = 'sto.' . $ekzKundenNr . '.ID' . $stoidplus;
            }
        }
        print "upgrade_ekzOrderNr_for_STO::modify_acquisition_import object_item_number:$object_item_number -> $new_object_item_number:\n" if $debug;

        if ( $new_object_number ne $object_number || $new_object_item_number ne $object_item_number ) {
            my $sthMod = $dbh->prepare(q{
                UPDATE acquisition_import
                SET object_number = ?,
                    object_item_number = ?
                WHERE  id = ?;
            });
            $sthMod->execute($new_object_number,$new_object_item_number,$id);    # $new_object_item_number undef -> object_item_number = NULL
            $modifiedCount += 1;
        }
    }

    print "upgrade_ekzOrderNr_for_STO::modify_acquisition_import END; ekzKundenNr:$ekzKundenNr: modifiedCount:$modifiedCount:\n" if $debug;

    return $modifiedCount;
}


sub modify_aqbasketgroups {
    my ( $ekzKundenNr, $ekzBooksellersId ) = @_;
    my $modifiedCount = 0;
	print "upgrade_ekzOrderNr_for_STO::modify_aqbasketgroups START ekzKundenNr:$ekzKundenNr: ekzBooksellersId:$ekzBooksellersId:\n" if $debug;

    my $sthSel = $dbh->prepare(q{
        SELECT  id, name, booksellerid
        FROM aqbasketgroups
        WHERE  name LIKE '%stoID%'
          /*AND booksellerid = ?*/
        ;
    });
    #$sthSel->execute($ekzBooksellersId);
    $sthSel->execute();

    while ( my ( $id, $name, $booksellerid ) = $sthSel->fetchrow ) {
	    print "upgrade_ekzOrderNr_for_STO::modify_aqbasketgroups id:$id: name:$name: booksellerid:$booksellerid:\n" if $debug;
        my $new_name = $name;

        if ($name =~ /^(.*)?stoID(.*)$/ ) {
            my $stoid = $2;
            $new_name = $1 . 'sto.' . $ekzKundenNr . '.ID' . $stoid;
        }
        print "upgrade_ekzOrderNr_for_STO::modify_aqbasketgroups name:$name -> $new_name:\n" if $debug;

        if ( $new_name ne $name ) {
            my $sthMod = $dbh->prepare(q{
                UPDATE aqbasketgroups
                SET name = ?
                WHERE  id = ?;
            });
            $sthMod->execute($new_name,$id);
            $modifiedCount += 1;
        }
    }
    print "upgrade_ekzOrderNr_for_STO::modify_aqbasketgroups END; ekzKundenNr:$ekzKundenNr: modifiedCount:$modifiedCount:\n" if $debug;

    return $modifiedCount;
}


sub modify_aqbasket {
    my ( $ekzKundenNr, $ekzBooksellersId ) = @_;
    my $modifiedCount = 0;
	print "upgrade_ekzOrderNr_for_STO::modify_aqbasket START ekzKundenNr:$ekzKundenNr: ekzBooksellersId:$ekzBooksellersId:\n" if $debug;

    my $sthSel = $dbh->prepare(q{
        SELECT  basketno, basketname, note, booksellerid
        FROM aqbasket
        WHERE  (basketname LIKE '%stoID%'
                OR note LIKE '%stoID%'    )
          /*AND booksellerid = ?*/
        ;
    });
    #$sthSel->execute($ekzBooksellersId);
    $sthSel->execute();

    while ( my ( $basketno, $basketname, $note, $booksellerid ) = $sthSel->fetchrow ) {
	    print "upgrade_ekzOrderNr_for_STO::modify_aqbasket basketno:$basketno: basketname:$basketname: note:$note: booksellerid:$booksellerid:\n" if $debug;
        my $new_basketname = $basketname;
        my $new_note = $note;

        if ($basketname =~ /^(.*)?stoID(.*)$/ ) {
            my $stoid = $2;
            $new_basketname = $1 . 'sto.' . $ekzKundenNr . '.ID' . $stoid;
        }
        print "upgrade_ekzOrderNr_for_STO::modify_aqbasket basketname:$basketname -> $new_basketname:\n" if $debug;

        if ( defined($new_note) ) {
            while ($new_note =~ /^(.*)?stoID(.*)$/s ) {
                my $stoidplus = $2;
                $new_note = $1 . 'sto.' . $ekzKundenNr . '.ID' . $stoidplus;
            }
        }
        print "upgrade_ekzOrderNr_for_STO::modify_aqbasket note:$note -> $new_note:\n" if $debug;

        if ( $new_basketname ne $basketname || $new_note ne $note ) {
            my $sthMod = $dbh->prepare(q{
                UPDATE aqbasket
                SET basketname = ?,
                    note = ?
                WHERE  basketno = ?;
            });
            $sthMod->execute($new_basketname,$new_note,$basketno);
            $modifiedCount += 1;
        }
    }
    print "upgrade_ekzOrderNr_for_STO::modify_aqbasket END; ekzKundenNr:$ekzKundenNr: modifiedCount:$modifiedCount:\n" if $debug;

    return $modifiedCount;
}


### main ###
my $modifiedCountAcquisitionImport = 0;
my $modifiedCountAqbasketgroups = 0;
my $modifiedCountAqbasket = 0;

# read ekzKundenNr
my $ekzKundenNr = &read_systempreferences('ekzWebServicesCustomerNumber');

print "upgrade_ekzOrderNr_for_STO.pl START ekzKundenNr:$ekzKundenNr:\n" if $debug;

# migrate ekzOrderNr only with single ekzKundenNr but not with multiple ekzKundenNrs
if ( index($ekzKundenNr, '|') == -1 ) {
    
    # read ekz aqbooksellers id
    my $ekzBooksellersId = &read_systempreferences('ekzaqbooksellersid');

    # modify ekzOrderNr in acquisition_import
    $modifiedCountAcquisitionImport = &modify_acquisition_import($ekzKundenNr);

    # modify ekzOrderNr in aqbasketgroups
    $modifiedCountAqbasketgroups = &modify_aqbasketgroups($ekzKundenNr,$ekzBooksellersId);

    # modify ekzOrderNr in aqbasket
    $modifiedCountAqbasket = &modify_aqbasket($ekzKundenNr,$ekzBooksellersId);
}
print "upgrade_ekzOrderNr_for_STO.pl END modifiedCountAcquisitionImport:$modifiedCountAcquisitionImport:  modifiedCountAqbasketgroups:$modifiedCountAqbasketgroups:  modifiedCountAqbasket:$modifiedCountAqbasket:\n" if $debug;

if ( $rollItBack ) {
    # roll it back for TEST
    $dbh->rollback;
    $dbh->{AutoCommit} = 1;
} else {
    #$dbh->commit();
}



