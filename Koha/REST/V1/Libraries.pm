package Koha::REST::V1::Libraries;

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

use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Koha::Calendar;
use Koha::DateUtils qw( dt_from_string );
use Koha::Libraries;
use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::Library - Koha REST API for handling libraries (V1)

=head1 API

=head2 Methods

=cut

=head3 list

Controller function that handles listing Koha::Library objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $libraries_set = Koha::Libraries->new;
        my $libraries     = $c->objects->search( $libraries_set );
        return $c->render( status => 200, openapi => $libraries );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller function that handles retrieving a single Koha::Library

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $library_id = $c->validation->param('library_id');
        my $library = Koha::Libraries->find( $library_id );

        unless ($library) {
            return $c->render( status  => 404,
                            openapi => { error => "Library not found" } );
        }

        return $c->render(
            status  => 200,
            openapi => $library->to_api
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding a new Koha::Library object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $library = Koha::Library->new_from_api( $c->validation->param('body') );
        $library->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $library->branchcode );

        return $c->render(
            status  => 201,
            openapi => $library->to_api
        );
    }
    catch {
        if ( blessed $_ && $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => $_->error, conflict => $_->duplicate_id }
            );
        }

        $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::Library object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $library = Koha::Libraries->find( $c->validation->param('library_id') );

    if ( not defined $library ) {
        return $c->render(
            status  => 404,
            openapi => { error => "Library not found" }
        );
    }

    return try {
        my $params = $c->req->json;
        $library->set_from_api( $params );
        $library->store();
        return $c->render(
            status  => 200,
            openapi => $library->to_api
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller function that handles deleting a Koha::Library object

=cut

sub delete {

    my $c = shift->openapi->valid_input or return;

    my $library = Koha::Libraries->find( $c->validation->param( 'library_id' ) );

    if ( not defined $library ) {
        return $c->render( status => 404, openapi => { error => "Library not found" } );
    }

    return try {
        $library->delete;
        return $c->render( status => 204, openapi => '');
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 list_holidays

Controller function that returns closed days for a library within a date range.
Used by booking calendar to disable selection of closed days.

=cut

sub list_holidays {
    my $c = shift->openapi->valid_input or return;

    my $library_id = $c->param('library_id');
    my $from       = $c->param('from');
    my $to         = $c->param('to');

    my $library = Koha::Libraries->find($library_id);

    if ( !$library ) {
        return $c->render(
            status  => 404,
            openapi => { error => 'Library not found' }
        );
    }

    return try {
        my $from_dt = $from ? dt_from_string( $from, 'iso' ) : dt_from_string();
        my $to_dt   = $to   ? dt_from_string( $to,   'iso' ) : $from_dt->clone->add( months => 3 );

        if ( $to_dt->compare($from_dt) < 0 ) {
            return $c->render(
                status  => 400,
                openapi => { error => "'to' date must be after 'from' date" }
            );
        }

        my $calendar = Koha::Calendar->new( branchcode => $library_id );
        my $holidays = [];

        my $current = $from_dt->clone;
        while ( $current <= $to_dt ) {
            if ( $calendar->is_holiday($current) ) {
                push @{$holidays}, $current->ymd;
            }
            $current->add( days => 1 );
        }

        return $c->render(
            status  => 200,
            openapi => $holidays
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
