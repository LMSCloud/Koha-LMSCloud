#!/usr/bin/perl

# Copyright 2026 LMSCloud GmbH
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
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;
use Test::More tests => 6;
use Test::NoWarnings;
use File::Slurp qw( read_file );
use YAML::XS;

use Koha::Database;
use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Koha::Illrequest shim' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    use_ok('Koha::Illrequest');
    can_ok( 'Koha::Illrequest', 'checkIfIllItem' );
    can_ok( 'Koha::Illrequest', 'can_patron_place_ill_in_opac' );

    t::lib::Mocks::mock_preference( 'IllModule', 0 );

    my $item = $builder->build_sample_item;
    my ( $is_ill, $request ) = Koha::Illrequest->checkIfIllItem( $item->unblessed );
    is( $is_ill,  0,     'checkIfIllItem returns 0 when IllModule is off' );
    is( $request, undef, 'checkIfIllItem returns undef request when IllModule is off' );

    t::lib::Mocks::mock_preference( 'IllModule',    1 );
    t::lib::Mocks::mock_preference( 'IllItemtypes', $item->itype );

    my ( $is_ill_on, $request_on ) = Koha::Illrequest->checkIfIllItem( $item->unblessed );
    is( $is_ill_on,  1,     'checkIfIllItem returns 1 when IllModule is on and itype matches' );
    is( $request_on, undef, 'checkIfIllItem returns undef request when no ILL request exists for biblio' );

    $schema->storage->txn_rollback;
};

subtest 'ZKSH ILL controllers' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    use_ok('Koha::REST::V1::ZKSH_illrequests');
    can_ok( 'Koha::REST::V1::ZKSH_illrequests', 'add' );

    my $swagger_content = read_file('api/v1/swagger/swagger.yaml');
    my $swagger         = YAML::XS::Load($swagger_content);

    ok( exists $swagger->{paths}{'/zksha_illrequests'}, 'Swagger defines /zksha_illrequests path' );
    ok( exists $swagger->{paths}{'/zkshp_illrequests'}, 'Swagger defines /zkshp_illrequests path' );

    $schema->storage->txn_rollback;
};

subtest 'ALV ILL controller' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    use_ok('Koha::REST::V1::ALV_illrequests');
    can_ok( 'Koha::REST::V1::ALV_illrequests', 'add' );

    my $swagger_content = read_file('api/v1/swagger/swagger.yaml');
    my $swagger         = YAML::XS::Load($swagger_content);

    ok( exists $swagger->{paths}{'/alv_illrequests'}, 'Swagger defines /alv_illrequests path' );

    $schema->storage->txn_rollback;
};

subtest 'SIP2 FeeDebit' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    use_ok('C4::SIP::ILS::Transaction::FeeDebit');

    my $fee_debit = C4::SIP::ILS::Transaction::FeeDebit->new();
    isa_ok( $fee_debit, 'C4::SIP::ILS::Transaction::FeeDebit' );
    isa_ok( $fee_debit, 'C4::SIP::ILS::Transaction' );

    use_ok('C4::SIP::Sip::Constants');
    C4::SIP::Sip::Constants->import(qw( FEE_DEBIT ));
    is( C4::SIP::Sip::Constants::FEE_DEBIT(), '43', 'FEE_DEBIT constant is defined as message type 43' );

    $schema->storage->txn_rollback;
};

subtest 'C4::SIP::ILS::Patron::_fee_limit threshold sub' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    use_ok('C4::SIP::ILS::Patron');

    t::lib::Mocks::mock_preference( 'noissuescharge', 12 );
    is( C4::SIP::ILS::Patron::_fee_limit(), 12, 'returns noissuescharge value when set to positive number' );

    t::lib::Mocks::mock_preference( 'noissuescharge', 0 );
    is( C4::SIP::ILS::Patron::_fee_limit(), 5, 'returns 5 fallback when noissuescharge is 0 (falsy)' );

    t::lib::Mocks::mock_preference( 'noissuescharge', undef );
    is( C4::SIP::ILS::Patron::_fee_limit(), 5, 'returns 5 fallback when noissuescharge is undef' );

    $schema->storage->txn_rollback;
};
