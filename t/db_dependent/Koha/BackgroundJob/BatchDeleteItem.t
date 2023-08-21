#!/usr/bin/perl

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

use Test::More tests => 1;

use Koha::Database;
use Koha::BackgroundJobs;
use Koha::BackgroundJob::BatchDeleteItem;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'enqueue() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $record_ids = [ 1, 2 ];

    my $job_id = Koha::BackgroundJob::BatchDeleteItem->new->enqueue( { record_ids => $record_ids } );
    my $job    = Koha::BackgroundJobs->find($job_id)->_derived_class;

    is( $job->size,   scalar @{$record_ids}, 'Size is correct' );
    is( $job->status, 'new',                 'Initial status set correctly' );
    is( $job->queue,  'long_tasks',          'BatchUpdateItem should use the long_tasks queue' );

    $schema->storage->txn_rollback;
};
