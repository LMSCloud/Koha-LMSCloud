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

# The LMSCloud patron search filters of GET /api/v1/patrons, sent as reserved
# words inside q as the staff patron search does, with patrons on and around
# each boundary.

use Modern::Perl;

use Test::More tests => 10;
use Test::Mojo;

use JSON qw( encode_json );

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::OverdueIssue;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );
my $t = Test::Mojo->new('Koha::REST::V1');

my $password = 'thePassword123';
my ( $userid, $surname );

sub setup {
    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 1 } } );
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    t::lib::Mocks::mock_userenv( { patron => $librarian } );
    $userid  = $librarian->userid;
    $surname = 'Lmsfilter' . int( rand(1_000_000) );
}

# A patron sharing the test surname, named $firstname
sub patron {
    my ( $firstname, %values ) = @_;
    return $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                surname => $surname, firstname => $firstname, email    => undef, emailpro    => undef,
                B_email => undef,    debarred  => undef,      lastseen => undef, dateofbirth => undef,
                %values
            }
        }
    );
}

# The first names of the test patrons the filters find, sorted
sub found {
    my (%filters) = @_;
    my $q         = encode_json( { '-and' => [ { 'me.surname' => $surname }, \%filters ] } );
    my $response  = $t->get_ok("//$userid:$password@/api/v1/patrons?_per_page=-1&q=$q")->status_is(200)->tx->res->json;
    return join ' ', sort map { $_->{firstname} } @{$response};
}

sub years_ago { return dt_from_string->subtract( years => $_[0] )->ymd }
sub days_ago  { return dt_from_string->subtract( days  => $_[0] )->ymd }

sub checkout {
    my ($patron) = @_;
    return $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value =>
                { borrowernumber => $patron->borrowernumber, itemnumber => $builder->build_sample_item->itemnumber }
        }
    );
}

subtest 'Age, with both ends inclusive' => sub {
    plan tests => 4 * 3;

    $schema->storage->txn_begin;
    setup();
    patron( '17', dateofbirth => dt_from_string->subtract( years => 18 )->add( days => 1 )->ymd );
    patron( '18', dateofbirth => years_ago(18) );
    patron( '30', dateofbirth => years_ago(30) );
    patron( '31', dateofbirth => years_ago(31) );

    is( found( age_from => '18', age_to => '30' ), '18 30',    'from 18 to 30' );
    is( found( age_from => '18' ),                 '18 30 31', 'from 18' );
    is( found( age_to   => '30' ),                 '17 18 30', 'to 30, a day before the 18th birthday is 17' );
    is( found( age_from => '31', age_to => '31' ), '31',       'exactly 31' );

    $schema->storage->txn_rollback;
};

subtest 'Number of checkouts' => sub {
    plan tests => 3 * 3;

    $schema->storage->txn_begin;
    setup();
    patron('none');
    checkout( patron('one') );
    my $two = patron('two');
    checkout($two) for 1 .. 2;

    is( found( issue_count_from => '1', issue_count_to => '1' ), 'one',     'exactly one' );
    is( found( issue_count_to   => '0' ),                        'none',    'none' );
    is( found( issue_count_from => '1' ),                        'one two', 'at least one' );

    $schema->storage->txn_rollback;
};

subtest 'Open charges amount' => sub {
    plan tests => 5 * 3;

    $schema->storage->txn_begin;
    setup();
    patron('nolines');
    my $paid = patron('paid');
    my $line = $paid->account->add_debit( { amount => 3, type => 'MANUAL', interface => 'intranet' } );
    $paid->account->pay( { amount => 3, lines => [$line], interface => 'intranet' } );
    patron('five')->account->add_debit( { amount => 5, type => 'MANUAL', interface => 'intranet' } );

    is( found( charges_from => '0', charges_to => '0' ),    'nolines paid',      'nothing open' );
    is( found( charges_to   => '5' ),                       'five nolines paid', 'up to 5' );
    is( found( charges_from => '5' ),                       'five',              'from 5' );
    is( found( charges_from => '5.01' ),                    '',                  'from 5.01' );
    is( found( charges_from => '1', charges_to => '4.99' ), '',                  'between 1 and 4.99' );

    $schema->storage->txn_rollback;
};

