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

# The LMSCloud Elasticsearch mappings and query syntax. Each subtest loads the
# mappings from admin/searchengine/elasticsearch/mappings.yaml, as
# rebuild_elasticsearch.pl -r does on every upgrade, and checks the documents
# built from MARC records and the queries built from search terms. No
# Elasticsearch server is needed.

use Modern::Perl;
use utf8;

use Test::More tests => 8;

use MARC::Field;
use MARC::Record;

use Koha::Database;
use Koha::SearchEngine::Elasticsearch;
use Koha::SearchEngine::Elasticsearch::QueryBuilder;
use Koha::SearchFields;

use t::lib::Mocks;

my $schema = Koha::Database->new->schema;

# The LMSCloud query aliases and the search fields they stand for
my %lms_aliases = (
    cn      => 'control-number',
    cna     => 'control-number-agency',
    sbg     => 'subject-genre-form',
    ocn     => 'other-classification-number',
    katno   => 'kateg-no',
    katname => 'kateg-name',
    sys     => 'systematik',
    sysp    => 'systematik-prefix',
    sysc    => 'systematik-class-part',
    sysn    => 'systematik-num-part',
    fsk     => 'ekz-fsk',
    usk     => 'ekz-usk',
    age     => 'ekz-age',
    antc    => 'antolin-count',
    anta    => 'antolin-age',
);

sub reset_mappings {
    t::lib::Mocks::mock_preference( 'marcflavour', 'MARC21' );
    Koha::SearchEngine::Elasticsearch->reset_elasticsearch_mappings;
    Koha::SearchEngine::Elasticsearch->clear_search_fields_cache;
}

sub rollback {
    $schema->storage->txn_rollback;
    Koha::SearchEngine::Elasticsearch->clear_search_fields_cache;
}

sub document {
    my (@fields) = @_;
    my $record = MARC::Record->new;
    $record->leader('00000nam a22000007a 4500');
    $record->append_fields( MARC::Field->new( '001', '4711' ), @fields );
    return Koha::SearchEngine::Elasticsearch->new( { index => 'biblios' } )->marc_records_to_documents( [$record] )
        ->[0];
}

sub query_string {
    my (@args) = @_;
    my ( undef, $query ) =
        Koha::SearchEngine::Elasticsearch::QueryBuilder->new( { index => 'biblios' } )->build_query_compat(@args);
    return $query->{query}{bool}{must}[0]{query_string}{query};
}

subtest 'Records index the LMSCloud fields of mappings.yaml' => sub {
    plan tests => 13;

    $schema->storage->txn_begin;
    reset_mappings();

    my $doc = document(
        MARC::Field->new( '003', 'DE-576' ),
        MARC::Field->new( '072', ' ', ' ', a => 'Roman' ),
        MARC::Field->new( '084', ' ', ' ', 2 => 'sfb',   a => '5.1' ),
        MARC::Field->new( '245', '1', '0', a => 'Titel', n => 'Band 2' ),
        MARC::Field->new( '249', ' ', ' ', a => 'Beigefügt' ),
        MARC::Field->new( '264', ' ', '1', c => '2021' ),
        MARC::Field->new( '690', ' ', ' ', a => 'Lokales Schlagwort' ),
        MARC::Field->new( '852', ' ', ' ', a => 'Magazin', k => 'Pre', h => 'Kl', j => '42' ),
        MARC::Field->new( '856', ' ', ' ', x => '3', z => '8-10' ),
        MARC::Field->new( '900', ' ', ' ', a => 'Verweisform' ),
        MARC::Field->new( '910', ' ', ' ', a => 'Körperschaft' ),
    );

    is_deeply( $doc->{'subject-genre-form'},          ['Roman'],   'interest group from 072$a' );
    is_deeply( $doc->{'control-number-agency'},       ['DE-576'],  'control number agency from 003' );
    is_deeply( $doc->{'other-classification-number'}, ['sfb 5.1'], 'other classification from 084$2$a' );
    is_deeply( $doc->{systematik},                    ['Magazin'], 'systematik from 852$a' );
    is_deeply( $doc->{'systematik-prefix'},           ['Pre'],     'systematik prefix from 852$k' );
    is_deeply( $doc->{'systematik-class-part'},       ['Kl'],      'systematik class part from 852$h' );
    is_deeply( $doc->{'systematik-num-part'},         ['42'],      'systematik number part from 852$j' );
    is_deeply( [ @{ $doc->{'antolin-count'} }, @{ $doc->{'antolin-age'} } ], [ '3', '8-10' ], 'Antolin from 856$x$z' );
    ok( ( grep { $_ eq 'Verweisform' } @{ $doc->{author} } ), 'author includes 900$a' );
    is_deeply( $doc->{'author-name-corporate'}, ['Körperschaft'], 'corporate author from 910$a' );
    ok( ( grep { $_ eq 'Lokales Schlagwort' } @{ $doc->{subject} } ), 'subject includes 690$a' );
    ok(
        ( grep { $_ eq 'Band 2' } @{ $doc->{title} } ) && ( grep { $_ eq 'Beigefügt' } @{ $doc->{title} } ),
        'title includes 245$n and 249$a'
    );
    is_deeply( $doc->{publyear}, ['2021'], 'publication year from 264$c' );

    rollback();
};

