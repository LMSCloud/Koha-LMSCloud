#!/usr/bin/perl

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

use Modern::Perl;

use Test::More tests => 12;
use t::lib::TestBuilder;

use C4::Context;
use C4::Acquisition;
use C4::Biblio;
use C4::Items;
use C4::Budgets;
use t::lib::Mocks;

use Koha::Database;
use Koha::DateUtils;
use Koha::Acquisition::Booksellers;
use Koha::Acquisition::Orders;
use MARC::Record;

my $schema = Koha::Database->new()->schema();
$schema->storage->txn_begin();
my $dbh = C4::Context->dbh;
$dbh->{RaiseError} = 1;

my $builder = t::lib::TestBuilder->new;
my $itemtype = $builder->build({ source => 'Itemtype' })->{ itemtype };

my $bookseller = Koha::Acquisition::Bookseller->new(
    {
        name => "my vendor 1",
        address1 => "bookseller's address",
        phone => "0123456",
        active => 1
    }
)->store;
t::lib::Mocks::mock_preference('AcqCreateItem', 'receiving');

my $basketno1 = C4::Acquisition::NewBasket(
    $bookseller->id
);

my $budgetid = C4::Budgets::AddBudget(
    {
        budget_code => "budget_code_test_transferorder",
        budget_name => "budget_name_test_transferorder",
    }
);

my $budget = C4::Budgets::GetBudget( $budgetid );

my ($biblionumber, $biblioitemnumber) = AddBiblio(MARC::Record->new, '');
my $itemnumber = AddItem( { itype => $itemtype }, $biblionumber );

my $order = Koha::Acquisition::Order->new(
    {
        basketno => $basketno1,
        quantity => 2,
        biblionumber => $biblionumber,
        budget_id => $budget->{budget_id},
    }
)->store;
my $ordernumber = $order->ordernumber;

ModReceiveOrder(
    {
        biblionumber     => $biblionumber,
        order            => $order->unblessed,
        quantityreceived => 2,
    }
);

$order->add_item( $itemnumber );

CancelReceipt($ordernumber);

is(scalar GetItemnumbersFromOrder($ordernumber), 0, "Create items on receiving: 0 item exist after cancelling a receipt");

my $itemnumber1 = AddItem( { itype => $itemtype }, $biblionumber );
my $itemnumber2 = AddItem( { itype => $itemtype }, $biblionumber );

t::lib::Mocks::mock_preference('AcqCreateItem', 'ordering');
t::lib::Mocks::mock_preference('AcqItemSetSubfieldsWhenReceiptIsCancelled', '7=9'); # notforloan is mapped with 952$7
$order = Koha::Acquisition::Order->new(
    {
        basketno => $basketno1,
        quantity => 2,
        biblionumber => $biblionumber,
        budget_id => $budget->{budget_id},
    }
)->store;
$ordernumber = $order->ordernumber;

is( $order->parent_ordernumber, $order->ordernumber,
    "Insert an order should set parent_order=ordernumber, if no parent_ordernumber given"
);

$order->add_item( $itemnumber1 );
$order->add_item( $itemnumber2 );

is(
    scalar( GetItemnumbersFromOrder( $order->ordernumber ) ),
    2,
    "Create items on ordering: 2 items should be linked to the order before receiving"
);

my ( undef, $new_ordernumber ) = ModReceiveOrder(
    {
        biblionumber     => $biblionumber,
        order            => $order->unblessed,
        quantityreceived => 1,
        received_items   => [ $itemnumber1 ],
    }
);

my $new_order = GetOrder( $new_ordernumber );

is( $new_order->{ordernumber}, $new_ordernumber,
    "ModReceiveOrder should return a correct ordernumber" );
isnt( $new_ordernumber, $ordernumber,
    "ModReceiveOrder should return a different ordernumber" );
is( $new_order->{parent_ordernumber}, $ordernumber,
    "The new order created by ModReceiveOrder should be linked to the parent order"
);

is(
    scalar( GetItemnumbersFromOrder( $order->ordernumber ) ),
    1,
    "Create items on ordering: 1 item should still be linked to the original order after receiving"
);
is(
    scalar( GetItemnumbersFromOrder($new_ordernumber) ),
    1,
    "Create items on ordering: 1 item should be linked to new order after receiving"
);

CancelReceipt($new_ordernumber);

is(
    scalar( GetItemnumbersFromOrder($new_ordernumber) ),
    0,
    "Create items on ordering: no item should be linked to the cancelled order"
);
is(
    scalar( GetItemnumbersFromOrder( $order->ordernumber ) ),
    2,
    "Create items on ordering: items are not deleted after cancelling a receipt"
);

my $item1 = C4::Items::GetItem( $itemnumber1 );
is( $item1->{notforloan}, 9, "The notforloan value has been updated with '9'" );

my $item2 = C4::Items::GetItem( $itemnumber2 );
is( $item2->{notforloan}, 0, "The notforloan value has been updated with '9'" );

$schema->storage->txn_rollback();
