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
use Test::More tests => 10;
use Test::NoWarnings;

use File::Slurp qw( read_file );

use Koha::Database;
use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Reserves    qw( IsAvailableForItemLevelRequest ItemsAnyAvailableAndNotRestricted );
use C4::Circulation qw( GetBranchItemRule );
use Koha::Libraries;
use Koha::CirculationRules;
use Koha::Policy::Holds;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'EnableHoldsNotForLoanStatus syspref-driven notforloan check' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    Koha::CirculationRules->set_rules(
        {
            categorycode => '*',
            itemtype     => '*',
            branchcode   => '*',
            rules        => {
                onshelfholds => 0,
            }
        }
    );

    my $item_nfl_neg1 = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            notforloan   => -1,
        }
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1' );
    ok(
        C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is holdable when EnableHoldsNotForLoanStatus includes -1'
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is NOT holdable when EnableHoldsNotForLoanStatus is empty'
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '0' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is NOT holdable when EnableHoldsNotForLoanStatus is 0 (does not match -1)'
    );

    my $item_nfl_neg2 = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            notforloan   => -2,
        }
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1|-2' );
    ok(
        C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg1, $patron ),
        'notforloan=-1 item is holdable when EnableHoldsNotForLoanStatus is -1|-2'
    );
    ok(
        C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg2, $patron ),
        'notforloan=-2 item is holdable when EnableHoldsNotForLoanStatus is -1|-2'
    );

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_neg2, $patron ),
        'notforloan=-2 item is NOT holdable when EnableHoldsNotForLoanStatus is only -1'
    );

    my $item_nfl_pos = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            notforloan   => 1,
        }
    );
    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1|-2|1' );
    ok(
        !C4::Reserves::IsAvailableForItemLevelRequest( $item_nfl_pos, $patron ),
        'notforloan=1 (positive) item is always blocked regardless of EnableHoldsNotForLoanStatus (early return in function)'
    );

    Koha::CirculationRules->set_rules(
        {
            categorycode => '*',
            itemtype     => '*',
            branchcode   => '*',
            rules        => {
                onshelfholds => 2,
            }
        }
    );

    Koha::Cache::Memory::Lite->get_instance->flush;

    t::lib::Mocks::mock_preference( 'EnableHoldsNotForLoanStatus', '-1|-2' );

    my $result = ItemsAnyAvailableAndNotRestricted( { biblionumber => $biblio->biblionumber, patron => $patron } );
    is(
        $result, 0,
        'ItemsAnyAvailableAndNotRestricted returns 0 when all items have negative notforloan and EnableHoldsNotForLoanStatus matches them (items treated as unavailable via notforloan)'
    );

    $schema->storage->txn_rollback;
};

subtest 'Mobile branch (get_effective_branch) in C4::Reserves' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $source = read_file('C4/Reserves.pm');
    like( $source, qr/use Koha::Libraries/, 'C4::Reserves imports Koha::Libraries' );
    like(
        $source,
        qr/Koha::Libraries->get_effective_branch/,
        'C4::Reserves references get_effective_branch'
    );

    can_ok( 'Koha::Libraries', 'get_effective_branch' );

    my $parent_library = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => { mobilebranch => undef }
        }
    );

    my $result = Koha::Libraries->get_effective_branch( $parent_library->branchcode );
    is( $result, $parent_library->branchcode, 'get_effective_branch returns same branchcode when no mobilebranch set' );

    my $mobile_station = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => { mobilebranch => $parent_library->branchcode }
        }
    );

    $result = Koha::Libraries->get_effective_branch( $mobile_station->branchcode );
    is( $result, $parent_library->branchcode, 'get_effective_branch returns parent branchcode for mobile station' );

    $schema->storage->txn_rollback;
};

subtest 'NoticeFees and SuppressNotificationOnHolds in C4::Reserves' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $source = read_file('C4/Reserves.pm');

    like( $source, qr/use C4::NoticeFees/, 'C4::Reserves imports C4::NoticeFees' );
    like(
        $source,
        qr/C4::NoticeFees->new\(\)/,
        'C4::Reserves instantiates C4::NoticeFees in _koha_notify_reserve'
    );

    like(
        $source,
        qr/SuppressNotificationOnHolds/,
        'C4::Reserves references SuppressNotificationOnHolds syspref'
    );

    use_ok('C4::NoticeFees');

    $schema->storage->txn_rollback;
};

