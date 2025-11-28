#!/usr/bin/perl

# Copyright 2020 LMSCloud GmbH
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

use C4::Auth qw(get_template_and_user);
use CGI qw ( -utf8 );
use C4::Context;
use C4::Koha;
use C4::Output qw(output_html_with_http_headers);
use C4::Budgets;

use Koha::DateUtils qw( dt_from_string );

=head1 acquisitionStart.pl

alternative start page of the aquisition module for BZSH

=cut

my $input = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "acqui/acquisitionStart.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { 'acquisition' => '*' },
        debug           => 1,
    }
);

my $filters = {
    basket                  => scalar $input->param('basket'),
    title                   => scalar $input->param('title'),
    author                  => scalar $input->param('author'),
    isbn                    => scalar $input->param('isbn'),
    issn                    => scalar $input->param('issn'),
    name                    => scalar $input->param('name'),
    internalnote            => scalar $input->param('internalnote'),
    vendornote              => scalar $input->param('vendornote'),
    ean                     => scalar $input->param('ean'),
    basketgroupname         => scalar $input->param('basketgroupname'),
    budget                  => scalar $input->param('budget'),
    booksellerinvoicenumber => scalar $input->param('booksellerinvoicenumber'),
    budget                  => scalar $input->param('budget'),
    orderstatus             => scalar $input->param('orderstatus'),
    is_standing             => scalar $input->param('is_standing'),
    ordernumber             => scalar $input->param('ordernumber'),
    search_children_too     => scalar $input->param('search_children_too'),
    created_by              => [ $input->multi_param('created_by') ],
    managing_library        => scalar $input->param('managing_library'),
};

my $from_placed_on = eval { dt_from_string( scalar $input->param('from') ) } || dt_from_string;
my $to_placed_on   = eval { dt_from_string( scalar $input->param('to')   ) } || dt_from_string;
unless ( $input->param('from') ) {
    # Fill the form with year-1
    $from_placed_on->set_time_zone('floating')->subtract( years => 1 );
}
$filters->{from_placed_on} = $from_placed_on;
$filters->{to_placed_on}   = $to_placed_on;

my $budgetperiods = C4::Budgets::GetBudgetPeriods;
my $bp_loop = $budgetperiods;
for my $bp ( @{$budgetperiods} ) {
    my $hierarchy = C4::Budgets::GetBudgetHierarchy( $$bp{budget_period_id}, undef, undef, 1 );
    for my $budget ( @{$hierarchy} ) {
        $$budget{budget_display_name} = sprintf("%s", ">" x $$budget{depth} . $$budget{budget_name});
    }
    $$bp{hierarchy} = $hierarchy;
}

$template->param(
    filters     => $filters,
    bp_loop     => $bp_loop,
);

output_html_with_http_headers $input, $cookie, $template->output;
