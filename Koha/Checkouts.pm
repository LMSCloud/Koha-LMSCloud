package Koha::Checkouts;

# Copyright ByWater Solutions 2015
# Updated LMSCloud 2021
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Carp;

use C4::Context;
use C4::Circulation;
use Koha::Checkout;
use Koha::Database;
use Koha::DateUtils;

use Koha::DateUtils;

use base qw(Koha::Objects);

=head1 NAME

Koha::Checkouts - Koha Checkout object set class

=head1 API

=head2 Class Methods

=cut

=head3 get_issue_dates_and_branches

my $issue_dates = Koha::Checkouts::new()->get_issue_dates_and_branches();

returns a hash reference with due dates if items containing information of branches and counts 

=cut

sub get_issue_dates_and_branches {
    my ($self,$params) = @_;
    
    my ($selectbranch,$selectgroup,$result,$where) = ('','',{},{});
    
    $selectbranch = $params->{branchcode} if ( defined($params) && defined($params->{branchcode}) );
    $selectgroup = $params->{categorycode} if ( defined($params) && defined($params->{categorycode}) );

    if ( $selectbranch ) {
        $where = { branchcode => $selectbranch };
    }
    elsif ( $selectgroup ) {
        my $schema = Koha::Database->new->schema;
        my $inside_rs = $schema->resultset('LibraryGroup')->search({ parent_id => $selectgroup });
        $where = { branchcode => { IN => $inside_rs->get_column('branchcode')->as_query } };
    }

    my $today_iso = output_pref( { dt => dt_from_string, dateonly => 1, dateformat => 'iso' });
    foreach my $issue($self->search($where, 
        {
            group_by => [ 
                { DATE => 'date_due' },
                'branchcode'
            ],
            select => [
              'branchcode',
              { count => '*' },
              { DATE => 'date_due' }
            ],
            as => [qw/
              branchcode
              count
              date_due
            /]
        })) 
    {
        my $found = $issue->unblessed();
        
        if ( $found->{date_due} ge $today_iso ) {
            $result->{$found->{date_due}}->{count} += $found->{count};
            $result->{$found->{date_due}}->{branchcode}->{$found->{branchcode}} = $found->{count};
        }
    }
    
    return $result;
}

=head3 get_issue_due_on_selected_date

my $params = {};

$params->{branchcode} = 'MAIN';
$params->{datedue} = '20271201';

my $issues = Koha::Checkouts::new()->get_issue_due_on_selected_date($params);

select issues that due on a specific date

=cut

sub get_issue_due_on_selected_date {
    my ($self,$params) = @_;
    
    my ($selectbranch,$selectgroup,$where) = ('','',{});
    
    my $result = undef;
    
    $selectbranch = $params->{branchcode} if ( defined($params) && defined($params->{branchcode}) );
    $selectgroup = $params->{categorycode} if ( defined($params) && defined($params->{categorycode}) );
    
    return undef if (! defined($params->{datedue}) );

    if ( $selectbranch ) {
        $where = { branchcode => $selectbranch };
    }
    elsif ( $selectgroup ) {
        my $schema = Koha::Database->new->schema;
        my $inside_rs = $schema->resultset('LibraryGroup')->search({ parent_id => $selectgroup });
        $where = { branchcode => { IN => $inside_rs->get_column('branchcode')->as_query } };
    }
    
    $where->{ date_due } = { 'like' => $params->{datedue} . '%' };

    $result = $self->search($where);
    
    return $result;
}

=head3 calculate_dropbox_date

my $dt = Koha::Checkouts::calculate_dropbox_date();

=cut

sub calculate_dropbox_date {
    my $userenv    = C4::Context->userenv;
    my $branchcode = $userenv->{branch} // q{};

    my $daysmode = Koha::CirculationRules->get_effective_daysmode(
        {
            categorycode => undef,
            itemtype     => undef,
            branchcode   => $branchcode,
        }
    );
    my $calendar     = Koha::Calendar->new( branchcode => $branchcode, days_mode => $daysmode );
    my $today        = dt_from_string;
    my $dropbox_date = $calendar->addDuration( $today, -1 );

    return $dropbox_date;
}

=head3 automatic_checkin

my $automatic_checkins = Koha::Checkouts->automatic_checkin()

Checks in every due issue which itemtype has automatic_checkin enabled

=cut

sub automatic_checkin {
    my ($self, $params) = @_;

    my $current_date = dt_from_string;

    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $due_checkouts = $self->search(
        { date_due => { '<=' => $dtf->format_datetime($current_date) } },
        { prefetch => 'item'}
    );

    while ( my $checkout = $due_checkouts->next ) {
        if ( $checkout->item->itemtype->automatic_checkin ) {
            C4::Circulation::AddReturn( $checkout->item->barcode,
                $checkout->branchcode, undef, dt_from_string($checkout->date_due) );
        }
    }
}

=head3 type

=cut

sub _type {
    return 'Issue';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Checkout';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