subtest 'Account expiry, with both ends inclusive' => sub {
    plan tests => 2 * 3;

    $schema->storage->txn_begin;
    setup();
    patron( 'early', dateexpiry => days_ago(-10) );
    patron( 'late',  dateexpiry => days_ago(-20) );

    is( found( account_expiry_from => days_ago(-10), account_expiry_to => days_ago(-10) ), 'early', 'on the day' );
    is( found( account_expiry_from => days_ago(-9) ), 'early late', 'from a day before' );

    $schema->storage->txn_rollback;
};

subtest 'Restriction end date, with both ends inclusive' => sub {
    plan tests => 2 * 3;

    $schema->storage->txn_begin;
    setup();
    patron('free');
    patron( 'restricted', debarred => days_ago(-5) );

    is(
        found( debarred_period_from => days_ago(-5), debarred_period_to => days_ago(-5) ), 'restricted',
        'restricted until the day'
    );
    is( found( debarred_period_to => days_ago(-6) ), 'restricted', 'restricted until a day later at most' );

    $schema->storage->txn_rollback;
};

subtest 'Inactive since a day' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    setup();
    patron( 'seenbefore', lastseen => days_ago(11) . ' 15:00:00' );
    patron( 'seenon',     lastseen => days_ago(10) . ' 09:00:00' );
    checkout( patron('borrowing') );

    is( found( inactive_period_from => days_ago(10) ), 'seenbefore', 'neither seen nor borrowing since the day' );

    $schema->storage->txn_rollback;
};

subtest 'Last sent letter' => sub {
    plan tests => 2 * 3;

    $schema->storage->txn_begin;
    setup();
    my $message = sub {
        my ( $patron, $code, $status, $days_ago ) = @_;
        $builder->build(
            {
                source => 'MessageQueue',
                value  => {
                    borrowernumber => $patron->borrowernumber, letter_code => $code, status => $status,
                    time_queued    => days_ago($days_ago) . ' 10:00:00'
                }
            }
        );
    };
    my $odue = patron('odue');
    $message->( $odue, 'PREDUE', 'sent', 5 );
    $message->( $odue, 'ODUE',   'sent', 1 );
    my $later = patron('later');
    $message->( $later, 'ODUE',   'sent', 5 );
    $message->( $later, 'PREDUE', 'sent', 1 );

    is( found( last_letter => 'ODUE' ),   'odue',  'the latest sent letter is an ODUE' );
    is( found( last_letter => 'PREDUE' ), 'later', 'the latest sent letter is a PREDUE' );

    $schema->storage->txn_rollback;
};

subtest 'Overdue level of a current checkout' => sub {
    plan tests => 2 * 3;

    $schema->storage->txn_begin;
    setup();
    my $claimed = checkout( patron('claimed') );
    Koha::OverdueIssue->new( { issue_id => $claimed->issue_id, claim_level => $_, claim_time => days_ago( 3 - $_ ) } )
        ->store
        for 1 .. 2;
    checkout( patron('unclaimed') );

    is( found( overdue_level => '2' ), 'claimed', 'the highest level reached' );
    is( found( overdue_level => '1' ), '',        'not a level passed earlier' );

    $schema->storage->txn_rollback;
};

subtest 'Email address' => sub {
    plan tests => 2 * 3;

    $schema->storage->txn_begin;
    setup();
    patron( 'private', email    => 'anna.meier@example.de' );
    patron( 'work',    emailpro => 'anna.meier@work.example.org' );
    patron( 'broken',  email    => 'not-an-address' );
    patron('none');

    is( found( valid_email => 'yes' ), 'private work', 'a usable private or work address' );
    is( found( valid_email => 'no' ),  'broken none',  'none or no usable address' );

    $schema->storage->txn_rollback;
};

subtest 'Patron list, combined with another filter' => sub {
    plan tests => 2 * 3;

    $schema->storage->txn_begin;
    setup();
    my $list = $builder->build( { source => 'PatronList' } );
    for my $patron (
        patron( 'listedyoung', dateofbirth => years_ago(10) ),
        patron( 'listedold',   dateofbirth => years_ago(40) )
        )
    {
        $builder->build(
            {
                source => 'PatronListPatron',
                value  => { patron_list_id => $list->{patron_list_id}, borrowernumber => $patron->borrowernumber }
            }
        );
    }
    patron( 'unlisted', dateofbirth => years_ago(10) );

    is( found( patron_list => $list->{patron_list_id} ), 'listedold listedyoung', 'the list members' );
    is(
        found( patron_list => $list->{patron_list_id}, age_to => '18' ), 'listedyoung',
        'and the young ones among them'
    );

    $schema->storage->txn_rollback;
};
