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

use Test::More tests => 21;
use Test::Exception;
use Test::Warn;

use Koha::CirculationRules;
use Koha::Database;
use Koha::DateUtils qw(dt_from_string);
use Koha::ArticleRequests;
use Koha::Patrons;
use Koha::Patron::Relationships;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Accessor tests' => sub {
    plan tests => 9;
    $schema->storage->txn_begin;

    my $object = Koha::Patron->new( { surname => 'Test Patron' } );
    is( $object->surname(), 'Test Patron', "Accessor returns correct value" );
    $object->surname('Test Patron Surname');
    is( $object->surname(), 'Test Patron Surname', "Accessor returns correct value after set" );

    my $object2 = Koha::Patron->new( { surname => 'Test Patron 2' } );
    is( $object2->surname(), 'Test Patron 2', "Accessor returns correct value" );
    $object2->surname('Test Patron Surname 2');
    is( $object2->surname(), 'Test Patron Surname 2', "Accessor returns correct value after set" );

    my $ret;
    $ret = $object2->set( { surname => "Test Patron Surname 3", firstname => "Test Firstname" } );
    ok( ref($ret) eq 'Koha::Patron', "Set returns object on success" );
    is( $object2->surname(),   "Test Patron Surname 3", "Set sets first field correctly" );
    is( $object2->firstname(), "Test Firstname",        "Set sets second field correctly" );

    our $patron = Koha::Patron->new(
        {
            borrowernumber      => '12345',
            cardnumber          => '1234567890',
            surname             => 'mySurname',
            firstname           => 'myFirstname',
            title               => 'Mr.',
            othernames          => 'myOthernames',
            initials            => 'MM',
            streetnumber        => '100',
            streettype          => 'Blvd',
            address             => 'my personal address',
            address2            => 'my adress2',
            city                => 'Marseille',
            state               => 'mystate',
            zipcode             => '13006',
            country             => 'France',
            email               => 'mySurname.myFirstname@email.com',
            phone               => '0402872934',
            mobile              => '0627884632',
            fax                 => '0402872935',
            emailpro            => 'myEmailPro@email.com',
            phonepro            => '0402873334',
            B_streetnumber      => '101',
            B_streettype        => 'myB_streettype',
            B_address           => 'myB_address',
            B_address2          => 'myB_address2',
            B_city              => 'myB_city',
            B_state             => 'myB_state',
            B_zipcode           => '23456',
            B_country           => 'myB_country',
            B_email             => 'myB_email',
            B_phone             => '0678353935',
            dateofbirth         => '1990-07-16',
            branchcode          => 'myBranCode',
            categorycode        => 'myCatCode',
            dateenrolled        => '2015-03-19',
            dateexpiry          => '2016-03-19',
            gonenoaddress       => '0',
            lost                => '0',
            debarred            => '2015-04-19',
            debarredcomment     => 'You are debarred',
            borrowernotes       => 'borrowernotes',
            sex                 => 'M',
            password            => 'hfkurhfe976634èj!',
            flags               => '55555',
            userid              => '87987',
            opacnote            => 'myOpacnote',
            contactnote         => 'myContactnote',
            sort1               => 'mySort1',
            sort2               => 'mySort2',
            altcontactfirstname => 'myAltcontactfirstname',
            altcontactsurname   => 'myAltcontactsurname',
            altcontactaddress1  => 'myAltcontactaddress1',
            altcontactaddress2  => 'myAltcontactaddress2',
            altcontactaddress3  => 'myAltcontactaddress3',
            altcontactstate     => 'myAltcontactstate',
            altcontactzipcode   => '465843',
            altcontactcountry   => 'myOtherCountry',
            altcontactphone     => 'myOtherphone',
            smsalertnumber      => '0683027346',
            privacy             => '667788',
        }
    );

    subtest 'Accessor tests after new' => sub {
        plan tests => 60;
        is( $patron->borrowernumber, '12345',               'borrowernumber accessor returns correct value' );
        is( $patron->cardnumber,     '1234567890',          'cardnumber accessor returns correct value' );
        is( $patron->surname,        'mySurname',           'surname accessor returns correct value' );
        is( $patron->firstname,      'myFirstname',         'firstname accessor returns correct value' );
        is( $patron->title,          'Mr.',                 'title accessor returns correct value' );
        is( $patron->othernames,     'myOthernames',        'othernames accessor returns correct value' );
        is( $patron->initials,       'MM',                  'initials accessor returns correct value' );
        is( $patron->streetnumber,   '100',                 'streetnumber accessor returns correct value' );
        is( $patron->streettype,     'Blvd',                'streettype accessor returns correct value' );
        is( $patron->address,        'my personal address', 'address accessor returns correct value' );
        is( $patron->address2,       'my adress2',          'address2 accessor returns correct value' );
        is( $patron->city,           'Marseille',           'city accessor returns correct value' );
        is( $patron->state,          'mystate',             'state accessor returns correct value' );
        is( $patron->zipcode,        '13006',               'zipcode accessor returns correct value' );
        is( $patron->country,        'France',              'country accessor returns correct value' );
        is( $patron->email,    'mySurname.myFirstname@email.com', 'email accessor returns correct value' );
        is( $patron->phone,    '0402872934',                      'phone accessor returns correct value' );
        is( $patron->mobile,   '0627884632',                      'mobile accessor returns correct value' );
        is( $patron->fax,      '0402872935',                      'fax accessor returns correct value' );
        is( $patron->emailpro, 'myEmailPro@email.com',            'emailpro accessor returns correct value' );
        is( $patron->phonepro, '0402873334',                      'phonepro accessor returns correct value' );
        is( $patron->B_streetnumber,  '101',               'B_streetnumber accessor returns correct value' );
        is( $patron->B_streettype,    'myB_streettype',    'B_streettype accessor returns correct value' );
        is( $patron->B_address,       'myB_address',       'B_address accessor returns correct value' );
        is( $patron->B_address2,      'myB_address2',      'B_address2 accessor returns correct value' );
        is( $patron->B_city,          'myB_city',          'B_city accessor returns correct value' );
        is( $patron->B_state,         'myB_state',         'B_state accessor returns correct value' );
        is( $patron->B_zipcode,       '23456',             'B_zipcode accessor returns correct value' );
        is( $patron->B_country,       'myB_country',       'B_country accessor returns correct value' );
        is( $patron->B_email,         'myB_email',         'B_email accessor returns correct value' );
        is( $patron->B_phone,         '0678353935',        'B_phone accessor returns correct value' );
        is( $patron->dateofbirth,     '1990-07-16',        'dateofbirth accessor returns correct value' );
        is( $patron->branchcode,      'myBranCode',        'branchcode accessor returns correct value' );
        is( $patron->categorycode,    'myCatCode',         'categorycode accessor returns correct value' );
        is( $patron->dateenrolled,    '2015-03-19',        'dateenrolled accessor returns correct value' );
        is( $patron->dateexpiry,      '2016-03-19',        'dateexpiry accessor returns correct value' );
        is( $patron->gonenoaddress,   '0',                 'gonenoaddress accessor returns correct value' );
        is( $patron->lost,            '0',                 'lost accessor returns correct value' );
        is( $patron->debarred,        '2015-04-19',        'debarred accessor returns correct value' );
        is( $patron->debarredcomment, 'You are debarred',  'debarredcomment accessor returns correct value' );
        is( $patron->borrowernotes,   'borrowernotes',     'borrowernotes accessor returns correct value' );
        is( $patron->sex,             'M',                 'sex accessor returns correct value' );
        is( $patron->password,        'hfkurhfe976634èj!', 'password accessor returns correct value' );
        is( $patron->flags,           '55555',             'flags accessor returns correct value' );
        is( $patron->userid,          '87987',             'userid accessor returns correct value' );
        is( $patron->opacnote,        'myOpacnote',        'opacnote accessor returns correct value' );
        is( $patron->contactnote,     'myContactnote',     'contactnote accessor returns correct value' );
        is( $patron->sort1,           'mySort1',           'sort1 accessor returns correct value' );
        is( $patron->sort2,           'mySort2',           'sort2 accessor returns correct value' );
        is(
            $patron->altcontactfirstname, 'myAltcontactfirstname',
            'altcontactfirstname accessor returns correct value'
        );
        is( $patron->altcontactsurname,  'myAltcontactsurname',  'altcontactsurname accessor returns correct value' );
        is( $patron->altcontactaddress1, 'myAltcontactaddress1', 'altcontactaddress1 accessor returns correct value' );
        is( $patron->altcontactaddress2, 'myAltcontactaddress2', 'altcontactaddress2 accessor returns correct value' );
        is( $patron->altcontactaddress3, 'myAltcontactaddress3', 'altcontactaddress3 accessor returns correct value' );
        is( $patron->altcontactstate,    'myAltcontactstate',    'altcontactstate accessor returns correct value' );
        is( $patron->altcontactzipcode,  '465843',               'altcontactzipcode accessor returns correct value' );
        is( $patron->altcontactcountry,  'myOtherCountry',       'altcontactcountry accessor returns correct value' );
        is( $patron->altcontactphone,    'myOtherphone',         'altcontactphone accessor returns correct value' );
        is( $patron->smsalertnumber,     '0683027346',           'smsalertnumber accessor returns correct value' );
        is( $patron->privacy,            '667788',               'privacy accessor returns correct value' );
    };

    subtest 'Accessor tests after set' => sub {
        plan tests => 60;

        $patron->set(
            {
                borrowernumber      => '12346',
                cardnumber          => '1234567891',
                surname             => 'SmySurname',
                firstname           => 'SmyFirstname',
                title               => 'Mme.',
                othernames          => 'SmyOthernames',
                initials            => 'SS',
                streetnumber        => '200',
                streettype          => 'Rue',
                address             => 'Smy personal address',
                address2            => 'Smy adress2',
                city                => 'Lyon',
                state               => 'Smystate',
                zipcode             => '69000',
                country             => 'France',
                email               => 'SmySurname.myFirstname@email.com',
                phone               => '0402872935',
                mobile              => '0627884633',
                fax                 => '0402872936',
                emailpro            => 'SmyEmailPro@email.com',
                phonepro            => '0402873335',
                B_streetnumber      => '102',
                B_streettype        => 'SmyB_streettype',
                B_address           => 'SmyB_address',
                B_address2          => 'SmyB_address2',
                B_city              => 'SmyB_city',
                B_state             => 'SmyB_state',
                B_zipcode           => '12333',
                B_country           => 'SmyB_country',
                B_email             => 'SmyB_email',
                B_phone             => '0678353936',
                dateofbirth         => '1991-07-16',
                branchcode          => 'SmyBranCode',
                categorycode        => 'SmyCatCode',
                dateenrolled        => '2014-03-19',
                dateexpiry          => '2017-03-19',
                gonenoaddress       => '1',
                lost                => '1',
                debarred            => '2016-04-19',
                debarredcomment     => 'You are still debarred',
                borrowernotes       => 'Sborrowernotes',
                sex                 => 'F',
                password            => 'zerzerzer#',
                flags               => '666666',
                userid              => '98233',
                opacnote            => 'SmyOpacnote',
                contactnote         => 'SmyContactnote',
                sort1               => 'SmySort1',
                sort2               => 'SmySort2',
                altcontactfirstname => 'SmyAltcontactfirstname',
                altcontactsurname   => 'SmyAltcontactsurname',
                altcontactaddress1  => 'SmyAltcontactaddress1',
                altcontactaddress2  => 'SmyAltcontactaddress2',
                altcontactaddress3  => 'SmyAltcontactaddress3',
                altcontactstate     => 'SmyAltcontactstate',
                altcontactzipcode   => '565843',
                altcontactcountry   => 'SmyOtherCountry',
                altcontactphone     => 'SmyOtherphone',
                smsalertnumber      => '0683027347',
                privacy             => '667789'
            }
        );

        is( $patron->borrowernumber,      '12346',                            'borrowernumber field set ok' );
        is( $patron->cardnumber,          '1234567891',                       'cardnumber field set ok' );
        is( $patron->surname,             'SmySurname',                       'surname field set ok' );
        is( $patron->firstname,           'SmyFirstname',                     'firstname field set ok' );
        is( $patron->title,               'Mme.',                             'title field set ok' );
        is( $patron->othernames,          'SmyOthernames',                    'othernames field set ok' );
        is( $patron->initials,            'SS',                               'initials field set ok' );
        is( $patron->streetnumber,        '200',                              'streetnumber field set ok' );
        is( $patron->streettype,          'Rue',                              'streettype field set ok' );
        is( $patron->address,             'Smy personal address',             'address field set ok' );
        is( $patron->address2,            'Smy adress2',                      'address2 field set ok' );
        is( $patron->city,                'Lyon',                             'city field set ok' );
        is( $patron->state,               'Smystate',                         'state field set ok' );
        is( $patron->zipcode,             '69000',                            'zipcode field set ok' );
        is( $patron->country,             'France',                           'country field set ok' );
        is( $patron->email,               'SmySurname.myFirstname@email.com', 'email field set ok' );
        is( $patron->phone,               '0402872935',                       'phone field set ok' );
        is( $patron->mobile,              '0627884633',                       'mobile field set ok' );
        is( $patron->fax,                 '0402872936',                       'fax field set ok' );
        is( $patron->emailpro,            'SmyEmailPro@email.com',            'emailpro field set ok' );
        is( $patron->phonepro,            '0402873335',                       'phonepro field set ok' );
        is( $patron->B_streetnumber,      '102',                              'B_streetnumber field set ok' );
        is( $patron->B_streettype,        'SmyB_streettype',                  'B_streettype field set ok' );
        is( $patron->B_address,           'SmyB_address',                     'B_address field set ok' );
        is( $patron->B_address2,          'SmyB_address2',                    'B_address2 field set ok' );
        is( $patron->B_city,              'SmyB_city',                        'B_city field set ok' );
        is( $patron->B_state,             'SmyB_state',                       'B_state field set ok' );
        is( $patron->B_zipcode,           '12333',                            'B_zipcode field set ok' );
        is( $patron->B_country,           'SmyB_country',                     'B_country field set ok' );
        is( $patron->B_email,             'SmyB_email',                       'B_email field set ok' );
        is( $patron->B_phone,             '0678353936',                       'B_phone field set ok' );
        is( $patron->dateofbirth,         '1991-07-16',                       'dateofbirth field set ok' );
        is( $patron->branchcode,          'SmyBranCode',                      'branchcode field set ok' );
        is( $patron->categorycode,        'SmyCatCode',                       'categorycode field set ok' );
        is( $patron->dateenrolled,        '2014-03-19',                       'dateenrolled field set ok' );
        is( $patron->dateexpiry,          '2017-03-19',                       'dateexpiry field set ok' );
        is( $patron->gonenoaddress,       '1',                                'gonenoaddress field set ok' );
        is( $patron->lost,                '1',                                'lost field set ok' );
        is( $patron->debarred,            '2016-04-19',                       'debarred field set ok' );
        is( $patron->debarredcomment,     'You are still debarred',           'debarredcomment field set ok' );
        is( $patron->borrowernotes,       'Sborrowernotes',                   'borrowernotes field set ok' );
        is( $patron->sex,                 'F',                                'sex field set ok' );
        is( $patron->password,            'zerzerzer#',                       'password field set ok' );
        is( $patron->flags,               '666666',                           'flags field set ok' );
        is( $patron->userid,              '98233',                            'userid field set ok' );
        is( $patron->opacnote,            'SmyOpacnote',                      'opacnote field set ok' );
        is( $patron->contactnote,         'SmyContactnote',                   'contactnote field set ok' );
        is( $patron->sort1,               'SmySort1',                         'sort1 field set ok' );
        is( $patron->sort2,               'SmySort2',                         'sort2 field set ok' );
        is( $patron->altcontactfirstname, 'SmyAltcontactfirstname',           'altcontactfirstname field set ok' );
        is( $patron->altcontactsurname,   'SmyAltcontactsurname',             'altcontactsurname field set ok' );
        is( $patron->altcontactaddress1,  'SmyAltcontactaddress1',            'altcontactaddress1 field set ok' );
        is( $patron->altcontactaddress2,  'SmyAltcontactaddress2',            'altcontactaddress2 field set ok' );
        is( $patron->altcontactaddress3,  'SmyAltcontactaddress3',            'altcontactaddress3 field set ok' );
        is( $patron->altcontactstate,     'SmyAltcontactstate',               'altcontactstate field set ok' );
        is( $patron->altcontactzipcode,   '565843',                           'altcontactzipcode field set ok' );
        is( $patron->altcontactcountry,   'SmyOtherCountry',                  'altcontactcountry field set ok' );
        is( $patron->altcontactphone,     'SmyOtherphone',                    'altcontactphone field set ok' );
        is( $patron->smsalertnumber,      '0683027347',                       'smsalertnumber field set ok' );
        is( $patron->privacy,             '667789',                           'privacy field set ok' );
    };

    $schema->storage->txn_rollback;
};

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

        my @debits = $account->outstanding_debits->as_list;
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

        my @debits = $account->outstanding_debits->as_list;
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

    plan tests => 16;

    my $schema = Koha::Database->new->schema;
    $schema->storage->txn_begin;

    Koha::Patron::Attribute::Types->search->delete;

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
        Koha::Patron::Attribute::Types->search->delete;

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
        Koha::Patron::Attribute::Types->search->delete;

        my $patron_1 = $builder->build_object({ class => 'Koha::Patrons' });
        my $patron_2 = $builder->build_object({ class => 'Koha::Patrons' });

        my $attribute_type_1 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { unique_id => 1 }
            }
        );

        my $attribute_type_2 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { unique_id => 0 }
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
        Koha::Patron::Attribute::Types->search->delete;

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
        Koha::Patron::Attribute::Types->search->delete;

        my $patron = $builder->build_object({ class => 'Koha::Patrons' });

        my $attribute_type_1 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { mandatory => 1, class => 'a', category_code => undef }
            }
        );

        my $attribute_type_2 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { mandatory => 0, class => 'a', category_code => undef }
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

    subtest 'limited category mandatory attributes tests' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;
        Koha::Patron::Attribute::Types->search->delete;

        my $patron = $builder->build_object({ class => 'Koha::Patrons' });

        my $attribute_type_1 = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { mandatory => 1, class => 'a', category_code => $patron->categorycode }
            }
        );

        $patron->extended_attributes(
            [
                { code => $attribute_type_1->code, attribute => 'a' }
            ]
        );

        is( $patron->extended_attributes->count, 1, 'Extended attributes succeeded' );

        $patron = $builder->build_object({ class => 'Koha::Patrons' });
        # new patron, new category - they shouldn't be required to have any attributes


        ok( $patron->extended_attributes([]), "We can set no attributes, mandatory attribute for other category not required");


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

