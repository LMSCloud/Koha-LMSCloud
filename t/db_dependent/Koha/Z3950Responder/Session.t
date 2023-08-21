#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 3;
use t::lib::TestBuilder;
use C4::Items qw( GetMarcItem );

use Koha::AuthorisedValues;

BEGIN {
    use_ok('Koha::Z3950Responder');
    use_ok('Koha::Z3950Responder::Session');
}

my $builder = t::lib::TestBuilder->new;
my $schema  = Koha::Database->new->schema;

$schema->storage->txn_begin;

subtest 'add_item_status' => sub {

    plan tests => 3;

    ## FIRST ITEM HAS ALL THE STATUSES ##
    my $item_1 = $builder->build_sample_item(
        {
            onloan     => '2017-07-07',
            itemlost   => 1,
            notforloan => 1,
            damaged    => 1,
            withdrawn  => 1,
        }
    );
    my ( $itemtag, $itemsubfield ) = C4::Biblio::GetMarcFromKohaField( "items.itemnumber" );
    my $item_marc_1 = C4::Items::GetMarcItem( $item_1->biblionumber, $item_1->itemnumber );
    my $item_field_1 = scalar $item_marc_1->field($itemtag);
    $builder->build({ source => 'Reserve', value=> { itemnumber => $item_1->itemnumber } });
    $builder->build(
        {
            source => 'Branchtransfer',
            value  => {
                itemnumber    => $item_1->itemnumber,
                datearrived   => undef,
                datecancelled => undef,
                datesent      => \'NOW()',
            }
        }
    );
    ## END FIRST ITEM ##

    ## SECOND ITEM HAS NO STATUSES ##
    my $item_2 = $builder->build_sample_item;
    my $item_marc_2 = C4::Items::GetMarcItem( $item_2->biblionumber, $item_2->itemnumber );
    my $item_field_2 = scalar $item_marc_2->field($itemtag);
    ## END SECOND ITEM ##

    # We want to test the default values, so we remove custom status alias if present
    my $available = Koha::AuthorisedValues->find({ category => 'Z3950_STATUS', authorised_value => 'AVAILABLE' });
    $available->delete if $available;

    # Create the responder
    my $args={ PEER_NAME => 'PEER'};
    my $zR = Koha::Z3950Responder->new({add_item_status_subfield => 'k'});
    $zR->init_handler($args);

    $args->{HANDLE}->add_item_status($item_field_1);
    is($item_field_1->subfield('k'),"Checked Out, Lost, Not for Loan, Damaged, Withdrawn, In Transit, On Hold","All statuses added in one field as expected");

    $args->{HANDLE}->add_item_status($item_field_2);
    is($item_field_2->subfield('k'),'Available',"Available status added as expected");

    is($item_field_2->subfield( $itemsubfield ), $item_2->itemnumber, "Itemnumber not removed when status added");

};

$schema->storage->txn_rollback;
