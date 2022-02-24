#!/usr/bin/perl

# Copyright 2019 Koha Development team
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 8;
use Test::Exception;
use Test::Warn;

use Koha::Database;
use Koha::DateUtils qw(dt_from_string);
use Koha::Patrons;
use Koha::Patron::Relationships;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'add_guarantor() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'borrowerRelationship', 'father1|father2' );

    my $patron_1 = $builder->build_object({ class => 'Koha::Patrons' });
    my $patron_2 = $builder->build_object({ class => 'Koha::Patrons' });

    throws_ok
        { $patron_1->add_guarantor({ guarantor_id => $patron_2->borrowernumber }); }
        'Koha::Exceptions::Patron::Relationship::InvalidRelationship',
        'Exception is thrown as no relationship passed';

    is( $patron_1->guarantee_relationships->count, 0, 'No guarantors added' );

    throws_ok
        { $patron_1->add_guarantor({ guarantor_id => $patron_2->borrowernumber, relationship => 'father' }); }
        'Koha::Exceptions::Patron::Relationship::InvalidRelationship',
        'Exception is thrown as a wrong relationship was passed';

    is( $patron_1->guarantee_relationships->count, 0, 'No guarantors added' );

    $patron_1->add_guarantor({ guarantor_id => $patron_2->borrowernumber, relationship => 'father1' });

    my $guarantors = $patron_1->guarantor_relationships;

    is( $guarantors->count, 1, 'No guarantors added' );

    {
        local *STDERR;
        open STDERR, '>', '/dev/null';
        throws_ok
            { $patron_1->add_guarantor({ guarantor_id => $patron_2->borrowernumber, relationship => 'father2' }); }
            'Koha::Exceptions::Patron::Relationship::DuplicateRelationship',
            'Exception is thrown for duplicated relationship';
        close STDERR;
    }

    $schema->storage->txn_rollback;
};

subtest 'relationships_debt() tests' => sub {

    plan tests => 168;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'borrowerRelationship', 'parent' );

    my $parent_1 = $builder->build_object({ class => 'Koha::Patrons', value => { firstname => "Parent 1" } });
    my $parent_2 = $builder->build_object({ class => 'Koha::Patrons', value => { firstname => "Parent 2" } });
    my $child_1 = $builder->build_object({ class => 'Koha::Patrons', value => { firstname => " Child 1" } });
    my $child_2 = $builder->build_object({ class => 'Koha::Patrons', value => { firstname => " Child 2" } });

    $child_1->add_guarantor({ guarantor_id => $parent_1->borrowernumber, relationship => 'parent' });
    $child_1->add_guarantor({ guarantor_id => $parent_2->borrowernumber, relationship => 'parent' });
    $child_2->add_guarantor({ guarantor_id => $parent_1->borrowernumber, relationship => 'parent' });
    $child_2->add_guarantor({ guarantor_id => $parent_2->borrowernumber, relationship => 'parent' });

    is( $child_1->guarantor_relationships->guarantors->count, 2, 'Child 1 has correct number of guarantors' );
    is( $child_2->guarantor_relationships->guarantors->count, 2, 'Child 2 has correct number of guarantors' );
    is( $parent_1->guarantee_relationships->guarantees->count, 2, 'Parent 1 has correct number of guarantees' );
    is( $parent_2->guarantee_relationships->guarantees->count, 2, 'Parent 2 has correct number of guarantees' );

    my $patrons = [ $parent_1, $parent_2, $child_1, $child_2 ];

    # First test: No debt
    my ($parent1_debt, $parent2_debt, $child1_debt, $child2_debt) = (0,0,0,0);
    _test_combinations($patrons, $parent1_debt,$parent2_debt,$child1_debt,$child2_debt);

    # Add debt to child_2
    $child2_debt = 2;
    $child_2->account->add_debit({ type => 'ACCOUNT', amount => $child2_debt, interface => 'commandline' });
    is( $child_2->account->non_issues_charges, $child2_debt, 'Debt added to Child 2' );
    _test_combinations($patrons, $parent1_debt,$parent2_debt,$child1_debt,$child2_debt);

    $parent1_debt = 3;
    $parent_1->account->add_debit({ type => 'ACCOUNT', amount => $parent1_debt, interface => 'commandline' });
    is( $parent_1->account->non_issues_charges, $parent1_debt, 'Debt added to Parent 1' );
    _test_combinations($patrons, $parent1_debt,$parent2_debt,$child1_debt,$child2_debt);

    $parent2_debt = 5;
    $parent_2->account->add_debit({ type => 'ACCOUNT', amount => $parent2_debt, interface => 'commandline' });
    is( $parent_2->account->non_issues_charges, $parent2_debt, 'Parent 2 owes correct amount' );
    _test_combinations($patrons, $parent1_debt,$parent2_debt,$child1_debt,$child2_debt);

    $child1_debt = 7;
    $child_1->account->add_debit({ type => 'ACCOUNT', amount => $child1_debt, interface => 'commandline' });
    is( $child_1->account->non_issues_charges, $child1_debt, 'Child 1 owes correct amount' );
    _test_combinations($patrons, $parent1_debt,$parent2_debt,$child1_debt,$child2_debt);

    $schema->storage->txn_rollback;
};

