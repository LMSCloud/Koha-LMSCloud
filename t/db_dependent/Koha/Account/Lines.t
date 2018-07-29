#!/usr/bin/perl

# Copyright 2018 Koha Development team
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
# along with Koha; if not, see <http://www.gnu.org/licenses>

use Modern::Perl;

use Test::More tests => 2;

use Koha::Account::Lines;
use Koha::Items;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'item' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build( { source => 'Branch' } );
    my $biblioitem = $builder->build( { source => 'Biblioitem' } );
    my $patron = $builder->build( { source => 'Borrower' } );
    my $item = Koha::Item->new(
    {
        biblionumber     => $biblioitem->{biblionumber},
        biblioitemnumber => $biblioitem->{biblioitemnumber},
        homebranch       => $library->{branchcode},
        holdingbranch    => $library->{branchcode},
        barcode          => 'some_barcode_12',
        itype            => 'BK',
    })->store;

    my $line = Koha::Account::Line->new(
    {
        borrowernumber => $patron->{borrowernumber},
        itemnumber     => $item->itemnumber,
        accounttype    => "F",
        amount         => 10,
    })->store;

    my $account_line_item = $line->item;
    is( ref( $account_line_item ), 'Koha::Item', 'Koha::Account::Line->item should return a Koha::Item' );
    is( $line->itemnumber, $account_line_item->itemnumber, 'Koha::Account::Line->item should return the correct item' );

    $schema->storage->txn_rollback;
};

subtest 'total_outstanding' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $patron  = $builder->build_object({ class => 'Koha::Patrons' });

    my $lines = Koha::Account::Lines->search({ borrowernumber => $patron->id });
    is( $lines->total_outstanding, 0, 'total_outstanding returns 0 if no lines (undef case)' );

    my $debit_1 = Koha::Account::Line->new(
        {   borrowernumber    => $patron->id,
            accounttype       => "F",
            amount            => 10,
            amountoutstanding => 10
        }
    )->store;

    my $debit_2 = Koha::Account::Line->new(
        {   borrowernumber    => $patron->id,
            accounttype       => "F",
            amount            => 10,
            amountoutstanding => 10
        }
    )->store;

    $lines = Koha::Account::Lines->search({ borrowernumber => $patron->id });
    is( $lines->total_outstanding, 20, 'total_outstanding sums correctly' );

    my $credit_1 = Koha::Account::Line->new(
        {   borrowernumber    => $patron->id,
            accounttype       => "F",
            amount            => -10,
            amountoutstanding => -10
        }
    )->store;

    $lines = Koha::Account::Lines->search({ borrowernumber => $patron->id });
    is( $lines->total_outstanding, 10, 'total_outstanding sums correctly' );

    my $credit_2 = Koha::Account::Line->new(
        {   borrowernumber    => $patron->id,
            accounttype       => "F",
            amount            => -10,
            amountoutstanding => -10
        }
    )->store;

    $lines = Koha::Account::Lines->search({ borrowernumber => $patron->id });
    is( $lines->total_outstanding, 0, 'total_outstanding sums correctly' );

    my $credit_3 = Koha::Account::Line->new(
        {   borrowernumber    => $patron->id,
            accounttype       => "F",
            amount            => -100,
            amountoutstanding => -100
        }
    )->store;

    $lines = Koha::Account::Lines->search({ borrowernumber => $patron->id });
    is( $lines->total_outstanding, -100, 'total_outstanding sums correctly' );

    $schema->storage->txn_rollback;
};