subtest 'ILL hold fee check in AddReserve' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $source = read_file('C4/Reserves.pm');

    like( $source, qr/use Koha::Illrequest/, 'C4::Reserves imports Koha::Illrequest' );
    like(
        $source,
        qr/Koha::Illrequest->checkIfIllItem/,
        'AddReserve calls Koha::Illrequest->checkIfIllItem'
    );
    like(
        $source,
        qr/IllModule.*checkIfIllItem|checkIfIllItem.*IllModule/s,
        'ILL check is gated behind IllModule syspref'
    );
    like(
        $source,
        qr/reservefee_acceptable/,
        'AddReserve uses reservefee_acceptable flag to gate hold fee charging'
    );

    t::lib::Mocks::mock_preference( 'IllModule', 1 );

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio       = $builder->build_sample_biblio;
    my $ill_itemtype = 'ILL_T';

    my $itemtype_obj = Koha::ItemTypes->find($ill_itemtype);
    if ($itemtype_obj) {
        $itemtype_obj->delete;
    }
    $builder->build_object(
        {
            class => 'Koha::ItemTypes',
            value => { itemtype => $ill_itemtype, notforloan => 0 }
        }
    );

    my $item = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            library      => $library->branchcode,
            itype        => $ill_itemtype,
        }
    );

    t::lib::Mocks::mock_preference( 'IllItemtypes', $ill_itemtype );

    my ( $is_ill, $request ) = Koha::Illrequest->checkIfIllItem( $item->unblessed );
    is( $is_ill, 1, 'checkIfIllItem correctly identifies item with ILL itemtype as an ILL item' );

    $schema->storage->txn_rollback;
};