sub _test_combinations {
    my ( $patrons, $parent1_debt, $parent2_debt, $child1_debt, $child2_debt ) = @_;
    note("Testing with parent 1 debt $parent1_debt | Parent 2 debt $parent2_debt | Child 1 debt $child1_debt | Child 2 debt $child2_debt");
    # Options
    # P1 => P1 + C1 + C2 ( - P1 ) ( + P2 )
    # P2 => P2 + C1 + C2 ( - P2 ) ( + P1 )
    # C1 => P1 + P2 + C1 + C2 ( - C1 )
    # C2 => P1 + P2 + C1 + C2 ( - C2 )

# 3 params, count from 0 to 7 in binary ( 3 places ) to get the set of switches, then do that 4 times, one for each parent and child
    for my $i ( 0 .. 7 ) {
        my ( $only_this_guarantor, $include_guarantors, $include_this_patron )
          = split '', sprintf( "%03b", $i );
        note("---------------------");
        for my $patron ( @$patrons ) {
            if ( $only_this_guarantor
                && !$patron->guarantee_relationships->count )
            {
                throws_ok {
                    $patron->relationships_debt(
                        {
                            only_this_guarantor => $only_this_guarantor,
                            include_guarantors  => $include_guarantors,
                            include_this_patron => $include_this_patron
                        }
                    );
                }
                'Koha::Exceptions::BadParameter',
                  'Exception is thrown as patron is not a guarantor';

            }
            else {

                my $debt = 0;
                if ( $patron->firstname eq 'Parent 1' ) {
                    $debt += $parent1_debt if ($include_this_patron && $include_guarantors);
                    $debt += $child1_debt + $child2_debt;
                    $debt += $parent2_debt unless ($only_this_guarantor || !$include_guarantors);
                }
                elsif ( $patron->firstname eq 'Parent 2' ) {
                    $debt += $parent2_debt if ($include_this_patron & $include_guarantors);
                    $debt += $child1_debt + $child2_debt;
                    $debt += $parent1_debt unless ($only_this_guarantor || !$include_guarantors);
                }
                elsif ( $patron->firstname eq ' Child 1' ) {
                    $debt += $child1_debt if ($include_this_patron);
                    $debt += $child2_debt;
                    $debt += $parent1_debt + $parent2_debt if ($include_guarantors);
                }
                else {
                    $debt += $child2_debt if ($include_this_patron);
                    $debt += $child1_debt;
                    $debt += $parent1_debt + $parent2_debt if ($include_guarantors);
                }

                is(
                    $patron->relationships_debt(
                        {
                            only_this_guarantor => $only_this_guarantor,
                            include_guarantors  => $include_guarantors,
                            include_this_patron => $include_this_patron
                        }
                    ),
                    $debt,
                    $patron->firstname
                      . " debt of " . sprintf('%02d',$debt) . " calculated correctly for ( only_this_guarantor: $only_this_guarantor, include_guarantors: $include_guarantors, include_this_patron: $include_this_patron)"
                );
            }
        }
    }
}

