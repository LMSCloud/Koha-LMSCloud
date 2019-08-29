#!/usr/bin/perl

# Copyright 2019 (C) LMSCLoud GmbH
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

=head1 NAME

archive_illrequests.pl - cron script for archiving old completed ILL requests

=head1 SYNOPSIS

./archive_illrequests.pl [ -b <backend name> ] [ -m <number of days> ] [ -c ]

or, in crontab:
0 1 * * * archive_illrequests.pl -b ILLZKSHA -m 28 -c

=head1 DESCRIPTION

This script shifts database records that represent an completed ILL request
from the current tables illrequests and illrequestattributes
to the archive tables old_illrequests and old_illrequestattributes.
The reason for this is to keep the current tables free of ballast
that slows down display of lists without giving any advantage.
The tables old_illrequests and old_illrequestattributes may be
evaluated using special Koha reports, if required by customers.

The argument -m specifies an age in days; all illrequests
that have been completed before this age will be archived.
Mandatory, minimum value: 7

The argument -b specifies the name of the ILL backend that has to be archived.
Mandatory


=cut

=head1 OPTIONS

=over 8

=item B<-help>

Prints a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-v>

Verbose. Without this flag set, only result and errors are reported.

=item B<-d>

Extra verbose for debugging.

=item B<-b>

Name of the ILL backend that has to be archived. Mandatory.

=item B<-m>

Minimum age (in days). Only ILL records with an completed-date surpassing this age are archived.
Mandatory, minimum value: 7

=item B<-c>

Confirm flag: Add this option. The script will only print a usage
statement otherwise.

=back

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Try::Tiny;
use Data::Dumper;

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}
use C4::Context;
use C4::Log;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Circulation;
use Koha::Libraries;
use Koha::Checkouts;
use Koha::DateUtils;
use Koha::Illrequests;
use Koha::Illrequestattributes;
use Koha::Schema::Result::OldIllrequest;
use Koha::Schema::Result::OldIllrequestattribute;



binmode( STDOUT, ':encoding(UTF-8)' );

# These are defaults for command line options.
my $confirm;                                                        # -c: Confirm that the user has read and configured this script.
my $backend;                                                        # -b: name of ILL backend to be archived
my $mindays = 6;                                                    # -m: Minimum age (in days)
my $verbose = 0;                                                    # -v: verbose
my $debug = 0;                                                      # -d: debug

my $help    = 0;
my $man     = 0;

GetOptions(
            'help|?' => \$help,
            'man' => \$man,
            'c' => \$confirm,
            'b:s' => \$backend,
            'm:i' => \$mindays,
            'v' => \$verbose,
            'd' => \$debug,
       ) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -verbose => 2 ) if $man;

if ( ! $confirm ||
     ! $backend ||
     $mindays < 7
   ) {
     pod2usage(1);
}


