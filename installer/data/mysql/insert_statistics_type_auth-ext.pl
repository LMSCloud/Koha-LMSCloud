#!/usr/bin/perl

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
    #$dbh->begin_work; Already in a transaction at line 35.
}


sub insert_auth_ext {
    my $insertedCount = 0;
	print "insert_auth_ext START\n" if $debug;

    my $sthSel = $dbh->prepare(q{
        SELECT a.timestamp, a.object, a.info, b.branchcode
        FROM action_logs a LEFT JOIN borrowers b ON b.borrowernumber = a.object
        WHERE a.module = 'DIVIBIB'
          AND a.action = 'AUTHENTICATION'
          AND a.timestamp > '2019-01-01'
        ;
    });
    $sthSel->execute();

    while ( my ($timestamp, $object, $info, $branchcode ) = $sthSel->fetchrow ) {
	    print "insert_auth_ext timestamp:$timestamp: object:$object: info:$info: branchcode:$branchcode:\n" if $debug;

        my $datetime          = defined($timestamp)  ? $timestamp  : '2018-12-31 23:59:59';
        my $branch            = $branchcode;
        ###my $branch            = defined($branchcode) ? $branchcode : '';
        my $type              = 'auth-ext';
        my $amount            = 0;
        my $other             = defined($info)       ? $info       : '';
        my $itemnumber        = undef;
        my $itemtype          = '';
        my $location          = undef;
        my $borrowernumber    = defined($object)     ? $object     : '';
        my $accountno         = '';
        my $ccode             = '';

	    print "insert_auth_ext timestamp:$timestamp: object:$object: info:$info: branchcode:$branchcode:\n" if $debug;
        print "insert_auth_ext datetime:$datetime:\n" if $debug;
        print "insert_auth_ext branch:$branch:\n" if $debug;
        print "insert_auth_ext type:$type:\n" if $debug;
        print "insert_auth_ext amount:$amount:\n" if $debug;
        print "insert_auth_ext other:$other:\n" if $debug;
        print "insert_auth_ext itemnumber$itemnumber:\n" if $debug;
        print "insert_auth_ext itemtype:$itemtype:\n" if $debug;
        print "insert_auth_ext location:$location:\n" if $debug;
        print "insert_auth_ext borrowernumber:$borrowernumber:\n" if $debug;
        print "insert_auth_ext accountno:$accountno:\n" if $debug;
        print "insert_auth_ext ccode:$ccode :\n" if $debug;

        my $sthDel = $dbh->prepare(
            "DELETE FROM statistics
             WHERE datetime = ?
               AND type = ?
               AND borrowernumber = ?"
        );
        $sthDel->execute($datetime,$type,$borrowernumber);

        my $sthIns = $dbh->prepare(
            "INSERT INTO statistics
            (   datetime,
                branch,
                type,
                value,
                other,
                itemnumber,
                itemtype,
                location,
                borrowernumber,
                proccode,
                ccode)
             VALUES (?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?)"
        );
        my $res = $sthIns->execute(
            $datetime,
            $branch,
            $type,
            $amount,
            $other,
            $itemnumber,
            $itemtype,
            $location,
            $borrowernumber,
            $accountno,
            $ccode
        );
        $insertedCount += 1;
    }

    print "insert_auth_ext END; insertedCount:$insertedCount:\n" if $debug;

    return $insertedCount;
}




### main ###
my $inseredStatistics = 0;

# insert statistics records with type 'auth-ext' based on action_logs where module = 'DIVIBIB' and action = 'AUTHENTICATION'
$inseredStatistics = &insert_auth_ext();

print "main END inseredStatistics:$inseredStatistics:\n" if $debug;

if ( $rollItBack ) {
    # roll it back for TEST
    $dbh->rollback;
    $dbh->{AutoCommit} = 1;
} else {
    #$dbh->commit();
}