subtest 'add_enrolment_fee_if_needed() tests' => sub {

    plan tests => 2;

    subtest 'category has enrolment fee' => sub {
        plan tests => 7;

        $schema->storage->txn_begin;

        my $category = $builder->build_object(
            {
                class => 'Koha::Patron::Categories',
                value => {
                    enrolmentfee => 20
                }
            }
        );

        my $patron = $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => {
                    categorycode => $category->categorycode
                }
            }
        );

        my $enrollment_fee = $patron->add_enrolment_fee_if_needed();
        is( $enrollment_fee * 1, 20, 'Enrolment fee amount is correct' );
        my $account = $patron->account;
        is( $patron->account->balance * 1, 20, 'Patron charged the enrolment fee' );
        # second enrolment fee, new
        $enrollment_fee = $patron->add_enrolment_fee_if_needed(0);
        # third enrolment fee, renewal
        $enrollment_fee = $patron->add_enrolment_fee_if_needed(1);
        is( $patron->account->balance * 1, 60, 'Patron charged the enrolment fees' );

        my @debits = $account->outstanding_debits;
        is( scalar @debits, 3, '3 enrolment fees' );
        is( $debits[0]->debit_type_code, 'ACCOUNT', 'Account type set correctly' );
        is( $debits[1]->debit_type_code, 'ACCOUNT', 'Account type set correctly' );
        is( $debits[2]->debit_type_code, 'ACCOUNT_RENEW', 'Account type set correctly' );

        $schema->storage->txn_rollback;
    };

    subtest 'no enrolment fee' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        my $category = $builder->build_object(
            {
                class => 'Koha::Patron::Categories',
                value => {
                    enrolmentfee => 0
                }
            }
        );

        my $patron = $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => {
                    categorycode => $category->categorycode
                }
            }
        );

        my $enrollment_fee = $patron->add_enrolment_fee_if_needed();
        is( $enrollment_fee * 1, 0, 'No enrolment fee' );
        my $account = $patron->account;
        is( $patron->account->balance, 0, 'Patron not charged anything' );

        my @debits = $account->outstanding_debits;
        is( scalar @debits, 0, 'no debits' );

        $schema->storage->txn_rollback;
    };
};

subtest 'to_api() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $patron_class = Test::MockModule->new('Koha::Patron');
    $patron_class->mock(
        'algo',
        sub { return 'algo' }
    );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                debarred => undef
            }
        }
    );

    my $restricted = $patron->to_api->{restricted};
    ok( defined $restricted, 'restricted is defined' );
    ok( !$restricted, 'debarred is undef, restricted evaluates to false' );

    $patron->debarred( dt_from_string->add( days => 1 ) )->store->discard_changes;
    $restricted = $patron->to_api->{restricted};
    ok( defined $restricted, 'restricted is defined' );
    ok( $restricted, 'debarred is defined, restricted evaluates to true' );

    my $patron_json = $patron->to_api({ embed => { algo => {} } });
    ok( exists $patron_json->{algo} );
    is( $patron_json->{algo}, 'algo' );

    $schema->storage->txn_rollback;
};

subtest 'login_attempts tests' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
        }
    );
    my $patron_info = $patron->unblessed;
    $patron->delete;
    delete $patron_info->{login_attempts};
    my $new_patron = Koha::Patron->new($patron_info)->store;
    is( $new_patron->discard_changes->login_attempts, 0, "login_attempts defaults to 0 as expected");

    $schema->storage->txn_rollback;
};

subtest 'is_superlibrarian() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',

            value => {
                flags => 16
            }
        }
    );

    is( $patron->is_superlibrarian, 0, 'Patron is not a superlibrarian and the method returns the correct value' );

    $patron->flags(1)->store->discard_changes;
    is( $patron->is_superlibrarian, 1, 'Patron is a superlibrarian and the method returns the correct value' );

    $patron->flags(0)->store->discard_changes;
    is( $patron->is_superlibrarian, 0, 'Patron is not a superlibrarian and the method returns the correct value' );

    $schema->storage->txn_rollback;
};