sub archive_illrequests {
    my ($backend, $mindays, $verbose, $debug) = @_;
    my $ret = 0;
    my $dbh = C4::Context->dbh;
    my $schema = Koha::Database->new->schema;

    # Are we able to actually work?
    my $backends = Koha::Illrequest::Config->new->available_backends;
    warn dt_from_string . " archive_illrequests() backends:" . Dumper($backends) if $debug;
    my $backends_available = ( scalar @{$backends} > 0 );
    my $illmodule = C4::Context->preference('ILLModule');

    if ( !($illmodule && $backends_available) ) {
        warn dt_from_string . " archive_illrequests(): ILLModule or ILLbackends not available. C4::Context->preference('ILLModule'):$illmodule: backends_available:$backends_available:";
    }

    my $thresholddate = output_pref( { dt => dt_from_string->add( days => -$mindays ), dateonly => 1, dateformat => 'dmydot' } );
    my $seldate;
    my $sqlformattedDate;
    if ( $thresholddate ) {
        $seldate = eval { dt_from_string( $thresholddate ) };
        $sqlformattedDate = output_pref( { dt => $seldate, dateonly => 1, dateformat => 'iso' } ) if ( $seldate );
    }
    warn dt_from_string . " archive_illrequests() sqlformattedDate:$sqlformattedDate:" if ($verbose || $debug);


    my $countSelectedIllRequests = 0;
    my $countCopiedIllRequests = 0;
    my $countTransferredIllRequests = 0;

    if ( ! defined $sqlformattedDate ) {
        warn dt_from_string . " archive_illrequests() threshhold date is not valid (thresholddate:$thresholddate)";
    } elsif ( $seldate->add( days => 7 ) > DateTime->now() ) {
        warn dt_from_string . " archive_illrequests() threshhold date has to be at least 7 days in the past (thresholddate:$thresholddate)";
    } elsif ( ! $backend ) {
        warn dt_from_string . " archive_illrequests() invalid backend name (backend:$backend)";
    } else {
        my $illrequests = Koha::Illrequests->new();
        my $illrequests_rs;
        if ( $backend eq 'allillbackends' ) {
            $illrequests_rs = $illrequests->_resultset()->search( { -and => [ status => 'COMP', completed => { '>' => '1900-01-01' }, completed => { '<' => $sqlformattedDate} ] },  { order_by => ['illrequest_id'] } );
        } else {
            $illrequests_rs = $illrequests->_resultset()->search( { -and => [ status => 'COMP', completed => { '>' => '1900-01-01' }, completed => { '<' => $sqlformattedDate}, backend => $backend ] },  { order_by => ['illrequest_id'] } );
        }
        if ( ! $illrequests_rs ) {
            warn dt_from_string . " archive_illrequests() error during ILL record selection - no records found";
        } else {
            $ret = 1;
            my @selectedIllRequests = $illrequests_rs->all();
            warn dt_from_string . " archive_illrequests() count illrequest_rs:" . @selectedIllRequests if $debug;
            $countSelectedIllRequests = scalar @selectedIllRequests;
            warn dt_from_string . " archive_illrequests() Found $countSelectedIllRequests ILL requests for transferring to storage table." if ($verbose || $debug);
            ILLREQUEST: foreach my $selectedIllRequest (@selectedIllRequests) {

                # archive the illrequests record
                my $old_illrequestsRecord = {
                    illrequest_id => $selectedIllRequest->illrequest_id(),
                    borrowernumber => $selectedIllRequest->{_column_data}->{borrowernumber},
                    biblio_id => $selectedIllRequest->biblio_id(),
                    branchcode => $selectedIllRequest->{_column_data}->{branchcode},
                    status => $selectedIllRequest->status(),
                    placed => $selectedIllRequest->placed(),
                    replied => $selectedIllRequest->replied(),
                    updated => $selectedIllRequest->updated(),
                    completed => $selectedIllRequest->completed(),
                    medium => $selectedIllRequest->medium(),
                    accessurl => $selectedIllRequest->accessurl(),
                    cost => $selectedIllRequest->cost(),
                    notesopac => $selectedIllRequest->notesopac(),
                    notesstaff => $selectedIllRequest->notesstaff(),
                    orderid => $selectedIllRequest->orderid(),
                    backend => $selectedIllRequest->backend(),
                };
                warn dt_from_string . " archive_illrequests() next old_illrequestsRecord:" . Dumper($old_illrequestsRecord) if $debug;

                my $old_illrequests = $schema->resultset('OldIllrequest');

                my $old_illrequests_rs;
                my $old_illrequestattributes = $schema->resultset('OldIllrequestattribute');
                my $old_illrequestattributes_rs;

                try {
                    # delete from table old_illrequestattributes the correlated records if already existing
                    $old_illrequestattributes_rs = $old_illrequestattributes->search( { illrequest_id => $selectedIllRequest->illrequest_id() } );
                    warn dt_from_string . " archive_illrequests() old_illrequestattributes_rs->count:" . $old_illrequestattributes_rs->count() if $debug;

                    if ( $old_illrequestattributes_rs->count() > 0 ) {
                        warn dt_from_string . " archive_illrequests() old_illrequestattributes_rs now will be deleted." if $debug;
                        $old_illrequestattributes_rs->delete();
                    }
                    # delete from table old_illrequests the copy of the record if already existing
                    $old_illrequests_rs = $old_illrequests->search( { illrequest_id => $selectedIllRequest->illrequest_id() } );
                    warn dt_from_string . " archive_illrequests() old_illrequests_rs->count:" . $old_illrequests_rs->count() if $debug;
                    if ( $old_illrequests_rs->count() > 0 ) {
                        warn dt_from_string . " archive_illrequests() old_illrequests_rs now will be deleted." if $debug;
                        $old_illrequests_rs->delete();
                    }

                    # insert copied record into old_illrequests
                    warn dt_from_string . " archive_illrequests() old_illrequests record now will be inserted. (illrequest_id:" . $old_illrequestsRecord->{illrequest_id} . ":)" if ($verbose || $debug);
                    $old_illrequests_rs = $old_illrequests->create($old_illrequestsRecord);
                }
                catch {
                    my $exception = $_;
                    warn dt_from_string . " archive_illrequests() trying to create old_illrequests record, catched exception:" . Dumper($exception);
                    if (ref($exception) eq 'DBIx::Class::Exception') {
                        # 'Copy'-action failed, so we do not delete illrequests record and correlated illrequestattributes records.
                        # trying our luck with next illrequest, not deleting illreq
                        next ILLREQUEST;
                    } else {
                        $exception->rethrow();
                    }
                };


                # archive all correlated illrequestattributes records
                my $illrequestattributes = Koha::Illrequestattributes->new();
                my $illrequestattributes_rs = $illrequestattributes->_resultset()->search( { illrequest_id => $selectedIllRequest->illrequest_id() } );
                
                if ( ! $illrequestattributes_rs ) {
                    warn dt_from_string . " archive_illrequests() error during ILL attributes record selection - no records found";
                    last ILLREQUEST;
                }
                my @selectedIllRequestattributes = $illrequestattributes_rs->all();
                foreach my $selectedIllRequestattribute (@selectedIllRequestattributes) {

                    my $old_illrequestattributesRecord = {
                        illrequest_id => $selectedIllRequestattribute->illrequest_id(),
                        type => $selectedIllRequestattribute->type(),
                        value => $selectedIllRequestattribute->value(),
                    };
                    warn dt_from_string . " archive_illrequests() next old_illrequestattributesRecord:" . Dumper($old_illrequestattributesRecord) if $debug;

                    try {
                        # insert copied record into old_illrequestattributes
                        warn dt_from_string . " archive_illrequests() old_illrequestattributes record now will be inserted. (illrequest_id:" . $old_illrequestattributesRecord->{illrequest_id} . ": type:" . $old_illrequestattributesRecord->{type} . ": value:" . $old_illrequestattributesRecord->{value} . ":)" if ($verbose || $debug);
                        $old_illrequestattributes_rs = $old_illrequestattributes->create($old_illrequestattributesRecord);
                    }
                    catch {
                        my $exception = $_;
                        warn dt_from_string . " archive_illrequests() trying to create old_illrequestattributes record, catched exception:" . Dumper($exception);
                        if (ref($exception) eq 'DBIx::Class::Exception') {
                            # 'Copy'-action failed, so we do not delete illrequests record and correlated illrequestattributes records.
                            # trying our luck with next illrequest
                            next ILLREQUEST;
                        } else {
                            $exception->rethrow();
                        }
                    };
                }
                $countCopiedIllRequests += 1;
                # Successfully copied the illrequests record to database table old_illrequests, 
                # and the correlated illrequestattributes records to database table old_illrequestattributes.

                # So now the correlated illrequestattributes records and the illrequests record itself can be deleted.
                $schema->storage->txn_begin;
                try {
                    # delete correlated records from illrequestattributes
                    $illrequestattributes_rs = $illrequestattributes->_resultset()->search( { illrequest_id => $selectedIllRequest->illrequest_id() } );
                    warn dt_from_string . " archive_illrequests() trying to delete illrequestattributes records (illrequest_id:" . $selectedIllRequest->illrequest_id() . "); count:" . $illrequestattributes_rs->count() if ($verbose || $debug);
                    $illrequestattributes_rs->delete();
                    
                    # delete the record from illrequests
                    $illrequests_rs = $illrequests->_resultset()->search( { illrequest_id => $selectedIllRequest->illrequest_id() } );
                    warn dt_from_string . " archive_illrequests() trying to delete illrequests record (illrequest_id:" . $selectedIllRequest->illrequest_id() . "); count:" . $illrequests_rs->count() if ($verbose || $debug);
                    $illrequests_rs->delete();
                }
                catch {
                    my $exception = $_;
                    warn dt_from_string . " archive_illrequests() trying to delete illrequests and illrequestattributes records (illrequest_id:" . $selectedIllRequest->illrequest_id() . "), catched exception:" . Dumper($exception);
                    $schema->storage->txn_rollback;
                    if (ref($exception) eq 'DBIx::Class::Exception') {
                        # trying our luck with next illrequest
                        next ILLREQUEST;
                    } else {
                        $exception->rethrow();
                    }
                };
                $schema->storage->txn_commit;
                $countTransferredIllRequests += 1;

            }
        }
        warn dt_from_string . " archive_illrequests() $countSelectedIllRequests ILL requests have been found for archiving.";
        warn dt_from_string . " archive_illrequests() $countCopiedIllRequests ILL requests have been copied to storage tables.";
        warn dt_from_string . " archive_illrequests() $countTransferredIllRequests ILL requests have been deleted from original tables.";
    }
    return $ret;
}


cronlogaction();

warn dt_from_string . " archive_illrequests.pl: starting with args backend:$backend: mindays:$mindays: verbose:$verbose: debug:$debug:";

my $ret = &archive_illrequests($backend, $mindays, $verbose, $debug);

warn dt_from_string . " archive_illrequests.pl: END ret:$ret:" if ($verbose || $debug);




