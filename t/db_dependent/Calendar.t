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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 6;
use t::lib::TestBuilder;

use DateTime;
use Koha::Caches;
use Koha::DateUtils;

use_ok('Koha::Calendar');

my $schema  = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $today = dt_from_string();
my $holiday_dt = $today->clone;
$holiday_dt->add(days => 15);

Koha::Caches->get_instance()->flush_all();

my $builder = t::lib::TestBuilder->new();
my $holiday = $builder->build({
    source => 'SpecialHoliday',
    value => {
        branchcode => 'LIB1',
        day => $holiday_dt->day,
        month => $holiday_dt->month,
        year => $holiday_dt->year,
        title => 'My holiday',
        isexception => 0
    },
});

my $calendar = Koha::Calendar->new( branchcode => 'LIB1');
my $forwarded_dt = $calendar->days_forward($today, 10);

my $expected = $today->clone;
$expected->add(days => 10);
is($forwarded_dt->ymd, $expected->ymd, 'With no holiday on the perioddays_forward should add 10 days');

$forwarded_dt = $calendar->days_forward($today, 20);

$expected->add(days => 11);
is($forwarded_dt->ymd, $expected->ymd, 'With holiday on the perioddays_forward should add 20 days + 1 day for holiday');

$forwarded_dt = $calendar->days_forward($today, 0);
is($forwarded_dt->ymd, $today->ymd, '0 day should return start dt');

$forwarded_dt = $calendar->days_forward($today, -2);
is($forwarded_dt->ymd, $today->ymd, 'negative day should return start dt');

subtest 'crossing_DST' => sub {

    plan tests => 3;

    my $tz = DateTime::TimeZone->new( name => 'America/New_York' );
    my $start_date = dt_from_string( "2016-03-09 02:29:00",undef,$tz );
    my $end_date = dt_from_string( "2017-01-01 00:00:00", undef, $tz );
    my $days_between = $calendar->days_between($start_date,$end_date);
    is( $days_between->delta_days, 298, "Days calculated correctly" );
    $days_between = $calendar->days_between($end_date,$start_date);
    is( $days_between->delta_days, 298, "Swapping returns the same" );
    my $hours_between = $calendar->hours_between($start_date,$end_date);
    is( $hours_between->delta_minutes, 298 * 24 * 60 - 149, "Hours (in minutes) calculated correctly" );

};

$schema->storage->txn_rollback();
