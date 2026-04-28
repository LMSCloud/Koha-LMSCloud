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

use C4::Context;
use C4::Letters qw( GetAdhocNoticeLetters GetMessagesById EnqueueLetter );

use Koha::Database;
use Koha::Notice::Messages;
use Koha::Patron::Relationships;
use Koha::Patrons;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

subtest 'Family card guarantor relationship validation' => sub {
    plan tests => 10;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $family_category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => {
                category_type    => 'A',
                family_card      => 1,
                can_be_guarantee => 0,
            },
        }
    );

    my $regular_adult_category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => {
                category_type    => 'A',
                family_card      => 0,
                can_be_guarantee => 1,
            },
        }
    );

    my $child_category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => {
                category_type    => 'C',
                family_card      => 0,
                can_be_guarantee => 1,
            },
        }
    );

    t::lib::Mocks::mock_preference( 'borrowerRelationship', 'parent|guardian' );

    my $guarantor = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $family_category->categorycode,
                branchcode   => $library->branchcode,
            },
        }
    );

    ok( $guarantor->is_family_card, 'Guarantor with family_card category returns true for is_family_card' );

    my $guarantee_child = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $child_category->categorycode,
                branchcode   => $library->branchcode,
            },
        }
    );

    my $relationship = $guarantee_child->add_guarantor(
        { guarantor_id => $guarantor->borrowernumber, relationship => 'parent' }
    );
    ok( $relationship, 'Successfully linked child guarantee to family card guarantor' );

    is(
        $guarantee_child->get_family_card_id, $guarantor->borrowernumber,
        'get_family_card_id returns the family card guarantor borrowernumber for child'
    );

    my $relationships = $guarantee_child->guarantor_relationships;
    ok(
        $relationships->hasFamilyCardRelationship,
        'hasFamilyCardRelationship returns true when guarantor has family card category'
    );

    my $guarantee_adult = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $regular_adult_category->categorycode,
                branchcode   => $library->branchcode,
            },
        }
    );

    my $adult_relationship = $guarantee_adult->add_guarantor(
        { guarantor_id => $guarantor->borrowernumber, relationship => 'guardian' }
    );
    ok( $adult_relationship, 'Successfully linked adult guarantee to family card guarantor' );

    is(
        $guarantee_adult->get_family_card_id, $guarantor->borrowernumber,
        'get_family_card_id returns the family card guarantor borrowernumber for adult member'
    );

    my $standalone_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $regular_adult_category->categorycode,
                branchcode   => $library->branchcode,
            },
        }
    );

    is( $standalone_patron->get_family_card_id, undef, 'get_family_card_id returns undef for patron without guarantor' );
    ok( !$standalone_patron->is_family_card, 'Patron with regular category returns false for is_family_card' );

    my $non_family_guarantor = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $regular_adult_category->categorycode,
                branchcode   => $library->branchcode,
            },
        }
    );

    my $non_family_child = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $child_category->categorycode,
                branchcode   => $library->branchcode,
            },
        }
    );

    $non_family_child->add_guarantor(
        { guarantor_id => $non_family_guarantor->borrowernumber, relationship => 'parent' }
    );

    my $nf_relationships = $non_family_child->guarantor_relationships;
    ok(
        !$nf_relationships->hasFamilyCardRelationship,
        'hasFamilyCardRelationship returns false when guarantor does not have family card'
    );

    is(
        $non_family_child->get_family_card_id, undef,
        'get_family_card_id returns undef when guarantor does not have family card'
    );

    $schema->storage->txn_rollback;
};

