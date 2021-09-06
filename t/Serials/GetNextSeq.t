#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 43;
use C4::Serials;

# TEST CASE 1 - 1 variable, from 1 to 4
my $subscription = {
    lastvalue1 => 1, lastvalue2 => 1, lastvalue3 => 1,
    innerloop1 => 0, innerloop2 => 0, innerloop3 => 0,
    skip_serialseq => 0,
    irregularity => '',
    locale => 'en',
};
my $pattern = {
             add1 =>  1,          add2 =>  0,          add3 =>  0,
           every1 =>  1,        every2 =>  0,        every3 =>  0,
    whenmorethan1 =>  4, whenmorethan2 =>  0, whenmorethan3 =>  0,
           setto1 =>  1,        setto2 =>  0,        setto3 =>  0,
    numberingmethod => 'X: {X}',
    numbering1 => '',
    numbering2 => '',
    numbering3 => '',
};

my $seq = _next_seq($subscription, $pattern);
is($seq, 'X: 2');
$seq = _next_seq($subscription, $pattern);
is($seq, 'X: 3');
$seq = _next_seq($subscription, $pattern);
is($seq, 'X: 4');
$seq = _next_seq($subscription, $pattern);
is($seq, 'X: 1');
$seq = _next_seq($subscription, $pattern);
is($seq, 'X: 2');

# TEST CASE 2 - 1 variable, use 'dayname' numbering, from 1 to 7
$subscription = {
    lastvalue1 => 1, lastvalue2 => 1, lastvalue3 => 1,
    innerloop1 => 0, innerloop2 => 0, innerloop3 => 0,
    skip_serialseq => 0,
    irregularity => '',
    locale => 'C',
};
$pattern = {
             add1 =>  1,          add2 =>  1,          add3 =>  0,
           every1 =>  1,        every2 =>  1,        every3 =>  0,
    whenmorethan1 =>  7, whenmorethan2 =>  7, whenmorethan3 =>  0,
           setto1 =>  1,        setto2 =>  1,        setto3 =>  0,
    numberingmethod => 'dayname: {X} | dayabrv: {Y}',
    numbering1 => 'dayname',
    numbering2 => 'dayabrv',
    numbering3 => '',
};

$seq = _next_seq($subscription, $pattern);
is($seq, 'dayname: Tuesday | dayabrv: Tue');
$seq = _next_seq($subscription, $pattern);
is($seq, 'dayname: Wednesday | dayabrv: Wed');
$seq = _next_seq($subscription, $pattern);
is($seq, 'dayname: Thursday | dayabrv: Thu');
$seq = _next_seq($subscription, $pattern);
is($seq, 'dayname: Friday | dayabrv: Fri');
$seq = _next_seq($subscription, $pattern);
is($seq, 'dayname: Saturday | dayabrv: Sat');
$seq = _next_seq($subscription, $pattern);
is($seq, 'dayname: Sunday | dayabrv: Sun');
$seq = _next_seq($subscription, $pattern);
is($seq, 'dayname: Monday | dayabrv: Mon');

# TEST CASE 3 - 1 variable, use 'monthname' numbering, from 0 to 11 by step of 2
$subscription = {
    lastvalue1 => 0, lastvalue2 => 0, lastvalue3 => 0,
    innerloop1 => 0, innerloop2 => 0, innerloop3 => 0,
    skip_serialseq => 0,
    irregularity => '',
    locale => 'C',  # locale set to 'C' to ensure we'll have english strings
};
$pattern = {
             add1 =>  2,          add2 =>  2,           add3 =>  0,
           every1 =>  1,        every2 =>  1,         every3 =>  0,
    whenmorethan1 => 11, whenmorethan2 =>  11, whenmorethan3 =>  0,
           setto1 =>  0,        setto2 =>  0,         setto3 =>  0,
    numberingmethod => 'monthname: {X} | monthabrv: {Y}',
    numbering1 => 'monthname',
    numbering2 => 'monthabrv',
    numbering3 => '',
};

$seq = _next_seq($subscription, $pattern);
is($seq, 'monthname: March | monthabrv: Mar');
$seq = _next_seq($subscription, $pattern);
is($seq, 'monthname: May | monthabrv: May');
$seq = _next_seq($subscription, $pattern);
is($seq, 'monthname: July | monthabrv: Jul');
$seq = _next_seq($subscription, $pattern);
is($seq, 'monthname: September | monthabrv: Sep');
$seq = _next_seq($subscription, $pattern);
is($seq, 'monthname: November | monthabrv: Nov');
$seq = _next_seq($subscription, $pattern);
is($seq, 'monthname: January | monthabrv: Jan');
$seq = _next_seq($subscription, $pattern);
is($seq, 'monthname: March | monthabrv: Mar');