subtest 'Pickup branch resolves correctly for each SetPickupLocationOfReservedItems value' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    # opac/opac-reserve.pl is a CGI and cannot be eval'd/called cleanly, so this
    # transcribes its item-level branch-selection block (~L214-273, with
    # OPACAllowUserToChooseBranch disabled) and drives it against the REAL functions
    # it depends on (holds_control_library, GetBranchItemRule, the item accessors).
    # It verifies the decision logic and the SetPickupLocationOfReservedItems values;
    # it does not by itself prove the CGI still wires these together (no clean seam).
    my $resolve_pickup_branch = sub {
        my ( $item, $patron ) = @_;

        # L214-217: user cannot choose the branch -> default to patron home
        my $branch = $patron->branchcode;

        # L223-236: with a specific item, the community hold-fulfillment policy decides
        if ( !C4::Context->preference('OPACAllowUserToChooseBranch') && $item ) {
            my $type                    = $item->effective_itemtype;
            my $reserves_control_branch = Koha::Policy::Holds->holds_control_library( $item, $patron );
            my $rule                    = GetBranchItemRule( $reserves_control_branch, $type );

            if ( $rule->{hold_fulfillment_policy} eq 'any' || $rule->{hold_fulfillment_policy} eq 'patrongroup' ) {
                $branch = $patron->branchcode;
            } elsif ( $rule->{hold_fulfillment_policy} eq 'holdgroup' ) {
                $branch = $item->homebranch;
            } else {
                my $policy = $rule->{hold_fulfillment_policy};
                $branch = $item->$policy;
            }
        }

        # L266-273: the LMSCloud override
        if ( C4::Context->preference('SetPickupLocationOfReservedItems')
            && !C4::Context->preference('OPACAllowUserToChooseBranch') )
        {
            my $pickUpBranch = C4::Context->preference('SetPickupLocationOfReservedItems');
            if ( $pickUpBranch && $item->$pickUpBranch ) {
                $branch = $item->$pickUpBranch;
            }
        }

        return $branch;
    };

    # Three distinct libraries so patron-home / item-home / item-holding never collide.
    my $patron_home  = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $item_home    = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $item_holding = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );

    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $patron_home->branchcode } } );

    my $biblio = $builder->build_sample_biblio;
    my $item   = $builder->build_sample_item(
        {
            biblionumber  => $biblio->biblionumber,
            library       => $item_home->branchcode,       # homebranch
            holdingbranch => $item_holding->branchcode,    # distinct holding branch
        }
    );

    t::lib::Mocks::mock_preference( 'OPACAllowUserToChooseBranch', 0 );
    t::lib::Mocks::mock_preference( 'ReservesControlBranch',       'PatronLibrary' );

    # Default hold-fulfillment policy ("any") so the empty-value case falls through
    # to the patron's home library.
    Koha::CirculationRules->set_rules(
        {
            branchcode => undef,
            itemtype   => undef,
            rules      => { hold_fulfillment_policy => 'any' },
        }
    );

    t::lib::Mocks::mock_preference( 'SetPickupLocationOfReservedItems', 'homebranch' );
    is(
        $resolve_pickup_branch->( $item, $patron ),
        $item_home->branchcode,
        q{'home library of the item' (homebranch) -> item's owning library}
    );

    t::lib::Mocks::mock_preference( 'SetPickupLocationOfReservedItems', 'holdingbranch' );
    is(
        $resolve_pickup_branch->( $item, $patron ),
        $item_holding->branchcode,
        q{'holding library of the item' (holdingbranch) -> item's holding library}
    );

    t::lib::Mocks::mock_preference( 'SetPickupLocationOfReservedItems', '' );
    is(
        $resolve_pickup_branch->( $item, $patron ),
        $patron_home->branchcode,
        q{'patron's home library' (empty) -> patron home, when hold_fulfillment_policy is 'any'}
    );

    # GOTCHA: the empty value is NOT a hard guarantee of the patron's home library --
    # it defers to the community hold-fulfillment policy. If the governing rule is
    # item-based, the empty setting silently yields the item's branch instead.
    Koha::CirculationRules->set_rules(
        {
            branchcode => undef,
            itemtype   => undef,
            rules      => { hold_fulfillment_policy => 'homebranch' },
        }
    );
    t::lib::Mocks::mock_preference( 'SetPickupLocationOfReservedItems', '' );
    is(
        $resolve_pickup_branch->( $item, $patron ),
        $item_home->branchcode,
        q{empty value defers to hold_fulfillment_policy 'homebranch' -> item's branch, NOT patron home}
    );

    # And a non-empty override still wins over an item-based fulfillment policy.
    t::lib::Mocks::mock_preference( 'SetPickupLocationOfReservedItems', 'holdingbranch' );
    is(
        $resolve_pickup_branch->( $item, $patron ),
        $item_holding->branchcode,
        q{non-empty override wins over hold_fulfillment_policy 'homebranch'}
    );

    $schema->storage->txn_rollback;
};

subtest 'Hold fees: not_always and issued_or_reserved, with unavailable items counted as issued' => sub {
    plan tests => 12;

    $schema->storage->txn_begin;

    my $category = $builder->build_object( { class => 'Koha::Patron::Categories', value => { reservefee => 2 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );
    my $other = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $fee = sub {
        my ( $mode, $biblio ) = @_;
        t::lib::Mocks::mock_preference( 'HoldFeeMode', $mode );
        return C4::Reserves::GetReserveFee( $patron->borrowernumber, $biblio->biblionumber ) + 0;
    };

    my $item   = $builder->build_sample_item;
    my $biblio = $item->biblio;
    is( $fee->( 'not_always',         $biblio ), 0, 'not_always: available, no other holds' );
    is( $fee->( 'issued_or_reserved', $biblio ), 0, 'issued_or_reserved: available, no other holds' );

    my $hold = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => { biblionumber => $biblio->biblionumber, borrowernumber => $other->borrowernumber }
        }
    );
    is( $fee->( 'not_always',         $biblio ), 0, 'not_always: available, another hold' );
    is( $fee->( 'issued_or_reserved', $biblio ), 2, 'issued_or_reserved: available, another hold' );

    $hold->delete;
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { itemnumber => $item->itemnumber, borrowernumber => $other->borrowernumber }
        }
    );
    is( $fee->( 'not_always',         $biblio ), 0, 'not_always: checked out, no other holds' );
    is( $fee->( 'issued_or_reserved', $biblio ), 2, 'issued_or_reserved: checked out, no other holds' );

    $builder->build_object(
        {
            class => 'Koha::Holds',
            value => { biblionumber => $biblio->biblionumber, borrowernumber => $other->borrowernumber }
        }
    );
    is( $fee->( 'not_always',         $biblio ), 2, 'not_always: checked out, another hold' );
    is( $fee->( 'issued_or_reserved', $biblio ), 2, 'issued_or_reserved: checked out, another hold' );

    foreach my $status (qw( itemlost withdrawn notforloan damaged )) {
        my $unavailable = $builder->build_sample_item( { $status => 1 } );
        is( $fee->( 'issued_or_reserved', $unavailable->biblio ), 2, "a $status item is not available" );
    }

    $schema->storage->txn_rollback;
};

subtest 'Hold notices: notice fee, discarded home libraries, suppression and print fallback' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'SuppressNotificationOnHolds',          0 );
    t::lib::Mocks::mock_preference( 'DiscardHoldsNoticeFeeOfHomeLibraries', '' );
    t::lib::Mocks::mock_preference( 'EmailFieldPrimary',                    'email' );
    $schema->resultset('NoticeFeeRule')->delete;
    $builder->build(
        {
            source => 'NoticeFeeRule',
            value  => {
                branchcode => '*', categorycode => '*', message_transport_type => '*', letter_code => 'HOLD',
                notice_fee => 0.5
            }
        }
    );
    Koha::Notice::Templates->search( { module => 'reserves', code => 'HOLD' } )->delete;
    for my $mtt (qw( email print )) {
        $builder->build(
            {
                source => 'Letter',
                value  => {
                    module => 'reserves', code    => 'HOLD', branchcode => '', message_transport_type => $mtt,
                    lang   => 'default',  is_html => 0,      content    => 'Your hold is waiting',
                }
            }
        );
    }

    my $library    = $builder->build_object( { class => 'Koha::Libraries' } );
    my $attribute  = Koha::Patron::MessagePreference::Attributes->find( { message_name => 'Hold_Filled' } );
    my $new_patron = sub {
        my ($with_email_preference) = @_;
        my $patron = $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => { branchcode => $library->branchcode, email => 'hold@example.com', smsalertnumber => undef }
            }
        );
        C4::Members::Messaging::SetMessagingPreference(
            {
                borrowernumber          => $patron->borrowernumber,
                message_attribute_id    => $attribute->message_attribute_id,
                message_transport_types => ['email'],
                wants_digest            => 0,
            }
        ) if $with_email_preference;
        return $patron;
    };
    my $notify = sub {
        my ($patron) = @_;
        my $item     = $builder->build_sample_item( { library => $library->branchcode } );
        my $hold     = $builder->build_object(
            {
                class => 'Koha::Holds',
                value => {
                    borrowernumber => $patron->borrowernumber, biblionumber => $item->biblionumber,
                    itemnumber     => $item->itemnumber, branchcode => $library->branchcode, found => 'W',
                }
            }
        );
        C4::Reserves::_koha_notify_reserve( $hold->id );
        return $item;
    };
    my $sent = sub {
        my ($patron) = @_;
        return [ map { $_->message_transport_type }
                Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'HOLD' } )
                ->as_list ];
    };
    my $fees = sub {
        my ($patron) = @_;
        return [
            map { sprintf '%.2f', $_->amount } Koha::Account::Lines->search(
                { borrowernumber => $patron->borrowernumber, debit_type_code => 'NOTIFICATION' }
            )->as_list
        ];
    };

    my $charged = $new_patron->(1);
    my $item    = $notify->($charged);
    is_deeply( $sent->($charged), ['email'], 'the hold notice is sent' );
    is_deeply( $fees->($charged), ['0.50'],  'and charged by the HOLD notice fee rule' );

    t::lib::Mocks::mock_preference( 'DiscardHoldsNoticeFeeOfHomeLibraries', 'NOPE|' . $library->branchcode );
    my $discarded = $new_patron->(1);
    $notify->($discarded);
    is_deeply( $sent->($discarded), ['email'], 'an item of a discarded home library is notified' );
    is_deeply( $fees->($discarded), [],        'but not charged' );

    t::lib::Mocks::mock_preference( 'DiscardHoldsNoticeFeeOfHomeLibraries', '' );
    my $no_transport = $new_patron->(0);
    $notify->($no_transport);
    is_deeply( $sent->($no_transport), ['print'], 'a patron without transports gets a print notice' );

    t::lib::Mocks::mock_preference( 'SuppressNotificationOnHolds', 1 );
    my $suppressed = $new_patron->(1);
    $notify->($suppressed);
    is_deeply( $sent->($suppressed), [], 'SuppressNotificationOnHolds: no notice' );
    is_deeply( $fees->($suppressed), [], 'and no fee' );

    $schema->storage->txn_rollback;
};

