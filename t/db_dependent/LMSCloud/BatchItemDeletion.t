#!/usr/bin/perl

# Copyright 2026 LMSCloud GmbH
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 2;
use Test::NoWarnings;

use JSON qw( encode_json );

use Koha::Database;
use Koha::BackgroundJob::BatchDeleteItem;
use Koha::Biblios;
use Koha::Items;
use Koha::Serials;
use Koha::Serial::Items;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# Bug 37115 upstream lets batch item deletion delete the serial issue
# linked to a deleted item. The upstream regression test only covers the
# case where the biblio is deleted too, which removes the serial via the
# serial.biblionumber FK cascade regardless of the option. This test
# pins the option's own effect: the serial must go (or stay) while the
# biblio survives because another item remains.
subtest 'delete_serial_issues honoured when the biblio survives' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $build_serial_setup = sub {
        my $biblio      = $builder->build_sample_biblio;
        my $serial_item = $builder->build_sample_item( { biblionumber => $biblio->id } );
        my $other_item  = $builder->build_sample_item( { biblionumber => $biblio->id } );
        my $serial = $builder->build_object( { class => 'Koha::Serials', value => { biblionumber => $biblio->id } } );
        $builder->build_object(
            {
                class => 'Koha::Serial::Items',
                value => { itemnumber => $serial_item->itemnumber, serialid => $serial->serialid }
            }
        );
        return ( $biblio, $serial_item, $other_item, $serial );
    };

    my $run_job = sub {
        my ($args) = @_;
        my $job = Koha::BackgroundJob::BatchDeleteItem->new(
            {
                status         => 'new',
                size           => 1,
                borrowernumber => undef,
                type           => 'batch_item_record_deletion',
                data           => encode_json($args),
            }
        )->store;
        $job->process($args);
    };

    my ( $biblio, $serial_item, $other_item, $serial ) = $build_serial_setup->();
    $run_job->(
        {
            record_ids           => [ $serial_item->id ],
            delete_biblios       => 1,
            delete_serial_issues => 1,
        }
    );

    is( Koha::Items->find( $serial_item->id ), undef, 'Serial-linked item deleted' );
    ok( Koha::Biblios->find( $biblio->id ), 'Biblio survives (second item remains)' );
    is(
        Koha::Serials->find( $serial->serialid ), undef,
        'Serial deleted through delete_serial_issues despite surviving biblio'
    );
    is( Koha::Serial::Items->find( $serial_item->id ), undef, 'Serial/item link deleted' );

    ( $biblio, $serial_item, $other_item, $serial ) = $build_serial_setup->();
    $run_job->(
        {
            record_ids           => [ $serial_item->id ],
            delete_biblios       => 1,
            delete_serial_issues => 0,
        }
    );

    is( Koha::Items->find( $serial_item->id ), undef, 'Serial-linked item deleted (option off)' );
    ok( Koha::Biblios->find( $biblio->id ), 'Biblio survives (option off)' );
    ok(
        Koha::Serials->find( $serial->serialid ),
        'Serial kept when delete_serial_issues is off'
    );
    is(
        Koha::Serial::Items->find( $serial_item->id ), undef,
        'Serial/item link removed by item-delete cascade'
    );

    $schema->storage->txn_rollback;
};
