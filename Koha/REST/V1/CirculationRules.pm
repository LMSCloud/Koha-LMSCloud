package Koha::REST::V1::CirculationRules;

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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Calendar;
use Koha::CirculationRules;
use Koha::DateUtils qw( dt_from_string );

use C4::Circulation qw( GetLoanLength CalcDateDue _GetCircControlBranch );

use Try::Tiny qw( catch try );

=head1 PRIVATE METHODS

=head2 _public_rule_kinds

Get the list of circulation rule kinds that are allowed for public access

=cut

sub _public_rule_kinds {
    return [
        'bookings_lead_period',
        'bookings_trail_period',
        'issuelength',
        'renewalsallowed',
        'renewalperiod'
    ];
}

=head2 _add_days_with_calendar

Add days to a date using the Koha calendar for the given days_mode

=cut

sub _add_days_with_calendar {
    my ( $date, $days, $branchcode, $mode ) = @_;
    my $calendar = Koha::Calendar->new( branchcode => $branchcode, days_mode => $mode );
    my $dur      = DateTime::Duration->new( days => $days );
    my $new_date = $calendar->addDuration( $date->clone, $dur, 'days' );
    $new_date->set_hour(23);
    $new_date->set_minute(59);
    return $new_date;
}

=head2 _calculate_circulation_dates

Calculate due dates and periods using CalcDateDue

    my $calculated_data = _calculate_circulation_dates({
        patron_category => $patron_category,
        item_type => $item_type,
        branchcode => $branchcode,
        start_date => $start_date,
        existing_rules => $existing_rules,
        date_range_constraint => $date_range_constraint
    });

=cut

sub _calculate_circulation_dates {
    my ($args) = @_;

    my $patron_category       = $args->{patron_category};
    my $item_type             = $args->{item_type};
    my $branchcode            = $args->{branchcode};
    my $start_date            = $args->{start_date};
    my $existing_rules        = $args->{existing_rules};
    my $date_range_constraint = $args->{date_range_constraint};

    if ( !defined $branchcode ) {
        return {};
    }

    if ( !defined $item_type || !defined $patron_category ) {
        return {};
    }

    my $test_item = {
        itype         => $item_type,
        homebranch    => $branchcode,
        holdingbranch => $branchcode,
    };

    my $test_patron = {
        categorycode => $patron_category,
        branchcode   => $branchcode,
    };

    my $circ_branch      = _GetCircControlBranch( $test_item, $test_patron );
    my $effective_branch = $circ_branch || $branchcode;

    my $start_dt    = $start_date ? dt_from_string( $start_date, 'rfc3339' ) : dt_from_string();
    my $due_date    = CalcDateDue( $start_dt, $item_type, $effective_branch, $test_patron );
    my $period_days = $start_dt->delta_days($due_date)->in_units('days');

    my $loanlength = GetLoanLength( $patron_category, $item_type, $effective_branch );

    if ( !$date_range_constraint || $date_range_constraint ne 'issuelength_with_renewals' ) {
        return {
            calculated_due_date    => join( q{ }, $due_date->ymd(), $due_date->hms() ),
            calculated_period_days => $period_days,
            circulation_branch     => $effective_branch,
            lengthunit             => $loanlength->{lengthunit} // 'days',
        };
    }

    my $renewalsallowed = $existing_rules->{renewalsallowed} // 0;
    my $renewalperiod   = $existing_rules->{renewalperiod}   // 0;

    if ( $renewalsallowed <= 0 || $renewalperiod <= 0 ) {
        return {
            calculated_due_date    => join( q{ }, $due_date->ymd(), $due_date->hms() ),
            calculated_period_days => $period_days,
            circulation_branch     => $effective_branch,
            lengthunit             => $loanlength->{lengthunit} // 'days',
        };
    }

    my $renewal_days = $renewalsallowed * $renewalperiod;

    my $daysmode = Koha::CirculationRules->get_effective_daysmode(
        {
            categorycode => $patron_category,
            itemtype     => $item_type,
            branchcode   => $effective_branch,
        }
    );

    my $daysmode_handlers = {
        Days     => sub { my ( $date, $days ) = @_; return $date->clone->add( days => $days ); },
        Calendar => sub { return _add_days_with_calendar( @_, $effective_branch, 'Calendar' ); },
        Datedue  => sub { return _add_days_with_calendar( @_, $effective_branch, 'Datedue' ); },
        Dayweek  => sub { return _add_days_with_calendar( @_, $effective_branch, 'Dayweek' ); },
    };

    my $handler  = $daysmode_handlers->{$daysmode} // $daysmode_handlers->{Days};
    $due_date    = $handler->( $due_date, $renewal_days );
    $period_days = $start_dt->delta_days($due_date)->in_units('days');

    return {
        calculated_due_date    => join( q{ }, $due_date->ymd(), $due_date->hms() ),
        calculated_period_days => $period_days,
        circulation_branch     => $effective_branch,
        lengthunit             => $loanlength->{lengthunit} // 'days',
    };
}

