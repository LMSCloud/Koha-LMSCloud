#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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

use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use C4::Auth qw( get_template_and_user get_session haspermission );
use Koha::BiblioFrameworks;
use Koha::Cash::Registers;
use Koha::Libraries;
use Koha::Desks;

my $query = CGI->new();

my ( $template, $borrowernumber, $cookie, $flags ) = get_template_and_user({
    template_name   => "circ/set-library.tt",
    query           => $query,
    type            => "intranet",
    flagsrequired   => { catalogue => 1, },
});

my $sessionID = $query->cookie("CGISESSID");
my $session = get_session($sessionID);

my $op                  = $query->param('op') || q{};
my $branch              = $query->param('branch');
my $desk_id             = $query->param('desk_id');
my $register_id         = $query->param('register_id');
my $userenv_branch      = C4::Context->userenv->{'branch'} || '';
my $userenv_desk        = C4::Context->userenv->{'desk_id'} || '';
my $userenv_register_id = C4::Context->userenv->{'register_id'} || '';

# if bookmobile support is enabled we enable selection of libraries 
# based on library categories if defined
my $branchcategory = $query->param('branchcategory' );
my $userenv_branchcategory  = C4::Context->userenv->{'branchcategory'} || '';

my @updated;

my $library = Koha::Libraries->find($branch);
# $session lines here are doing the updating
if (
       $op eq 'cud-set-library'
    && $library
    && (   C4::Auth::haspermission( C4::Context->userenv->{'id'}, { 'loggedinlibrary' => 1 } )
        or C4::Context::IsSuperLibrarian() )
    )
{
    if ( !$userenv_branch or $userenv_branch ne $branch ) {
        my $branchname = $library->branchname;
        $session->param( 'branchname', $branchname );    # update sesssion in DB
        $session->param( 'branch',     $branch );        # update sesssion in DB
        push @updated, { updated_branch => 1 };
    }
} else {
    $branch = $userenv_branch;    # fallback value
}

if ( defined($desk_id) && ( !$userenv_desk || $userenv_desk ne $desk_id ) ) {
    if ($desk_id) {

        # A desk was selected
    my $desk          = Koha::Desks->find( { desk_id => $desk_id } );
    $session->param( desk_name => $desk->desk_name );
    $session->param( desk_id   => $desk->desk_id );
    } else {

        # "No desk" was explicitly selected - clear desk from session
        $session->clear( [ 'desk_name', 'desk_id' ] );
    }
    push @updated, { updated_desk => 1 };
} else {
    $desk_id = $userenv_desk;
}

# store the branchcategory selection for the session
if ( C4::Context->preference('BookMobileSupportEnabled') and
     defined($branchcategory) and $branchcategory ne $userenv_branchcategory) {
     $session->param('branchcategory', $branchcategory);    # update sesssion in DB
     push @updated,
          {
            updated_branchcategory => 1,
            old_branchcategory     => $userenv_branchcategory
          };
}

########################################
#  Read library groups
########################################
if ( C4::Context->preference('BookMobileSupportEnabled') ) {

    my @search_groups = Koha::Library::Groups->get_search_groups( { interface => 'staff' } )->as_list;
    @search_groups = sort { $a->title cmp $b->title } @search_groups;

    $branchcategory = $userenv_branchcategory || '*' if ( !defined($branchcategory) || $branchcategory eq '' );
    if ( scalar(@search_groups) ) {
        $template->param( groupselect   => 1,
                          librarygroups => \@search_groups,
                          selgroup      => $branchcategory,
                          selbranch     => $branch,
                           );
    }
}

$template->param(updated => \@updated) if (scalar @updated);

my @recycle_loop;
foreach ($query->param()) {
    $_ or next;                   # disclude blanks
    $_ eq "branch"     and next;  # disclude branch
    $_ eq "desk_id"    and next;  # disclude desk_id
    $_ eq "register_id" and next;    # disclude register
    $_ eq "oldreferer" and next;  # disclude oldreferer
    $_ eq "branchcategory" and next;  # disclude branchcategory
    push @recycle_loop, {
        param => $_,
        value => scalar $query->param($_),
      };
}

$session->flush();


my $referer =  $query->param('oldreferer') || $ENV{HTTP_REFERER} || '';
if ( scalar @updated ) {
    print $query->redirect($referer || '/cgi-bin/koha/mainpage.pl');
}

$template->param(
    referer     => $referer,
    branch      => $branch,
    desk_id     => $desk_id,
);

# Checking if there is a Fast Cataloging Framework
$template->param( fast_cataloging => 1 ) if Koha::BiblioFrameworks->find( 'FA' );

output_html_with_http_headers $query, $cookie, $template->output;
