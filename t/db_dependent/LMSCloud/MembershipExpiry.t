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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

# End-to-end tests for misc/cronjobs/membership_expiry.pl: the real cron runs
# in-process inside a transaction and the tests assert on message_queue.
#
# NB: no Test::NoWarnings here on purpose -- eval-ing the script more than once
# per run emits "Subroutine ... redefined" warnings.

use Modern::Perl;

use Test::More tests => 4;

use File::Slurp qw( read_file );

use C4::Members::Messaging;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Notice::Messages;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $script = read_file('misc/cronjobs/membership_expiry.pl');

sub run_membership_expiry {
    local @ARGV = @_;
    eval $script;    ## no critic (StringyEval)
    die $@ if $@;
}

# A library with its own MEMBERSHIP_EXPIRY notice, so only patrons built here are picked up.
sub build_library {
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    for my $mtt (qw( email print )) {
        $builder->build_object(
            {
                class => 'Koha::Notice::Templates',
                value => {
                    module                 => 'members',
                    code                   => 'MEMBERSHIP_EXPIRY',
                    branchcode             => $library->branchcode,
                    lang                   => 'default',
                    message_transport_type => $mtt,
                    is_html                => 0,
                    title                  => 'Expiry',
                    content                => 'Your card expires',
                }
            }
        );
    }
    return $library;
}

sub build_expiring_patron {
    my ( $library, $category, $email ) = @_;
    return $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode             => $library->branchcode,
                categorycode           => $category->categorycode,
                dateexpiry             => dt_from_string->add( days => 14 )->ymd,
                email                  => $email,
                emailpro               => undef,
                B_email                => undef,
                lang                   => 'default',
                primary_contact_method => undef,
            }
        }
    );
}

sub set_expiry_preference {
    my ( $patron, @transports ) = @_;
    my $attribute = $schema->resultset('MessageAttribute')->find( { message_name => 'Patron_Expiry' } );
    C4::Members::Messaging::SetMessagingPreference(
        {
            borrowernumber          => $patron->borrowernumber,
            message_attribute_id    => $attribute->message_attribute_id,
            message_transport_types => \@transports,
        }
    );
}

sub queued_transports {
    my ($patron) = @_;
    return [ sort map { $_->message_transport_type }
            Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber } )->as_list ];
}

t::lib::Mocks::mock_preference( 'MembershipExpiryDaysNotice', 14 );

subtest 'The patron messaging preference decides the transport' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = build_library();
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { enforce_expiry_notice => 0 } } );
    my $wants_email = build_expiring_patron( $library, $category, 'expiry@example.com' );
    my $no_pref     = build_expiring_patron( $library, $category, 'expiry2@example.com' );
    set_expiry_preference( $wants_email, 'email' );

    run_membership_expiry( '-c', '-branch', $library->branchcode );

    is_deeply( queued_transports($wants_email), ['email'], 'A patron who chose email gets an email' );
    is_deeply( queued_transports($no_pref),     [],        'A patron without the preference gets no notice' );

    $schema->storage->txn_rollback;
};

subtest '-n queues nothing' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my $library = build_library();
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { enforce_expiry_notice => 0 } } );
    my $patron = build_expiring_patron( $library, $category, 'expiry@example.com' );
    set_expiry_preference( $patron, 'email' );

    run_membership_expiry( '-c', '-n', '-branch', $library->branchcode );

    is_deeply( queued_transports($patron), [], 'No notice is queued with -n' );

    $schema->storage->txn_rollback;
};

subtest 'Only categories that enforce the notice make it mandatory' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = build_library();
    my $enforced =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { enforce_expiry_notice => 1 } } );
    my $optional =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { enforce_expiry_notice => 0 } } );
    my $mandatory = build_expiring_patron( $library, $enforced, undef );
    my $other     = build_expiring_patron( $library, $optional, undef );

    run_membership_expiry( '-c', '-branch', $library->branchcode );

    is_deeply(
        queued_transports($mandatory), ['print'],
        'A patron in an enforcing category gets a notice without a preference'
    );
    is_deeply( queued_transports($other), [], 'A patron in another category does not' );

    $schema->storage->txn_rollback;
};

subtest 'A patron without an email address gets a print notice' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    my $library = build_library();
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { enforce_expiry_notice => 0 } } );
    my $patron = build_expiring_patron( $library, $category, undef );
    set_expiry_preference( $patron, 'email' );

    run_membership_expiry( '-c', '-branch', $library->branchcode );

    is_deeply( queued_transports($patron), ['print'], 'The email falls back to print' );

    $schema->storage->txn_rollback;
};