subtest 'extended_attributes' => sub {

    plan tests => 15;

    my $schema = Koha::Database->new->schema;
    $schema->storage->txn_begin;

    my $patron_1 = $builder->build_object({class=> 'Koha::Patrons'});
    my $patron_2 = $builder->build_object({class=> 'Koha::Patrons'});

    t::lib::Mocks::mock_userenv({ patron => $patron_1 });

    my $attribute_type1 = Koha::Patron::Attribute::Type->new(
        {
            code        => 'my code1',
            description => 'my description1',
            unique_id   => 1
        }
    )->store;
    my $attribute_type2 = Koha::Patron::Attribute::Type->new(
        {
            code             => 'my code2',
            description      => 'my description2',
            opac_display     => 1,
            staff_searchable => 1
        }
    )->store;

    my $new_library = $builder->build( { source => 'Branch' } );
    my $attribute_type_limited = Koha::Patron::Attribute::Type->new(
        { code => 'my code3', description => 'my description3' } )->store;
    $attribute_type_limited->library_limits( [ $new_library->{branchcode} ] );

    my $attributes_for_1 = [
        {
            attribute => 'my attribute1',
            code => $attribute_type1->code(),
        },
        {
            attribute => 'my attribute2',
            code => $attribute_type2->code(),
        },
        {
            attribute => 'my attribute limited',
            code => $attribute_type_limited->code(),
        }
    ];

    my $attributes_for_2 = [
        {
            attribute => 'my attribute12',
            code => $attribute_type1->code(),
        },
        {
            attribute => 'my attribute limited 2',
            code => $attribute_type_limited->code(),
        }
    ];

    my $extended_attributes = $patron_1->extended_attributes;
    is( ref($extended_attributes), 'Koha::Patron::Attributes', 'Koha::Patron->extended_attributes must return a Koha::Patron::Attribute set' );
    is( $extended_attributes->count, 0, 'There should not be attribute yet');

    $patron_1->extended_attributes->filter_by_branch_limitations->delete;
    $patron_2->extended_attributes->filter_by_branch_limitations->delete;
    $patron_1->extended_attributes($attributes_for_1);
    $patron_2->extended_attributes($attributes_for_2);

    my $extended_attributes_for_1 = $patron_1->extended_attributes;
    is( $extended_attributes_for_1->count, 3, 'There should be 3 attributes now for patron 1');

    my $extended_attributes_for_2 = $patron_2->extended_attributes;
    is( $extended_attributes_for_2->count, 2, 'There should be 2 attributes now for patron 2');

    my $attribute_12 = $extended_attributes_for_2->search({ code => $attribute_type1->code })->next;
    is( $attribute_12->attribute, 'my attribute12', 'search by code should return the correct attribute' );

    $attribute_12 = $patron_2->get_extended_attribute( $attribute_type1->code );
    is( $attribute_12->attribute, 'my attribute12', 'Koha::Patron->get_extended_attribute should return the correct attribute value' );

    my $expected_attributes_for_2 = [
        {
            code      => $attribute_type1->code(),
            attribute => 'my attribute12',
        },
        {
            code      => $attribute_type_limited->code(),
            attribute => 'my attribute limited 2',
        }
    ];
    # Sorting them by code
    $expected_attributes_for_2 = [ sort { $a->{code} cmp $b->{code} } @$expected_attributes_for_2 ];
    my @extended_attributes_for_2 = $extended_attributes_for_2->as_list;

    is_deeply(
        [
            {
                code      => $extended_attributes_for_2[0]->code,
                attribute => $extended_attributes_for_2[0]->attribute
            },
            {
                code      => $extended_attributes_for_2[1]->code,
                attribute => $extended_attributes_for_2[1]->attribute
            }
        ],
        $expected_attributes_for_2
    );

    # TODO - What about multiple? POD explains the problem
    my $non_existent = $patron_2->get_extended_attribute( 'not_exist' );
    is( $non_existent, undef, 'Koha::Patron->get_extended_attribute must return undef if the attribute does not exist' );

    # Test branch limitations
    t::lib::Mocks::mock_userenv({ patron => $patron_2 });
    # Return all
    $extended_attributes_for_1 = $patron_1->extended_attributes;
    is( $extended_attributes_for_1->count, 3, 'There should be 2 attributes for patron 1, the limited one should be returned');

    # Return filtered
    $extended_attributes_for_1 = $patron_1->extended_attributes->filter_by_branch_limitations;
    is( $extended_attributes_for_1->count, 2, 'There should be 2 attributes for patron 1, the limited one should be returned');

    # Not filtered
    my $limited_value = $patron_1->get_extended_attribute( $attribute_type_limited->code );
    is( $limited_value->attribute, 'my attribute limited', );

    ## Do we need a filtered?
    #$limited_value = $patron_1->get_extended_attribute( $attribute_type_limited->code );
    #is( $limited_value, undef, );

    $schema->storage->txn_rollback;

    subtest 'non-repeatable attributes tests' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        my $patron = $builder->build_object({ class => 'Koha::Patrons' });
        my $attribute_type = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { repeatable => 0 }
            }
        );

        is( $patron->extended_attributes->count, 0, 'Patron has no extended attributes' );

        throws_ok
            {
                $patron->extended_attributes(
                    [
                        { code => $attribute_type->code, attribute => 'a' },
                        { code => $attribute_type->code, attribute => 'b' }
                    ]
                );
            }
            'Koha::Exceptions::Patron::Attribute::NonRepeatable',
            'Exception thrown on non-repeatable attribute';

        is( $patron->extended_attributes->count, 0, 'Extended attributes storing rolled back' );

        $schema->storage->txn_rollback;

    };

    subtest 'unique attributes tests' => sub {

        plan tests => 5;

        $schema->storage->txn_begin;

        my $patron_1 = $builder->build_object({ class => 'Koha::Patrons' });
        my $patron_2 = $builder->build_object({ class => 'Koha::Patrons' });

        my $attribute_type_1 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { unique => 1 }
            }
        );

        my $attribute_type_2 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { unique => 0 }
            }
        );

        is( $patron_1->extended_attributes->count, 0, 'patron_1 has no extended attributes' );
        is( $patron_2->extended_attributes->count, 0, 'patron_2 has no extended attributes' );

        $patron_1->extended_attributes(
            [
                { code => $attribute_type_1->code, attribute => 'a' },
                { code => $attribute_type_2->code, attribute => 'a' }
            ]
        );

        throws_ok
            {
                $patron_2->extended_attributes(
                    [
                        { code => $attribute_type_1->code, attribute => 'a' },
                        { code => $attribute_type_2->code, attribute => 'a' }
                    ]
                );
            }
            'Koha::Exceptions::Patron::Attribute::UniqueIDConstraint',
            'Exception thrown on unique attribute';

        is( $patron_1->extended_attributes->count, 2, 'Extended attributes stored' );
        is( $patron_2->extended_attributes->count, 0, 'Extended attributes storing rolled back' );

        $schema->storage->txn_rollback;

    };

    subtest 'invalid type attributes tests' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        my $patron = $builder->build_object({ class => 'Koha::Patrons' });

        my $attribute_type_1 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { repeatable => 0 }
            }
        );

        my $attribute_type_2 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types'
            }
        );

        my $type_2 = $attribute_type_2->code;
        $attribute_type_2->delete;

        is( $patron->extended_attributes->count, 0, 'Patron has no extended attributes' );

        throws_ok
            {
                $patron->extended_attributes(
                    [
                        { code => $attribute_type_1->code, attribute => 'a' },
                        { code => $attribute_type_2->code, attribute => 'b' }
                    ]
                );
            }
            'Koha::Exceptions::Patron::Attribute::InvalidType',
            'Exception thrown on invalid attribute type';

        is( $patron->extended_attributes->count, 0, 'Extended attributes storing rolled back' );

        $schema->storage->txn_rollback;

    };

    subtest 'globally mandatory attributes tests' => sub {

        plan tests => 5;

        $schema->storage->txn_begin;

        my $patron = $builder->build_object({ class => 'Koha::Patrons' });

        my $attribute_type_1 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { mandatory => 1, class => 'a' }
            }
        );

        my $attribute_type_2 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { mandatory => 0, class => 'a' }
            }
        );

        is( $patron->extended_attributes->count, 0, 'Patron has no extended attributes' );

        throws_ok
            {
                $patron->extended_attributes(
                    [
                        { code => $attribute_type_2->code, attribute => 'b' }
                    ]
                );
            }
            'Koha::Exceptions::Patron::MissingMandatoryExtendedAttribute',
            'Exception thrown on missing mandatory attribute type';

        is( $@->type, $attribute_type_1->code, 'Exception parameters are correct' );

        is( $patron->extended_attributes->count, 0, 'Extended attributes storing rolled back' );

        $patron->extended_attributes(
            [
                { code => $attribute_type_1->code, attribute => 'b' }
            ]
        );

        is( $patron->extended_attributes->count, 1, 'Extended attributes succeeded' );

        $schema->storage->txn_rollback;

    };

};

subtest 'can_log_into() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                flags => undef
            }
        }
    );
    my $library = $builder->build_object({ class => 'Koha::Libraries' });

    t::lib::Mocks::mock_preference('IndependentBranches', 1);

    ok( $patron->can_log_into( $patron->library ), 'Patron can log into its own library' );
    ok( !$patron->can_log_into( $library ), 'Patron cannot log into different library, IndependentBranches on' );

    # make it a superlibrarian
    $patron->set({ flags => 1 })->store->discard_changes;
    ok( $patron->can_log_into( $library ), 'Superlibrarian can log into different library, IndependentBranches on' );

    t::lib::Mocks::mock_preference('IndependentBranches', 0);

    # No special permissions
    $patron->set({ flags => undef })->store->discard_changes;
    ok( $patron->can_log_into( $patron->library ), 'Patron can log into its own library' );
    ok( $patron->can_log_into( $library ), 'Patron can log into any library' );

    $schema->storage->txn_rollback;
};