subtest 'can_request_article() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'ArticleRequests', 1 );

    my $item = $builder->build_sample_item;

    my $library_1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron    = $builder->build_object( { class => 'Koha::Patrons' } );

    t::lib::Mocks::mock_userenv( { branchcode => $library_2->id } );

    Koha::CirculationRules->set_rule(
        {
            categorycode => undef,
            branchcode   => $library_1->id,
            rule_name    => 'open_article_requests_limit',
            rule_value   => 4,
        }
    );

    $builder->build_object(
        {
            class => 'Koha::ArticleRequests',
            value => { status => 'REQUESTED', borrowernumber => $patron->id }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::ArticleRequests',
            value => { status => 'PENDING', borrowernumber => $patron->id }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::ArticleRequests',
            value => { status => 'PROCESSING', borrowernumber => $patron->id }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::ArticleRequests',
            value => { status => 'CANCELED', borrowernumber => $patron->id }
        }
    );

    ok(
        $patron->can_request_article( $library_1->id ),
        '3 current requests, 4 is the limit: allowed'
    );

    # Completed request, same day
    my $completed = $builder->build_object(
        {
            class => 'Koha::ArticleRequests',
            value => {
                status         => 'COMPLETED',
                borrowernumber => $patron->id
            }
        }
    );

    ok( !$patron->can_request_article( $library_1->id ),
        '3 current requests and a completed one the same day: denied' );

    $completed->updated_on(
        dt_from_string->add( days => -1 )->set(
            hour   => 23,
            minute => 59,
            second => 59,
        )
    )->store;

    ok( $patron->can_request_article( $library_1->id ),
        '3 current requests and a completed one the day before: allowed' );

    Koha::CirculationRules->set_rule(
        {
            categorycode => undef,
            branchcode   => $library_2->id,
            rule_name    => 'open_article_requests_limit',
            rule_value   => 3,
        }
    );

    ok( !$patron->can_request_article,
        'Not passing the library_id param makes it fallback to userenv: denied'
    );

    $schema->storage->txn_rollback;
};

