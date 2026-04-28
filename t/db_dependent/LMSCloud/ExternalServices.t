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

use Test::More tests => 7;
use Test::NoWarnings;

use C4::Context;

use Koha::Database;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Brockhaus and Munzinger' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    use_ok('C4::External::Brockhaus');
    use_ok('C4::External::Munzinger');

    t::lib::Mocks::mock_preference( 'BrockhausCustomerID', 'test-customer-123' );
    is(
        C4::Context->preference('BrockhausCustomerID'),
        'test-customer-123',
        'BrockhausCustomerID syspref is accessible'
    );

    t::lib::Mocks::mock_preference( 'BrockhausDomain', 'brockhaus.de' );
    is(
        C4::Context->preference('BrockhausDomain'),
        'brockhaus.de',
        'BrockhausDomain syspref is accessible'
    );

    t::lib::Mocks::mock_preference( 'BrockhausSearchActive', '1' );
    is(
        C4::Context->preference('BrockhausSearchActive'),
        '1',
        'BrockhausSearchActive syspref is accessible'
    );

    t::lib::Mocks::mock_preference( 'MunzingerEncyclopediaSearchEnabled', '1' );
    is(
        C4::Context->preference('MunzingerEncyclopediaSearchEnabled'),
        '1',
        'MunzingerEncyclopediaSearchEnabled syspref is accessible'
    );

    $schema->storage->txn_rollback;
};

subtest 'Divibib integration' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    use_ok('C4::Divibib::NCIPService');
    use_ok('C4::External::DivibibPatronStatus');

    t::lib::Mocks::mock_preference( 'DivibibEnabled', '1' );
    is(
        C4::Context->preference('DivibibEnabled'),
        '1',
        'DivibibEnabled syspref is accessible'
    );

    $schema->storage->txn_rollback;
};

subtest 'Coverflow REST controllers' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    use_ok('Koha::REST::V1::CoverflowDataBiblionumber');
    use_ok('Koha::REST::V1::CoverflowDataNearbyItems');
    use_ok('Koha::REST::V1::CoverflowDataQuery');

    require YAML::XS;
    my $swagger = YAML::XS::LoadFile('api/v1/swagger/swagger.yaml');

    ok(
        exists $swagger->{paths}{'/public/coverflow_data_biblionumber/{biblio_ids}'},
        'Swagger path exists for /public/coverflow_data_biblionumber/{biblio_ids}'
    );
    ok(
        exists $swagger->{paths}{'/public/coverflow_data_nearby_items/{item_id}'},
        'Swagger path exists for /public/coverflow_data_nearby_items/{item_id}'
    );
    ok(
        exists $swagger->{paths}{'/public/coverflow_data_query'},
        'Swagger path exists for /public/coverflow_data_query'
    );

    $schema->storage->txn_rollback;
};

subtest 'BZSH order status' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    require YAML::XS;
    my $swagger = YAML::XS::LoadFile('api/v1/swagger/swagger.yaml');

    ok(
        exists $swagger->{paths}{'/bzsh/bib_updates'},
        'Swagger path exists for /bzsh/bib_updates'
    );
    ok(
        exists $swagger->{paths}{'/bzsh/id_mapping'},
        'Swagger path exists for /bzsh/id_mapping'
    );
    ok(
        exists $swagger->{paths}{'/bzsh/order_status'},
        'Swagger path exists for /bzsh/order_status'
    );

    use_ok('Koha::REST::V1::BZSH::OrderStatus');
    use_ok('Koha::REST::V1::BZSH::IdMapping');
    use_ok('Koha::REST::V1::BZSH::BibUpdates');
    use_ok('Koha::REST::V1::BZSH::ExternalOrder');
    use_ok('Koha::REST::V1::BZSH::ExternalOrderItemBiblionumberUpdates');

    $schema->storage->txn_rollback;
};

subtest 'Adhoc notices' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AdhocNoticesLetterCodes', 'ADHOC_TEST' );
    is(
        C4::Context->preference('AdhocNoticesLetterCodes'),
        'ADHOC_TEST',
        'AdhocNoticesLetterCodes syspref is accessible'
    );

    require C4::Letters;
    can_ok( 'C4::Letters', 'GetAdhocNoticeLetters' );

    $schema->storage->txn_rollback;
};

subtest 'EKZ integration' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    ok( -f 'external/ekz-media-services.pl', 'external/ekz-media-services.pl exists' );

    use_ok('C4::External::EKZ::EkzAuthentication');

    SKIP: {
        my $can_load_soap = eval { require SOAP::Lite; 1 };
        skip 'SOAP::Lite not installed, skipping BudgetCheckElement', 1 unless $can_load_soap;

        use_ok('C4::External::EKZ::BudgetCheckElement');
    }

    $schema->storage->txn_rollback;
};