subtest 'Indicator-qualified mappings index only fields with those indicators' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    reset_mappings();

    my $doc = document(
        MARC::Field->new( '945', 'a', 'f', a => '12' ),
        MARC::Field->new( '945', 'a', 'u', a => '6' ),
        MARC::Field->new( '945', 'a', 'a', a => '10' ),
        MARC::Field->new( '945', 'b', 'f', a => '99' ),
    );
    is_deeply( $doc->{'ekz-fsk'}, ['12'], 'FSK from 945 with indicators a/f only' );
    is_deeply( $doc->{'ekz-usk'}, ['6'],  'USK from 945 with indicators a/u' );
    is_deeply( $doc->{'ekz-age'}, ['10'], 'age from 945 with indicators a/a' );

    rollback();
};

subtest 'Sort values drop non-sorting parts and leading articles' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    reset_mappings();

    my $sort = sub { document( MARC::Field->new( '245', '1', '0', a => shift ) )->{title__sort}->[0] };
    is( $sort->("\x{0098}Der \x{009c}Zauberberg"), 'Zauberberg',   'marked non-sorting part' );
    is( $sort->('Die Blechtrommel'),               'Blechtrommel', 'German article' );

    rollback();
};

subtest 'Years are indexed as four digits only' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    reset_mappings();

    my $publyear = sub { document( MARC::Field->new( '264', ' ', '1', c => shift ) )->{publyear} };
    is_deeply( $publyear->('c2019'), ['2019'], 'a copyright year is reduced to its digits' );
    is_deeply( $publyear->('0000'),  [],       'a 0000 placeholder is not indexed' );

    rollback();
};

subtest 'Did-you-mean draws on the string_plus fields' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;
    reset_mappings();

    is_deeply(
        [ Koha::SearchEngine::Elasticsearch->get_didyoumean_fields ],
        [qw( author subject subject-genre-form title title-series )],
        'author, subject, interest group, title and series'
    );

    rollback();
};

subtest 'The LMSCloud query aliases search existing fields' => sub {
    plan tests => 2 * keys %lms_aliases;

    $schema->storage->txn_begin;
    reset_mappings();
    t::lib::Mocks::mock_preference( 'QueryAutoTruncate', 0 );

    foreach my $alias ( sort keys %lms_aliases ) {
        my $field = $lms_aliases{$alias};
        is( query_string( undef, ["$alias:x"] ), "($field:x)", "$alias searches $field" );
        ok( Koha::SearchFields->find( { name => $field } ), "$field is a search field of mappings.yaml" );
    }

    rollback();
};

subtest 'Query terms and limits' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;
    reset_mappings();
    t::lib::Mocks::mock_preference( 'QueryAutoTruncate',                         0 );
    t::lib::Mocks::mock_preference( 'ElasticsearchAdditionalAvailabilitySearch', '' );

    is( query_string( undef, ['Die drei ???'] ),           '(Die drei drei fragezeichen)', '??? is searched as words' );
    is( query_string( undef, ['katze and hund or maus'] ), '(katze AND hund OR maus)',     'lowercase operators work' );
    is( query_string( undef, ['pubdate>=2000'] ),          '(pubdate>=2000)',              '>= is kept' );
    is( query_string( undef, ['x'], undef, ['available'] ), '(x) AND availability:true', 'available limit' );

    t::lib::Mocks::mock_preference( 'ElasticsearchAdditionalAvailabilitySearch', 'NOT ekz-fsk:18' );
    is(
        query_string( undef, ['x'], undef, ['available'] ), '(x) AND (availability:true) AND (NOT ekz-fsk:18)',
        'available limit with the additional availability search'
    );

    rollback();
};

subtest 'Publication years reach copydate for the year limit' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;
    reset_mappings();
    t::lib::Mocks::mock_preference( 'QueryAutoTruncate', 0 );

    is_deeply(
        document( MARC::Field->new( '264', ' ', '1', c => '2021' ) )->{copydate}, ['2021'],
        'a year in 264$c'
    );
    is_deeply(
        document( MARC::Field->new( '260', ' ', ' ', c => '1999-' ) )->{copydate}, ['1999-'],
        'an open-ended run in 260$c'
    );
    is(
        query_string( undef, ['x'], undef, ['copydate,st-numeric=2021'] ), '(x) AND copydate:2021',
        'the year limit searches copydate'
    );

    rollback();
};