subtest 'article_requests() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $library = $builder->build_object({ class => 'Koha::Libraries' });
    t::lib::Mocks::mock_userenv( { branchcode => $library->id } );

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $article_requests = $patron->article_requests;
    is( ref($article_requests), 'Koha::ArticleRequests',
        'In scalar context, type is correct' );
    is( $article_requests->count, 0, 'No article requests' );

    foreach my $i ( 0 .. 3 ) {

        my $item = $builder->build_sample_item;

        Koha::ArticleRequest->new(
            {
                borrowernumber => $patron->id,
                biblionumber   => $item->biblionumber,
                itemnumber     => $item->id,
                title          => "Title",
            }
        )->request;
    }

    $article_requests = $patron->article_requests;
    is( $article_requests->count, 4, '4 article requests' );

    $schema->storage->txn_rollback;

};

subtest 'can_patron_change_staff_only_lists() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    # make a user with no special permissions
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                flags => undef
            }
        }
    );
    is( $patron->can_patron_change_staff_only_lists(), 0, 'Patron without permissions cannot change staff only lists');

    # make it a 'Catalogue' permission
    $patron->set({ flags => 4 })->store->discard_changes;
    is( $patron->can_patron_change_staff_only_lists(), 1, 'Catalogue patron can change staff only lists');


    # make it a superlibrarian
    $patron->set({ flags => 1 })->store->discard_changes;
    is( $patron->can_patron_change_staff_only_lists(), 1, 'Superlibrarian patron can change staff only lists');

    $schema->storage->txn_rollback;
};

