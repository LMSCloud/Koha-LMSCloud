#!/usr/bin/perl

# Copyright 2020 Koha Development team
#
# This file is part of Koha
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

use Modern::Perl;

use Test::More tests => 11;
use Test::MockModule;
use JSON qw( decode_json );

use Koha::Database;
use Koha::BackgroundJobs;
use Koha::DateUtils;

use t::lib::TestBuilder;
use t::lib::Mocks;
use t::lib::Dates;
use t::lib::Koha::BackgroundJob::BatchTest;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

t::lib::Mocks::mock_userenv;

my $net_stomp = Test::MockModule->new('Net::Stomp');
$net_stomp->mock( 'send_with_receipt', sub { return 1 } );

my $data     = { a => 'aaa', b => 'bbb' };
my $job_size = 10;
my $job_id   = t::lib::Koha::BackgroundJob::BatchTest->new->enqueue(
    {
        size => $job_size,
        %$data
    }
);

# Enqueuing a new job
my $new_job = Koha::BackgroundJobs->find($job_id);
ok( $new_job, 'New job correctly enqueued' );
is_deeply( decode_json( $new_job->data ),
    $data, 'data retrieved and json encoded correctly' );
is( t::lib::Dates::compare( $new_job->enqueued_on, dt_from_string ),
    0, 'enqueued_on correctly filled with now()' );
is( $new_job->size,   $job_size,    'job size retrieved correctly' );
is( $new_job->status, "new",        'job has not started yet, status is new' );
is( $new_job->type,   "batch_test", 'job type retrieved from ->job_type' );

# Test cancelled job
$new_job->status('cancelled')->store;
my $processed_job =
  t::lib::Koha::BackgroundJob::BatchTest->process( { job_id => $new_job->id } );
is( $processed_job, undef );
$new_job->discard_changes;
is( $new_job->status, "cancelled", "A cancelled job has not been processed" );

# Test new job to process
$new_job->status('new')->store;
$new_job =
  t::lib::Koha::BackgroundJob::BatchTest->process( { job_id => $new_job->id } );
is( $new_job->status,             "finished", 'job is new finished!' );
is( scalar( @{ $new_job->messages } ), 10,    '10 messages generated' );
is_deeply(
    $new_job->report,
    { total_records => 10, total_success => 10 },
    'Correct number of records processed'
);

$schema->storage->txn_rollback;