subtest 'Bookmobile station patrons may hold items of their parent library' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'ReservesControlBranch', 'ItemHomeLibrary' );
    Koha::CirculationRules->set_rules(
        {
            categorycode => undef, branchcode => undef, itemtype => undef,
            rules        => { reservesallowed => 10, holds_per_record => 10, holds_per_day => 10 }
        }
    );
    Koha::CirculationRules->set_rules(
        {
            branchcode => undef, itemtype => undef,
            rules      =>
                { holdallowed => 'from_home_library', hold_fulfillment_policy => 'any', returnbranch => 'homebranch' }
        }
    );

    my $parent = $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } );
    my $station =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => $parent->branchcode } } );
    my $other = $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } );
    my $item  = $builder->build_sample_item( { library => $parent->branchcode } );

    my $status = sub {
        my ($library) = @_;
        my $patron =
            $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
        Koha::Cache::Memory::Lite->flush;
        return C4::Reserves::CanItemBeReserved( $patron, $item )->{status};
    };
    is( $status->($station), 'OK',                             'a station patron counts as the parent library' );
    is( $status->($other),   'cannotReserveFromOtherBranches', 'a patron of another library does not' );

    $schema->storage->txn_rollback;
};

subtest 'Holds on ILL items charge no hold fee unless the ILL backend accepts it' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'IllModule',   1 );
    t::lib::Mocks::mock_preference( 'HoldFeeMode', 'any_time_is_placed' );
    my $itemtype = $builder->build_object( { class => 'Koha::ItemTypes', value => { notforloan => 0 } } )->itemtype;
    t::lib::Mocks::mock_preference( 'IllItemtypes', $itemtype );

    my $library  = $builder->build_object( { class => 'Koha::Libraries',          value => { pickup_location => 1 } } );
    my $category = $builder->build_object( { class => 'Koha::Patron::Categories', value => { reservefee      => 2 } } );
    my $hold_fee = sub {
        my ($with_ill_request) = @_;
        my $patron = $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => { categorycode => $category->categorycode, branchcode => $library->branchcode }
            }
        );
        my $item = $builder->build_sample_item( { itype => $itemtype, library => $library->branchcode } );
        $builder->build_object(
            {
                class => 'Koha::ILL::Requests',
                value => { biblio_id => $item->biblionumber, backend => 'Standard', borrowernumber => $patron->id }
            }
        ) if $with_ill_request;
        C4::Reserves::AddReserve(
            {
                branchcode   => $library->branchcode, borrowernumber => $patron->borrowernumber,
                biblionumber => $item->biblionumber,  itemnumber     => $item->itemnumber, priority => 1,
            }
        );
        return Koha::Account::Lines->search(
            { borrowernumber => $patron->borrowernumber, debit_type_code => 'RESERVE' } )->count;
    };

    is( $hold_fee->(1), 0, 'an item of an ILL request: no hold fee' );
    is( $hold_fee->(0), 1, 'an item of the ILL item type without a request: the hold fee is charged' );

    $schema->storage->txn_rollback;
};