subtest 'password expiration tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;
    my $date = dt_from_string();
    my $category = $builder->build_object({ class => 'Koha::Patron::Categories', value => {
            password_expiry_days => 10,
            require_strong_password => 0,
        }
    });
    my $patron = $builder->build_object({ class=> 'Koha::Patrons', value => {
            categorycode => $category->categorycode,
            password => 'hats'
        }
    });

    $patron->delete()->store()->discard_changes(); # Make sure we are storing a 'new' patron

    is( $patron->password_expiration_date(), $date->add( days => 10 )->ymd() , "Password expiration date set correctly on patron creation");

    $patron = $builder->build_object({ class => 'Koha::Patrons', value => {
            categorycode => $category->categorycode,
            password => undef
        }
    });
    $patron->delete()->store()->discard_changes();

    is( $patron->password_expiration_date(), undef, "Password expiration date is not set if patron does not have a password");

    $category->password_expiry_days(undef)->store();
    $patron = $builder->build_object({ class => 'Koha::Patrons', value => {
            categorycode => $category->categorycode
        }
    });
    $patron->delete()->store()->discard_changes();
    is( $patron->password_expiration_date(), undef, "Password expiration date is not set if category does not have expiry days set");

    $schema->storage->txn_rollback;

    subtest 'password_expired' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;
        my $date = dt_from_string();
        $patron = $builder->build_object({ class => 'Koha::Patrons', value => {
                password_expiration_date => undef
            }
        });
        is( $patron->password_expired, 0, "Patron with no password expiration date, password not expired");
        $patron->password_expiration_date( $date )->store;
        $patron->discard_changes();
        is( $patron->password_expired, 1, "Patron with password expiration date of today, password expired");
        $date->subtract( days => 1 );
        $patron->password_expiration_date( $date )->store;
        $patron->discard_changes();
        is( $patron->password_expired, 1, "Patron with password expiration date in past, password expired");

        $schema->storage->txn_rollback;
    };

    subtest 'set_password' => sub {

        plan tests => 4;

        $schema->storage->txn_begin;

        my $date = dt_from_string();
        my $category = $builder->build_object({ class => 'Koha::Patron::Categories', value => {
                password_expiry_days => 10
            }
        });
        my $patron = $builder->build_object({ class => 'Koha::Patrons', value => {
                categorycode => $category->categorycode,
                password_expiration_date =>  $date->subtract( days => 1 )
            }
        });
        is( $patron->password_expired, 1, "Patron password is expired");

        $date = dt_from_string();
        $patron->set_password({ password => "kitten", skip_validation => 1 })->discard_changes();
        is( $patron->password_expired, 0, "Patron password no longer expired when new password set");
        is( $patron->password_expiration_date(), $date->add( days => 10 )->ymd(), "Password expiration date set correctly on patron creation");


        $category->password_expiry_days( undef )->store();
        $patron->set_password({ password => "puppies", skip_validation => 1 })->discard_changes();
        is( $patron->password_expiration_date(), undef, "Password expiration date is unset if category does not have expiry days");

        $schema->storage->txn_rollback;
    };

};

