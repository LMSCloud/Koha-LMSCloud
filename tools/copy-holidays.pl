#!/usr/bin/perl

# Copyright 2012 Catalyst IT
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

use CGI qw ( -utf8 );

use C4::Auth;
use C4::Output;
use C4::Calendar;

use Koha::DateUtils;

my $input               = new CGI;
my $dbh                 = C4::Context->dbh();

checkauth($input, 0, {tools=> 'edit_calendar'}, 'intranet');

my $branchcode             = $input->param('branchcode');
my $branchgroup            = $input->param('branchgroup');
my $from_branchcode        = $input->param('from_branchcode');
my $limitcopydaterange     = $input->param('limitcopydaterange');
my $limitcopydeletebefore  = $input->param('limitcopydeletebefore');
my $datefrom               = $input->param('datefrom');
my $dateto                 = $input->param('dateto');

if ( $limitcopydaterange ) {
    $datefrom = eval { output_pref({ dt => dt_from_string( $datefrom ), dateformat => 'iso', dateonly => 1 } ); };
    $dateto = eval { output_pref({ dt => dt_from_string( $dateto ), dateformat => 'iso', dateonly => 1 } ); };
    
    if ( $datefrom && $dateto ) {
        if ( $branchgroup && $from_branchcode ) {
            C4::Calendar->new(branchcode => $from_branchcode)->copy_to_group_special($branchgroup,$datefrom,$dateto,$limitcopydeletebefore);
        }
        elsif ( $branchcode && $from_branchcode  ) {
            C4::Calendar->new(branchcode => $from_branchcode)->copy_to_branch_special($branchcode,$datefrom,$dateto,$limitcopydeletebefore);
        }
    }
}
else {
    if ( $branchgroup && $from_branchcode ) {
        C4::Calendar->new(branchcode => $from_branchcode)->copy_to_group($branchgroup);
    }
    elsif ( $branchcode && $from_branchcode  ) {
        C4::Calendar->new(branchcode => $from_branchcode)->copy_to_branch($branchcode);
    }
}

print $input->redirect("/cgi-bin/koha/tools/holidays.pl?branch=".($branchcode || $from_branchcode));
