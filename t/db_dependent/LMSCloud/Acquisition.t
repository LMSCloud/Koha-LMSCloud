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

use Test::More tests => 5;
use Test::NoWarnings;
use Test::Exception;

use C4::Acquisition qw( GetBaskets GetBasketgroupsGeneric );

use Koha::Database;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'GetBaskets selects on plain, unquoted values' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $bookseller = $builder->build( { source => 'Aqbookseller' } );
    my $basket     = $builder->build(
        {
            source => 'Aqbasket',
            value  => {
                basketname   => 'LMS plain basket',
                booksellerid => $bookseller->{id},
            },
        }
    );

    my $hits = GetBaskets( { basketname => 'LMS plain basket' } );
    is( scalar @{$hits},        1,                   'a basket is found by its unquoted name' );
    is( $hits->[0]->{basketno}, $basket->{basketno}, 'the expected basket is returned' );

    $hits = GetBaskets( { basketno => $basket->{basketno} } );
    is( scalar @{$hits}, 1, 'a basket is found by its numeric key' );

    $hits = GetBaskets( { basketname => 'LMS basket that does not exist' } );
    is( scalar @{$hits}, 0, 'an unknown name matches nothing' );

    $schema->storage->txn_rollback;
};

subtest 'GetBaskets treats quotes in a value as data' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $bookseller = $builder->build( { source => 'Aqbookseller' } );
    my $quoted     = q{L-2026/O'Brien "Sonderband"};
    my $basket     = $builder->build(
        {
            source => 'Aqbasket',
            value  => {
                basketname   => $quoted,
                booksellerid => $bookseller->{id},
            },
        }
    );

    my $hits;
    lives_ok { $hits = GetBaskets( { basketname => $quoted } ) }
    'a name holding single and double quotes does not break the query';
    is( scalar @{$hits},        1,                   'the basket is found by its quoted name' );
    is( $hits->[0]->{basketno}, $basket->{basketno}, 'the expected basket is returned' );

    $schema->storage->txn_rollback;
};

subtest 'GetBaskets matches on several columns and honours extra clauses' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $bookseller = $builder->build( { source => 'Aqbookseller' } );
    my $other      = $builder->build( { source => 'Aqbookseller' } );

    my $first = $builder->build(
        {
            source => 'Aqbasket',
            value  => { basketname => 'LMS shared name', booksellerid => $bookseller->{id} },
        }
    );
    my $second = $builder->build(
        {
            source => 'Aqbasket',
            value  => { basketname => 'LMS shared name', booksellerid => $bookseller->{id} },
        }
    );
    $builder->build(
        {
            source => 'Aqbasket',
            value  => { basketname => 'LMS shared name', booksellerid => $other->{id} },
        }
    );

    my $hits = GetBaskets( { basketname => 'LMS shared name', booksellerid => $bookseller->{id} } );
    is( scalar @{$hits}, 2, 'both criteria are combined with AND' );

    $hits = GetBaskets( { basketname => 'LMS shared name', booksellerid => $bookseller->{id} }, { limit => 1 } );
    is( scalar @{$hits}, 1, 'the limit clause is applied' );

    $hits = GetBaskets(
        { basketname => 'LMS shared name', booksellerid => $bookseller->{id} },
        { orderby    => 'basketno DESC' }
    );
    is(
        $hits->[0]->{basketno}, ( sort { $b <=> $a } ( $first->{basketno}, $second->{basketno} ) )[0],
        'the orderby clause is applied'
    );

    $schema->storage->txn_rollback;
};

subtest 'GetBasketgroupsGeneric selects on plain, unquoted values' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $bookseller = $builder->build( { source => 'Aqbookseller' } );
    my $quoted     = q{R-2026/O'Brien "Sonderband"};

    my $group = $builder->build(
        {
            source => 'Aqbasketgroup',
            value  => { name => 'LMS plain group', booksellerid => $bookseller->{id} },
        }
    );
    my $quoted_group = $builder->build(
        {
            source => 'Aqbasketgroup',
            value  => { name => $quoted, booksellerid => $bookseller->{id} },
        }
    );

    my $hits = GetBasketgroupsGeneric( { name => 'LMS plain group', booksellerid => $bookseller->{id} } );
    is( scalar @{$hits},  1,            'a basket group is found by its unquoted name' );
    is( $hits->[0]->{id}, $group->{id}, 'the expected basket group is returned' );

    lives_ok { $hits = GetBasketgroupsGeneric( { name => $quoted, booksellerid => $bookseller->{id} } ) }
    'a name holding single and double quotes does not break the query';
    is( $hits->[0]->{id}, $quoted_group->{id}, 'the quoted basket group is returned' );

    $schema->storage->txn_rollback;
};