subtest 'safe_to_delete() tests' => sub {

    plan tests => 14;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });

    ## Make it the anonymous
    t::lib::Mocks::mock_preference( 'AnonymousPatron', $patron->id );

    ok( !$patron->safe_to_delete, 'Cannot delete, it is the anonymous patron' );
    my $message = $patron->safe_to_delete->messages->[0];
    is( $message->type, 'error', 'Type is error' );
    is( $message->message, 'is_anonymous_patron', 'Cannot delete, it is the anonymous patron' );
    # cleanup
    t::lib::Mocks::mock_preference( 'AnonymousPatron', 0 );

    ## Make it have a checkout
    my $checkout = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->id }
        }
    );

    ok( !$patron->safe_to_delete, 'Cannot delete, has checkouts' );
    $message = $patron->safe_to_delete->messages->[0];
    is( $message->type, 'error', 'Type is error' );
    is( $message->message, 'has_checkouts', 'Cannot delete, has checkouts' );
    # cleanup
    $checkout->delete;

    ## Make it have a guarantee
    t::lib::Mocks::mock_preference( 'borrowerRelationship', 'parent' );
    $builder->build_object({ class => 'Koha::Patrons' })
            ->add_guarantor({ guarantor_id => $patron->id, relationship => 'parent' });

    ok( !$patron->safe_to_delete, 'Cannot delete, has guarantees' );
    $message = $patron->safe_to_delete->messages->[0];
    is( $message->type, 'error', 'Type is error' );
    is( $message->message, 'has_guarantees', 'Cannot delete, has guarantees' );

    # cleanup
    $patron->guarantee_relationships->delete;

    ## Make it have debt
    my $debit = $patron->account->add_debit({ amount => 10, interface => 'intranet', type => 'MANUAL' });

    ok( !$patron->safe_to_delete, 'Cannot delete, has debt' );
    $message = $patron->safe_to_delete->messages->[0];
    is( $message->type, 'error', 'Type is error' );
    is( $message->message, 'has_debt', 'Cannot delete, has debt' );
    # cleanup
    my $manager = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_userenv( { borrowernumber => $manager->id } );
    $patron->account->pay({ amount => 10, debits => [ $debit ] });

    ## Happy case :-D
    ok( $patron->safe_to_delete, 'Can delete, all conditions met' );
    my $messages = $patron->safe_to_delete->messages;
    is_deeply( $messages, [], 'Patron can be deleted, no messages' );

    $schema->storage->txn_rollback;
};

