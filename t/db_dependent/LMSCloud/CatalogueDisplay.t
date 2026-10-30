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

use MARC::Field;

use C4::Biblio qw( ModBiblio );
use C4::XSLT;
use Koha::Biblios;
use Koha::Database;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'get_marc_notes() shows only $b of a 520 review that has $a and $b' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'marcflavour', 'MARC21' );
    t::lib::Mocks::mock_preference( 'NotesToHide', '' );

    my $biblio = $builder->build_sample_biblio;
    my $record = $biblio->metadata->record;
    $record->append_fields(
        MARC::Field->new( '520', '1', '', a => 'Review text | second review', b => 'Short review' ),
        MARC::Field->new( '520', '1', '', a => 'Review without short form' ),
        MARC::Field->new( '520', '8', '', a => 'Summary text' ),
    );
    ModBiblio( $record, $biblio->biblionumber );
    $biblio = Koha::Biblios->find( $biblio->biblionumber );

    my @notes = map { $_->{marcnote} } grep { ( $_->{tag} // '' ) eq '520' } @{ $biblio->get_marc_notes };
    is( $notes[0], 'Short review',              'Review with $a and $b shows only $b' );
    is( $notes[1], 'Review without short form', 'Review without $b shows $a' );
    is( $notes[2], 'Summary text',              'Other indicators show the whole field' );

    $schema->storage->txn_rollback;
};

subtest 'Staff detail XSLT labels and abridges 520 like 22.11' => sub {
    plan tests => 4;

    my $record = MARC::Record->new;
    $record->leader('00000nam a2200000 a 4500');
    $record->append_fields(
        MARC::Field->new( '245', '0', '0', a => 'Title' ),
        MARC::Field->new( '520', '1', ' ', a => 'Long review', b => 'Short review' ),
        MARC::Field->new( '520', '8', ' ', a => 'Summary text' ),
    );

    my $xslfile = C4::XSLT::_get_best_default_xslt_filename(
        C4::Context->config('intrahtdocs'), 'prog', 'en',
        'MARC21slim2intranetDetail.xsl'
    );
    my $html = C4::XSLT::engine->transform( { xml => $record->as_xml_record('MARC21'), file => $xslfile } );
    $html = $html->{output} if ref $html;

    like( $html, qr{<span class="label">Review: </span>Short review}, 'Review shows $b' );
    unlike( $html, qr{Long review}, 'Review hides $a when $b is present' );
    like( $html, qr{<span class="label">Summary: </span>Summary text}, 'ind1=8 is labelled as summary' );
    unlike( $html, qr{<span class="label"></span>}, 'No empty 520 label' );
};
