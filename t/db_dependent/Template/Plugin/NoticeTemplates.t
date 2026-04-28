#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 6;

use Koha::Database;
use Koha::Notice::Templates;

use t::lib::Mocks;
use t::lib::TestBuilder;

BEGIN {
    use_ok('Koha::Template::Plugin::NoticeTemplates');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
$schema->storage->txn_begin;

Koha::Notice::Templates->delete();

my $notice_templates = Koha::Notice::Templates->search( { module => 'members' } );

$builder->build(
    {
        source => 'Letter',
        value  => {
            name   => 'Hold cancellation',
            module => 'reserves'
        }
    }
);

$builder->build(
    {
        source => 'Letter',
        value  => {
            name   => 'Account expiration',
            module => 'members'
        }
    }
);

$builder->build(
    {
        source => 'Letter',
        value  => {
            name   => 'Discharge',
            module => 'members'
        }
    }
);

my $plugin = Koha::Template::Plugin::NoticeTemplates->new();
ok( $plugin, "initialized notice templates plugin" );

my $notices = $plugin->GetByModule('members');
is( $notices->count, 2, 'returns 2 defined members letters' );

$notices = $plugin->GetByModule('reserves');
is( $notices->count, 1, 'returns 2 defined reserves letters' );

subtest 'GetByModuleForLibrary' => sub {
    plan tests => 3;

    my $branch1 = $builder->build( { source => 'Branch' } )->{branchcode};
    my $branch2 = $builder->build( { source => 'Branch' } )->{branchcode};

    # All-libraries notice (branchcode = '')
    $builder->build(
        { source => 'Letter', value => { module => 'add_message', code => 'MSG_ALL', branchcode => '' } } );

    # Branch1-specific notice only (no default version)
    $builder->build(
        { source => 'Letter', value => { module => 'add_message', code => 'MSG_BRANCH1', branchcode => $branch1 } } );

    t::lib::Mocks::mock_userenv( { branchcode => $branch1 } );
    $notices = $plugin->GetByModuleForLibrary('add_message');
    is( scalar @$notices, 2, 'user at branch1 sees all-libraries and branch-specific notices' );

    t::lib::Mocks::mock_userenv( { branchcode => $branch2 } );
    $notices = $plugin->GetByModuleForLibrary('add_message');
    is( scalar @$notices, 1, 'user at branch2 sees only all-libraries notices' );

    t::lib::Mocks::mock_userenv( { branchcode => $branch2 } );
    $notices = $plugin->GetByModuleForLibrary('add_message');
    is( scalar @$notices, 1, 'user with no branch sees only all-libraries notices' );
};

$schema->storage->txn_rollback;
