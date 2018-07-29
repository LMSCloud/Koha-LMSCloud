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

#####Sets holiday periods for each branch. Datedues will be extended if branch is closed -TG
use Modern::Perl;

use CGI qw ( -utf8 );

use C4::Auth;
use C4::Output;

use C4::Calendar;
use Koha::DateUtils;

use Koha::Library;

my $input = new CGI;

my $dbh = C4::Context->dbh();
# Get the template to use
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "tools/holidays.tt",
                             type => "intranet",
                             query => $input,
                             authnotrequired => 0,
                             flagsrequired => {tools => 'edit_calendar'},
                             debug => 1,
                           });

# calendardate - date passed in url for human readability (syspref)
# if the url has an invalid date default to 'now.'
my $calendarinput_dt = eval { dt_from_string( scalar $input->param('calendardate') ); } || dt_from_string;
my $calendardate = output_pref( { dt => $calendarinput_dt, dateonly => 1 } );

# keydate - date passed to calendar.js.  calendar.js does not process dashes within a date.
my $keydate = output_pref( { dt => $calendarinput_dt, dateonly => 1, dateformat => 'iso' } );
$keydate =~ s/-/\//g;

my $branch= $input->param('branch') || C4::Context->userenv->{'branch'};

# Get all the holidays

my $calendar = C4::Calendar->new(branchcode => $branch);
my $week_days_holidays = $calendar->get_week_days_holidays();
my @week_days;
foreach my $weekday (keys %$week_days_holidays) {
# warn "WEEK DAY : $weekday";
    my %week_day;
    %week_day = (KEY => $weekday,
                 TITLE => $week_days_holidays->{$weekday}{title},
                 DESCRIPTION => $week_days_holidays->{$weekday}{description});
    push @week_days, \%week_day;
}

my $day_month_holidays = $calendar->get_day_month_holidays();
my @day_month_holidays;
foreach my $monthDay (keys %$day_month_holidays) {
    # Determine date format on month and day.
    my $day_monthdate;
    my $day_monthdate_sort;
    if (C4::Context->preference("dateformat") eq "metric") {
      $day_monthdate_sort = "$day_month_holidays->{$monthDay}{month}-$day_month_holidays->{$monthDay}{day}";
      $day_monthdate = "$day_month_holidays->{$monthDay}{day}/$day_month_holidays->{$monthDay}{month}";
    } elsif (C4::Context->preference("dateformat") eq "dmydot") {
      $day_monthdate_sort = "$day_month_holidays->{$monthDay}{month}.$day_month_holidays->{$monthDay}{day}";
      $day_monthdate = "$day_month_holidays->{$monthDay}{day}.$day_month_holidays->{$monthDay}{month}";
    }elsif (C4::Context->preference("dateformat") eq "us") {
      $day_monthdate = "$day_month_holidays->{$monthDay}{month}/$day_month_holidays->{$monthDay}{day}";
      $day_monthdate_sort = $day_monthdate;
    } else {
      $day_monthdate = "$day_month_holidays->{$monthDay}{month}-$day_month_holidays->{$monthDay}{day}";
      $day_monthdate_sort = $day_monthdate;
    }
    my %day_month;
    %day_month = (KEY => $monthDay,
                  DATE_SORT => $day_monthdate_sort,
                  DATE => $day_monthdate,
                  TITLE => $day_month_holidays->{$monthDay}{title},
                  DESCRIPTION => $day_month_holidays->{$monthDay}{description});
    push @day_month_holidays, \%day_month;
}

my $exception_holidays = $calendar->get_exception_holidays();
my @exception_holidays;
foreach my $yearMonthDay (keys %$exception_holidays) {
    my $exceptiondate = eval { dt_from_string( $exception_holidays->{$yearMonthDay}{date} ) };
    my %exception_holiday;
    %exception_holiday = (KEY => $yearMonthDay,
                          DATE_SORT => $exception_holidays->{$yearMonthDay}{date},
                          DATE => output_pref( { dt => $exceptiondate, dateonly => 1 } ),
                          TITLE => $exception_holidays->{$yearMonthDay}{title},
                          DESCRIPTION => $exception_holidays->{$yearMonthDay}{description});
    push @exception_holidays, \%exception_holiday;
}

my $single_holidays = $calendar->get_single_holidays();
my @holidays;
foreach my $yearMonthDay (keys %$single_holidays) {
    my $holidaydate_dt = eval { dt_from_string( $single_holidays->{$yearMonthDay}{date} ) };
    my %holiday;
    %holiday = (KEY => $yearMonthDay,
                DATE_SORT => $single_holidays->{$yearMonthDay}{date},
                DATE => output_pref( { dt => $holidaydate_dt, dateonly => 1 } ),
                TITLE => $single_holidays->{$yearMonthDay}{title},
                DESCRIPTION => $single_holidays->{$yearMonthDay}{description});
    push @holidays, \%holiday;
}

########################################
#  Read library groups
########################################
my @search_groups =
  Koha::Library::Groups->get_search_groups( { interface => 'staff' } );
@search_groups = sort { $a->title cmp $b->title } @search_groups;

$template->param(
    WEEK_DAYS_LOOP           => \@week_days,
    HOLIDAYS_LOOP            => \@holidays,
    EXCEPTION_HOLIDAYS_LOOP  => \@exception_holidays,
    DAY_MONTH_HOLIDAYS_LOOP  => \@day_month_holidays,
    calendardate             => $calendardate,
    keydate                  => $keydate,
    branch                   => $branch,
    librarygroups            => \@search_groups,
);

# Shows the template with the real values replaced
output_html_with_http_headers $input, $cookie, $template->output;
