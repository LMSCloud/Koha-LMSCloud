package Koha::Issues;

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
use DateTime;

use Koha::Database;
use Koha::Issue;
use Koha::DateUtils;


use base qw(Koha::Objects);

sub _type {
    return 'Issue';
}

sub object_class {
    return 'Koha::Issue';
}

sub getIssueDatesAndBranches {
    my ($self,$params) = @_;
    
    my ($selectbranch,$selectgroup,$result,$where) = ('','',{},{});
    
    $selectbranch = $params->{branchcode} if ( defined($params) && defined($params->{branchcode}) );
    $selectgroup = $params->{categorycode} if ( defined($params) && defined($params->{categorycode}) );

    if ( $selectbranch ) {
        $where = { branchcode => $selectbranch };
    }
    elsif ( $selectgroup ) {
        my $schema = Koha::Database->new->schema;
        my $inside_rs = $schema->resultset('Branchrelation')->search({ categorycode => $selectgroup });
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

sub getIssueDueOnSelectedDate {
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
        my $inside_rs = $schema->resultset('Branchrelation')->search({ categorycode => $selectgroup });
        $where = { branchcode => { IN => $inside_rs->get_column('branchcode')->as_query } };
    }
    
    $where->{ date_due } = { 'like' => $params->{datedue} . '%' };

    $result = $self->search($where);
    
    return $result;
}

1;
