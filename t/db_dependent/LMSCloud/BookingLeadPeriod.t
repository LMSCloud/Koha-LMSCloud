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

use Test::More tests => 3;
use Test::NoWarnings;

use C4::Calendar;
use Koha::Biblio::Availability::Booking;
use Koha::CirculationRules;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# Days of the item's map that carry the lead_floor warning, as offsets from today
sub lead_floor_days {
    my ($params) = @_;

    my $today  = dt_from_string->truncate( to => 'day' );
    my $result = Koha::Biblio::Availability::Booking->check(
        {
            biblio            => $params->{biblio},
            from              => $today,
            to                => $today->clone->add( days => 10 ),
            pickup_library_id => $params->{library}->branchcode,
            item_type_id      => $params->{item}->itype,
        }
    );

    my @days;
    for my $offset ( 0 .. 10 ) {
        my $cell = $result->{availability}->{ $today->clone->add( days => $offset )->ymd }->{ $params->{item}->id };
        push @days, $offset if $cell && $cell->{warnings}->{lead_floor};
    }
    return \@days;
}

sub setup {
    Koha::CirculationRules->search( { rule_name => { '-in' => [ 'bookings_lead_period', 'bookings_trail_period' ] } } )
        ->delete;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $itemtype = $builder->build_object( { class => 'Koha::ItemTypes' } );
    my $biblio   = $builder->build_sample_biblio;
    my $item =
        $builder->build_sample_item( { biblionumber => $biblio->id, bookable => 1, itype => $itemtype->itemtype } );

    Koha::CirculationRules->set_rules(
        {
            branchcode => $library->branchcode,
            itemtype   => $itemtype->itemtype,
            rules      => { bookings_lead_period => 2 },
        }
    );

    return ( $library, $biblio, $item );
}

subtest 'lead period from today counts calendar days without closed days' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my ( $library, $biblio, $item ) = setup();

    is_deeply(
        lead_floor_days( { library => $library, biblio => $biblio, item => $item } ),
        [ 0, 1 ], 'Today and tomorrow are inside a 2-day lead period'
    );

    $schema->storage->txn_rollback;
};

subtest 'lead period from today skips closed days of the pickup library' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my ( $library, $biblio, $item ) = setup();

    my $closed = dt_from_string->truncate( to => 'day' )->add( days => 1 );
    C4::Calendar->new( branchcode => $library->branchcode )->insert_single_holiday(
        day         => $closed->day,
        month       => $closed->month,
        year        => $closed->year,
        title       => 'Closed',
        description => 'Closed',
    );

    is_deeply(
        lead_floor_days( { library => $library, biblio => $biblio, item => $item } ),
        [ 0, 1, 2 ], 'The closed day does not count, so the lead period ends a day later'
    );

    $schema->storage->txn_rollback;
};