# TEST CASE 4 - 1 variable, use 'season' numbering, from 0 to 3
# Months starts at 0, this implies subscription's lastvalue1 should be 0,
# together with setto1 and whenmorethan1 should be 11
$subscription = {
    lastvalue1 => 0, lastvalue2 => 0, lastvalue3 => 0,
    innerloop1 => 0, innerloop2 => 0, innerloop3 => 0,
    skip_serialseq => 0,
    irregularity => '',
    locale => 'C',  # locale set to 'C' to ensure we'll have english strings
};
$pattern = {
             add1 =>  1,          add2 =>  1,          add3 =>  0,
           every1 =>  1,        every2 =>  1,        every3 =>  0,
    whenmorethan1 =>  3, whenmorethan2 =>  3, whenmorethan3 =>  0,
           setto1 =>  0,        setto2 =>  0,        setto3 =>  0,
    numberingmethod => 'season: {X} | seasonabrv: {Y}',
    numbering1 => 'season',
    numbering2 => 'seasonabrv',
    numbering3 => '',
};

$seq = _next_seq($subscription, $pattern);
is($seq, 'season: Summer | seasonabrv: Sum');
$seq = _next_seq($subscription, $pattern);
is($seq, 'season: Fall | seasonabrv: Fal');
$seq = _next_seq($subscription, $pattern);
is($seq, 'season: Winter | seasonabrv: Win');
$seq = _next_seq($subscription, $pattern);
is($seq, 'season: Spring | seasonabrv: Spr');
$seq = _next_seq($subscription, $pattern);
is($seq, 'season: Summer | seasonabrv: Sum');

# TEST CASE 5 - 2 variables, from 1 to 12, and from 1 to 4
$subscription = {
    lastvalue1 => 1, lastvalue2 => 1, lastvalue3 => 1,
    innerloop1 => 0, innerloop2 => 0, innerloop3 => 0,
    skip_serialseq => 0,
    irregularity => '',
    locale => 'C',  # locale set to 'C' to ensure we'll have english strings
};
$pattern = {
             add1 =>  1,          add2 =>  1,          add3 =>  0,
           every1 =>  1,        every2 =>  4,        every3 =>  0,
    whenmorethan1 =>  4, whenmorethan2 => 12, whenmorethan3 =>  0,
           setto1 =>  1,        setto2 =>  1,        setto3 =>  0,
    numberingmethod => 'Y: {Y}, X: {X}',
    numbering1 => '',
    numbering2 => '',
    numbering3 => '',
};

$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 1, X: 2');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 1, X: 3');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 1, X: 4');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 2, X: 1');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 2, X: 2');
# Back to the future
for (1..39) {
    $seq = _next_seq($subscription, $pattern);
}
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 12, X: 2');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 12, X: 3');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 12, X: 4');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Y: 1, X: 1');

# TEST CASE 6 - 3 variables, from 1 to 12, from 1 to 8, and from 1 to 4
$subscription = {
    lastvalue1 => 1, lastvalue2 => 1, lastvalue3 => 1,
    innerloop1 => 0, innerloop2 => 0, innerloop3 => 0,
    skip_serialseq => 0,
    irregularity => '',
    locale => 'C',  # locale set to 'C' to ensure we'll have english strings
};
$pattern = {
             add1 =>  1,          add2 =>  1,          add3 =>  1,
           every1 =>  1,        every2 =>  4,        every3 =>  32,
    whenmorethan1 =>  4, whenmorethan2 =>  8, whenmorethan3 =>  12,
           setto1 =>  1,        setto2 =>  1,        setto3 =>  1,
    numberingmethod => 'Z: {Z}, Y: {Y}, X: {X}',
    numbering1 => '',
    numbering2 => '',
    numbering3 => '',
};

$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 1, X: 2');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 1, X: 3');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 1, X: 4');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 2, X: 1');
for (1..24) {
    $seq = _next_seq($subscription, $pattern);
}
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 8, X: 2');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 8, X: 3');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 8, X: 4');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 2, Y: 1, X: 1');
for (1..350) {
    $seq = _next_seq($subscription, $pattern);
}
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 12, Y: 8, X: 4');
$seq = _next_seq($subscription, $pattern);
is($seq, 'Z: 1, Y: 1, X: 1');


sub _next_seq {
    my ($subscription, $pattern) = @_;
    my $seq;
    ($seq, $subscription->{lastvalue1}, $subscription->{lastvalue2},
        $subscription->{lastvalue3}, $subscription->{innerloop1},
        $subscription->{innerloop2}, $subscription->{innerloop3}) =
            GetNextSeq($subscription, $pattern);
    return $seq;
}
