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

use Modern::Perl;
use utf8;

use Test::More tests => 4;

use_ok('Koha::SEPAPayment');

# These methods work on plain data, so no database access and no call of new() is needed.
my $sepa = bless { verbose => 0, sepaSysPrefs => {} }, 'Koha::SEPAPayment';

subtest 'sepaPainFormat' => sub {
    plan tests => 5;

    $sepa->{sepaSysPrefs}->{SepaDirectDebitPainFormat} = undef;
    is( $sepa->sepaPainFormat, 'pain.008.001.02', 'undefined preference results in the old default format' );

    $sepa->{sepaSysPrefs}->{SepaDirectDebitPainFormat} = '';
    is( $sepa->sepaPainFormat, 'pain.008.001.02', 'empty preference results in the old default format' );

    $sepa->{sepaSysPrefs}->{SepaDirectDebitPainFormat} = 'pain.008.001.02';
    is( $sepa->sepaPainFormat, 'pain.008.001.02', 'pain.008.001.02 is accepted' );

    $sepa->{sepaSysPrefs}->{SepaDirectDebitPainFormat} = ' pain.008.001.08 ';
    is( $sepa->sepaPainFormat, 'pain.008.001.08', 'pain.008.001.08 is accepted, surrounding blanks are ignored' );

    $sepa->{sepaSysPrefs}->{SepaDirectDebitPainFormat} = 'pain.008.001.99';
    is( $sepa->sepaPainFormat, 'pain.008.001.02', 'unknown value results in the old default format' );
};

subtest 'bicElementName' => sub {
    plan tests => 3;

    is( $sepa->bicElementName('pain.008.001.02'), 'BIC',   'BIC in pain.008.001.02' );
    is( $sepa->bicElementName('pain.008.001.08'), 'BICFI', 'BICFI in pain.008.001.08' );
    is( $sepa->bicElementName(undef),             'BIC',   'BIC if no format is given' );
};

subtest 'remittanceInfo' => sub {
    plan tests => 9;

    # localtime style date parts: 2026-11-13
    my ( $year, $mon, $mday ) = ( 126, 10, 13 );
    my $borrower = {
        borrowernumber => 42,
        cardnumber     => '6720221397',
        surname        => 'Müller ',
        firstname      => 'Jürgen',
        dateofbirth    => undef,   # not selected by the real code, only used to test undefined values
    };

    is( $sepa->remittanceInfo( 'Jahresentgelt', $borrower, $year, $mon, $mday ),
        'Jahresentgelt', 'text without placeholders is unchanged' );
    is( $sepa->remittanceInfo( '441-<<borrowers.cardnumber>>-Jahresentgelt', $borrower, $year, $mon, $mday ),
        '441-6720221397-Jahresentgelt', 'cardnumber placeholder' );
    is( $sepa->remittanceInfo( '<<dd>>.<<mm>>.<<cc>><<yy>>', $borrower, $year, $mon, $mday ),
        '13.11.2026', 'date placeholders' );
    is( $sepa->remittanceInfo( '<<borrowers.surname>>, <<borrowers.firstname>>', $borrower, $year, $mon, $mday ),
        'Muller, Jurgen', 'patron values are transliterated to ASCII and trimmed' );
    is( $sepa->remittanceInfo( '<<borrowers.cardnumber>> <<borrowers.cardnumber>>', $borrower, $year, $mon, $mday ),
        '6720221397 6720221397', 'a placeholder can be used more than once' );
    is( $sepa->remittanceInfo( '[<<borrowers.dateofbirth>>]', $borrower, $year, $mon, $mday ),
        '[]', 'undefined patron value results in empty text' );
    is( $sepa->remittanceInfo( 'X<<borrowers.unknown>>Y<<unknown>>', $borrower, $year, $mon, $mday ),
        'X<<borrowers.unknown>>Y<<unknown>>', 'unknown placeholders are left unchanged' );
    is( length( $sepa->remittanceInfo( 'A' x 150, $borrower, $year, $mon, $mday ) ),
        140, 'result is cut to 140 characters' );
    is( $sepa->remittanceInfo( undef, undef, $year, $mon, $mday ), '', 'undefined template and patron do not die' );
};