subtest 'GetAdhocNoticeLetters' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    $dbh->do(q|DELETE FROM letter|);

    $dbh->do(
        q|INSERT INTO letter (module, code, branchcode, name, title, content, message_transport_type)
          VALUES ('circulation', 'ADHOC_OVERDUE', '', 'Adhoc Overdue', 'Overdue', 'Content', 'email')|
    );
    $dbh->do(
        q|INSERT INTO letter (module, code, branchcode, name, title, content, message_transport_type)
          VALUES ('members', 'ADHOC_WELCOME', '', 'Adhoc Welcome', 'Welcome', 'Content', 'email')|
    );
    $dbh->do(
        q|INSERT INTO letter (module, code, branchcode, name, title, content, message_transport_type)
          VALUES ('circulation', 'ODUE', '', 'Overdue Notice', 'Overdue', 'Content', 'email')|
    );
    $dbh->do(
        q|INSERT INTO letter (module, code, branchcode, name, title, content, message_transport_type)
          VALUES ('suggestions', 'ADHOC_SUGGEST', '', 'Adhoc Suggestion', 'Suggestion', 'Content', 'email')|
    );
    $dbh->do(
        q|INSERT INTO letter (module, code, branchcode, name, title, content, message_transport_type)
          VALUES ('acquisitions', 'ADHOC_ACQ', '', 'Adhoc Acquisitions', 'Acq', 'Content', 'email')|
    );

    t::lib::Mocks::mock_preference( 'AdhocNoticesLetterCodes', 'ADHOC_*' );

    my $letters = GetAdhocNoticeLetters();
    ok( ref $letters eq 'ARRAY', 'GetAdhocNoticeLetters returns an arrayref' );

    my @codes = map { $_->{code} } @$letters;

    ok(
        ( grep { $_ eq 'ADHOC_OVERDUE' } @codes ),
        'Wildcard ADHOC_* matches ADHOC_OVERDUE in circulation module'
    );
    ok(
        ( grep { $_ eq 'ADHOC_WELCOME' } @codes ),
        'Wildcard ADHOC_* matches ADHOC_WELCOME in members module'
    );
    ok(
        ( grep { $_ eq 'ADHOC_SUGGEST' } @codes ),
        'Wildcard ADHOC_* matches ADHOC_SUGGEST in suggestions module'
    );
    ok(
        !( grep { $_ eq 'ADHOC_ACQ' } @codes ),
        'ADHOC_ACQ in acquisitions module is NOT returned (only circulation, members, reserves, suggestions)'
    );

    $schema->storage->txn_rollback;
};

subtest 'GetMessagesById' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode },
        }
    );

    my $message_id_1 = C4::Letters::EnqueueLetter(
        {
            borrowernumber         => $patron->borrowernumber,
            message_transport_type => 'email',
            letter                 => {
                content      => 'Test message one',
                title        => 'Test Subject 1',
                code         => 'TEST_MSG_1',
                content_type => 'text/plain',
            },
        }
    );
    ok( $message_id_1, 'First test message enqueued successfully' );

    my $message_id_2 = C4::Letters::EnqueueLetter(
        {
            borrowernumber         => $patron->borrowernumber,
            message_transport_type => 'email',
            letter                 => {
                content      => 'Test message two',
                title        => 'Test Subject 2',
                code         => 'TEST_MSG_2',
                content_type => 'text/plain',
            },
        }
    );
    ok( $message_id_2, 'Second test message enqueued successfully' );

    my $messages = GetMessagesById( { message_id => [ $message_id_1, $message_id_2 ] } );
    is( scalar @$messages, 2, 'GetMessagesById returns both messages when passed an arrayref of IDs' );

    my %returned_ids = map { $_->{message_id} => 1 } @$messages;
    ok(
        $returned_ids{$message_id_1} && $returned_ids{$message_id_2},
        'Returned messages contain the correct message IDs'
    );

    $schema->storage->txn_rollback;
};

subtest 'EnqueueLetter branchcode propagation' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    ok(
        Koha::Database->new->schema->source('MessageQueue')->has_column('branchcode'),
        'MessageQueue schema has branchcode column'
    );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode },
        }
    );

    my $message_id = C4::Letters::EnqueueLetter(
        {
            borrowernumber         => $patron->borrowernumber,
            message_transport_type => 'print',
            branchcode             => $library->branchcode,
            letter                 => {
                content      => 'Branch test content',
                title        => 'Branch Test',
                code         => 'TEST_BRANCH',
                content_type => 'text/plain',
            },
        }
    );
    ok( $message_id, 'Message with branchcode enqueued successfully' );

    my $message = Koha::Notice::Messages->find($message_id);
    is( $message->branchcode, $library->branchcode, 'Enqueued message has the correct branchcode stored' );

    my $message_id_no_branch = C4::Letters::EnqueueLetter(
        {
            borrowernumber         => $patron->borrowernumber,
            message_transport_type => 'print',
            letter                 => {
                content      => 'No branch content',
                title        => 'No Branch Test',
                code         => 'TEST_NOBRANCH',
                content_type => 'text/plain',
            },
        }
    );

    my $msg_no_branch = Koha::Notice::Messages->find($message_id_no_branch);
    is( $msg_no_branch->branchcode, undef, 'Enqueued message without branchcode has NULL branchcode' );

    $schema->storage->txn_rollback;
};
