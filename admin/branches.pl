#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# Copyright 2015 Koha Development Team
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
use C4::Context;
use C4::Output;
use C4::Koha;
use Koha::Patrons;
use Koha::Items;
use Koha::Libraries;
use Koha::LibraryCategories;

my $input        = new CGI;
my $branchcode   = $input->param('branchcode');
my $categorycode = $input->param('categorycode');
my $op           = $input->param('op') || 'list';
my @messages;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {   template_name   => "admin/branches.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => 'parameters_remaining_permissions' },
        debug           => 1,
    }
);

if ( $op eq 'add_form' ) {
    my $library;
    my $searchmobile = { 'mobilebranch' => undef };
    if ($branchcode) {
        $library = Koha::Libraries->find($branchcode);
        $searchmobile->{'branchcode'} = { '!=' => $branchcode };
    }

    $template->param(
        library    => $library,
        categories => [ Koha::LibraryCategories->search( {}, { order_by => [ 'categorytype', 'categoryname' ] } ) ],
        mobilebranches => [ Koha::Libraries->search($searchmobile) ],
        $library ? ( selected_categorycodes => [ map { $_->categorycode } $library->get_categories ] ) : (),
    );
} elsif ( $op eq 'add_validate' ) {
    my @fields = qw(
      branchname
      branchaddress1
      branchaddress2
      branchaddress3
      branchzip
      branchcity
      branchstate
      branchcountry
      branchphone
      branchfax
      branchemail
      branchreplyto
      branchreturnpath
      branchurl
      issuing
      branchip
      branchnotes
      opac_info
      mobilebranch
    );
    my $is_a_modif = $input->param('is_a_modif');

    my @categories;
    for my $category ( Koha::LibraryCategories->search ) {
        push @categories, $category
          if $input->param( "selected_categorycode_" . $category->categorycode );
    }
    if ($is_a_modif) {
        my $library = Koha::Libraries->find($branchcode);
        for my $field (@fields) {
            $library->$field( scalar $input->param($field) );
        }
        $library->mobilebranch(undef) if (! $input->param('mobilebranch'));
        $library->update_categories( \@categories );

        eval { $library->store; };
        if ($@) {
            push @messages, { type => 'alert', code => 'error_on_update' };
        } else {
            push @messages, { type => 'message', code => 'success_on_update' };
        }
    } else {
        $branchcode =~ s|\s||g;
        my $library = Koha::Library->new(
            {   branchcode => $branchcode,
                ( map { $_ => scalar $input->param($_) || undef } @fields )
            }
        );
        eval { $library->store; };
        $library->add_to_categories( \@categories );
        if ($@) {
            push @messages, { type => 'alert', code => 'error_on_insert' };
        } else {
            push @messages, { type => 'message', code => 'success_on_insert' };
        }
    }
    $op = 'list';
} elsif ( $op eq 'delete_confirm' ) {
    my $library       = Koha::Libraries->find($branchcode);
    my $items_count = Koha::Items->search(
        {   -or => {
                holdingbranch => $branchcode,
                homebranch    => $branchcode
            },
        }
    )->count;
    my $patrons_count = Koha::Patrons->search( { branchcode => $branchcode, } )->count;

    if ( $items_count or $patrons_count ) {
        push @messages,
          { type => 'alert',
            code => 'cannot_delete_library',
            data => {
                items_count   => $items_count,
                patrons_count => $patrons_count,
            },
          };
        $op = 'list';
    } else {
        $template->param(
            library       => $library,
            items_count   => $items_count,
            patrons_count => $patrons_count,
        );
    }
} elsif ( $op eq 'delete_confirmed' ) {
    my $library = Koha::Libraries->find($branchcode);

    my $deleted = eval { $library->delete; };

    if ( $@ or not $deleted ) {
        push @messages, { type => 'alert', code => 'error_on_delete' };
    } else {
        push @messages, { type => 'message', code => 'success_on_delete' };
    }
    $op = 'list';
} elsif ( $op eq 'add_form_category' ) {
    my $category;
    if ($categorycode) {
        $category = Koha::LibraryCategories->find($categorycode);
    }
    $template->param( category => $category, );
} elsif ( $op eq 'add_validate_category' ) {
    my $is_a_modif = $input->param('is_a_modif');
    my @fields     = qw(
      categoryname
      codedescription
      categorytype
    );
    if ($is_a_modif) {
        my $category = Koha::LibraryCategories->find($categorycode);
        for my $field (@fields) {
            $category->$field( scalar $input->param($field) );
        }
        $category->show_in_pulldown( scalar $input->param('show_in_pulldown') eq 'on' );
        eval { $category->store; };
        if ($@) {
            push @messages, { type => 'alert', code => 'error_on_update_category' };
        } else {
            push @messages, { type => 'message', code => 'success_on_update_category' };
        }
    } else {
        my $category = Koha::LibraryCategory->new(
            {   categorycode => $categorycode,
                ( map { $_ => scalar $input->param($_) || undef } @fields )
            }
        );
        $category->show_in_pulldown( scalar $input->param('show_in_pulldown') eq 'on' );
        eval { $category->store; };
        if ($@) {
            push @messages, { type => 'alert', code => 'error_on_insert_category' };
        } else {
            push @messages, { type => 'message', code => 'success_on_insert_category' };
        }
    }
    $op = 'list';
} elsif ( $op eq 'delete_confirm_category' ) {
    my $category = Koha::LibraryCategories->find($categorycode);
    if ( my $libraries_count = $category->libraries->count ) {
        push @messages,
          { type => 'alert',
            code => 'cannot_delete_category',
            data => { libraries_count => $libraries_count, },
          };
        $op = 'list';
    } else {
        $template->param( category => $category );
    }
} elsif ( $op eq 'delete_confirmed_category' ) {
    my $category = Koha::LibraryCategories->find($categorycode);
    my $deleted = eval { $category->delete; };

    if ( $@ or not $deleted ) {
        push @messages, { type => 'alert', code => 'error_on_delete_category' };
    } else {
        push @messages, { type => 'message', code => 'success_on_delete_category' };
    }
    $op = 'list';
} else {
    $op = 'list';
}

if ( $op eq 'list' ) {
    my $libraries = Koha::Libraries->search( {}, { order_by => ['branchcode'] }, );
    $template->param(
        libraries   => $libraries,
        group_types => [
            {   categorytype => 'searchdomain',
                categories   => [ Koha::LibraryCategories->search( { categorytype => 'searchdomain' } ) ],
            },
            {   categorytype => 'properties',
                categories   => [ Koha::LibraryCategories->search( { categorytype => 'properties' } ) ],
            },
        ]
    );
}

$template->param(
    messages => \@messages,
    op       => $op,
    bookmobileactive => C4::Context->preference('BookMobileSupportEnabled'),
);

output_html_with_http_headers $input, $cookie, $template->output;