subtest 'article_request_fee() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    # Cleanup, to avoid interference
    Koha::CirculationRules->search( { rule_name => 'article_request_fee' } )->delete;

    t::lib::Mocks::mock_preference( 'ArticleRequests', 1 );

    my $item = $builder->build_sample_item;

    my $library_1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron    = $builder->build_object( { class => 'Koha::Patrons' } );

    # Rule that should never be picked, because the patron's category is always picked
    Koha::CirculationRules->set_rule(
        {   categorycode => undef,
            branchcode   => undef,
            rule_name    => 'article_request_fee',
            rule_value   => 1,
        }
    );

    is( $patron->article_request_fee( { library_id => $library_2->id } ), 1, 'library_id used correctly' );

    Koha::CirculationRules->set_rule(
        {   categorycode => $patron->categorycode,
            branchcode   => undef,
            rule_name    => 'article_request_fee',
            rule_value   => 2,
        }
    );

    Koha::CirculationRules->set_rule(
        {   categorycode => $patron->categorycode,
            branchcode   => $library_1->id,
            rule_name    => 'article_request_fee',
            rule_value   => 3,
        }
    );

    is( $patron->article_request_fee( { library_id => $library_2->id } ), 2, 'library_id used correctly' );

    t::lib::Mocks::mock_userenv( { branchcode => $library_1->id } );

    is( $patron->article_request_fee(), 3, 'env used correctly' );

    $schema->storage->txn_rollback;
};