=head1 API

=head2 Methods

=head3 get_kinds

List all available circulation rules that can be used.

=cut

sub get_kinds {
    my $c = shift->openapi->valid_input or return;

    return $c->render(
        status  => 200,
        openapi => Koha::CirculationRules->rule_kinds,
    );
}

=head3 list_rules

Get effective rules for the requested patron/item/branch combination

=cut

sub list_rules {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $effective = $c->param('effective') // 1;
        my $kinds =
            defined( $c->param('rules') )
            ? [ split /\s*,\s*/, $c->param('rules') ]
            : [ keys %{ Koha::CirculationRules->rule_kinds } ];
        my $item_type       = $c->param('item_type_id');
        my $branchcode      = $c->param('library_id');
        my $patron_category = $c->param('patron_category_id');
        my $calculate_dates = $c->param('calculate_dates');
        my $start_date      = $c->param('start_date');
        my ( $filter_branch, $filter_itemtype, $filter_patron );

        if ($item_type) {
            $filter_itemtype = 1;
            if ( $item_type eq '*' ) {
                $item_type = undef;
            } else {
                my $type = Koha::ItemTypes->find($item_type);
                return $c->render(
                    status  => 400,
                    openapi => {
                        error      => 'Invalid parameter value',
                        error_code => 'invalid_parameter_value',
                        path       => '/query/item_type_id',
                        values     => {
                            uri   => '/api/v1/item_types',
                            field => 'item_type_id'
                        }
                    }
                ) unless $type;
            }
        }

        if ($branchcode) {
            $filter_branch = 1;
            if ( $branchcode eq '*' ) {
                $branchcode = undef;
            } else {
                my $library = Koha::Libraries->find($branchcode);
                return $c->render(
                    status  => 400,
                    openapi => {
                        error      => 'Invalid parameter value',
                        error_code => 'invalid_parameter_value',
                        path       => '/query/library_id',
                        values     => {
                            uri   => '/api/v1/libraries',
                            field => 'library_id'
                        }
                    }
                ) unless $library;
            }
        }

        if ($patron_category) {
            $filter_patron = 1;
            if ( $patron_category eq '*' ) {
                $patron_category = undef;
            } else {
                my $category = Koha::Patron::Categories->find($patron_category);
                return $c->render(
                    status  => 400,
                    openapi => {
                        error      => 'Invalid parameter value',
                        error_code => 'invalid_parameter_value',
                        path       => '/query/patron_category_id',
                        values     => {
                            uri   => '/api/v1/patron_categories',
                            field => 'patron_category_id'
                        }
                    }
                ) unless $category;
            }
        }

        my $rules;
        if ($effective) {

            my $effective_rules = Koha::CirculationRules->get_effective_rules(
                {
                    categorycode => $patron_category,
                    itemtype     => $item_type,
                    branchcode   => $branchcode,
                    rules        => $kinds
                }
            ) // {};
            my $return;
            for my $kind ( @{$kinds} ) {
                $return->{$kind} = $effective_rules->{$kind};
            }

            if ( $calculate_dates && $effective ) {
                my $date_range_constraint = C4::Context->preference('BookingDateRangeConstraint');
                my $calculated_data       = _calculate_circulation_dates(
                    {
                        patron_category       => $patron_category,
                        item_type             => $item_type,
                        branchcode            => $branchcode,
                        start_date            => $start_date,
                        existing_rules        => $effective_rules,
                        date_range_constraint => $date_range_constraint,
                    }
                );

                %{$return} = ( %{$return}, %{$calculated_data} );
            }

            my $has_booking_rules = grep { /^booking/ } @{$kinds};
            if ($has_booking_rules) {
                $return->{booking_constraint_mode} = C4::Context->preference('BookingConstraintMode') || 'range';
            }

            push @{$rules}, $return;
        } else {
            my $select = [
                { 'COALESCE' => [ 'branchcode',   \["'*'"] ], -as => 'branchcode' },
                { 'COALESCE' => [ 'categorycode', \["'*'"] ], -as => 'categorycode' },
                { 'COALESCE' => [ 'itemtype',     \["'*'"] ], -as => 'itemtype' }
            ];
            my $as = [ 'branchcode', 'categorycode', 'itemtype' ];
            for my $kind ( @{$kinds} ) {
                push @{$select}, { max => \[ "CASE WHEN rule_name = ? THEN rule_value END", $kind ], -as => $kind };
                push @{$as}, $kind;
            }

            $rules = Koha::CirculationRules->search(
                {
                    ( $filter_branch   ? ( branchcode   => $branchcode )      : () ),
                    ( $filter_itemtype ? ( itemtype     => $item_type )       : () ),
                    ( $filter_patron   ? ( categorycode => $patron_category ) : () )
                },
                {
                    select   => $select,
                    as       => $as,
                    group_by => [ 'branchcode', 'categorycode', 'itemtype' ]
                }
            )->unblessed;

        }

        return $c->render(
            status  => 200,
            openapi => $rules
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_kinds_public

Get circulation rule kinds available for public access

=cut

sub get_kinds_public {
    my $c = shift->openapi->valid_input or return;

    my $allowed_kinds = _public_rule_kinds();
    my %public_rule_kinds;

    my $all_kinds = Koha::CirculationRules->rule_kinds;
    for my $kind ( @{$allowed_kinds} ) {
        $public_rule_kinds{$kind} = $all_kinds->{$kind} if exists $all_kinds->{$kind};
    }

    return $c->render(
        status  => 200,
        openapi => \%public_rule_kinds,
    );
}

=head3 list_rules_public

Get effective circulation rules for public access

=cut

sub list_rules_public {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron_category = $c->param('patron_category_id');
        my $item_type       = $c->param('item_type_id');
        my $branchcode      = $c->param('library_id');
        my $calculate_dates = $c->param('calculate_dates');
        my $start_date      = $c->param('start_date');

        my $allowed_kinds   = _public_rule_kinds();
        my $requested_rules = $c->param('rules');

        my $kinds;
        if ($requested_rules) {
            my @requested = split /\s*,\s*/, $requested_rules;
            my %allowed   = map { $_ => 1 } @{$allowed_kinds};

            my @filtered_kinds = grep { $allowed{$_} } @requested;
            $kinds = @filtered_kinds ? \@filtered_kinds : $allowed_kinds;
        } else {
            $kinds = $allowed_kinds;
        }

        my $effective_rules = Koha::CirculationRules->get_effective_rules(
            {
                categorycode => $patron_category,
                itemtype     => $item_type,
                branchcode   => $branchcode,
                rules        => $kinds
            }
        ) // {};

        my $return = {};
        for my $kind ( @{$kinds} ) {
            $return->{$kind} = $effective_rules->{$kind};
        }

        if ($calculate_dates) {
            my $date_range_constraint = C4::Context->preference('OPACBookingDateRangeConstraint');
            my $calculated_data       = _calculate_circulation_dates(
                {
                    patron_category       => $patron_category,
                    item_type             => $item_type,
                    branchcode            => $branchcode,
                    start_date            => $start_date,
                    existing_rules        => $effective_rules,
                    date_range_constraint => $date_range_constraint,
                }
            );

            %{$return} = ( %{$return}, %{$calculated_data} );
        }

        my $has_booking_rules = grep { /^booking/ } @{$kinds};
        if ($has_booking_rules) {
            $return->{booking_constraint_mode} = C4::Context->preference('OPACBookingConstraintMode') || 'range';
        }

        return $c->render(
            status  => 200,
            openapi => [$return],
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
