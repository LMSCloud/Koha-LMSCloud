#!/usr/bin/perl
#
# Fix Elasticsearch indexing problems:

# Copyright 2024 LMSCloud GmbH
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

fix_es_indexing.pl - fix Elasticsearch indexing problems:
                     Remove ES documents that are deleted in Koha
                     Exected Background indexing jobs that are currently not extecuted

=head1 SYNOPSIS

B<fix_es_indexing.pl>

=cut

use Modern::Perl;
use C4::Context;
use Koha::Logger;
use Koha::BackgroundJobs;
use Koha::Biblios;
use Koha::SearchEngine;
use Koha::SearchEngine::Indexer;
use Koha::SearchEngine::Elasticsearch::DocumentIdList;
use Try::Tiny;
use Array::Utils qw( array_minus );

if (  C4::Context->preference('SearchEngine') ne 'Elasticsearch' ) {
    die "This instance is not using Elasticsearch as indexer.";
}

restartUndoneBackgroundJobs();
fixESIndexProblems();

sub fixESIndexProblems {
    my $esListGen = Koha::SearchEngine::Elasticsearch::DocumentIdList->new( { index => 'biblios' } );

    my @eslist  = $esListGen->getIDList();
    print "Found " . scalar(@eslist) . " indexed document IDs in ElasticSearch.\n";
    
    my @biblist = Koha::Biblios->search()->get_column('biblionumber');
    print "Found " . scalar(@biblist) . " biblio record IDs in Koha the database.\n";
     
    my @koha_problems = sort { $a =~ /^[0-9]+$/ && $b =~ /^[0-9]+$/ ? $a <=> $b : $a cmp $b } array_minus(@biblist, @eslist);
    my @es_problems   = sort { $a =~ /^[0-9]+$/ && $b =~ /^[0-9]+$/ ? $a <=> $b : $a cmp $b } array_minus(@eslist, @biblist);

    my $es_params = $esListGen->get_elasticsearch_params;
    my $es_base   = "$es_params->{nodes}[0]/".$esListGen->index_name;

    my $indexer = Koha::SearchEngine::Indexer->new({ index => $Koha::SearchEngine::BIBLIOS_INDEX });

    if ( @es_problems ){
        print "=================\n";
        print "Records that exist in ES but not in Koha\n";
        for my $biblionumber ( @es_problems ){
            print "  Deleting Doc ID $biblionumber from ES index.\n";
            $indexer->index_records( $biblionumber, "recordDelete", "biblioserver" );
            #print " View record using: curl -X GET \"$es_base/_doc/$problem?pretty=true\"\n";
        }
    }
    else {
        print "No mismatch of indexed document IDs in Elasticsearch index found\n";
    }
    if ( @koha_problems ) {
        print "=================\n";
        print "Records that exist in Koha that are not index in ES\n";
        for my $biblionumber ( @koha_problems ){
            print "  Indexing biblio record $biblionumber.\n";
            $indexer->index_records( $biblionumber, "specialUpdate", "biblioserver" );
        }
    }
    else {
        print "No un-indexed Koha records found.\n";
    }
}

sub restartUndoneBackgroundJobs {
    my $logger = Koha::Logger->get({ interface =>  'worker' });

    my $biblio_indexer = Koha::SearchEngine::Indexer->new({ index => $Koha::SearchEngine::BIBLIOS_INDEX });
    my $auth_indexer = Koha::SearchEngine::Indexer->new({ index => $Koha::SearchEngine::AUTHORITIES_INDEX });

    my @jobs = Koha::BackgroundJobs->search({ status => 'new', queue => 'elastic_index' } )->as_list;
    if ( @jobs ){
        print "=================\n";
        print "Undone background indexing jobs with status new found\n";
        foreach my $job(@jobs) {
            print "  Running job ", $job->id, ".\n";
            runBackgroundJob($biblio_indexer,$auth_indexer,$logger,$job);
        }
    }
}

sub runBackgroundJob {
    my ($biblio_indexer,$auth_indexer,$logger,@jobs) = @_;

    my @bib_records;
    my @auth_records;

    my $jobs = Koha::BackgroundJobs->search( { id => [ map { $_->id } @jobs ] });
    # Start
    $jobs->update({
        progress => 0,
        status => 'started',
        started_on => \'NOW()',
    });

    for my $job (@jobs) {
        #my $args = try {
            my $args = $job->json->decode( $job->data );
        #} catch {
         #   $logger->warn( sprintf "Cannot decode data for job id=%s", $job->id );
         #   $job->status('failed')->store;
         #   return;
        #};
        next unless $args;
        if ( $args->{record_server} eq 'biblioserver' ) {
            push @bib_records, @{ $args->{record_ids} };
        } else {
            push @auth_records, @{ $args->{record_ids} };
        }
    }

    if (@auth_records) {
        try {
            $auth_indexer->update_index( \@auth_records );
        } catch {
            $logger->warn( sprintf "Update of elastic index failed with: %s", $_ );
        };
    }
    if (@bib_records) {
        try {
            $biblio_indexer->update_index( \@bib_records );
        } catch {
            $logger->warn( sprintf "Update of elastic index failed with: %s", $_ );
        };
    }

    # Finish
    $jobs->update({
        progress => 1,
        status => 'finished',
        ended_on => \'NOW()',
    });
}