subtest 'add_article_request_fee_if_needed() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    my $amount = 0;

    my $patron_mock = Test::MockModule->new('Koha::Patron');
    $patron_mock->mock( 'article_request_fee', sub { return $amount; } );

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    is( $patron->article_request_fee, $amount, 'article_request_fee mocked' );

    my $library_1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $staff     = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item      = $builder->build_sample_item;

    t::lib::Mocks::mock_userenv(
        { branchcode => $library_1->id, patron => $staff } );

    my $debit = $patron->add_article_request_fee_if_needed();
    is( $debit, undef, 'No fee, no debit line' );

    # positive value
    $amount = 1;

    $debit = $patron->add_article_request_fee_if_needed({ item_id => $item->id });
    is( ref($debit), 'Koha::Account::Line', 'Debit object type correct' );
    is( $debit->amount, $amount,
        'amount set to $patron->article_request_fee value' );
    is( $debit->manager_id, $staff->id,
        'manager_id set to userenv session user' );
    is( $debit->branchcode, $library_1->id,
        'branchcode set to userenv session library' );
    is( $debit->debit_type_code, 'ARTICLE_REQUEST',
        'debit_type_code set correctly' );
    is( $debit->itemnumber, $item->id,
        'itemnumber set correctly' );

    $amount = 100;

    $debit = $patron->add_article_request_fee_if_needed({ library_id => $library_2->id });
    is( ref($debit), 'Koha::Account::Line', 'Debit object type correct' );
    is( $debit->amount, $amount,
        'amount set to $patron->article_request_fee value' );
    is( $debit->branchcode, $library_2->id,
        'branchcode set to userenv session library' );
    is( $debit->itemnumber, undef,
        'itemnumber set correctly to undef' );

    $schema->storage->txn_rollback;
};

subtest 'messages' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $messages = $patron->messages;
    is( $messages->count, 0, "No message yet" );
    my $message_1 = $builder->build_object(
        {
            class => 'Koha::Patron::Messages',
            value => { borrowernumber => $patron->borrowernumber }
        }
    );
    my $message_2 = $builder->build_object(
        {
            class => 'Koha::Patron::Messages',
            value => { borrowernumber => $patron->borrowernumber }
        }
    );

    $messages = $patron->messages;
    is( $messages->count, 2, "There are two messages for this patron" );
    is( $messages->next->message, $message_1->message );
    is( $messages->next->message, $message_2->message );
    $schema->storage->txn_rollback;
};

subtest 'recalls() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $biblio1 = $builder->build_object({ class => 'Koha::Biblios' });
    my $item1 = $builder->build_object({ class => 'Koha::Items' }, { value => { biblionumber => $biblio1->biblionumber } });
    my $biblio2 = $builder->build_object({ class => 'Koha::Biblios' });
    my $item2 = $builder->build_object({ class => 'Koha::Items' }, { value => { biblionumber => $biblio2->biblionumber } });

    Koha::Recall->new(
        {   biblio_id         => $biblio1->biblionumber,
            patron_id         => $patron->borrowernumber,
            item_id           => $item1->itemnumber,
            pickup_library_id => $patron->branchcode,
            created_date      => \'NOW()',
            item_level        => 1,
        }
    )->store;
    Koha::Recall->new(
        {   biblio_id         => $biblio2->biblionumber,
            patron_id         => $patron->borrowernumber,
            item_id           => $item2->itemnumber,
            pickup_library_id => $patron->branchcode,
            created_date      => \'NOW()',
            item_level        => 1,
        }
    )->store;
    Koha::Recall->new(
        {   biblio_id         => $biblio1->biblionumber,
            patron_id         => $patron->borrowernumber,
            item_id           => undef,
            pickup_library_id => $patron->branchcode,
            created_date      => \'NOW()',
            item_level        => 0,
        }
    )->store;
    my $recall = Koha::Recall->new(
        {   biblio_id         => $biblio1->biblionumber,
            patron_id         => $patron->borrowernumber,
            item_id           => undef,
            pickup_library_id => $patron->branchcode,
            created_date      => \'NOW()',
            item_level        => 0,
        }
    )->store;
    $recall->set_cancelled;

    is( $patron->recalls->count,                                                                       4, "Correctly gets this patron's recalls" );
    is( $patron->recalls->filter_by_current->count,                                                    3, "Correctly gets this patron's active recalls" );
    is( $patron->recalls->filter_by_current->search( { biblio_id => $biblio1->biblionumber } )->count, 2, "Correctly gets this patron's active recalls on a specific biblio" );

    $schema->storage->txn_rollback;
};

