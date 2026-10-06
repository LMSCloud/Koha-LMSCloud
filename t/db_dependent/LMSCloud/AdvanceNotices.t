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

# End-to-end tests for the LMSCloud behaviour of misc/cronjobs/advance_notices.pl:
# the script runs in-process (as t/db_dependent/cronjobs/advance_notices_digest.t
# does) inside a transaction, and the tests assert on the queued messages.
#
# NB: no Test::NoWarnings, evaluating the script more than once redefines its subs.

use Modern::Perl;

use Test::More tests => 3;

use File::Slurp qw( read_file );

use Koha::Database;
use Koha::DateUtils qw( dt_from_string output_pref );

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

my $script = read_file('misc/cronjobs/advance_notices.pl');

sub run_advance_notices {
    local @ARGV = @_;
    eval $script;    ## no critic (StringyEval)
    die $@ if $@;
}

# A patron at $library who wants a PREDUEDGST email digest one day in advance,
# with the given titles checked out at $library and due tomorrow.
sub build_digest_scenario {
    my ( $library, @titles ) = @_;
    return build_advance_scenario( $library, 1, @titles );
}

# As build_digest_scenario, but $wants_digest chooses a digest or one PREDUE per item.
sub build_advance_scenario {
    my ( $library, $wants_digest, @titles ) = @_;

    my $patron = $builder->build_object(
        { class => 'Koha::Patrons', value => { branchcode => $library, email => 'advance@example.com' } } );
    my $attribute  = $builder->build( { source => 'MessageAttribute', value => { message_name => 'Advance_Notice' } } );
    my $preference = $builder->build(
        {
            source => 'BorrowerMessagePreference',
            value  => {
                borrowernumber       => $patron->borrowernumber,
                wants_digest         => $wants_digest,
                days_in_advance      => 1,
                message_attribute_id => $attribute->{message_attribute_id},
            }
        }
    );
    $builder->build(
        {
            source => 'BorrowerMessageTransportPreference',
            value  => {
                borrower_message_preference_id => $preference->{borrower_message_preference_id},
                message_transport_type         => 'email',
            }
        }
    );
    my $tomorrow = dt_from_string->add( days => 1 )->strftime('%F');
    foreach my $title (@titles) {
        my $biblio = $builder->build_sample_biblio( { title => $title } );
        my $item   = $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library } );
        $builder->build(
            {
                source => 'Issue',
                value  => {
                    date_due       => $tomorrow,
                    itemnumber     => $item->itemnumber,
                    branchcode     => $library,
                    borrowernumber => $patron->borrowernumber,
                    returndate     => undef,
                }
            }
        );
    }
    return $patron;
}

sub setup_digest_letter {
    my ( $content, $code ) = @_;
    $code //= 'PREDUEDGST';
    $dbh->do(q|DELETE FROM message_attributes WHERE message_name = 'Advance_Notice'|);
    $dbh->do( q|DELETE FROM letter WHERE module = 'circulation' AND code = ?|, undef, $code );
    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => $code,
                branchcode             => '',
                message_transport_type => 'email',
                lang                   => 'default',
                is_html                => 0,
                content                => $content,
            }
        }
    );
}

sub queued_messages {
    my ( $borrowernumber, $code ) = @_;
    return $dbh->selectall_arrayref(
        q|SELECT content, branchcode FROM message_queue WHERE borrowernumber = ? AND letter_code = ?|,
        { Slice => {} }, $borrowernumber, $code // 'PREDUEDGST'
    );
}

t::lib::Mocks::mock_preference( 'dateformat',                   'metric' );
t::lib::Mocks::mock_preference( 'EnhancedMessagingPreferences', 1 );

subtest '<<today>> is substituted in advance notices' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    setup_digest_letter('Sent <<today>>');
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } );
    my $patron  = build_digest_scenario( $library->branchcode, 'Advance one' );

    run_advance_notices('-c');
    my $messages = queued_messages( $patron->borrowernumber );
    is( scalar @{$messages}, 1, 'one digest is queued' );
    is(
        $messages->[0]->{content}, 'Sent ' . output_pref( { dt => dt_from_string, dateonly => 1 } ),
        'today\'s date replaces <<today>>'
    );

    $schema->storage->txn_rollback;
};

subtest '<item> blocks repeat for the items of digests and single notices' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    setup_digest_letter('Due:<item> [<<biblio.title>>]</item>');
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } );
    my $patron  = build_digest_scenario( $library->branchcode, 'Advance one', 'Advance two' );

    run_advance_notices('-c');
    my $messages = queued_messages( $patron->borrowernumber );
    like( $messages->[0]->{content}, qr/\[Advance one\]/, 'digest: the first item is listed' );
    like( $messages->[0]->{content}, qr/\[Advance two\]/, 'digest: the second item is listed' );

    setup_digest_letter( 'Due:<item> [<<biblio.title>>]</item>', 'PREDUE' );
    my $single = build_advance_scenario( $library->branchcode, 0, 'Advance three' );
    run_advance_notices('-c');
    my $notices = queued_messages( $single->borrowernumber, 'PREDUE' );
    like( $notices->[0]->{content}, qr/\[Advance three\]/, 'single notice: the item is listed' );

    $schema->storage->txn_rollback;
};

subtest 'Bookmobile stations notify on behalf of their parent library' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    setup_digest_letter('<<branches.branchname>>');
    my $parent = $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => undef } } );
    my $station =
        $builder->build_object( { class => 'Koha::Libraries', value => { mobilebranch => $parent->branchcode } } );
    my $patron = build_digest_scenario( $station->branchcode, 'Advance one' );

    run_advance_notices('-c');
    my $messages = queued_messages( $patron->borrowernumber );
    is( $messages->[0]->{content},    $parent->branchname, 'the letter names the parent library' );
    is( $messages->[0]->{branchcode}, $parent->branchcode, 'the message is queued for the parent library' );

    $schema->storage->txn_rollback;
};
