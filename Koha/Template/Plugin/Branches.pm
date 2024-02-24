package Koha::Template::Plugin::Branches;

# Copyright ByWater Solutions 2012
# Copyright BibLibre 2014

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

use Template::Plugin;
use base qw( Template::Plugin );

use C4::Koha;
use C4::Context;
use Koha::Cache::Memory::Lite;
use Koha::Libraries;
use Koha::AdditionalContents;

sub new {
    my ($class, $context) = @_;

    my $self = {
        _CONTEXT => $context,
    };

    return bless $self, $class;
}

sub GetName {
    my ( $self, $branchcode ) = @_;
    return q{} unless defined $branchcode;
    return q{} if $branchcode eq q{};

    my $memory_cache = Koha::Cache::Memory::Lite->get_instance;
    my $cache_key    = "Library_branchname:" . $branchcode;
    my $cached       = $memory_cache->get_from_cache($cache_key);
    return $cached if $cached;

    my $l = Koha::Libraries->find($branchcode);

    my $branchname = $l ? $l->branchname : q{};
    $memory_cache->set_in_cache( $cache_key, $branchname );
    return $branchname;
}

sub GetLoggedInBranchcode {
    my ($self) = @_;

    return C4::Context::mybranch;
}

sub GetLoggedInBranchname {
    my ($self) = @_;

    return C4::Context->userenv ? C4::Context->userenv->{'branchname'} : q{};
}

sub GetURL {
    my ( $self, $branchcode ) = @_;

    unless (exists $self->{libraries}->{$branchcode} ){
        my $l = Koha::Libraries->find($branchcode);
        $self->{libraries}->{$branchcode} = $l if $l;
    }
    return $self->{libraries}->{$branchcode} ? $self->{libraries}->{$branchcode}->branchurl : q{};
}

sub all {
    my ( $self, $params ) = @_;
    my $selected = $params->{selected} // ();
    my $unfiltered = $params->{unfiltered} || 0;
    my $search_params = $params->{search_params} || {};
    my $do_not_select_my_library = $params->{do_not_select_my_library} || 0; # By default we select the library of the logged in user if no selected passed

    if ( !$unfiltered ) {
        $search_params->{only_from_group} = $params->{only_from_group} || 0;
    }
    
    $search_params = { -or => [ mobilebranch => undef, mobilebranch => '' ] } if ( $params->{restrict} && $params->{restrict} eq 'NoMobileStations' );

    my @selected =
      ref $selected eq 'Koha::Libraries'
      ? $selected->get_column('branchcode')
      : ( $selected // () );

    my $libraries = $unfiltered
      ? Koha::Libraries->search( $search_params, { order_by => ['branchname'] } )->unblessed
      : Koha::Libraries->search_filtered( $search_params, { order_by => ['branchname'] } )->unblessed;

    my $lang = 'default';
    eval {
        my $stash = $self->{_CONTEXT}->stash();
        $lang = $stash->get('lang');
    };
    
    for my $l (@$libraries) {
        if ( grep { $l->{branchcode} eq $_ } @selected
            or  not @selected
                and not $do_not_select_my_library
                and C4::Context->userenv
                and $l->{branchcode} eq ( C4::Context->userenv->{branch} // q{} ) )
        {
             $l->{selected} = 1;
        }
        eval {
            my $opac_info = Koha::AdditionalContents->find_best_match({
                                    category => 'html_customizations',
                                    location => 'OpacLibraryInfo',
                                    lang => $lang,
                                    library_id => $l->{branchcode},
                                });
            $l->{opac_info} = $opac_info->content if ($opac_info);
        };
    }


    return $libraries;
}

sub InIndependentBranchesMode {
    my ( $self ) = @_;
    return ( not C4::Context->preference("IndependentBranches") or C4::Context::IsSuperLibrarian );
}

sub pickup_locations {
    my ( $self, $params ) = @_;
    my $search_params = $params->{search_params} || {};
    my $selected      = $params->{selected};
    my @libraries;

    if ( defined $search_params->{item} || defined $search_params->{biblio} ) {
        my $item   = $search_params->{'item'};
        my $biblio = $search_params->{'biblio'};
        my $patron = $search_params->{'patron'};

        unless ( !defined $patron || ref($patron) eq 'Koha::Patron' ) {
            $patron = Koha::Patrons->find($patron);
        }

        if ($item) {
            $item = Koha::Items->find($item)
              unless ref($item) eq 'Koha::Item';
            @libraries = $item->pickup_locations( { patron => $patron } )->as_list
              if defined $item;
        } elsif ($biblio) {
            $biblio = Koha::Biblios->find($biblio)
              unless ref($biblio) eq 'Koha::Biblio';
            @libraries = $biblio->pickup_locations( { patron => $patron } )->as_list
              if defined $biblio;
        }
    } else {
        @libraries = Koha::Libraries->search( { pickup_location => 1 }, { order_by => ['branchname'] } )->as_list
          unless @libraries;
    }

    @libraries = map { $_->unblessed } @libraries;

    for my $l (@libraries) {
        if ( defined $selected and $l->{branchcode} eq $selected
            or not defined $selected
            and C4::Context->userenv
            and $l->{branchcode} eq C4::Context->userenv->{branch} )
        {
            $l->{selected} = 1;
        }
    }

    return \@libraries;
}

1;