subtest 'encode_secret and decoded_secret' => sub {
    plan tests => 5;
    $schema->storage->txn_begin;

    t::lib::Mocks::mock_config('encryption_key', 't0P_secret');

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    is( $patron->decoded_secret, undef, 'TestBuilder does not initialize it' );
    $patron->secret(q{});
    is( $patron->decoded_secret, q{}, 'Empty string case' );

    $patron->encode_secret('encrypt_me'); # Note: lazy testing; should be base32 string normally.
    is( length($patron->secret) > 0, 1, 'Secret length' );
    isnt( $patron->secret, 'encrypt_me', 'Encrypted column' );
    is( $patron->decoded_secret, 'encrypt_me', 'Decrypted column' );

    $schema->storage->txn_rollback;
};

subtest 'notify_library_of_registration()' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;
    my $dbh = C4::Context->dbh;

    my $library = $builder->build_object(
        {
            class => 'Koha::Libraries',
            value => {
                branchemail   => 'from@mybranch.com',
                branchreplyto => 'to@mybranch.com'
            }
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode => $library->branchcode
            }
        }
    );

    t::lib::Mocks::mock_preference( 'KohaAdminEmailAddress', 'root@localhost' );
    t::lib::Mocks::mock_preference( 'EmailAddressForPatronRegistrations', 'library@localhost' );

    # Test when EmailPatronRegistrations equals BranchEmailAddress
    t::lib::Mocks::mock_preference( 'EmailPatronRegistrations', 'BranchEmailAddress' );
    is( $patron->notify_library_of_registration(C4::Context->preference('EmailPatronRegistrations')), 1, 'OPAC_REG email is queued if EmailPatronRegistration syspref equals BranchEmailAddress');
    my $sth = $dbh->prepare("SELECT to_address FROM message_queue where borrowernumber = ?");
    $sth->execute( $patron->borrowernumber );
    my $to_address = $sth->fetchrow_array;
    is( $to_address, 'to@mybranch.com', 'OPAC_REG email queued to go to branchreplyto address when EmailPatronRegistration equals BranchEmailAddress' );
    $dbh->do(q|DELETE FROM message_queue|);

    # Test when EmailPatronRegistrations equals EmailAddressForPatronRegistrations
    t::lib::Mocks::mock_preference( 'EmailPatronRegistrations', 'EmailAddressForPatronRegistrations' );
    is( $patron->notify_library_of_registration(C4::Context->preference('EmailPatronRegistrations')), 1, 'OPAC_REG email is queued if EmailPatronRegistration syspref equals EmailAddressForPatronRegistrations');
    $sth->execute( $patron->borrowernumber );
    $to_address = $sth->fetchrow_array;
    is( $to_address, 'library@localhost', 'OPAC_REG email queued to go to EmailAddressForPatronRegistrations syspref when EmailPatronRegistration equals EmailAddressForPatronRegistrations' );
    $dbh->do(q|DELETE FROM message_queue|);

    # Test when EmailPatronRegistrations equals KohaAdminEmailAddress
    t::lib::Mocks::mock_preference( 'EmailPatronRegistrations', 'KohaAdminEmailAddress' );
    t::lib::Mocks::mock_preference( 'ReplyToDefault', 'root@localhost' ); # FIXME Remove localhost
    is( $patron->notify_library_of_registration(C4::Context->preference('EmailPatronRegistrations')), 1, 'OPAC_REG email is queued if EmailPatronRegistration syspref equals KohaAdminEmailAddress');
    $sth->execute( $patron->borrowernumber );
    $to_address = $sth->fetchrow_array;
    is( $to_address, 'root@localhost', 'OPAC_REG email queued to go to KohaAdminEmailAddress syspref when EmailPatronRegistration equals KohaAdminEmailAddress' );
    $dbh->do(q|DELETE FROM message_queue|);

    $schema->storage->txn_rollback;
};

subtest 'update privacy tests' => sub {
    $schema->storage->txn_begin;

    plan tests => 5;

    my $patron = $builder->build_object({ class => 'Koha::Patrons', value => { privacy => 1 } });

    my $old_checkout = $builder->build_object({ class => 'Koha::Old::Checkouts', value => { borrowernumber => $patron->id } });

    t::lib::Mocks::mock_preference( 'AnonymousPatron', '0' );

    $patron->privacy(2); #set to never

    throws_ok{ $patron->store } 'Koha::Exceptions::Patron::FailedAnonymizing', 'We throw an exception when anonymizing fails';

    $old_checkout->discard_changes; #refresh from db
    $patron->discard_changes;

    is( $old_checkout->borrowernumber, $patron->id, "When anonymizing fails, we don't clear the checkouts");
    is( $patron->privacy(), 1, "When anonymizing fails, we don't chaneg the privacy");

    my $anon_patron = $builder->build_object({ class => 'Koha::Patrons'});
    t::lib::Mocks::mock_preference( 'AnonymousPatron', $anon_patron->id );

    $patron->privacy(2)->store(); #set to never

    $old_checkout->discard_changes; #refresh from db
    $patron->discard_changes;

    is( $old_checkout->borrowernumber, $anon_patron->id, "Checkout is successfully anonymized");
    is( $patron->privacy(), 2, "Patron privacy is successfully updated");

    $schema->storage->txn_rollback;
};
