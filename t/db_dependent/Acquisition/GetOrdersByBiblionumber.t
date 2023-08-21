#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use C4::Acquisition qw( NewBasket GetOrders GetOrdersByBiblionumber GetOrder );
use C4::Biblio qw( AddBiblio );
use C4::Budgets qw( AddBudget GetBudget );
use Koha::Database;
use Koha::Acquisition::Orders;

use MARC::Record;

#Start transaction
my $schema = Koha::Database->new()->schema();
$schema->storage->txn_begin();

my $bookseller = Koha::Acquisition::Bookseller->new(
    {
        name => "my vendor",
        address1 => "bookseller's address",
        phone => "0123456",
        active => 1
    }
)->store;

my $basketno = C4::Acquisition::NewBasket(
    $bookseller->id
);

my $budgetid = C4::Budgets::AddBudget(
    {
        budget_code => "budget_code_test",
        budget_name => "budget_name_test",
    }
);

my $budget = C4::Budgets::GetBudget( $budgetid );

my ($biblionumber1, $biblioitemnumber1) = AddBiblio(MARC::Record->new, '');
my ($biblionumber2, $biblioitemnumber2) = AddBiblio(MARC::Record->new, '');
my $order1 = Koha::Acquisition::Order->new(
    {
        basketno => $basketno,
        quantity => 24,
        biblionumber => $biblionumber1,
        budget_id => $budget->{budget_id},
    }
)->store;
my $ordernumber1 = $order1->ordernumber;

my $order2 = Koha::Acquisition::Order->new(
    {
        basketno => $basketno,
        quantity => 42,
        biblionumber => $biblionumber2,
        budget_id => $budget->{budget_id},
    }
)->store;
my $ordernumber2 = $order2->ordernumber;

my $order3 = Koha::Acquisition::Order->new(
    {
        basketno => $basketno,
        quantity => 4,
        biblionumber => $biblionumber2,
        budget_id => $budget->{budget_id},
    }
)->store;
my $ordernumber3 = $order3->ordernumber;

my @orders = GetOrdersByBiblionumber();
is(scalar(@orders), 0, 'GetOrdersByBiblionumber : no argument, return undef');

@orders = GetOrdersByBiblionumber( $biblionumber1 );
is(scalar(@orders), 1, '1 order on biblionumber 1');

@orders = GetOrdersByBiblionumber( $biblionumber2 );
is(scalar(@orders), 2, '2 orders on biblionumber 2');

#End transaction
$schema->storage->txn_rollback();

done_testing;
